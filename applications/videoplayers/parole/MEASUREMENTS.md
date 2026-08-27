# Parole - measured landmarks

Everything `driver.conf` uses, measured against a live window brought up exactly
as `usage_scenario.yml` brings it up.

## The window

```
WM_CLASS(STRING) = "parole", "Parole"
title            = 01-h264-1440x900p30
```

Pinned to `X=0 Y=0 WIDTH=1440 HEIGHT=900`, undecorated, one window only.

| landmark | position |
|---|---|
| menu bar | y 10: Media 28, Playback 92, Audio 156, Video 210, Tools 260, Help 308 |
| track bar | y 48: Audio Track combo 136, Subtitles combo 310 |
| video area | y 66-860 |
| control bar | y 878: previous 24, play/pause 58, next 92 |
| seek bar | x 185-1303 at y 878 |

The **track bar** is unusual and useful: Parole puts an Audio Track and a
Subtitles combo box permanently on screen, so both are one click away and, more
importantly, **both are visible in every reference screenshot**. This is the only
entrant in the group where a capture shows which tracks are selected.

## The seek bar

Measured by clicking at known x on the 50 s clip 01:

| x | timecode |
|---|---|
| 200 | 00:00:00.000 |
| 400 | 00:00:09.600 |
| 700 | 00:00:23.000 |
| 1000 | 00:00:36.433 |

400 -> 1000 is 26.833 s over 600 px = **0.044722 s/px**, so t=0 is at x=**185**
and 50 s ends near x=**1303**. Checked at x=700: predicted 23.03, measured
23.000.

Absolute and idempotent - three clicks at the same x all landed on the same
timecode. The landing snaps to a keyframe, which is why the first attempt at this
measurement, taken on the 15-second clip, fitted badly: too few keyframes for the
quantisation to average out. Redoing it on the long clip gave a clean fit.

## The combo boxes move under their own state

This is the defect this entrant contributed, and it is worth stating plainly.

Measured with **English** selected, the Subtitles combo dropped down with English
at y=52 and German at y=81. The recording reaches block 8 with **None** showing -
block 1 turns subtitles off - and the click at y=81 selected **English**, not
German. The evidence was in the reference image itself: block 8's track bar read
`Subtitles: English`.

A combo popup aligns its current selection under the pointer, so its row
positions are a function of what is already selected. `Video -> Subtitles` does
not move: None 89, Select Text Subtitles 115, English 141, German 166. Both
subtitle actions go through the menu now.

The Audio Track combo is kept, because it demonstrably worked - block 10 read
`Audio Track: German` - and it reaches that block with English selected, which is
the state its rows were measured in.

## Subtitles are on at startup

Parole selects the first subtitle track even though the corpus flags neither
default - the same behaviour as Totem and mpv. There is no command-line option,
so `dismiss_startup` turns them off through Video -> Subtitles -> None, and the
track bar in every later capture shows `Subtitles: None` until block 8.

## Keys

| action | key | measured |
|---|---|---|
| play/pause | Space | paused at 00:00:09.967, unchanged four seconds later |
| seek back / forward | Left / Right | 9.967 -> 0.000, 0.000 -> 09.583, so about 10 s |
| volume up / down | `+` / `-` | from the Audio menu |
| mute | `0` | from the Audio menu |
| fullscreen | F11 | from the Video menu |

Parole binds no key to next or previous track, so the driver clicks the transport
buttons. The new clip arrives **playing** - measured: after the next button clip
02 read 00:00:03.400 and then 00:00:10.450 five seconds later.

## A weakness worth naming

Block 8 asks for the German subtitle track and then plays six seconds. The
corpus's cues run 0.5-4.5, 5.5-9.5, 10.5-14.5 and so on, and this entrant's block
8 finishes at 00:00:24.867 - a fifth of a second after cue 5 ends. So the capture
shows no subtitle at all, and blocks 8 and 9 differ only in the track bar.

Here the track bar rescues it. In the entrants that have no such bar, blocks 8
and 9 can be indistinguishable, which is the same class of weakness as the volume
and mute blocks. Making the cues continuous would fix it for every entrant and
would mean rebuilding the corpus and re-recording everything.
