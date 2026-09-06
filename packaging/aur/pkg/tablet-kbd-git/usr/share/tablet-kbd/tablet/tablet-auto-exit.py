#!/usr/bin/env python3
# Auto-exit tablet mode when laptop usage is detected (proxy for "hinge back").
# The X30W-J hinge sysfs is stuck at 0 and there is no SW_TABLET_MODE switch,
# so watch the physical keyboard at kernel level instead.
# KEYBOARD ONLY (2026-09-06): touchpad scrolling in tablet mode is
# legitimate use at tent angles (pad stays alive there), so pad activity
# must never exit tablet mode — it did, twice. A real keypress means
# unfolded hands, unambiguously.
# Hyprland's device disable is compositor-level — /dev/input still emits.
# Any deliberate keypress means unfolded hands, unambiguously.
import os
import re
import select
import struct
import subprocess
import sys
import time

HOME = os.path.expanduser("~")
STATE_FILE = HOME + "/.local/state/omarchy/toggles/hypr/tablet-mode-on"
MODE_SCRIPT = HOME + "/.config/hypr/scripts/tablet-mode.sh"

EV_KEY, EV_REL, EV_ABS = 1, 2, 3
EVENT_FMT = "llHHI"
EVENT_SIZE = struct.calcsize(EVENT_FMT)

GRACE_SECS = 3.0          # ignore folding jostle right after entering tablet
POLL_TIMEOUT = 1.0


def notify(msg):
    for cmd in (["omarchy-notification-send", "-u", "low", msg],
                ["notify-send", msg]):
        try:
            subprocess.run(cmd, check=False,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return
        except FileNotFoundError:
            continue


def find_handler(want):
    """Resolve /dev/input/eventN for a device name fragment via /proc."""
    name, handler = "", ""
    try:
        with open("/proc/bus/input/devices") as f:
            for line in f:
                if line.startswith("N:"):
                    name = line
                elif line.startswith("H:"):
                    if want in name:
                        m = re.search(r"event\d+", line)
                        if m:
                            return "/dev/input/" + m.group(0)
                    name = ""
    except OSError:
        pass
    return ""


def open_nb(path):
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
        # Drain anything queued before we started watching.
        try:
            while os.read(fd, 4096):
                pass
        except (OSError, BlockingIOError):
            pass
        return fd
    except OSError:
        return -1


def read_events(fd):
    try:
        data = os.read(fd, EVENT_SIZE * 32)
    except (OSError, BlockingIOError):
        return
    for off in range(0, len(data) - EVENT_SIZE + 1, EVENT_SIZE):
        _, _, typ, _code, val = struct.unpack(
            EVENT_FMT, data[off:off + EVENT_SIZE])
        yield typ, val


def main(test_device="", dry_run=False):
    if test_device:
        kbd_path = test_device
    else:
        kbd_link = "/dev/input/by-path/platform-i8042-serio-0-event-kbd"
        kbd_path = kbd_link if os.path.exists(kbd_link) else find_handler(
            "AT Translated Set 2 keyboard")

    kbd = open_nb(kbd_path) if kbd_path else -1
    if kbd < 0:
        return 0  # no permission (pre-input-group login?) — manual EXIT stays

    fds = [kbd]
    # tablet-mode.sh starts us before it writes STATE_FILE — wait for it
    # instead of exiting instantly on a missing file (race, seen 2026-09-05).
    for _ in range(50):
        if os.path.exists(STATE_FILE):
            break
        time.sleep(0.2)
    else:
        return 0
    start = time.monotonic()

    while os.path.exists(STATE_FILE):
        try:
            r, _, _ = select.select(fds, [], [], POLL_TIMEOUT)
        except (OSError, ValueError):
            break
        now = time.monotonic()
        if now - start < GRACE_SECS:
            for fd in r:
                for _ in read_events(fd):
                    pass
            continue
        for fd in r:
            for typ, val in read_events(fd):
                if typ == EV_KEY and val in (1, 2):
                    return trigger(dry_run, "keyboard")
    return 0


def trigger(dry_run, via):
    if dry_run:
        print("would-exit-via-" + via)
        return 0
    notify("Laptop input detected — leaving tablet mode")
    subprocess.run([MODE_SCRIPT, "off"], check=False)
    return 0


if __name__ == "__main__":
    args = sys.argv[1:]
    sys.exit(main(test_device=args[args.index("--test-device") + 1]
             if "--test-device" in args else "",
             dry_run="--dry-run" in args))
