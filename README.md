# Parrot — Record and Replay X Application Interactions

Parrot lets you record mouse clicks, keyboard input, and navigation paths through any X11 GUI application, then replay those interactions automatically. It is designed for benchmarking and testing desktop applications in a reproducible, sandboxed environment.

Everything runs inside Docker, so there are no security implications for the host system and results are fully reproducible across machines.

## How It Works

1. **Record** — Interact with any X application through a browser-based VNC viewer. Parrot captures every mouse movement, click, and keystroke. It also takes care of setting the screen and application size correctly.
2. **Replay** — Play back the recorded session against the same application. Parrot finds the correct window, replays each action with correct timing, and optionally asserts on screenshots.
3. **Benchmark** — Plug the replay into the [Green Metrics Tool](https://www.green-coding.io/projects/green-metrics-tool/) via a `usage_scenario.yml` to measure energy and performance.

## Example Applications

| Application | Path |
| ----------- | ---- |
| Firefox | `applications/firefox/` |
| LibreOffice Calc | `applications/calc/` |
| VLC | `applications/vlc/` |
| Okular (PDF viewer) | `applications/pdf_viewers/okular/` |

Each application directory contains the recorded `.parrot` macro file and a `usage_scenario.yml` for use with the Green Metrics Tool.

## Quick Start

### 1. Start the Window Container

Every application ships with a Docker Compose file (or uses the shared `ribalba/xwindow-server` image).

### 2. Record a Macro

```bash
./record-macro.py applications/firefox/firefox.parrot
```

- Interact with the application in the browser-based VNC viewer.
- Press `Pause` to stop recording.
- Press `Scroll Lock` at any point to capture a reference screenshot (inserts a `Check` assertion into the macro).
- Pass `--script path/to/script.md` to attach one note per checkpoint; trimmed blank lines and lines starting with `#` are ignored.
- When a script is provided, recording shows a live checklist and highlights the next pending item in green.

Override the hotkeys if your browser intercepts them:

```bash
STOP_KEYSYM=F9 CHECK_KEYSYM=F3 ./record-macro.py applications/firefox/firefox.parrot
```

Output files are written to `recordings/<app-name>/`:

```text
recordings/firefox/firefox.parrot
recordings/firefox/firefox-check-001.png
```

### 3. Replay a Macro

```bash
./replay.py applications/firefox/firefox.parrot
```

Optional speed multiplier:

```bash
REPLAY_SPEED=2.0 ./replay.py applications/firefox/firefox.parrot   # faster
REPLAY_SPEED=0.5 ./replay.py applications/firefox/firefox.parrot  # slower
```

Replay finds the application window by class/title metadata embedded in the macro, focuses it, and plays back every action. Any `Check` line triggers a screenshot comparison against the saved reference image. A failed check exits non-zero.

### Screen Recording

Set `RECORD_VIDEO` to capture the full replay as an MP4 video:

```bash
# Save to a specific file
RECORD_VIDEO=/tmp/my-replay.mp4 ./replay.py applications/firefox/firefox.parrot

# Auto-generate a timestamped file under /tmp
RECORD_VIDEO=1 ./replay.py applications/firefox/firefox.parrot
```

The video is recorded at 25 fps using `ffmpeg`'s `x11grab` input. The output path is printed to stderr at the start and end of the run. If a `Check` step fails and replay exits early, the video is still finalized and saved.

## Recording Any X Application

Parrot is not limited to the bundled applications. You can record interactions with any X11 GUI application by supplying the relevant metadata at record time:

```bash
APP_STARTCOMMAND='xterm' \
APP_WINDOW_TITLE='xterm' \
APP_WINDOW_CLASS='xterm' \
./record-macro.py <your-parrog-file>
```

Metadata is embedded into the `.parrot` macro file and used by replay to locate and focus the correct window.

## File Extension

Parrot macro files support two extensions — `.parrot` and `.🦜` — and both work identically. This documentation uses `.parrot` throughout because it is easier to type in terminals and scripts. Feel free to use `.🦜` if you prefer the native extension:

```bash
./record-macro.py applications/firefox/firefox.🦜
./replay.py applications/firefox/firefox.🦜
```

## Macro File Format

Recorded macros (`.parrot` files) contain:

- `#APP` metadata lines — window class, title, and optional start command
- Timed xmacro events — `MotionNotify`, `ButtonPress`, `KeyStrPress`, etc.
- `#WAIT_SEC <seconds>` — timing gaps between events
- `Check <path>.png` — screenshot assertion lines
- `log <text>` — note lines emitted to stdout during replay as `<timestamp_microseconds> <text>`

Example header:

```text
#APP startcommand='firefox https://browserbench.org/Speedometer3.1/'
#APP windowtitle=Firefox
#APP windowclass=firefox
```

## Screenshot Assertions

Press `Scroll Lock` during recording to insert a checkpoint. During replay, Parrot compares the current window screenshot to the saved reference using RMSE.

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
        command: python3 /usr/local/bin/replay.py /tmp/repo/applications/firefox/firefox.parrot
```

Point the Green Metrics Tool at the repository and it will set up the container, run the replay, and collect energy and performance metrics automatically.

## Comparing Recordings Across Applications (`tools/check_blocks.py`)

When the same script is recorded against several applications (e.g. multiple PDF viewers running the same checklist), each `.parrot` file should contain the same ordered set of *blocks*. A block is the sequence of actions ending in a `log <message>` line followed by a `check <ref>.png` line — the log message is the block's identity.

`tools/check_blocks.py` cross-checks those files, prints a per-block wait-time table, and can split or time-normalize them.

```bash
# Verify structure and print the wait-time table
./tools/check_blocks.py applications/pdf_viewers/

# Write each block as its own self-contained .parrot under <app>/blocks/
./tools/check_blocks.py applications/pdf_viewers/ --split

# Write <name>-normalized.parrot next to each file, padding every block to
# the longest duration that block has across all files
./tools/check_blocks.py applications/pdf_viewers/ --normalize-time
```

The script recursively finds every `*.parrot` under the given folder, ignoring `-normalized.parrot` outputs and anything inside a `blocks/` directory. If the files disagree on block names or order, mismatches are listed on stderr and the script exits non-zero.

Time normalization inserts a single extra `wait <padding>` line immediately before each block's `log` line, so the action timing within a block is preserved while the total runtime of each block matches across files — useful for fair side-by-side benchmarking.

## Deterministic Window Layout

To keep click coordinates and screenshots stable across runs, configure fixed window geometry in the compose environment:

| Variable | Description |
| -------- | ----------- |
| `AUTO_POSITION` | `1` to enable, `0` to disable |
| `WINDOW_X` / `WINDOW_Y` | Window position |
| `WINDOW_WIDTH` / `WINDOW_HEIGHT` | Window size |
| `APP_WINDOW_CLASS` | xdotool window class matcher |
| `APP_WINDOW_TITLE` | xdotool window title matcher |

## Environment Variables

All variables can be set on the command line or, when running inside the Green Metrics Tool, in the `environment:` section of a service in your `usage_scenario.yml`:

```yaml
services:
  window-container:
    image: ribalba/xwindow-server
    environment:
      REPLAY_SPEED: "0.8"
      CHECK_MAX_RMSE: "0.05"
      PARROT_DEBUG_DIR: /tmp/parrot-debug
```

### Replay (`replay.py`)

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `DISPLAY` | `:99` | X display to replay on. |
| `REPLAY_SPEED` | `1.0` | Playback speed multiplier. `2.0` is twice as fast, `0.5` is half speed. |
| `RECORD_VIDEO` | _(off)_ | Set to a file path to save an MP4 of the replay, or `1`/`true` to auto-generate a timestamped path under `/tmp`. |
| `REPLAY_INIT_CAPSLOCK` | `off` | Desired Caps Lock state before replay starts (`on`, `off`, or `keep`). |
| `REPLAY_INIT_NUMLOCK` | `off` | Desired Num Lock state before replay starts (`on`, `off`, or `keep`). |
| `REPLAY_INIT_SCROLLLOCK` | `keep` | Desired Scroll Lock state before replay starts (`on`, `off`, or `keep`). |

### Screenshot checks (`check-image.sh`)

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `CHECK_MAX_RMSE` | `0.2` | Maximum allowed normalised RMSE between the captured screenshot and the reference image. Lower values are stricter. |
| `CHECK_IGNORE_RECT` | _(none)_ | Mask one or more regions before comparing. Format: `x,y,width,height`. Separate multiple rectangles with `;`. Useful for toolbars, clocks, or other dynamic areas. |
| `CHECK_SCALE_ON_MISMATCH` | `0` | Set to `1` to scale the captured screenshot to the reference size when dimensions differ, instead of failing immediately. |
| `PARROT_DEBUG_DIR` | _(none)_ | Directory where failure artifacts (actual screenshot, diff overlay, metadata) are copied when a check fails. The directory must already exist. When unset, artifacts are only kept in a temporary directory that is deleted on exit. |

### Window server (`entrypoint.sh`)

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `DISPLAY` | `:99` | X display number used by Xvfb and all X tools. |
| `SCREEN_SIZE` | `1440x900x24` | Virtual display resolution and colour depth passed to Xvfb. |
| `DEBUG` | `0` | Set to `1` to enable verbose entrypoint logging. |

### Recording (`record-macro.py`)

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `STOP_KEYSYM` | `Pause` | Key that stops the recording session. Override if your browser or OS intercepts the default. |
| `CHECK_KEYSYM` | `Scroll_Lock` | Key that inserts a screenshot checkpoint during recording. Must differ from `STOP_KEYSYM`. |

## Troubleshooting

- **Stop key not working in browser** — set `STOP_KEYSYM` to another key, e.g. `F9`.
- **Check hotkey affects the app** — `Scroll Lock` is the default; if your keyboard or environment handles it poorly, choose another key via `CHECK_KEYSYM`.
- **Screenshot checks fail due to minor UI variation** — increase `CHECK_MAX_RMSE` slightly or mask dynamic regions with `CHECK_IGNORE_RECT`.
- **Click coordinates are off** — rebuild/restart the container and re-record; window geometry may have shifted.

## Workflow to record an application

1. Copy a usage_scenario file into a new folder. Edit it so that the applications are installed in the setup commands section. Also change the paths to the new folder

2. Start the application with the GMT to make sure that everything is set with

   ```bash
   ./runner.py --uri /home/didi/code/parrot --filename applications/pdf_viewers/okular/okular.yml --dev-no-sleep --allow-unsafe --debug
   ```

   Then step to the point when the container is started and the setup-commands are exectuted.

3. Connect to the VPN through [http://localhost:6080/vnc.html](http://localhost:6080/vnc.html)

   You should see a blank screen with no application loaded

4. Start the recording program with

   ```bash
   ./record-macro.py --script applications/pdf_viewers/script.md --startcommand okular --windowtitle Okular --windowclass okular  applications/pdf_viewers/okular/okular.parrot
   ```


## Credit / Funding

This work is funded by the Deutsche Bundesstiftung Umwelt (DBU) under the number [DBU Project 39703/01](https://www.dbu.de/projektdatenbank/39703-01/)

Project details are to be found on the [project page](https://greencoding.f2.htw-berlin.de/projekte/caso-entwicklung-von-technologien-zur-co2-und-energieeinsparung-bei-der-softwareentwicklung/)

![DBU Logo](https://www.dbu.de/app/uploads/jpg-DBU-Logosponsored-by-RGB.jpg)

We are super grateful for this funding and are blessed to have been granted the opportunity to create this data repository for the greater
software community!

   make sure to adapt the commands. Now the application should be loaded in the VNC and have the focus. Now everytime you select Scroll Lock the script should advance.
