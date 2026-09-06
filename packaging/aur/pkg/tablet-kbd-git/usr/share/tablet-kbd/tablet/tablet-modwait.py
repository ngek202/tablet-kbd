#!/usr/bin/env python3
# Wait for keyboard quiescence before tablet-mode.sh disables it.
# Disabling while any key is down strands it: the release never lands
# and Hyprland's repeat timer (regular keys) or held state (modifiers)
# persists — seen 2026-09-06 with quick Enter taps and SUPER+SHIFT+T.
#
# Detection uses EVIOCGKEY (live key-state bitmap), NOT the event
# stream: already-held keys emit nothing, so event-watching sails
# straight through the exact case it must catch (fixed 2026-09-06 —
# the first version drained the buffer and waited on new presses only).
# Best-effort: always exits 0 within ~2s.
import array
import fcntl
import os
import time

TIMEOUT = 2.0
POLL = 0.05
KEY_MAX = 0x2FF
EVIOCGKEY = (2 << 30) | (96 << 16) | (0x45 << 8) | 0x18


def pressed(fd):
    buf = array.array("B", [0]) * 96
    fcntl.ioctl(fd, EVIOCGKEY, buf, True)
    return {i for i in range(KEY_MAX + 1) if buf[i // 8] & (1 << (i % 8))}


def main():
    import importlib.util
    try:
        spec = importlib.util.spec_from_file_location(
            "tablet_auto_exit", os.path.expanduser(
                "~/.config/hypr/scripts/tablet-auto-exit.py"))
        tae = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(tae)
        find_handler = tae.find_handler
    except Exception:
        return 0
    link = "/dev/input/by-path/platform-i8042-serio-0-event-kbd"
    path = link if os.path.exists(link) else None
    if path is None:
        try:
            path = find_handler("AT Translated Set 2 keyboard")
        except Exception:
            path = ""
    if not path:
        return 0
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
    except OSError:
        return 0
    end = time.monotonic() + TIMEOUT
    try:
        while time.monotonic() < end:
            if not pressed(fd):
                return 0
            time.sleep(POLL)
    except OSError:
        pass
    finally:
        try:
            os.close(fd)
        except Exception:
            pass
    return 0


main()
