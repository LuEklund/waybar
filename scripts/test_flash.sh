#!/usr/bin/env bash
# Self-check for flash.sh: 20 concurrent runs must yield exactly 2 toggles
# (one show, one hide). Stubs killall so the real bar is untouched.
set -u
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
printf '#!/bin/sh\necho x >>"%s/log"\n' "$tmp" >"$tmp/killall"
chmod +x "$tmp/killall"
export PATH="$tmp:$PATH"
rm -f /tmp/waybar-flash.deadline

for _ in $(seq 20); do "$(dirname "$0")/flash.sh" & done
wait
sleep 4 # secs=2 deadline + watcher poll margin

n=$(wc -l <"$tmp/log")
[[ $n -eq 2 ]] && echo "OK: 2 toggles (1 show + 1 hide)" || { echo "FAIL: $n toggles"; exit 1; }
