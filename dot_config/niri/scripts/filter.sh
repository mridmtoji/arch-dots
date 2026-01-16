#!/bin/bash

PRESET_DIR="$HOME/.config/sunsetr/presets"
PRESETS=$(find "$PRESET_DIR" -maxdepth 1 -mindepth 1 -type d -printf "%f\n")

ACTIVE=$(sunsetr preset active | awk '{print $3}')

MENU=$(echo "$PRESETS" | awk -v act="$ACTIVE" '
{
    if ($0 == act) {
        print "  " $0
    } else {
        print $0
    }
}')

if [ -z "$PRESETS" ]; then
    notify-send "Sunsetr" "No presets found!"
    exit 1
fi

CHOSEN=$(echo "$MENU" | fuzzel --dmenu | sed 's/^  //')

[ -z "$CHOSEN" ] && exit 0

sunsetr preset "$CHOSEN"
