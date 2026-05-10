#!/usr/bin/env python3

import fcntl
import json
import os
import signal
import socket
import subprocess
import sys
import time
from pathlib import Path


HOME = Path.home()
STATE_FILE = HOME / ".cache" / "hypr-refresh-mode.json"
LOCK_FILE = HOME / ".cache" / "hypr-refresh-mode.lock"
ICON = HOME / ".config" / "swaync" / "images" / "ja.png"
WAYBAR_SIGNAL_OFFSET = 8
DEBOUNCE_SECONDS = 1.0


def run(cmd, check=False):
    return subprocess.run(cmd, capture_output=True, text=True, check=check)


def get_socket_path():
    runtime_dir = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
    hypr_dir = runtime_dir / "hypr"
    signature = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")

    if signature:
        socket_path = hypr_dir / signature / ".socket2.sock"
        if socket_path.exists():
            return socket_path

    if not hypr_dir.exists():
        return None

    candidates = sorted(hypr_dir.iterdir(), key=lambda path: path.stat().st_mtime, reverse=True)
    for candidate in candidates:
        socket_path = candidate / ".socket2.sock"
        if socket_path.exists():
            return socket_path

    return None


def get_monitors():
    proc = run(["hyprctl", "-j", "monitors"])
    if proc.returncode != 0:
        return None
    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError:
        return None


def get_internal_monitor(monitors):
    for monitor in monitors:
        if not monitor.get("disabled") and monitor.get("name", "").startswith("eDP-"):
            return monitor
    return None


def has_external_monitor(monitors):
    return any(
        not monitor.get("disabled") and not monitor.get("name", "").startswith("eDP-")
        for monitor in monitors
    )


def write_state(hz, mode):
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)

    if hz is None:
        payload = {
            "text": "Ext",
            "tooltip": "Extern skarm aktiv, intern panel ej tillganglig",
            "class": "refresh-mode external-only",
        }
    else:
        payload = {
            "text": f"{hz}Hz",
            "tooltip": f"Auto refresh mode: {mode}",
            "class": f"refresh-mode hz-{hz}",
        }

    STATE_FILE.write_text(json.dumps(payload) + "\n")


def notify_mode(hz, mode):
    body = f"{hz}Hz, {mode}" if hz is not None else f"Extern skarm, {mode}"
    run(
        [
            "notify-send",
            "-e",
            "-u",
            "low",
            "-h",
            "string:x-canonical-private-synchronous:refresh_mode",
            "-h",
            "boolean:SWAYNC_BYPASS_DND:true",
            "-i",
            str(ICON),
            "Refresh Mode",
            body,
        ]
    )


def signal_waybar():
    try:
        sig = signal.SIGRTMIN + WAYBAR_SIGNAL_OFFSET
    except Exception:
        return

    proc = run(["pgrep", "-x", "waybar"])
    if proc.returncode != 0:
        return

    for pid in proc.stdout.split():
        try:
            os.kill(int(pid), sig)
        except OSError:
            continue


def desired_state(monitors):
    internal = get_internal_monitor(monitors)
    external = has_external_monitor(monitors)
    hz = 60 if external else 240
    mode = "dockad" if external else "laptop only"
    return internal, hz, mode


def available_for_hz(monitor, hz):
    wanted_prefix = f"{monitor['width']}x{monitor['height']}@{hz}"
    return any(mode.startswith(wanted_prefix) for mode in monitor.get("availableModes", []))


def apply_refresh(monitor, hz):
    scale = monitor.get("scale", 1)
    monitor_arg = (
        f"{monitor['name']},"
        f"{monitor['width']}x{monitor['height']}@{hz},"
        f"{monitor['x']}x{monitor['y']},"
        f"{scale:g}"
    )
    proc = run(["hyprctl", "keyword", "monitor", monitor_arg])
    return proc.returncode == 0


def load_existing_state():
    if not STATE_FILE.exists():
        return None
    try:
        return json.loads(STATE_FILE.read_text())
    except json.JSONDecodeError:
        return None


def reconcile(notify=False):
    monitors = get_monitors()
    if not monitors:
        return

    internal, wanted_hz, mode = desired_state(monitors)

    if internal is None:
        previous = load_existing_state()
        write_state(None, "extern only")
        signal_waybar()
        if notify and previous is not None and previous.get("text") != "Ext":
            notify_mode(None, "extern only")
        return

    current_hz = int(round(float(internal.get("refreshRate", 0))))
    if current_hz != wanted_hz and available_for_hz(internal, wanted_hz):
        if apply_refresh(internal, wanted_hz):
            time.sleep(0.6)
            monitors = get_monitors() or monitors
            internal = get_internal_monitor(monitors) or internal
            current_hz = int(round(float(internal.get("refreshRate", wanted_hz))))

    previous = load_existing_state()
    write_state(current_hz, mode)
    signal_waybar()

    if notify:
        prev_text = previous.get("text") if previous else None
        if prev_text != f"{current_hz}Hz":
            notify_mode(current_hz, mode)


def monitor_event(event_line):
    return event_line.startswith(("monitoradded", "monitorremoved", "monitoraddedv2", "monitorremovedv2"))


def listen():
    socket_path = get_socket_path()
    if socket_path is None:
        print("Hyprland socket2 not found", file=sys.stderr)
        return 1

    while True:
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
                client.connect(str(socket_path))
                buffer = ""
                while True:
                    data = client.recv(4096)
                    if not data:
                        break
                    buffer += data.decode(errors="ignore")
                    while "\n" in buffer:
                        line, buffer = buffer.split("\n", 1)
                        if monitor_event(line):
                            time.sleep(DEBOUNCE_SECONDS)
                            reconcile(notify=True)
        except OSError:
            time.sleep(2)
            socket_path = get_socket_path()
            if socket_path is None:
                continue


def acquire_lock():
    LOCK_FILE.parent.mkdir(parents=True, exist_ok=True)
    lock_handle = LOCK_FILE.open("w")
    try:
        fcntl.flock(lock_handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        return None
    lock_handle.write(str(os.getpid()))
    lock_handle.flush()
    return lock_handle


def main():
    if "--once" in sys.argv:
        reconcile(notify=True)
        return 0

    lock_handle = acquire_lock()
    if lock_handle is None:
        return 0

    time.sleep(DEBOUNCE_SECONDS)
    reconcile(notify=True)
    try:
        return listen()
    finally:
        lock_handle.close()


if __name__ == "__main__":
    raise SystemExit(main())
