#!/usr/bin/env python3
"""Parrot recording and replay utilities.

Records xmacrorec2 input into the Parrot v2 .🦜 format and replays it.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import time
from pathlib import Path

from helpers import (
    APP_FIELDS,
    EVENT_VERBS,
    PARROT_HEADER,
    format_metadata_lines,
    load_app_metadata,
    normalize_app_meta,
)

# ---------------------------------------------------------------------------
# xmacrorec2 input parsing
# ---------------------------------------------------------------------------

# Map xmacrorec2 event names to Parrot v2 verbs.
XMACRO_TO_PARROT: dict[str, str] = {
    "motionnotify":  "mousemove",
    "buttonpress":   "mousedown",
    "buttonrelease": "mouseup",
    "keypress":      "keydown",
    "keyrelease":    "keyup",
    "keystrpress":   "keydown",
    "keystrrelease": "keyup",
}

# Informational lines xmacrorec2 sometimes writes to stdout.
_NOISE = [
    re.compile(r"^Press the key you want"),
    re.compile(r"^Only key-release events"),
    re.compile(r"^To end the recording"),
    re.compile(r"^All keysyms from except"),
    re.compile(r"^XRecord for server"),
    re.compile(r"^Server VendorRelease:"),
    re.compile(r"^xmacrorec"),
]

_KEY_RE = re.compile(r"^(Key(?:Str)?Press|Key(?:Str)?Release):?\s+(\S+)")


def _is_noise(line: str) -> bool:
    return not line.strip() or any(p.search(line) for p in _NOISE)


def _parse_key_event(line: str):
    """Return (kind, keysym, is_press, is_release) or None."""
    m = _KEY_RE.match(line.strip())
    if not m:
        return None
    kind = m.group(1)
    keysym = m.group(2)
    return kind, keysym, ("Press" in kind and "Release" not in kind), ("Release" in kind)


def _xmacro_to_parrot(line: str) -> str | None:
    """Convert one xmacrorec2 event line to Parrot v2 format, or None if unknown."""
    parts = line.split(None, 1)
    if not parts:
        return None
    verb = XMACRO_TO_PARROT.get(parts[0].rstrip(":").lower())
    if verb is None:
        return None
    args = parts[1].strip() if len(parts) > 1 else ""
    return f"{verb} {args}".strip()


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


def _derive_check_paths(output_path: Path, index: int) -> tuple[str, Path, str, str]:
    """Return (app_name, host_dir, png_name, ref) for a check screenshot."""
    app_name = output_path.stem
    host_dir = output_path.parent
    if host_dir.name != app_name:
        host_dir = host_dir / app_name

    png_name = f"{app_name}-check-{index:03d}.png"
    ref = f"{app_name}/{png_name}"
    return app_name, host_dir, png_name, ref


# ---------------------------------------------------------------------------
# Recording
# ---------------------------------------------------------------------------

def _capture_screenshot(
    output_path: Path,
    index: int,
    app_meta: dict[str, str],
    display: str,
    container: str,
) -> str:
    """
    Screenshot the app window inside *container* and save it alongside the recording.

    Returns the ref string written into the .🦜 file, e.g. 'firefox/firefox-check-001.png'.
    The image is captured inside the container and then copied back to the host
    next to the recording so replay can read it via the readonly repo bind-mount.
    """
    app_name, host_dir, png_name, ref = _derive_check_paths(output_path, index)
    container_dir = f"/tmp/parrot-checks/{app_name}"
    container_out = f"{container_dir.rstrip('/')}/{png_name}"
    host_out = host_dir / png_name
    host_dir.mkdir(parents=True, exist_ok=True)

    proc = subprocess.run(
        [
            "docker", "exec",
            "-e", f"DISPLAY={display}",
            "-e", f"SNAPSHOT_OUT={container_out}",
            "-e", f"APP_WINDOW_CLASS={app_meta.get('windowclass', '')}",
            "-e", f"APP_WINDOW_TITLE={app_meta.get('windowtitle', '')}",
            container, "bash", "-lc",
            (
                'export DISPLAY=${DISPLAY:-:99}; '
                'find_win(){ '
                '  local win=""; '
                '  [ -n "${APP_WINDOW_CLASS:-}" ] && '
                '    win="$(xdotool search --onlyvisible --class "$APP_WINDOW_CLASS" 2>/dev/null | head -n1)"; '
                '  [ -z "$win" ] && [ -n "${APP_WINDOW_TITLE:-}" ] && '
                '    win="$(xdotool search --onlyvisible --name "$APP_WINDOW_TITLE" 2>/dev/null | head -n1)"; '
                '  [ -n "$win" ] || return 1; printf "%s\n" "$win"; }; '
                'win="$(find_win)" || { echo "window not found" >&2; exit 1; }; '
                'mkdir -p "$(dirname "$SNAPSHOT_OUT")"; '
                'xdotool windowraise "$win" >/dev/null 2>&1 || true; '
                'xdotool windowfocus "$win" >/dev/null 2>&1 || true; '
                'sleep 0.1; '
                'import -window "$win" "$SNAPSHOT_OUT"'
            ),
        ],
        stdin=subprocess.DEVNULL, capture_output=True, text=True, check=False,
    )
    if proc.returncode != 0:
        detail = (proc.stderr or proc.stdout or f"exit={proc.returncode}").strip()
        raise RuntimeError(f"screenshot capture failed: {detail}")

    copy_proc = subprocess.run(
        ["docker", "cp", f"{container}:{container_out}", str(host_out)],
        stdin=subprocess.DEVNULL, capture_output=True, text=True, check=False,
    )
    if copy_proc.returncode != 0:
        detail = (copy_proc.stderr or copy_proc.stdout or f"exit={copy_proc.returncode}").strip()
        raise RuntimeError(f"screenshot copy failed: {detail}")

    subprocess.run(
        ["docker", "exec", container, "rm", "-f", container_out],
        stdin=subprocess.DEVNULL, capture_output=True, text=True, check=False,
    )
    return ref


def cmd_record(
    output_path: Path,
    screenshot_key: str | None,
    stop_key: str | None,
    app_meta_raw: dict[str, str] | None,
    display: str | None = None,
    save_dir: str | None = None,
    container: str = "window-container",
    container_repo: str = "/tmp/repo",
) -> int:
    """Read xmacrorec2 lines from stdin and write a Parrot v2 .🦜 recording."""
    output_path.parent.mkdir(parents=True, exist_ok=True)
    last_ts    = time.monotonic()
    event_count = check_count = 0
    screenshot_key_norm = screenshot_key.upper() if screenshot_key else None
    stop_key_norm       = stop_key.upper()       if stop_key       else None
    app_meta = normalize_app_meta(app_meta_raw)
    display = _resolve_display(container, display)
    with output_path.open("w", encoding="utf-8", newline="\n") as f:
        f.write(f"{PARROT_HEADER}\n\n")
        for line in format_metadata_lines(app_meta):
            f.write(f"{line}\n")
        f.write("\n")

        for raw in sys.stdin:
            line = raw.rstrip("\n")
            if _is_noise(line):
                continue

            now   = time.monotonic()
            delay = now - last_ts

            key_info = _parse_key_event(line)
            if key_info is not None:
                _, keysym, is_press, is_release = key_info
                keysym_norm = keysym.upper()

                if stop_key_norm and keysym_norm == stop_key_norm:
                    continue

                if screenshot_key_norm and keysym_norm == screenshot_key_norm:
                    if is_release:
                        check_count += 1
                        try:
                            ref = _capture_screenshot(
                                output_path, check_count, app_meta,
                                display,
                                container=container,
                            )
                        except Exception as exc:
                            print(str(exc), file=sys.stderr)
                            return 1
                        f.write(f"wait {delay:.6f}\n")
                        f.write(f"check {ref}\n")
                        f.flush()
                        last_ts = now
                        event_count += 1
                        print(f"Inserted check {ref}", file=sys.stderr)
                    continue  # consume both press and release for the hotkey

            parrot_line = _xmacro_to_parrot(line)
            if parrot_line is None:
                continue

            f.write(f"wait {delay:.6f}\n")
            f.write(f"{parrot_line}\n")
            last_ts = now
            event_count += 1

        f.flush()

    print(f"Saved {event_count} events to {output_path} (checks: {check_count})", file=sys.stderr)
    return 0


# ---------------------------------------------------------------------------
# Replay
# ---------------------------------------------------------------------------

def iter_replay_lines(input_path: Path, speed: float):
    """
    Yield event lines from a .🦜 recording, sleeping between them.

    'wait X.X' lines set the delay before the next event; they are not yielded.
    Comment, blank, and metadata lines are all skipped.
    """
    pending_wait = 0.0
    with input_path.open("r", encoding="utf-8") as f:
        for raw in f:
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split(None, 1)
            verb  = parts[0].lower()

            if verb == "wait":
                try:
                    pending_wait = float(parts[1]) if len(parts) > 1 else 0.0
                except ValueError:
                    pending_wait = 0.0
                continue

            if verb not in EVENT_VERBS:
                continue  # metadata line

            if pending_wait > 0:
                time.sleep(pending_wait / speed)
            pending_wait = 0.0
            yield line


def parse_xmacro_event(line: str) -> tuple | None:
    """
    Parse a Parrot v2 event line into an action tuple for dispatch.

    Examples:
        'mousemove 651 284'  →  ('mousemove', '651', '284')
        'keydown Alt_L'      →  ('keydown', 'Alt_L')
        'check foo/bar.png'  →  ('check', 'foo/bar.png')
    """
    parts = line.split()
    if not parts:
        return None
    verb = parts[0].lower()
    if verb == "mousemove"  and len(parts) >= 3: return ("mousemove", parts[1], parts[2])
    if verb == "mousedown"  and len(parts) >= 2: return ("mousedown", parts[1])
    if verb == "mouseup"    and len(parts) >= 2: return ("mouseup",   parts[1])
    if verb == "keydown"    and len(parts) >= 2: return ("keydown",   parts[1])
    if verb == "keyup"      and len(parts) >= 2: return ("keyup",     parts[1])
    if verb == "check"      and len(parts) >= 2: return ("check",     parts[1])
    return None


# ---------------------------------------------------------------------------
# CLI subcommands
# ---------------------------------------------------------------------------

def cmd_replay_xdotool(input_path: Path, speed: float) -> int:
    if speed <= 0:
        print("--speed must be > 0", file=sys.stderr)
        return 2
    skipped = emitted = 0
    for line in iter_replay_lines(input_path, speed):
        action = parse_xmacro_event(line)
        if action is None:
            skipped += 1
            continue
        try:
            sys.stdout.write("\t".join(action) + "\n")
            sys.stdout.flush()
        except BrokenPipeError:
            _suppress_broken_pipe()
            return 0
        emitted += 1
    if skipped:
        print(f"Skipped {skipped} unsupported events", file=sys.stderr)
    print(f"Emitted {emitted} replay actions", file=sys.stderr)
    return 0


def cmd_app_meta(input_path: Path, fmt: str) -> int:
    import shlex
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


def _suppress_broken_pipe() -> None:
    try:
        fd = sys.stdout.fileno()
        with open(os.devnull, "w") as devnull:
            os.dup2(devnull.fileno(), fd)
    except OSError:
        pass


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_rec = sub.add_parser("record", help="Read xmacrorec2 stdout and save a .🦜 recording")
    p_rec.add_argument("--output",           required=True, type=Path)
    p_rec.add_argument("--screenshot-key",   default=None)
    p_rec.add_argument("--stop-key",         default=None)
    p_rec.add_argument("--app-startcommand", default="")
    p_rec.add_argument("--app-windowtitle",  default="")
    p_rec.add_argument("--app-windowclass",  default="")
    p_rec.add_argument("--display",          default=None)
    p_rec.add_argument("--save-dir",         default=None)
    p_rec.add_argument("--container",        default="window-container")
    p_rec.add_argument("--container-repo",   default="/tmp/repo")

    p_rxd = sub.add_parser("replay-xdotool", help="Emit xdotool actions to stdout with timing")
    p_rxd.add_argument("--input", required=True, type=Path)
    p_rxd.add_argument("--speed", type=float, default=1.0)

    p_meta = sub.add_parser("app-meta", help="Read metadata from a .🦜 recording")
    p_meta.add_argument("--input",  required=True, type=Path)
    p_meta.add_argument("--format", choices=["shell", "tsv"], default="shell")

    return parser


def main() -> int:
    args = _build_parser().parse_args()

    if args.cmd == "record":
        return cmd_record(
            args.output,
            args.screenshot_key,
            args.stop_key,
            {"startcommand": args.app_startcommand,
             "windowtitle":  args.app_windowtitle,
             "windowclass":  args.app_windowclass},
            display=args.display,
            save_dir=args.save_dir,
            container=args.container,
            container_repo=args.container_repo,
        )
    if args.cmd == "replay-xdotool":
        return cmd_replay_xdotool(args.input, args.speed)
    if args.cmd == "app-meta":
        return cmd_app_meta(args.input, args.format)

    _build_parser().error("unknown command")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
