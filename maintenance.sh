#!/usr/bin/env bash
set -uo pipefail

log_file="/var/log/maintenance.log"
failed=0

log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$log_file"
}

run_step() {
    local name="$1"
    shift
    log "--- $name ---"
    if "$@" >>"$log_file" 2>&1; then
        log "OK: $name"
    else
        log "FAILED: $name (exit $?)"
        failed=1
    fi
}

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

exec 9>/var/lock/maintenance.lock
if ! flock -n 9; then
    log "Another maintenance run is already in progress, exiting"
    exit 0
fi

log "Maintenance run started"

run_step "System update" pacman -Syu --noconfirm
run_step "Clean package cache" paccache -r --noconfirm

orphans="$(pacman -Qdtq || true)"
if [ -n "$orphans" ]; then
    run_step "Remove orphaned packages" pacman -Rns $orphans --noconfirm
else
    log "OK: Remove orphaned packages (none found)"
fi

run_step "Vacuum journal (keep 90 days)" journalctl --vacuum-time=90d

home_cache="${HOME:-/root}/.cache"
if [ -d "$home_cache" ]; then
    find "$home_cache" -mindepth 1 -maxdepth 1 -exec rm -rf {} + >>"$log_file" 2>&1 \
        && log "OK: Clean user cache" \
        || { log "FAILED: Clean user cache"; failed=1; }
fi

if [ "$failed" -eq 0 ]; then
    log "Maintenance run finished successfully"
else
    log "Maintenance run finished with failures"
fi
exit "$failed"
