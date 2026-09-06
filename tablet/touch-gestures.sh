#!/bin/bash
# Touchscreen gestures via lisgd — finger only, tablet companion.
# Resolves the finger event node dynamically (event numbers shift across
# reboots; device names vary per convertible — see tablet-devices.sh).
# Gestures: 3-finger L/R = workspace, 1-finger up from the visual bottom
# edge = OSK, 3-finger up anywhere = OSK toggle (the edge-free dismiss:
# a full-width OSK covers the bottom edge, so the edge swipe can't reach
# while open), 4-finger inward from the visual LEFT edge = exit tablet
# mode (moved 2026-09-06 off the top edge: swipes originating on the bar
# dragged through widgets). "Visual" edges follow rotation via -o below.
# Direction code reads origin-to-travel (DU,B = bottom→up), so left-edge
# inward is LR,L. This is the emergency exit — it stays no matter what
# (bar plugin crash, shell death); never remove without a replacement.
# NOTE 2026-09-05: 4-finger L/R window focus was tried and reverted —
# awkward to perform, conflicts with in-app touch (file manager); tap
# the target window to focus it instead (direct manipulation).
# Safe no-op if lisgd is not installed yet.
# NOTE: lisgd reads this file once at startup. After editing, restart it:
#   pkill -x lisgd && setsid -f ~/.config/hypr/scripts/touch-gestures.sh
# (autostart only runs it at login, `hyprctl reload` does NOT refresh it.)
set -u

command -v lisgd >/dev/null 2>&1 || exit 0
# NOTE: device checks run BEFORE the pkill below, so a failed start never
# kills a working daemon (seen 2026-09-05: don't murder the old mapping
# when the finger node is momentarily unreadable).

# Find the finger event node via /proc/bus/input/devices, matching the
# detected kernel-name pattern (tablet-devices.sh; generic, not model-bound).
source "$(dirname "${BASH_SOURCE[0]}")/tablet-devices.sh"
EVENT=""
name=""
while IFS= read -r line; do
  case "$line" in
    N:*Name=*) name="$line" ;;
    H:*Handlers=*)
      # Case-insensitive match: kernel names capitalize ("Finger"),
      # the detected pattern is lowercase.
      low=${name,,}
      if [[ $low =~ ($TABLET_FINGER_KERNEL) ]] && [[ ! $low =~ touchpad ]]; then
        EVENT=$(echo "$line" | grep -o 'event[0-9]*' | head -n 1)
      fi
      name=""
      ;;
  esac
done < /proc/bus/input/devices

[ -n "${EVENT:-}" ] || exit 0
DEV="/dev/input/$EVENT"
# Needs input-group membership (takes effect on next login). Fail silent until then.
[ -r "$DEV" ] || exit 0

# All checks passed — now safe to replace any running daemon.
pkill -x lisgd 2>/dev/null || true

OSK="$HOME/.config/hypr/scripts/osk-toggle.sh"
# Exit only when tablet mode is actually on (no-op in laptop mode, so a
# stray 4-finger swipe never kills a manually opened OSK there).
TABLET_OFF="sh -c '[ -f $HOME/.local/state/omarchy/toggles/hypr/tablet-mode-on ] && $HOME/.config/hypr/scripts/tablet-mode.sh off'"

# Thresholds mirror sxmo defaults; tune via env if needed.
TH="${SXMO_LISGD_THRESHOLD:-125}"
TH_P="${SXMO_LISGD_THRESHOLD_PRESSED:-60}"

# Orientation follows the display transform (auto-rotate.sh re-runs this
# script with ORIENTATION set on every rotation). lisgd's own -o flag
# rotates its gesture frame, so one static binding set works in every
# orientation — no per-orientation edge rebinding needed.
exec lisgd -d "$DEV" -o "${ORIENTATION:-0}" -t "$TH" -T "$TH_P" \
  -g "3,LR,*,*,hyprctl dispatch workspace -1" \
  -g "3,RL,*,*,hyprctl dispatch workspace +1" \
  -g "1,DU,B,*,$OSK" \
  -g "3,DU,*,*,$OSK" \
  -g "4,LR,L,*,$TABLET_OFF" >/dev/null 2>&1
