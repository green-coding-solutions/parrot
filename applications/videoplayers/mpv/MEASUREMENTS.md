# mpv - measured landmarks

Everything `driver.conf` uses, measured against a live window brought up exactly
as `usage_scenario.yml` brings it up. Nothing here is inferred from
documentation; where mpv's manual and the running program disagreed, the running
program is what is written down.

## The window

```
WM_CLASS(STRING) = "mpv", "mpv"
WM_WINDOW_ROLE   = (not set)
title            = 01-h264-1440x900p30 - mpv
```

Unpinned, mpv sizes the window to the video: `X=0 Y=76 WIDTH=1440 HEIGHT=810`,
centred by fluxbox. Pinned by `pin-windows.sh mpv 1440 900` it is
`X=0 Y=0 WIDTH=1440 HEIGHT=900`, undecorated, so client coordinates are screen
coordinates. The 1440x810 video then sits in a 1440x900 window with a 45 px
letterbox top and bottom, which is what every reference image shows.

mpv maps exactly one window. That matters because `record-macro.py` captures the
FIRST `xdotool search --onlyvisible --class mpv` match while `check-image.sh`
takes the LARGEST, and with one window they cannot disagree. VLC and SMPlayer map
eight each; mpv is the easy case.

## The window resizes itself - and only the corpus could fix it

`auto-window-resize` defaults to `yes`, and mpv acts on it whenever the video
geometry changes. Measured across one full recording, with the fluxbox pin
active the whole time:

| after block | window | why |
|---|---|---|
| 1-10 | 1440x900 | pinned at map time |
| 11 aspect 4:3 | **1440x1080** | mpv resized the window to the overridden aspect |
| 12 aspect back | **1440x810** | resized again, to the video's own size - not back to the pin |
| 16 | **640x360** | the upscaled-SD clip; mpv shrank the window to the video |

fluxbox applies an `[app]` rule when a window is MAPPED, so none of these was
corrected.

**`auto-window-resize=no` does not fix it.** Measured: with the option set, mpv
0.37 still went to 640x360 across a playlist change. Two things together do fix
it, and the first is not an mpv setting at all:

* the corpus is **1440x900, exactly the pinned window**, so five of the six clips
  give mpv nothing to resize to. This is why the whole corpus was rebuilt at the
  screen's own 16:10 shape rather than at 16:9 - a letterbox means the video's
  size and the window's size are two different numbers, and mpv resolves that
  disagreement by moving the window;
* `autofit=1440x900` handles the sixth, scaling the 640x400 clip **up** to the
  window instead of shrinking the window down to it - which is exactly what
  block 19 is meant to measure.

One exception remains and is expected: the aspect-override blocks ask for 4:3,
mpv fits that inside 1440x900 as 1200x900, so block 11 is the only capture in
this entrant that is not 1440x900. `CP()` warns about it on every recording.

## The OSC seek bar

mpv has no widgets. The OSC is a Lua script that draws the controls into the
video frame and fades them out about a second after the pointer stops moving,
which is why `park()` puts the pointer at 1430,8 and waits before every capture.

The bar was measured by clicking at a known x and reading the clip's own burnt-in
timecode back off the frame - never off the widget's apparent edges, which are
inset by an amount no screenshot shows:

| x | timecode |
|---|---|
| 300 | 00:00:00.233 |
| 400 | 00:00:04.967 |
| 600 | 00:00:14.433 |
| 800 | 00:00:23.900 |
| 900 | 00:00:28.600 |
| 930 | 00:00:29.967 (clamped at the end) |

400 -> 800 gives 18.933 s over 400 px = **0.04733 s/px**, so t=0 is at
x = 400 - 4.967/0.04733 = **295** and the end of the 30 s clip used for the
measurement was at **929**. Checked against the reading at x=600: predicted
14.44 s, measured 14.433 s.

`BAR_Y=880`.

The bar's ends do not move between clips even though the clips differ in length:
its width is what is left after the elapsed and remaining labels either side of
it, and every clip in the corpus is under a minute, so both labels are eight
characters wide throughout.

## Track selection, and why mpv needs `--sid=no`

The corpus deliberately flags neither subtitle track `default`, so that every
entrant starts with subtitles off. **mpv selects the first subtitle track
anyway.** Read off the OSC's subtitle indicator on a freshly started player:
`1/2`, on a file whose subtitle streams both carry `default=0`.

So mpv gets `--sid=no` in its launcher. Without it mpv would be the only entrant
drawing subtitles through blocks 2 to 7 - a text renderer's worth of work per
frame that no other entrant is doing.

With `--sid=no` the `j` cycle starts at "off". Measured off the OSC indicator:

```
-/2  --j-->  1/2  --j-->  2/2  --j-->  -/2
```

so German is two presses and off is one more. `#` (`numbersign` to xdotool)
moves the audio indicator `1/2 -> 2/2`, English stereo to German 5.1.

## Play state across a playlist change

`>` does **not** resume. mpv's `pause` is a global property, so pressing `>` on a
paused clip lands paused on the next one - measured, the OSC showed the play
triangle on `02-h264-1440x900p60` at `00:00:00` after the press. `do_next` and
`do_prev` therefore end with a `space`, because `drive-scenario.sh` requires them
to leave the new clip playing.

## Volume

`9` is `add volume -2` and `0` is `add volume 2`; there is no coarser binding and
the OSC has no volume slider, only a mute button. 38 presses take the default 100
to 24 - "about a quarter" - and 38 of `0` put it back. This is the only route mpv
offers, and it is why this entrant's volume block is 76 keystrokes where another
entrant's is one drag.

## Fullscreen changes no pixels here

The pinned window is already an undecorated 1440x900 at 0,0, so `f` produces a
window of the same size in the same place. It is still a real state change - mpv
sets `_NET_WM_STATE_FULLSCREEN` - but blocks 13 and 14 look identical to their
neighbours in this entrant, where in the entrants that have a menu bar and a
control bar to hide they do not.

## Startup

`LOAD_WAIT=12`, on top of the 12 s `record-session.sh` waits for the recorder to
arm. Those 24 s are 24 s of playback: the first recording paused block 1 at
**22.9 s** into what was then a 30-second clip, which ran the clip out during
block 2 and advanced the playlist under the whole rest of the run. Block 1 now
ends with a seek back to the start, and clip 01 is 50 s.

## A correction: the rollover is fine

An earlier recording of this entrant ended block 21 on clip 06's **first** frame,
at 00:00:00.000, and stayed there - so the note here used to say that mpv pauses
itself when a clip runs out and the playlist advances. It does not. That was the
null ALSA device stalling the clock, the same defect that froze Totem, and it
disappeared when the image moved to a PulseAudio null sink. Block 21 now lands at
00:00:10.567, well inside clip 06.

It is left written down because it is the second finding in this group that was
really the audio device wearing a costume, and because "the player pauses itself"
is exactly the kind of plausible explanation that survives a passing replay.

## The recording, block by block

Read off the burnt-in timecode in each reference image. Clip 01 is 50 s long, so
the last block that plays from it, block 13, finishes 8.6 s clear of the end:

| block | clip | timecode | |
|---|---|---|---|
| 1 | 01 | 00:00:00.000 | the seek back to the start landed exactly |
| 2 | 01 | 00:00:10.067 | 10 s played |
| 3 | 01 | 00:00:09.600 | ten alternating jumps, net -0.5 s |
| 4 | 01 | 00:00:12.467 | a quarter of 50 s |
| 5 | 01 | 00:00:18.567 | +6 s |
| 6 | 01 | 00:00:18.567 | volume moves nothing |
| 7 | 01 | 00:00:18.567 | mute moves nothing |
| 8 | 01 | 00:00:24.633 | +6 s with subtitles on |
| 9 | 01 | 00:00:24.633 | |
| 10 | 01 | 00:00:28.833 | +6 s on the German 5.1 track |
| 11-12 | 01 | 00:00:28.833 | aspect only; block 11's window is 1200x900 |
| 13 | 01 | 00:00:38.900 | +10 s fullscreen, 11 s of clip left |
| 14 | 01 | 00:00:38.900 | |
| 15 | 02 | 00:00:10.083 | |
| 16 | 03 | 00:00:10.100 | |
| 17 | 04 | 00:00:10.100 | |
| 18 | 05 | 00:00:10.067 | |
| 19 | 06 | 00:00:10.100 | upscaled 2.25x; the burnt-in label is visibly larger |
| 20 | 05 | 00:00:03.100 | previous |
| 21 | 06 | 00:00:10.567 | rolled over from clip 05 on its own |
| 22 | 06 | 00:00:10.567 | idle |
