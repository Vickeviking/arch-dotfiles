# desk-backup

Nightly restic backups between the two machines over Tailscale. The desktop
(`legion-arch`) backs up to the ThinkPad at `~/backups/legion-arch`.

What goes in: `~/dev`, the chezmoi source, `~/Documents`, `~/Pictures`, and a
read-only `pg_dump` of Arcturon's dev database (`arcturon-dev-pg`) when it runs.
Build output and caches stay out (`excludes`). Snapshots kept: 7 daily,
4 weekly, 6 monthly.

## Turning it on (Viktor, once)

1. Install restic on both machines:

       sudo pacman -S --needed restic

2. Pick a repository password and store it (only you know it; keep a copy in
   your password manager, because without it the backups can't be read):

       install -m 600 /dev/null ~/.config/desk-backup/password
       nvim ~/.config/desk-backup/password

3. Create the repository on the ThinkPad (the desktop already reaches it
   with SSH keys):

       ssh vango@vango-arch-thinkpad mkdir -p backups
       RESTIC_PASSWORD_FILE=~/.config/desk-backup/password \
         restic -r sftp:vango@vango-arch-thinkpad:/home/vango/backups/legion-arch init

4. First backup by hand (it takes a while), then turn on the timer:

       desk-backup
       systemctl --user enable --now desk-backup.timer

5. Check it once by restoring a file:

       desk-backup snapshots
       desk-backup restore latest /home/vango/Documents/<some file> /tmp/restore-test

The ThinkPad → desktop direction needs sshd on the desktop, which is off on
purpose; turn it on only if you want the ThinkPad backed up too.

## Where the password lives

- the desktop: `~/.config/desk-backup/password`
- gunnar (the Pi): `~/.config/desk-backup/password-legion-arch` (only readable by vango)

If the desktop is gone, restore from any machine with:

    scp gunnar:.config/desk-backup/password-legion-arch /tmp/restic-pass
    restic -r sftp:vango@vango-arch-thinkpad:/home/vango/backups/legion-arch \
      --password-file /tmp/restic-pass snapshots

Not on the ThinkPad on purpose: the backups and their key on one
unencrypted laptop would make the encryption pointless if it were stolen.
