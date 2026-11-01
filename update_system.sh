#!/bin/bash
exec &>>/var/log/pacman.log
echo -e "System update $(date)\n"
pacman -Syu --noconfirm
