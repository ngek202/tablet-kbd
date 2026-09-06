#!/bin/bash
# Tablet mode — finger touch only (pen deferred).
# on:  internal keyboard + touchpad off, finger stays on, follow_mouse=2, OSK started
# off: everything restored, OSK stopped
# Touch exit is a 4-finger swipe inward from the left visual edge (lisgd,
# see touch-gestures.sh). tablet-exit.py remains as a manual fallback pill.
#
# Hardening (2026-09-05 touchpad incident): no silent hyprctl failures.
# Every eval is exit-checked; failures notify loudly and mode_off falls
# back to `hyprctl reload` (restores device defaults).
# Usage: tablet-mode.sh [on|off|toggle|status]
set -u

STATE_DIR="$HOME/.local/state/omarchy/toggles/hypr"
STATE_FILE="$STATE_DIR/tablet-mode-on"

# Device detection (single source of truth; resolves the instance sig for
# daemon contexts too). User overrides live in tablet-devices.conf.
source "$(dirname "${BASH_SOURCE[0]}")/tablet-devices.sh"
KBD="$TABLET_KBD"
PAD="$TABLET_PAD"
FINGER="$TABLET_FINGER"

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
  # Empty name = device absent (e.g. pad-less convertible): skip cleanly.
  [[ -n ${1:-} ]] || return 0
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
  if [[ -z $FINGER ]]; then
    alert "Tablet mode: no touch device detected (see tablet-devices.conf to pin one)"
    return 1
  fi
  mkdir -p "$STATE_DIR"
  # Quiescence first (2026-09-06): disabling between a press and its
  # release strands the key (release never lands; Hyprland's repeat
  # timer fires it forever — seen with a quick Enter tap and with
  # SUPER+SHIFT+T). Wait up to ~2s for all keys released. Best-effort.
  python3 "$HOME/.config/hypr/scripts/tablet-modwait.py" >/dev/null 2>&1 || true
  dev_set "$KBD" false
  dev_set "$PAD" false
  ev "finger on" "hl.device({ name = \"$FINGER\", enabled = true })"
  ev "follow_mouse 2" 'hl.config({ input = { follow_mouse = 2 } })'
  if [[ $FAILED -ne 0 ]]; then
    alert "Tablet mode partially applied — hyprctl failed (see journal). Keyboard may still be live."
  else
    : >"$STATE_FILE"
    osk_start
    notify "Tablet mode on — 4-finger swipe inward from left edge to exit"
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
  # Modifier reset REMOVED 2026-09-06: virtual press+release
  # (wtype -P/-p) does not reliably release — Hyprland ignores parts of
  # virtual modifier traffic, so this stranded Super itself on every
  # exit. Device cycle (manual) remains the cure; entry-race prevention
  # (tablet-modwait.py) the pending fix.
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
