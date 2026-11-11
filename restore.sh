#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

if [ $# -ne 1 ]; then
    echo "Usage: $0 <backup-directory>" >&2
    exit 1
fi

src="$1"
[ -d "$src" ] || { echo "Not a directory: $src" >&2; exit 1; }

log_file="${LOG_FILE:-/var/log/restore.log}"
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$log_file"
}

log "Restore started from $src"

if [ -f "$src/pkglist-explicit.txt" ]; then
    pacman -S --needed --noconfirm - <"$src/pkglist-explicit.txt" >>"$log_file" 2>&1
    log "Restored explicit packages"
fi
if [ -f "$src/pkglist-foreign.txt" ]; then
    if command -v yay >/dev/null 2>&1; then
        yay -S --needed --noconfirm - <"$src/pkglist-foreign.txt" >>"$log_file" 2>&1 || log "WARNING: some foreign packages could not be restored with yay"
    else
        log "WARNING: yay not installed, skipping foreign package restore"
    fi
fi

[ -d "$src/etc" ] && rsync -aHAX --delete "$src/etc/" /etc/ && log "Restored /etc"
[ -d "$src/root" ] && rsync -aHAX "$src/root/" /root/ && log "Restored /root"
[ -d "$src/home" ] && rsync -aHAX "$src/home/" /home/ && log "Restored /home"
[ -d "$src/docker-volumes" ] && rsync -aHAX "$src/docker-volumes/" /var/lib/docker/volumes/ && log "Restored docker volumes"

log "Restore finished from $src"
