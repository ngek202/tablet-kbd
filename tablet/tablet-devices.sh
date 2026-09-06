#!/bin/bash
# tablet-devices.sh — single source of truth for tablet device detection.
# Source this from every tablet script; do NOT hardcode device names.
#
# Provides (exported, refreshed by tablet_detect):
#   TABLET_FINGER          Hyprland touch-device name   (e.g. wacom-hid-5272-finger)
#   TABLET_FINGER_KERNEL   kernel-name pattern for /proc/bus/input/devices
#   TABLET_KBD             internal keyboard (Hyprland name)
#   TABLET_PAD             touchpad (Hyprland name; may be EMPTY)
#   TABLET_OUTPUT          internal display (e.g. eDP-1)
#   _tablet_hyprctl()      hyprctl wrapper (resolves the instance sig if missing)
#   tablet_detect()        re-run detection (call after the compositor is up —
#                          boot-time services may source this module too early)
#
# Detection: hyprctl first, /proc fallback, then user overrides in
# ~/.config/hypr/tablet-devices.conf always win.

# Resolve HYPRLAND_INSTANCE_SIGNATURE for daemon/gesture contexts.
if [[ -z ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
  _sig_dir="/run/user/$(id -u)/hypr"
  _sig=$(ls -t "$_sig_dir" 2>/dev/null | head -n 1)
  [[ -n $_sig ]] && export HYPRLAND_INSTANCE_SIGNATURE="$_sig"
fi

_tablet_hyprctl() {
  command hyprctl "$@" 2>/dev/null
}

tablet_detect() {
  TABLET_FINGER=""
  TABLET_FINGER_KERNEL="finger|touchscreen"
  TABLET_KBD=""
  TABLET_PAD=""
  TABLET_OUTPUT=""

  local _devices_json
  _devices_json=$(_tablet_hyprctl -j devices)
  if [[ -n $_devices_json ]]; then
    # Touch: hyprctl's own touch category is authoritative when populated.
    TABLET_FINGER=$(jq -r '.touch[]?.name // empty' <<<"$_devices_json" | head -n 1)
    # Touchpad: the touchpads category can be empty even when a pad exists;
    # scan every category for a *-touchpad name instead.
    TABLET_PAD=$(jq -r '.. | .name? // empty' <<<"$_devices_json" \
      | grep -- '-touchpad$' | head -n 1)
    # Keyboard: prefer the generic internal AT keyboard name, else first
    # keyboard that isn't a button/hid-event/virtual device.
    TABLET_KBD=$(jq -r '.keyboards[]?.name // empty' <<<"$_devices_json" \
      | grep -x 'at-translated-set-2-keyboard' | head -n 1)
    if [[ -z $TABLET_KBD ]]; then
      TABLET_KBD=$(jq -r '.keyboards[]?.name // empty' <<<"$_devices_json" \
        | grep -viE 'button|video-bus|intel-hid|virtual|power|sleep' | head -n 1)
    fi
  fi

  # Kernel-name fallback: derive the Hyprland name from /proc when hyprctl
  # gave nothing (early boot, compositor restart windows).
  if [[ -z $TABLET_FINGER && -r /proc/bus/input/devices ]]; then
    local _kname
    _kname=$(grep -iE "N:.*($TABLET_FINGER_KERNEL)" /proc/bus/input/devices 2>/dev/null \
      | grep -viE 'touchpad|pad' | head -n 1 | sed 's/^N: Name="//; s/"$//')
    if [[ -n $_kname ]]; then
      TABLET_FINGER_KERNEL=$(printf '%s' "$_kname" | sed 's/[][\.*^$()+{}?]/./g')
      TABLET_FINGER=$(printf '%s' "$_kname" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')
    fi
  fi

  TABLET_OUTPUT=$(_tablet_hyprctl -j monitors | jq -r '.[]?.name // empty' | grep -m1 '^eDP')
  [[ -n $TABLET_OUTPUT ]] || TABLET_OUTPUT=$(_tablet_hyprctl -j monitors | jq -r '.[]?.name // empty' | head -n 1)

  # User overrides always win (pin names on unusual hardware). Re-applied
  # on every detect so lazy re-detection never clobbers a pinned name.
  local _override="$HOME/.config/hypr/tablet-devices.conf"
  [[ -f $_override ]] && source "$_override"

  export TABLET_FINGER TABLET_FINGER_KERNEL TABLET_KBD TABLET_PAD TABLET_OUTPUT
}

# Best-effort detect at source time; consumers in boot-time services
# (auto-rotate) call tablet_detect again once the compositor is reachable.
tablet_detect
