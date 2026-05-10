#!/bin/bash

SCRIPTSDIR="$HOME/.config/hypr/scripts"
wallpaper_current="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"

# shellcheck source=/home/vango/.config/hypr/scripts/WallpaperBackend.sh
source "$SCRIPTSDIR/WallpaperBackend.sh" || exit 0

[ -f "$wallpaper_current" ] || exit 0
wallpaper_start_daemon || exit 0
wallpaper_img "$wallpaper_current" >/dev/null 2>&1 || exit 0
"$SCRIPTSDIR/WallustSwww.sh" "$wallpaper_current" >/dev/null 2>&1 &
