#!/bin/bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# For disabling touchpad.
# Edit the Touchpad_Device on ~/.config/hypr/UserConfigs/Laptops.conf according to your system
# use hyprctl devices to get your system touchpad device name
# source https://github.com/hyprwm/Hyprland/discussions/4283?sort=new#discussioncomment-8648109

notif="$HOME/.config/swaync/images/ja.png"

export STATUS_FILE="$XDG_RUNTIME_DIR/touchpad.status"

get_touchpad_name() {
    hyprctl devices | awk '
        /^[[:space:]]+[[:graph:]]+touchpad$/ {
            gsub(/^[[:space:]]+/, "", $0)
            print
            exit
        }
    '
}

enable_touchpad() {
    local touchpad_name
    touchpad_name="$(get_touchpad_name)"
    if [ -z "$touchpad_name" ]; then
        notify-send -u normal -i "$notif" "Touchpad" "No touchpad device found"
        return 1
    fi

    printf "true" >"$STATUS_FILE"
    notify-send -u low -i "$notif" " Enabling" " touchpad"
    hyprctl keyword "device[$touchpad_name]:enabled" "true" >/dev/null
}

disable_touchpad() {
    local touchpad_name
    touchpad_name="$(get_touchpad_name)"
    if [ -z "$touchpad_name" ]; then
        notify-send -u normal -i "$notif" "Touchpad" "No touchpad device found"
        return 1
    fi

    printf "false" >"$STATUS_FILE"
    notify-send -u low -i "$notif" " Disabling" " touchpad"
    hyprctl keyword "device[$touchpad_name]:enabled" "false" >/dev/null
}

if ! [ -f "$STATUS_FILE" ]; then
  enable_touchpad
else
  if [ $(cat "$STATUS_FILE") = "true" ]; then
    disable_touchpad
  elif [ $(cat "$STATUS_FILE") = "false" ]; then
    enable_touchpad
  fi
fi
