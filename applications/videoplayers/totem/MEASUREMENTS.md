# Totem - measured landmarks

Everything `driver.conf` uses, measured against a live window brought up exactly
as `usage_scenario.yml` brings it up. Where Totem's behaviour and the obvious
assumption disagreed, the behaviour is what is written down - and on this entrant
they disagreed four times.

## The window

```
WM_CLASS(STRING) = "totem", "Totem"
WM_WINDOW_ROLE   = (not set)
title            = 01-h264-1440x900p30
```

Pinned by `pin-windows.sh totem 1440 900` to `X=0 Y=0 WIDTH=1440 HEIGHT=900`,
undecorated. Totem maps one window, so `record-macro.py`'s first match and
`check-image.sh`'s largest match cannot disagree.

Layout inside it, measured off captures:

| landmark | position |
|---|---|
| header bar | y 0-44 |
| languages / subtitles menu button | 1247,22 |
| main menu button | 1289,22 |
| video area | y 45-843 |
| control bar | y 845-895, auto-hiding |
| previous / play / next | 30,869 · 77,869 · 124,869 |
| seek bar | x 207-1288 at y 869 |

Totem scales the 1440x900 video down into the ~1440x798 video area, so this
entrant is always scaling where mpv is not.

## The null ALSA device froze it, and that was the root cause of three "findings"

Before the audio device was fixed, Totem sat at `00:00:00.000` for thirty seconds
of observation and looked like an entrant that does not autoplay. It also seemed
to advance its playlist when sent a space, and seemed not to seek forward. All
three were downstream of the same thing: with `pcm.!default { type null }`
GStreamer slaves the pipeline clock to an audio sink that never paces, so the
clock stalls and the video stops with it.

Measured with the null ALSA default removed and nothing else changed:

```
+6 s   00:00:06.133
+12 s  00:00:13.600
+18 s  00:00:20.967
```

and against the PulseAudio null sink that replaced it:

```
+6 s   00:00:04.333
+12 s  00:00:11.033
+18 s  00:00:18.200
```

with `pactl list short sink-inputs` showing `float32le 2ch 48000Hz`. Totem
autoplays perfectly well. See `common/install-common.sh`.

## Two keyboard traps

From Totem's own Shortcuts window, read off the screen:

| action | binding |
|---|---|
| Play/Pause | **P** / K / Ctrl+Space |
| Previous video | **B** / Alt+Left / - |
| Next video | **N** / Alt+Right / + |
| Go back 15 seconds | **Left** |
| Go forward 60 seconds | **Right** |
| Go back 5 seconds | Shift+Left |
| Go forward 15 seconds | **Shift+Right** |
| Volume up / down | **Up** / **Down** |
| Mute | **M** |
| Fullscreen | **F** / F11, **Escape** to leave |
| Select next subtitle | V |
| Toggle subtitles | Shift+V |

**Plain space is not play/pause.** It activates the focused GTK widget, which at
startup is a transport button - so a space sent as "pause" advanced the playlist.
The clip label in the frame is the only thing that showed it.

**Right is +60 s, not the mirror of Left.** On a 15-second clip that runs past the
end and advances the playlist, which is exactly what it looked like: three Rights
in a row appeared to do nothing to the position while the clip quietly changed
underneath. `Shift+Right` is the +15 s binding and is what the driver uses.

## The playlist order is not the argument order

Handing Totem all six paths at once produces a **non-deterministic** playlist.
Three identical runs, reading the title after startup and after each `n`:

```
run 1   start=02  n1=03  n2=04        <- clip 01 silently pushed to the back
run 2   start=01  n1=02  n2=03
run 3   start=01  n1=02  n2=03
```

A recording made on run 1 would replay against run 2 and every checkpoint in it
would be wrong, with nothing in the logs to say why.

`totem --enqueue` appends exactly one file to the running instance over D-Bus, so
the launcher opens clip 01, waits for the instance to own its D-Bus name, and
then enqueues the other five a second apart. Two runs of that launcher gave
`start=01 n1=02 n2=03 n3=04` both times.

An `.m3u` playlist is not an alternative: Totem never mapped a window for one,
and logged `g_filename_to_utf8: assertion 'opsysstring != NULL' failed`.

## The seek bar

Measured by clicking at known x and reading the burnt-in timecode back:

| x | timecode |
|---|---|
| 250 | 00:00:02.000 |
| 450 | 00:00:11.267 |
| 700 | 00:00:22.800 |
| 950 | 00:00:34.400 |
| 1200 | 00:00:45.933 |
| 1290 | unchanged - the click landed past the widget |

250 -> 1200 is 43.933 s over 950 px = **0.046245 s/px**, so t=0 is at
x = 250 - 2.000/0.046245 = **207**, and the 50 s clip fills 1081 px, ending at
**1288**. Checked at x=700: predicted 22.80 s, measured 22.800 s.

## Menus

Row centres measured off 2x captures rather than estimated off a montage - the
first estimates were 6 px out, which is inside a row but not reliably so.

Languages and subtitles menu, button at **1247,22**:

| row | y |
|---|---|
| Languages: English | 100 |
| Languages: German | 126 |
| Subtitles: None | 169 |
| Subtitles: English | 195 |
| Subtitles: German | 221 |
| Select Text Subtitles... | 245 |

Main menu, button at **1289,22**: Aspect Ratio 83, Switch Angles 108 (disabled),
Preferences 142, Keyboard Shortcuts 168. Clicking Aspect Ratio opens a submenu -
**clicking, not hovering**; a hover highlights the row and leaves the submenu
shut - with Auto 115, Square 141, 4:3 (TV) 167, 16:9 (Widescreen) 193,
2.11:1 (DVB) 218.

Any x from about 1180 to 1320 is inside these rows; the driver uses 1220 and
1240.

## Totem auto-selects the first subtitle track

The corpus flags neither subtitle track default and Totem selects English anyway -
confirmed by opening the menu and seeing the English radio filled. There is no
command-line option for it, so `dismiss_startup` turns subtitles off through the
menu in block 1. That costs this entrant two clicks in block 1 that mpv does not
pay; it is the price of both arriving at block 2 in the same state.

## `n` and `b` leave the clip playing

Measured: paused on clip 01 at 00:00:03.467, pressed `n`, and clip 02 read
00:00:04.517 and then 00:00:11.100 five seconds later. So unlike mpv, which
inherits the paused state and needs a space afterwards, `do_next` here is a
single key.

## Switching audio track is not visible in PulseAudio

`pactl list short sink-inputs` reported `float32le 2ch 48000Hz` both before and
after selecting the German 5.1 track: GStreamer downmixes to the sink's format,
so the channel count says nothing about which track is selected. The menu's own
radio button is the ground truth, and it moved to German.

## Getting block 1 onto a fixed frame took three attempts

The recorder needs about thirty seconds to arm and for the launcher to finish
enqueuing, and the clip plays throughout - so block 1 arrives somewhere around
00:00:36 and, worse, somewhere *different* each run: 36.367, 36.400, 36.900 and
36.967 across four recordings. Blocks 2 and 3 inherit that offset, and BBB frames
half a second apart are far enough apart to fail a 0.2 RMSE check, so this is not
cosmetic.

| attempt | result |
|---|---|
| click the left end of the position bar (`bar 0.0`) | failed four times running - block 1 stayed at ~36.9 |
| `b`, which restarts the current clip | does nothing here: measured to work from a **playing** clip, and block 1 pauses first |
| **five presses of Left** | each is -15 s and the seek clamps at zero, so from anywhere in a 50 s clip it lands on exactly 00:00:00.000 |

The clamp is the whole point: it turns "wherever startup happened to leave us"
into a fixed frame without needing to know where that was, and it needs no chrome
to be visible.

## A popover keeps its grab after it closes

The first click after a menu selection is swallowed. Measured: after selecting
Subtitles -> None, a bar click at x=207 left the position at 00:00:26.633, and an
identical second click moved it to 00:00:00.033. An `Escape` after the selection
releases the grab.

That Escape is used **only** in `dismiss_startup`. Adding one after every menu
action made things worse - Escape is also Totem's "leave fullscreen" - and
produced a recording whose playback never stopped where it should have, ending
with eight blocks all captured on clip 01 at its final frame.

## The bar click is sent twice

Not superstition: across two otherwise identical recordings, one lost the third
click of block 4 and left the position at the midpoint instead of the quarter
mark. A seek to an absolute position is idempotent, so a second click at the same
coordinates either lands on a position already set - a no-op - or catches the case
where the first was swallowed. A repeated *relative* seek could not be doubled
this way.

## The launcher waits for D-Bus, not for a clock

The first version slept ten seconds before enqueuing. One run enqueued nothing at
all: the playlist stayed one item long, `n` did nothing for the rest of the
recording, and all eight clip-change blocks captured clip 01. It now polls
`org.freedesktop.DBus.Peer.Ping` on `org.gnome.Totem` until the instance answers,
which is why `libglib2.0-bin` is in this entrant's install list.

## The recording, block by block

Read off the burnt-in timecode in each reference image. Clip 01 is 50 s, and the
last block that plays from it, block 13, finishes 10.9 s clear of the end:

| block | clip | timecode | |
|---|---|---|---|
| 1 | 01 | 00:00:00.000 | five clamped Left presses |
| 2 | 01 | 00:00:10.067 | 10 s played |
| 3 | 01 | 00:00:14.967 | ten alternating jumps; the back ones clamp at 0, so the net is forward |
| 4 | 01 | 00:00:12.500 | a quarter of 50 s, exactly |
| 5 | 01 | 00:00:18.567 | +6 s |
| 6 | 01 | 00:00:18.567 | volume moves nothing |
| 7 | 01 | 00:00:18.567 | mute moves nothing |
| 8 | 01 | 00:00:24.633 | +6 s with the German subtitles on |
| 9 | 01 | 00:00:24.633 | |
| 10 | 01 | 00:00:29.067 | +6 s on the German 5.1 track |
| 11-12 | 01 | 00:00:29.067 | aspect only |
| 13 | 01 | 00:00:39.133 | +10 s fullscreen |
| 14 | 01 | 00:00:39.133 | |
| 15 | 02 | 00:00:08.117 | |
| 16 | 03 | 00:00:08.133 | |
| 17 | 04 | 00:00:08.100 | |
| 18 | 05 | 00:00:08.100 | |
| 19 | 06 | 00:00:08.133 | upscaled 2.25x; the burnt-in label is visibly larger |
| 20 | 05 | 00:00:01.100 | previous, which is two `b` presses here |
| 21 | 06 | 00:00:08.600 | rolled over from clip 05 on its own |
| 22 | 06 | 00:00:08.600 | idle |

Unlike mpv, this entrant resumes on the rollover, so block 21 lands well inside
clip 06 and its capture differs from block 22's only in that nothing moved.
