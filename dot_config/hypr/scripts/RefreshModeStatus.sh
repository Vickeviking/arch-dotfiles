#!/bin/bash

STATE_FILE="$HOME/.cache/hypr-refresh-mode.json"

if [ -s "$STATE_FILE" ]; then
    cat "$STATE_FILE"
else
    printf '{"text":"--Hz","tooltip":"Refresh mode starting","class":"refresh-mode unknown"}\n'
fi
