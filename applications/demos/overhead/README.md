# Replay overhead benchmark

What does Parrot itself cost? Every measurement in this repository includes the
replay harness that drives the application. This benchmark measures the harness
on its own, against an application that does nothing, so its share can be
reported and subtracted.

Two properties of `replay.py` are under test. Both are switches, and both
defaults are what every existing scenario has always run with, so earlier runs
stay comparable.

| Variable | Default | Opt-in | What changes |
| --- | --- | --- | --- |
| `REPLAY_INJECTOR` | `xdotool` | `xtest` | How an input event reaches the X server |
| `REPLAY_TIMING` | `relative` | `absolute` | What a recorded `wait` is measured from |

## Why these two

**One process per event.** With `xdotool`, `replay.py` starts an `xdotool`
process for every `mousemove`, `mousedown`, `mouseup`, `keydown` and `keyup`.
Each process connects to the X server, reads the whole keyboard map, sends one
request and exits. `xdotool keydown` and `keyup` then also sleep 12 ms, their
default `--delay`, before exiting. The committed macros hold tens of thousands
of such events, a few hundred to well over a thousand per session.

`xtest` sends the same requests from inside `replay.py`, over one connection
that stays open for the whole replay (`XTestInjector` in `replay.py`). The
requests are read from the source of the `xdotool` in the image, 3.20160805.1:

| Event | Request, both injectors |
| --- | --- |
| `mousemove X Y` | `WarpPointer` to X,Y on the root window. `xdotool` does not use `XTestFakeMotionEvent` for an absolute move. |
| `mousedown N`, `mouseup N` | `XTestFakeButtonEvent` |
| `keydown NAME`, `keyup NAME` | `XTestFakeKeyEvent` for the lowest keycode carrying the keysym. For a modifier key, the first keycode of that modifier is sent before it, as `xdotool` does. |

So only the client changes, not what the server is asked to do. Anything
`xdotool` would treat differently, such as a keysym no keycode carries, is
handed to `xdotool` and counted as a fallback. The committed macros cause none,
see [Checking the injector](#checking-the-injector).

**Uncompensated waits.** With `relative`, every recorded wait is slept as it
is, after the previous event has been sent. The time spent sending comes on top,
so a replay runs longer than its recording by the sum of all dispatch times,
checks included. `absolute` sleeps until t0 + (recorded waits so far) / speed
on the monotonic clock, so the dispatch time comes out of the next wait. An
event that is already late is sent at once, never with a negative sleep, and
the lateness is recorded as the lag.

`absolute` changes how long the phases of an existing recording last, which is
why it is opt-in and why the two switches are measured separately.

## Design

The target is xlogo, from `x11-apps`. It draws one static picture, has no
hover effects and reacts to nothing the conditions send, so the application's
share of every phase is the same, and what differs between phases is the
replay. Its app-defaults bind exactly two keys, `q` and `Escape`, both to quit,
so the key conditions press `a` and `Shift_L` and never either of those.

The window is pinned to 1439x877 at 0,0, the geometry of the xlogo demo in
[`../xlogo/`](../xlogo/). The checks compare against `overhead-check-001.png`
in this folder and not against that demo's screenshot. xlogo in the current
image draws the logo a few pixels off the demo's screenshot along every edge,
2.5 % of the window and an RMSE of 0.159 against a limit of 0.2. That passes,
but it would also pass almost any change to xlogo, and the checks phase is
what confirms that the key phases left xlogo alone. `overhead-check-001.png`
was captured from this scenario's own setup and matches at an RMSE of 0.

Every condition is one macro, replayed as a whole file in a flow step of its
own, so every condition is a GMT phase. Each one lasts the same recorded time,
60 s by default, between an opening and a closing `log` line. Those two lines
become notes in GMT.

| Phase | Macro | Events | Measures |
| --- | --- | --- | --- |
| Start xlogo (hidden) | `start.parrot` | 1 check | Starts xlogo and checks it against the reference, outside every measured phase |
| Idle | `idle.parrot` | none | The control. xlogo, the X server, and `replay.py` starting and sleeping. |
| Mousemove 10 Hz | `mousemove-10hz.parrot` | 600 moves, 100 ms apart | Cost per event when the gaps leave plenty of room |
| Mousemove 50 Hz | `mousemove-50hz.parrot` | 3,000 moves, 20 ms apart | Cost per event at a gap longer than most in the recordings |
| Mousemove 200 Hz | `mousemove-200hz.parrot` | 12,000 moves, 5 ms apart | Cost per event at a gap shorter than an `xdotool` process takes |
| Key presses 5 Hz | `keypress-a-5hz.parrot` | 300 presses of `a`, 200 ms apart | Cost per key event, with room for `xdotool`'s 12 ms sleep |
| Key presses 20 Hz | `keypress-a-20hz.parrot` | 1,200 presses of `a`, 50 ms apart | Cost per key event at a rate `xdotool` barely keeps up with |
| Shift presses 5 Hz | `keypress-shift-5hz.parrot` | 300 presses of `Shift_L`, 200 ms apart | The modifier path of the `xtest` injector |
| Screenshot checks | `checks.parrot` | 12 checks, 5 s apart | Cost of a checkpoint, the same for both injectors. Last, so it also confirms that the key phases left xlogo as it was. |

A press is a `keydown` and a `keyup` 12 ms later. That is the hold time of the
recordings, whose median keydown to keyup gap is 11.6 ms for plain keys and
11.9 ms for modifiers.

The rates bracket the recordings. Across the committed macros (the
time-normalized copies left out), the median gap between two input events is
11.5 ms. 78 % of the gaps are shorter than 20 ms, 69 % are shorter than the
12 ms an `xdotool` key event sleeps on its own, and 19 % are shorter than 5 ms.

Key events are most of what the recordings replay. Of the 76,956 input events
in the committed macros, 62,210 (81 %) are `keydown` or `keyup`, 8,080 are
button events and 6,666 are `mousemove`. With `xdotool` a key event is also the
most expensive one, because it sleeps 12 ms after the event on top of the
process start. A press therefore costs two process starts and 24 ms of sleep.
With `relative` timing all of it is added to the phase. With `absolute` timing
at 20 presses per second most of every 50 ms period goes to sending the press,
and every `keyup` is late, because its `keydown` takes longer than the 12 ms
hold.

For orientation, these are the `dispatch_s / events` of one local GMT run per
injector, both with `relative` timing, on the development machine
(2026-10-24). They are times, not energy, and the machine was busy, so they
show the order of magnitude only.

| Phase | `xdotool` | `xtest` |
| --- | --- | --- |
| Mousemove 10 Hz | 6.1 ms per event | 0.57 ms |
| Mousemove 200 Hz | 4.2 ms | 0.49 ms |
| Key presses 5 Hz | 18.9 ms | 0.72 ms |
| Key presses 20 Hz | 19.0 ms | 0.73 ms |
| Shift presses 5 Hz | 19.1 ms | 0.71 ms |

With `xdotool` and `relative` timing, the 60 s phases ran 3.8 s (Mousemove
10 Hz), 52.7 s (Mousemove 200 Hz), 11.5 s (Key presses 5 Hz) and 46.2 s (Key
presses 20 Hz) over their recording. With `xtest` and `absolute` timing every
input phase ended within 31 ms of its recorded 60 s, and no event was more
than 2.1 ms late.

The moves alternate between 560,380 and 880,500, both inside the xlogo window,
so every event is a real move and none crosses the window border. Moves and
presses are written as a `label`/`loop` body, the same way the website scroll
macros repeat a wheel tick.

Every phase also contains what `replay.py` does before its first event. That is
the Python start, finding the xlogo window, `position-window.sh` re-applying the
pinned geometry (about half a second, mostly sleep) and the lock-key check. It
is the same in every phase, and the Idle control carries it as well, so it
cancels in a difference against Idle.

What a phase measures is therefore

    E(condition) - E(Idle)      energy of the condition's events
    ... / events                energy per event, for the mousemove and key phases
    ... / checks                energy per checkpoint, for the checks phase

and, from the phase duration, how far the replay ran over its recording.

### Runs

The two switches are chosen per run, through two GMT variables, so one scenario
file covers all four combinations:

| `__GMT_VAR_INJECTOR__` | `__GMT_VAR_TIMING__` | Role |
| --- | --- | --- |
| `xdotool` | `relative` | Before. What every other Parrot scenario runs. |
| `xtest` | `relative` | The injector alone |
| `xdotool` | `absolute` | The timing alone |
| `xtest` | `absolute` | After |

Both variables are required. GMT refuses a run at parse time when either is
missing, and also when a variable is passed that the file does not use.

Run every combination on the same machine, several times each, and in an
interleaved order rather than all repetitions of one combination in a row.
Results from different machines are not comparable. Machine 15 is the one the
Parrot application sweep runs on.

### The summary line

At the end of every replay, `replay.py` prints one line to stderr, never to
stdout, which GMT reads for notes. GMT keeps it in the run's logs.

    [replay] injector=xtest timing=absolute events=2400 fallbacks=0 dispatch_s=1.8449 checks=0 check_s=0.0000 sleep_s=58.0186 wall_s=60.0222 recorded_s=60.0000 max_lag_s=0.0008

| Field | Meaning |
| --- | --- |
| `events` | input events sent |
| `fallbacks` | events the `xtest` injector handed to `xdotool`, always 0 for `xdotool` |
| `dispatch_s` | time spent sending input events |
| `checks`, `check_s` | screenshot checks run, and the time they took |
| `sleep_s` | time spent sleeping between events |
| `wall_s` | time from reading the first macro to the end of the replay |
| `recorded_s` | recorded waits replayed, divided by `REPLAY_SPEED` |
| `max_lag_s` | the furthest any event was sent behind its recorded time |

`wall_s - recorded_s` is how far the replay ran over its recording. With
`relative` it is `dispatch_s + check_s` plus the time every sleep overshoots,
which adds up as well. At 200 events per second that was 1.5 s over 60 s even
with `xtest`. With `absolute` it is close to the lag of the last event.

## Running it locally

GMT's Postgres has to be up (`green-coding-postgres-container` on port 9573).
Energy figures from this machine mean nothing, because there is no RAPL here. A
local run shows that the scenario boots and that every flow step passes.

```bash
cd /home/didi/code/green-metrics-tool
venv/bin/python runner.py --uri /home/didi/code/parrot \
  --filename applications/demos/overhead/usage_scenario.yml \
  --name "Parrot replay overhead xtest absolute" \
  --variable __GMT_VAR_INJECTOR__=xtest --variable __GMT_VAR_TIMING__=absolute \
  --dev-no-sleeps --dev-cache-build --skip-download-dependencies --skip-optimizations \
  --dev-no-system-checks=check_ssh_session --print-phase-stats-table
```

The scenario has no `docker-run-args`, so `--allow-unsafe` is not needed.

Without GMT, a condition can be replayed in a bare container set up the way
the scenario sets it up, from the repository root.

```bash
docker run --rm -v "$PWD":/tmp/repo:ro -e REPLAY_INJECTOR=xtest -e REPLAY_TIMING=absolute \
  -e RESOLUTION=1440x900 -e WINDOW_X=0 -e WINDOW_Y=0 -e WINDOW_WIDTH=1439 -e WINDOW_HEIGHT=877 \
  ribalba/xwindow-server bash -c '
    bash /tmp/repo/applications/common/apt-snapshot.sh
    apt-get install -y -qq --no-install-recommends x11-apps=7.7+11build3 >/dev/null
    bash /usr/local/bin/entrypoint.sh
    python3 /tmp/repo/replay.py /tmp/repo/applications/demos/overhead/start.parrot
    python3 /tmp/repo/replay.py /tmp/repo/applications/demos/overhead/keypress-a-20hz.parrot'
```

## Submitting it to the cluster

Every flow step runs `/tmp/repo/replay.py`, the copy in the cloned repository,
and not `/usr/local/bin/replay.py` from the image. That copy imports
`helpers.py` and `timed_xmacro.py` from its own folder, so the branch under test
runs without a new image. `check-image.sh`, `position-window.sh` and
`freeze-window-size.py` still come from the image. The cluster clones the
branch, so it has to be committed and pushed first.

Submit once per combination.

```bash
/home/didi/code/green-metrics-tool/venv/bin/python \
  /home/didi/code/gmt-helpers/api/submit_software.py submit \
  --name "Parrot replay overhead xtest absolute" \
  --repo-url "https://github.com/green-coding-solutions/parrot" \
  --branch replay-overhead \
  --filename applications/demos/overhead/usage_scenario.yml \
  --machine-id 15 \
  --schedule-mode one-off \
  --variables "__GMT_VAR_INJECTOR__=xtest" \
  --variables "__GMT_VAR_TIMING__=absolute"
```

Put the combination into `--name`. It is what the dashboard shows.

## Changing the conditions

The macros and `usage_scenario.yml` are written by `generate.py`. Do not edit
them. Change the parameters and rerun it instead.

```bash
./generate.py                    # 60 s, moves at 10/50/200 Hz, a at 5/20 Hz, Shift_L at 5 Hz, 12 checks
./generate.py --duration 120 --move-rates 10,100 --key-rates 10 --shift-rates "" --checks 24
./generate.py --check            # exit 1 if a file is out of date
```

## Checking the injector

`check_xtest_keys.py` lists every distinct key name in the committed macros
and shows that each one resolves under the `xtest` path. With `--display` it
also presses and releases every name and every mouse button once per injector,
records the device events the X server generates with XRecord, and compares
the two recordings. It presses every key, so run it on a display with nothing
on it.

```bash
docker run --rm -v "$PWD":/tmp/repo:ro ribalba/xwindow-server bash -c \
  'Xvfb :99 -screen 0 1440x900x24 & sleep 1; DISPLAY=:99 \
   python3 /tmp/repo/applications/demos/overhead/check_xtest_keys.py --display :99'
```
