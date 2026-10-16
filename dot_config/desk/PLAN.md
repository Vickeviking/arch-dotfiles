# Desk plan

Viktor's master plan for both machines (desktop `legion-arch` + ThinkPad), the Lantern hub, and later Arcturon.

**How this file works**
- One section per area. When Viktor mentions a new idea, Claude appends it to the matching section (or **Inbox** if it fits nowhere yet) and dates it.
- Status: `[ ]` todo · `[~]` in progress · `[x]` done · `[?]` needs a decision from Viktor.
- **Now** is the only ordered list; everything else is a backlog grouped by area.
- Synced to both machines through chezmoi (`~/.config/desk/PLAN.md`).

---

## Now (in order)

1. [ ] **ThinkPad SSH is unreachable since its reboot** (ping works, port 22 doesn't). Viktor runs on the ThinkPad: `systemctl status sshd --no-pager | head -5; sudo ufw status verbose | head -12; ip -br addr | grep -i tailscale`.
2. [ ] Desktop finishing touches (Viktor): `/theme` → *Desk · Rain-city noir*, paste `statusLine` + `spinnerVerbs` into `~/.claude/settings.json`, `sudo pacman -S arch-audit`.
3. [ ] Commit + push today's dotfiles (Viktor's OK given 2026-10-16), then roll out styling to the ThinkPad.
4. [ ] Lantern: design mockup (artifact) → Viktor approves → phase 1.
5. [ ] Dotfiles: one source of truth (see **Dotfiles & sync**).
6. [ ] Backups.

---

## Security
- [x] ufw on both machines: deny in, allow out/routed, allow `tailscale0` + `docker0` (+ `virbr0` on desktop). 2026-10-16
- [x] ThinkPad SSH keys-only (`/etc/ssh/sshd_config.d/10-keys-only.conf`). 2026-10-16
- [x] Desktop locks after 30 min idle. 2026-10-15
- [x] Waybar privacy indicators: mic/screen-share (`privacy`), camera (`desk-camera`). 2026-10-16
- [x] Waybar updates counter (`desk-updates`); turns red with `arch-audit` findings once installed. 2026-10-16
- [ ] Arcturon Postgres (5432) + Redis (6379) are bound to 0.0.0.0 via `scripts/init_db.sh` / `init_redis.sh`; Docker bypasses ufw → bind to 127.0.0.1 (check the data volume before recreating). *Deferred by Viktor.*
- [ ] ThinkPad: 10 pending updates incl. kernel → `sudo pacman -Syu` then reboot immediately.
- [ ] ThinkPad disk encryption (LUKS): only at a future reinstall.
- Rule learned: after a kernel update, reboot before touching firewall/network config.

## Styling & desktop
- [x] `desk-theme` switcher: 6 palettes (`~/.config/themes/palettes`), default **Rain-city noir**; Super+Shift+T picker; `/desk-theme` in Claude. 2026-10-16
- [x] Waybar `[TOP] Rain City` + `[Desk] Themed.css` (3 islands). Rollback: `~/.config/themes/waybar-rollback.sh`. 2026-10-16
- [x] Hyprland: amber→teal gradient border, soft shadow, gaps 4/10, snappy animations. 2026-10-16
- [x] kitty, rofi, swaync, hyprlock follow the theme. 2026-10-16
- [ ] Verify hyprlock look on first real lock.
- [ ] Optional: kitty font (Fantasque Bold now) → regular weight?
- [ ] Theme gallery artifact: https://claude.ai/artifact/6u3wsKUpN79yTCxEAvrxxB

**Max it out** (Viktor 2026-10-16: "really focus on making the OS and feel of everything maxed", same on both machines). Everything below reads the `desk-theme` palette so one switch restyles all of it:
- [ ] **Browser colors**: `desk-theme` writes an unpacked Chrome theme (load once in `chrome://extensions`); Firefox via `userChrome.css` if used.
- [ ] **Browser vim keys mirroring Viktor's nvim**: Surfingkeys (Chrome) with mappings generated from `~/.config/nvim/lua/vango/core/keymaps.lua`; Tridactyl if Firefox.
- [?] Which browser is the daily driver? (Super+B launches `firefox-hybrid`.)
- [ ] **GTK + Qt apps** (Thunar, dialogs, file pickers): GTK3/4 CSS + Kvantum/qt6ct from the palette.
- [ ] **nvim colorscheme** generated from the palette (same amber/teal as kitty), switches live.
- [ ] **Shell prompt** (starship) + fastfetch + btop + cava themed.
- [ ] **Cursor + icons**: one cursor theme and one icon theme on both machines.
- [ ] **Login + boot**: SDDM theme (wallpaper + palette), plymouth splash, GRUB theme.
- [ ] **Apps**: Spotify (spicetify), Discord (Vesktop + theme), Obsidian, zathura.
- [ ] **Sound design**: small, consistent notification/plug/unplug sounds.
- [ ] **Wallpapers per theme**: each palette ships a matching wallpaper (optional, toggle).

## ThinkPad
- [ ] Roll out styling (themes, scripts, waybar, Hyprland Lua, kitty, rofi, swaync, hyprlock, `rain-city` mod). Compare every file first; keybinds, monitors and hyprlock may be machine-specific.
- [ ] Replace nm-applet + blueman with Lantern's Wi-Fi and Bluetooth tabs; waybar icons open those tabs.
- [ ] Install the `desk-mods` marketplace + `rain-city` plugin.

## Dotfiles & sync
Today GitHub (`Vickeviking/arch-dotfiles`, chezmoi), the desktop and the ThinkPad are three different versions: the repo still holds the old `.conf` Hyprland files and none of the Lua config; the desktop has 48 files differing from the repo.
- [ ] Make GitHub the single source of truth: add the live Lua config + today's files, retire the stale `.conf` files (kept in git history).
- [ ] Per-machine differences via chezmoi templates on hostname (monitors, keybinds, hyprlock, laptop-only modules).
- [ ] Workflow written into the `arch-machine` skill: edit → `chezmoi add` → commit → (push with OK) → other machine `chezmoi diff` → `chezmoi update`.
- [ ] Commit the 3 pending nvim changes on the desktop (Viktor reviews).

## Lantern (Super+Space hub)
**Vision:** a god view of the computer, beautiful and fast. Rust + GTK4 + gtk4-layer-shell (same stack as Arch-flywheel), colors from `desk-theme`, repo `~/dev/project/Lantern`.

Tabs:
- [ ] **Home**: launcher + quick actions (what Flywheel did), at-a-glance machine health.
- [ ] **System**: CPU per core, RAM/swap, GPU, temps, disks, battery, uptime; history graphs.
- [ ] **Processes**: sortable list, tree view, kill/renice (with confirmation), per-process CPU/RAM/IO/network.
- [ ] **Network → Per-app traffic**: which program talks to which host, bandwidth, GeoIP country.
- [ ] **Network → Home map**: devices on the LAN, new-device alerts, open ports on your own devices.
- [ ] **Network → Packet inspector**: live capture + protocol decode of own traffic (tshark engine; one-time root setup by Viktor: `wireshark` group / capabilities).
- [ ] **Network → Wi-Fi radio**: nearby networks, channels, signal over time, interference.
- [ ] **Wi-Fi**: connect / forget / hotspot (NetworkManager D-Bus).
- [ ] **Bluetooth**: scan / pair / connect / battery levels (BlueZ D-Bus).
- [ ] **Manuals**: man pages, tldr, offline Arch wiki, searchable.
- [ ] **Keybinds**: live cheat sheet parsed from the Lua bind files (from the old Super+H app).
- [ ] **Ask**: local AI (Ollama) or Claude, answers from dotfiles/man/wiki; must stay fast.

Phases:
- [ ] 0. Mockup artifact, Viktor approves the look.
- [ ] 1. Skeleton: layer-shell window, tabs, theme loading, Super+Space toggle, <100 ms open.
- [ ] 2. System + Processes.
- [ ] 3. Wi-Fi + Bluetooth (unblocks the ThinkPad GUI swap).
- [ ] 4. Network god view (per-app → home map → Wi-Fi radio → packet inspector).
- [ ] 5. Manuals + Keybinds + Ask.
- [ ] Decisions: Flywheel retired (repo stays); Super+H freed (old `hypr_sheet.py` retires).

## Quick ask (Super+A)
- [ ] Super+A anywhere: silent full-screen screenshot (no preview/animation) → small floating chat bottom-left with the screenshot attached.
- [ ] Answer via Claude (`claude -p` with the image; works on the ThinkPad) or local Ollama on the desktop; pick per question.
- [ ] Use it to ask about and update dotfiles quickly.
- [?] Super+A today toggles the Quickshell overview: move the overview to another key?

## Backups
- [ ] restic, desktop ⇄ ThinkPad over Tailscale, nightly; scope `~/dev`, chezmoi source, `~/Documents`, `~/Pictures` (minus build dirs) + Arcturon `pg_dump`.
- [ ] Viktor sets the repo password + SSH keys and enables the `systemd --user` timers.
- [ ] Verify by restoring a file.

## Clean-up
- [ ] `comfyui` container still running although `/mnt/data/ai` models are gone → stop/remove (with OK).
- [ ] Old `hypr_sheet.py` (Super+H) once Lantern covers it.
- [ ] Orphan packages, pacman cache, Docker images, old `.bak-*` files: inventory first, Viktor approves.
- [ ] Ollama models: keep only what Ask uses.

## Claude Code
- [x] Global profile `~/.claude/CLAUDE.md`, `arch-machine` skill, house rules ("Viktor is the captain"). 2026-10-15
- [x] Plugins pruned (Superpowers, Firecrawl, GitKraken, Agent Flow removed); connectors trimmed. 2026-10-15
- [x] `rain-city` mod: status band, long-turn toast + chime, `/desk-theme`. 2026-10-16
- [ ] Status line + spinner verbs pasted by Viktor.

## Arcturon (later)
- [ ] Bring the desk style to the app with the design/UX skills.
- [ ] Clean-up, refactoring, tests, scaling review, documentation.

## Inbox
- (new ideas land here until sorted)

## Decisions
- 2026-10-15 Security: sensible, not paranoid; nothing that can lock Viktor out.
- 2026-10-16 Theme: Rain-city noir default; snappy & subtle animations.
- 2026-10-16 Lantern: Rust + GTK4; Flywheel retired; Super+H freed; Wi-Fi/Bluetooth as hub tabs; Ask kept if it stays fast.
