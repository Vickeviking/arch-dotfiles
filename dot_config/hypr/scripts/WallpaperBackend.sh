#!/bin/bash

wallpaper_backend_cmd() {
    if command -v swww >/dev/null 2>&1 && command -v swww-daemon >/dev/null 2>&1; then
        printf '%s\n' "swww"
    elif command -v awww >/dev/null 2>&1 && command -v awww-daemon >/dev/null 2>&1; then
        printf '%s\n' "awww"
    else
        return 1
    fi
}

wallpaper_daemon_cmd() {
    case "$(wallpaper_backend_cmd)" in
        swww) printf '%s\n' "swww-daemon" ;;
        awww) printf '%s\n' "awww-daemon" ;;
        *) return 1 ;;
    esac
}

wallpaper_start_daemon() {
    local backend daemon i

    backend=$(wallpaper_backend_cmd) || return 1
    if "$backend" query >/dev/null 2>&1; then
        return 0
    fi

    daemon=$(wallpaper_daemon_cmd) || return 1
    case "$daemon" in
        swww-daemon) "$daemon" --format xrgb >/dev/null 2>&1 & ;;
        awww-daemon) "$daemon" >/dev/null 2>&1 & ;;
        *) return 1 ;;
    esac

    for i in $(seq 1 25); do
        sleep 0.2
        if "$backend" query >/dev/null 2>&1; then
            return 0
        fi
    done

    return 1
}

wallpaper_img() {
    local backend

    backend=$(wallpaper_backend_cmd) || return 1
    "$backend" img "$@"
}

wallpaper_kill() {
    local backend

    backend=$(wallpaper_backend_cmd) || return 0
    "$backend" kill >/dev/null 2>&1
}
