#!/bin/bash
# install.sh — tablet-kbd share package installer.
# Coexistence, not conquest: never installs/removes other OSK software,
# only adds missing marker lines (backed up, idempotent), pins `custom`
# as the default backend, and ends verify-green-or-loud-fail.
set -u

REPO="$(cd "$(dirname "$0")" && pwd)"
HYPR="$HOME/.config/hypr"
HOOKDIR="$HOME/.config/omarchy/hooks/post-update.d"
UNITDIR="$HOME/.config/systemd/user"
STATE="$HOME/.local/state/omarchy/toggles/hypr"
FAIL=0

say()  { echo "-- $1"; }
ok()   { echo "OK: $1"; }
skip() { echo "SKIP: $1"; }

bak() {
  local f="$1" b="$1.bak.$(date +%s)"
  cp "$f" "$b" && echo "backup: $b"
}

# Copy repo→live unless live is NEWER (unmirrored live edits exist).
# Identical content skips silently (no .bak churn on reinstall).
sync_file() {
  local src="$1" dst="$2" mode="${3:-}"
  if [[ -f "$dst" ]]; then
    if cmp -s "$src" "$dst"; then skip "$(basename "$dst") identical"; return 0; fi
    if [[ "$dst" -nt "$src" ]]; then
      echo "FATAL: live $(basename "$dst") is newer than repo copy — mirror live→repo first, then re-run"
      exit 1
    fi
    bak "$dst" >/dev/null
  fi
  cp "$src" "$dst" || { echo "FATAL: cannot copy $src"; exit 1; }
  [[ -n "$mode" ]] && chmod "$mode" "$dst"
  ok "$(basename "$dst") installed"
}

# --- 1. Dependencies (Arch-native: pacman, yay for AUR) ---
say "dependencies"
OFFICIAL=(wtype python-gobject gtk4 gtk4-layer-shell)
MISSING=()
for p in "${OFFICIAL[@]}"; do
  pacman -Q "$p" >/dev/null 2>&1 && ok "$p present" || MISSING+=("$p")
done
if pacman -Q lisgd >/dev/null 2>&1; then
  ok "lisgd present"
else
  MISSING_AUR=(lisgd)
fi
if [[ "${#MISSING[@]}" -gt 0 ]]; then
  say "installing missing official packages: ${MISSING[*]}"
  sudo pacman -S --needed "${MISSING[@]}" || { echo "FATAL: pacman install failed"; exit 1; }
fi
if [[ "${MISSING_AUR:-unset}" != "unset" ]]; then
  say "installing missing AUR packages: ${MISSING_AUR[*]}"
  yay -S --needed "${MISSING_AUR[@]}" || { echo "FATAL: yay install failed"; exit 1; }
fi

# --- 2. Files (ours outright; backup anything in the way) ---
say "files"
mkdir -p "$HYPR/scripts" "$HYPR/kbd-layouts" "$HOOKDIR" "$UNITDIR" "$STATE"
for s in tablet-mode.sh tablet-modwait.py tablet-auto-exit.py touch-gestures.sh \
         auto-rotate.sh touch-cursor.py touch-toggle.sh osk-toggle.sh \
         custom-kbd.py custom-kbd-toggle.sh squeekboard-toggle.sh wvkbd-toggle.sh \
         tablet-verify.sh tablet-verify-interactive.sh; do
  src=""
  [[ -f "$REPO/tablet/$s" ]] && src="$REPO/tablet/$s"
  [[ -f "$REPO/kbd/$s" ]] && src="$REPO/kbd/$s"
  [[ -z "$src" ]] && { echo "FATAL: $s not in repo"; exit 1; }
  sync_file "$src" "$HYPR/scripts/$s" "+x"
done
[[ -f "$REPO/kbd/layouts/en.json" ]] || { echo "FATAL: en.json not in repo"; exit 1; }
sync_file "$REPO/kbd/layouts/en.json" "$HYPR/kbd-layouts/en.json"
sync_file "$REPO/tablet/tablet.lua" "$HYPR/tablet.lua"
for u in auto-rotate.service lisgd-gestures.service touch-cursor.service; do
  sync_file "$REPO/tablet/units/$u" "$UNITDIR/$u"
done
systemctl --user daemon-reload
for u in auto-rotate.service lisgd-gestures.service touch-cursor.service; do
  systemctl --user enable --now "$u" && ok "enabled $u" || { echo "FATAL: cannot enable $u"; exit 1; }
done
cp "$REPO/hooks/tablet-verify.hook" "$HOOKDIR/tablet-verify.hook" \
  && chmod +x "$HOOKDIR/tablet-verify.hook" && ok "post-update hook (report-only)"

# --- 3. Owned-file wiring (additive-only, idempotent) ---
say "owned wiring"
if grep -qF 'require("hypr.tablet")' "$HYPR/hyprland.lua"; then
  skip "hyprland.lua require present"
else
  bak "$HYPR/hyprland.lua"
  echo 'require("hypr.tablet")' >> "$HYPR/hyprland.lua"
  luac -p "$HYPR/hyprland.lua" 2>/dev/null && ok "hyprland.lua require added" \
    || { echo "FATAL: hyprland.lua broke syntax check — restore the .bak"; exit 1; }
fi

if grep -qF 'tablet-mode.sh toggle' "$HYPR/bindings.lua"; then
  skip "bindings.lua tablet binds present"
else
  bak "$HYPR/bindings.lua"
  cat >> "$HYPR/bindings.lua" <<'EOF'

-- Tablet mode + OSK (tablet-kbd package — additive, survives until next refresh).
o.bind("SUPER + SHIFT + T", "Tablet mode toggle", "~/.config/hypr/scripts/tablet-mode.sh toggle")
o.bind("SUPER + B", "On-screen keyboard", "~/.config/hypr/scripts/osk-toggle.sh")
o.bind("SUPER + SHIFT + P", "Finger touch toggle", "~/.config/hypr/scripts/touch-toggle.sh toggle")
EOF
  luac -p "$HYPR/bindings.lua" 2>/dev/null && ok "bindings.lua binds added" \
    || { echo "FATAL: bindings.lua broke syntax check — restore the .bak"; exit 1; }
fi

if grep -qF 'natural_scroll = true' "$HYPR/input.lua" && \
   grep -qF 'disable_while_typing = false' "$HYPR/input.lua"; then
  skip "input.lua touchpad settings active"
else
  bak "$HYPR/input.lua"
  cat >> "$HYPR/input.lua" <<'EOF'

-- tablet-kbd package (additive standalone block — merged with any above).
hl.config({
  input = {
    touchpad = {
      natural_scroll = true,
      clickfinger_behavior = true,
      -- Virtual-OSK key events trip libinput disable-while-typing;
      -- on a convertible the "typing" is often the OSK itself.
      disable_while_typing = false,
    },
  },
})
EOF
  if luac -p "$HYPR/input.lua" 2>/dev/null; then
    say "reloading hypr to effect-gate input settings"
    hyprctl reload >/dev/null 2>&1; sleep 2
    if hyprctl getoption input:touchpad:natural_scroll 2>/dev/null | grep -q "int: 1" && \
       hyprctl getoption input:touchpad:disable_while_typing 2>/dev/null | grep -q "int: 0"; then
      ok "input.lua touchpad settings active (effect-verified)"
    else
      echo "FALLBACK: settings appended but not effective — restoring backup, add manually:"
      LATEST=$(ls -t "$HYPR"/input.lua.bak.* | head -n 1); cp "$LATEST" "$HYPR/input.lua"
      echo "  hl.config({ input = { touchpad = { natural_scroll = true, clickfinger_behavior = true, disable_while_typing = false } } })"
      FAIL=1
    fi
  else
    echo "FALLBACK: input.lua broke syntax — restoring backup, add manually (see above)"
    LATEST=$(ls -t "$HYPR"/input.lua.bak.* | head -n 1); cp "$LATEST" "$HYPR/input.lua"
    FAIL=1
  fi
fi

# --- 4. Pin default (re-pin on reinstall is documented, not silent) ---
echo custom > "$STATE/osk-backend"
ok "backend pinned to custom (OSK_BACKEND still overrides per-shell)"

# --- 5. Coexistence report (detect only — never touch) ---
say "other keyboards (left untouched)"
for k in squeekboard wvkbd; do
  command -v "$k" >/dev/null 2>&1 \
    && echo "INFO: fallback present: $k (select via OSK_BACKEND=$k)" \
    || echo "INFO: fallback absent: $k (optional safety net: sudo pacman -S $k)"
done

# --- 6. Final gate ---
say "final verify"
if [[ "$FAIL" -ne 0 ]]; then
  echo "FATAL: manual fallback steps above are required, then re-run install.sh"
  exit 1
fi
"$HYPR/scripts/tablet-verify.sh" || { echo "FATAL: verify red — see FAIL lines above"; exit 1; }
echo "install.sh: ALL GREEN — install with:"
echo "  git clone https://github.com/ngek202/tablet-kbd.git && ./tablet-kbd/install.sh"
