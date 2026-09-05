#!/bin/bash
# Auto-rotate eDP-1 + finger touch together from the accelerometer.
# Tablet-only build: pen deferred until pen returns.
# Reads orientation lines from monitor-sensor (iio-sensor-proxy).
# Mapping (verified by finger-tap test, adjust if taps land rotated):
#   normal=0, left-up=1, bottom-up=2, right-up=3
set -u

MONITOR="eDP-1"
FINGER="wacom-hid-5272-finger"
LOG="$HOME/.local/state/omarchy/auto-rotate.log"

# hyprctl needs the instance signature. Resolve it LAZILY on every apply:
# at boot this service can start before Hyprland creates its socket, and a
# once-at-startup resolution then stays broken until manual restart (seen
# 2026-09-05: post-reboot applies all failed with "not set!"). resolve_sig
# is cheap (one ls) and re-runs whenever the var is empty; apply() retries
# once after re-resolving if hyprctl reports a stale/missing signature.
resolve_sig() {
  [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && return 0
  local sig_dir="/run/user/$(id -u)/hypr" newest=""
  if [[ -d $sig_dir ]]; then
    newest=$(ls -t "$sig_dir" 2>/dev/null | head -n 1)
  fi
  [[ -n $newest ]] && export HYPRLAND_INSTANCE_SIGNATURE="$newest"
  [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]
}

_hyprctl_eval() {
  # $1 = lua expression. Prints hyprctl output. Retries once with a fresh
  # signature if hyprctl complains the signature is missing/stale.
  local out
  out=$(hyprctl eval "$1" 2>&1)
  if [[ $out == *"HYPRLAND_INSTANCE_SIGNATURE"* ]]; then
    HYPRLAND_INSTANCE_SIGNATURE=""
    if resolve_sig; then
      out=$(hyprctl eval "$1" 2>&1)
    fi
  fi
  printf '%s' "$out"
}

apply() {
  local t=$1
  local m_out f_out
  resolve_sig || true
  # Preserve the user's scale: a transform-only hl.monitor eval resets
  # scale to Hyprland auto (1.5 on this panel — seen 2026-09-05). Read the
  # live scale and pass it back with the transform.
  local scale
  scale=$(hyprctl monitors -j 2>/dev/null | jq -r --arg m "$MONITOR" \
    '.[] | select(.name == $m) | .scale // empty')
  [[ $scale =~ ^[0-9]+(\.[0-9]+)?$ ]] || scale="1.25"
  m_out=$(_hyprctl_eval "hl.monitor({ output = \"$MONITOR\", transform = $t, scale = $scale })")
  f_out=$(_hyprctl_eval "hl.device({ name = \"$FINGER\", transform = $t })")
  printf '%s apply transform=%s scale=%s monitor=[%s] finger=[%s]\n' \
    "$(date +%H:%M:%S)" "$t" "$scale" "$m_out" "$f_out" >>"$LOG"
  # lisgd edge gestures are kernel-fixed: rebind summon/exit to the new
  # visual bottom/top via lisgd's own -o frame rotation. The service stays
  # the single owner of the daemon (a detached spawn here would fight it —
  # seen 2026-09-05: service restarts wiped the mapping twice). Restart it
  # with the orientation in its environment instead.
  if [[ $m_out == "ok" ]]; then
    systemctl --user set-environment ORIENTATION="$t" 2>/dev/null
    systemctl --user restart lisgd-gestures.service 2>/dev/null || \
      ORIENTATION="$t" setsid -f "$HOME/.config/hypr/scripts/touch-gestures.sh" \
        >/dev/null 2>&1 &
  fi
}

# Exact-name match only: -f patterns here would match our own shell's
# command line (it contains these words) and kill it.
pkill -x monitor-sensor 2>/dev/null || true

# stdbuf: monitor-sensor block-buffers when piped, so orientation lines
# would sit in libc's buffer and the service would never react. Unbuffer it.
stdbuf -o0 -e0 monitor-sensor 2>/dev/null | while read -r line; do
  case "$line" in
    *"orientation changed: normal"*) printf '%s event: normal\n' "$(date +%H:%M:%S)" >>"$LOG"; apply 0 ;;
    *"orientation changed: left-up"*) printf '%s event: left-up\n' "$(date +%H:%M:%S)" >>"$LOG"; apply 1 ;;
    *"orientation changed: bottom-up"*) printf '%s event: bottom-up\n' "$(date +%H:%M:%S)" >>"$LOG"; apply 2 ;;
    *"orientation changed: right-up"*) printf '%s event: right-up\n' "$(date +%H:%M:%S)" >>"$LOG"; apply 3 ;;
  esac
done
