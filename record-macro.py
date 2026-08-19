#!/usr/bin/env python3
"""Record a Parrot .🦜 macro by capturing input from a running container.

The container must already be running with the display environment ready
(e.g. via entrypoint.sh). Use --container to override the default name.

Example:
  python3 record-macro.py applications/firefox/firefox.🦜 \\
      --startcommand "firefox https://browserbench.org/Speedometer3.1/ --no-default-browser-check" \\
      --windowtitle Firefox --windowclass firefox
"""

from __future__ import annotations

import argparse
import os
import shlex
import subprocess
import sys
import time
from pathlib import Path


def _status(message: str) -> None:
    """Emit startup/status output immediately to preserve terminal ordering."""
    print(message, flush=True)


def _run_quiet(cmd: list[str]) -> subprocess.CompletedProcess:
    """Run a subprocess without letting incidental tool output disrupt the checklist."""
    return subprocess.run(
        cmd,
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Record a .🦜 macro from a running container",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("output", type=Path, help="Path to write the .🦜 recording")
    parser.add_argument("--startcommand", default="",   help="Command to launch the app")
    parser.add_argument("--windowtitle",  default="",   help="Window title for app detection")
    parser.add_argument("--windowclass",  default="",   help="WM_CLASS for app detection")
    # Only for an app whose driven window does not exist until the macro has
    # clicked through a startup dialog - the JetBrains IDEs. See STARTUP_FIELDS
    # in helpers.py. Default None, not "": an omitted option must stay out of the
    # recording, while an explicit empty one is a deliberate "match on the other
    # half alone" and is written.
    parser.add_argument("--startupwindowtitle", default=None,
                        help="Title of a window proving the app started, if not --windowtitle")
    parser.add_argument("--startupwindowclass", default=None,
                        help="WM_CLASS of a window proving the app started, if not --windowclass")
    parser.add_argument(
        "--script",
        type=Path,
        default=None,
        help="Optional checkpoint note script; one trimmed non-comment line is used per Scroll Lock checkpoint",
    )
    parser.add_argument(
        "--display",
        default=None,
        help="X display to use (default: container $DISPLAY or :99)",
    )
    parser.add_argument(
        "--save-dir",
        default=None,
        help="Container path for screenshots (default: /save_dir if it exists)",
    )
    parser.add_argument("--container", default="window-container", help="Docker container name")
    parser.add_argument("--container-repo", default="/tmp/repo",
                        help="Path where the project repo is mounted in the container")
    return parser.parse_args()


def _find_window(container: str, display: str, window_class: str, window_title: str) -> str | None:
    """Return the largest visible xdotool window ID from inside the container."""
    for flag, value in [("--class", window_class), ("--name", window_title)]:
        if not value:
            continue
        result = subprocess.run(
            ["docker", "exec", "-e", f"DISPLAY={display}", container,
             "xdotool", "search", "--onlyvisible", flag, value],
            capture_output=True, text=True,
        )
        ids = result.stdout.strip().splitlines()
        if ids:
            best_id = None
            best_area = -1
            for window_id in ids:
                geom = subprocess.run(
                    ["docker", "exec", "-e", f"DISPLAY={display}", container,
                     "xdotool", "getwindowgeometry", "--shell", window_id],
                    capture_output=True, text=True,
                )
                width = height = None
                for line in geom.stdout.splitlines():
                    if line.startswith("WIDTH="):
                        width = line.split("=", 1)[1]
                    elif line.startswith("HEIGHT="):
                        height = line.split("=", 1)[1]
                try:
                    area = int(width) * int(height)
                except (TypeError, ValueError):
                    area = 0
                if area > best_area:
                    best_area = area
                    best_id = window_id
            if best_id:
                return best_id
    return None


def _get_display_geometry(container: str, display: str) -> tuple[int, int] | None:
    result = subprocess.run(
        ["docker", "exec", "-e", f"DISPLAY={display}", container, "xdotool", "getdisplaygeometry"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        return None
    parts = result.stdout.strip().split()
    if len(parts) != 2:
        return None
    try:
        width, height = int(parts[0]), int(parts[1])
    except ValueError:
        return None
    return width, height


def focus_app(container: str, display: str, start_cmd: str, win_class: str, win_title: str) -> None:
    """Ensure the app is running and focused inside the container."""
    win = _find_window(container, display, win_class, win_title)

    if win is None and start_cmd:
        _status(f"[record] window not found — launching: {start_cmd}")
        _run_quiet(
            ["docker", "exec", "-d", "-e", f"DISPLAY={display}", container, "bash", "-lc", start_cmd]
        )
        time.sleep(1)
        win = _find_window(container, display, win_class, win_title)

    if win:
        geometry = _get_display_geometry(container, display)
        if geometry:
            width, height = geometry
            _run_quiet(
                ["docker", "exec", "-e", f"DISPLAY={display}", container,
                 "xdotool", "windowsize", win, str(width), str(height)]
            )
            _run_quiet(
                ["docker", "exec", "-e", f"DISPLAY={display}", container,
                 "xdotool", "windowmove", win, "0", "0"]
            )
        _run_quiet(
            ["docker", "exec", "-e", f"DISPLAY={display}", container, "xdotool", "windowraise", win]
        )
        _run_quiet(
            ["docker", "exec", "-e", f"DISPLAY={display}", container, "xdotool", "windowfocus", win]
        )
    else:
        _status("[record] warning: app window not found")


def _resolve_display(container: str, override: str | None) -> str:
    if override:
        return override
    result = subprocess.run(
        ["docker", "exec", container, "printenv", "DISPLAY"],
        capture_output=True,
        text=True,
    )
    display = result.stdout.strip()
    if result.returncode == 0 and display:
        return display
    return ":99"


def _resolve_save_dir(container: str, override: str | None) -> str | None:
    if override:
        return override
    result = subprocess.run(
        ["docker", "exec", container, "test", "-d", "/save_dir"],
        capture_output=True,
        text=True,
    )
    if result.returncode == 0:
        return "/save_dir"
    return None


def main() -> int:
    args = parse_args()
    args.display = _resolve_display(args.container, args.display)
    args.save_dir = _resolve_save_dir(args.container, args.save_dir)

    stop_key  = os.environ.get("STOP_KEYSYM",  "Pause")
    check_key = os.environ.get("CHECK_KEYSYM", "Scroll_Lock")
    if stop_key.upper() == check_key.upper():
        _status(f"CHECK_KEYSYM and STOP_KEYSYM must be different (got {check_key})")
        return 1

    _status(f"Recording to  : {args.output}")
    _status(f"Container     : {args.container}  display: {args.display}")
    _status(f"App class     : {args.windowclass}  title: {args.windowtitle}")
    if args.startcommand:
        _status(f"Start command : {args.startcommand}")
    if args.script:
        _status(f"Checkpoint script : {args.script}")
    _status(f"Stop key      : {stop_key}  (press in VNC session to finish)")
    _status(f"Check key     : {check_key}  (press to capture a reference screenshot)")
    _status("Open noVNC at http://localhost:6080/vnc.html, interact, then press the stop key.")

    focus_app(args.container, args.display, args.startcommand, args.windowclass, args.windowtitle)

    # Start xmacrorec2 inside the container; auto-arm it by injecting the stop key once.
    recorder_cmd = [
        "docker", "exec", "-e", f"DISPLAY={args.display}", args.container,
        "bash", "-lc",
        (
            f"export DISPLAY={shlex.quote(args.display)}; "
            f"(sleep 0.7; xdotool key --clearmodifiers {shlex.quote(stop_key)} >/dev/null 2>&1 || true) & "
            "stdbuf -oL xmacrorec2"
        ),
    ]

    # Pipe xmacrorec2 output through the local timed recorder.
    script_dir = Path(__file__).resolve().parent
    timed_cmd = [
        sys.executable, str(script_dir / "timed_xmacro.py"), "record",
        "--output",           str(args.output),
        "--screenshot-key",   check_key,
        "--stop-key",         stop_key,
        "--app-startcommand", args.startcommand,
        "--app-windowtitle",  args.windowtitle,
        "--app-windowclass",  args.windowclass,
        "--display",          args.display,
        "--container",        args.container,
        "--container-repo",   args.container_repo,
    ]
    for option, value in (("--app-startupwindowtitle", args.startupwindowtitle),
                          ("--app-startupwindowclass", args.startupwindowclass)):
        if value is not None:
            timed_cmd.extend([option, value])
    if args.script:
        timed_cmd.extend(["--script", str(args.script)])
    if args.save_dir:
        timed_cmd.extend(["--save-dir", args.save_dir])

    producer = subprocess.Popen(
        recorder_cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )
    assert producer.stdout is not None
    consumer = subprocess.Popen(timed_cmd, stdin=producer.stdout)
    producer.stdout.close()
    consumer_rc = consumer.wait()
    producer_rc = producer.wait()

    return consumer_rc or producer_rc


if __name__ == "__main__":
    raise SystemExit(main())
