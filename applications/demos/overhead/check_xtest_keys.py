#!/usr/bin/env python3
"""Show that replay.py's xtest injector sends every recorded key the way xdotool does.

Without a display, lists every distinct key name in the committed macros and
resolves it to a keysym the way XTestInjector does, through xdotool's aliases
and python-xlib. Where libX11 can be loaded it also checks that python-xlib and
libX11's XStringToKeysym, which is what xdotool calls, agree on every name.

With --display, also resolves each name to a keycode on that server, and then
replays a press and a release of every name and every mouse button twice, once
with one xdotool process per event and once with XTestInjector, while an XRecord
client records the device events the server generates. The two recordings must
be identical. That presses every key, so use a display with nothing on it.

Needs python-xlib, so run it in the window container.

    docker run --rm -v "$PWD":/tmp/repo:ro ribalba/xwindow-server \\
        python3 /tmp/repo/applications/demos/overhead/check_xtest_keys.py

    # With a bare X server and no window manager to react to the keys.
    docker run --rm -v "$PWD":/tmp/repo:ro ribalba/xwindow-server bash -c \\
        'Xvfb :99 -screen 0 1440x900x24 & sleep 1; DISPLAY=:99 \\
         python3 /tmp/repo/applications/demos/overhead/check_xtest_keys.py --display :99'

Exits 1 when a name does not resolve, resolves differently, falls back to
xdotool, or produces different device events.
"""

from __future__ import annotations

import argparse
import collections
import ctypes
import ctypes.util
import os
import subprocess
import sys
import threading
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO))

from replay import XTestInjector  # noqa: E402  (needs the path set up above)

MACRO_SUFFIXES = (".parrot", ".🦜")
MACRO_ROOTS = ("applications/", "websites/")
KEY_VERBS = ("keydown", "keyup")


def macro_files() -> tuple[list[Path], str]:
    """The committed macros, or every macro on disk when git is not available."""
    try:
        listed = subprocess.run(
            ["git", "-C", str(REPO), "-c", "core.quotepath=off", "ls-files", "-z"],
            capture_output=True, text=True, check=True,
        ).stdout.split("\0")
        source = "git ls-files"
    except (OSError, subprocess.CalledProcessError):
        listed = [str(p.relative_to(REPO)) for root in MACRO_ROOTS
                  for p in (REPO / root).rglob("*") if p.is_file()]
        source = "the files on disk (no git here)"
    files = sorted(REPO / name for name in listed
                   if name.endswith(MACRO_SUFFIXES) and name.startswith(MACRO_ROOTS))
    return files, source


def key_names(files: list[Path]) -> collections.Counter:
    names: collections.Counter = collections.Counter()
    for path in files:
        for raw in path.read_text(encoding="utf-8").splitlines():
            parts = raw.split()
            if len(parts) >= 2 and parts[0].lower() in KEY_VERBS:
                names[parts[1]] += 1
    return names


def libx11_string_to_keysym():
    """XStringToKeysym from libX11, or None when the library cannot be loaded."""
    try:
        lib = ctypes.CDLL(ctypes.util.find_library("X11") or "libX11.so.6")
    except OSError:
        return None
    func = lib.XStringToKeysym
    func.restype = ctypes.c_ulong
    func.argtypes = [ctypes.c_char_p]
    return lambda name: func(name.encode())


def static_check(names: collections.Counter) -> bool:
    from Xlib import X, XK  # noqa: PLC0415

    ok = True
    x11 = libx11_string_to_keysym()
    print(f"{'name':<12} {'uses':>6}  {'keysym':>8}  libX11")
    for name in sorted(names):
        resolved = XTestInjector.ALIASES.get(name.lower(), name)
        keysym = XK.string_to_keysym(resolved)
        verdict = ""
        if x11 is not None:
            verdict = "same" if x11(resolved) == keysym else f"DIFFERENT ({x11(resolved):#x})"
        if keysym == X.NoSymbol or set(name) & XTestInjector.REJECTED_CHARS or verdict.startswith("DIFF"):
            ok = False
            verdict += "  <- does NOT resolve under the xtest path"
        print(f"{name:<12} {names[name]:>6}  {keysym:#8x}  {verdict}")

    if x11 is None:
        print("libX11 not found: python-xlib was not compared with XStringToKeysym")
    else:
        # Every name python-xlib knows by default, not only the recorded ones.
        known = [attr[3:] for attr in dir(XK) if attr.startswith("XK_")]
        differ = [n for n in known if x11(n) != XK.string_to_keysym(n)]
        print(f"python-xlib and libX11 agree on {len(known) - len(differ)} of {len(known)} "
              f"keysym names python-xlib knows" + (f", differ on {differ}" if differ else ""))
        ok = ok and not differ
    return ok


class DeviceEventRecorder:
    """Collect the core device events a server generates, from an XRecord context."""

    def __init__(self, display: str) -> None:
        from Xlib import X  # noqa: PLC0415
        from Xlib import display as xdisplay  # noqa: PLC0415
        from Xlib.ext import record  # noqa: PLC0415
        from Xlib.protocol import rq  # noqa: PLC0415

        self._record, self._rq = record, rq
        self._control = xdisplay.Display(display)
        self._data = xdisplay.Display(display)
        if not self._data.has_extension("RECORD"):
            raise SystemExit(f"{display} has no RECORD extension")
        self._context = self._data.record_create_context(0, [record.AllClients], [{
            "core_requests": (0, 0), "core_replies": (0, 0),
            "ext_requests": (0, 0, 0, 0), "ext_replies": (0, 0, 0, 0),
            "delivered_events": (0, 0),
            "device_events": (X.KeyPress, X.MotionNotify),
            "errors": (0, 0), "client_started": False, "client_died": False,
        }])
        self._lock = threading.Lock()
        self._events: list[tuple] = []
        self._thread = threading.Thread(
            target=self._data.record_enable_context, args=(self._context, self._on_reply),
            daemon=True,
        )
        self._thread.start()
        time.sleep(0.2)

    def _on_reply(self, reply) -> None:
        if reply.category != self._record.FromServer or reply.client_swapped:
            return
        data = reply.data
        while len(data) >= 32:
            event, data = self._rq.EventField(None).parse_binary_value(
                data, self._data.display, None, None)
            with self._lock:
                self._events.append((event.type, event.detail))

    def capture(self, send) -> list[tuple]:
        """Return the device events generated while *send* runs."""
        time.sleep(0.05)
        with self._lock:
            self._events.clear()
        send()
        time.sleep(0.15)
        with self._lock:
            return list(self._events)

    def close(self) -> None:
        self._control.record_disable_context(self._context)
        self._control.sync()
        self._thread.join(timeout=2)
        self._control.close()


def display_check(display: str, names: collections.Counter) -> bool:
    from Xlib import X  # noqa: PLC0415

    env = {**os.environ, "DISPLAY": display}
    injector = XTestInjector(display)
    recorder = DeviceEventRecorder(display)
    labels = {X.KeyPress: "press", X.KeyRelease: "release",
              X.ButtonPress: "press", X.ButtonRelease: "release"}

    def describe(events: list[tuple]) -> str:
        return " ".join(f"{labels.get(t, t)}:{d}" for t, d in events) or "(none)"

    def xdotool(down: str, up: str, arg: str):
        return lambda: [subprocess.run(["xdotool", verb, arg], env=env, check=False)
                        for verb in (down, up)]

    def xtest(down: str, up: str, arg: str):
        return lambda: [injector.send((verb, arg)) for verb in (down, up)]

    cases = [("key", name, "keydown", "keyup") for name in sorted(names)]
    cases += [("button", str(b), "mousedown", "mouseup") for b in range(1, 6)]

    ok = True
    print(f"\n{'':<7}{'name':<12} {'keycode':>7} {'mods':>5}  device events (xdotool = xtest)")
    try:
        for kind, arg, down, up in cases:
            keycode = mods = "-"
            if kind == "key":
                key = injector._resolve_key(arg)  # noqa: SLF001 - the point of the check
                if key is None:
                    print(f"{kind:<7}{arg:<12} falls back to xdotool  <- FALLBACK")
                    ok = False
                    continue
                keycode, mods = key[0], f"{key[1]:#x}"
            by_xdotool = recorder.capture(xdotool(down, up, arg))
            by_xtest = recorder.capture(xtest(down, up, arg))
            same = by_xdotool == by_xtest and by_xdotool
            if not same:
                ok = False
            print(f"{kind:<7}{arg:<12} {keycode:>7} {mods:>5}  {describe(by_xtest)}"
                  + ("" if same else f"  <- DIFFERENT, xdotool sent {describe(by_xdotool)}"))
    finally:
        recorder.close()
        injector.close()
    print(f"fallbacks: {injector.fallbacks}")
    return ok and injector.fallbacks == 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    parser.add_argument("--display", default=None,
                        help="also resolve keycodes on this display and compare the device "
                             "events of both injectors (presses every key)")
    args = parser.parse_args(argv)

    files, source = macro_files()
    names = key_names(files)
    print(f"{len(names)} distinct key names, {sum(names.values())} key events, "
          f"in {len(files)} macros from {source}\n")
    ok = static_check(names)
    if args.display:
        ok = display_check(args.display, names) and ok
    print("\nOK" if ok else "\nFAILED")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
