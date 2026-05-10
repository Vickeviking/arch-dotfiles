#!/bin/bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Game Mode. Turning off all animations

notif="$HOME/.config/swaync/images/ja.png"
SCRIPTSDIR="$HOME/.config/hypr/scripts"

# shellcheck source=/home/vango/.config/hypr/scripts/WallpaperBackend.sh
source "$SCRIPTSDIR/WallpaperBackend.sh"


HYPRGAMEMODE=$(hyprctl getoption animations:enabled | awk 'NR==1{print $2}')
if [ "$HYPRGAMEMODE" = 1 ] ; then
    hyprctl --batch "\
        keyword animations:enabled 0;\
        keyword decoration:shadow:enabled 0;\
        keyword decoration:blur:enabled 0;\
        keyword general:gaps_in 0;\
        keyword general:gaps_out 0;\
        keyword general:border_size 1;\
        keyword decoration:rounding 0"
	
	hyprctl keyword "windowrule opacity 1 override 1 override 1 override, ^(.*)$"
    wallpaper_kill
    notify-send -e -u low -i "$notif" " Gamemode:" " enabled"
    exit
else
	wallpaper_start_daemon && wallpaper_img "$HOME/.config/rofi/.current_wallpaper" >/dev/null 2>&1
	sleep 0.1
	${SCRIPTSDIR}/WallustSwww.sh "$HOME/.config/rofi/.current_wallpaper"
	sleep 0.5
	${SCRIPTSDIR}/Refresh.sh	 
    notify-send -e -u normal -i "$notif" " Gamemode:" " disabled"
    exit
fi
hyprctl reload
