# SMPlayer - measured landmarks

Everything `driver.conf` uses, measured against a live window brought up exactly
as `usage_scenario.yml` brings it up.

## The window

```
WM_CLASS(STRING) = "smplayer", "smplayer"
title            = 01-h264-1440x900p30 - SMPlayer
```

Pinned to `X=0 Y=0 WIDTH=1440 HEIGHT=900`, undecorated.

**This entrant maps eight windows with the same WM_CLASS** - the main window and
seven Qt children:

```
[01-h264-1440x900p30 - SMPlayer]  1440x900   <- first, and largest
[smplayer]                        1440x756
[smplayer]                        1440x22
[smplayer]                        1440x24
[smplayer]                        1440x45
[smplayer]                        1440x53
[smplayer]                        1440x756
[smplayer]                        1210x756
```

That matters because `record-macro.py` captures the **first** `xdotool search`
match while `check-image.sh` takes the **largest**. Here they are the same window
- the main window is both - so the two agree. `CP()` asserts the captured size on
every checkpoint anyway, because if they ever stopped agreeing the reference
images would silently become pictures of a toolbar.

Layout, measured off captures:

| landmark | position |
|---|---|
| menu bar | y 10: Open 28, Play 72, Video 124, Audio 170, Subtitles 230, Browse 296, View 350, Options 406 |
| toolbar | y 44 |
| video area | y 67-830 |
| control bar | y 849 |
| seek bar | x 257-1211 at y 849 |

## The seek bar snaps to keyframes, and that is fine

Measured by clicking at known x on the 50 s clip and reading the burnt-in
timecode:

| x | timecode |
|---|---|
| 220 | 00:00:00.000 |
| 500 | 00:00:12.733 |
| 800 | 00:00:28.100 |
| 1100 | 00:00:44.167 |

500 -> 1100 is 31.434 s over 600 px = **0.05239 s/px**, so t=0 is at x=**257** and
the clip ends near x=**1211**. The fit is not perfect - x=800 predicted 28.45 and
measured 28.100 - because the seek lands on the nearest keyframe.

That is deterministic, which is what a recording needs: **three clicks at x=700
all landed on 00:00:23.600**. It is not exact, which is why block 1 clicks at
x=215 rather than at BAR_X0: a click on the bar's own zero lands on the keyframe
at 00:00:01.500, while a click short of the trough clamps to 00:00:00.000 and
matches what the other entrants do.

A plain left click seeks absolutely here - no middle-click needed, unlike the
QScrollBar trick AGENTS.md describes for list widgets.

## Keys

Read out of `/usr/share/smplayer/shortcuts/default.keys`, then checked against
the running program:

| action | key |
|---|---|
| pause (toggles) | Space |
| rewind1 / forward1 | Left / Right |
| decrease_volume / increase_volume | 9 / 0 |
| mute | M |
| next_subtitle | J |
| next_audio | K |
| next_aspect | A |
| fullscreen | F |
| play_next / play_prev | `>` / `<` |

**Space is bound to an action called `pause`, and it toggles.** Measured: space
paused at 00:00:14.700, the clip was still there four seconds later, and a second
space resumed it and ran the clip out into the next one.

`J` cycles off -> English -> German -> off, read off the rendered subtitle line.

## Aspect ratio goes through the menu

`A` is `next_aspect` and cycles through eleven ratios, so the driver uses
Video -> Aspect ratio instead. The submenu **opens on a click**; hovering the
parent row left it highlighted and the submenu shut, twice.

| row | position |
|---|---|
| Video menu | 124,10 |
| Aspect ratio | 210,184 |
| submenu: Auto | 520,184 |
| submenu: 4:3 | 520,259 |

The submenu's Auto row sits at the parent row's own y, which is convenient and
worth writing down rather than re-deriving.

## The new clip arrives playing

After `>` clip 02 read 00:00:03.367 and then 00:00:11.217 five seconds later, so
`do_next` is a single key here. mpv and Celluloid both inherit the paused state
and need a space afterwards; this entrant and Totem do not.

## The recording, block by block

| block | clip | timecode | |
|---|---|---|---|
| 1 | 01 | 00:00:00.000 | the click short of the trough clamps |
| 2 | 01 | 00:00:10.067 | |
| 3 | 01 | 00:00:12.733 | ten alternating jumps, landing on a keyframe |
| 4 | 01 | 00:00:12.733 | a quarter of 50 s, to the nearest keyframe |
| 5 | 01 | 00:00:18.800 | |
| 6-7 | 01 | 00:00:18.800 | volume and mute move nothing |
| 8-9 | 01 | 00:00:24.867 | |
| 10-12 | 01 | 00:00:29.067 | audio track, then aspect |
| 13-14 | 01 | 00:00:39.133 | |
| 15 | 02 | 00:00:08.150 | |
| 16 | 03 | 00:00:08.167 | |
| 17 | 04 | 00:00:08.133 | |
| 18 | 05 | 00:00:08.133 | |
| 19 | 06 | 00:00:08.133 | |
| 20 | 05 | 00:00:01.133 | |
| 21 | 06 | 00:00:05.867 | rolled over on its own |
| 22 | 06 | 00:00:05.867 | idle |
