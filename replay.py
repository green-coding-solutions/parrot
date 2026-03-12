#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import time
from pathlib import Path

from helpers import load_app_metadata
from timed_xmacro import iter_replay_lines, parse_xmacro_event

CHECK_IMAGE_SCRIPT   = "/usr/local/bin/check-image.sh"
POSITION_WINDOW_SCRIPT = "/usr/local/bin/position-window.sh"


# ---------------------------------------------------------------------------
# CLI / configuration
# ---------------------------------------------------------------------------

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Replay a .🦜 xmacro recording inside the current container"
    )
    parser.add_argument("macro_file", help="Path to the .🦜 recording file")
    parser.add_argument(
        "--display",
        default=os.environ.get("DISPLAY", ":99"),
        help="X display to use (default: $DISPLAY or :99)",
    )
    return parser.parse_args()


def parse_speed() -> float:
    """Read REPLAY_SPEED from the environment (default 1.0)."""
    raw = os.environ.get("REPLAY_SPEED", "1.0")
    try:
        speed = float(raw)
    except ValueError:
        raise SystemExit(f"Invalid REPLAY_SPEED: {raw}")
    if speed <= 0:
        raise SystemExit("REPLAY_SPEED must be > 0")
    return speed


# ---------------------------------------------------------------------------
# Window size hint (read from the first Check image in the recording)
# ---------------------------------------------------------------------------

def _png_dimensions(path: Path) -> tuple[int, int] | None:
    """Return (width, height) from a PNG header, or None if unreadable."""
    try:
        header = path.read_bytes()[:24]
    except OSError:
        return None
    if len(header) < 24 or header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
        return None
    width  = int.from_bytes(header[16:20], "big")
    height = int.from_bytes(header[20:24], "big")
    return (width, height) if width > 0 and height > 0 else None


def infer_window_size(macro_file: Path) -> tuple[int, int] | None:
    """
    Scan the recording for the first Check line and return that image's size.
    Check refs are relative to the application directory, e.g.:
        Check firefox/firefox-check-001.png
    so we try both macro_file.parent.parent and macro_file.parent as roots.
    """
    try:
        lines = macro_file.read_text(encoding="utf-8").splitlines()
    except OSError:
        return None

    for raw in lines:
        line = raw.strip()
        if not line.lower().startswith("check "):
            continue
        ref = line[len("check "):].strip()

        ref_path = Path(ref)
        for root in (macro_file.parent.parent, macro_file.parent):
            size = _png_dimensions(root / ref_path)
            if size:
                return size
    return None


# ---------------------------------------------------------------------------
# App window management
# ---------------------------------------------------------------------------

def _find_window(display: str, window_class: str, window_title: str) -> str | None:
    """Return the first visible xdotool window ID matching class or title."""
    env = {**os.environ, "DISPLAY": display}
    for flag, value in [("--class", window_class), ("--name", window_title)]:
        if not value:
            continue
        result = subprocess.run(
            ["xdotool", "search", "--onlyvisible", flag, value],
            env=env, capture_output=True, text=True,
        )
        ids = result.stdout.strip().splitlines()
        if ids:
            return ids[0]
    return None


def focus_app(app_meta: dict[str, str], display: str, window_size: tuple[int, int] | None) -> None:
    """
    Ensure the app is running, positioned, and in the foreground.

    1. Try to find an existing window by class / title.
    2. If not found, launch the app via startcommand and wait briefly.
    3. Run position-window.sh to size and place it.
    4. Raise and focus the window.
    """
    env = {**os.environ, "DISPLAY": display}
    win_class  = app_meta.get("windowclass", "")
    win_title  = app_meta.get("windowtitle", "")
    start_cmd  = app_meta.get("startcommand", "")

    win = _find_window(display, win_class, win_title)

    if win is None and start_cmd:
        print(f"[replay] window not found — launching: {start_cmd}")
        with open("/tmp/xtest-app-launch.log", "w") as log:
            subprocess.Popen(["bash", "-lc", start_cmd], env=env, stdout=log, stderr=log)
        time.sleep(1)
        win = _find_window(display, win_class, win_title)

    pos_env = {
        **env,
        "APP_WINDOW_CLASS": win_class,
        "APP_WINDOW_TITLE": win_title,
    }
    if window_size is not None:
        pos_env.setdefault("WINDOW_WIDTH",  str(window_size[0]))
        pos_env.setdefault("WINDOW_HEIGHT", str(window_size[1]))
    subprocess.run([POSITION_WINDOW_SCRIPT], env=pos_env, check=False)

    win = _find_window(display, win_class, win_title)
    if win:
        subprocess.run(["xdotool", "windowraise", win], env=env, check=False)
        subprocess.run(["xdotool", "windowfocus", win], env=env, check=False)
        time.sleep(0.1)


# ---------------------------------------------------------------------------
# Lock-key normalisation
# ---------------------------------------------------------------------------

def _lock_key_state(display: str, label: str) -> str | None:
    """Query xset and return 'on' or 'off' for the given lock key label."""
    if not shutil.which("xset"):
        return None
    result = subprocess.run(
        ["xset", "q"], env={**os.environ, "DISPLAY": display},
        capture_output=True, text=True,
    )
    for line in result.stdout.lower().splitlines():
        if label.lower() + ":" in line:
            if re.search(r":\s*on\b",  line):
                return "on"
            if re.search(r":\s*off\b", line):
                return "off"
    return None


def normalize_lock_key(display: str, label: str, xdotool_key: str, desired: str) -> None:
    """Toggle a lock key if its current state differs from *desired* ('on'/'off'/'keep')."""
    if desired == "keep":
        return
    current = _lock_key_state(display, label)
    if current and current != desired:
        subprocess.run(
            ["xdotool", "key", xdotool_key],
            env={**os.environ, "DISPLAY": display}, check=False,
        )


# ---------------------------------------------------------------------------
# Replay event loop
# ---------------------------------------------------------------------------

def resolve_check_ref(ref: str, app_dir: Path) -> str:
    """
    Resolve a relative check image path to absolute.

    Refs are written as  'firefox/firefox-check-001.png'  (app-name/filename).
    We look first in app_dir.parent (the applications root) then in app_dir.
    """
    if Path(ref).is_absolute():
        return ref
    for root in (app_dir.parent, app_dir):
        candidate = root / ref
        if candidate.is_file():
            return str(candidate)
    return ref  # let check-image.sh produce a clear error message


def dispatch(action: tuple, display: str, app_meta: dict[str, str], app_dir: Path) -> None:
    """Execute a single parsed replay action."""
    env  = {**os.environ, "DISPLAY": display}
    op   = action[0]

    if op == "mousemove":
        subprocess.run(["xdotool", "mousemove", action[1], action[2]], env=env, check=False)
    elif op == "mousedown":
        subprocess.run(["xdotool", "mousedown", action[1]], env=env, check=False)
    elif op == "mouseup":
        subprocess.run(["xdotool", "mouseup",   action[1]], env=env, check=False)
    elif op == "keydown":
        subprocess.run(["xdotool", "keydown",   action[1]], env=env, check=False)
    elif op == "keyup":
        subprocess.run(["xdotool", "keyup",     action[1]], env=env, check=False)
    elif op == "check":
        ref = resolve_check_ref(action[1], app_dir)
        check_env = {
            **env,
            "APP_WINDOW_CLASS":  app_meta.get("windowclass", ""),
            "APP_WINDOW_TITLE":  app_meta.get("windowtitle", ""),
            "CHECK_MAX_RMSE":    os.environ.get("CHECK_MAX_RMSE",    ""),
            "CHECK_IGNORE_RECT": os.environ.get("CHECK_IGNORE_RECT", ""),
        }
        subprocess.run([CHECK_IMAGE_SCRIPT, ref], env=check_env, check=True)


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> int:
    args = parse_args()

    macro_file = Path(args.macro_file).resolve()
    if not macro_file.is_file():
        print(f"Macro file not found: {macro_file}")
        return 1

    display = args.display
    if not display:
        print("--display must not be empty")
        return 1

    speed    = parse_speed()
    app_meta = load_app_metadata(macro_file)
    app_dir  = macro_file.parent   # e.g. applications/firefox/

    window_size = infer_window_size(macro_file)

    print(f"Replaying : {macro_file}")
    print(f"Display   : {display}  speed={speed}")
    print(f"App class : {app_meta.get('windowclass', '')}  title: {app_meta.get('windowtitle', '')}")
    if app_meta.get("startcommand"):
        print(f"Start cmd : {app_meta['startcommand']}")
    if window_size:
        print(f"Win size  : {window_size[0]}x{window_size[1]} (from check image)")

    # 1. Ensure the app is running and focused.
    focus_app(app_meta, display, window_size)

    # 2. Make lock-key state deterministic before replaying key events.
    normalize_lock_key(display, "Caps Lock",   "Caps_Lock",   os.environ.get("REPLAY_INIT_CAPSLOCK",   "off"))
    normalize_lock_key(display, "Num Lock",    "Num_Lock",    os.environ.get("REPLAY_INIT_NUMLOCK",    "off"))
    normalize_lock_key(display, "Scroll Lock", "Scroll_Lock", os.environ.get("REPLAY_INIT_SCROLLLOCK", "keep"))

    # 3. Parse the recording and replay each event in-process.
    #    iter_replay_lines() sleeps between events to honour the recorded timing.
    for line in iter_replay_lines(macro_file, speed):
        action = parse_xmacro_event(line)
        if action is not None:
            dispatch(action, display, app_meta, app_dir)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
