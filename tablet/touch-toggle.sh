#!/bin/bash
# Toggle finger touch (palm rejection while inking with the pen).
# Pen stays enabled. Usage: touch-toggle.sh [on|off|toggle]
set -u

STATE_DIR="$HOME/.local/state/omarchy/toggles/hypr"
STATE_FILE="$STATE_DIR/touch-off"
source "$(dirname "${BASH_SOURCE[0]}")/tablet-devices.sh"
TOUCH="$TABLET_FINGER"

notify() {
  omarchy-notification-send -u low "$1" 2>/dev/null || notify-send "$1" 2>/dev/null || true
}

case "${1:-toggle}" in
  on)
    rm -f "$STATE_FILE"
    hyprctl eval "hl.device({ name = \"$TOUCH\", enabled = true })" >/dev/null 2>&1
    notify "Touch on"
    ;;
  off)
    mkdir -p "$STATE_DIR"
    : >"$STATE_FILE"
    hyprctl eval "hl.device({ name = \"$TOUCH\", enabled = false })" >/dev/null 2>&1
    notify "Touch off (pen still works)"
    ;;
  toggle)
    if [[ -f $STATE_FILE ]]; then exec "$0" on; else exec "$0" off; fi
    ;;
  *) echo "Usage: touch-toggle.sh [on|off|toggle]" >&2; exit 1 ;;
esac
