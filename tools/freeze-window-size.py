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

ONLY THE SIZE FIELDS ARE TOUCHED.  The rest of WM_NORMAL_HINTS is read back and
written out unchanged, and win_gravity is the reason.  ICCCM lets that field
decide what a move request means: with StaticGravity the requested position is
where the CLIENT goes, with the default NorthWestGravity it is where the FRAME
goes and the client lands one border and one title bar further in.  Writing a
fresh hints structure dropped PWinGravity, so every Qt window - which asks for
StaticGravity - silently moved from 0,0 to 1,23 under fluxbox, hung 22 px off
the bottom of the screen, and `import -window` returned the visible 1439x877
instead of the recorded 1440x900:

    [check-image] size mismatch: actual=1439x877 ref=1440x900

which is how okular and qpdfview failed.  Apps that ask for NorthWestGravity
(atril, xpdf, xlogo) were never affected and are not affected by preserving it
either - their recordings already carry the offset frame.

Usage: freeze-window-size.py <window_id> <width> <height>
  window_id may be decimal or 0x-hex (xdotool prints decimal).
"""
from __future__ import annotations

import sys

from Xlib import Xutil, display


def _current_hints(win) -> dict:
    """Return the window's WM_NORMAL_HINTS as keyword arguments for set_wm_normal_hints.

    A window that carries no hints yet gets an empty structure with
    NorthWestGravity, which is what ICCCM says an absent win_gravity means - so
    the fallback states the default rather than leaving the field at 0, a value
    that is not a gravity at all and that fluxbox reads as "no offset".
    """
    hints = win.get_wm_normal_hints()
    if not hints:
        return {"flags": Xutil.PWinGravity, "win_gravity": Xutil.NorthWestGravity}

    return {
        "flags":       hints.flags | Xutil.PWinGravity,
        "min_width":   hints.min_width,
        "min_height":  hints.min_height,
        "max_width":   hints.max_width,
        "max_height":  hints.max_height,
        "width_inc":   hints.width_inc,
        "height_inc":  hints.height_inc,
        "min_aspect":  {"num": hints.min_aspect.num, "denum": hints.min_aspect.denum},
        "max_aspect":  {"num": hints.max_aspect.num, "denum": hints.max_aspect.denum},
        "base_width":  hints.base_width,
        "base_height": hints.base_height,
        "win_gravity": hints.win_gravity or Xutil.NorthWestGravity,
    }


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
        # Pin min == max == target so the size cannot change. PResizeInc is
        # cleared (no increments) so nothing snaps the window to a larger step;
        # everything else the app asked for - win_gravity above all - is carried
        # over from the hints already on the window. See the module docstring.
        hints = _current_hints(win)
        hints.update(
            flags=(hints["flags"] & ~Xutil.PResizeInc)
                  | Xutil.PMinSize | Xutil.PMaxSize | Xutil.PSize | Xutil.USSize,
            min_width=width,  min_height=height,
            max_width=width,  max_height=height,
            width=width,      height=height,
            width_inc=0,      height_inc=0,
        )
        win.set_wm_normal_hints(**hints)
        # Apply the size immediately in case the app is currently larger/smaller.
        win.configure(width=width, height=height)
        d.sync()
    finally:
        d.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
