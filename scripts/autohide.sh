#!/usr/bin/env bash
# ============================================================================
# DISABLED BACKUP -- not run by default. This is the old auto-hide behaviour:
# the bar reveals when the cursor reaches the BOTTOM edge of the screen AND for
# a few seconds whenever the active workspace changes. The current setup uses
# scripts/flash.sh (workspace-switch only) instead.
#
# To re-enable this instead of flash.sh:
#   1. config.jsonc: keep "start_hidden": true
#   2. hyprland.conf: remove the per-workspace `exec, .../flash.sh` binds,
#      and add:  exec-once = ~/.config/waybar/scripts/autohide.sh
#   3. Restart: killall waybar; waybar & disown; then run this script.
#
# Note: SIGUSR1 is a blind toggle and the bar must start hidden
# (start_hidden: true) so the internal `shown` state stays in sync. This script
# must be the only thing toggling the bar, started together with waybar.
# ============================================================================

reveal_at=2      # show the bar when cursor Y is within this many px of the bottom
hide_above=20    # hide again once cursor Y rises this many px above the bottom
interval=0.12    # polling interval, seconds
ws_reveal_secs=2 # how long to keep the bar shown after a workspace change

shown=0          # current bar state (0 = hidden, matches start_hidden)
last_ws=""       # last seen active workspace id
reveal_until=0   # epoch seconds until which the workspace-triggered reveal lasts

# Bottom edge Y = the largest (monitor.y + monitor.height) across all outputs.
# With a horizontal, equal-height layout this is the same for every monitor.
screen_h=$(hyprctl monitors -j 2>/dev/null \
  | grep -oP '"(y|height)":\s*\K[0-9]+' \
  | paste - - \
  | awk '{ s=$1+$2; if (s>m) m=s } END { print m }')
[[ -z "$screen_h" ]] && screen_h=1080   # fallback if hyprctl is unavailable

while true; do
  now=$(date +%s)

  # hyprctl cursorpos prints e.g. "2483, 751"; strip comma, take the Y field.
  read -r _ y < <(hyprctl cursorpos 2>/dev/null | tr -d ',')

  # hyprctl activeworkspace prints e.g. "workspace ID 1 (1) on monitor ...".
  read -r ws < <(hyprctl activeworkspace 2>/dev/null | grep -oP 'ID \K[0-9]+')
  if [[ -n "$ws" && -n "$last_ws" && "$ws" != "$last_ws" ]]; then
    reveal_until=$((now + ws_reveal_secs))
  fi
  [[ -n "$ws" ]] && last_ws="$ws"

  # Decide whether the bar should be shown this tick.
  want=0
  [[ "$y" =~ ^[0-9]+$ ]] && ((y >= screen_h - reveal_at)) && want=1
  ((now < reveal_until)) && want=1

  # Only re-toggle when crossing the hide_above threshold, so cursor jitter in
  # the middle of the screen doesn't flip the bar while a timed reveal is active.
  if ((want == 1 && shown == 0)); then
    killall -SIGUSR1 waybar
    shown=1
  elif ((want == 0 && shown == 1)); then
    if [[ "$y" =~ ^[0-9]+$ ]] && ((y <= screen_h - hide_above)); then
      killall -SIGUSR1 waybar
      shown=0
    fi
  fi

  sleep "$interval"
done
