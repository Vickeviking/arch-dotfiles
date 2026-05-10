# Arch Package Snapshot

Generated package lists for restoring this machine.

- `pacman-explicit.txt`: all explicitly installed packages.
- `pacman-native-explicit.txt`: explicitly installed official repository packages.
- `pacman-foreign-explicit.txt`: explicitly installed foreign/AUR packages.
- `dev-tools-versions.txt`: quick version snapshot for common development tools.

Regenerate with:

```sh
pacman -Qqe > ~/.config/pkglist/pacman-explicit.txt
pacman -Qqen > ~/.config/pkglist/pacman-native-explicit.txt
pacman -Qqem > ~/.config/pkglist/pacman-foreign-explicit.txt
```
