#!/bin/bash
# tablet-kbd-uninstall — remove the per-user tablet-kbd setup.
# Reverses install.sh: units, post-update hook, installed files, the
# additive wiring blocks (backed up first — your own content is never
# touched), state files, private logs, and the usage-guide window.
# Idempotent: missing files are skipped. AUR installs also run
# `sudo pacman -R tablet-kbd-git` to remove the system share.
# Usage: tablet-kbd-uninstall
set -u

HYPR="$HOME/.config/hypr"
SCRIPTS="$HYPR/scripts"
UNITDIR="$HOME/.config/systemd/user"
HOOKDIR="$HOME/.config/omarchy/hooks/post-update.d"
STATE="$HOME/.local/state/omarchy/toggles/hypr"
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/tablet-kbd"

say() { echo "-- $1"; }

# 1. Stop + disable + remove the units
say "units"
for u in auto-rotate.service lisgd-gestures.service touch-cursor.service; do
  systemctl --user disable --now "$u" >/dev/null 2>&1 && echo "  disabled $u" || true
done
rm -f "$UNITDIR/auto-rotate.service" "$UNITDIR/lisgd-gestures.service" \
      "$UNITDIR/touch-cursor.service"
systemctl --user daemon-reload
echo "  unit files removed"

# 2. Remove the post-update hook
rm -f "$HOOKDIR/tablet-verify.hook" && echo "hook removed"

# 3. Close the usage-guide window + SAM OSK if open
pkill -f "title=SAM OSK Usage" 2>/dev/null || true
pkill -f "custom-kbd" 2>/dev/null || true

# 4. Remove the installed files (exact list — your own files stay)
say "files"
for f in tablet-mode.sh tablet-modwait.py tablet-auto-exit.py touch-gestures.sh \
         auto-rotate.sh touch-cursor.py touch-toggle.sh osk-toggle.sh \
         custom-kbd.py custom-kbd-toggle.sh squeekboard-toggle.sh wvkbd-toggle.sh \
         tablet-verify.sh tablet-verify-interactive.sh tablet-devices.sh \
         page-switch.sh tablet-kbd-uninstall.sh; do
  rm -f "$SCRIPTS/$f"
done
rm -rf "$HYPR/kbd-layouts" "$LOG_DIR"
rm -f "$STATE/osk-backend" "$STATE/tablet-mode-on" "$STATE/touch-off" \
      "$STATE/tablet-draw-on"
echo "  installed files, layouts, state, logs removed"
echo "  note: .bak backups are kept (your restore path)"

# 5. Strip the owned wiring (additive blocks this package added — backed up)
say "wiring"
bak() {
  local f
  local b
  f="$1"
  b="$1.uninstall-backup.$(date +%s)"
  cp "$1" "$b" && echo "  backup: $b"
}

if [[ -f "$HYPR/hyprland.lua" ]] && grep -qE '^[[:space:]]*require\("hypr\.tablet"\)' "$HYPR/hyprland.lua"; then
  bak "$HYPR/hyprland.lua"
  sed -i '/^[[:space:]]*require("hypr\.tablet")$/d' "$HYPR/hyprland.lua"
  echo "  removed: hypr.tablet require"
fi

if [[ -f "$HYPR/bindings.lua" ]] && grep -q 'tablet-mode.sh toggle' "$HYPR/bindings.lua"; then
  bak "$HYPR/bindings.lua"
  sed -i '/^-- Tablet mode + OSK (tablet-kbd package/,/touch-toggle.sh toggle"$/d' "$HYPR/bindings.lua"
  if grep -q 'tablet-mode.sh toggle' "$HYPR/bindings.lua"; then
    echo "  WARN: some tablet binds remain outside the known block — see the .bak"
  else
    echo "  removed: tablet binds block"
  fi
fi

if [[ -f "$HYPR/input.lua" ]] && grep -q 'tablet-kbd package (additive standalone block' "$HYPR/input.lua"; then
  bak "$HYPR/input.lua"
  START=$(grep -n 'tablet-kbd package (additive standalone block' "$HYPR/input.lua" | cut -d: -f1)
  END=$(awk -v s="$START" 'NR>=s && /^\}[)]/{print NR; exit}' "$HYPR/input.lua")
  if [[ -n $START && -n $END ]]; then
    sed -i "${START},${END}d" "$HYPR/input.lua"
    echo "  removed: touchpad settings block"
  fi
fi

# 6. Validate + reload
BAD=0
for f in "$HYPR/hyprland.lua" "$HYPR/bindings.lua" "$HYPR/input.lua"; do
  [[ -f $f ]] && { luac -p "$f" 2>/dev/null || { echo "WARN: $f failed the Lua syntax check — restore from the .uninstall-backup"; BAD=1; }; }
done
hyprctl reload >/dev/null 2>&1 || true

echo
if [[ $BAD -eq 0 ]]; then
  echo "tablet-kbd per-user setup removed. Hyprland reloaded."
else
  echo "tablet-kbd removed WITH WARNINGS — check the files above."
fi
echo "Also consider:"
echo "  omarchy plugin remove io.github.ngek202.tablet-toggle   (the bar widget)"
echo "  sudo pacman -R tablet-kbd-git                           (AUR: system share)"
echo "Note: Omarchy ships no OSK by default — after this there is no"
echo "on-screen keyboard unless you install an alternative."
