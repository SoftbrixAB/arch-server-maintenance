# Arch Server Maintenance

Shell scripts for keeping an Arch Linux server up to date and tidy. All scripts
are safe to run repeatedly and exit with a non-zero status if anything fails,
so they are suitable for cron or systemd timers.

## Requirements

- Arch Linux with `pacman` (the maintenance and system-update scripts)
- Root privileges for `update_system.sh`, `maintenance.sh`, `check_updates.sh`,
  `reboot_if_needed.sh`, `backup.sh`, `restore.sh`, and `security_audit.sh`
- `rsync` for `backup.sh` / `restore.sh`
- Docker with either the Compose v2 plugin (`docker compose`) or the legacy
  `docker-compose` binary (the docker scripts); one of the two is required

## Scripts

### `update_system.sh`

Updates all packages:

```sh
sudo ./update_system.sh
```

Runs `pacman -Syu --noconfirm`. Output goes to stdout/stderr; pacman's own log
is written to `/var/log/pacman.log` by pacman itself.

### `maintenance.sh`

Full maintenance pass. Run as root:

```sh
sudo ./maintenance.sh
```

Performs the following steps, each logged with a timestamp and an `OK` /
`FAILED` status to `/var/log/maintenance.log` (and to stdout):

1. System update (`pacman -Syu --noconfirm`)
2. Package cache cleanup (`paccache -r --noconfirm`)
3. Removal of orphaned packages (`pacman -Qdtq` piped to `pacman -Rns -`)
4. Journal vacuum keeping the last 90 days (`journalctl --vacuum-time=90d`)
5. Cleanup of the root user's `~/.cache` contents

A `flock` on `/var/lock/maintenance.lock` prevents overlapping runs: if another
instance is already running, the script exits immediately with status 0. The
script exits non-zero if any step failed.

### `update_docker.sh`

Updates Docker Compose services. Run from the directory that contains one
subdirectory per service (each with a compose file):

```sh
cd /srv && ./update_docker.sh
```

For every subdirectory containing a `docker-compose.yml`, `docker-compose.yaml`,
`compose.yml`, or `compose.yaml`, it runs `pull` followed by `up -d
--remove-orphans` inside that directory. Directories without a compose file are
skipped. The script exits non-zero if any service failed to update.

### `docker_down.sh`

Stops all Docker Compose services. Same directory layout and compose-file
detection as `update_docker.sh`; runs `down` in each service directory and exits
non-zero if any service failed to stop.

### `check_updates.sh`

Reports how many package updates are pending and whether a reboot is required
(running kernel vs. installed `linux` kernel). Run as root:

```sh
sudo ./check_updates.sh
```

Exit codes: `0` = up to date / no reboot needed, `2` = reboot required,
`1` = error (e.g. not run as root). Handy for monitoring and alerting.

### `reboot_if_needed.sh`

Reboots the server **only if a reboot is required** (via `check_updates.sh`,
exit code `2`) **and only inside the reboot window — by default between
02:00 and 03:00**. Outside the window it exits `0` without doing anything, so
cron can run it frequently (e.g. every 15 minutes) and the reboot will still
happen within the window:

```sh
sudo ./reboot_if_needed.sh
```

The window can be changed with `REBOOT_WINDOW_START` / `REBOOT_WINDOW_END`
(hours, 24h format, default `2` and `3`). Actions are logged to
`/var/log/reboot_if_needed.log` (override with `LOG_FILE`).

### `backup.sh`

Creates a timestamped backup snapshot. Run as root:

```sh
sudo ./backup.sh                 # -> /var/backups/server/<timestamp>/
sudo ./backup.sh /mnt/nas/daily  # custom destination
```

Each snapshot contains the explicit package list (`pacman -Qqe`), the foreign
/AUR package list (`pacman -Qqm`), and copies of `/etc`, `/root`, `/home`, and
`/var/lib/docker/volumes`. Old snapshots under `BACKUP_DIR` are pruned, keeping
the newest `BACKUP_KEEP` (default `7`). Logs to `/var/log/backup.log`
(override with `LOG_FILE`). Exits non-zero on failure.

### `restore.sh`

Restores from a backup snapshot created by `backup.sh`. Run as root:

```sh
sudo ./restore.sh /var/backups/server/2026-11-02_040000
```

Reinstalls packages from the snapshot's package lists (uses `yay` for foreign
packages if installed) and copies `/etc`, `/root`, `/home`, and docker volumes
back. Logs to `/var/log/restore.log`. **Review the snapshot contents before
restoring on a live system.**

### `security_audit.sh`

Read-only security audit. Run as root:

```sh
sudo ./security_audit.sh
```

Checks and reports (to stdout and `/var/log/security_audit.log`): listening
ports, failed SSH logins in the last 24h, accounts with empty passwords,
`PermitRootLogin` setting, world-writable files in `/etc`, firewall state
(nftables/ufw/firewalld), and pending package updates. Exits `1` if any issue
was found, `0` if clean — suitable for daily cron with failure notification.

## Recommended automated setup (cron)

1. Install the scripts to a fixed location, e.g.:

   ```sh
   sudo git clone https://github.com/SoftbrixAB/arch-server-maintenance.git /opt/arch-server-maintenance
   sudo chmod +x /opt/arch-server-maintenance/*.sh
   ```

2. Add root crontab entries (`sudo crontab -e`):

   ```cron
   # m h dom mon dow  command
   0 1 * * 0  /opt/arch-server-maintenance/maintenance.sh
   0 5 * * *  cd /srv && /opt/arch-server-maintenance/update_docker.sh
   0 6 * * *  /opt/arch-server-maintenance/backup.sh
   30 6 * * * /opt/arch-server-maintenance/security_audit.sh
   */15 * * * * /opt/arch-server-maintenance/reboot_if_needed.sh
   ```

   - `maintenance.sh` runs early Sunday at 01:00 so that any kernel update it
     installs is picked up by the reboot check in the same night's window.
   - `reboot_if_needed.sh` runs every 15 minutes but **only reboots between
     02:00 and 03:00** (the `REBOOT_WINDOW_START`/`REBOOT_WINDOW_END` default).
     Outside that window it does nothing. If you prefer a single fixed reboot
     time instead, replace the line with `0 2 * * 0 systemctl reboot` guarded
     by `check_updates.sh`, but the windowed script is the recommended option
     because it reboots as soon as possible inside the window.
   - All scripts log to `/var/log/*.log` and exit non-zero on failure, so cron
     will mail you (or, with systemd timers, trigger `OnFailure=`) when
     something breaks.

## Notes

- The docker scripts work with both `docker compose` (v2 plugin, preferred) and
  the deprecated standalone `docker-compose`.
- Paths with spaces are handled correctly in the docker scripts.
- Run `shellcheck *.sh` after modifying the scripts.

## License

See [LICENSE](LICENSE).
