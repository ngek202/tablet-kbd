#!/bin/bash
# Touchscreen gestures via lisgd — finger only, tablet companion.
# Resolves the finger event node dynamically (event numbers shift across
# reboots; device names vary per convertible — see tablet-devices.sh).
# Gestures: 3-finger L/R = page scroll prev/next (scrolling layout —
# window switching; works in ALL modes via page-switch.sh), 1-finger up
# from the visual bottom edge = OSK, 3-finger up anywhere = OSK toggle
# (the edge-free dismiss: a full-width OSK covers the bottom edge, so
# the edge swipe can't reach while open), 3-finger inward from the
# visual LEFT or RIGHT edge = exit tablet mode when on, page scroll
# otherwise (dual-mode; was 4-finger left-edge only until 2026-09-06 —
# the 4-finger was then restored per user preference, see below — and
# was moved off the top edge earlier the same day: swipes originating
# on the bar dragged through widgets). "Visual" edges follow rotation
# via -o below.
# Direction code reads origin-to-travel (DU,B = bottom→up), so left-edge
# inward is LR,L and right-edge inward is RL,R.
# EDGE PRIORITY: the edge-bound exit gestures are defined BEFORE the
# generic workspace gestures because lisgd executes the FIRST match
# (lisgd.c gestureexecute: return 1). Their commands are dual-mode: in
# tablet mode they exit; in laptop mode they fall through to the same
# workspace dispatch the generic binding would run — so edge-originated
# 3-finger swipes keep switching workspaces when tablet mode is off.
# This is the emergency exit — it stays no matter what (bar plugin
# crash, shell death); never remove without a replacement.
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
PAGES="$HOME/.config/hypr/scripts/page-switch.sh"
# Edge-exit gestures are dual-mode (see header): exit tablet mode when
# it's on; otherwise perform the same page scroll the generic binding
# runs (page-switch.sh) — edge-originated 3-finger swipes never become
# dead zones in laptop mode.
STATE="$HOME/.local/state/omarchy/toggles/hypr/tablet-mode-on"
EDGE_EXIT_L="sh -c 'if [ -f $STATE ]; then $HOME/.config/hypr/scripts/tablet-mode.sh off; else $PAGES prev; fi'"
EDGE_EXIT_R="sh -c 'if [ -f $STATE ]; then $HOME/.config/hypr/scripts/tablet-mode.sh off; else $PAGES next; fi'"
# 4-finger edges: ORIGINAL emergency exit (restored 2026-09-06 alongside
# the 3-finger edges per user preference: 3-finger alone felt off), now
# on BOTH edges (right-edge added after the user found it missing when
# testing — original restore carried only the left-edge binding).
# Tablet-only — no-op in laptop mode (stray 4-finger never kills a
# manually opened OSK there).
TABLET_OFF="sh -c '[ -f $STATE ] && $HOME/.config/hypr/scripts/tablet-mode.sh off'"

# Thresholds mirror sxmo defaults; tune via env if needed.
TH="${SXMO_LISGD_THRESHOLD:-125}"
TH_P="${SXMO_LISGD_THRESHOLD_PRESSED:-60}"

# Orientation follows the display transform (auto-rotate.sh re-runs this
# script with ORIENTATION set on every rotation). lisgd's own -o flag
# rotates its gesture frame, so one static binding set works in every
# orientation — no per-orientation edge rebinding needed.
# ORDER MATTERS: edge-bound exit gestures BEFORE the generic * gestures
# (lisgd executes the first defined match). Directions are touch-native
# (content follows finger): swipe rightward (LR) = previous page,
# leftward (RL) = next page.
exec lisgd -d "$DEV" -o "${ORIENTATION:-0}" -t "$TH" -T "$TH_P" \
  -g "3,LR,L,*,$EDGE_EXIT_L" \
  -g "3,RL,R,*,$EDGE_EXIT_R" \
  -g "3,LR,*,*,$PAGES prev" \
  -g "3,RL,*,*,$PAGES next" \
  -g "1,DU,B,*,$OSK" \
  -g "3,DU,*,*,$OSK" \
  -g "4,LR,L,*,$TABLET_OFF" \
  -g "4,RL,R,*,$TABLET_OFF" >/dev/null 2>&1
