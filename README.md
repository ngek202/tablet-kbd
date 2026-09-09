# Convertible Tablet + SAM OSK

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-ngek202-yellow)](https://www.buymeacoffee.com/ngek202)

**For the moments your laptop becomes a tablet** — presenting, notes in
meetings, reading, watching, or just lounging with touch. Built for 2-in-1
**convertible laptops** on **Omarchy / Hyprland** (Arch-based, Wayland),
especially machines without a working kernel fold/tablet-mode switch:
fold the laptop, get a touch-first desktop.

**What you get:**

- **SAM OSK** — from-scratch GTK4 on-screen keyboard: Shift latch +
  Caps double-tap, symbols page, hold-repeat, split thumb layout (`⇄`),
  **never steals focus**
- **Tablet mode** — internal keyboard + touchpad off, auto-rotate via
  accelerometer, orientation-aware gestures, double-tap cursor warp +
  window focus
- **Page scrolling** — 3-finger swipes switch workspaces (scrolling-layout
  pages) in any mode
- **Self-healing** — device auto-detection (override file for odd
  hardware), health check with interactive repair, post-update
  protection hook

**Support & limitations:** Omarchy 4.x / Hyprland (Wayland) — X11 and
other compositors untested. Touch digitizer required. **Pen:**
palm-rejection toggle only today — full pen support is a parked future
update. **Omarchy ships no OSK by default** — installing this gives you
one. **No fold signal, no auto-entry:** this hardware class reports no
kernel tablet-mode switch, so folding cannot auto-trigger tablet mode —
and orientation heuristics can't tell folding apart from tent mode or
sideways reading (they'd falsely disable your keyboard). Tablet mode is
one tap away (`SUPER+SHIFT+T` or the bar widget); the screen still
auto-rotates when you fold.

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

Coexistence, not conquest: on machines that already have an OSK it's
left untouched and selectable via `OSK_BACKEND`; on Omarchy — which
ships none — SAM OSK becomes your first.

## Requirements

- A **convertible laptop** with a touch digitizer (internal display
  preferred for rotation)
- Arch-based system (Omarchy recommended)
- Installer pulls these automatically:
  - **Official repos:** `wtype`, `python-gobject`, `gtk4`, `gtk4-layer-shell`
  - **AUR (via `yay`):** `lisgd` (the gesture daemon)

## Usage

| Action | How |
|---|---|
| **SAM OSK** | `SUPER+B` · or tap the bar widget |
| **Tablet mode** | `SUPER+SHIFT+T` · or the bar widget |
| **Exit tablet mode** | 3-finger swipe inward from **left or right** edge · 4-finger left-edge · `SUPER+SHIFT+T` (keyboard live) |
| **Scroll pages** | 3-finger swipe left/right = switch to the previous/next workspace (window-page in scrolling layout) — anywhere, any mode |
| **Switch window** | Double-tap a window (touch) — cursor warps + window focuses |
| **Summon SAM OSK** | Swipe up from bottom edge · 3-finger up |
| **Pen palm-rejection** | `touch-toggle.sh off` (finger off, pen works) · `on` restores |
| **Fallback keyboard** | `OSK_BACKEND=squeekboard` / `wvkbd` — install one first (Omarchy ships none) |

Entering tablet mode: internal keyboard + touchpad off, auto-rotate on,
gestures orientation-aware, touch cursor active.

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
  legacy toggles (`squeekboard-`, `wvkbd-`), `units/` (systemd user
  services)
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
  binds, and remove the `SUPER+B` keybind. Note: Omarchy ships no OSK,
  so after removal there is no on-screen keyboard unless you install an
  alternative first (e.g. `sudo pacman -S squeekboard`, then set
  `OSK_BACKEND=squeekboard`) — or keep this stack installed and just
  switch `OSK_BACKEND` when you want a different engine.
