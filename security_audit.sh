#!/usr/bin/env bash
set -uo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

log_file="${LOG_FILE:-/var/log/security_audit.log}"
issues=0

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$log_file"
}

warn() {
    log "WARN: $*"
    issues=$((issues + 1))
}

ok() {
    log "OK: $*"
}

log "Security audit started"

log "--- Listening ports ---"
ss -tlnp >>"$log_file" 2>&1

log "--- Failed SSH logins (last 24h) ---"
failed="$(journalctl -u sshd --since "24 hours ago" --no-pager 2>/dev/null | grep -c 'Failed password' || true)"
if [ "$failed" -gt 0 ]; then
    warn "$failed failed SSH login attempts in the last 24 hours"
else
    ok "No failed SSH logins in the last 24 hours"
fi

log "--- Accounts with empty passwords ---"
empty="$(awk -F: '$2 == "" {print $1}' /etc/shadow)"
if [ -n "$empty" ]; then
    warn "Accounts with empty passwords: $empty"
else
    ok "No accounts with empty passwords"
fi

log "--- SSH root login setting ---"
if grep -Eq '^\s*PermitRootLogin\s+(yes|prohibit-password)' /etc/ssh/sshd_config 2>/dev/null; then
    warn "PermitRootLogin allows root login ($(grep -E '^\s*PermitRootLogin' /etc/ssh/sshd_config))"
else
    ok "Root SSH login is disabled or password-based root login blocked"
fi

log "--- World-writable files in /etc ---"
ww="$(find /etc -type f -perm -0002 2>/dev/null)"
if [ -n "$ww" ]; then
    warn "World-writable files in /etc: $ww"
else
    ok "No world-writable files in /etc"
fi

log "--- Firewall state ---"
if command -v nft >/dev/null 2>&1 && nft list ruleset >/dev/null 2>&1 && [ -n "$(nft list ruleset 2>/dev/null)" ]; then
    ok "nftables ruleset is active"
elif command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q '^Status: active'; then
    ok "ufw is active"
elif command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state 2>/dev/null | grep -q running; then
    ok "firewalld is running"
else
    warn "No active firewall detected (nftables/ufw/firewalld)"
fi

log "--- Pending updates ---"
count="$(pacman -Qu 2>/dev/null | wc -l)"
if [ "$count" -gt 0 ]; then
    warn "$count package updates pending"
else
    ok "System is up to date"
fi

if [ "$issues" -eq 0 ]; then
    log "Security audit finished: no issues found"
    exit 0
else
    log "Security audit finished: $issues issue(s) found"
    exit 1
fi
