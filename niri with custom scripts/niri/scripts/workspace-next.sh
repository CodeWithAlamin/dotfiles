#!/bin/sh

direction="$1"

current=$(niri msg -j workspaces | jq -r '.[] | select(.is_focused) | .idx')
count=$(niri msg -j workspaces | jq 'length')

if [ "$direction" = "down" ]; then
    next=$((current + 1))
    [ "$next" -gt "$count" ] && exit 0
else
    next=$((current - 1))
    [ "$next" -lt 1 ] && exit 0
fi

# Skip the special workspace.
target=$(niri msg -j workspaces | jq -r --argjson idx "$next" \
    '.[] | select(.idx == $idx) | .name')

if [ "$target" = "special" ]; then
    if [ "$direction" = "down" ]; then
        next=$((next + 1))
    else
        next=$((next - 1))
    fi
fi

[ "$next" -ge 1 ] && [ "$next" -le "$count" ] &&
    niri msg action focus-workspace "$next"
