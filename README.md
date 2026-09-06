# Convertible Tablet + Custom OSK

From-scratch on-screen keyboard (GTK4 + `wtype`) and finger-tablet wiring
for a convertible with no kernel fold signal. Built and tested on a
Dynabook Portege X30W-J running Omarchy/Hyprland.

- **License:** GPL-3.0 (see `LICENSE`)
- **Companion bar-widget:** https://github.com/ngek202/tablet-toggle (separate repo)

## Install

```bash
git clone https://github.com/ngek202/tablet-kbd.git && ./tablet-kbd/install.sh
```

The installer is idempotent and backs up anything it replaces. It:

1. Installs missing dependencies.
2. Copies the keyboard, layouts, tablet wiring, systemd units, and the
   report-only post-update hook.
3. Adds only missing owned-file wiring (the `hypr.tablet` require, the
   tablet/OSK binds, the touchpad settings) — additive, never rewriting
   your content. If an anchor is unfamiliar it prints what to paste
   instead of guessing.
4. Pins the custom OSK as default.
5. Runs the verify check at the end — it fails loudly if not green.

Coexistence, not conquest: existing keyboards are left untouched and
remain selectable via `OSK_BACKEND`; ours is pinned as default.

## Requirements

Installer pulls these automatically (Arch-based system):

- **Official repos:** `wtype`, `python-gobject`, `gtk4`, `gtk4-layer-shell`
- **AUR (via `yay`):** `lisgd` (the gesture daemon)

## Usage

- **On-screen keyboard:** toggle with `SUPER+B` (dispatches via
  `osk-toggle.sh`; backend chosen by `OSK_BACKEND`).
- **Tablet mode:** toggle with `SUPER+SHIFT+T` or the bar-widget
  companion. Entering/leaving runs the tablet wiring (auto-rotate,
  gesture orientation, touch cursor).
- **Exit tablet mode:** 4-finger swipe inward from the **left** visual
  edge (orientation-aware via `-o`).
- **Other keyboards:** set `OSK_BACKEND=squeekboard` (or `wvkbd`) in the
  environment to use a fallback; the custom engine remains the default.

## Health check

`tablet-verify.sh` runs a read-only report (exit 0 = green). Run it with
`--fix` for mechanical repairs only (re-apply the require line, restore
exec bits) — never binding semantics. `tablet-verify-interactive.sh`
runs the check and offers `--fix` only if problems are found.

The installer also ships a report-only `post-update.d` hook that notifies
(never auto-repairs) if the stack breaks after an Omarchy update.

## Layout

- `kbd/` — custom keyboard: `custom-kbd.py`, `custom-kbd-toggle.sh`,
  `osk-toggle.sh` (backend dispatcher), `layouts/en.json`
- `tablet/` — tablet wiring: `tablet-mode.sh`, `tablet-modwait.py`,
  `tablet-auto-exit.py`, `touch-gestures.sh` (lisgd), `auto-rotate.sh`,
  `touch-cursor.py`, `touch-toggle.sh`, `tablet.lua`, `tablet-verify.sh`,
  `tablet-verify-interactive.sh`, legacy toggles (`squeekboard-`,
  `wvkbd-`), `units/` (systemd user services)
- `hooks/` — `tablet-verify.hook` (report-only post-update check)
- `install.sh` — the installer

## Restore / safety

- Config regression: `tar -xzf ~/backups/<step>.tgz -C ~`, then
  `hyprctl reload` (+ `systemctl --user restart` for services).
- Never `rm -rf`; per-file `.bak.<ts>` before edits.
