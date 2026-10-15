---
name: arch-machine
description: How to work on Viktor's two Arch + Hyprland machines (desktop and ThinkPad). Use when changing system or dotfile config (Hyprland, waybar, rofi, kitty, zsh, nvim), installing or removing packages, managing services, cleaning up disk or files outside a project, checking security or privacy (camera, mic, firewall, SSH), or styling the desktop.
---

# Arch machine

The house rules in `~/.claude/CLAUDE.md` ("Viktor is the captain") apply in full: root goes to Viktor as commands, deleting means trash, databases and git are guarded. This skill adds how the machines are set up and the procedure for touching them.

## The machines

- **Desktop** (this machine, `legion-arch`) and **ThinkPad** (`ssh vango@vango-arch-thinkpad`). Both on Tailscale; the ThinkPad may be asleep: use `ssh -o ConnectTimeout=5` and report it offline rather than waiting.
- Arch, ext4 root (no snapshots), zsh, `yay` for AUR, Docker, kitty, rofi, swaync, hyprlock, hypridle, swww, waybar.
- Hyprland 0.56 with **KoolDots** (JaKooLit lineage), configured in **Lua**: entry `~/.config/hypr/hyprland.lua`; personal overrides go in `~/.config/hypr/UserConfigs/user_*.lua`. Base `lua/*.lua` modules are upstream templates: leave them alone so upgrades stay clean.
- waybar: `~/.config/waybar/config` and `style.css` are symlinks into `configs/` and `style/`; personal modules live in `UserModules`.
- Dotfiles: **chezmoi**, source `~/.local/share/chezmoi`, repo `Vickeviking/arch-dotfiles`, shared by both machines. The live files are newer than the repo in places (Hyprland moved to Lua after the last commit), so the live file is the truth.

## Changing a config

1. **Look**: read the live file and `chezmoi diff <path>` before editing.
2. **Backup**: copy the file to `<file>.bak-YYYYMMDD-HHMMSS` next to it.
3. **Edit** the live file, smallest change that does the job.
4. **Verify** the change took: `hyprctl reload` then `hyprctl configerrors` (empty = good), `pkill -SIGUSR2 waybar` or restart waybar, and check the result (`hyprctl getoption`, a screenshot via `grim` if visual). Done means verified, never just "edited".
5. **Show** Viktor the diff and the backup path.
6. **Sync**: `chezmoi add <path>` for files chezmoi manages, then commit in the chezmoi repo; ask before pushing. The other machine picks it up with `chezmoi update`, which Viktor runs or approves after seeing `chezmoi diff` there.

`chezmoi apply` or `update` overwrites live files: run it only on paths whose `chezmoi diff` Viktor has seen.

## Packages and services

- You may query freely: `pacman -Q/-Qi/-Ss`, `yay -Ss`, `systemctl status`, `journalctl`.
- Installing, removing, enabling or disabling system services needs root: hand Viktor the exact command, e.g. `sudo pacman -S --needed trash-cli`, and say what it does. `systemctl --user` services you may manage yourself.
- Prefer official repos over AUR; for an AUR package, name it as AUR and show its PKGBUILD source before suggesting it.

## Cleaning up

1. **Inventory** first: sizes (`du -sh`, `ncdu -x` if installed), `pacman -Qdtq` (orphans), `paccache -dk2` (dry run), `docker system df`, stale `*.bak-*` files.
2. Present a table: path, size, why it is safe, how to restore.
3. After Viktor approves, `gio trash` user files; root-owned cleanups (orphans, pacman cache) go to Viktor as commands.

Docker images, containers and volumes belong to projects (Arcturon's Postgres lives in a volume): touch them only by name, after approval.

## Security and privacy checks

Read-only by default, both machines, then a findings table ranked by risk with the fix for each:

- Camera/mic: who holds `/dev/video*` (`fuser -v /dev/video*`), PipeWire clients (`pw-cli ls Node`, `wpctl status`), portal permissions.
- Network: listening ports (`ss -tulpn`), firewall state, Tailscale (`tailscale status`, `tailscale serve status`).
- SSH: `sshd -T` key settings (password auth, root login), `~/.ssh/authorized_keys` contents (report, never edit).
- Updates: `checkupdates` count; Lynis audit if installed (`lynis audit system` needs root → Viktor runs it and shares the report).

## Styling

Pick one theme and apply it everywhere (Hyprland borders/gaps/animations, waybar, rofi, kitty, swaync, hyprlock) so the desktop reads as one system. Try it on one machine first, show a screenshot, and roll out to the other only after Viktor likes it.
