#!/bin/sh

ANIMATION="$HOME/.config/niri/cfg/animation.kdl"
NORMAL="$HOME/.config/niri/cfg/animation.kdl.normal"
INSTANT="$HOME/.config/niri/cfg/animation.kdl.instant"

LOCK="/tmp/niri-special-workspace.lock"
QUEUE="/tmp/niri-special-workspace.queue"

# If another instance is running, queue this toggle.
if ! mkdir "$LOCK" 2>/dev/null; then
    count=$(cat "$QUEUE" 2>/dev/null || echo 0)
    echo $((count + 1)) > "$QUEUE"
    exit 0
fi

echo 1 > "$QUEUE"

cleanup() {
    cp "$NORMAL" "$ANIMATION"
    niri msg action load-config-file >/dev/null 2>&1
    rm -f "$QUEUE"
    rmdir "$LOCK" 2>/dev/null
}

trap cleanup EXIT INT TERM

while true; do

    # Consume one queued action.
    count=$(cat "$QUEUE" 2>/dev/null || echo 1)

    if [ "$count" -gt 1 ]; then
        echo $((count - 1)) > "$QUEUE"
    else
        echo 0 > "$QUEUE"
    fi

    # Disable workspace animation.
    cp "$INSTANT" "$ANIMATION"
    niri msg action load-config-file >/dev/null 2>&1

    # Determine where we are going.
    if niri msg -j workspaces | jq -e \
        '.[] | select(.is_focused and .name == "special")' >/dev/null
    then
        TARGET="previous"
    else
        TARGET="special"
    fi

    # Perform the toggle.
    if [ "$TARGET" = "special" ]; then
        niri msg action focus-workspace special
    else
        niri msg action focus-workspace-previous
    fi

    # Wait for Niri's state to actually change.
    # No fixed transition delay.
    while true; do
        if [ "$TARGET" = "special" ]; then
            niri msg -j workspaces |
                jq -e '.[] | select(.is_focused and .name == "special")' \
                >/dev/null && break
        else
            if ! niri msg -j workspaces |
                jq -e '.[] | select(.is_focused and .name == "special")' \
                >/dev/null
            then
                break
            fi
        fi

        sleep 0.01
    done

    # Workspace transition is actually complete.
    cp "$NORMAL" "$ANIMATION"
    niri msg action load-config-file >/dev/null 2>&1

    # Anything else queued?
    count=$(cat "$QUEUE" 2>/dev/null || echo 0)

    [ "$count" -eq 0 ] && break

    # Process the next queued toggle immediately.
done
