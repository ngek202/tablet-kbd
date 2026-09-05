#!/usr/bin/env python3
# Double-tap warps the cursor to the tap point; single taps stay
# cursor-less (Wayland touch paradigm). Pointer-on-demand for touch use.
# Detection is kernel-level (BTN_TOUCH pairs), so it works everywhere.
# Coordinate mapping mirrors the display transform (same convention as
# auto-rotate.sh); portrait formulas are calibrated live — if the cursor
# lands mirrored, swap the t1/t3 arms below.
import array
import fcntl
import json
import os
import re
import select
import struct
import subprocess
import sys
import time

HOME = os.path.expanduser("~")
LOG = HOME + "/.local/state/omarchy/touch-cursor.log"
CRASH_LOG = "/tmp/touch-cursor-crash.log"

EV_FMT = "llHHi"  # kernel input_event: value is SIGNED (__s32)
EV_SIZE = struct.calcsize(EV_FMT)
EV_ABS, EV_KEY = 3, 1
ABS_X, ABS_Y = 0x00, 0x01
BTN_TOUCH = 0x14A

DOUBLE_MS = 800  # touch double-taps run slower than mouse clicks;
# 400ms caught only triple-clicks, 600ms still missed slow pairs.
RADIUS_UNITS = 450  # ~3% of panel diagonal


def log(msg):
    try:
        with open(LOG, "a") as f:
            f.write(f"{time.strftime('%H:%M:%S')} {msg}\n")
    except OSError:
        pass


def resolve_sig():
    if os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"):
        return True
    try:
        uid = str(os.getuid())
        d = f"/run/user/{uid}/hypr"
        newest = sorted(os.listdir(d), key=lambda n: os.stat(
            os.path.join(d, n)).st_mtime, reverse=True)[0]
        os.environ["HYPRLAND_INSTANCE_SIGNATURE"] = newest
        return True
    except (OSError, IndexError):
        return False


def find_finger():
    name = ""
    try:
        with open("/proc/bus/input/devices") as f:
            for line in f:
                if line.startswith("N:"):
                    name = line
                elif line.startswith("H:"):
                    if "Wacom HID 5272 Finger" in name:
                        m = re.search(r"event\d+", line)
                        if m:
                            return "/dev/input/" + m.group(0)
                    name = ""
    except OSError:
        pass
    return ""


def abs_range(fd, axis):
    buf = array.array("i", [0] * 5)
    req = (2 << 30) | (20 << 16) | (0x45 << 8) | (0x40 + axis)
    fcntl.ioctl(fd, req, buf, True)
    return buf[1], buf[2]  # min, max


def screen_geo():
    """(LOGICAL W, H, transform) for eDP-1. monitors -j reports physical
    mode size — divide by scale (cursor.move + cursorpos live in logical
    space; seen 2026-09-05: asking x=1900 clamps at 1535=1920/1.25)."""
    try:
        out = subprocess.run(["hyprctl", "monitors", "-j"],
                             capture_output=True, text=True,
                             timeout=5).stdout
        for m in json.loads(out):
            if m.get("name") == "eDP-1":
                s = m.get("scale", 1) or 1
                t = m.get("transform", 0)
                w, h = m["width"] / s, m["height"] / s
                if t in (1, 3):  # portrait: physical dims don't rotate
                    w, h = h, w
                return w, h, t
    except Exception:
        pass
    return 1536, 864, 0


def to_screen(x, y, xmax, ymax, W, H, t):
    # Kernel axes are fixed to the panel (+x toward device-right,
    # +y toward device-bottom). Derived 2026-09-05 from the physical
    # rotation (NOT guessed): right-up = device CCW, so device-right
    # points viewer-up and device-bottom points viewer-right.
    # t1/t3 were swapped in the first version — symptom: cursor lands
    # mirrored (far window instead of under finger).
    nx, ny = x / xmax, y / ymax
    if t == 1:  # left-up (device CW): +x -> viewer-down, +y -> viewer-left
        return W - ny * W, nx * H
    if t == 2:  # bottom-up (180, symmetric)
        return W - nx * W, H - ny * H
    if t == 3:  # right-up (device CCW): +x -> viewer-up, +y -> viewer-right
        return ny * W, H - nx * H
    return nx * W, ny * H


def warp(sx, sy):
    """Absolute warp via the native cursor dispatcher (found by probing
    hl.dsp: cursor.move takes { x, y }). No converge loop, no uinput,
    rotation handled by the target mapping in to_screen()."""
    if not resolve_sig():
        log("warp: no signature")
        return False
    try:
        r = subprocess.run(
            ["hyprctl", "eval",
             f"hl.dispatch(hl.dsp.cursor.move({{ x = {int(sx)}, "
             f"y = {int(sy)} }}))"],
            capture_output=True, text=True, timeout=5)
        ok = r.returncode == 0 and "error" not in (r.stdout + r.stderr)[:60]
        if not ok:
            log(f"warp eval failed: {(r.stdout + r.stderr)[:120]}")
        return ok
    except Exception as e:
        log(f"warp failed: {e}")
        return False


def _osk_open():
    """True while our board is up (typing context — never warp)."""
    try:
        r = subprocess.run(["pgrep", "-f", "[c]ustom-kbd\\.py"],
                           capture_output=True, timeout=5)
        return r.returncode == 0
    except Exception:
        return False


def watch(fd, xmax, ymax):
    x = y = None
    last_t, last_x, last_y = 0.0, 0, 0
    in_contact, contact_pos = False, []
    geo_at = 0.0
    W, H, t = 1536, 864, 0
    while True:
        r, _, _ = select.select([fd], [], [], 1.0)
        if not r:
            continue
        try:
            data = os.read(fd, EV_SIZE * 64)
        except BlockingIOError:
            continue
        for off in range(0, len(data) - EV_SIZE + 1, EV_SIZE):
            try:
                _, _, typ, code, val = struct.unpack(
                    EV_FMT, data[off:off + EV_SIZE])
            except struct.error:
                break
            if typ == EV_ABS and code == ABS_X:
                x = val
                if in_contact:
                    contact_pos.append((val, y))
            elif typ == EV_ABS and code == ABS_Y:
                y = val
                if in_contact and x is not None:
                    contact_pos.append((x, val))
            elif typ == EV_KEY and code == BTN_TOUCH:
                if val == 1 and not in_contact:
                    in_contact, contact_pos = True, []
                elif val == 0 and in_contact:
                    in_contact = False
                    # Tap point: freshest in-contact position wins (DOWN
                    # itself carries no coordinates); a perfectly still
                    # finger emits no ABS during contact, so fall back to
                    # last-known coords (never drop taps).
                    if contact_pos:
                        tx, ty = contact_pos[-1]
                        tx = tx if tx is not None else x
                        ty = ty if ty is not None else y
                    else:
                        tx, ty = x, y
                    if tx is None or ty is None:
                        continue
                    now = time.monotonic() * 1000
                    dx, dy = tx - last_x, ty - last_y
                    if now - last_t < DOUBLE_MS and \
                            dx * dx + dy * dy < \
                            RADIUS_UNITS * RADIUS_UNITS:
                        if _osk_open():
                            # Board is up: only skip taps landing ON it
                            # (typing double-letters). Taps elsewhere warp
                            # normally — pointer on demand must work with
                            # the board open (tablet has no touchpad).
                            if time.monotonic() - geo_at > 5:
                                W, H, t = screen_geo()
                                geo_at = time.monotonic()
                            _sx, _sy = to_screen(tx, ty, xmax, ymax, W, H, t)
                            if _sy > H - 380:
                                last_t = 0.0
                                continue
                        if time.monotonic() - geo_at > 5:
                            W, H, t = screen_geo()
                            geo_at = time.monotonic()
                        sx, sy = to_screen(tx, ty, xmax, ymax, W, H, t)
                        ok = warp(sx, sy)
                        log(f"warp x={tx} y={ty} -> {int(sx)},{int(sy)} "
                            f"t={t} ok={ok}")
                        last_t = 0.0
                    else:
                        last_t, last_x, last_y = now, tx, ty


def main():
    while True:
        node = find_finger()
        if not node:
            time.sleep(5)
            continue
        try:
            fd = os.open(node, os.O_RDONLY | os.O_NONBLOCK)
            _, xmax = abs_range(fd, ABS_X)
            _, ymax = abs_range(fd, ABS_Y)
            log(f"listening {node} xmax={xmax} ymax={ymax}")
            watch(fd, xmax, ymax)
        except OSError as e:
            log(f"device error: {e}")
            try:
                os.close(fd)
            except Exception:
                pass
            time.sleep(5)
        except Exception:
            with open(CRASH_LOG, "a") as f:
                f.write(time.strftime("[%H:%M:%S] "))
                import traceback
                traceback.print_exc(file=f)
            time.sleep(5)


main()
