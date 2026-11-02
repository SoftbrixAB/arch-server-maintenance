# Arch Server Maintenance

Shell scripts for keeping an Arch Linux server up to date and tidy. All scripts
are safe to run repeatedly and exit with a non-zero status if anything fails,
so they are suitable for cron or systemd timers.

## Requirements

- Arch Linux with `pacman` (the maintenance and system-update scripts)
- Root privileges for `update_system.sh` and `maintenance.sh`
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

## Scheduling examples

Cron (as root), e.g. weekly system maintenance and daily docker updates:

```cron
0 4 * * 0 /opt/arch-server-maintenance/maintenance.sh
0 5 * * * cd /srv && /opt/arch-server-maintenance/update_docker.sh
```

Or with systemd timers. Because the scripts exit non-zero on failure, you can
wire the timer units to notify on failure (e.g. `OnFailure=`).

## Notes

- The docker scripts work with both `docker compose` (v2 plugin, preferred) and
  the deprecated standalone `docker-compose`.
- Paths with spaces are handled correctly in the docker scripts.
- Run `shellcheck *.sh` after modifying the scripts.

## License

See [LICENSE](LICENSE).
