#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

backup_dir="${BACKUP_DIR:-/var/backups/server}"
dest="${1:-$backup_dir/$(date '+%Y-%m-%d_%H%M%S')}"
keep="${BACKUP_KEEP:-7}"

log_file="${LOG_FILE:-/var/log/backup.log}"
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$log_file"
}

log "Backup started -> $dest"
mkdir -p "$dest"

pacman -Qqe >"$dest/pkglist-explicit.txt"
pacman -Qqm >"$dest/pkglist-foreign.txt"

rsync -aHAX --delete \
    /etc "$dest/etc/"
rsync -aHAX /root "$dest/root/"
rsync -aHAX /home "$dest/home/"
rsync -aHAX /var/lib/docker/volumes "$dest/docker-volumes/" 2>>"$log_file" || log "WARNING: no docker volumes directory, skipped"

if [ -d "$backup_dir" ]; then
    find "$backup_dir" -maxdepth 1 -mindepth 1 -type d -printf '%T@ %p\n' \
        | sort -rn | tail -n +"$((keep + 1))" | cut -d' ' -f2- \
        | while IFS= read -r old; do
            rm -rf "$old"
            log "Pruned old backup: $old"
        done
fi

log "Backup finished: $dest"
