# VLC - measured landmarks

Everything `driver.conf` uses, measured against a live window brought up exactly
as `usage_scenario.yml` brings it up. Three real defects in `install.sh` were
found on the way and are written up below, because all three were silent.

## The window

```
WM_CLASS(STRING) = "vlc", "vlc"
WM_WINDOW_ROLE   = "vlc-main"      (the privacy dialog carries "vlc-privacy")
title            = 01-h264-1440x900p30 - VLC media player
```

Pinned to `X=0 Y=0 WIDTH=1440 HEIGHT=900`, undecorated. VLC maps eight windows
with this class; the main window is first and largest, so `record-macro.py` and
`check-image.sh` agree.

| landmark | position |
|---|---|
| menu bar | y 10: Media 24, Playback 84, Audio 150, Video 206, Subtitle 266, Tools 320, View 368 |
| video area | y 22-840 |
| seek bar | x 62-1378 at y 856 |
| transport | y 884: play 24, previous 60, stop 90, next 114, fullscreen 144 |

## Three defects in the launcher, all silent

**`--no-qt-updates-notif` is not a VLC option.** VLC 3.0.20 refuses to start with
it - `unknown option or missing mandatory argument` - and exits before mapping a
window, which looks exactly like a slow start. `--no-qt-privacy-ask` is real.
`vlc --longhelp --advanced` is the authority.

**VLC resizes its own window.** It came up **1440x974** - the 1440x900 video plus
its control bar - with the bottom 74 px off the screen, and the fluxbox pin did
not hold it, because fluxbox applies a rule when a window MAPS and VLC resized
afterwards. `--no-qt-video-autoresize` fixes it. This is the same class of
problem as mpv's autofit and Celluloid's GL surface: three entrants, three
different post-map resizes.

**VLC could not reach the audio sink, and said so only in its log.**
`/etc/pulse/client.conf` names the socket and `pactl info` works for `vlcuser`,
but VLC itself reported `PulseAudio server connection failure: Connection
refused` and fell through to ALSA, which has no device:
`main audio output error: module not functional`. That is this entrant silently
not decoding audio while the other six did. Setting **`PULSE_SERVER`** in the
environment fixes it, and `pactl list short sink-inputs` then shows VLC as
`float32le 2ch 48000Hz`.

## The seek bar

Measured on the 15 s clip 02:

| x | timecode |
|---|---|
| 100 | 00:00:00.450 |
| 400 | 00:00:03.850 |
| 800 | 00:00:08.400 |
| 1200 | 00:00:12.967 |
| 1370 | 00:00:14.883 |

400 -> 1200 is 9.117 s over 800 px = **0.011396 s/px**, so t=0 is at x=**62** and
15 s ends at x=**1378**. The fit is the cleanest in the group: predicted 8.41 at
x=800 against 8.400 measured, 0.43 at x=100 against 0.450, and 14.91 at x=1370
against 14.883.

`BAR_Y=856`.

## The video menu is disabled while paused

This is the trap this entrant contributes, and it changes how the driver has to
be written. With playback **paused**, VLC's Video menu greys out Zoom, **Aspect
Ratio**, Crop, Deinterlace and Take Snapshot. Resume, and all of them enable.

`drive-scenario.sh` reaches blocks 11 and 12 - the aspect blocks - with the clip
paused, so a menu route would find them greyed. VLC binds **`a`** to "cycle
aspect ratio", and that is what the driver should use, but whether it works while
paused has not been checked yet.

## Menus

| path | position |
|---|---|
| Video menu | 206,10 |
| Video: Video Track 35, Fullscreen 61, Always Fit Window 87, Set as Wallpaper 112, Zoom 138, **Aspect Ratio 163**, Crop 189, Deinterlace 215, Deinterlace mode 240, Take Snapshot 266 | x 250 |
| Subtitle menu | 266,10 |
| Subtitle: Add Subtitle File 36, **Sub Track 60** | x 280 |
| Audio menu | 150,10 |

## Confirmed behaviour

* **Subtitles are off at startup** - VLC does not auto-select the first track,
  unlike mpv, Totem and Parole, so no `dismiss_startup` is needed for them.
* **Space toggles** play and pause.
* **`n` goes to the next clip and leaves it playing** - measured: clip 03 read
  00:00:05.233 and then 00:00:12.267 five seconds later. So `do_next` is a single
  key, as in Totem, SMPlayer and Parole.

## The rest, measured

**Track menus stay enabled while paused**, unlike the video ones - checked in the
state the blocks actually run in. Sub Track: Disable 60, Track 1 [English] 84,
Track 2 [German] 109 at x=470, reached through Subtitle 266,10 -> Sub Track
280,60. Audio Track: Disable 35, Track 1 60, Track 2 83 at x=420, through
Audio 150,10 -> Audio Track 200,34.

**The aspect cycle, read off VLC's own OSD one press at a time:**

```
Default -> 1:1 -> 4:3 -> 16:9 -> 16:10 -> 221:100 -> 235:100 -> 239:100 -> 5:4 -> Default
```

so 4:3 is **two** presses of `a` and getting back to Default is **seven** more,
not two. The frames confirm it: block 11's capture is visibly pillarboxed and
block 12's is full width again.

**`p` goes back one clip and does not restart the current one first** - measured
03 -> 02 -> 01, one clip per press. That is unlike Totem, whose `b` restarts
before it moves.

**Fullscreen** is `f` to enter and `Escape` to leave; the window stays 1440x900
through the round trip, since it already fills the screen.

## The recording, block by block

| block | clip | timecode | |
|---|---|---|---|
| 1 | 01 | 00:00:00.067 | |
| 2 | 01 | 00:00:10.167 | |
| 3 | 01 | 00:00:10.000 | ten alternating jumps |
| 4 | 01 | 00:00:12.567 | a quarter of 50 s |
| 5 | 01 | 00:00:18.633 | |
| 6-7 | 01 | 00:00:18.633 | volume and mute move nothing |
| 8-9 | 01 | 00:00:24.700 | |
| 10-12 | 01 | 00:00:30.767 | audio track, then aspect out and back |
| 13-14 | 01 | 00:00:40.800 | |
| 15 | 02 | 00:00:10.033 | |
| 16 | 03 | 00:00:10.033 | |
| 17 | 04 | 00:00:10.000 | |
| 18 | 05 | 00:00:10.033 | |
| 19 | 06 | 00:00:10.067 | |
| 20 | 05 | 00:00:03.000 | |
| 21 | 06 | 00:00:10.467 | rolled over on its own |
| 22 | 06 | 00:00:10.467 | idle |
