#!/usr/bin/env python3
# Wait for keyboard quiescence before tablet-mode.sh disables it.
# Disabling between a press and its release strands the key: the release
# never lands and Hyprland's repeat timer fires it forever (seen 2026-09-06
# with a quick Enter tap at entry; Super/Shift strand the same way via the
# entry hotkey). Tracks ALL keys, not just modifiers. Best-effort: always
# exits 0 within ~2s; worst case is the old behavior.
import select
import struct
import sys
import time

import importlib.util as _ilu
import os as _os

_tae_path = _os.path.expanduser("~/.config/hypr/scripts/tablet-auto-exit.py")
_tae_spec = _ilu.spec_from_file_location("tablet_auto_exit", _tae_path)
_tae = _ilu.module_from_spec(_tae_spec)
_tae_spec.loader.exec_module(_tae)
find_handler, open_nb, read_events, EV_KEY = (
    _tae.find_handler, _tae.open_nb, _tae.read_events, _tae.EV_KEY)

TIMEOUT = 2.0
QUIET_NEED = 0.25  # no unreleased presses + this much silence = go


def main():
    import os
    link = "/dev/input/by-path/platform-i8042-serio-0-event-kbd"
    path = link if os.path.exists(link) else find_handler(
        "AT Translated Set 2 keyboard")
    fd = open_nb(path) if path else -1
    if fd < 0:
        return 0
    held = set()
    quiet_from = time.monotonic()
    end = quiet_from + TIMEOUT
    while time.monotonic() < end:
        r, _, _ = select.select([fd], [], [],
                                max(0.0, min(0.05, end - time.monotonic())))
        if not r:
            if not held and time.monotonic() - quiet_from >= QUIET_NEED:
                break
            continue
        for typ, code, val in read_events(fd):
            if typ != EV_KEY:
                continue
            quiet_from = time.monotonic()
            if val in (1, 2):
                held.add(code)
            elif val == 0:
                held.discard(code)
        if not held and time.monotonic() - quiet_from >= QUIET_NEED:
            break
    return 0


main()
