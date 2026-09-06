#!/bin/bash
# tablet-verify.sh — verify-only health check for the tablet + OSK stack.
# Read-only by default (exit 0 = healthy, exit 1 = problems found).
# With --fix: re-apply ONLY mechanical repairs (require line, exec bits).
# Never rewrites binding semantics — owned-lua content stays yours.
set -u

HYPR="$HOME/.config/hypr"
HOOK_MODE="${TABLET_VERIFY_HOOK:-0}"
FAIL=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAIL=1; }

grep_q() { grep -qF "$1" "$2" 2>/dev/null; }

# --- 1. Owned-lua markers (what refresh-hyprland overwrites) ---
if grep_q 'require("hypr.tablet")' "$HYPR/hyprland.lua"; then
  pass "hyprland.lua requires hypr.tablet"
else
  fail "hyprland.lua missing require(\"hypr.tablet\")"
  if [[ "${1:-}" == "--fix" ]]; then
    # Appended at EOF (original sits ~line 21); equivalent — tablet.lua
    # is self-contained (boot cleanup + no_focus rules, no ordering deps).
    echo 'require("hypr.tablet")' >> "$HYPR/hyprland.lua"
    echo "FIXED: require line re-appended"
  fi
fi

if grep_q 'tablet-mode.sh toggle' "$HYPR/bindings.lua" && \
   grep_q 'osk-toggle.sh' "$HYPR/bindings.lua"; then
  pass "bindings.lua tablet + OSK binds present"
else
  fail "bindings.lua tablet/OSK binds missing (manual restore — semantics, not mechanical)"
fi

if grep_q 'natural_scroll = true' "$HYPR/input.lua" && \
   grep_q 'disable_while_typing = false' "$HYPR/input.lua"; then
  pass "input.lua touchpad settings present"
else
  fail "input.lua touchpad settings missing (manual restore)"
fi

[[ -f "$HYPR/tablet.lua" ]] \
  && pass "tablet.lua present" \
  || fail "tablet.lua missing"

# --- 2. Scripts executable ---
for s in tablet-mode.sh tablet-modwait.py tablet-auto-exit.py touch-gestures.sh \
         auto-rotate.sh touch-cursor.py osk-toggle.sh custom-kbd.py custom-kbd-toggle.sh; do
  if [[ -x "$HYPR/scripts/$s" ]]; then
    pass "exec $s"
  else
    fail "not executable: $s"
    if [[ "${1:-}" == "--fix" && -f "$HYPR/scripts/$s" ]]; then
      chmod +x "$HYPR/scripts/$s" && echo "FIXED: chmod +x $s"
    fi
  fi
done

# --- 3. State + layout sanity ---
BACKEND="$(cat "$HOME/.local/state/omarchy/toggles/hypr/osk-backend" 2>/dev/null || echo custom)"
case "$BACKEND" in
  custom|squeekboard|wvkbd) pass "osk-backend=$BACKEND" ;;
  *) fail "osk-backend invalid: $BACKEND" ;;
esac

if python3 -c "import json;json.load(open('$HYPR/kbd-layouts/en.json'))" 2>/dev/null; then
  pass "en.json parses"
else
  fail "en.json invalid JSON"
fi

# --- 4. Systemd units enabled ---
for u in auto-rotate.service lisgd-gestures.service touch-cursor.service; do
  if systemctl --user is-enabled "$u" >/dev/null 2>&1; then
    pass "unit enabled $u"
  else
    fail "unit not enabled: $u"
  fi
done

# --- 5. Bar toggle placement (warn-only: user may move it deliberately) ---
if python3 -c "
import json,sys
cfg=json.load(open('$HOME/.config/omarchy/shell.json'))
blob=json.dumps(cfg)
sys.exit(0 if 'io.github.ngek202.tablet-toggle' in blob else 1)" 2>/dev/null; then
  pass "toggle widget placed in bar"
else
  echo "WARN: toggle widget id not found in shell.json (ok if moved/removed deliberately)"
fi

if [[ "$FAIL" -eq 0 ]]; then
  echo "tablet-verify: ALL GREEN"
else
  echo "tablet-verify: PROBLEMS FOUND (run with --fix for mechanical repairs)"
fi
exit "$FAIL"
