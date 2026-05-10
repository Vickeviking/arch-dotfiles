#!/bin/sh
set -eu

ln -sfn "$HOME/.config/waybar/configs/[TOP] Default Laptop" "$HOME/.config/waybar/config"
ln -sfn "$HOME/.config/waybar/style/[Extra] Modern-Combined - Transparent.css" "$HOME/.config/waybar/style.css"

printf '%s\n' 'Restored JaKooLit Waybar defaults.'
