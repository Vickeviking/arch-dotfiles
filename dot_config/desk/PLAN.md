# Desk plan

Viktor's master plan for both machines (desktop `legion-arch` + ThinkPad), the Watchtower hub, and later Arcturon.

**How this file works**
- One section per area. When Viktor mentions a new idea, Claude appends it to the matching section (or **Inbox** if it fits nowhere yet) and dates it.
- Status: `[ ]` todo · `[~]` in progress · `[x]` done · `[?]` needs a decision from Viktor.
- **Now** is the only ordered list; everything else is a backlog grouped by area.
- Synced to both machines through chezmoi (`~/.config/desk/PLAN.md`).

---

## Now (in order)

1. [x] ThinkPad SSH works again (it was mid-update). 2026-10-16
2. [ ] Desktop finishing touches (Viktor): `/theme` → *Desk · Rain-city noir*, paste `statusLine` + `spinnerVerbs` into `~/.claude/settings.json`, `sudo pacman -S arch-audit`.
3. [x] Dotfiles pushed and styling rolled out to the ThinkPad. 2026-10-16
4. [ ] Watchtower: design mockup (artifact) → Viktor approves → phase 1.
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
- [x] Styling rolled out 2026-10-16: desk-theme + palettes, Rain City waybar, Hyprland Lua (border, animations, keybinds), hyprlock, kitty, rofi, swaync, wallpapers + art (rsync), `desk-mods` + `rain-city` plugin. Every file compared first; backups `*.bak-20261016-*`; waybar rollback `~/.config/themes/waybar-rollback.sh`. `hyprctl configerrors` clean, screenshot verified.
- [x] waybar privacy no longer flags spektra's speaker capture as the mic (both machines). 2026-10-16
- [ ] Viktor (root): `sudo pacman -S imagemagick arch-audit`; SDDM + Plymouth + GRUB theme like the desktop (initramfs uses the `systemd` hook; GRUB cmdline already `loglevel=3 quiet`); GRUB theme header already says `vango-arch-thinkpad`, GFXMODE 1920x1080.
- [x] Viktor: `/theme` → Desk, statusLine + spinnerVerbs, wallpaper timer (both machines). 2026-10-16
- [x] GTK synced 2026-10-16: `~/.themes` + `~/.icons` (Flat-Remix GTK/icons, Bibata cursor; manual installs, not packages) rsynced; `gtk-3.0/settings.ini` + window rules (no forced maximize) in chezmoi; hidden files shown in GTK3/GTK4 dialogs and Thunar on both; ThinkPad dialog size 1100×650.
- [ ] ThinkPad has no file manager: Viktor runs `sudo pacman -S thunar gvfs tumbler thunar-archive-plugin thunar-volman ffmpegthumbnailer xarchiver` (settings already placed).
- [ ] GTK colors from the desk palette (instead of Flat-Remix blue) so dialogs/Thunar match the theme.
- [ ] ThinkPad-only uncommitted chezmoi changes (monitor profiles, waybar Modules/ModulesCustom, Brightness.sh, RefreshModeDaemon.py): review + commit in the dotfiles clean-up.
- [ ] Replace nm-applet + blueman with Watchtower's Wi-Fi and Bluetooth tabs; waybar icons open those tabs.
- [ ] Install the `desk-mods` marketplace + `rain-city` plugin.

## Dotfiles & sync
Today GitHub (`Vickeviking/arch-dotfiles`, chezmoi), the desktop and the ThinkPad are three different versions: the repo still holds the old `.conf` Hyprland files and none of the Lua config; the desktop has 48 files differing from the repo.
- [ ] Make GitHub the single source of truth: add the live Lua config + today's files, retire the stale `.conf` files (kept in git history).
- [ ] Per-machine differences via chezmoi templates on hostname (monitors, keybinds, hyprlock, laptop-only modules).
- [ ] Workflow written into the `arch-machine` skill: edit → `chezmoi add` → commit → (push with OK) → other machine `chezmoi diff` → `chezmoi update`.
- [ ] Commit the 3 pending nvim changes on the desktop (Viktor reviews).

## Watchtower (Super+Space hub)
**Vision:** a god view of the computer, beautiful and fast. Rust + GTK4 + gtk4-layer-shell (same stack as Arch-flywheel), colors from `desk-theme`, repo `~/dev/project/Watchtower`.

Tabs:
- [ ] **Home**: launcher + quick actions (what Flywheel did), at-a-glance machine health.
- [ ] **Machines** (Viktor 2026-10-16): one-key SSH into the ThinkPad and the Raspberry Pi (`gunnar`) and the other machines, opening a themed kitty; show each node's status (online via Tailscale, CPU/temp from `watchtower-agent`).
- [ ] **System**: CPU per core, RAM/swap, GPU, temps, disks, battery, uptime; history graphs.
- [ ] **Processes**: sortable list, tree view, kill/renice (with confirmation), per-process CPU/RAM/IO/network.
- [ ] **Network → Per-app traffic**: which program talks to which host, bandwidth, GeoIP country.
- [ ] **Network → Home map**: devices on the LAN, new-device alerts, open ports on your own devices.
- [ ] **Network → Packet inspector**: live capture + protocol decode of own traffic (tshark engine; one-time root setup by Viktor: `wireshark` group / capabilities).
- [ ] **Network → Wi-Fi radio**: nearby networks, channels, signal over time, interference.
- [ ] **Network Observatory** (2026-10-16, ideas from Viktor + ChatGPT brainstorm). One event model shared by every mode:
  - **Galaxy**: live topology, devices as nodes, traffic as particle flows (thicker = more bandwidth), latency spikes ripple, new devices materialize as unknown nodes, scrub/replay history. Starts with **Viktor's own fleet** via a `watchtower-agent` (Rust) on desktop, ThinkPad, Pi (`gunnar`) and the 4th machine over Tailscale: per-process traffic, inter-node latency, CPU/temps.
  - **Recon / Device Hunter**: inventory from router clients, DHCP, ARP/IPv6 neighbours; first/last seen, IP/MAC changes; scoped scans of own devices only.
  - **Exposure**: open services, TLS health, plaintext protocols, Wi-Fi security, router hygiene; each finding with evidence, confidence, severity, fix.
  - **Radio**: nearby access points, channels, signal timelines, channel congestion, BLE (monitor mode only with suitable hardware).
  - **Forensics**: packet autopsy (tshark), DNS analysis, TLS Lab on own test sessions, Time Machine replay, Sankey (device → protocol → destination).
  - **Latency Autopsy**: gateway vs internet latency, loss/jitter, DNS vs connect time, bufferbloat (idle vs loaded).
  - Build order: Galaxy (own fleet) → Latency Autopsy → Device Hunter → DNS Observatory → Sankey + Time Machine → Forensics/TLS Lab.
  - Stack: Watchtower native (Rust/GTK) + Galaxy as WebGL inside Watchtower (WebKitGTK), fed by the Rust collector; SQLite first, Postgres/Timescale if history outgrows it. Privileged capture lives in a small, narrowly scoped service; the UI and Claude never get blanket root.
  - Limits: HTTPS hides search terms, URLs and contents even from the router owner; no interception of other people's encrypted traffic.
  - [?] What is the 4th machine ("mycomputer")?
- [ ] **DNS on the Pi**: AdGuard Home on `gunnar` for the DNS Observatory + house-wide ad-block; keep it light, the Pi runs Arcturon production.
- [ ] **Network → Router** (Viktor has the admin password, 2026-10-16): device list, traffic and logs from the router itself; feed Watchtower's Home map. If the model supports OpenWrt: per-device stats, house-wide ad-block, SQM, WireGuard home VPN (Viktor flashes it himself).
- [?] Router brand + model? (sticker underneath)
- [ ] Talk with Li before anything shows per-device detail for her devices.
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
- [ ] Old `hypr_sheet.py` (Super+H) once Watchtower covers it.
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
- 2026-10-16 **Image generation**: `desk-imagine "prompt" -o file.png` (OpenAI Images, key in `~/.config/desk/image-api.env`, mode 600, ignored by chezmoi). Key expires 2026-10-17; ~$3.50 credit. Revoke it at platform.openai.com when done (it was pasted in chat).
  - [x] Wallpapers for neon-rain, tokyo-night, rose-pine-moon, gruvbox-warm + Watchtower icon in `~/Pictures/wallpapers/desk/`. 2026-10-16
  - [x] Art direction (Viktor 2026-10-16): **dark, night, orange lights, crisp high quality; photo + cinematic-render mix; not painted, not always rain; only Rain-city gets new art.** Model `gpt-image-2.5-flare` at 3840×2160 (pixel cap), cropped per screen, never stretched.
  - [x] Rain-city set v2 (6): alley photo, street render, rooftop photo, platform render, desk photo, harbor render. Painted v1 set trashed. 2026-10-16
  - [x] `desk-wallpaper` crops per monitor aspect (laptop 16:10 → 3456×2160, 4K → 3840×2160), cached in `~/.cache/desk-wallpaper`. 2026-10-16
  - [x] Login screen v2: SDDM theme `rain-city` (copy of simple_sddm_2) in `~/.local/share/desk-art/sddm/rain-city`: dark city image, JetBrains Mono, cream clock, orange date/accents, no teal blur. Viktor: "That's better!!" 2026-10-16
  - [x] SDDM theme, Plymouth (hook + theme) and GRUB theme installed by Viktor on both machines. 2026-10-16
  - [?] GRUB lists every firmware entry ("EFI BootNext"): `GRUB_DISABLE_BOOTNEXT=true`, plus os-prober for a single Windows entry if Windows is still used.
  - [x] nvim follows desk-theme (`colors/desk.lua`, live recolor, lualine from palette). Viktor: "sooo crisp". 2026-10-16
  - [x] Boot splash: Plymouth theme `rain-city` in `~/.local/share/desk-art/plymouth/rain-city` (lantern, breathing amber glow, thin progress line). 2026-10-16
  - [ ] Viktor installs Plymouth + theme, adds `quiet splash` to GRUB (boot is via GRUB, `GRUB_CMDLINE_LINUX_DEFAULT` currently unset).
  - [x] GRUB theme `rain-city` in `~/.local/share/desk-art/grub/rain-city` (dark city, orange band of light, JetBrains Mono, amber selection bar, thin countdown line). 2026-10-16
  - [ ] Viktor installs GRUB theme together with `quiet splash` (one `grub-mkconfig` run). Header text says `legion-arch`: the ThinkPad copy needs its own hostname.
  - [x] 14 Watchtower tab illustrations (line-art, amber/teal) in `~/Pictures/desk-art/watchtower-tabs/`. 2026-10-16
  - [?] Regenerate the tab illustrations in the new darker, high-quality style?
  - [ ] `~/.local/share/desk-art` + wallpapers go to the ThinkPad via rsync (too big for git).
  - [x] `desk-wallpaper`: wallpaper of the day from the active theme's folder (same all day, never yesterday's; `--next` for another); `desk-theme` brings the theme's wallpaper along. 2026-10-16
  - [ ] Viktor enables the daily change: `systemctl --user enable --now desk-wallpaper.timer` (06:00 + 30 s after login).
  - [ ] Wallpapers to the ThinkPad via rsync (kept out of git, ~30 MB).
  - [ ] More wallpapers for the other themes (1 each today) while credit lasts.
  - [ ] New Watchtower app icon (the current `desk-art/lantern-icon.png` is a lantern) in the dark/orange photo-render style.
  - [ ] Wallpapers are 1536×1024: upscale for the 4K monitor or regenerate larger if they look soft.
  - [ ] Still to make while the credit lasts: SDDM/plymouth art, Watchtower tab illustrations.

## Decisions
- 2026-10-15 Security: sensible, not paranoid; nothing that can lock Viktor out.
- 2026-10-16 Theme: Rain-city noir default; snappy & subtle animations.
- 2026-10-16 Hub renamed Lantern → **Watchtower** (Viktor). Rust + GTK4; Flywheel retired; Super+H freed; Wi-Fi/Bluetooth as hub tabs; Ask kept if it stays fast.
