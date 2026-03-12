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
    parser.add_argument("--display",   default=os.environ.get("DISPLAY", ":99"))
    parser.add_argument("--container", default="window-container", help="Docker container name")
    parser.add_argument("--container-repo", default="/tmp/repo",
                        help="Path where the project repo is mounted in the container")
    return parser.parse_args()


def _find_window(container: str, display: str, window_class: str, window_title: str) -> str | None:
    """Return the first visible xdotool window ID from inside the container."""
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
            return ids[0]
    return None


def focus_app(container: str, display: str, start_cmd: str, win_class: str, win_title: str) -> None:
    """Ensure the app is running and focused inside the container."""
    win = _find_window(container, display, win_class, win_title)

    if win is None and start_cmd:
        print(f"[record] window not found — launching: {start_cmd}")
        subprocess.run(
            ["docker", "exec", "-d", "-e", f"DISPLAY={display}", container, "bash", "-lc", start_cmd],
            check=False,
        )
        time.sleep(1)
        win = _find_window(container, display, win_class, win_title)

    if win:
        subprocess.run(
            ["docker", "exec", "-T", "-e", f"DISPLAY={display}", container, "xdotool", "windowraise", win],
            check=False,
        )
        subprocess.run(
            ["docker", "exec", "-T", "-e", f"DISPLAY={display}", container, "xdotool", "windowfocus", win],
            check=False,
        )
    else:
        print("[record] warning: app window not found")


def main() -> int:
    args = parse_args()

    stop_key  = os.environ.get("STOP_KEYSYM",  "Pause")
    check_key = os.environ.get("CHECK_KEYSYM", "F2")
    if stop_key.upper() == check_key.upper():
        print(f"CHECK_KEYSYM and STOP_KEYSYM must be different (got {check_key})")
        return 1

    print(f"Recording to  : {args.output}")
    print(f"Container     : {args.container}  display: {args.display}")
    print(f"App class     : {args.windowclass}  title: {args.windowtitle}")
    if args.startcommand:
        print(f"Start command : {args.startcommand}")
    print(f"Stop key      : {stop_key}  (press in VNC session to finish)")
    print(f"Check key     : {check_key}  (press to capture a reference screenshot)")
    print("Open noVNC at http://localhost:6080/vnc.html, interact, then press the stop key.")

    focus_app(args.container, args.display, args.startcommand, args.windowclass, args.windowtitle)

    # Start xmacrorec2 inside the container; auto-arm it by injecting the stop key once.
    recorder_cmd = [
        "docker", "exec", "-T", "-e", f"DISPLAY={args.display}", args.container,
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
        "--container",        args.container,
        "--container-repo",   args.container_repo,
    ]

    producer = subprocess.Popen(recorder_cmd, stdout=subprocess.PIPE)
    assert producer.stdout is not None
    consumer = subprocess.Popen(timed_cmd, stdin=producer.stdout)
    producer.stdout.close()
    consumer_rc = consumer.wait()
    producer_rc = producer.wait()

    return consumer_rc or producer_rc


if __name__ == "__main__":
    raise SystemExit(main())
