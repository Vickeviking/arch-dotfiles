#!/usr/bin/env bash

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/hyprsunset"
STATE_FILE="$CACHE_DIR/state"
TEMP_FILE="$CACHE_DIR/temperature"
DEFAULT_TEMP=3400
GAMMA_ON=85
GAMMA_OFF=100
SIGNAL=9

notify_waybar() {
	pkill -RTMIN+"$SIGNAL" waybar 2>/dev/null || true
}

json() {
	printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' "$1" "$2" "$3"
}

is_night_hours() {
	local hour
	hour="$(date +%H)"
	[ "$hour" -ge 21 ] || [ "$hour" -lt 7 ]
}

current_temp() {
	if [ -f "$TEMP_FILE" ]; then
		cat "$TEMP_FILE"
	else
		printf '%s\n' "$DEFAULT_TEMP"
	fi
}

ensure_daemon() {
	command -v hyprsunset >/dev/null 2>&1 || return 1

	if pgrep -x hyprsunset >/dev/null 2>&1; then
		return 0
	fi

	systemctl --user start hyprsunset.service >/dev/null 2>&1 || {
		nohup hyprsunset >/tmp/hyprsunset.log 2>&1 &
	}

	sleep 0.4
}

status_class() {
	if [ -f "$STATE_FILE" ]; then
		cat "$STATE_FILE"
	elif is_night_hours; then
		printf 'on\n'
	else
		printf 'off\n'
	fi
}

turn_on() {
	ensure_daemon || return 1
	local temp
	temp="$(current_temp)"
	hyprctl hyprsunset temperature "$temp" >/dev/null
	hyprctl hyprsunset gamma "$GAMMA_ON" >/dev/null
	mkdir -p "$CACHE_DIR"
	printf 'on\n' > "$STATE_FILE"
	printf '%s\n' "$temp" > "$TEMP_FILE"
}

turn_off() {
	ensure_daemon || return 1
	hyprctl hyprsunset identity >/dev/null
	hyprctl hyprsunset gamma "$GAMMA_OFF" >/dev/null
	mkdir -p "$CACHE_DIR"
	printf 'off\n' > "$STATE_FILE"
}

adjust_temp() {
	ensure_daemon || return 1
	local delta temp
	delta="$1"
	temp="$(current_temp)"
	temp=$((temp + delta))

	if [ "$temp" -lt 2000 ]; then
		temp=2000
	elif [ "$temp" -gt 6000 ]; then
		temp=6000
	fi

	mkdir -p "$CACHE_DIR"
	printf '%s\n' "$temp" > "$TEMP_FILE"
	hyprctl hyprsunset temperature "$temp" >/dev/null
	hyprctl hyprsunset gamma "$GAMMA_ON" >/dev/null
	printf 'on\n' > "$STATE_FILE"
}

status() {
	if ! command -v hyprsunset >/dev/null 2>&1; then
		json "󰖔" "Hyprsunset missing. Install with: sudo pacman -S hyprsunset" "missing"
		return
	fi

	case "$(status_class)" in
		on)
			json "󰖔" "Night light on ($(current_temp)K). Click: toggle. Scroll: adjust warmth. Right click: off." "on"
			;;
		*)
			json "󰖔" "Night light off. Click: warm display. Scroll: adjust warmth." "off"
			;;
	esac
}

case "$1" in
	start)
		if is_night_hours; then
			turn_on
		else
			turn_off
		fi
		;;
	on)
		turn_on
		notify_waybar
		;;
	off)
		turn_off
		notify_waybar
		;;
	toggle)
		if [ "$(status_class)" = "on" ]; then
			turn_off
		else
			turn_on
		fi
		notify_waybar
		;;
	warmer)
		adjust_temp -250
		notify_waybar
		;;
	cooler)
		adjust_temp 250
		notify_waybar
		;;
	status|*)
		status
		;;
esac
