#!/usr/bin/env python3
"""Resize an X window and freeze its size by pinning WM_NORMAL_HINTS.

A plain `xdotool windowsize` only sends a one-off resize request. Toolkit apps
like xpdf (Motif/Xt) re-assert a preferred geometry through WM_NORMAL_HINTS
shortly after launch and whenever they load a document, which silently
overrides that request — so the window drifts to a size we never asked for
(we observed 878 on one run, 845 on the next).

Setting min == max == target marks the window non-resizable. A conforming
window manager then clamps every later resize request (the app's included)
back to exactly that size, so the geometry stays put for the whole replay.

Usage: freeze-window-size.py <window_id> <width> <height>
  window_id may be decimal or 0x-hex (xdotool prints decimal).
"""
from __future__ import annotations

import sys

from Xlib import Xutil, display


def main() -> int:
    if len(sys.argv) != 4:
        print("usage: freeze-window-size.py <window_id> <width> <height>", file=sys.stderr)
        return 2

    win_id = int(sys.argv[1], 0)
    width  = int(sys.argv[2])
    height = int(sys.argv[3])

    d = display.Display()  # honours $DISPLAY
    try:
        win = d.create_resource_object("window", win_id)
        # Pin min == max == target so the size cannot change. PResizeInc is left
        # unset (no increments) so nothing snaps the window to a larger step.
        win.set_wm_normal_hints(
            flags=(Xutil.PMinSize | Xutil.PMaxSize | Xutil.PSize | Xutil.USSize),
            min_width=width,  min_height=height,
            max_width=width,  max_height=height,
            width=width,      height=height,
        )
        # Apply the size immediately in case the app is currently larger/smaller.
        win.configure(width=width, height=height)
        d.sync()
    finally:
        d.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
