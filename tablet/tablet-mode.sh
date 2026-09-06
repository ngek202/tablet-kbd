#!/bin/bash
# Tablet mode for Portege X30W-J — finger touch only (pen deferred).
# on:  internal keyboard + touchpad off, finger stays on, follow_mouse=2, Squeekboard started
# off: everything restored, Squeekboard stopped
# Touch exit is a 4-finger swipe down from the top edge (lisgd, see
# touch-gestures.sh). tablet-exit.py remains as a manual fallback pill.
#
# Hardening (2026-09-05 touchpad incident): no silent hyprctl failures.
# Every eval is exit-checked; failures notify loudly and mode_off falls
# back to `hyprctl reload` (restores device defaults).
# Usage: tablet-mode.sh [on|off|toggle|status]
set -u

STATE_DIR="$HOME/.local/state/omarchy/toggles/hypr"
STATE_FILE="$STATE_DIR/tablet-mode-on"
KBD="at-translated-set-2-keyboard"
PAD="3030303142534f54:00-06cb:cddd-touchpad"
FINGER="wacom-hid-5272-finger"

# hyprctl needs the instance signature. Interactive shells usually have it,
# but gesture/daemon contexts (lisgd, systemd) may not — resolve it like
# auto-rotate.sh does instead of failing silently.
if [[ -z ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
  sig_dir="/run/user/$(id -u)/hypr"
  if [[ -d $sig_dir ]]; then
    newest=$(ls -t "$sig_dir" 2>/dev/null | head -n 1)
    [[ -n $newest ]] && export HYPRLAND_INSTANCE_SIGNATURE="$newest"
  fi
fi

FAILED=0

notify() {
  omarchy-notification-send -u low "$1" 2>/dev/null || notify-send "$1" 2>/dev/null || true
}

alert() {
  omarchy-notification-send -u critical "$1" 2>/dev/null || notify-send -u critical "$1" 2>/dev/null || true
}

# Checked eval: records failure instead of swallowing it.
ev() {
  local desc="$1"; shift
  if ! out=$(hyprctl eval "$1" 2>&1); then
    echo "tablet-mode: FAIL [$desc]: $out" >&2
    FAILED=1
    return 1
  fi
  return 0
}

dev_set() {
  ev "device $1 enabled=$2" "hl.device({ name = \"$1\", enabled = $2 })"
}

osk_start() {
  # Phase 3: backend-agnostic (osk-toggle.sh dispatches to custom /
  # squeekboard / wvkbd). Summon-on-demand: the custom board has no hidden
  # mode, so enter only clears leftovers instead of pre-starting.
  # EXIT POLICY (2026-09-06, user decision): tablet mode exits ONLY via
  # the deliberate 4-finger swipe (or SUPER+SHIFT+T with a live
  # keyboard). No automatic exit on input — the kernel-level watcher
  # fired on folding jostle and stranded modifiers. tablet-auto-exit.py
  # stays in tree, unwired.
  pkill -x squeekboard 2>/dev/null || true
  pkill -x wvkbd-mobintl 2>/dev/null || true
  pkill -f "[c]ustom-kbd\\.py" 2>/dev/null || true
  rm -f "$STATE_DIR/wvkbd-visible"
}

osk_stop() {
  "$HOME/.config/hypr/scripts/osk-toggle.sh" hide 2>/dev/null || true
  pkill -x squeekboard 2>/dev/null || true
  pkill -x wvkbd-mobintl 2>/dev/null || true
  pkill -f "[c]ustom-kbd\\.py" 2>/dev/null || true
  rm -f "$STATE_DIR/wvkbd-visible"
}

mode_on() {
  FAILED=0
  mkdir -p "$STATE_DIR"
  dev_set "$KBD" false
  dev_set "$PAD" false
  ev "finger on" "hl.device({ name = \"$FINGER\", enabled = true })"
  ev "follow_mouse 2" 'hl.config({ input = { follow_mouse = 2 } })'
  if [[ $FAILED -ne 0 ]]; then
    alert "Tablet mode partially applied — hyprctl failed (see journal). Keyboard may still be live."
  else
    : >"$STATE_FILE"
    osk_start
    notify "Tablet mode on — 4-finger swipe down from top to exit"
  fi
  return $FAILED
}

mode_off() {
  FAILED=0
  dev_set "$KBD" true
  dev_set "$PAD" true
  ev "finger on" "hl.device({ name = \"$FINGER\", enabled = true })"
  ev "follow_mouse 1" 'hl.config({ input = { follow_mouse = 1 } })'
  if [[ $FAILED -ne 0 ]]; then
    # Safety net: reload restores device defaults from config.
    alert "Tablet off hit hyprctl errors — reloading Hyprland to restore input"
    hyprctl reload >/dev/null 2>&1 || true
  fi
  # Modifier reset (2026-09-06): entering via SUPER+SHIFT+T disables the
  # keyboard mid-hotkey while Super/Shift are still held, so the release
  # never lands and the modifier stays stranded (every key fires Super
  # binds after exit). A virtual press+release pair re-syncs compositor
  # state on every exit. Best-effort: wtype missing = skip silently.
  for mod in Super_L Super_R Shift_L Shift_R; do
    wtype -P "$mod" -p "$mod" >/dev/null 2>&1 || true
  done
  rm -f "$STATE_FILE"
  osk_stop
  notify "Tablet mode off"
  return $FAILED
}

case "${1:-toggle}" in
  on) mode_on ;;
  off) mode_off ;;
  toggle) if [[ -f $STATE_FILE ]]; then mode_off; else mode_on; fi ;;
  status) if [[ -f $STATE_FILE ]]; then echo "on"; else echo "off"; fi ;;
  *) echo "Usage: tablet-mode.sh [on|off|toggle|status]" >&2; exit 1 ;;
esac
