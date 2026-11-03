#!/usr/bin/env python3
"""Emit keyboard press timestamps for the keycount shell plugin."""

import glob
import json
import os
import select
import struct
import sys
import time

EVENT = struct.Struct("llHHI")
KEY_LEFTSHIFT = 42
KEY_RIGHTSHIFT = 54
KEY_K = 37
DOUBLE_TAP_WINDOW = 0.35


def devices():
    paths = sorted(glob.glob("/dev/input/by-path/*-event-kbd"))
    return [os.open(path, os.O_RDONLY | os.O_NONBLOCK) for path in paths]


def main():
    handles = devices()
    if not handles:
        return 1
    last_k = 0.0
    try:
        while True:
            ready, _, _ = select.select(handles, [], [], 1.0)
            for handle in ready:
                while True:
                    try:
                        data = os.read(handle, EVENT.size)
                    except BlockingIOError:
                        break
                    if len(data) != EVENT.size:
                        break
                    _, _, event_type, code, value = EVENT.unpack(data)
                    if event_type == 1 and value == 1 and code not in (KEY_LEFTSHIFT, KEY_RIGHTSHIFT):
                        now = time.monotonic()
                        toggle = code == KEY_K and now - last_k <= DOUBLE_TAP_WINDOW
                        if code == KEY_K:
                            last_k = now
                        sys.stdout.write(json.dumps({"key": int(code), "toggle": toggle}) + "\n")
                        sys.stdout.flush()
    finally:
        for handle in handles:
            os.close(handle)
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
