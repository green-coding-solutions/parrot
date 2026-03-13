# Parrot — Record and Replay X Application Interactions

Parrot lets you record mouse clicks, keyboard input, and navigation paths through any X11 GUI application, then replay those interactions automatically. It is designed for benchmarking and testing desktop applications in a reproducible, sandboxed environment.

Everything runs inside Docker, so there are no security implications for the host system and results are fully reproducible across machines.

## How It Works

1. **Record** — Interact with any X application through a browser-based VNC viewer. Parrot captures every mouse movement, click, and keystroke. It also takes care of setting the screen and application size correctly.
2. **Replay** — Play back the recorded session against the same application. Parrot finds the correct window, replays each action with correct timing, and optionally asserts on screenshots.
3. **Benchmark** — Plug the replay into the [Green Metrics Tool](https://www.green-coding.io/projects/green-metrics-tool/) via a `usage_scenario.yml` to measure energy and performance.

## Example Applications

| Application | Path |
|-------------|------|
| Firefox | `applications/firefox/` |
| LibreOffice Calc | `applications/calc/` |
| VLC | `applications/vlc/` |
| Okular (PDF viewer) | `applications/pdf_viewers/okular/` |

Each application directory contains the recorded `.🦜` macro file and a `usage_scenario.yml` for use with the Green Metrics Tool.

## Quick Start

### 1. Start the Window Container

Every application ships with a Docker Compose file (or uses the shared `ribalba/xwindow-server` image). To bring up Firefox:

```bash
docker compose -f applications/firefox/usage_scenario.yml up --build
```

Open the GUI in your browser at `http://localhost:6080/vnc.html`.

### 2. Record a Macro

```bash
./record-macro.py applications/firefox/usage_scenario.yml
```

- Interact with the application in the browser-based VNC viewer.
- Press `Pause` to stop recording.
- Press `F2` at any point to capture a reference screenshot (inserts a `Check` assertion into the macro).

Override the hotkeys if your browser intercepts them:

```bash
STOP_KEYSYM=F9 CHECK_KEYSYM=F3 ./record-macro.py applications/firefox/usage_scenario.yml
```

Output files are written to `recordings/<app-name>/`:

```
recordings/firefox/firefox.🦜
recordings/firefox/firefox-check-001.png
```

### 3. Replay a Macro

```bash
./replay.py applications/firefox/usage_scenario.yml
```

Optional speed multiplier:

```bash
REPLAY_SPEED=2.0 ./replay.py applications/firefox/usage_scenario.yml   # faster
REPLAY_SPEED=0.5 ./replay.py applications/firefox/usage_scenario.yml   # slower
```

Replay finds the application window by class/title metadata embedded in the macro, focuses it, and plays back every action. Any `Check` line triggers a screenshot comparison against the saved reference image. A failed check exits non-zero.

## Recording Any X Application

Parrot is not limited to the bundled applications. You can record interactions with any X11 GUI application by supplying the relevant metadata at record time:

```bash
APP_STARTCOMMAND='xterm' \
APP_WINDOW_TITLE='xterm' \
APP_WINDOW_CLASS='xterm' \
./record-macro.py <your-compose-file.yml>
```

Metadata is embedded into the `.🦜` macro file and used by replay to locate and focus the correct window.

## Macro File Format

Recorded macros (`.🦜` files) contain:

- `#APP` metadata lines — window class, title, and optional start command
- Timed xmacro events — `MotionNotify`, `ButtonPress`, `KeyStrPress`, etc.
- `#WAIT_SEC <seconds>` — timing gaps between events
- `Check <path>.png` — screenshot assertion lines

Example header:

```
#APP startcommand='firefox https://browserbench.org/Speedometer3.1/'
#APP windowtitle=Firefox
#APP windowclass=firefox
```

## Screenshot Assertions

Press `F2` during recording to insert a checkpoint. During replay, Parrot compares the current window screenshot to the saved reference using RMSE.

Tune the comparison:

```bash
# Loosen the threshold
CHECK_MAX_RMSE=0.02 ./replay.py applications/firefox/usage_scenario.yml

# Ignore dynamic regions (e.g. toolbars, clocks) — format: x,y,width,height
CHECK_IGNORE_RECT=0,0,420,40 ./replay.py applications/firefox/usage_scenario.yml

# Multiple regions (semicolon-separated)
CHECK_IGNORE_RECT="0,0,420,40;300,580,120,30" ./replay.py applications/firefox/usage_scenario.yml
```

## Green Metrics Tool Integration

Parrot has native support for the [Green Metrics Tool](https://www.green-coding.io/projects/green-metrics-tool/). Each application includes a `usage_scenario.yml` that defines the container setup and the replay command:

```yaml
name: Parrot Firefox
author: Didi <didi@green-coding.io>
description: Benchmarks Firefox using Parrot

services:
  window-container:
    image: ribalba/xwindow-server
    environment:
      DEBUG: 0
    setup-commands:
      - command: bash /tmp/repo/applications/firefox/install.sh
      - command: bash /usr/local/bin/entrypoint.sh

flow:
  - name: Run Benchmark
    container: window-container
    commands:
      - type: console
        command: python3 /usr/local/bin/replay.py /tmp/repo/applications/firefox/firefox.🦜
```

Point the Green Metrics Tool at the repository and it will set up the container, run the replay, and collect energy and performance metrics automatically.

## Deterministic Window Layout

To keep click coordinates and screenshots stable across runs, configure fixed window geometry in the compose environment:

| Variable | Description |
|----------|-------------|
| `AUTO_POSITION` | `1` to enable, `0` to disable |
| `WINDOW_X` / `WINDOW_Y` | Window position |
| `WINDOW_WIDTH` / `WINDOW_HEIGHT` | Window size |
| `APP_WINDOW_CLASS` | xdotool window class matcher |
| `APP_WINDOW_TITLE` | xdotool window title matcher |

## Troubleshooting

- **Stop key not working in browser** — set `STOP_KEYSYM` to another key, e.g. `F9`.
- **Check hotkey affects the app** — Firefox `F6` focuses the toolbar; use `F2` (the default) or another key via `CHECK_KEYSYM`.
- **Screenshot checks fail due to minor UI variation** — increase `CHECK_MAX_RMSE` slightly or mask dynamic regions with `CHECK_IGNORE_RECT`.
- **Click coordinates are off** — rebuild/restart the container and re-record; window geometry may have shifted.
