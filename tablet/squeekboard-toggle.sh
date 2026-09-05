#!/bin/bash
# Toggle Squeekboard visibility via DBus (Hyprland has no auto-show).
# Running + visible -> hide. Running + hidden -> show.
# Not running -> start, wait for the bus name, then show.
# Usage: squeekboard-toggle.sh [toggle|show|hide|status]
set -u

BUS="sm.puri.OSK0"
OBJ="/sm/puri/OSK0"
IFACE="sm.puri.OSK0"

notify() {
  omarchy-notification-send -u low "$1" 2>/dev/null || notify-send "$1" 2>/dev/null || true
}

is_running() { pgrep -x squeekboard >/dev/null 2>&1; }

is_visible() {
  [[ $(busctl --user get-property "$BUS" "$OBJ" "$IFACE" Visible 2>/dev/null) == *"true"* ]]
}

set_visible() {
  busctl --user call "$BUS" "$OBJ" "$IFACE" SetVisible b "$1" >/dev/null 2>&1
}

wait_for_bus() {
  local i
  for i in $(seq 1 50); do
    busctl --user list 2>/dev/null | grep -q "$BUS" && return 0
    sleep 0.1
  done
  return 1
}

do_show() {
  if ! is_running; then
    uwsm-app -- squeekboard >/dev/null 2>&1 &
    wait_for_bus || { notify "Squeekboard failed to start"; return 1; }
  fi
  set_visible true || { notify "Squeekboard show failed"; return 1; }
}

do_hide() {
  is_running && set_visible false
}

case "${1:-toggle}" in
  show) do_show ;;
  hide) do_hide ;;
  status)
    if ! is_running; then echo "stopped";
    elif is_visible; then echo "visible";
    else echo "hidden"; fi ;;
  toggle)
    if ! is_running; then do_show;
    elif is_visible; then do_hide; else do_show; fi ;;
  *) echo "Usage: squeekboard-toggle.sh [toggle|show|hide|status]" >&2; exit 1 ;;
esac
