#!/usr/bin/env bash
# Flash Waybar: show the bar, then hide it again after a few seconds.
# Called from the workspace keybinds in hyprland.conf so the bar appears
# briefly each time you switch workspace. Pairs with "start_hidden": true.
#
# SIGUSR1 is a blind toggle, so every check-then-toggle and the state file
# live under one lock (fd 8). Without it, two rapid switches can both see
# "not shown" and double-toggle, leaving the bar's real state inverted
# (stuck visible) forever after.

secs=2                           # how long the bar stays visible
state=/tmp/waybar-flash.deadline # epoch-second deadline, present while shown

# Show the bar only if we're not already inside a flash window.
exec 8>>/tmp/waybar-flash.state.lock
flock 8
[[ -f "$state" ]] || killall -SIGUSR1 waybar
echo $(($(date +%s) + secs)) >"$state"
flock -u 8

# Start exactly one watcher (flock -n on fd 9) that hides the bar at the
# deadline. It re-reads the deadline under the lock, so a switch that lands
# mid-hide just extends the flash instead of desyncing the toggle.
{
  flock -n 9 || exit 0
  while :; do
    flock 8
    d=$(cat "$state" 2>/dev/null)
    [[ -z "$d" ]] || (($(date +%s) >= d)) && break
    flock -u 8
    sleep 0.2
  done
  # still holding lock 8
  [[ -f "$state" ]] && killall -SIGUSR1 waybar
  rm -f "$state"
} 9>/tmp/waybar-flash.lock 8>>/tmp/waybar-flash.state.lock &
