#!/bin/sh
set -eu

if command -v docker-compose >/dev/null 2>&1; then
    dc="docker-compose"
elif docker compose version >/dev/null 2>&1; then
    dc="docker compose"
else
    echo "Neither 'docker-compose' nor 'docker compose' is available" >&2
    exit 1
fi

failed=0
for d in */; do
    [ -f "${d}docker-compose.yml" ] || [ -f "${d}docker-compose.yaml" ] || [ -f "${d}compose.yml" ] || [ -f "${d}compose.yaml" ] || continue
    echo "$d"
    if ( cd "$d" && $dc pull && $dc up -d --remove-orphans ); then
        :
    else
        echo "docker update failed in $d" >&2
        failed=1
    fi
done
exit "$failed"
