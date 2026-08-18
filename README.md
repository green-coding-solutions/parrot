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
| Thunderbird (email client) | `applications/emailclients/thunderbird/` |

Each application directory contains the recorded `.parrot` macro file and a `usage_scenario.yml` for use with the Green Metrics Tool.

Three directories hold whole comparisons rather than a single application, where the same script is recorded against every candidate:

| Comparison | Path | What it provides |
| ---------- | ---- | ---------------- |
| PDF viewers | [`applications/pdf_viewers/`](applications/pdf_viewers/) | Six viewers over one local document |
| Email clients | [`applications/emailclients/`](applications/emailclients/) | Eight clients over a local IMAP server holding a deterministic ~500 MB mailbox |
| Code editors | [`applications/codeeditors/`](applications/codeeditors/) | Eleven editors over one Python project, including a generated 10 MB source file |

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
- A script line may be written as `label: detailed instruction`. Recording shows the whole line, so whoever drives the application knows exactly what to do and every application is driven identically. Replay emits only the label as the note. See [Script labels](#script-labels).
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

Skip the screenshot comparisons entirely with `--no-checks` (or `REPLAY_IGNORE_CHECKS=1`). `Check` lines are then logged and skipped instead of asserted, so replay never fails on a mismatched display. This is useful for benchmarking on hardware where the reference screenshots were not captured:

```bash
./replay.py --no-checks applications/firefox/firefox.parrot
REPLAY_IGNORE_CHECKS=1 ./replay.py applications/firefox/firefox.parrot
```

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
- `log <text>` — note lines emitted to stdout during replay as `<timestamp_microseconds> <label>`, where the label is the part of `<text>` before the first colon (see [Script labels](#script-labels))

Example header:

```text
#APP startcommand='firefox https://browserbench.org/Speedometer3.1/'
#APP windowtitle=Firefox
#APP windowclass=firefox
```

## Script labels

A checkpoint script line can carry both a short label and the full instruction,
separated by the first colon:

```text
* Reply and send: reply to message 2 with the body text `Thank you so much` and send it
```

The two audiences want different things from that line, so each gets what it
needs:

| Where | What it uses | Why |
| ----- | ------------ | --- |
| Recording checklist | the whole line | Whoever drives the application has to know exactly what to do, or two recordings of the "same" step end up being different steps. |
| The `.parrot` file | the whole line | A recording stays self-documenting; you can read what a block was meant to do a year later. |
| Replay output and Green Metrics Tool notes | the label only | The note names a measurement phase. A full sentence per phase makes the report unreadable. |
| `tools/check_blocks.py` table | the label only | Same reason — but block *identity* still compares the whole line, so two files disagreeing on the detail is still an error. |

Only lines starting with `*` become checkpoints. Blank lines and lines starting
with `#` are skipped — but **an HTML comment block is not**. `<!-- ... -->` in a
script file is parsed as ordinary note text, so every line of it is consumed as a
checkpoint note and the real steps shift out of alignment. The recording still has
the right number of blocks, which is what makes it easy to miss: the block *names*
are the comment prose. Keep explanations in a README rather than in the script.

Scripts without colons keep working unchanged: the whole line becomes the label.
Only the first colon splits, so an instruction may contain as many more as it
likes. A line starting with a colon is left alone rather than producing an empty
note.

[`applications/emailclients/script.md`](applications/emailclients/script.md) uses
this throughout — the same scenario has to be reproduced by hand against eight
different email clients, which is exactly the case where a vague instruction
turns into eight subtly different benchmarks.

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

The class is tried first and the title only if it finds nothing, so an app whose
windows all share one `WM_CLASS` needs the class left **empty** to be matched
reliably — otherwise the lookup returns whichever window it happens to hit first.
Recording with `--windowclass ''` stores an empty value and matching falls through
to the title alone. Thunderbird needs this: its main window is `"Mail"`, its
composer `"Msgcompose"` and its dialogs `"Thunderbird"`, so no single class
identifies the window the coordinates were measured against.

Empty is therefore meaningful and is preserved end to end — through the `.🦜`
file, `position-window.sh` and `check-image.sh`. Only an *unset* matcher falls
back to the `gnome-calculator` demo default.

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
| `REPLAY_IGNORE_CHECKS` | _(off)_ | Set to `1`/`true` to skip all `Check` screenshot comparisons (same as the `--no-checks` flag). Checks are logged and skipped instead of asserted. |

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
   make sure to adapt the commands. Now the application should be loaded in the VNC and have the focus. Now everytime you select Scroll Lock the script should advance.


## Credit / Funding

This work is funded by the Deutsche Bundesstiftung Umwelt (DBU) under the number [DBU Project 39703/01](https://www.dbu.de/projektdatenbank/39703-01/)

Project details are to be found on the [project page](https://greencoding.f2.htw-berlin.de/projekte/caso-entwicklung-von-technologien-zur-co2-und-energieeinsparung-bei-der-softwareentwicklung/)

![DBU Logo](https://www.dbu.de/app/uploads/jpg-DBU-Logosponsored-by-RGB.jpg)

We are super grateful for this funding and are blessed to have been granted the opportunity to create this data repository for the greater
software community!
