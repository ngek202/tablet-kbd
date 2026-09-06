# Tablet Mode for Dynabook Portege X30W-J on Omarchy 4

> Hardware: Wacom 5272 pen + finger touch, hinge angle sensor `iio:device4`,
> accel/gyro, no `SW_TABLET_MODE` switch. Omarchy 4.0.2 / Hyprland 0.56.2 (Lua).
> Baseline 2026-09-05: `~/backups/tablet-baseline-20260905-071831.tgz` (sha256 `be1acc79…583509cb`, verified OK).
> Old snapshot `~/backups/tablet-work-20260903-165407.tgz` is missing — do not reference it for restore.

## Baseline & restore (2026-09-05, tablet-only focus, pen deferred)

- Baseline tgz contains: `.config/hypr/` (all lua/conf/scripts/TABLET.md), `.config/omarchy/shell.json`, `.config/omarchy/shell.toml`, `.config/systemd/user/auto-rotate.service`, `.local/state/omarchy/toggles/hypr/`.
- Known state at baseline: `tablet.lua` missing, `wvkbd`/`iio-sensor-proxy`/`monitor-sensor` not installed, `auto-rotate.service` present but disabled, scripts (`tablet-draw.sh`, `touch-toggle.sh`, `osk-toggle.sh`, `auto-rotate.sh`, `tablet-exit.py`) present.
- Verify: `sha256sum -c ~/backups/tablet-baseline-20260905-071831.tgz.sha256`
- Restore full: `tar -xzf ~/backups/tablet-baseline-20260905-071831.tgz -C ~ && hyprctl reload && hyprctl configerrors && omarchy restart shell`
- Restore single file: `tar -xzOf ~/backups/tablet-baseline-20260905-071831.tgz .config/hypr/bindings.lua > ~/.config/hypr/bindings.lua && hyprctl reload`
- Change rule going forward: per-file `.bak.YYYYMMDD-HHMMSS` before each edit + new `~/backups/tablet-<step>-<ts>.tgz` after each working step + one line below.

## Change log (newest first)

| Date (UTC) | Change | Files | Backup | Verified |
|---|---|---|---|---|
| 2026-09-05 07:18 | Baseline snapshot before tablet-only work (pen deferred) | `hypr/*`, `shell.json/toml`, `auto-rotate.service`, toggle state | `tablet-baseline-20260905-071831.tgz` | sha OK, extract diff clean |
| 2026-09-05 07:25 | Tablet-only build: `tablet-mode.sh` + `tablet.lua` (finger-only, boot-safe), `squeekboard-toggle.sh`, `touch-gestures.sh`, bindings `SUPER+SHIFT+T/B/SHIFT+P`, `auto-rotate.sh` pen removed, `hyprland.lua` requires tablet, guarded lisgd autostart | `tablet.lua`, `scripts/tablet-mode.sh`, `scripts/squeekboard-toggle.sh`, `scripts/touch-gestures.sh`, `scripts/auto-rotate.sh`, `bindings.lua`, `hyprland.lua`, `autostart.lua` | `tablet-tabletmode-20260905-072548.tgz` | `hyprctl reload` ok, `configerrors` clean, on/off cycle verified, bindings listed |
| 2026-09-05 07:29 | Packages live: `iio-sensor-proxy` (active, accel `normal`), `squeekboard` (starts/kills clean), `lisgd` (runs with input group), `auto-rotate.service` enabled+active, user added to `input` group (re-login required), `touch-gestures.sh` readability guard | `scripts/touch-gestures.sh` | `tablet-packages-20260905-072917.tgz` | tablet on/off with real OSK+overlay verified, lisgd 4s run clean via input group, reload clean |
| 2026-09-05 07:36 | EXIT pill replaced by gesture: 4-finger swipe down from top edge exits tablet (guarded no-op in laptop mode), overlay unhooked from `tablet-mode.sh`, `tablet-exit.py` kept as manual fallback + fixed to call `tablet-mode.sh` | `scripts/touch-gestures.sh`, `scripts/tablet-mode.sh`, `scripts/tablet-exit.py` | `tablet-gesture-exit-20260905-073631.tgz` | gesture command verified on/off/no-op end-to-end, screenshot confirms no pill, reload clean. NOTE: lisgd needs re-login (input group) before swipe works |
| 2026-09-05 08:49 | Touchpad-stranded repair: `tablet-mode.sh` hardened (exit-checked evals, signature resolve for gesture context, state file only on full success, `hyprctl reload` fallback + critical alert on off-failure), Squeekboard toggle rewritten to DBus show/hide (`SetVisible`, persistent process, cold-start path) | `scripts/tablet-mode.sh`, `scripts/squeekboard-toggle.sh`, `scripts/tablet-auto-exit.py` (stub cleaned) | `tablet-repair-20260905-084954.tgz` (pre: `tablet-prerepair-20260905-084813.tgz`) | Squeekboard visible screenshot OK, toggle hidden/visible/cold-start verified, 3x on/off round-trips exit 0, signature-less off exit 0, reload clean |
| 2026-09-05 09:06 | Reverted corner right-click to default: `clickfinger_behavior` false→true (suspect in single-finger issue; user accepted two-finger right-click). `natural_scroll=true` kept | `input.lua` | `tablet-clickfinger-revert-20260905-090657.tgz` (pre: `tablet-prerevert-20260905-090657.tgz`) | reload ok, configerrors clean. CONFIRMED by user hands-on: single finger fully back. Culprit was `clickfinger_behavior=false` on Hyprland 0.56 (killed single-finger incl. motion, undocumented). Corner right-click stays reverted; two-finger right-click is the way |
| 2026-09-05 ~09:15 | EC fold test (no tablet mode): pad+kbd die on 360° fold, return normally on unfold. Firmware cooperates — no stuck EC. Decision: keep script pad/kbd management (needed for unfolded tablet use; mechanism never proven broken, clickfinger explained the symptoms) | — (no code change) | — | User-tested both directions |
| 2026-09-05 09:32 | Squeekboard Shift fix attempt: `input:virtualkeyboard:share_states=true` (option read from Hyprland 0.56.2 binary). fcitx5 confirmed Wayland-OSK-dead-end (no UI upstream); opencode-desktop confirmed Electron w/o `--enable-wayland-ime` (no text-input events possible) | `input.lua` | `tablet-sharestates-20260905-093206.tgz` (pre: `tablet-preshare-20260905-093206.tgz`) | reload ok, configerrors clean. FAILED user hands-on: Shift still dead (capitals + symbols) |
| 2026-09-05 09:40 | OSK swapped Squeekboard→wvkbd (AUR 0.20, `wvkbd-mobintl` binary): `share_states` reverted, new `wvkbd-toggle.sh` (SIGUSR2 + visibility marker), tablet-enter auto-presents, tablet-exit kills, swipe/`SUPER+B` rewired, lua rule added. Squeekboard stays installed as fallback. Maliit ruled out (doesn't render on Hyprland); auto-show track retired (wvkbd has no focus-popup) | `input.lua`, `scripts/wvkbd-toggle.sh`, `scripts/tablet-mode.sh`, `scripts/touch-gestures.sh`, `tablet.lua`, `bindings.lua` | `tablet-wvkbd-20260905-093900.tgz` (pre: `tablet-prewvkbd-20260905-093900.tgz`) | wvkbd renders on overlay layer (screenshot), hide/toggle cycle + tablet on/off cycle verified, reload clean. LAPSE: swipe still summoned Squeekboard — running lisgd was started at login with old script (`hyprctl reload` doesn't refresh it) |
| 2026-09-05 09:44 | Fixed stale lisgd: restarted with current gestures (bottom-edge→wvkbd), killed stray Squeekboard, added restart reminder to script header | `scripts/touch-gestures.sh` | `tablet-lisgd-restart-20260905-094448.tgz` | live daemon cmdline confirms wvkbd-toggle, reload clean. PENDING user hands-on: swipe summon + Shift/capitals/symbols typing test |
| 2026-09-05 09:50 | OSK dismiss trap fixed: full-width wvkbd covers the bottom edge so the edge swipe couldn't dismiss it (user stuck, freed via pkill). Added edge-free `3-finger swipe up anywhere` → OSK toggle; daemon restarted live | `scripts/touch-gestures.sh` | `tablet-osk-dismiss-20260905-095042.tgz` | daemon cmdline confirms 5 gestures. PENDING user hands-on: Shift typing test + dismiss swipe |
| 2026-09-05 09:54 | Squeekboard restored as interim OSK (user decision: nicer/more compatible until custom keyboard built; wvkbd stays installed). Toggle/bindings/gestures/tablet-mode rewired back; daemon restarted live; dead `share_states` line already reverted earlier | `scripts/tablet-mode.sh`, `bindings.lua`, `scripts/touch-gestures.sh` | `tablet-squeek-restore-20260905-095447.tgz` (pre: `tablet-presqueek-20260905-095447.tgz`) | DBus toggle cycle visible/hidden verified, daemon cmdline confirms, reload clean. KNOWN OPEN: Squeekboard Shift broken on Hyprland; no auto-show (fcitx holds IM; Electron lacks IME flag) — both queued behind custom keyboard |
| 2026-09-05 ~10:25 | Custom keyboard Phase 1 DONE: `custom-kbd.py` (GTK4 + LayerShell bottom 1536x320, wtype one-shot, Shift latch + Caps double-tap, symbols page, hide) + `custom-kbd-toggle.sh` (toggle/show/hide/status, LD_PRELOAD fix for layer-shell linking) + `tablet.lua` no_focus rule. Fixes: direct shifted keysyms (Hyprland ignores `-M shift`), full-width default size. Interim OSK untouched | `scripts/custom-kbd.py`, `scripts/custom-kbd-toggle.sh`, `tablet.lua` | `tablet-customkbd-p1-20260905-102448.tgz` | Phase 1 gate passed user hands-on: typing, full Shift matrix, Caps, symbols/arrows, focus retention, hide/show |
| 2026-09-05 ~10:35 | Custom keyboard hold-repeat (pulled into Phase 1 early): press-and-hold repeat via GestureClick (400ms delay, 60ms interval, tap-only action keys). Fixes: `cancel` not `cancelled` signal (windowless-startup crash), guarded callbacks + stale-timer cleanup (CapsLock+mash crash), Shift+Enter → plain Return per user call (no Kitty `;2u`) | `scripts/custom-kbd.py`, `scripts/custom-kbd-toggle.sh` (stderr log) | `tablet-customkbd-enterfix-*` | User-verified: hold-⌫/hold-letter repeat, no doubles, Caps+mash survives, Shift+Enter plain newline |
| 2026-09-05 ~11:58 | Auto-rotate end-to-end FIXED (first real physical test; earlier verify was manual transforms only): `monitor-sensor` block-buffers when piped so the service never saw orientation lines. Fix: `stdbuf -o0 -e0` + event/apply logging to `~/.local/state/omarchy/auto-rotate.log`. Related: bar scale toggle fails while rotated + wipes transform (upstream omarchy bug, landscape-only workaround) | `scripts/auto-rotate.sh` | `tablet-autorotate-fix-20260905-115754.tgz` (pre: `auto-rotate.sh.bak.20260905-115645`) | Log proves pipeline: right-up/bottom-up/normal events → transform 3/2/0, monitor+finger `ok`. User-confirmed screen follows |
| 2026-09-05 ~12:35 | Auto-rotate boot race FIXED: service starts before Hyprland socket exists → once-at-startup signature resolution stays broken (`HYPRLAND_INSTANCE_SIGNATURE not set!` in log). Fix: lazy `resolve_sig()` on every apply + one retry on stale signature | `scripts/auto-rotate.sh` | `tablet-autorotate-sigfix-*` (pre: `auto-rotate.sh.bak.20260905-123618`) | Live-verified 12:45: right-up/normal events → `monitor=[ok] finger=[ok]`, no signature errors |
| 2026-09-05 ~12:50 | Rotation reset display scale to auto (1.5): transform-only `hl.monitor` eval drops scale to Hyprland auto. Fix: `apply()` reads live scale and passes it back with the transform. Display restored to 1.25/transform 0 | `scripts/auto-rotate.sh` | `tablet-autorotate-scalefix-*` (pre: `auto-rotate.sh.bak.20260905-124829`) | Proven by direct test: transform-only eval → scale 1.5; needs one user rotation to confirm end-to-end |
| 2026-09-05 ~12:05 | Bar-untouchable false alarm: finger touch was toggled off (`touch-off` state, ~12:00, accidental `SUPER+SHIFT+P`), not a Hyprland/shell bug. Re-enabled via `touch-toggle.sh on`; shell had already been restarted cleanly | — (no code change) | — | User-confirmed bar touch works |
| 2026-09-05 ~12:10 | Missing active-window border: Omarchy `window-no-gaps` toggle was on (zeroes gaps/border/rounding, loads after looknfeel so it wins). Turned off via `omarchy hyprland toggle window-no-gaps off` → `border_size: 2` back. Note: `looknfeel.lua` gained a `border_size = 2` block 12:26 (user/plugin attempt) — now redundant, left in place | — (toggle state only) | — | `hyprctl getoption` confirms `border_size: 2` |
| 2026-09-05 ~17:20 | Phase 3 swap DONE: `osk-toggle.sh` dispatcher (`OSK_BACKEND`=custom default, squeekboard/wvkbd fallbacks, `backend` get/set); bindings/input/hyprland restored after Omarchy rewrote them to stock 12:22 (tablet keys + Thunar + natural_scroll/clickfinger + `require tablet`); SUPER+B + gestures → dispatcher; tablet enter = summon-on-demand + auto-exit watcher wired (fixed chmod + STATE_FILE race with startup wait); `lisgd-gestures.service` permanent autostart | `scripts/osk-toggle.sh`, `scripts/tablet-mode.sh`, `scripts/touch-gestures.sh`, `scripts/tablet-auto-exit.py`, `bindings.lua`, `hyprland.lua`, `input.lua`, `lisgd-gestures.service` | `tablet-phase3-swap-20260905-171955.tgz` (pre: per-file `.bak.20260905-171518`) | Machine-verified: dispatch all backends, reload clean, bindings listed, daemon via service (1 instance), tablet on/off exit 0, watcher lifecycle. PENDING user hands-on: SUPER+B, gesture summon, tablet ×3, rotation, reboot |
| 2026-09-05 ~18:00 | Gesture summon followed rotation: lisgd edges are kernel-fixed, visual bottom moves. First tried per-orientation edge remap (wrong layer — and user-observed summon on wrong edge). Real fix: lisgd's own `-o` orientation flag rotates its gesture frame; one static binding set + `ORIENTATION=$transform` re-run from `auto-rotate.sh apply()` on every rotation. Also reordered touch-gestures.sh checks-before-pkill so a failed start never kills the working daemon | `scripts/touch-gestures.sh`, `scripts/auto-rotate.sh` | `tablet-gesture-orient-*` (pre: `.bak.20260905-175041`) | Verified live in right-up: rebind in daemon cmdline, visual-bottom swipe summons board with correct portrait geometry. Left-up/bottom-up follow same convention, uncalibrated |
| 2026-09-05 ~20:15 | Gesture dual-ownership bug: rotation hook spawned detached daemons while `lisgd-gestures.service` restarted and wiped the mapping to `-o 0` (service restarted twice). Fix: service stays single owner; hook now does `set-environment ORIENTATION` + service restart, with detached spawn only as fallback. Verified: one restart per rotation, single `-o 3` daemon, swipe summons | `scripts/auto-rotate.sh` | `tablet-gesture-owner-*` (pre: `.bak.20260905-201201`) | User-confirmed working |
| 2026-09-05 ~20:45 | Window focus gestures: 4-finger L/R (edge-free) → `movefocus l/r` — column navigation in scrolling layout, plain focus step otherwise. Rotation-safe via `-o`. Committed `2385c21` | `scripts/touch-gestures.sh` | `tablet-gesture-focus-*` (pre: `.bak.20260905-204419`) | Machine-verified bindings live, single daemon. PENDING user swipe test |
| 2026-09-05 ~22:15 | Double-tap warps cursor (pointer on demand; single tap stays cursor-less): kernel BTN_TOUCH pairs → native `hl.dsp.cursor.move({x,y})`. Path there: uinput REL proven ignored by stack (even fully-disguised), struct pack order + signed-value + ID_INPUT_MOUSE lessons, physical-vs-logical trap (cursor space is logical 1536x864). Landscape verified exact. Portrait t1/t3 arms uncalibrated | `scripts/touch-cursor.py`, `touch-cursor.service` | `tablet-touchcursor-*` + repo commits | User-confirmed cursor lands under finger |
| 2026-09-05 ~22:50 | Touch warp hardened: DOWN carries no coords (contact-position tracking + still-finger fallback), 800ms window, no-warp over board zone (typing guard that doesn't block app-area warps). Verified 100% hands-on | `scripts/touch-cursor.py` | `tablet-touchcursor-zone-*` | User-confirmed |
| 2026-09-06 ~08:30 | Warp carries focus: cursor teleport alone doesn't move focus (user's ping-pong workaround). `focus_at()` finds topmost mapped client under actual cursor, focuses via `hl.dsp.focus({window="address:…"})` (legacy string form dies in Lua translation — probed). Double-tap = go there, cursor + focus. Verified hands-on | `scripts/touch-cursor.py` | `tablet-touchcursor-focusfix-*` | warp EXACT + focus ok ×2, activewindow follows |
| 2026-09-06 ~08:35 | Reboot persistence verified (3+ organic boots): all three services active, backend still custom, bindings/require/input overrides intact, daemon `-o` correct for orientation, dispatcher show/hide cycle clean | — (no change) | `tablet-preupdate-20260906-073932.tgz` | All green after up-1:07 boot |
| 2026-09-06 ~08:00 | Touchpad-scroll false alarm + Chromium wedge: two-finger scroll died after OSK/rotation testing. Kernel delivers MT scroll data fine; added `disable_while_typing=false` (virtual-OSK keys tripped DWT) + reload. Residual was OpenCode-only (browser/Files scrolled) with wheel dead too → app-level. Clean app restart fixed it: Chromium wedges scroll state across scale/rotation churn. Rule: retest scroll in a second app before blaming input | `input.lua` | `input.lua.bak.20260906-074803` | Browser/Files/OpenCode-post-restart all scroll |
| 2026-09-05 ~22:35 | Portrait cursor calibration: corner-tap math exposed swapped t1/t3 arms (were mirror images) + physical-dims trap (monitors -j never rotates W/H — swap when t in 1,3). Fixed, verified numerically exact on live taps | `scripts/touch-cursor.py` | `tablet-touchcursor-calib-*` | Awaiting final under-finger confirmation |
| 2026-09-05 ~21:00 | REVERTED the 4-finger focus gestures: awkward to perform, conflicts with in-app touch (file manager). Tap-to-focus already works (verified healthy: `follow_mouse=1`, `focus_on_activate=true`, `no_focus` only on overlays) — direct manipulation wins. Committed `80250e2` | `scripts/touch-gestures.sh` | `tablet-gesture-tapfocus-*` (pre: `.bak.20260905-205838`) | Single daemon, movefocus bindings gone, service active |

## Keybindings

| Keys | Action | Prior binding? |
|---|---|---|
| `SUPER+SHIFT+T` | Tablet mode on/off (finger-only; kbd+pad off) | none (free) |
| `SUPER+B` | Squeekboard toggle (was `wvkbd-mobintl`) | none (free) |
| `SUPER+SHIFT+P` | Finger touch on/off (palm reject) | Google Photos — unbound, still in app menu |

## Files

| File | Purpose |
|---|---|
| `~/.config/hypr/tablet.lua` | Finger → `eDP-1` pin, boot-state wipe (tmpfs marker), Squeekboard + EXIT overlay rules (pen deferred) |
| `~/.config/hypr/scripts/tablet-mode.sh` | Tablet mode on/off/toggle/status (kbd+pad off, finger on, `follow_mouse` 2↔1, Squeekboard + EXIT overlay) |
| `~/.config/hypr/scripts/squeekboard-toggle.sh` | Start/kill Squeekboard |
| `~/.config/hypr/scripts/touch-gestures.sh` | lisgd gestures (dynamic finger event resolve; no-op until lisgd installed) |
| `~/.config/hypr/scripts/tablet-draw.sh` | Legacy drawing mode (pen; deferred, kept for reference) |
| `~/.config/hypr/scripts/osk-toggle.sh` | Legacy `wvkbd-mobintl` toggle (kept for reference) |
| `~/.config/hypr/scripts/touch-toggle.sh` | Finger touch on/off/toggle with persisted state |
| `~/.config/hypr/scripts/tablet-exit.py` | Layer-shell touch EXIT overlay (auto-started in drawing mode, never takes focus) |
| `~/.config/hypr/scripts/auto-rotate.sh` + `~/.config/systemd/user/auto-rotate.service` | Accelerometer rotation: monitor + pen + finger transforms together |
| `~/.config/omarchy/plugins/.../argus/BarWidget.qml` | Fixed: `<font>` urgent markup → per-segment Row (WidgetButton is PlainText) |

## Phase 0 — Manual drawing mode ✅ DONE
- [x] Install: `aseprite` (source 1.3.18.3), `wvkbd`, `xorg-xinput`, `iio-sensor-proxy`
- [x] Pen/finger pinned to `eDP-1`, reload clean, toggle cycle verified
- [x] Xwayland pen names (`xwayland-tablet stylus/eraser`) detected natively by Aseprite
- [ ] User pen-pressure test in Aseprite (fallback: `x11_stylus_id` in `aseprite.ini`)

## Phase 1 — Automatic fold detection ⛔ BLOCKED (no kernel fold signal)
- [x] Confirm hinge sensor channels (`hinge`/`screen`/`keyboard`, scale = °→rad)
- [x] Calibrate: open AND fully-folded raw values stay `0` — sysfs polling is dead
- [x] `SW_TABLET_MODE` query on all `/dev/input/event*` — absent everywhere
- [x] Intel HID nodes have **no `EV_SW` caps at all** — firmware never reports fold state
- [x] Toshiba ACPI `TOS6208` exposes no tablet attribute; proxy has no `TabletMode`
- [ ] Non-keyboard exit failsafe — pen barrel test PENDING (no pen at hand); fallback: touch EXIT button
- [ ] Manual toggle stays the interface; revisit auto-detect only if kernel/HID support appears
- BONUS LEAD: Intel HID 5-button array exposes `KEY_ROTATE_LOCK_TOGGLE` (561) + `KEY_LEFTMETA` (125) — possible **physical toggle button** if firmware keeps it alive when folded. Test pending.
- [x] Side-button capture while folded: **0 events** — only physical button is power. Physical-toggle idea dead.

## Phase 2 — Auto-rotation 🔄 BUILT, needs physical test
- [x] `auto-rotate.sh` + user service (enabled): `monitor-sensor` → transform 0/1/2/3 on monitor + pen + finger via `hyprctl eval`
- [x] Transform switching verified live (screen flipped to portrait and back)
- [ ] Physical test: rotate machine → screen follows? finger taps land correctly? (mapping may need flipping)
- Lesson: never `pkill -f` a bare word from scripts — it matches the caller's own command line. Use `pkill -x`.

## Phase 3 — Touch-first shell (planned)
- [ ] OSK auto-show on focus, bar tablet-state indicator (tappable override)
- [ ] Edge-swipe workspace gestures

## Phase 4 — App profiles (planned)
- [ ] Aseprite: fullscreen option, barrel-button undo/eyedropper, auto palm-reject
- [ ] Auto power-saver on fold (charger flips profile to `balanced` — re-assert after plugging in)

## Lessons learned
- `hyprctl keyword` is legacy-only on Hyprland 0.56 Lua — use `hyprctl eval 'hl.config/hl.device(...)'`.
- Disabling the internal keyboard also kills the exit hotkey — every kbd-off state needs a non-keyboard exit.
- Heavy builds push Argus metrics urgent (that's how the `<font>` bug surfaced); power-saver keeps temps ~51°C vs 91°C.
- Backups: per-file `.bak.<ts>` + full `~/backups/tablet-work-<ts>.tgz`. Restore = unpack over `~/.config/` + `hyprctl reload`.
- **2026-09-03 lockout:** `tablet-draw-on` + `touch-off` re-created 17:29 (manual hotkeys), killing kbd+pad+touch; reboot re-applied them via `tablet.lua` → total input loss a *system* snapshot restore can't fix (`/home` isn't in it). Fixed: `tablet.lua` wipes both state files on fresh boot (marker in tmpfs `/run/user`), so login always starts with input enabled.
- Never `pkill -f` a bare word from scripts — it matches the caller's own command line. Use `pkill -x`.
