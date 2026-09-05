#!/bin/bash
# Backend-agnostic on-screen keyboard control (Phase 3 swap interface).
# OSK_BACKEND selects the engine (default: custom):
#   custom       custom-kbd.py via wtype (Shift correct by design)
#   squeekboard  Squeekboard via DBus (fallback; Shift broken on Hyprland)
#   wvkbd        wvkbd-mobintl via SIGUSR2 (legacy fallback)
# Backend source, first wins: $OSK_BACKEND env, state file, built-in default.
# All backends honor: toggle | show | hide | status.
# Usage: osk-toggle.sh [toggle|show|hide|status]
#        OSK_BACKEND=squeekboard osk-toggle.sh toggle
#        osk-toggle.sh backend [custom|squeekboard|wvkbd]
set -u

SCRIPTS="$HOME/.config/hypr/scripts"
STATE_DIR="$HOME/.local/state/omarchy/toggles/hypr"
BACKEND_FILE="$STATE_DIR/osk-backend"
DEFAULT_BACKEND="custom"

resolve_backend() {
  local b="${OSK_BACKEND:-}"
  if [[ -z $b && -f $BACKEND_FILE ]]; then
    b=$(cat "$BACKEND_FILE" 2>/dev/null)
  fi
  [[ -z $b ]] && b="$DEFAULT_BACKEND"
  case "$b" in
    custom|squeekboard|wvkbd) printf '%s' "$b" ;;
    *) echo "osk-toggle: unknown backend '$b'" >&2; return 1 ;;
  esac
}

backend_script() {
  case "$1" in
    custom) printf '%s' "$SCRIPTS/custom-kbd-toggle.sh" ;;
    squeekboard) printf '%s' "$SCRIPTS/squeekboard-toggle.sh" ;;
    wvkbd) printf '%s' "$SCRIPTS/wvkbd-toggle.sh" ;;
  esac
}

cmd="${1:-toggle}"
if [[ $cmd == "backend" ]]; then
  if [[ $# -ge 2 ]]; then
    case "$2" in
      custom|squeekboard|wvkbd)
        mkdir -p "$STATE_DIR"
        printf '%s' "$2" >"$BACKEND_FILE"
        echo "OSK backend: $2" ;;
      *) echo "Usage: osk-toggle.sh backend [custom|squeekboard|wvkbd]" >&2; exit 1 ;;
    esac
  else
    resolve_backend
  fi
  exit 0
fi

backend=$(resolve_backend) || exit 1
exec "$(backend_script "$backend")" "$cmd"
