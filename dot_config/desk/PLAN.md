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

1. [~] **Watchtower**: all ten tabs live on both machines (2026-10-16) → nvim-style focus model (Viktor, below) → `watchtower-agent` + Settings Privacy/Startup.
2. [x] (2026-10-18) ThinkPad: Viktor installs Thunar (`sudo pacman -S thunar gvfs tumbler thunar-archive-plugin thunar-volman ffmpegthumbnailer xarchiver`).
3. [x] GRUB clutter (desktop, dual boot, Windows stays): `GRUB_DISABLE_BOOTNEXT=true` removed the PXE/duplicate BootNext entries, `11_windows` stays; plus `resume=` and the `resume` hook so hibernation can wake. Done by Viktor 2026-10-16.
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
- [x] GTK + Qt colors from the palette: desk-theme generates adw-gtk3 gtk.css (GTK 3+4), qt5ct/qt6ct palette (Fusion) and accent folder icons (Desk icon theme). 2026-10-18
- [~] starship config generated + .zshrc switches to it once installed (`sudo pacman -S starship`); btop + cava themed from desk-theme; fastfetch follows kitty's ANSI colors. 2026-10-18
- [~] Apps: zathura themed (needs `zathura-pdf-mupdf` to open PDFs); Spotify: spicetify 2.45.3 in ~/.spicetify on both, Desk theme applied on the ThinkPad, desktop applies with `~/.spicetify/spicetify backup apply` (restarts Spotify; after Spotify updates run it again); desk-theme runs `spicetify refresh -n` on switches. Discord: Vesktop theme + enabledThemes pre-placed (needs `yay -S vesktop-bin`); Obsidian snippet at ~/.config/themes/current/obsidian.css (vault path in obsidian.json no longer exists). 2026-10-18
- [x] Sound design: desk sound theme (~/.local/share/sounds/desk, make-sounds.py), desk-sound (quiet in DND, `touch ~/.config/desk/sounds-off` mutes), swaync notification sound, desk-plug-sounds.service (USB + charger), Sounds.sh on desk. 2026-10-18
- [ ] Verify hyprlock look on first real lock.
- [ ] Optional: kitty font (Fantasque Bold now) → regular weight?
- Theme gallery: https://claude.ai/artifact/6u3wsKUpN79yTCxEAvrxxB

## ThinkPad
- [x] Everything above rolled out and verified with screenshots; files compared first, backups `*.bak-20261016-*`. 2026-10-16
- [x] Thunar (see **Now**). 2026-10-18
- [~] waybar Wi-Fi/Bluetooth left-click → `watchtower --tab settings` (right-click keeps nmtui/blueman). nm-applet stays: it's NetworkManager's password agent (eduroam). 2026-10-18
- [ ] ThinkPad-only uncommitted chezmoi changes (monitor profiles, waybar Modules/ModulesCustom, Brightness.sh, RefreshModeDaemon.py): review in the dotfiles clean-up.

## Dotfiles & sync
GitHub (`Vickeviking/arch-dotfiles`, chezmoi) now holds everything made on 2026-10-15/16, but still carries the old `.conf` Hyprland files and lacks parts of the live Lua config.
- [ ] Make GitHub the single source of truth: add the remaining live Lua config, retire stale `.conf` files (kept in git history).
- [~] Per-machine differences via chezmoi templates on hostname: the 9 files that differ (monitors.conf, Monitor_Profiles/*, Weather.sh, RefreshModeDaemon.py, Brightness.sh, waybar Modules/ModulesCustom/[TOP] Default Laptop) are listed in ~/.cache/desk-dl/tmplfiles.txt; build the templates when the ThinkPad is online (it went offline mid-way 2026-10-18).
- [x] Workflow in the `arch-machine` skill, plus desk-theme generation, hostname templates and desk-sync. 2026-10-18
- [x] `desk-sync` (desktop → ThinkPad, newer files only, never deletes; `-n` dry run). 2026-10-18
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
- [x] 2. System + Processes (collector thread, never wakes a sleeping NVIDIA GPU, 0.15 % CPU while hidden). 2026-10-16
- [x] 3. Settings: Wi-Fi, Bluetooth, sound, displays, brightness, theme, DND, keyboard, power, updates, Privacy, Startup. [x] Privacy and Startup sections (2026-10-16). [ ] Waybar Wi-Fi/Bluetooth clicks → `watchtower --tab settings`, then drop nm-applet + blueman on the ThinkPad. 2026-10-16
- [~] 4. Machines (tailnet + ping + SSH) and Atlas (live `ss` connections on a cairo globe, offline DB-IP lite in `~/.local/share/watchtower/`, physics check flags CDN/anycast, `t` tracepath route) done. [ ] `watchtower-agent` for per-machine detail. [x] GeoIP refresh is one key in Settings → Atlas (do it monthly). 2026-10-16
- [x] 5. Manuals (man + offline Arch wiki + std search, Rust/embedded/Linux shelf, man page of the day, `r` random), Keybinds (live from hyprctl), Ask (Claude Haiku read-only or local Ollama; ThinkPad has no Ollama), Toolbox (listening ports, own-machine port check, latency, DNS, TLS). 2026-10-16
- [ ] 6. Network Observatory modes, in the build order above.
- [x] 7. **Apps** tab (`a`, after Ask): own games (council, comedian, republic, Byn, Me via `dumb tui <game>`) + Spektra + Li's voice, generated icons in `~/Pictures/desk-art/apps/`; per-machine status (ThinkPad: games need dumb-games + Ollama). **Settings → Spektra** (on/off, scene, hype, colors, screens, borders, screensaver); Spektra removed from waybar on both machines (`*.bak-20261016-spektra`). Both machines run the same binary. 2026-10-16. [x] Committed (Watchtower `b7be3cd`, dumb-games `e86a59f`, chezmoi `f4c35fc`; not pushed). dumb-games copied to the ThinkPad: Byn and the read-only views run there; the four Ollama games show dimmed as "needs Ollama (desktop only)" and won't start. Byn paused 2026-10-17 (Viktor): `by stopp` + autostart disabled for `byn@lis`, `byn@ren`, `byn-webb`; wake with `by start` + `systemctl --user enable byn@lis byn@ren`. [ ] Maybe a pause/wake key on the Byn tile.
- [~] 8. **Genomlysning** → now the Rust X-ray debugger (Viktor 2026-10-17). Plan: `~/.claude/plans/love-the-in-composed-cat.md`, effort 20/20/60:
  - [x] Phase 1, nvim (20 %), 2026-10-17: Deck on Space r (follows the buffer's language: Rust, C/C++, Python, TypeScript/Vue, Go, Java, SQL, Lua; Keys tab generated live) · Space ? · which-key helix + groups · debugger on Space d (nvim-dap + dap-view + codelldb) · RustOwl (Space Ro) · blink.cmp (same keys, codeium modes kept) · lazydev · lua_ls + gopls enabled · Rust keys on Space R · PDFs → zathura, videos → default app · startup 40 → 37 ms. Both machines' configs merged and identical; chezmoi source caught up (`61597e8`).
    - [x] (2026-10-18, synced) ThinkPad was asleep for the last sync: `chezmoi update` (safe, no local edits) → `nvim --headless "+Lazy! restore" "+Lazy! clean" +qa` → `nvim --headless "+MasonInstall lua-language-server gopls" +qa`; zathura is not installed there (PDFs fall back to xdg-open).
    - [x] (upgraded to v9.2.1 2026-10-18, live debug checked) rustaceanvim prints a deprecation warning on nvim 0.12; fixed only in v7+ (latest v9.2.1), config pins ^6. Upgrade?
  - [x] Phase 2, Rust lens (20 %), 2026-10-17: K = hover with size/align, K K = lens (Overview · Layout byte strips + "Inside" tree · Methods by receiver · Traits + derives · Calls · Tests; Enter jumps; `r` records generic instantiations). `lens-sizes` CLI (~/.cargo/bin) writes target/lens/sizes.json, refreshed on save once used. Root fix: rustaceanvim now uses rustup's rust-analyzer (mason's couldn't compute layouts at all). genomlysning repo, branch `lens` (7b452aa; no main yet).
    - [x] (2026-10-18, pushed and synced) Push chezmoi `29c26c6` (waiting for Viktor's OK); ThinkPad sync then also needs `rustup component add rust-analyzer` there if missing.
    - [ ] Later polish: kitty-image layout rendering via snacks.image; Send/Sync/Unpin in Traits.
  - [~] Phase 3, X-ray (60 %): repo `~/dev/project/genomlysning`. [x] Spike: codelldb gives addresses for every variable + readMemory (see `spike/FINDINGS.md`) → default adapter. [x] proxy: `xray-dap` (~/.cargo/bin) sits between nvim-dap and codelldb, snapshot per stop in $XDG_RUNTIME_DIR/xray/ (latest.json + session history); nvim uses it for every Rust debug session; branch `xray`. Note: codelldb 1.12.1 prints a harmless traceback at start (Rust 1.99 dropped `lldb_commands`; formatters still load). [x] model + std lenses (2026-10-17): `xray-model` turns each stop into a graph (stack slots, heap blocks, owns/shares/weak/borrows/borrows-mut edges; Vec/String/Box/Rc/Arc/Weak/RefCell/Mutex/HashMap/Option/slices; diffs: changed values, new/freed blocks, Vec realloc, moved-from); `fixtures/zoo` recorded with `xray-probe`, scene tests + golden text; `xray-show` prints graphs. [x] Mode A inline (2026-10-17): notes on every `let` line + `Space dx` panel (memory map with arrows, frames of all threads, heap, changes with explanations); deck Debugger tab updated; chezmoi pushed 2026-10-17 (Viktor's OK); one more local commit (rust-analyzer by path, lens fixes) waits for an OK. ThinkPad: nvim config rsynced (backup ~/.config/nvim.bak-20261017-204458.tgz), plugins restored, xray-dap/lens-sizes/xray-show/RustOwl installed; its chezmoi repo is behind 4 with uncommitted hypr/waybar edits (Viktor sorts those); needs `sudo pacman -S --needed zathura zathura-pdf-mupdf go`. Tour of every feature: ~/dev/project/rust-stuff/nvim-tour (one file per feature). [x] "Why not?" (Space Rw, 2026-10-17): borrow errors as timelines from rustc labels, curated rules for 8 codes, rustc --explain, fixes on `a`; fixtures/whynot. [~] timeline: `[ ]` steps through a session's stops in the X-ray panel. Showcase: https://claude.ai/artifact/VMZL2avvoLeojWm9pFEMcz [x] crates (2026-10-17): lenses for tokio (tasks + what they await), parking_lot, crossbeam-epoch, serde_json, ron, anyhow, tracing, http/hyper/reqwest/url/bytes, axum, sqlx, rayon, rand, uuid, chrono; generic tidy for any crate; ~/.config/xray/lenses.toml for your own; concurrent-hashmap guest (fixtures/chm-guest) mid-resize. [x] things show themselves: statusline key hints, automatic Why not?, X-ray sidebar (Space dm), Space dX off per nvim. [x] GTK window (xray-window, Space dW, auto on a 2nd monitor). [x] 2026-10-18: **Ask** in nvim (Space aq / Space ae, Claude Haiku via the claude CLI, no tools) · **Space cr** runs a file in any language · every language: inlay hints + Space ci, bordered K, hints, bashls/taplo/dockerls, shfmt/taplo/gofmt · lens fixes (right type inside macros, type docs, "In the debugger" note, rustc layout for src/bin) · tour t15–t18 + `languages/` · artifact https://claude.ai/artifact/W79q659RQrazufs1AGibJ2 · ThinkPad synced (chezmoi ff + apply nvim/xray, genomlysning ff, tour, tools, 32/32 tests). [x] JDK 25 installed on both; jdtls attaches (2 s desktop, 4 s ThinkPad). [ ] ThinkPad has no `claude` CLI, so Ask there needs Viktor to install + log in. [x] genomlysning `xray` merged into main on both machines (ca75f07). 2026-10-18 [ ] smol/async-std. [x] 2026-10-18 **C, C++ and Python debugging on the same keys** (Viktor asked: "c/c++ as I can for Rust"): C/C++ go through xray-dap too (nvim adapter `xray-codelldb`; Space dd = build this file -g -O0 / pick a binary / with args), Python via debugpy (mason) + nvim-dap-python. X-ray for C/C++: `Lang` in snapshot/graph (left out for Rust, so Rust JSON is byte-identical), clang.rs lenses (pointers point, NULL is a value, char* → bytes/literal, malloc block read as array via glibc header, std::vector/string(SSO)/unique_ptr/shared_ptr/weak_ptr/map-set nodes, `T &` refers), C/C++ decls by treesitter; fixtures/c-zoo + 11 tests. Rust verified unchanged: recorded graphs + live probe + nvim render identical. Committed, pushed and on both machines (genomlysning main 16f527d; ThinkPad codelldb pinned to 1.12.1, 1.12.3 segfaults on vector<unique_ptr>). hypridle + gitconfig are now hostname templates; 01-UserDefaults.conf restored on the desktop (hypr scripts read it). [ ] C dangling-pointer detection (free() but pointer kept). [ ] arrays of structs from malloc. Known limit: a moved Box looks like a borrow of the new owner (both point at one block).
  - Earlier proposal: https://claude.ai/artifact/QQVyGCG3ie6s2gz6RceQDw
- Note: an untracked `crates/wt` (network toolkit start) sits in the Watchtower repo from a parallel run; Viktor decides keep or trash.
- Art: app icon `~/Pictures/desk-art/watchtower-icon.png` (lone tower, orange light); 14 line-art tab illustrations in `~/Pictures/desk-art/watchtower-tabs/` [?] regenerate in the darker photo-render style.
- Decisions: Flywheel retired (repo stays); Super+H freed (old `hypr_sheet.py` retires).

## Quick ask (Super+A)
- [x] Super+A anywhere: silent full-screen screenshot → small floating chat bottom-left with the screenshot attached. 2026-10-18
- [x] Answer via Claude (`claude -p` Haiku, Read/Grep/Glob only). 2026-10-18
- [x] Use it to ask about dotfiles: it reads ~/.config and shows edits, never makes them. 2026-10-18
- [x] Super+A = Quick ask (~/.local/bin/quick-ask: screenshot + nvim Ask, floating bottom-left, read-only ~/.config); overview moved to Super+O. 2026-10-18

## Backups
- [x] (live 2026-10-18: first snapshot 20.8 GiB, test restore identical, `restic check` clean, desk-backup.timer nightly ~03:30) restic, desktop ⇄ ThinkPad over Tailscale, nightly; `~/dev`, chezmoi source, `~/Documents`, `~/Pictures` (minus build dirs) + Arcturon `pg_dump`.
- [x] Password made with `desk-backup-password` (spare copy on gunnar: ~/.config/desk-backup/password-legion-arch); timer enabled. 2026-10-18
- [x] Verified by restoring a file. 2026-10-18

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
- [x] (revoked 2026-10-18) The first key was pasted in chat: revoke it at platform.openai.com once it's no longer needed.
- [x] (revoked 2026-10-18) 2026-10-16 A second key was pasted in chat and now sits in `image-api.env` (old file kept as `image-api.env.bak-20261016`): revoke both once done with image generation.
- [ ] 2026-10-18 A third key (1-day, Viktor's choice) was pasted in chat for the desk-cat sprites; it sits in ~/.config/desk/image-api.env (600). Revoke it at platform.openai.com when done, or let it expire.

## Arcturon (later)
- [ ] Bring the desk style to the app with the design/UX skills.
- [ ] Clean-up, refactoring, tests, scaling review, documentation.

## Inbox

- 2026-10-18 **Locked in (Viktor): 4 → 3 → 2 → 1**
  - [-] 4. Tools: dropped (Viktor doesn't need them, 2026-10-18); the wiring was reverted.
  - [~] 3. Session restore: `desk-session` (save every 2 min via desk-session-save.timer, restore at login from user_startup.lua; terminals in their folder, floating windows at their spot, apps on their workspace, nothing re-run; `desk-session show/off/on`). Desktop done + tested with a fake snapshot; [ ] real reboot test. ThinkPad done (startup line + timer).
  - [x] 2. Sam (ThinkPad synced 2026-10-18): Quickshell overlay ~/.config/desk-sam/shell.qml (frames from generated sheets, ~/Pictures/desk-art/cat/anim, slice.py SIT_PX 136), lives upper right, walks in from the right; sleeps during pomodoro focus (no wandering/pounce/sound, play refused), stretches + purrs when focus ends; click purr, hover pounce, idle 3 min → sleep; feed/ball/yarn/treat via waybar 🐈 menu (desk-sam). Off = process stopped, remembered (~/.config/desk/sam-off). Autostart in user_startup.lua. [x] play mode works (Viktor).
  - [x] 1. Visualizer (genomlysning branch `lab`): [x] labsync crate (std::sync/thread look-alikes recording locks + atomics with their line; `labsync::explore` = shuttle schedules, first failure saved, LABSYNC_SEED replays) · [x] lab-view = Lockscope (HTML timeline: thread lanes, lock rows + queue, atomic values, cursor panel, stats, step player, deadlock cycle) · [x] examples sum / hand_over_hand / racy_counter / deadlock · [x] nvim Space ds, deck Concurrency tab, tour t19 (runnable) · both machines. [x] Structure movie: xray-movie (Space dM), chains/trees/columns, per-node changes in words, tested live; tour t20; xray-window heap columns fit small screens. [x] movie merged into main on both machines (2026-10-18). [x] `lab` merged into main on both machines (2026-10-18).

- 2026-10-18 Desk cat concept (pixel sprites from Viktor's photos in ~/Pictures/desk-art/cat/): https://claude.ai/artifact/4VCD5QPa7H6JDxzsmKQqSB · ten Rust visualization ideas in the same page · Viktor wants Mac-style session restore (windows back in place, terminals in their folders, no processes restarted).

- 2026-10-18 [x] Arcturon English TTS sidecar back up: ~/dev/tts-lab had vanished, so arcturon-tts-en.service failed every 10 s. Rebuilt the venv with uv (Python 3.12, torch 2.11 cu128 for the RTX 5070 Ti, kokoro, espeakng-loader, phonemizer, fastapi, uvicorn, soundfile) + the spaCy model `en_core_web_sm` 3.8.0 (misaki fetches it with pip, which uv venvs lack). Checked: synthesis faithful, warm 4.45 s audio in 0.05 s, gunnar (prod) sees /health. [ ] Arcturon: a requirements file for services/tts so the venv can be rebuilt in one step.

- 2026-10-18 [x] Pomodoro in waybar on both machines (desk-pomodoro, after the clock): 25/5, long break 15 after every 4th round; pling (rings even in DND) + notification at each end; click start/pause, middle skip, right reset, scroll focus length, Super+Shift+P. Viktor asked for it to study while the big projects wait.

- 2026-10-18 Clean-up inventory, waiting for Viktor (nothing removed yet): pacman cache `sudo paccache -rk2` (~57.6 GB) · journal `sudo journalctl --vacuum-size=500M` (~3.4 GB) · Trash 30 GB (`gio trash --empty`) · 11 orphan *-debug packages `sudo pacman -Rns $(pacman -Qdtq | grep -- -debug$)` (keep go/cmake/meson/libmupdf: used) · Docker: `local-ai/comfyui` image 7.86 GB (container already gone), 104 anonymous unused volumes 8.1 GB (`docker volume prune`) · ~~`~/.config/nvim.bak-20250904` 1.6 GB~~ (trashed 2026-10-18).
- 2026-10-18 Installs for Viktor (both machines): `sudo pacman -S --needed starship zathura-pdf-mupdf restic`; optional AUR: spicetify-cli (+ `sudo chmod a+wr /opt/spotify /opt/spotify/Apps -R`), vesktop-bin.
- 2026-10-16 Fixed: `~/.local/bin/dumb` pointed at the old `~/dev/dumb-games`; spektra had no release build (rebuilt). Still stale: PATH entry `~/dev/rost-kloning/bin` (repo is in `~/dev/project/`), so `li` doesn't resolve from the shell.
- 2026-10-16 Viktor: "Galaxy" renamed **Atlas** (World globe with GeoIP arcs from Uppsala + Home network view); new tabs **Toolbox** (own-device scans, traceroute, DNS, TLS, capture, bufferbloat) and **Settings** (one place for Wi-Fi, Bluetooth, display, sound, look, keyboard, power, notifications, privacy, updates, startup). Mockup v3 has all of it.
- 2026-10-16 Away from home: gunnar is the always-home sensor; Watchtower reaches it over the tailnet.
- 2026-10-16 TV is a Samsung smart TV; Viktor: no need to control it. Dropped.

- 2026-10-16 Atlas with real data (Viktor's packet-radar brief): own machine first. Phase A without root: live connections from `ss`/conntrack + an offline GeoIP database (DB-IP lite) → arcs; per-connection bytes. Phase B: a small capture helper with only `cap_net_raw` (Viktor runs `setcap`) for packet metadata via libpcap; flow engine groups packets into connections. Click an arc → panel: IP, estimated country/city, protocol/port, packets/s, bytes, first/last seen, how sure the geolocation is. Timeline replay. Traceroute hops drawn as the route. Limits shown in the UI: GeoIP is approximate (CDNs, VPNs), HTTPS hides URLs and content, other devices' traffic only via gunnar/AdGuard (DNS) since the R15 can't mirror ports; talk with Li first.

- 2026-10-16 Done: nvim-style navigation, OnDemand keyboard (no lock-out), machine detail views over SSH, compact ThinkPad layout. Open: ThinkPad's SSH key isn't on gunnar (Viktor: `ssh-copy-id vango@gunnar` from the ThinkPad if wanted); the desktop has no sshd, so the ThinkPad can't read it (backups plan covers that).
- 2026-10-16 Viktor: Watchtower navigation like nvim windows. Ctrl+h / Ctrl+l move between the menu and the view. In the menu j/k change tab; in the view j/k scroll AND step through every clickable thing (cards, rows, buttons), Enter clicks it. Same keys everywhere.

- 2026-10-16 Health check: desktop can free ~280 GB (Arcturon cargo-target 186 GB + worktrees 40 GB, pacman cache 58 GB reclaimable, Spotify cache 22 GB, journal 3.9 GB, 46 orphans). Watchtower System → Housekeeping shows it live. Broken: `planner-watcher` (~/planner gone), `school-sync` (SEPM repo on detached commit 6b61b4e). Fixed: ThinkPad desk-wallpaper boot race. Viktor: "lägg till 1 och 5, synca, sen är vi nöjda" → done. Clean-up done 2026-10-16: Spotify/huggingface/torch caches + Flywheel target trashed (30 GB, freed when Viktor empties trash), comfyui container removed, planner-watcher timer disabled, SEPM repo back on main. Viktor runs: paccache, journal vacuum, orphans, Arcturon `cargo clean`, `gio trash --empty`.

## Decisions
- 2026-10-16 Desktop stays dual boot with Windows 11 (own disk, own ESP).
- 2026-10-15 Security: sensible, not paranoid; nothing that can lock Viktor out.
- 2026-10-16 Theme: Rain-city noir default; snappy & subtle animations; Chrome is the daily browser.
- 2026-10-16 Hub renamed Lantern → **Watchtower**. Rust + GTK4; Flywheel retired; Super+H freed; Wi-Fi/Bluetooth as hub tabs; Ask kept if it stays fast; `j`/`k` and `?` are musts.

- 2026-10-17 Viktor's idea: a cooler Shift+K for Rust in nvim that draws the memory layout like cheats.rs (plus a debugger/wrapper). Five-way proposal "Next five": https://claude.ai/artifact/PWCw5Q4gie1iNwz3ChqLPg (Layout lens · X-ray debugger · nvim 0.12 tune-up · Embedded bench · Local AI refresh). Viktor picked: nvim → lens → X-ray (see Watchtower phase 8).
