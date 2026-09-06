#!/bin/bash
# Toggle wvkbd-mobintl (reliable Shift on wlroots; no auto-show, summon only).
# Not running -> start (hidden until SIGUSR2? wvkbd starts visible, so hide
# is managed by the caller sequence below). Running -> SIGUSR2 toggles.
# Usage: wvkbd-toggle.sh [toggle|show|hide|status]
set -u

BIN="wvkbd-mobintl"
ARGS="-H 260 -L 180 --bg 1e1e2e --fg 313244 --press 89b4fa"

is_running() { pgrep -x "$BIN" >/dev/null 2>&1; }

do_show() {
  if ! is_running; then
    # shellcheck disable=SC2086
    uwsm-app -- $BIN $ARGS >/dev/null 2>&1 &
    for _ in $(seq 1 50); do
      is_running && break
      sleep 0.1
    done
  else
    pkill -USR2 "$BIN" 2>/dev/null || true
  fi
  # Visibility is toggle-based (SIGUSR2); 'show' on a visible board hides it.
  # Callers that need deterministic show should hide-first when possible.
  # For our flows (summon only when hidden/stopped) plain toggle is correct.
}

do_hide() {
  # SIGUSR2 toggles; only send it when we believe the board is visible.
  # We track visibility with a marker managed by show/hide paths.
  local mark="$HOME/.local/state/omarchy/toggles/hypr/wvkbd-visible"
  if is_running && [[ -f $mark ]]; then
    pkill -USR2 "$BIN" 2>/dev/null || true
    rm -f "$mark"
  fi
}

case "${1:-toggle}" in
  show)
    do_show
    mkdir -p "$HOME/.local/state/omarchy/toggles/hypr"
    : >"$HOME/.local/state/omarchy/toggles/hypr/wvkbd-visible"
    ;;
  hide) do_hide ;;
  status)
    if ! is_running; then echo "stopped";
    elif [[ -f $HOME/.local/state/omarchy/toggles/hypr/wvkbd-visible ]]; then echo "visible";
    else echo "hidden"; fi ;;
  toggle)
    if ! is_running; then
      "$0" show
    elif [[ -f $HOME/.local/state/omarchy/toggles/hypr/wvkbd-visible ]]; then
      do_hide
    else
      "$0" show
    fi ;;
  *) echo "Usage: wvkbd-toggle.sh [toggle|show|hide|status]" >&2; exit 1 ;;
esac
