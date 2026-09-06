#!/bin/bash
# SAM OSK toggle — same CLI as squeekboard-toggle.sh
# (toggle/show/hide/status) so gestures, SUPER+B and tablet-mode
# plug in unchanged at swap time (Phase 3). Phase 1: standalone,
# not yet wired — interim OSK stays Squeekboard.
# Usage: custom-kbd-toggle.sh [toggle|show|hide|status]
set -u

APP="custom-kbd.py"
# Bracket trick: pkill -f matches full cmdlines, and our own invocation
# contains this script's name — [c] prevents self-match (TABLET.md lesson).
PAT="[c]ustom-kbd\.py"

is_running() { pgrep -f "$PAT" >/dev/null 2>&1; }

do_show() {
  if ! is_running; then
    # gtk4-layer-shell python bindings need the preload (see upstream
    # linking.md) or init_for_window silently fails: window falls back
    # to a regular window and loses exclusive-zone + keyboard-NONE.
    export LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so
    # Keep stderr (incl. GLib fatals) for crash diagnosis.
    uwsm-app -- python3 "$HOME/.config/hypr/scripts/$APP" >>/tmp/custom-kbd-stderr.log 2>&1 &
  fi
}

do_hide() { pkill -f "$PAT" 2>/dev/null || true; }

case "${1:-toggle}" in
  show) do_show ;;
  hide) do_hide ;;
  status) if is_running; then echo "visible"; else echo "stopped"; fi ;;
  toggle) if is_running; then do_hide; else do_show; fi ;;
  *) echo "Usage: custom-kbd-toggle.sh [toggle|show|hide|status]" >&2; exit 1 ;;
esac
