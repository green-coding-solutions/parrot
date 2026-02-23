#!/usr/bin/env python3
from __future__ import annotations

import os
import re
import shlex
import subprocess
import sys
from pathlib import Path

from helpers import derive_run_name

SERVICE = "window-container"


def usage() -> int:
    print(f"Usage: {Path(sys.argv[0]).name} <docker-compose-file>")
    print(f"Example: {Path(sys.argv[0]).name} docker-compose-firefox.yml")
    return 1


def load_compose_env_value(compose_file: Path, key: str) -> str:
    pattern_map = re.compile(rf"^\s*{re.escape(key)}\s*:\s*(.*)$")
    pattern_list = re.compile(rf"^\s*-\s*{re.escape(key)}=(.*)$")
    for raw in compose_file.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        m = pattern_map.match(raw)
        if not m:
            m = pattern_list.match(raw)
        if not m:
            continue
        value = m.group(1).strip()
        if "#" in value:
            value = value.split("#", 1)[0].rstrip()
        if (value.startswith('"') and value.endswith('"')) or (value.startswith("'") and value.endswith("'")):
            value = value[1:-1]
        return value
    return ""


def run(cmd: list[str], *, env: dict[str, str], check: bool = True) -> int:
    proc = subprocess.run(cmd, env=env, check=False)
    if check and proc.returncode != 0:
        raise SystemExit(proc.returncode)
    return proc.returncode


def main() -> int:
    if len(sys.argv) != 2:
        return usage()

    compose_file = Path(sys.argv[1])
    if not compose_file.is_file():
        print(f"Compose file not found: {compose_file}")
        return 1

    run_name = derive_run_name(compose_file)
    if not re.fullmatch(r"[A-Za-z0-9._-]+", run_name):
        print(f"Derived run name is invalid: {run_name}")
        return 1

    recordings_dir = Path("recordings") / run_name
    recordings_dir.mkdir(parents=True, exist_ok=True)
    outfile = recordings_dir / f"{run_name}.xmacro"

    stop_key = os.environ.get("STOP_KEYSYM", "Pause")
    check_key = os.environ.get("CHECK_KEYSYM", "F2")
    if stop_key.upper() == check_key.upper():
        print(f"CHECK_KEYSYM and STOP_KEYSYM must be different (got {check_key})")
        return 1

    compose_app_start = load_compose_env_value(compose_file, "APP_STARTCOMMAND")
    compose_app_title = load_compose_env_value(compose_file, "APP_WINDOW_TITLE")
    compose_app_class = load_compose_env_value(compose_file, "APP_WINDOW_CLASS")

    app_startcommand = os.environ.get("APP_STARTCOMMAND", compose_app_start)
    app_window_title = os.environ.get("APP_WINDOW_TITLE", compose_app_title)
    app_window_class = os.environ.get("APP_WINDOW_CLASS", compose_app_class)

    env = os.environ.copy()
    env["COMPOSE_FILE"] = str(compose_file)
    compose_cmd = ["docker", "compose", "-f", str(compose_file)]

    print(f"Recording to {outfile} (timed)")
    print(f"Compose file: {compose_file}")
    print(f"Run name: {run_name}")
    print(f"Auto-arming xmacro recorder with stop key: {stop_key}")
    print(f"Screenshot/check hotkey during recording: {check_key}")
    print(f"App window match: class='{app_window_class}' title='{app_window_title}'")
    if app_startcommand:
        print(f"App start command (used if window not found): {app_startcommand}")
    print("Open noVNC (http://localhost:6080/vnc.html), interact with the app, then press " f"{stop_key} in the VNC session to finish.")
    print(
        f"If your browser/noVNC intercepts {stop_key}, rerun with STOP_KEYSYM=<other-key> (example: STOP_KEYSYM=F9)."
    )
    print(f"Press {check_key} during recording to capture a reference image and insert a Check line.")

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

if [[ -n "$win" ]]; then
  xdotool windowraise "$win" >/dev/null 2>&1 || true
  xdotool windowfocus "$win" >/dev/null 2>&1 || true
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
            SERVICE,
            "bash",
            "-lc",
            focus_script,
        ],
        env=env,
    )

    recorder_cmd = compose_cmd + [
        "exec",
        "-T",
        SERVICE,
        "bash",
        "-lc",
        (
            "export DISPLAY=${DISPLAY:-:99}; "
            f"(sleep 0.7; xdotool key --clearmodifiers {shlex.quote(stop_key)} >/dev/null 2>&1 || true) & "
            "stdbuf -oL xmacrorec2"
        ),
    ]

    timed_cmd = [
        sys.executable,
        "timed_xmacro.py",
        "record",
        "--output",
        str(outfile),
        "--screenshot-key",
        check_key,
        "--stop-key",
        stop_key,
        "--app-startcommand",
        app_startcommand,
        "--app-windowtitle",
        app_window_title,
        "--app-windowclass",
        app_window_class,
    ]

    producer = subprocess.Popen(recorder_cmd, stdout=subprocess.PIPE, env=env)
    assert producer.stdout is not None
    consumer = subprocess.Popen(timed_cmd, stdin=producer.stdout, env=env)
    producer.stdout.close()
    consumer_rc = consumer.wait()
    producer_rc = producer.wait()

    return consumer_rc or producer_rc


if __name__ == "__main__":
    raise SystemExit(main())
