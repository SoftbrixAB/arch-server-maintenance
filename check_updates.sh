#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

if command -v checkupdates >/dev/null 2>&1; then
    count="$({ checkupdates 2>/dev/null || true; } | wc -l)"
else
    count="$({ pacman -Qu 2>/dev/null || true; } | wc -l)"
fi
echo "Pending package updates: $count"

running_kernel="$(uname -r)"
newest_kernel="$(pacman -Q linux 2>/dev/null | awk '{print $2}')"
if [ -n "$newest_kernel" ] && [ "$running_kernel" != "$newest_kernel" ]; then
    echo "Reboot required: running kernel $running_kernel, installed kernel $newest_kernel"
    exit 2
fi

echo "No reboot required"
