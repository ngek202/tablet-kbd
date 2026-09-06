# Custom Keyboard Master Plan — "Squeekboard-simple, our engine"

## REMAINING (as of 2026-09-06 — remind on return)

Builds (approved, awaiting go):
1. DONE 2026-09-06: Verify-only resilience script (`tablet-verify.sh` +
   report-only `post-update.d` hook + `--fix`) — green/red paths tested
2. Modifier-keys spike (do virtual Super/Alt/Ctrl work at all?)
3. DONE 2026-09-06: Bar toggle plugin G (manifest + QML + state bridging;
   B stays) — live-enabled, touch-verified hands-on
4. Phase 4 share package (installer + docs; retire Squeekboard/wvkbd)

Verification (hands-on):
5. Tablet enter/exit ×3 completion
6. Left-up / bottom-up swipe calibration
7. Push 4 unpushed repo commits

External (user):
8. 1.5x preset desktop cross-check (resolved locally as 1.6x)

> Machine: Dynabook Portege X30W-J, Omarchy 4.0.2 / Hyprland 0.56.2 (Lua).
> Status: Phase 1 DONE + hardened, Phase 2 code done (portrait gate open),
> Phase 3 queued. Interim OSK is Squeekboard (Shift broken,
> no auto-show — parked). wvkbd installed as fallback. Pen work deferred.
> Tablet build log lives in `~/.config/hypr/TABLET.md`.
> Progress log below; tablet-side fixes in `TABLET.md` changelog.

## Decisions (locked 2026-09-05)

| Question | Decision |
|---|---|
| Engine | **C — from-scratch app** (GTK4 UI + `wtype` key emission) |
| Style | Minimal Squeekboard clone (4-row simplicity, Omarchy theme colors) |
| Portrait | Same layout squeezed (no dedicated reflow) |
| Toggle refactor | Lands **with** the swap, not before |
| Layout v1 | Minimal clone; number row / programmer symbols / sizing deferred to sketch |

## Architecture (all pieces verified on-machine)

- **UI:** Python + GTK4 + Gtk4LayerShell (installed; pattern proven by
  `~/.config/hypr/scripts/tablet-exit.py`). Bottom-anchored layer surface,
  exclusive zone (apps resize above it), keyboard-interactivity NONE
  (taps never steal focus).
- **Key emission:** `wtype` one-shot per tap (installed 0.4).
  CORRECTION 2026-09-05: Hyprland 0.56 ignores the virtual-keyboard
  Shift modifier (`wtype -M shift -k a` → `a`). Shift is now direct
  shifted keysyms (`A`, `!`, `?`, …) — correct by construction, no
  compositor modifier needed. Modifier form kept only for Shift+arrows.
  Raw key events work in every app class: Wayland GTK/Qt, XWayland,
  Electron, terminals.
- **Layouts:** JSON files (`~/.config/hypr/kbd-layouts/en.json`) — rows of
  `{label, keysym|action, width, style, shifted?, page?}`; actions are
  `shift`/`page`/`hide`. Missing/invalid JSON falls back to a minimal
  page (board never fails to start).
- **Show/hide contract:** process start/kill behind the existing toggle
  interface (`toggle/show/hide/status`), so gestures, `SUPER+B`, and
  tablet-mode plug in unchanged at swap time.
- **Key state (app-side):** Shift latch (tap), CapsLock (double-tap),
  symbols-page toggle, Backspace/Return/Space/Tab/Esc/arrows, dedicated
  hide key. Hold-repeat SHIPPED early (400ms delay, 60ms interval,
  tap-only action keys; Shift+Enter → plain Return per user call).

## Why this stack

- No C, no protocol plumbing, no new dependencies.
- Shift correct by design (the exact thing Squeekboard can't do here).
- More universal than Squeekboard's input-method path.
- Customizable where it counts: JSON layouts + GTK CSS theming.

## Known limits (no surprises later)

- No auto-show on focus (protocol reality) — manual summon stays
  (bottom-edge swipe, 3-finger swipe, `SUPER+B`).
- Per-tap process spawn adds ~10–30ms — fine for typing.
- Dead-key/compose sequences need deliberate layout entries.
- No CJK (same as Squeekboard; fcitx untouched).

## Phases

### Phase 1 — Prototype
Fixed 4-row QWERTY grid + Space/Backspace/Return/Shift-latch/
symbols-page/hide, GTK CSS in Omarchy theme colors.

Gate: typing test incl. full Shift matrix (`A-Z`, `? ! : " @ # $`),
summon/dismiss by hand, focus stays in target app (explicit Hyprland
#1939 regression check).

### Phase 2 — Layout system
JSON loader, EN main + numbers/symbols pages, portrait squeeze verified
by rotation, key sizing pass for 13" fingers.

### Phase 3 — Swap + integration
Backend-agnostic toggle refactor (`OSK_BACKEND` variable), point
gestures/hotkey/tablet-mode at the new board, enter/exit cycle ×3,
rotation sanity, reboot persistence, snapshots throughout.

### Phase 4 — Share package
Layout JSON + build/run recipe + wiring notes for other convertible users.

## Checklist / todos (staged, execution on go)

- [x] Phase 1: prototype grid + Shift latch + symbols page + hide key
- [x] Phase 1 gate: Shift matrix + focus-retention test (passed 2026-09-05 hands-on; fix: direct shifted keysyms, Hyprland ignores `-M shift`)
- [x] Phase 1 hardening: hold-repeat, `cancel`-signal crash fix, guarded callbacks, crash/stderr logs, Shift+Enter → plain Return (all user-verified)
- [x] Phase 2: JSON loader + pages + sizing pass (340px board, 60px keys, 21px font; 69 keys validated, fallback verified)
- [x] Phase 2 gate: portrait squeeze test (passed 2026-09-05 hands-on: 864x340 full portrait width, taps accurate, scale held 1.25)
- [x] Thumb split layout: ⇄ toggle on alpha row, width-midpoint halves + center gap (100px/48px), landscape starts split / portrait starts full, choice persists; pangram + toggle/persistence verified hands-on
- [x] Shift letter visuals + segfault fix: letters render uppercase while latch/Caps (symbols static); user-found crash (split + shifted + double-click letter) was latch-release destroying widgets under in-flight gestures → visuals now updated in place, structural rebuilds deferred to idle; verified hands-on
- [x] Phase 3: toggle refactor + swap + integration (osk-toggle dispatcher, SUPER+B/gestures/tablet-mode rewired, auto-exit watcher wired, lisgd systemd service, gesture `-o` orientation — all machine-verified + user-confirmed; reboot persistence test still open)
- [ ] Phase 4: share docs; retire Squeekboard/wvkbd per user call

## Packaging (locked 2026-09-05)

Share as a **package**, not a plugin. Verified against Omarchy plugin
manifests: plugins only declare shell-scoped kinds (`bar-widget`,
panels, in-shell services) and cannot own hypr bindings, systemd
units, or config files.

- **Package** (one repo, one install story): OSK engine + layouts +
  dispatcher + tablet wiring (scripts, service units, lua snippets) +
  install script (deps, enablement, hypr wiring blocks) + verify
  script + recipe docs.
- **Plugin** (optional companion): tablet toggle bar-widget only.
  Depends on the package, never the reverse. Placement via platform
  flow (`omarchy plugin add <url>` prompts for the bar slot;
  `omarchy plugin enable <id> --section right` for non-interactive) —
  installer MUST NOT hand-edit shell.json or ask placement itself
  (decided 2026-09-06; `omarchy plugin validate` passes, exit 0).
- **Hook** (ships inside the package): verify script installed to
  `post-update.d/` by the installer.
- Rationale: refresh-hyprland overwrites 7 owned lua files (seen
  2026-09-05 12:22); everything else already lives in paths refresh
  never lists. Update survival: plugin + package + hook all persist
  (user dirs); only the hyprland.lua `require` line + owned-file
  content is at risk, covered by verify.

## Open threads (parked, not forgotten)

- RESOLVED 2026-09-05: 1.6x confirmed as the default preset (not 1.5x). Observed 1.5x was Hyprland auto-scale after the rotation bug, since fixed.
- QUEUED 2026-09-05: verify-only resilience (`tablet-verify.sh` check + report + `--fix`, report-only `post-update.d` entry). Full auto-heal rejected as intrusive. Awaiting build go-ahead.
- DONE 2026-09-05: Shift visuals (letters swap case + symbols swap main/hint + sublabel hints) + segfault fix (in-place updates, idle-deferred rebuilds).
- DONE 2026-09-05: Symbols page update (`(`/`)` → `[`/`]` with `{`/`}` shifted; ⇄ on symbols row).

- Squeekboard Shift broken on Hyprland / no auto-show (fcitx holds IM
  slot; opencode-desktop is Electron without `--enable-wayland-ime`).
- Dormant `tablet-auto-exit.py` (wire or delete at swap time).
- Rotation-lock toggle, pen work on return.
- `input:virtualkeyboard:share_states` trialed, no effect, reverted.
- Tablet-side fixes live in `TABLET.md` changelog (auto-rotate buffering +
  boot-race + scale-preservation fixes; bar scale-toggle upstream bug;
  accidental touch/gaps toggles restored). Reboot + rotate test still
  the gold-standard confirmation for the boot-race fix.

## Progress log (2026-09-05, newest last)

- Phase 1 built: `custom-kbd.py` + `custom-kbd-toggle.sh` + `tablet.lua`
  no-focus rule. LayerShell needed `LD_PRELOAD`; full-width fix.
  Snapshot `tablet-customkbd-p1-20260905-101706.tgz`.
- Shift matrix failed hands-on → root cause Hyprland ignores `-M shift`
  → direct shifted keysyms. Gate passed. Snapshot `...-102448.tgz`.
- Hold-repeat shipped early (GestureClick, 400/60ms). Fixed `cancelled`
  → `cancel` crash, CapsLock+mash race, Shift+Enter → plain Return.
  Snapshots `tablet-customkbd-repeat-*`, `tablet-customkbd-enterfix-*`.
- Phase 2: `kbd-layouts/en.json` (alpha+symbols, 69 keys) + loader
  refactor + fallback + sizing pass. Snapshot `tablet-customkbd-p2-*`.
- Tablet detour: auto-rotate end-to-end (stdbuf), boot-race (lazy
  signature), rotation scale-reset (preserve live scale) — all fixed,
  live-verified; reboot test pending. Bar scale-toggle while rotated =
  upstream bug (drops transform). Accidental `touch-off` and
  `window-no-gaps` toggles diagnosed + restored, bindings left intact.
- Scale presets: 1.5x never in local/upstream list (always 1.6);
  observed 1.5x = Hyprland auto after rotation bug. Queued for
  desktop cross-check, no action.
- Gesture daemon gap found: `lisgd` has no autostart anywhere — reboots
  kill all touch gestures until `touch-gestures.sh` runs manually.
  Daemon restarted live; permanent fix (user systemd service) queued
  for Phase 3.
- 4-finger L/R focus tried and REVERTED same session (awkward +
  app conflicts); tap-to-focus PROVEN working via 10-min kernel+cursor+
  focus tracer (taps flow at kernel, focus follows to tapped window).
  One real gap found: cursor does NOT follow taps (frozen while focus
  moves) — Wayland touch paradigm, unlike mouse click.
- Phase 2 gate passed in portrait (864x340 layer, accurate taps).
- Phase 3 swap built + machine-verified; gesture-orientation fix (`-o`
  flag + auto-rotate hook) user-confirmed working. Left-up/bottom-up
  same convention, uncalibrated. Reboot persistence test pending.
- Thumb split shipped: ⇄ key, midpoint halves + gap, width-defaults +
  persistence; pangram verified. Snapshot `tablet-customkbd-split-*`.
- Shift visuals shipped + segfault killed (in-place visual updates,
  idle-deferred rebuilds). Snapshot `tablet-customkbd-noDestroy-*`.
- Repo created: `~/Work/tablet-kbd` (`main`, seeded from live files in
  Phase 4 package shape). Rule: live `~/.config` canonical until the
  Phase 4 installer lands; every change set mirrored here + committed.
  Remote: `github.com/ngek202/tablet-kbd` (private, pushed 2026-09-05).
- Verification 2026-09-06: SUPER+B user-tested OK. Double-tap warp +
  focus-follows verified OK. Open: tablet enter/exit ×3, left-up /
  bottom-up swipes, reboot persistence test.
- Strand saga closed 2026-09-06: press-across-disable strands any key
  (repeat timer); fixed by entry quiescence wait (`tablet-modwait.py`);
  virtual-modifier reset tried and reverted (stranded Super itself);
  exit policy = 4-finger swipe only. Verified hands-on.
- 2026-09-06: checked upstream (OpenClaw app, vi, test cleanup, Brave
  profiles — nothing tablet-related) and `omarchy update available`
  reports up to date (4.0.2-1). No update to test; pre-update snapshot
  `tablet-preupdate-20260906-073932.tgz` taken anyway.
- Double-tap warps cursor: kernel BTN_TOUCH pairs → native
  `hl.dsp.cursor.move({x,y})` in logical coords (uinput REL proven
  ignored by stack; physical-vs-logical trap found by probe).
  Landscape verified (cursor lands exactly on target).
- Symbols polish: secondary hints on all shifted keys (mobile-style
  sublabels), `(`/`)` replaced by `[`/`]` (`{`/`}` shifted), full
  shifted faces on latch/Caps (letters swap case, symbols swap
  main/hint),    ⇄ added to symbols row. Snapshots `tablet-customkbd-*`.
- Plugin G built 2026-09-06: `plugins/tablet-toggle/manifest.json` +
  `plugins/tablet-toggle/BarWidget.qml`
  (`io.github.ngek202.tablet-toggle`, polls `tablet-mode.sh status` every
  2s, click toggles, B untouched). Manifest validates, status poll verified
  (`off`/exit 0). Pending: live enable + touch test.
- Plugin G enabled live 2026-09-06: copied to
  `~/.config/omarchy/plugins/io.github.ngek202.tablet-toggle/`,
  `omarchy plugin enable --section right`, shell restarted clean (no QML
  errors in journal). Pending: touch-test bar toggle on/off + state highlight.
- Plugin G touch-verified 2026-09-06: bar toggle enters/exits tablet mode,
  highlight follows state, SUPER+B untouched, bare `a` lowercase (no stranded
  modifiers). Item 3 closed.

## Backups

- Tablet snapshots: `~/backups/tablet-*.tgz` (+`.sha256`), logged in
  `TABLET.md`. Same discipline applies to keyboard work:
  per-file `.bak.<ts>` + step snapshots + one log line each.
- Restore full: `tar -xzf <tgz> -C ~ && hyprctl reload && hyprctl configerrors`
