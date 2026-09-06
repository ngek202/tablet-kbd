# Convertible Tablet + SAM OSK

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-ngek202-yellow)](https://www.buymeacoffee.com/ngek202)

**SAM OSK** — a from-scratch on-screen keyboard (GTK4 + `wtype`) — plus
finger-tablet wiring for convertible laptops with no kernel fold signal.

Device names are **detected at runtime, not hardcoded** (see *Devices*
below), so the package is not bound to one model. Developed and tested
on a Dynabook Portege X30W-J running Omarchy/Hyprland.

- **License:** GPL-3.0 (see `LICENSE`)
- **Companion bar-widget:** https://github.com/ngek202/tablet-toggle (separate repo)

## Install

```bash
git clone https://github.com/ngek202/tablet-kbd.git && ./tablet-kbd/install.sh
```

The installer is idempotent and backs up anything it replaces. It:

1. Installs missing dependencies.
2. Copies SAM OSK, its layouts, the tablet wiring, systemd units, and the
   report-only post-update hook.
3. Detects your devices (touch / keyboard / touchpad / internal display)
   and writes them to generated files — see *Devices*.
4. Adds only missing owned-file wiring (the `hypr.tablet` require, the
   tablet/OSK binds, the touchpad settings) — additive, never rewriting
   your content. If an anchor is unfamiliar it prints what to paste
   instead of guessing.
5. Pins SAM OSK as the default backend.
6. Runs the verify check at the end — it fails loudly if not green.

Coexistence, not conquest: existing keyboards are left untouched and
remain selectable via `OSK_BACKEND`; SAM OSK is pinned as default.

## Requirements

- A **convertible laptop** with a touch digitizer (internal display
  preferred for rotation)
- Arch-based system (Omarchy recommended)
- Installer pulls these automatically:
  - **Official repos:** `wtype`, `python-gobject`, `gtk4`, `gtk4-layer-shell`
  - **AUR (via `yay`):** `lisgd` (the gesture daemon)

## Usage

- **SAM OSK (on-screen keyboard):** toggle with `SUPER+B`, or tap it in
  the bar via the companion widget. Dispatch goes through
  `osk-toggle.sh`; the backend is chosen by `OSK_BACKEND`.
- **Tablet mode:** toggle with `SUPER+SHIFT+T` or the bar-widget
  companion. Entering/leaving runs the tablet wiring: internal keyboard
  and touchpad off, auto-rotate on, gesture orientation, touch cursor.
- **Exit tablet mode:** 3-finger swipe inward from the **left or right**
  visual edge (orientation-aware) — or the 4-finger left-edge swipe
  (kept as the original emergency exit) — or `SUPER+SHIFT+T` while a
  keyboard is live. The edge swipes are dual-mode: in laptop mode they
  scroll window-pages instead.
- **Gestures (finger):** 3-finger left/right = scroll to the previous/
  next window-page (scrolling layout; works in all modes — in laptop
  mode too). Swipe up from the bottom edge = summon SAM OSK; 3-finger
  up anywhere = toggle it.
- **Pen users:** `touch-toggle.sh off` disables finger touch for palm
  rejection (pen keeps working); `on` restores it.
- **Other keyboards:** set `OSK_BACKEND=squeekboard` (or `wvkbd`) in the
  environment to use a fallback; SAM OSK remains the default.

## Devices (auto-detection)

Device names vary per convertible, so nothing is hardcoded:

- Shell scripts source `tablet-devices.sh`, which detects the touch
  digitizer, internal keyboard, touchpad (if any), and internal display
  via `hyprctl` at runtime.
- `tablet.lua` reads the installer-generated `~/.config/hypr/tablet-devices.lua`.
- **Overrides:** if detection guesses wrong on your hardware, pin names
  in `~/.config/hypr/tablet-devices.conf` (created as a commented
  template on install; it always wins). Find candidate names with
  `hyprctl devices`.

## Health check

`tablet-verify.sh` runs a read-only report (exit 0 = green). Run it with
`--fix` for mechanical repairs only (re-apply the require line, restore
exec bits, regenerate the devices files) — never binding semantics.
`tablet-verify-interactive.sh` runs the check and offers `--fix` only if
problems are found.

The installer also ships a report-only `post-update.d` hook that notifies
(never auto-repairs) if the stack breaks after an Omarchy update.

## Layout

- `kbd/` — SAM OSK: `custom-kbd.py`, `custom-kbd-toggle.sh`,
  `osk-toggle.sh` (backend dispatcher), `layouts/en.json`
- `tablet/` — tablet wiring: `tablet-mode.sh`, `tablet-modwait.py`,
  `tablet-auto-exit.py`, `touch-gestures.sh` (lisgd), `auto-rotate.sh`,
  `touch-cursor.py`, `touch-toggle.sh`, `tablet.lua`,
  `tablet-devices.sh` (detection), `tablet-verify.sh`,
  `tablet-verify-interactive.sh`, `page-switch.sh` (page scrolling),
  legacy toggles (`squeekboard-`,
  `wvkbd-`), `units/` (systemd user services)
- `hooks/` — `tablet-verify.hook` (report-only post-update check)
- `install.sh` — the installer

## Restore / safety

- The installer backs up anything it replaces (`.bak.<ts>` beside the
  file). To undo a specific file: copy the `.bak` back, then
  `hyprctl reload` (+ `systemctl --user restart` for services).
- Owned-file wiring is additive only; your own Hyprland content is
  never rewritten.
- To remove the stack: disable the three units
  (`systemctl --user disable --now auto-rotate lisgd-gestures
  touch-cursor`), delete the `hypr.tablet` require line and the added
  binds, and set `OSK_BACKEND=squeekboard` (or remove the keybind) —
  or just switch `OSK_BACKEND` and keep it around as a fallback.
