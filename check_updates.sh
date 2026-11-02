#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

count="$(pacman -Qu | wc -l)"
echo "Pending package updates: $count"

running_kernel="$(uname -r)"
newest_kernel="$(pacman -Q linux 2>/dev/null | awk '{print $2}')"
if [ -n "$newest_kernel" ] && [ "$running_kernel" != "$newest_kernel" ]; then
    echo "Reboot required: running kernel $running_kernel, installed kernel $newest_kernel"
    exit 2
fi

echo "No reboot required"
