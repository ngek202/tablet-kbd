#!/usr/bin/env python3
# Custom keyboard — minimal Squeekboard-style clone (Phase 2: JSON layouts).
# Stack: GTK4 + Gtk4LayerShell UI, wtype one-shot key emission.
# Layouts: ~/.config/hypr/kbd-layouts/*.json — rows of
# {label, keysym|action, width, style, shifted?, page?}.
# Contract: Shift latch (tap) / CapsLock (double-tap), hold-repeat,
# Backspace/Return/Space/Tab/Esc/arrows, dedicated hide key.
# Focus: layer-shell keyboard-interactivity NONE + buttons can_focus=False,
# so taps never steal focus (Hyprland #1939 regression check).
import subprocess
import sys
import time
import traceback

CRASH_LOG = "/tmp/custom-kbd-crash.log"


def _excepthook(etype, value, tb):
    with open(CRASH_LOG, "a") as f:
        f.write(time.strftime("[%Y-%m-%d %H:%M:%S] unhandled exception:\n"))
        traceback.print_exception(etype, value, tb, file=f)
    sys.__excepthook__(etype, value, tb)


sys.excepthook = _excepthook


def guarded(fn):
    """Log + swallow callback exceptions: a bad tap must never kill the board."""
    def wrapper(*args, **kwargs):
        try:
            return fn(*args, **kwargs)
        except Exception:
            with open(CRASH_LOG, "a") as f:
                f.write(time.strftime("[%Y-%m-%d %H:%M:%S] guarded:\n"))
                traceback.print_exc(file=f)
            return False
    return wrapper

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")
from gi.repository import Gtk, Gtk4LayerShell as LayerShell, Gdk, GLib

import json
import os

APP_ID = "custom.kbd"
TITLE = "custom-kbd"
HEIGHT = 340

LAYOUT_DIR = os.path.expanduser("~/.config/hypr/kbd-layouts")
LAYOUT_FILE = os.path.join(LAYOUT_DIR, "en.json")

STATE_DIR = os.path.expanduser("~/.local/state/omarchy/toggles/hypr")
SPLIT_FILE = os.path.join(STATE_DIR, "osk-split")

# Split (thumb) layout: rows break at the width midpoint with a center gap.
# Landscape starts split, portrait starts full; the ⇄ toggle persists.
SPLIT_MIN_WIDTH = 1000
SPLIT_GAP_WIDE = 100
SPLIT_GAP_NARROW = 48


def load_split(persisted_only=False, full_w=0):
    """Split state: persisted choice wins, else width default."""
    try:
        with open(SPLIT_FILE) as f:
            return f.read().strip() == "1"
    except OSError:
        if persisted_only:
            return None
        return full_w >= SPLIT_MIN_WIDTH


def save_split(on):
    try:
        os.makedirs(STATE_DIR, exist_ok=True)
        with open(SPLIT_FILE, "w") as f:
            f.write("1" if on else "0")
    except OSError:
        pass

# Fallback page if the JSON layout is missing/invalid — board must never
# fail to start. (Full layouts live in kbd-layouts/*.json.)
FALLBACK_LAYOUT = {
    "start_page": "alpha",
    "pages": {
        "alpha": [
            [{"label": "layout missing", "keysym": "space", "width": 6},
             {"label": "▼", "action": "hide", "width": 1, "style": "fn"}],
        ],
    },
}

# Hold-repeat (standard keyboard behavior): delay before repeat starts,
# then interval between repeats. Applies to all typeable keys.
REPEAT_DELAY_MS = 400
REPEAT_INTERVAL_MS = 60

# Osaka Jade (Omarchy) — dark mode
BG = "#111c18"
BTN_BG = "#23372b"
BTN_FG = "#c1c497"
ACCENT = "#509475"
SELECTION = "#32473b"
MUTED = "#53685b"

# Key dict: {label, keysym|action, width=1, style="", shifted?, page?}
# Actions: shift | page (needs "page": target) | hide.

def load_layout():
    """Load kbd-layouts/en.json. Returns (pages, start_page)."""
    try:
        with open(LAYOUT_FILE) as f:
            data = json.load(f)
        pages = data["pages"]
        assert isinstance(pages, dict) and pages, "no pages"
        for name, rows in pages.items():
            assert isinstance(rows, list) and rows, f"page {name} empty"
            for row in rows:
                assert isinstance(row, list) and row, f"page {name} bad row"
                for k in row:
                    assert "label" in k, f"page {name} key without label"
                    assert ("keysym" in k) != ("action" in k), \
                        f"page {name} key needs exactly one of keysym/action"
                    k.setdefault("width", 1)
                    k.setdefault("style", "")
        return pages, data.get("start_page", next(iter(pages)))
    except Exception as e:
        with open(CRASH_LOG, "a") as f:
            f.write(time.strftime("[%Y-%m-%d %H:%M:%S] layout fallback: "
                                  f"{e}\n"))
        fb = FALLBACK_LAYOUT
        return fb["pages"], fb["start_page"]


# Shifted output per US layout, emitted as direct text/keysym so it does
# NOT depend on the compositor applying a virtual-keyboard modifier
# (Hyprland 0.56 ignores `-M shift` for the following key — verified
# 2026-09-05: latch highlighted, output still lowercase).
# Already-shifted symbols map to themselves. Named non-printables
# (arrows etc.) keep the `-M shift` modifier form (text selection).
SHIFT_TEXT = {
    "1": "!", "2": "@", "3": "#", "4": "$", "5": "%",
    "6": "^", "7": "&", "8": "*", "9": "(", "0": ")",
    "comma": "<", "period": ">", "slash": "?",
    "semicolon": ":", "apostrophe": '"', "minus": "_",
    "grave": "~", "bracketleft": "{", "bracketright": "}",
    "backslash": "|", "equal": "+",
}


def _key_markup(main, small):
    """Two-line key face: main label + dimmed secondary hint."""
    text = GLib.markup_escape_text(main)
    if small:
        text += (f"\n<span size=\"small\" foreground=\"{MUTED}\">"
                 f"{GLib.markup_escape_text(small)}</span>")
    return text


def _paint_key(kind, widget, main, small):
    if kind == "plain":
        widget.set_label(main)
    else:
        widget.set_markup(_key_markup(main, small))


def wtype_args(key, shift):
    """Resolve a layout key + shift state to a wtype argv list."""
    keysym = key["keysym"]
    if keysym == "space":
        return ["wtype", " "]
    if shift and key.get("shifted"):
        return ["wtype", key["shifted"]]
    if shift and len(keysym) == 1 and keysym.isalpha():
        return ["wtype", keysym.upper()]
    if shift and keysym in SHIFT_TEXT:
        return ["wtype", SHIFT_TEXT[keysym]]
    if len(keysym) == 1:
        return ["wtype", keysym.lower() if keysym.isalpha() else keysym]
    # named keysym (BackSpace, Return, arrows, comma, ...)
    # Return ignores shift (mobile-style: plain Enter, no Kitty
    # ;2u sequence in terminals). Arrows keep the modifier form
    # so Shift+arrows can select text where the compositor
    # applies it.
    if shift and keysym != "Return":
        return ["wtype", "-M", "shift", "-k", keysym]
    return ["wtype", "-k", keysym]


class Keyboard(Gtk.Application):
    def __init__(self):
        super().__init__(application_id=APP_ID)
        self.layout, self.page = load_layout()
        if self.page not in self.layout:
            self.page = next(iter(self.layout))
        self.split = load_split(persisted_only=True)  # None = width default
        self.full_w = 0
        self.shift_latch = False
        self.caps = False
        self._last_shift_tap = 0.0
        self._latch_consumed = False  # latched shift spent by a held key
        self._holds = {}  # gesture -> {"argv", "timer"}
        self.rows_box = None
        self.shift_btns = []  # shift action buttons (visual state only)
        self.key_btns = []  # [(kind, widget, base, sub, is_letter)] typeables

    def do_activate(self):
        win = Gtk.Window(application=self)
        win.set_title(TITLE)
        win.set_decorated(False)
        win.set_resizable(False)
        win.set_can_focus(False)
        # Full monitor width: anchored LEFT+RIGHT stretches the surface,
        # but the window still needs an explicit wide default size.
        try:
            disp = Gdk.Display.get_default()
            mon = disp.get_primary_monitor() or disp.get_monitors()[0]
            geo = mon.get_geometry()
            full_w = geo.width
        except Exception:
            full_w = 1536
        self.full_w = full_w
        if self.split is None:
            self.split = load_split(full_w=full_w)
        win.set_default_size(full_w, HEIGHT)

        css = Gtk.CssProvider()
        css.load_from_string(
            f"window {{ background: {BG}; }}"
            f".kbd {{ background: {BG}; padding: 6px; }}"
            f"button.key {{ background: {BTN_BG}; color: {BTN_FG}; "
            f"font-size: 21px; border-radius: 8px; padding: 6px; "
            f"min-height: 60px; border: 1px solid {MUTED}; }}"
            f"button.key:active {{ background: {SELECTION}; }}"
            f"button.fn {{ color: {ACCENT}; font-weight: bold; }}"
            f"button.latched {{ background: {ACCENT}; color: {BG}; }}"
        )
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), css,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

        LayerShell.init_for_window(win)
        LayerShell.set_layer(win, LayerShell.Layer.BOTTOM)
        LayerShell.set_anchor(win, LayerShell.Edge.BOTTOM, True)
        LayerShell.set_anchor(win, LayerShell.Edge.LEFT, True)
        LayerShell.set_anchor(win, LayerShell.Edge.RIGHT, True)
        LayerShell.set_exclusive_zone(win, HEIGHT)
        LayerShell.set_keyboard_mode(win, LayerShell.KeyboardMode.NONE)

        self.rows_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        self.rows_box.add_css_class("kbd")
        win.set_child(self.rows_box)
        self.rebuild()
        win.present()

    def rebuild(self):
        # Drop any in-flight holds first: their buttons are gone, so stale
        # timers would repeat forever. Apply a consumed latch silently.
        for gesture in list(self._holds):
            self._cancel_hold(gesture)
        if self._latch_consumed:
            self._latch_consumed = False
            self.shift_latch = False
        # clear rows
        child = self.rows_box.get_first_child()
        while child:
            nxt = child.get_next_sibling()
            self.rows_box.remove(child)
            child = nxt
        self.shift_btns = []
        self.key_btns = []
        layout = self.layout.get(self.page) or next(iter(self.layout.values()))
        gap = SPLIT_GAP_WIDE if self.full_w >= SPLIT_MIN_WIDTH else SPLIT_GAP_NARROW
        for row in layout:
            if self.split and len(row) > 1:
                halves = self._split_row(row)
                h = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
                h.set_hexpand(True)
                left = self._keys_box(halves[0])
                left.set_hexpand(True)
                right = self._keys_box(halves[1])
                right.set_hexpand(True)
                spacer = Gtk.Box()
                spacer.set_size_request(gap, -1)
                h.append(left)
                h.append(spacer)
                h.append(right)
            else:
                h = self._keys_box(row)
            self.rows_box.append(h)
        self._refresh_shift_visuals()

    @staticmethod
    def _split_row(row):
        """Split a row into two halves at the cumulative-width midpoint."""
        total = sum(k.get("width", 1) for k in row)
        acc, idx = 0, len(row)
        for i, k in enumerate(row):
            acc += k.get("width", 1)
            if acc >= total / 2:
                idx = i + 1
                break
        return row[:idx], row[idx:]

    def _keys_box(self, keys):
        h = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        h.set_hexpand(True)
        h.set_homogeneous(False)
        for key in keys:
            h.append(self._make_key(key))
        return h

    def _make_key(self, key):
        label, w = key["label"], key.get("width", 1)
        keysym = key.get("keysym", "")
        is_letter = len(keysym) == 1 and keysym.isalpha()
        # Secondary (shifted) hint, mobile-style: keys whose Shift output
        # differs from the label show it small underneath (e.g. 1→!).
        # Letters are excluded — they swap case outright on Shift/Caps.
        sub = "" if is_letter else (
            key.get("shifted") or SHIFT_TEXT.get(keysym, ""))
        if sub:
            b = Gtk.Button()
            lab = Gtk.Label()
            lab.set_markup(_key_markup(label, sub))
            lab.set_can_focus(False)
            b.set_child(lab)
            self.key_btns.append(("markup", lab, label, sub, False))
        else:
            b = Gtk.Button(label=label)
            if is_letter:
                self.key_btns.append(("plain", b, label, None, True))
        b.add_css_class("key")
        b.set_can_focus(False)
        b.set_hexpand(True)
        # width weight via size request ratio hint
        b.set_size_request(int(64 * w), 60)
        if "action" in key:
            if key.get("style") == "fn":
                b.add_css_class("fn")
            # Action keys: tap-only, fire on release as before.
            b.connect("clicked", self.on_key, key)
        else:
            # Typeable keys: press-and-hold repeat via gesture
            # (one gesture per tap — no touch/mouse double-fire).
            g = Gtk.GestureClick.new()
            g.set_button(0)  # any button + touch
            g.connect("pressed", self.on_press, key)
            g.connect("released", self.on_release)
            g.connect("cancel", self.on_release)
            b.add_controller(g)
        if key.get("action") == "shift":
            self.shift_btns.append(b)
        return b

    def _refresh_shift_visuals(self):
        """Latch/Caps feedback without destroying widgets (crash-safe).
        Shifted keys show their shifted face (letters swap case, symbols
        swap main/hint) — what you see is what the next tap emits.
        Called after any latch/caps change and at the end of rebuild."""
        shifted = self.shift_latch or self.caps
        for b in self.shift_btns:
            if shifted:
                b.add_css_class("latched")
            else:
                b.remove_css_class("latched")
            b.set_label("⇧●" if self.caps else "⇧")
        for kind, widget, base, sub, is_letter in self.key_btns:
            if not shifted:
                main, small = base, sub
            elif is_letter:
                main, small = base.upper(), None
            elif sub:
                main, small = sub, base
            else:
                continue
            _paint_key(kind, widget, main, small)

    def _request_rebuild(self):
        """Structural rebuilds (page/split) deferred to idle: never destroy
        widgets inside their own signal emission."""
        GLib.idle_add(self._rebuild_deferred)

    @guarded
    def on_press(self, gesture, _n_press, _x, _y, key):
        argv = wtype_args(key, self.caps or self.shift_latch)
        try:
            subprocess.Popen(argv)
        except FileNotFoundError:
            print("wtype not found", file=sys.stderr)
        if self.shift_latch:
            # latch indicator stays until release; cleared then
            self._latch_consumed = True
        self._cancel_hold(gesture)  # stale timer on same gesture: drop it
        self._holds[gesture] = {
            "argv": argv,
            "timer": GLib.timeout_add(
                REPEAT_DELAY_MS, self._start_repeat, gesture),
        }

    def _cancel_hold(self, gesture):
        hold = self._holds.pop(gesture, None)
        if hold is not None:
            try:
                GLib.source_remove(hold["timer"])
            except Exception:
                pass

    @guarded
    def _start_repeat(self, gesture):
        hold = self._holds.get(gesture)
        if hold is None:
            return False
        try:
            subprocess.Popen(hold["argv"])
        except FileNotFoundError:
            return False
        hold["timer"] = GLib.timeout_add(
            REPEAT_INTERVAL_MS, self._repeat, gesture)
        return False

    @guarded
    def _repeat(self, gesture):
        hold = self._holds.get(gesture)
        if hold is None:
            return False
        try:
            subprocess.Popen(hold["argv"])
        except FileNotFoundError:
            return False
        return True

    @guarded
    def on_release(self, gesture, *_args):
        self._cancel_hold(gesture)
        if self._latch_consumed:
            self._latch_consumed = False
            self.shift_latch = False
            # In-place only: never destroy widgets on this path (segfault
            # hazard mashing latched keys — in-flight gestures outlive any
            # rebuild). Structural rebuilds go through _request_rebuild.
            self._refresh_shift_visuals()

    @guarded
    def _rebuild_deferred(self):
        self.rebuild()
        return False

    def on_key(self, _btn, key):
        now = time.monotonic()
        action = key.get("action", "")
        if action == "hide":
            self.quit()
            return
        if action == "page":
            target = key.get("page", "")
            if target in self.layout:
                self.page = target
                self._request_rebuild()
            return
        if action == "split":
            self.split = not self.split
            save_split(self.split)
            self._request_rebuild()
            return
        if action == "shift":
            # double-tap (<400ms) toggles CapsLock, single tap latches.
            # Visuals only — no rebuild (same segfault hazard as release).
            if now - self._last_shift_tap < 0.4:
                self.caps = not self.caps
                self.shift_latch = False
            else:
                if self.caps:
                    self.caps = False
                else:
                    self.shift_latch = not self.shift_latch
            self._last_shift_tap = now
            self._refresh_shift_visuals()
            return
        # Typeable keys are handled by on_press/on_release (hold-repeat),
        # not here — reaching this means an unknown action key.


if __name__ == "__main__":
    app = Keyboard()
    sys.exit(app.run(sys.argv))
