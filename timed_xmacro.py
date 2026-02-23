#!/usr/bin/env python3
"""Timed wrapper for xmacro recordings.

`xmacrorec2` records events but not timing. This helper stores per-event delays
in a comment directive and replays by sleeping between events while streaming
plain xmacro commands to stdout.
"""

from __future__ import annotations

import argparse
import os
import re
import shlex
import subprocess
import sys
import time
from pathlib import Path

from helpers import APP_FIELDS, format_app_directive_lines, load_app_metadata, normalize_app_meta

WAIT_PREFIX = "#WAIT_SEC "
HEADER = "# xtest timed xmacro v1"

# Common xmacrorec2 informational lines. They are usually stderr, but we filter
# them if they appear on stdout to avoid corrupting the macro file.
NOISE_PATTERNS = [
    re.compile(r"^Press the key you want"),
    re.compile(r"^Only key-release events"),
    re.compile(r"^To end the recording"),
    re.compile(r"^All keysyms from except"),
    re.compile(r"^XRecord for server"),
    re.compile(r"^Server VendorRelease:"),
    re.compile(r"^xmacrorec"),
]

KEY_EVENT_RE = re.compile(r"^(Key(?:Str)?Press|Key(?:Str)?Release):?\s+(\S+)")


def is_noise_line(line: str) -> bool:
    if not line.strip():
        return True
    return any(p.search(line) for p in NOISE_PATTERNS)


def parse_key_event(line: str):
    m = KEY_EVENT_RE.match(line.strip())
    if not m:
        return None
    kind = m.group(1)
    keysym = m.group(2)
    is_press = "Press" in kind and "Release" not in kind
    is_release = "Release" in kind
    return kind, keysym, is_press, is_release


def capture_reference_image(output_path: Path, index: int, app_meta: dict[str, str]) -> str:
    """Capture app window screenshot into /recordings and return filename."""
    png_name = f"{output_path.stem}-check-{index:03d}.png"
    try:
        rel_dir = output_path.parent.relative_to("recordings")
        if str(rel_dir) == ".":
            rel_png = Path(png_name)
        else:
            rel_png = rel_dir / png_name
    except ValueError:
        rel_png = Path(png_name)
    rel_png_str = rel_png.as_posix()
    container_out = f"/recordings/{rel_png_str}"
    app_window_class = app_meta.get("windowclass", "")
    app_window_title = app_meta.get("windowtitle", "")

    cmd = [
        "docker",
        "compose",
        "exec",
        "-T",
        "-e",
        f"SNAPSHOT_OUT={container_out}",
        "-e",
        f"APP_WINDOW_CLASS={app_window_class}",
        "-e",
        f"APP_WINDOW_TITLE={app_window_title}",
        "window-container",
        "bash",
        "-lc",
        (
            'export DISPLAY=${DISPLAY:-:99}; '
            'find_win(){ '
            '  local win=""; '
            '  if [ -n "${APP_WINDOW_CLASS:-}" ]; then '
            '    win="$(xdotool search --onlyvisible --class "$APP_WINDOW_CLASS" 2>/dev/null | head -n1)"; '
            '  fi; '
            '  if [ -z "$win" ] && [ -n "${APP_WINDOW_TITLE:-}" ]; then '
            '    win="$(xdotool search --onlyvisible --name "$APP_WINDOW_TITLE" 2>/dev/null | head -n1)"; '
            '  fi; '
            '  [ -n "$win" ] || return 1; '
            '  printf "%s\\n" "$win"; '
            '}; '
            'win="$(find_win)" || { '
            '  echo "app window not found (class=${APP_WINDOW_CLASS:-}, title=${APP_WINDOW_TITLE:-})" >&2; '
            '  exit 1; '
            '}; '
            'mkdir -p "$(dirname "$SNAPSHOT_OUT")"; '
            'xdotool windowraise "$win" >/dev/null 2>&1 || true; '
            'xdotool windowfocus "$win" >/dev/null 2>&1 || true; '
            'sleep 0.1; '
            'import -window "$win" "$SNAPSHOT_OUT"'
        ),
    ]
    proc = subprocess.run(
        cmd,
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        stderr = (proc.stderr or "").strip()
        stdout = (proc.stdout or "").strip()
        detail = stderr or stdout or f"exit={proc.returncode}"
        raise RuntimeError(f"screenshot capture failed: {detail}")
    return rel_png_str


def write_timed_line(f, delay: float, line: str):
    f.write(f"{WAIT_PREFIX}{delay:.6f}\n")
    f.write(f"{line}\n")


def cmd_record(
    output_path: Path,
    screenshot_key: str | None,
    stop_key: str | None,
    app_meta_raw: dict[str, str] | None,
) -> int:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    last_emitted_ts = time.monotonic()
    event_count = 0
    check_count = 0
    screenshot_key_norm = screenshot_key.upper() if screenshot_key else None
    stop_key_norm = stop_key.upper() if stop_key else None
    app_meta = normalize_app_meta(app_meta_raw)

    with output_path.open("w", encoding="utf-8", newline="\n") as f:
        f.write(f"{HEADER}\n")
        for line in format_app_directive_lines(app_meta):
            f.write(f"{line}\n")
        for raw in sys.stdin:
            line = raw.rstrip("\n")
            if is_noise_line(line):
                continue

            now = time.monotonic()
            delay = now - last_emitted_ts

            key_info = parse_key_event(line)
            if key_info is not None:
                _, keysym, is_press, is_release = key_info
                keysym_norm = keysym.upper()

                if stop_key_norm and keysym_norm == stop_key_norm:
                    # The recorder stop key is control for xmacrorec2, not part of the app macro.
                    continue

                if screenshot_key_norm and keysym_norm == screenshot_key_norm:
                    # Use release to trigger screenshot so the key press duration is included.
                    if is_release:
                        check_count += 1
                        try:
                            png_name = capture_reference_image(output_path, check_count, app_meta)
                        except Exception as exc:  # noqa: BLE001 - keep recording failure readable
                            print(str(exc), file=sys.stderr)
                            return 1
                        write_timed_line(f, delay, f"Check {png_name}")
                        f.flush()
                        last_emitted_ts = now
                        event_count += 1
                        print(f"Inserted Check {png_name}", file=sys.stderr)
                    # Consume both press and release for the screenshot hotkey.
                    continue

                if is_press or is_release:
                    # Fall through and record key events normally.
                    pass

            write_timed_line(f, delay, line)
            last_emitted_ts = now
            event_count += 1

        f.flush()

    print(f"Saved {event_count} events to {output_path} (checks inserted: {check_count})", file=sys.stderr)
    return 0


def iter_replay_lines(input_path: Path, speed: float):
    pending_wait = 0.0

    with input_path.open("r", encoding="utf-8") as f:
        for raw in f:
            line = raw.rstrip("\n")
            if not line:
                continue
            if line.startswith(WAIT_PREFIX):
                try:
                    pending_wait = float(line[len(WAIT_PREFIX) :])
                except ValueError:
                    pending_wait = 0.0
                continue
            if line.startswith("#"):
                continue

            if pending_wait > 0:
                sleep_for = pending_wait / speed
                if sleep_for > 0:
                    time.sleep(sleep_for)
            pending_wait = 0.0
            yield line


def cmd_replay(input_path: Path, speed: float) -> int:
    if speed <= 0:
        print("--speed must be > 0", file=sys.stderr)
        return 2

    for line in iter_replay_lines(input_path, speed):
        try:
            sys.stdout.write(line + "\n")
            sys.stdout.flush()
        except BrokenPipeError:
            _suppress_stdout_broken_pipe()
            return 0
    return 0


def parse_xmacro_event(line: str):
    if line.startswith("Check "):
        ref = line[len("Check ") :].strip()
        if ref:
            return ("check", ref)
        return None
    if line.startswith("CHECK "):
        ref = line[len("CHECK ") :].strip()
        if ref:
            return ("check", ref)
        return None

    parts = line.split()
    if not parts:
        return None

    event = parts[0].rstrip(":")
    args = parts[1:]

    if event == "MotionNotify" and len(args) >= 2:
        return ("mousemove", args[0], args[1])
    if event == "ButtonPress" and len(args) >= 1:
        return ("mousedown", args[0])
    if event == "ButtonRelease" and len(args) >= 1:
        return ("mouseup", args[0])

    # xmacro variants seen in the wild.
    if event in {"KeyPress", "KeyStrPress"} and len(args) >= 1:
        return ("keydown", args[0])
    if event in {"KeyRelease", "KeyStrRelease"} and len(args) >= 1:
        return ("keyup", args[0])

    # Unsupported/unknown event; caller can skip.
    return None


def _suppress_stdout_broken_pipe() -> None:
    """Avoid a second BrokenPipeError during interpreter shutdown."""
    try:
        stdout_fd = sys.stdout.fileno()
    except (AttributeError, OSError, ValueError):
        return
    try:
        with open(os.devnull, "w", encoding="utf-8") as devnull:
            os.dup2(devnull.fileno(), stdout_fd)
    except OSError:
        pass


def cmd_replay_xdotool(input_path: Path, speed: float) -> int:
    if speed <= 0:
        print("--speed must be > 0", file=sys.stderr)
        return 2

    skipped = 0
    emitted = 0
    for line in iter_replay_lines(input_path, speed):
        action = parse_xmacro_event(line)
        if action is None:
            skipped += 1
            continue
        try:
            sys.stdout.write("\t".join(action) + "\n")
            sys.stdout.flush()
        except BrokenPipeError:
            _suppress_stdout_broken_pipe()
            return 0
        emitted += 1

    if skipped:
        print(f"Skipped {skipped} unsupported events", file=sys.stderr)
    print(f"Emitted {emitted} replay actions", file=sys.stderr)
    return 0


def cmd_app_meta(input_path: Path, fmt: str) -> int:
    meta = load_app_metadata(input_path)

    if fmt == "shell":
        print(f"APP_STARTCOMMAND={shlex.quote(meta.get('startcommand', ''))}")
        print(f"APP_WINDOW_TITLE={shlex.quote(meta.get('windowtitle', ''))}")
        print(f"APP_WINDOW_CLASS={shlex.quote(meta.get('windowclass', ''))}")
        return 0

    if fmt == "tsv":
        for key in APP_FIELDS:
            print(f"{key}\t{meta.get(key, '')}")
        return 0

    print(f"unsupported format: {fmt}", file=sys.stderr)
    return 2


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_record = sub.add_parser("record", help="Read xmacrorec2 stdout and save timed macro")
    p_record.add_argument("--output", required=True, type=Path)
    p_record.add_argument("--screenshot-key", default=None, help="Keysym that inserts a Check screenshot (e.g. F6)")
    p_record.add_argument("--stop-key", default=None, help="Recorder stop keysym to filter from output (e.g. F8)")
    p_record.add_argument("--app-startcommand", default="", help="App start command to store in #APP metadata")
    p_record.add_argument("--app-windowtitle", default="", help="App window title matcher for #APP metadata")
    p_record.add_argument("--app-windowclass", default="", help="App window class matcher for #APP metadata")

    p_replay = sub.add_parser("replay", help="Emit macro lines to stdout with recorded timing")
    p_replay.add_argument("--input", required=True, type=Path)
    p_replay.add_argument("--speed", type=float, default=1.0, help="1.0=original speed, 2.0=2x faster")

    p_replay_xdotool = sub.add_parser(
        "replay-xdotool",
        help="Emit normalized xdotool actions to stdout with recorded timing",
    )
    p_replay_xdotool.add_argument("--input", required=True, type=Path)
    p_replay_xdotool.add_argument(
        "--speed", type=float, default=1.0, help="1.0=original speed, 2.0=2x faster"
    )

    p_app_meta = sub.add_parser("app-meta", help="Read effective #APP metadata from a macro file")
    p_app_meta.add_argument("--input", required=True, type=Path)
    p_app_meta.add_argument("--format", choices=["shell", "tsv"], default="shell")

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    if args.cmd == "record":
        return cmd_record(
            args.output,
            args.screenshot_key,
            args.stop_key,
            {
                "startcommand": args.app_startcommand,
                "windowtitle": args.app_windowtitle,
                "windowclass": args.app_windowclass,
            },
        )
    if args.cmd == "replay":
        return cmd_replay(args.input, args.speed)
    if args.cmd == "replay-xdotool":
        return cmd_replay_xdotool(args.input, args.speed)
    if args.cmd == "app-meta":
        return cmd_app_meta(args.input, args.format)

    parser.error("unknown command")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
