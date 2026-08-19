#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

from helpers import STARTUP_FIELDS, load_app_metadata, note_label
from timed_xmacro import iter_replay_lines, parse_xmacro_event

CHECK_IMAGE_SCRIPT   = "/usr/local/bin/check-image.sh"
POSITION_WINDOW_SCRIPT = "/usr/local/bin/position-window.sh"
APP_LAUNCH_LOG       = "/tmp/xtest-app-launch.log"


# ---------------------------------------------------------------------------
# CLI / configuration
# ---------------------------------------------------------------------------

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Replay a .🦜 xmacro recording inside the current container"
    )
    parser.add_argument(
        "macro_file",
        help="Path to a .🦜 recording file, or a directory of numbered block "
             "recordings when --run-to is given",
    )
    parser.add_argument(
        "--display",
        default=os.environ.get("DISPLAY", ":99"),
        help="X display to use (default: $DISPLAY or :99)",
    )
    parser.add_argument(
        "--run-to",
        type=int,
        default=None,
        help="Treat macro_file as a directory and replay every numbered block "
             "file up to and including this number, ordered by the leading "
             "number in the filename",
    )
    parser.add_argument(
        "--no-checks",
        action="store_true",
        default=_env_flag("REPLAY_IGNORE_CHECKS"),
        help="Skip Check (screenshot comparison) steps instead of asserting on "
             "them. Equivalent to setting REPLAY_IGNORE_CHECKS=1.",
    )
    return parser.parse_args()


def _env_flag(name: str) -> bool:
    """Return True if environment variable *name* is set to a truthy value."""
    return os.environ.get(name, "").strip().lower() in ("1", "true", "yes")


def _window_timeout() -> float:
    """
    Seconds to wait for the app window to map after launching it.

    90 s is roughly four times what the slowest client in the chat group takes
    to paint on the machine its macro was recorded on, and it is a ceiling
    rather than a delay: the poll returns the moment the window appears, so on a
    machine that starts the app as fast as the recording machine this costs
    nothing. Raise REPLAY_WINDOW_TIMEOUT for a slower measurement node.
    """
    raw = os.environ.get("REPLAY_WINDOW_TIMEOUT", "90")
    try:
        timeout = float(raw)
    except ValueError:
        raise SystemExit(f"Invalid REPLAY_WINDOW_TIMEOUT: {raw}")
    if timeout < 0:
        raise SystemExit("REPLAY_WINDOW_TIMEOUT must be >= 0")
    return timeout


def _tail(path: str, lines: int = 40) -> str:
    """Return the last *lines* lines of a file, indented, for error output."""
    try:
        content = Path(path).read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError as exc:
        return f"    (unreadable: {exc})"
    if not content:
        return "    (empty - the start command wrote nothing)"
    return "\n".join(f"    {line}" for line in content[-lines:])


def collect_block_files(directory: Path, run_to: int) -> list[Path]:
    """Return numbered block recordings in *directory* with leading number <= run_to."""
    blocks: list[tuple[int, Path]] = []
    for child in directory.iterdir():
        if not child.is_file():
            continue
        m = re.match(r"^(\d+)", child.name)
        if not m:
            continue
        num = int(m.group(1))
        if num <= run_to:
            blocks.append((num, child))
    blocks.sort(key=lambda item: item[0])
    return [path for _, path in blocks]


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


def infer_window_size(macro_file: Path, app_dir: Path | None = None) -> tuple[int, int] | None:
    """
    Scan the recording for the first Check line and return that image's size.
    Check refs are relative to the application directory, e.g.:
        Check firefox/firefox-check-001.png
    so we try app_dir (when given) plus macro_file.parent.parent and macro_file.parent.
    """
    try:
        lines = macro_file.read_text(encoding="utf-8").splitlines()
    except OSError:
        return None

    roots: list[Path] = []
    if app_dir is not None:
        roots.append(app_dir.parent)
        roots.append(app_dir)
    roots.append(macro_file.parent.parent)
    roots.append(macro_file.parent)

    for raw in lines:
        line = raw.strip()
        if not line.lower().startswith("check "):
            continue
        ref = line[len("check "):].strip()

        ref_path = Path(ref)
        for root in roots:
            size = _png_dimensions(root / ref_path)
            if size:
                return size
    return None


# ---------------------------------------------------------------------------
# App window management
# ---------------------------------------------------------------------------

def _window_area(display: str, window_id: str) -> int:
    """Return the visible area for a window ID, or 0 if it cannot be read."""
    env = {**os.environ, "DISPLAY": display}
    result = subprocess.run(
        ["xdotool", "getwindowgeometry", "--shell", window_id],
        env=env, capture_output=True, text=True,
    )
    if result.returncode != 0:
        return 0

    width = height = None
    for line in result.stdout.splitlines():
        if line.startswith("WIDTH="):
            width = line.split("=", 1)[1]
        elif line.startswith("HEIGHT="):
            height = line.split("=", 1)[1]

    try:
        return int(width) * int(height)
    except (TypeError, ValueError):
        return 0


def _find_window(display: str, window_class: str, window_title: str) -> str | None:
    """Return the largest visible xdotool window ID matching class or title."""
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
            return max(ids, key=lambda window_id: _window_area(display, window_id))
    return None


def _describe_visible_windows(display: str) -> str:
    """
    Return a one-line-per-window inventory of the display, for error output.

    WM_CLASS is the point of this, not a nicety: a window that maps under a class
    the recording does not name fails in exactly the same way as no window at all
    - check-image.sh exits 2 either way - and only the class tells the two apart.

    It is read with python-xlib rather than xdotool because the xdotool in this
    image (3.20160805) has no `getwindowclassname`, and `xprop` is not installed
    either; asking xdotool for it yields an empty column, which is the one thing
    this function must not do. python3-xlib is in the image; if it is ever not,
    fall back to names alone and say so rather than raising inside a failure path.
    """
    try:
        from Xlib import display as xdisplay   # noqa: PLC0415 - failure path only
    except ImportError:
        return _describe_visible_windows_by_name(display)

    try:
        conn = xdisplay.Display(display)
    except Exception as exc:                   # noqa: BLE001 - any failure is non-fatal here
        return f"    (could not open {display}: {exc})"

    lines: list[str] = []

    def walk(window, depth: int) -> None:
        # fluxbox reparents clients into frames, so the interesting windows are
        # not the root's direct children. Three levels covers frame -> client.
        if depth > 3:
            return
        try:
            klass = window.get_wm_class()
            name  = window.get_wm_name()
            geom  = window.get_geometry()
            children = window.query_tree().children
        except Exception:                      # noqa: BLE001 - window may vanish mid-walk
            return
        if klass or name:
            res_class = klass[1] if klass else ""
            lines.append(
                f"    {window.id}  class={res_class!r}  name={name or ''!r}  "
                f"{geom.width}x{geom.height}+{geom.x}+{geom.y}"
            )
        for child in children:
            walk(child, depth + 1)

    try:
        walk(conn.screen().root, 0)
    finally:
        conn.close()

    return "\n".join(lines) if lines else "    (no windows with a class or a name)"


def _describe_visible_windows_by_name(display: str) -> str:
    """Names-only inventory, used when python-xlib is unavailable. See above."""
    env = {**os.environ, "DISPLAY": display}
    try:
        search = subprocess.run(
            ["xdotool", "search", "--onlyvisible", "--name", "."],
            env=env, capture_output=True, text=True,
        )
    except OSError as exc:
        # This runs only when the run has already failed. It must not replace the
        # failure being reported with one of its own.
        return f"    (could not list windows: {exc})"
    lines = []
    for window_id in search.stdout.split():
        name = subprocess.run(
            ["xdotool", "getwindowname", window_id],
            env=env, capture_output=True, text=True,
        ).stdout.strip()
        lines.append(f"    {window_id}  name={name!r}  (no class - python-xlib unavailable)")
    return "\n".join(lines) if lines else "    (no visible windows)"


def report_missing_window(display: str, app_meta: dict[str, str], preamble: str = "") -> None:
    """
    Print everything that says WHY no window matched, to stderr.

    Both places this is called from - the launch in focus_app and a Check that
    exits 2 - report the same failure, and both happen inside a container that
    the runner tears down before anyone can look at it. The launch log and the
    window list only exist there, so the diagnosis has to travel out on stderr
    or it does not travel at all.
    """
    if preamble:
        print(preamble, file=sys.stderr)
    print(
        f"[replay] no window matching class={app_meta.get('windowclass', '')!r} "
        f"title={app_meta.get('windowtitle', '')!r}\n"
        f"[replay] visible windows on {display}:\n"
        f"{_describe_visible_windows(display)}\n"
        f"[replay] tail of {APP_LAUNCH_LOG}:\n"
        f"{_tail(APP_LAUNCH_LOG)}",
        file=sys.stderr,
    )


def wait_for_window(display: str, win_class: str, win_title: str, timeout: float) -> str | None:
    """
    Poll for the app window until it maps or *timeout* seconds elapse.

    This is NOT mainly about buying the app more time. Before it existed the app
    already got a generous budget before the first Check: a 1 s sleep, then
    position-window.sh's own 30 s wait loop, then the recording's leading wait -
    around 50 s for every client in the chat group, itself padding rather than a
    measured startup. An app that has not mapped a window in ~85 s is not slow,
    it has failed to start.

    What this buys is WHERE and HOW the run fails. Without it a failed launch
    surfaces a minute later as check-image.sh exiting 2 with "app window not
    found" - a screenshot-shaped error for something that is not a screenshot
    problem - and the launch output that says why dies with the container.
    Raise REPLAY_WINDOW_TIMEOUT on a measurement node slow enough to need it.
    """
    deadline = time.monotonic() + timeout
    while True:
        win = _find_window(display, win_class, win_title)
        if win:
            return win
        if time.monotonic() >= deadline:
            return None
        time.sleep(0.25)


def _startup_matcher(app_meta: dict[str, str]) -> tuple[str, str]:
    """Return the (class, title) to wait on after launching the app.

    The recording's own matcher unless it carries a startup matcher, in which
    case that one is used WHOLE - both halves, including an empty one. Falling
    back per field would quietly re-introduce the title the startup matcher
    exists to avoid waiting for.
    """
    if not any(key in app_meta for key in STARTUP_FIELDS):
        return app_meta.get("windowclass", ""), app_meta.get("windowtitle", "")
    return app_meta.get("startupwindowclass", ""), app_meta.get("startupwindowtitle", "")


def focus_app(app_meta: dict[str, str], display: str, window_size: tuple[int, int] | None) -> None:
    """
    Ensure the app is running, positioned, and in the foreground.

    1. Try to find an existing window by class / title.
    2. If not found, launch the app via startcommand and wait for it to map.
    3. Run position-window.sh to size and place it.
    4. Raise and focus the window.

    A recording carrying a startup matcher (see STARTUP_FIELDS in helpers.py)
    waits on THAT window in step 2, and skips step 3 when the window the macro
    drives does not exist yet - there is nothing to position, and a recording
    that needs a startup matcher gets its geometry from pin-windows.sh before
    the window manager starts, not from position-window.sh afterwards.
    """
    env = {**os.environ, "DISPLAY": display}
    win_class  = app_meta.get("windowclass", "")
    win_title  = app_meta.get("windowtitle", "")
    start_cmd  = app_meta.get("startcommand", "")
    startup_class, startup_title = _startup_matcher(app_meta)

    win = _find_window(display, win_class, win_title)

    if win is None and start_cmd:
        print(f"[replay] window not found — launching: {start_cmd}", file=sys.stderr)
        with open(APP_LAUNCH_LOG, "w") as log:
            subprocess.Popen(["bash", "-lc", start_cmd], env=env, stdout=log, stderr=log)

        timeout = _window_timeout()
        started = time.monotonic()
        win = wait_for_window(display, startup_class, startup_title, timeout)
        waited = time.monotonic() - started

        if win is None:
            # Every later action - the position, the clicks, the Checks - targets
            # a window that is not there, so the run is already lost. Fail here,
            # with the launch output, instead of 50 s later inside check-image.sh
            # where the only symptom is "app window not found".
            report_missing_window(
                display, app_meta,
                preamble=f"[replay] FATAL: the app did not map a window in {timeout:.0f}s",
            )
            raise SystemExit(1)

        # Worth printing on every run: it is the recorded leading wait's margin.
        # Anything close to the timeout means this machine is slower at starting
        # the app than the one the macro was recorded on, and the macro's own
        # leading wait no longer covers the startup - see wait_for_window.
        print(f"[replay] window mapped after {waited:.1f}s", file=sys.stderr)

    if _find_window(display, win_class, win_title) is None:
        # Only the startup window is up - the macro's own window comes later, out
        # of the dialogs the recording clicks through. Positioning now would
        # spend position-window.sh's 30 s wait looking for a window that cannot
        # appear until the replay has started, and delay the first event by that
        # much.
        print(
            f"[replay] app is up but class={win_class!r} title={win_title!r} has not mapped yet; "
            f"skipping position-window (geometry comes from the window manager)",
            file=sys.stderr,
        )
        return

    pos_env = {
        **env,
        "APP_WINDOW_CLASS": win_class,
        "APP_WINDOW_TITLE": win_title,
    }
    if window_size is not None:
        # Reference screenshots are captured from the window itself, so placing
        # the replay window at the origin avoids needless WM clipping when the
        # window size matches the full virtual display.
        pos_env.setdefault("WINDOW_X", "0")
        pos_env.setdefault("WINDOW_Y", "0")
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


def dispatch(action: tuple, display: str, app_meta: dict[str, str], app_dir: Path,
             ignore_checks: bool = False) -> None:
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
        if ignore_checks:
            print(f"[replay] skipping check: {action[1]}", file=sys.stderr)
            return
        ref = resolve_check_ref(action[1], app_dir)
        check_env = {
            **env,
            "APP_WINDOW_CLASS":  app_meta.get("windowclass", ""),
            "APP_WINDOW_TITLE":  app_meta.get("windowtitle", ""),
            "CHECK_MAX_RMSE":    os.environ.get("CHECK_MAX_RMSE",    ""),
            "CHECK_IGNORE_RECT": os.environ.get("CHECK_IGNORE_RECT", ""),
        }
        try:
            subprocess.run([CHECK_IMAGE_SCRIPT, ref], env=check_env, check=True)
        except subprocess.CalledProcessError as exc:
            # Exit 2 from check-image.sh means "no window matched", which is not a
            # screenshot problem: the app never mapped a window, or mapped one under
            # a class/title the recording does not name. The reason is in the launch
            # log and in the window list, neither of which survives the container - so
            # print both here, where they reach the runner's stderr.
            if exc.returncode == 2:
                report_missing_window(display, app_meta)
            raise
    elif op == "log":
        # Only the label - the text before the first colon - becomes the note.
        # The rest of the line is the instruction for whoever recorded the macro
        # and stays in the .🦜 file without being emitted.
        sys.stdout.write(f"{time.time_ns() // 1000} {note_label(action[1])}\n")
        sys.stdout.flush()


# ---------------------------------------------------------------------------
# Screen recording
# ---------------------------------------------------------------------------

def _display_size(display: str) -> tuple[int, int]:
    """Return (width, height) of the X display, falling back to 1024x768."""
    env = {**os.environ, "DISPLAY": display}
    result = subprocess.run(
        ["xdpyinfo"], env=env, capture_output=True, text=True,
    )
    for line in result.stdout.splitlines():
        m = re.search(r"dimensions:\s+(\d+)x(\d+)", line)
        if m:
            return int(m.group(1)), int(m.group(2))
    return (1024, 768)


def start_recording(display: str, output_path: str) -> subprocess.Popen:
    """Start an ffmpeg x11grab recording; return the process handle."""
    w, h = _display_size(display)
    cmd = [
        "ffmpeg", "-y",
        "-f", "x11grab",
        "-r", "25",
        "-s", f"{w}x{h}",
        "-i", display,
        "-c:v", "libx264",
        "-preset", "ultrafast",
        "-crf", "23",
        output_path,
    ]
    print(f"[replay] recording screen to {output_path} ({w}x{h})", file=sys.stderr)
    return subprocess.Popen(
        cmd,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def stop_recording(proc: subprocess.Popen) -> None:
    """Send SIGINT to ffmpeg so it flushes and writes a valid file."""
    if proc.poll() is None:
        proc.send_signal(__import__("signal").SIGINT)
        try:
            proc.wait(timeout=15)
        except subprocess.TimeoutExpired:
            proc.kill()


def resolve_video_output() -> str | None:
    """
    Return the output path for screen recording, or None if disabled.

    Set RECORD_VIDEO to a file path, or to '1' / 'true' to use a default
    path under /tmp.
    """
    val = os.environ.get("RECORD_VIDEO", "")
    if not val:
        return None
    if val.lower() in ("1", "true", "yes"):
        ts = int(time.time())
        return f"/tmp/parrot-replay-{ts}.mp4"
    return val


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> int:
    args = parse_args()

    target = Path(args.macro_file).resolve()
    display = args.display
    if not display:
        print("--display must not be empty", file=sys.stderr)
        return 1

    speed = parse_speed()

    if args.run_to is not None:
        if not target.is_dir():
            print(f"--run-to requires a directory: {target}", file=sys.stderr)
            return 1
        macro_files = collect_block_files(target, args.run_to)
        if not macro_files:
            print(
                f"No numbered block files found in {target} (run-to {args.run_to})",
                file=sys.stderr,
            )
            return 1
        # The first block carries the app metadata; later blocks reuse it.
        app_meta = load_app_metadata(macro_files[0])
        # Treat the parent of the blocks directory as the app dir so that
        # check refs like 'atril/atril-check-005.png' resolve the same way
        # they do for a top-level recording in the app dir.
        app_dir = target.parent
        window_size = None
        for block in macro_files:
            window_size = infer_window_size(block, app_dir)
            if window_size:
                break
    else:
        if not target.is_file():
            print(f"Macro file not found: {target}", file=sys.stderr)
            return 1
        macro_files = [target]
        app_meta = load_app_metadata(target)
        app_dir = target.parent   # e.g. applications/firefox/
        window_size = infer_window_size(target)

    if len(macro_files) == 1:
        print(f"Replaying : {macro_files[0]}", file=sys.stderr)
    else:
        print(f"Replaying : {len(macro_files)} blocks from {target}", file=sys.stderr)
        for block in macro_files:
            print(f"            {block.name}", file=sys.stderr)
    print(f"Display   : {display}  speed={speed}", file=sys.stderr)
    if args.no_checks:
        print("Checks    : ignored (--no-checks)", file=sys.stderr)
    print(
        f"App class : {app_meta.get('windowclass', '')}  title: {app_meta.get('windowtitle', '')}",
        file=sys.stderr,
    )
    if app_meta.get("startcommand"):
        print(f"Start cmd : {app_meta['startcommand']}", file=sys.stderr)
    if window_size:
        print(f"Win size  : {window_size[0]}x{window_size[1]} (from check image)", file=sys.stderr)

    # 1. Ensure the app is running and focused.
    focus_app(app_meta, display, window_size)

    # 2. Make lock-key state deterministic before replaying key events.
    normalize_lock_key(display, "Caps Lock",   "Caps_Lock",   os.environ.get("REPLAY_INIT_CAPSLOCK",   "off"))
    normalize_lock_key(display, "Num Lock",    "Num_Lock",    os.environ.get("REPLAY_INIT_NUMLOCK",    "off"))
    normalize_lock_key(display, "Scroll Lock", "Scroll_Lock", os.environ.get("REPLAY_INIT_SCROLLLOCK", "keep"))

    # 3. Optionally record the screen to a video file.
    video_output = resolve_video_output()
    recorder = start_recording(display, video_output) if video_output else None

    # 4. Parse each recording and replay its events in-process.
    #    iter_replay_lines() sleeps between events to honour the recorded timing.
    try:
        for macro_file in macro_files:
            for line in iter_replay_lines(macro_file, speed):
                action = parse_xmacro_event(line)
                if action is not None:
                    dispatch(action, display, app_meta, app_dir, args.no_checks)
    finally:
        if recorder:
            stop_recording(recorder)
            print(f"[replay] video saved to {video_output}", file=sys.stderr)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
