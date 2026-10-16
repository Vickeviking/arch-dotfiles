# Desk plan

Viktor's master plan for both machines (desktop `legion-arch` + ThinkPad), the Watchtower hub, and later Arcturon.

**How this file works**
- One section per area. When Viktor mentions a new idea, Claude appends it to the matching section (or **Inbox** if it fits nowhere yet) and dates it.
- Status: `[ ]` todo · `[~]` in progress · `[x]` done · `[?]` needs a decision from Viktor.
- **Now** is the only ordered list; everything else is a backlog grouped by area.
- Synced to both machines through chezmoi (`~/.config/desk/PLAN.md`).
- Overview page for Viktor: Desk HQ https://claude.ai/artifact/7vvEvMGHYX3bQqftBMWyDN

---

## Now (in order)

1. [~] **Watchtower**: phase 0 mockup loved; phase 1 skeleton built and on Super+Space (2026-10-16) → Viktor tries it → phase 2 (System + Processes).
2. [ ] ThinkPad: Viktor installs Thunar (`sudo pacman -S thunar gvfs tumbler thunar-archive-plugin thunar-volman ffmpegthumbnailer xarchiver`).
3. [~] GRUB clutter (desktop, dual boot, Windows stays): `GRUB_DISABLE_BOOTNEXT=true` removes the 10 PXE/duplicate BootNext entries; the custom `11_windows` entry stays. Viktor runs the commands. 2026-10-16
4. [ ] Dotfiles: one source of truth (see **Dotfiles & sync**).
5. [ ] Backups.

---

## Security
- [x] ufw on both machines: deny in, allow out/routed, allow `tailscale0` + `docker0` (+ `virbr0` on desktop). 2026-10-16
- [x] ThinkPad SSH keys-only (`/etc/ssh/sshd_config.d/10-keys-only.conf`); verified key works, password refused, LAN port 22 blocked. 2026-10-16
- [x] Desktop locks after 30 min idle. 2026-10-15
- [x] Waybar privacy: mic/screen-share (`privacy`, spektra ignored by name), camera (`desk-camera`). 2026-10-16
- [x] Waybar updates counter (`desk-updates`) + `arch-audit` on both (red when a package has a known vulnerability). 2026-10-16
- [ ] Arcturon Postgres (5432) + Redis (6379) bound to 0.0.0.0 via `scripts/init_db.sh` / `init_redis.sh`; Docker bypasses ufw → bind to 127.0.0.1 (check the data volume first). *Deferred by Viktor.*
- [ ] ThinkPad disk encryption (LUKS): only at a future reinstall.
- Rule learned: after a kernel update, reboot before touching firewall/network config.

## Look & feel (both machines)
Everything reads the `desk-theme` palette, so one switch restyles all of it.
- [x] `desk-theme`: 6 palettes, default **Rain-city noir**; Super+Shift+T picker; `/desk-theme` in Claude. 2026-10-16
- [x] Waybar `[TOP] Rain City` + `[Desk] Themed.css` (3 islands). Rollback: `~/.config/themes/waybar-rollback.sh`. 2026-10-16
- [x] Hyprland: amber→teal gradient border, soft shadow, gaps 4/10, snappy animations; window rule stops apps forcing maximize. 2026-10-16
- [x] kitty, rofi, swaync, hyprlock follow the theme. 2026-10-16
- [x] nvim: `colors/desk.lua` from the palette, open nvims recolor live, lualine from palette ("sooo crisp"). 2026-10-16
- [x] Chrome: generated theme (`~/.config/themes/current/chrome`, new-tab page = wallpaper) + Surfingkeys with nvim-style keys (`~/.config/themes/surfingkeys/maps.js`, Shift+J/K tabs). Super+B = Chrome. 2026-10-16
- [x] Claude Code: Desk theme, status line, spinner verbs, `rain-city` mod. 2026-10-16
- [x] Login (SDDM), boot splash (Plymouth) and GRUB in Rain-city on both machines. 2026-10-16
- [x] Wallpapers: 6 dark/orange 4K Rain-city images, wallpaper of the day (timer on), per-screen crops. 2026-10-16
- [x] GTK: dark Flat-Remix theme, icons, Bibata cursor synced; hidden files shown in dialogs + Thunar. 2026-10-16
- [ ] GTK + Qt colors from the palette (instead of Flat-Remix blue) so Thunar and dialogs match.
- [ ] Shell prompt (starship) + fastfetch + btop + cava themed.
- [ ] Apps: Spotify (spicetify), Discord (Vesktop), Obsidian, zathura.
- [ ] Sound design: small, consistent notification/plug/unplug sounds.
- [ ] Verify hyprlock look on first real lock.
- [ ] Optional: kitty font (Fantasque Bold now) → regular weight?
- Theme gallery: https://claude.ai/artifact/6u3wsKUpN79yTCxEAvrxxB

## ThinkPad
- [x] Everything above rolled out and verified with screenshots; files compared first, backups `*.bak-20261016-*`. 2026-10-16
- [ ] Thunar (see **Now**).
- [ ] Replace nm-applet + blueman with Watchtower's Wi-Fi and Bluetooth tabs; waybar icons open those tabs.
- [ ] ThinkPad-only uncommitted chezmoi changes (monitor profiles, waybar Modules/ModulesCustom, Brightness.sh, RefreshModeDaemon.py): review in the dotfiles clean-up.

## Dotfiles & sync
GitHub (`Vickeviking/arch-dotfiles`, chezmoi) now holds everything made on 2026-10-15/16, but still carries the old `.conf` Hyprland files and lacks parts of the live Lua config.
- [ ] Make GitHub the single source of truth: add the remaining live Lua config, retire stale `.conf` files (kept in git history).
- [ ] Per-machine differences via chezmoi templates on hostname (monitors, env/GPU, hyprlock, GRUB header, laptop modules).
- [ ] Workflow in the `arch-machine` skill: edit → `chezmoi add` → commit → (push with OK) → other machine `chezmoi diff` → `chezmoi update`.
- [ ] Big binaries (wallpapers, `~/.themes`, `~/.icons`, desk-art) stay out of git: one `desk-sync` script that rsyncs them.
- [ ] Commit Viktor's 3 pending nvim changes on the desktop (Viktor reviews).

## Watchtower (Super+Space hub)
**Vision:** a god view of the computer, beautiful and fast. Rust + GTK4 + gtk4-layer-shell (same stack as Arch-flywheel), colors from `desk-theme`, repo `~/dev/project/Watchtower`. Keyboard first: `j`/`k` tabs, `1`–`0` jump, `?` all keys, `/` search, `f` full size and back, `Esc` close.

Tabs:
- [ ] **Home**: fleet strip (each machine + the network, live), quick actions, tonight's events.
- [ ] **System**: CPU per core, RAM/swap, GPU, temps, disks, battery; history graphs.
- [ ] **Processes**: sortable list, tree view, end/renice with confirmation, per-process CPU/RAM/IO/network.
- [ ] **Galaxy**: live network topology, traffic as particle streams, new devices pulse red, replay the last hour.
- [ ] **Machines**: one-key SSH (themed kitty) to the ThinkPad, `gunnar` (Pi) and the rest; status via Tailscale + `watchtower-agent`.
- [ ] **Wi-Fi** and **Bluetooth**: connect, forget, pair, battery levels (NetworkManager / BlueZ D-Bus).
- [ ] **Manuals**: man pages, tldr, offline Arch wiki, Rust std docs.
- [ ] **Keybinds**: live cheat sheet from the Lua bind files.
- [ ] **Ask**: Claude or local Ollama, answers from dotfiles/man/wiki, must stay fast.

**Network Observatory** (ideas from Viktor + ChatGPT brainstorm, one event model shared by every mode):
- **Galaxy** (above) starts with Viktor's own fleet via `watchtower-agent` (Rust) over Tailscale.
- **Latency Autopsy**: gateway vs internet latency, loss/jitter, DNS vs connect time, bufferbloat.
- **Recon / Device Hunter**: router clients, DHCP, ARP/IPv6 neighbours; first/last seen; scans of own devices only.
- **Exposure**: open services, TLS health, plaintext protocols, router hygiene; findings with evidence + fix.
- **Radio**: nearby access points, channels, signal timelines, congestion.
- **Forensics**: packet autopsy (tshark), DNS analysis, TLS Lab on own sessions, Time Machine replay, Sankey.
- Build order: Galaxy → Latency Autopsy → Device Hunter → DNS Observatory → Sankey + Time Machine → Forensics.
- Stack: Galaxy as WebGL inside Watchtower (WebKitGTK) fed by the Rust collector; SQLite first. Privileged capture in a small, narrowly scoped service; the UI and Claude never get blanket root.
- Limits: HTTPS hides search terms, URLs and contents even from the router owner; no interception of other people's traffic.
- [ ] DNS on the Pi: AdGuard Home on `gunnar` (DNS Observatory + house-wide ad-block); keep it light, the Pi runs Arcturon production.
- [ ] Router: device list, traffic and logs; if supported, OpenWrt (per-device stats, SQM, WireGuard home VPN; Viktor flashes it).
- [ ] Talk with Li before anything shows per-device detail for her devices.
- 2026-10-16 Router is a **D-Link R15** (EAGLE PRO AI AX1500). Not in OpenWrt's hardware table as far as we can find, so no flashing: device discovery runs from `gunnar` (ARP/neighbours, AdGuard client list) and the router's own web UI.
- 2026-10-16 4th machine "mycomputer" is Viktor's **Windows Legion tower**. Machines tab shows it as a Windows box (ping/Tailscale if added later, no agent for now).

Phases:
- [x] 0. Mockup (published 2026-10-16); Viktor: "Sexiigt!!! älskar den!!!", Atlas proportions loved.
- [x] 1. Skeleton in `~/dev/project/Watchtower`: layer-shell overlay on the focused monitor, 10 tabs, live desk-theme colors, Super+Space toggle (resident, ~20 ms reopen), j/k 1–0 gg G f ? Esc, live Home cards, 8 tests. Committed (`ee69826`), on both machines. 2026-10-16
- [ ] 1b. Polish: regenerate tab art in the photo style; `ttf-ibm-plex` for the intended font; autostart with `exec-once` (Viktor decides).
- [ ] 2. System + Processes.
- [ ] 3. Wi-Fi + Bluetooth (unblocks the ThinkPad GUI swap).
- [ ] 4. Machines + `watchtower-agent` + Galaxy (own fleet).
- [ ] 5. Manuals + Keybinds + Ask.
- [ ] 6. Network Observatory modes, in the build order above.
- Art: app icon `~/Pictures/desk-art/watchtower-icon.png` (lone tower, orange light); 14 line-art tab illustrations in `~/Pictures/desk-art/watchtower-tabs/` [?] regenerate in the darker photo-render style.
- Decisions: Flywheel retired (repo stays); Super+H freed (old `hypr_sheet.py` retires).

## Quick ask (Super+A)
- [ ] Super+A anywhere: silent full-screen screenshot → small floating chat bottom-left with the screenshot attached.
- [ ] Answer via Claude (`claude -p` with the image; works on the ThinkPad) or local Ollama on the desktop.
- [ ] Use it to ask about and update dotfiles quickly.
- [?] Super+A today toggles the Quickshell overview: move the overview to another key?

## Backups
- [ ] restic, desktop ⇄ ThinkPad over Tailscale, nightly; `~/dev`, chezmoi source, `~/Documents`, `~/Pictures` (minus build dirs) + Arcturon `pg_dump`.
- [ ] Viktor sets the repo password + SSH keys and enables the `systemd --user` timers.
- [ ] Verify by restoring a file.

## Clean-up
- [ ] `comfyui` container still running although `/mnt/data/ai` models are gone → stop/remove (with OK).
- [ ] Old `hypr_sheet.py` (Super+H) once Watchtower covers it.
- [ ] Orphan packages, pacman cache, Docker images, old `.bak-*` files: inventory first, Viktor approves.
- [ ] Ollama models: keep only what Ask uses.

## Claude Code
- [x] Global profile `~/.claude/CLAUDE.md`, `arch-machine` skill, house rules ("Viktor is the captain"). 2026-10-15
- [x] Plugins pruned; connectors trimmed. 2026-10-15
- [x] `rain-city` mod (`desk-mods` marketplace) on both: status band, long-turn toast + chime, `/desk-theme`. 2026-10-16

## Image generation
- `desk-imagine "prompt" -o file.png [--size 3840x2160] [--transparent]` (OpenAI Images, `gpt-image-2.5-flare`, key in `~/.config/desk/image-api.env`, mode 600, ignored by chezmoi).
- Art direction (Viktor 2026-10-16): **dark, night, orange lights, crisp; photo + cinematic-render mix; not painted, not always rain; only Rain-city gets new art.**
- [ ] The first key was pasted in chat: revoke it at platform.openai.com once it's no longer needed.

## Arcturon (later)
- [ ] Bring the desk style to the app with the design/UX skills.
- [ ] Clean-up, refactoring, tests, scaling review, documentation.

## Inbox
- 2026-10-16 Viktor: "Galaxy" renamed **Atlas** (World globe with GeoIP arcs from Uppsala + Home network view); new tabs **Toolbox** (own-device scans, traceroute, DNS, TLS, capture, bufferbloat) and **Settings** (one place for Wi-Fi, Bluetooth, display, sound, look, keyboard, power, notifications, privacy, updates, startup). Mockup v3 has all of it.
- 2026-10-16 Away from home: gunnar is the always-home sensor; Watchtower reaches it over the tailnet.
- 2026-10-16 TV is a Samsung smart TV; Viktor: no need to control it. Dropped.

- 2026-10-16 Atlas with real data (Viktor's packet-radar brief): own machine first. Phase A without root: live connections from `ss`/conntrack + an offline GeoIP database (DB-IP lite) → arcs; per-connection bytes. Phase B: a small capture helper with only `cap_net_raw` (Viktor runs `setcap`) for packet metadata via libpcap; flow engine groups packets into connections. Click an arc → panel: IP, estimated country/city, protocol/port, packets/s, bytes, first/last seen, how sure the geolocation is. Timeline replay. Traceroute hops drawn as the route. Limits shown in the UI: GeoIP is approximate (CDNs, VPNs), HTTPS hides URLs and content, other devices' traffic only via gunnar/AdGuard (DNS) since the R15 can't mirror ports; talk with Li first.

## Decisions
- 2026-10-16 Desktop stays dual boot with Windows 11 (own disk, own ESP).
- 2026-10-15 Security: sensible, not paranoid; nothing that can lock Viktor out.
- 2026-10-16 Theme: Rain-city noir default; snappy & subtle animations; Chrome is the daily browser.
- 2026-10-16 Hub renamed Lantern → **Watchtower**. Rust + GTK4; Flywheel retired; Super+H freed; Wi-Fi/Bluetooth as hub tabs; Ask kept if it stays fast; `j`/`k` and `?` are musts.
