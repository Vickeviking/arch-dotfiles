#!/bin/bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Wallust Colors for current wallpaper

wallpaper_path="$1"
rofi_wallpaper="$HOME/.config/rofi/.current_wallpaper"
wallpaper_current="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
ln_success=false

if [ -z "$wallpaper_path" ] && [ -L "$rofi_wallpaper" ]; then
    wallpaper_path=$(readlink -f "$rofi_wallpaper")
fi

if [ -z "$wallpaper_path" ] && [ -f "$wallpaper_current" ]; then
    wallpaper_path="$wallpaper_current"
fi

if [ -z "$wallpaper_path" ] || [ ! -f "$wallpaper_path" ]; then
    cache_dir="$HOME/.cache/swww"
    if [ -d "$cache_dir" ] && command -v hyprctl >/dev/null 2>&1; then
        current_monitor=$(hyprctl monitors | awk '/^Monitor/{name=$2} /focused: yes/{print name}')
        cache_file="$cache_dir/$current_monitor"
        if [ -f "$cache_file" ]; then
            wallpaper_path=$(grep -v 'Lanczos3' "$cache_file" | head -n 1)
        fi
    fi
fi

if [ -n "$wallpaper_path" ] && [ -f "$wallpaper_path" ]; then
    if ln -sf "$wallpaper_path" "$rofi_wallpaper"; then
        ln_success=true
    fi

    if [ "$(readlink -f "$wallpaper_path")" != "$(readlink -f "$wallpaper_current" 2>/dev/null)" ]; then
        cp -f "$wallpaper_path" "$wallpaper_current"
    fi
fi

if [ "$ln_success" = true ]; then
    wallust run "$wallpaper_path" -s &
fi
