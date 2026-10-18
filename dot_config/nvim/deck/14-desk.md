# The desk (outside nvim)

## Keys anywhere

| Keys | Does |
| ---- | ---- |
| `Super A` | **Quick ask**: Claude sees your screen and can read `~/.config` (never changes it). `Super A` or `Esc Esc` closes |
| `Super O` | desktop overview (all workspaces) |
| `Super Shift P` | pomodoro start / pause |
| `Super Shift T` | pick a theme: every app recolors at once |
| `Super Return` | terminal · `Super D` app launcher · `Super E` files · `Super B` Chrome |

## Waybar, middle

| Click | Does |
| ---- | ---- |
| `󱎫 25` pomodoro | left: start / pause · middle: skip · right: reset · scroll: focus length. 25 min focus, 5 min break, 15 after every 4th. A pling at each end, even in Do Not Disturb |
| `󰏩` paw (Sam) | left: hide / show Sam (remembered) · right: his menu · middle: throw the ball |

## Sam

Lives in the upper right. **Drag** him anywhere: that becomes his spot. **Click** = purr, **right click** = menu (feed, ball, yarn, treat, back to his spot, hide). During a pomodoro focus round he sleeps and won't play; when it ends he stretches. Away 3 min → he naps.

## Things that just happen

| What | How |
| ---- | ---- |
| **Session restore** | windows come back after a reboot, terminals in their folders, nothing re-run. `desk-session show` lists what's saved, `desk-session off` / `on` |
| **Backups** | every night ~03:30 to the ThinkPad (restic). `desk-backup snapshots`, `desk-backup restore latest <path> <dir>`. Password copy on gunnar |
| **Sounds** | notifications, USB / charger plug, volume. `touch ~/.config/desk/sounds-off` mutes everything |
| **Theme** | `desk-theme <name>` (or `Super Shift T`): Hyprland, waybar, kitty, nvim, GTK, Qt, folders, btop, zathura, Spotify, Discord |

## Commands worth knowing

| Command | Does |
| ---- | ---- |
| `desk-sync` | copy wallpapers / themes / icons to the ThinkPad (`-n` = dry run) |
| `desk-imagine "prompt" -o out.png [--ref photo.jpg]` | generate an image (needs a key in `~/.config/desk/image-api.env`) |
| `lab-view file.json` · `xray-movie` | Lockscope · structure movie, outside nvim |
