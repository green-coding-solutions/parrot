#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

from helpers import derive_run_name, load_app_metadata

SERVICE = "window-container"


def usage() -> int:
    print(f"Usage: {Path(sys.argv[0]).name} <docker-compose-file> [--display :99]")
    print(f"Example: {Path(sys.argv[0]).name} docker-compose-firefox.yml --display :99")
    print("Optional: set REPLAY_SPEED=2.0 for faster replay")
    return 1


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("compose_file")
    parser.add_argument("--display", default=":99")
    parser.add_argument("-h", "--help", action="store_true")
    args, extra = parser.parse_known_args()
    if args.help:
        raise SystemExit(usage())
    if extra:
        raise SystemExit(usage())
    return args


def parse_speed() -> float:
    raw = os.environ.get("REPLAY_SPEED", "1.0")
    try:
        speed = float(raw)
    except ValueError:
        print(f"Invalid REPLAY_SPEED: {raw}")
        raise SystemExit(2)
    if speed <= 0:
        print("REPLAY_SPEED must be > 0")
        raise SystemExit(2)
    return speed


def run(cmd: list[str], *, env: dict[str, str], check: bool = True) -> int:
    proc = subprocess.run(cmd, env=env, check=False)
    if check and proc.returncode != 0:
        raise SystemExit(proc.returncode)
    return proc.returncode


def main() -> int:
    try:
        args = parse_args()
    except SystemExit as exc:
        code = exc.code
        return int(code) if isinstance(code, int) else 1

    compose_file = Path(args.compose_file)
    if not compose_file.is_file():
        print(f"Compose file not found: {compose_file}")
        return 1
    if not args.display:
        print("Display must be non-empty")
        return 1

    speed = parse_speed()
    display = args.display
    run_name = derive_run_name(compose_file)
    if not re.fullmatch(r"[A-Za-z0-9._-]+", run_name):
        print(f"Derived run name is invalid: {run_name}")
        return 1

    macro_file = Path("recordings") / run_name / f"{run_name}.xmacro"
    if not macro_file.is_file():
        print(f"Recording not found: {macro_file}")
        return 1

    app_meta = load_app_metadata(macro_file)
    app_startcommand = app_meta.get("startcommand", "")
    app_window_title = app_meta.get("windowtitle", "")
    app_window_class = app_meta.get("windowclass", "")

    env = os.environ.copy()
    env["COMPOSE_FILE"] = str(compose_file)
    compose_cmd = ["docker", "compose", "-f", str(compose_file)]

    print(f"Replaying {macro_file} on container display {display} at speed={speed}")
    print(f"Compose file: {compose_file}")
    print("Using #APP metadata from recording")
    print(f"App window match: class='{app_window_class}' title='{app_window_title}'")
    if app_startcommand:
        print(f"App start command (used if window not found): {app_startcommand}")

    focus_script = r'''set -euo pipefail
export DISPLAY=${DISPLAY:-:99}
find_app_window() {
  local win=""
  if [[ -n "${APP_WINDOW_CLASS:-}" ]]; then
    win="$(xdotool search --onlyvisible --class "$APP_WINDOW_CLASS" 2>/dev/null | head -n1 || true)"
  fi
  if [[ -z "$win" && -n "${APP_WINDOW_TITLE:-}" ]]; then
    win="$(xdotool search --onlyvisible --name "$APP_WINDOW_TITLE" 2>/dev/null | head -n1 || true)"
  fi
  [[ -n "$win" ]] || return 1
  printf '%s\n' "$win"
}

win="$(find_app_window || true)"
if [[ -z "$win" && -n "${APP_STARTCOMMAND:-}" ]]; then
  eval "${APP_STARTCOMMAND}" >/tmp/xtest-app-launch.log 2>&1 &
  sleep 1
  win="$(find_app_window || true)"
fi

/usr/local/bin/position-window.sh >/dev/null 2>&1 || true
win="$(find_app_window || true)"
if [[ -n "$win" ]]; then
  xdotool windowraise "$win" >/dev/null 2>&1 || true
  xdotool windowfocus "$win" >/dev/null 2>&1 || true
  sleep 0.1
fi
'''

    run(
        compose_cmd
        + [
            "exec",
            "-T",
            "-e",
            f"APP_STARTCOMMAND={app_startcommand}",
            "-e",
            f"APP_WINDOW_CLASS={app_window_class}",
            "-e",
            f"APP_WINDOW_TITLE={app_window_title}",
            "-e",
            f"DISPLAY={display}",
            SERVICE,
            "bash",
            "-lc",
            focus_script,
        ],
        env=env,
    )

    timed_cmd = [
        sys.executable,
        "timed_xmacro.py",
        "replay-xdotool",
        "--input",
        str(macro_file),
        "--speed",
        str(speed),
    ]

    replay_consumer_cmd = compose_cmd + [
        "exec",
        "-T",
        "-e",
        f"CHECK_MAX_RMSE={os.environ.get('CHECK_MAX_RMSE', '')}",
        "-e",
        f"CHECK_IGNORE_RECT={os.environ.get('CHECK_IGNORE_RECT', '')}",
        "-e",
        f"APP_WINDOW_CLASS={app_window_class}",
        "-e",
        f"APP_WINDOW_TITLE={app_window_title}",
        "-e",
        f"DISPLAY={display}",
        SERVICE,
        "bash",
        "-lc",
        r'''set -euo pipefail
export DISPLAY=${DISPLAY:-:99}
while IFS= read -r line; do
  [ -n "$line" ] || continue
  IFS=$'\t' read -r op a1 a2 <<< "$line"
  case "$op" in
    mousemove)
      xdotool mousemove "$a1" "$a2" >/dev/null 2>&1 || true
      ;;
    mousedown)
      xdotool mousedown "$a1" >/dev/null 2>&1 || true
      ;;
    mouseup)
      xdotool mouseup "$a1" >/dev/null 2>&1 || true
      ;;
    keydown)
      xdotool keydown "$a1" >/dev/null 2>&1 || true
      ;;
    keyup)
      xdotool keyup "$a1" >/dev/null 2>&1 || true
      ;;
    check)
      /usr/local/bin/check-image.sh "$a1"
      ;;
  esac
done
''',
    ]

    producer = subprocess.Popen(timed_cmd, stdout=subprocess.PIPE, env=env)
    assert producer.stdout is not None
    consumer = subprocess.Popen(replay_consumer_cmd, stdin=producer.stdout, env=env)
    producer.stdout.close()
    consumer_rc = consumer.wait()
    producer_rc = producer.wait()

    return consumer_rc or producer_rc


if __name__ == "__main__":
    raise SystemExit(main())
