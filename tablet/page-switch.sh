#!/bin/bash
# page-switch.sh — scroll to the previous/next window-page (Omarchy
# scrolling layout: one page per workspace). Used by the 3-finger swipe
# gestures in touch-gestures.sh (all modes) and as the dual-mode
# else-branch of the edge-exit bindings.
#
# WHY the hl.dispatch wrapper: bare `hyprctl dispatch workspace ±1` is
# broken on this build — it inlines the dispatcher+arg unquoted into a
# Lua eval (`hl.dispatch(workspace +1)`) which errors on any arg (seen
# 2026-09-06). `hl.dsp.focus` builds a Dispatcher; `hl.dispatch`
# executes it. Verified: e-1/e-1 hop between existing pages.
# Usage: page-switch.sh [prev|next]
set -u

case "${1:-}" in
  prev) arg='e-1' ;;
  next) arg='e+1' ;;
  *) echo "Usage: page-switch.sh [prev|next]" >&2; exit 1 ;;
esac

exec hyprctl eval "hl.dispatch(hl.dsp.focus({ workspace = '$arg' }))"
