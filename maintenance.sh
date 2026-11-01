#!/bin/bash

log_file="/var/log/maintenance.log"

# Update system
echo -e "System update $(date)\n" >> "$log_file"
pacman -Syu --noconfirm >> "$log_file" 2>&1

# Clean package cache
paccache -r --noconfirm >> "$log_file" 2>&1

# Remove orphaned packages
pacman -Rns $(pacman -Qdtq) --noconfirm >> "$log_file" 2>&1

# Clean package configuration files
pacman -Qdtq | pacman -Rns - >> "$log_file" 2>&1

# Delete old log files
journalctl --vacuum-time=90d >> "$log_file" 2>&1

# Remove unnecessary user cache files
rm -rf ~/.cache/* >> "$log_file" 2>&1

