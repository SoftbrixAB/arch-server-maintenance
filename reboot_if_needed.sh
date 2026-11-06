#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

window_start="${REBOOT_WINDOW_START:-2}"
window_end="${REBOOT_WINDOW_END:-3}"
log_file="${LOG_FILE:-/var/log/reboot_if_needed.log}"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$log_file"
}

hour="$(date +%H)"
if [ "$hour" -lt "$window_start" ] || [ "$hour" -ge "$window_end" ]; then
    exit 0
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

set +e
"$script_dir/check_updates.sh" >/dev/null 2>&1
rc=$?
set -e

if [ "$rc" -eq 2 ]; then
    log "Reboot required and current time is within the ${window_start}:00-${window_end}:00 window, rebooting now"
    systemctl reboot
elif [ "$rc" -ne 0 ]; then
    log "check_updates.sh failed with exit code $rc, skipping reboot"
    exit "$rc"
fi
