#!/usr/bin/env bash
# Flash Waybar: show the bar, then hide it again after a few seconds.
# Called from the workspace keybinds in hyprland.conf so the bar appears
# briefly each time you switch workspace. Pairs with "start_hidden": true.
#
# SIGUSR1 is a blind toggle, so we use a deadline file to stay safe when you
# switch workspaces several times quickly: the first switch shows the bar, each
# further switch just extends the deadline, and a single background watcher
# hides the bar once the deadline passes. No double-toggling.

secs=2                           # how long the bar stays visible
state=/tmp/waybar-flash.deadline # epoch-second deadline, present while shown
now=$(date +%s)

# Show the bar only if we're not already inside a flash window.
[[ -f "$state" ]] || killall -SIGUSR1 waybar
echo $((now + secs)) >"$state"

# Start exactly one watcher (flock guard) that hides the bar at the deadline.
{
  flock -n 9 || exit 0
  while d=$(cat "$state" 2>/dev/null); do
    (($(date +%s) >= d)) && break
    sleep 0.2
  done
  killall -SIGUSR1 waybar
  rm -f "$state"
} 9>/tmp/waybar-flash.lock &
