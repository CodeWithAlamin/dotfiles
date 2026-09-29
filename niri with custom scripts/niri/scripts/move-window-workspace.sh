#!/bin/sh

direction="$1"

workspaces=$(niri msg -j workspaces)

current=$(echo "$workspaces" |
    jq -r '.[] | select(.is_focused) | .idx')

count=$(echo "$workspaces" | jq 'length')

if [ "$direction" = "down" ]; then
    target=$((current + 1))

    while [ "$target" -le "$count" ]; do
        name=$(echo "$workspaces" |
            jq -r --argjson idx "$target" \
            '.[] | select(.idx == $idx) | .name // empty')

        [ "$name" != "special" ] && break

        target=$((target + 1))
    done
else
    target=$((current - 1))

    while [ "$target" -ge 1 ]; do
        name=$(echo "$workspaces" |
            jq -r --argjson idx "$target" \
            '.[] | select(.idx == $idx) | .name // empty')

        [ "$name" != "special" ] && break

        target=$((target - 1))
    done
fi

# No valid workspace in that direction.
[ "$target" -lt 1 ] && exit 0
[ "$target" -gt "$count" ] && exit 0

niri msg action move-window-to-workspace "$target"
