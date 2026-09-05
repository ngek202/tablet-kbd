# Convertible Tablet + Custom OSK (Dynabook Portege X30W-J, Omarchy/Hyprland)

From-scratch on-screen keyboard (GTK4 + `wtype`) and finger-tablet wiring
for a convertible with no kernel fold signal.

## Layout

- `kbd/` — custom keyboard: `custom-kbd.py`, `custom-kbd-toggle.sh`,
  `osk-toggle.sh` (backend dispatcher), `layouts/en.json`
- `tablet/` — tablet wiring: `tablet-mode.sh`, `touch-gestures.sh`
  (lisgd), `auto-rotate.sh`, `tablet-auto-exit.py`, `tablet.lua`,
  legacy toggles (`squeekboard-`, `wvkbd-`, `touch-toggle.sh`),
  `units/` (systemd user services)
- `docs/` — `TABLET.md` (machine changelog); master plan lives next
  to this repo as `KEYBOARD-PLAN.md`

## Status

Phase 1–3 built and hands-on verified (see plan checklist).
Live files in `~/.config` are canonical until the Phase 4 installer
lands; this repo mirrors them — every change set is copied here and
committed (`~/backups/*.tgz` remain the restore path).

## Restore (current discipline)

- Config regression: `tar -xzf ~/backups/<step>.tgz -C ~`,
  then `hyprctl reload` (+ `systemctl --user restart` for services).
- Never `rm -rf`; per-file `.bak.<ts>` before edits.
