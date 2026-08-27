# Benchmarking video players

Five video players driven through the same twenty-two-block session against the
same committed corpus. Nothing is downloaded at measurement time, so a recording
made today replays identically next year and on another machine.

**Status: all five record and replay cleanly - mpv, VLC, SMPlayer, Parole and
Totem.** Each is verified block by block against the clip name and timecode burnt
into every frame, and each runs end to end under Green Metrics Tool.

## Celluloid and Kaffeine were dropped

The group started with seven. **Celluloid and Kaffeine were removed because we
could not get them to record reliably**, and neither failure was something the
driver could work around. Both are written up in full, with reproductions and
measurements, in [VERIFICATION.md](VERIFICATION.md) - the short version:

* **Celluloid** - its GL surface goes black, and *every* reconfigure re-rolls the
  dice. Not a capture artefact: the root window and the window drawable were
  captured at the same instant and agree exactly. Two recordings in a row came
  out with a black video area for half their blocks, while six isolated launches
  out of six rendered fine, so it does not even reproduce on demand. Nothing
  short of another reconfigure recovers it, and `GSK_RENDERER=cairo` does not
  help.
* **Kaffeine** - its paused seeks are coalesced and dropped. Three forward seeks
  three seconds apart all left the position reading 00:00:39.333, so block 13's
  absolute seek cannot land on a fixed frame. The drift compounds until the
  playlist runs out and block 19's reference reads "Stopped". A deterministic
  route does exist - Kaffeine's own **Jump to Position (Ctrl+J)** takes an exact
  timestamp - but taking it would mean block 13 was no longer "the player's own
  seek keys" as `script.md` describes it, and that block would stop being
  comparable with the other entrants. That is a decision about the group's
  design, so it was left alone rather than fudged.

**Both would still have *run*.** Kaffeine's last GMT run reported 22 PASS /
0 FAIL on a recording whose block 19 says "Stopped" and whose last three blocks
are black, because the broken references match the broken replay exactly. That is
the trap described under "the pass count is not evidence" below, and it is the
reason they were dropped on the evidence of the burnt-in labels rather than kept
on the evidence of a green checkmark.

If they are ever revisited, the two things to attack are Celluloid's surface
(what does block 1 - pause, then seek - do that six clean launches did not?) and
Kaffeine's seek determinism.

## What the seven-entrant group taught us

This file used to say that *three* entrants were blocked by defects of their own.
Three defects in one group of seven widely-shipped players was not a plausible
reading, and it did not survive being checked:

| was called | actually was |
|---|---|
| Kaffeine plays the 60 fps clip at 1.46x | 0.96x - measured against a stale instance |
| Kaffeine's blocks 13/14 are grey | forward seeks while paused, on a corpus with no keyframe cadence |
| Totem dies after a subtitle change **plus a fullscreen cycle** | the fullscreen half was never needed - see below |
| Celluloid is black at startup | black at *any* reconfigure, and every reconfigure re-rolls it |

**Two of those were ours**: a corpus with no keyframe cadence, which put a
2.5x decode-cost difference on the codec axis the group exists to measure, and
menus driven by fixed coordinates - which in Totem's case clicked "Keyboard
Shortcuts" and handed the keyboard to a window that swallowed the rest of the
recording.

**One was real and is now fixed.** Advancing Totem's playlist while the subtitle
track is disabled kills its video output permanently. `dismiss_startup` turns
subtitles off in block 1, so every recording was poisoned from the start and died
at block 15 - the first block that advances. Totem's own `Shift+V` binding,
wrapped around each playlist change, fixes it.

**The pass count is not evidence.** Three of the broken recordings reported
22 PASS / 0 FAIL, because a reference screenshot of a dead player replays
perfectly against a dead player. Only the clip labels burnt into every frame
caught them.

| | mpv | totem | vlc | smplayer | parole |
|---|---|---|---|---|---|
| `install.sh` | yes | yes | yes | yes | yes |
| `usage_scenario.yml` | yes | yes | yes | yes | yes |
| `MEASUREMENTS.md` | yes | yes | yes | yes | yes |
| `driver.conf` | yes | yes | yes | yes | yes |
| `<app>.parrot` | **22/22** | **22/22** | **22/22** | **22/22** | **22/22** |
| replay | 22 PASS | 22 PASS | 22 PASS | 22 PASS | 22 PASS |
| GMT run | ok | ok | ok | ok | ok |

All five recordings are checked block by block against the clip name and
timecode burnt into every frame - the tables at the end of each entrant's
`MEASUREMENTS.md`.

**The corpus was rebuilt and every recording was redone against it.** A
re-encode changes every bitstream and with it every reference image, which is the
declared price of touching `make-corpus.sh` - and it was worth paying, because
the old corpus had no keyframe cadence at all and that was measuring x265's
default keyint as if it were HEVC's decode cost. See **The corpus** below.

**`PLAY_NEXT` is ten seconds for every entrant, and that is worth recording even
though the entrant that forced the question is gone.** Kaffeine used to override
it to 4, on a measurement that said it played the 60 fps clip at about 1.46x. Re-
measured from a clean launch it plays at **0.96x** - real time - and the original
figure had been taken while a previous instance was still holding the display. The
override had been making blocks 15 to 19 unequal work for that entrant, which is
exactly the kind of quiet incomparability this group exists to avoid. The hook
survives in `drive-scenario.sh` for an entrant that genuinely does not run at real
time; nothing uses it today.

No entrant here was a copy of another. Totem took eleven recordings to settle and
every one of the eleven was a defect the burnt-in labels caught: a stalled audio
clock, a non-deterministic playlist, two keyboard traps, a popover grab, a lost
click, and three different ways of failing to seek to the start of a clip.

```text
applications/videoplayers/
├── script.md                     the twenty-two blocks, and nothing else
├── README.md                     this file
├── make-corpus.sh                author-time: builds corpus/ from Big Buck Bunny
├── corpus/                       six clips, 38 MB, committed
├── common/
│   ├── install-common.sh         the shared half of every install.sh
│   ├── pin-windows.sh            deterministic window geometry, before fluxbox
│   ├── setup-container.sh        rebuild the container the way GMT would
│   ├── drive-scenario.sh         the twenty-two blocks, once, for every entrant
│   └── record-session.sh         rebuild, record, drive, report
└── <app>/
    ├── install.sh                pinned install + the /usr/local/bin/parrot-<app> launcher
    ├── usage_scenario.yml        the GMT entry point
    ├── driver.conf               this entrant's landmarks and actions
    ├── MEASUREMENTS.md           every landmark, and how it was measured
    ├── <app>-check-0NN.png       the reference screenshots
    └── <app>.parrot              the macro
```

One driver for all five, and per-entrant `driver.conf` files that supply the
actions - because the twenty-two blocks are the same user actions in the same
order while the way to perform each one differs in every entrant. The block
sequence lives in `common/drive-scenario.sh` once, so an entrant cannot quietly
do the blocks in a different order and a block cannot quietly go missing from one
recording.

## The entrants

Ubuntu 24.04 (noble) versions, because that is what `ribalba/xwindow-server` is.
Install counts are Debian popcon, gathered the same way as in
[../pdf_viewers/README.md](../pdf_viewers/README.md).

| Player | noble version | Toolkit | Playback engine | inst | vote |
|---|---|---|---|---|---|
| Totem (GNOME Videos) | 43.0-2ubuntu4 | GTK4 | GStreamer | 69285 | 11013 |
| VLC | 3.0.20-3build6 | Qt5 | libVLC (own) | 43633 | 143 |
| Parole | 4.18.1-1build2 | GTK3 | GStreamer | 24983 | 2212 |
| mpv | 0.37.0-1ubuntu4 | none - Lua OSC drawn into the video | libmpv | 21833 | 5891 |
| SMPlayer | 23.12.0+ds0-1build2 | Qt5 | mpv, spawned as a child process | 10329 | 1292 |
| ~~Kaffeine~~ | 2.0.18+git20230226 | Qt5 / KDE Frameworks | libVLC | 908 | 129 |
| ~~Celluloid~~ | 0.26-1build2 | GTK4 / libadwaita | libmpv, embedded | 867 | 263 |

The last two are struck through: they were **dropped**, for the reasons at the
top of this file. Their rows are kept because the engine coverage below is worth
reading with the gaps visible.

### Why these five

Three playback engines, and for two of them more than one front end:

* **libmpv** - bare `mpv`, plus SMPlayer, which drives mpv as a *separate
  process* rather than as a library. Celluloid would have been the third,
  embedding the library in GTK; **dropping it cost the group its
  library-embedded libmpv front end.**
* **libVLC** - VLC's own Qt interface. Kaffeine would have been a second, a KDE
  shell over the same library; **dropping it means libVLC now has only one front
  end, so that engine no longer has a front-end comparison at all.**
* **GStreamer** - Totem and Parole, one GTK4 and one GTK3, both on `playbin`.

That was the whole point of the group. The decode work in a block is fixed by the
clip, so where two entrants share an engine, the difference between them is the
cost of the *front end*: its toolkit, its compositing, its OSD, its idle loop.
Where they differ by engine, the difference is the decoder and the video output
path. Nothing else in the group varies - same X server, same window size, same
files, same blocks.

**With five entrants that comparison is weaker and it should be reported as
such.** GStreamer keeps a real front-end pair (Totem against Parole) and libmpv
keeps a library-versus-subprocess pair (mpv against SMPlayer), but libVLC is down
to a single data point. Conclusions of the form "this engine costs more than
that one" still hold; conclusions of the form "the Qt front end over libVLC costs
X" no longer have anything to compare against.

### Why not the others

Measured, not assumed - each of these was installed in the image and driven far
enough to find out.

* **Haruna** (`haruna`, 429 inst) - a Qt6/QML/Kirigami shell over libmpv. It runs
  cleanly and can do every block but one, and it was dropped only because three
  libmpv front ends already cover that engine. Dropping it is what let the
  aspect-ratio blocks into the script: its Video menu is Deinterlace / Zoom /
  Screenshot / Move / Adjustments, with no aspect item anywhere, and it was the
  last entrant standing in the way.
* **Dragon Player** (`dragonplayer`, 29984 inst) - the second most installed
  dedicated player in the table, and it still cannot take part. It has **no
  playlist at all**: given two files on the command line it plays the first and
  leaves Next and Previous greyed out, and it does the same with an `.m3u`. It
  also has no playback speed, no snapshot, and no way to jump to a position. Its
  whole menu is Play Media / Open Recent / Stop / Aspect Ratio / Subtitles /
  Audio Channels / Video Settings. Seven of the twenty-two blocks are impossible
  in it, and the file it was launched with is the only file it will ever play.
* **MPlayer's GUI** (`mplayer-gui`, `gmplayer`, 2416 inst) - does not start at
  all without a separate skin package (`mplayer-skin-blue`; the error is
  `Skin file /usr/share/mplayer/skins/default/skin not found`), and once it does
  it puts **three** top-level windows on screen - a skinned control panel, the
  video window and a warning dialog - which fluxbox places independently. The
  group pins one window per app.
* **xine-ui** (718 inst) - the xine engine would have been a fourth family, but
  it **crashes on startup** in this environment with the default audio driver
  (`*** buffer overflow detected ***`); it needs `-A null -V xshm` to come up at
  all, and then it also draws a floating panel window over the video window. Same
  two-window problem, on top of a player that has to be argued into starting.
* **Kodi**, **deepin-movie** - media centres, not file players; a different
  interaction model and a much larger dependency surface.
* **Firefox / Chromium** - browser video is a real workload but it is a different
  question, and the browser is already its own group.
* **audacious**, **gst123**, **ffplay** - audio-only, or no controls to drive.

If the MPlayer engine is wanted later, the cheap way in is a **second SMPlayer
entrant configured to use `mplayer` instead of `mpv`** - SMPlayer depends on both
and switches backend in Options. Same GUI, different engine, no skinned windows.

## The script

The twenty-two blocks are in [script.md](script.md), and that file contains
**nothing but the blocks**. `record-macro.py` passes it to
`load_checkpoint_notes`, which takes *every* non-blank line that does not begin
with `#` as the note for the next checkpoint, in order. A paragraph of
explanation in there is not ignored - it becomes checkpoint 2's note and every
block after it is labelled with the wrong text. So the reasoning lives here and
`script.md` stays machine-readable.

### Why the script looks the way it does

**The workload is decoding and drawing, so most of the script is clips, not
buttons.** Six clips differing in exactly one dimension at a time - codec, frame
rate, resolution - are worth more than any number of menu items, because that is
where the energy goes. The interaction blocks are there because they are what a
player *is*: seeking flushes and refills the decoder, subtitles add a text
renderer over every frame, an aspect override and fullscreen each change the
scaler's job, and paused-idle measures the floor, which is where front ends
differ most and where several of these players are known to keep working when
they have nothing to do.

**Every block ends on a still frame.** This is not stylistic. `check-image.sh`
compares a screenshot against the reference with `compare -metric RMSE` and a
default ceiling of `CHECK_MAX_RMSE=0.2`, and a running video never reaches a
stable state, so a checkpoint taken mid-playback is either flaky or meaningless.
Measured on the frames themselves:

| source | 1 frame apart | 0.5 s apart | 1 s apart | 5 s apart |
|---|---|---|---|---|
| `mandelbrot` | 0.124 | 0.209 | 0.235 | - |
| `gradients` | - | 0.130 | 0.433 | 0.137 |
| `testsrc2` | - | 0.135 | 0.124 | 0.140 |

Both failure modes are in that table. High-detail content trips the 0.2 ceiling
after a single frame of drift, so it can never be checkpointed while playing.
Flat synthetic content stays *under* the ceiling five seconds apart, so a check
against it would pass no matter where playback actually was - worse than no check.
Pausing removes the problem entirely: the same seek lands on the same frame, and
the burnt-in timecode in the corpus says which frame that is.

**And every block ends on a SEEK, not on a pause.** This is the same argument one
step further, and it was paid for: pausing stops the picture moving, but a block
shaped *resume, play ten seconds, pause* still ends wherever wall-clock timing and
the decoder's speed on the day left it. Four of the seven entrants failed their
first replay on exactly that shape, all of them marginally - 0.248 to 0.310
against the 0.2 ceiling, which is the signature of a few frames of drift rather
than of the wrong thing happening. mpv and VLC passed because their drift stayed
under the ceiling, which is luck and not a property anything designed.

So each of those blocks now ends by clicking the position bar at a mark, and the
captured frame becomes a property of the click instead of of the clock. Block 4
had always done this, and block 4 was the one block that replayed in all seven
entrants first time. Raising `CHECK_MAX_RMSE` would have turned the table green
and verified nothing.

Two things follow, and both are visible in the driver:

* **The marks are chosen off the corpus, not picked round.** The film cuts to
  black between about 3.5 s and 5.5 s into the fifteen-second clips, and the
  first attempt ended block 15 at 4.5 s - a black screen with two lines of white
  text on it, which every player renders identically. Consecutive marks also sit
  in different scenes, so that consecutive references do not look alike;
  `common/verify-app.sh` prints the RMSE between each pair to show it.
* **Those checkpoints no longer prove that playback happened.** A block whose
  resume was swallowed would seek to the same mark and pass. What still proves it
  is block 21, which can only be on clip 06 by having played off the end of clip
  05, and the `pactl list short sink-inputs` line at the end of every recording
  and every verification.

**Exact positions come from the position bar, not from key repeats.** The short-
jump step is 5 s in some of these players and 10 s in others, so "seek back ten
seconds" is not one action. The bar block clicks at a quarter, three quarters and
the midpoint - the same *position* in every entrant, and deterministic on replay
because the same pixel is clicked. The keyboard block keeps that path as its own
block and asks only for ten short jumps, whatever the player's step is; the cost
there is ten decoder flushes, which is comparable even when the distances are
not. It **alternates backwards and forwards** so that jumps of an unknown
size cannot walk off either end of the clip and trip the playlist. There are
eleven of them and not ten: five matched pairs come back to where they started,
and since block 2 now ends on a seek too, an even number would have left this
block capturing block 2's frame - and passing on a replay in which every one of
the jumps had gone nowhere.

**Volume, mute and audio-track blocks change something a screenshot cannot see.**
They are real user actions and they belong in the script, but their checkpoints
only prove the *chrome* changed - a slider position, a muted icon - and in mpv
even that is drawn by an OSC that auto-hides. Ground truth for those three should
come from MPRIS2: every one of the seven exports
`org.mpris.MediaPlayer2.Player`, and `Volume` is a readable property. That check
belongs in `drive-scenario.sh`, next to the landmark.

### What is deliberately not in the script, and why

Each of these was cut because at least one entrant cannot do it. Cutting the
block is right and dropping the entrant is wrong: seven players compared on
twenty-two things beats five players compared on twenty-four.

| Not in the script | Blocked by | Detail |
|---|---|---|
| Playback speed | Parole, Kaffeine | Neither has any speed control. Totem does (0.75/1.1/1.25/1.5/1.75), and so do the other four. |
| Snapshot / screenshot | Parole, Kaffeine | Not in Parole's menus at all. |
| Deinterlace | Totem, Parole | Present in VLC, mpv (`d`), SMPlayer and Kaffeine; absent from both GStreamer front ends. |
| Jump to an exact timestamp | mpv | Totem ("Skip To..."), Parole (Ctrl+G), Kaffeine (Ctrl+J), VLC and SMPlayer (Ctrl+J) all have a dialog. mpv has no UI for it - only the console. The bar block gets exact positions instead. |
| Opening a file from a file-chooser | mpv | mpv has no file dialog of any kind. Every entrant therefore gets its corpus on the **command line**, which is also the better measurement: it keeps GTK's and Qt's file choosers out of the numbers. |
| Resizing the window by dragging | the harness | `pin-windows.sh` / `freeze-window-size.py` fix the window geometry for the whole recording. Fullscreen is the scaling axis instead. |

Everything that *is* in the script was confirmed present in all seven, by opening
the menus of each one against a two-audio-track, two-subtitle-track file:

| Block | VLC | mpv | SMPlayer | Totem | Parole |
|---|---|---|---|---|---|
| playlist from the command line | menu | `>` | menu | skip button | skip button |
| pause / resume | Space | Space | Space | Space | Space |
| short-jump seek | arrows | arrows | arrows | arrows | arrows |
| click the position bar | yes | OSC | yes | yes | yes |
| volume / mute | menu | `9` `0` `m` | menu | yes | Audio menu |
| subtitle track + off | menu | `j` `v` | menu | menu | menu |
| audio track | menu | `#` | menu | menu | menu |
| aspect ratio 4:3 and back | menu | `Shift+A` | menu | menu | menu |
| fullscreen | `f` | `f` | `f` | `f` | F11 |

mpv has no aspect menu either, but `Shift+A` cycles `video-aspect-override` -
verified by driving it and watching the frame re-letterbox. The cycle is `16:9`
-> `4:3` -> `2.35:1` -> container, so 4:3 is two presses out and two presses
back; the other four pick 4:3 and Auto from a menu. Both are the same user action
and both are in scope.

## The corpus

Six clips in [corpus/](corpus/), 38 MB in total, all cut from the same seconds of
**Big Buck Bunny** (CC BY 3.0 - see [corpus/ATTRIBUTION.md](corpus/ATTRIBUTION.md))
by [make-corpus.sh](make-corpus.sh).

| File | Codec | Size | Rate | Length | Varies | Bytes | Keyframes |
|---|---|---|---|---|---|---|---|
| `01-h264-1440x900p30.mkv` | H.264 | 1440x900 | 30 | 50 s | baseline | 16 MB | 50 |
| `02-h264-1440x900p60.mkv` | H.264 | 1440x900 | 60 | 15 s | frame rate | 6 MB | 15 |
| `03-vp9-1440x900p30.mkv` | VP9 | 1440x900 | 30 | 15 s | decoder | 6 MB | 15 |
| `04-hevc-1440x900p30.mkv` | H.265 | 1440x900 | 30 | 15 s | decoder | 4 MB | 15 |
| `05-av1-1440x900p30.mkv` | AV1 | 1440x900 | 30 | 15 s | decoder | 5 MB | 15 |
| `06-h264-640x400p30.mkv` | H.264 | 640x400 | 30 | 15 s | scaling | 2 MB | 15 |

**One keyframe per second in every clip, and the same one in every codec.** That
column is load-bearing, not trivia. The first corpus set no GOP, so each encoder
used its own default and the clips came out with 2 to 5 keyframes each - the HEVC
clip had exactly two, at 0.00 s and 8.33 s, against VP9's four. A seek into HEVC
therefore made the decoder chew through up to 8.3 s of frames where the same seek
into the 60 fps H.264 clip cost at most 4.2 s of much cheaper ones, and this
scenario seeks more than twenty times. "HEVC costs more than VP9" was partly a
statement about x265's default keyint.

It broke the reference images too, which is how it was found. Seek while paused
to a position far from a keyframe and some players draw the target decoded
without its references - a flat grey field with blocks of garbage. Kaffeine does
it every time, and blocks 13 and 14 of its recording were two identical pictures
of exactly that. With the cadence above the same seeks render clean frames.

Each carries **two audio tracks** - AAC 2.0 `eng` and AAC 5.1 `ger`, a real
difference to switch between rather than the same stream twice - and **two SRT
subtitle tracks**, `eng` and `ger`, with a cue every five seconds that carries
its own start time.

**Exactly one audio track is flagged default and neither subtitle track is.** Both
halves were needed. ffmpeg carries the master's dispositions through, and the
master flags both of its audio tracks default, so without an explicit
`-disposition:a:1 0` the entrants were free to start on either one. Clearing the
subtitle flags is what makes every entrant start with subtitles off, so that
blocks 2 to 7 are not a text renderer's worth of work in some entrants and not in
others. Two entrants select the first subtitle track regardless - mpv, which
`--sid=no` fixes, and Totem, which has no equivalent option.

**Clip 01 is 50 s because five blocks play from it** - 2, 5, 8, 10 and 13. At
30 s it ran out during block 5, the playlist advanced on its own, and every block
after that was recorded against the wrong file while the checkpoint count, the
screenshot count and the warning count all stayed clean. The burnt-in clip labels
are what caught it.

**1440x900 is the screen, exactly.** Not 1440x810, which is where this started.
A 16:9 frame in a 16:10 window leaves a letterbox, and a letterbox means the
video's size and the window's size are two different numbers - which mpv resolves
by **resizing its own window to the video**. fluxbox applies a pin when a window
is mapped, so every later resize stands: with a 1440x810 corpus mpv's window went
to 1440x810, then to 640x360 on the small clip, with the pin still in force.
`auto-window-resize=no` did not stop it. Matching the corpus to the window did.

Getting 16:10 out of a 16:9 master means a centre crop - 1728x1080 of 1920x1080 -
which drops 10% of the width. Stretching instead would change every shape on
screen, and a benchmark that measures a scaler should not also measure a
distortion.

There is no 4K clip: it would have dominated the corpus size and it would have
measured a downscaler that only one clip exercised. Clip 06 covers the scaling
axis from the other side, going *up* 2.25x, for 1.3 MB.

**Every clip has its own name and a running timecode burnt into the frame.** The
content underneath is the same seconds of film in all six, so the codec axis is
not confounded by what is happening on screen - but that would make five codec
blocks produce identical-looking checkpoints, where a clip loaded out of order
would still pass. The burnt-in label is what keeps them distinguishable, and the
timecode is what makes a paused frame say which frame it is.

**Size was traded against duration, never against quality.** At CRF 26 these run
around 1.6 Mbit/s, which is what film content at this size really costs to
decode; lowering the quality to shrink the files would have quietly made every
entrant look better at exactly the thing being measured. The clips are short
instead. If 38 MB is still too much, shorten them further in `make-corpus.sh` and
shorten the play durations in `script.md` to match - do not raise the CRF.

**Big Buck Bunny "Sunflower", not the 2008 release.** It is the only official
encode that is natively **60 fps**, which is what makes clip 02 a real frame-rate
axis instead of duplicated frames, and it already ships two audio tracks. It is
also 634 s long, so there is plenty of footage to choose from; the corpus takes
the stretch at 300 s, which is dense forest canopy with camera motion and no
cuts.

## Audio

**Audio is in the measurement, and it is uniform because the image runs a
PulseAudio null sink**, set up by
[common/install-common.sh](common/install-common.sh).

Without a working device the container's missing sound card reaches the
entrants in several different ways: VLC probes PulseAudio, fails, tries
ALSA, fail, and print `main audio output error: no suitable audio output module`,
at which point they are not decoding audio at all; mpv fails differently; Totem
and Parole take a third path through `autoaudiosink`. Whether the second audio
track is even decoded stops being the same question in each entrant, and that
difference would sit inside the numbers.

**A null ALSA device looks like the answer and is not.** With
`pcm.!default { type null }` every entrant does open a device - mpv reports
`AO: [alsa]`, `speaker-test` succeeds - and mpv plays correctly. Totem does not.
It froze at `00:00:29.967` and stayed there for thirty seconds of observation.
Remove the file, change nothing else, and the same clip plays straight through:

```
null ALSA default          PulseAudio null sink
00:00:29.967               00:00:04.333
00:00:29.967    (frozen)   00:00:11.033
00:00:29.967               00:00:18.200
```

ALSA's null plugin discards samples without pacing them, and GStreamer slaves the
pipeline clock to the audio sink - so the clock stalls and the video stops with
it. The failure is silent, it looks exactly like a slow decoder, and it would
have been baked into the reference images of both GStreamer entrants. It cost
three wrong conclusions about Totem before it was found: that Totem does not
autoplay, that space advances its playlist, and that it cannot seek forward. All
three were the stall.

PulseAudio's null sink is a real sink with a real timer-based clock.
`pactl list short sink-inputs` then shows the player connected as
`float32le 2ch 48000Hz`, which is also **the only ground truth in this group that
audio is decoded at all**, since no screenshot can show it. `record-session.sh`
prints it at the end of every recording.

One caveat on that ground truth: the channel count does **not** tell you which
track is selected. Selecting the German 5.1 track in Totem left the sink-input at
`2ch`, because GStreamer downmixes to the sink's format. The player's own menu is
what says which track is playing.

The alternative - passing `--no-audio` to the players that accept it - was
rejected: VLC, mpv, SMPlayer and Celluloid take such a flag, but Totem, Parole
and Kaffeine have no equivalent, so it would silence four entrants and not the
other three. That is the harness introducing a difference in exactly the layer
the benchmark is comparing.

What is still not measured honestly is the *sound server* path, because there
isn't a real one. The null sink accepts and discards; what the entrants share is
the decode, the resample and the write, not a mixer driving hardware.

## Environment findings, all paid for during this survey

* **AV1 needs `gstreamer1.0-plugins-bad`.** Without it Totem fails the AV1 clip
  outright - `Missing plugin: gstreamer|1.0|totem|AV1 decoder` - while VLC and
  both mpv-based entrants play it, because those carry their own dav1d. With the
  package installed, Totem and Parole both play AV1 fine. It is not a recommended
  dependency of either, so `common/install-common.sh` names it. HEVC and VP9 work
  without it.
* **Video output is a confounder and has to be recorded.** Under Xvfb there is no
  XVideo and no hardware GL, and the entrants do not fall back to the same place.
  mpv lands on its **`sdl`** VO and says so - `Warning: this legacy VO has bad
  performance` - and forcing `--vo=x11` adds `Shared memory not supported`. That
  is a large part of what the numbers would be measuring, so `MEASUREMENTS.md`
  has to record what each entrant actually resolved to, per entrant, before any
  of them is compared with another.
* **VLC refuses to run as root.** It needs its own user, as
  `applications/vlc/docker-compose-vlc.yml` already does, and `--vout xcb_x11`
  under Xvfb.
* **The corpus strips the master's metadata** (`-map_metadata -1`). Before that,
  Totem's window title read `Blender Foundation 2008, Janus Bager Kristensen
  2013 - 01-h264-1440x900p30`, because players prefer container metadata to the
  filename. Window titles are what `APP_WINDOW_TITLE` and `check-image.sh` match
  on, so the clips carry only a title that is their own name.
* SMPlayer resolves to **mpv** as its backend on noble (verified: it spawns
  `mpv`), not mplayer.
* **Entrants disagree about whether a playlist plays on its own.** mpv starts
  playing immediately; Totem loads clip 01 and stops on its first frame,
  indefinitely. Block 1 therefore cannot assume playback has begun, and each
  entrant's launcher or driver has to bring it to the same state before block 2.
* **A keystroke can do something other than nothing.** Space over Totem's video
  advanced the playlist, because GTK gave the focus to a transport button and
  space activated it. AGENTS.md warns that a misdirected action is usually a
  silent no-op; this one was a plausible-looking wrong action instead, and only
  the burnt-in clip label showed it.
* **The recorder's own startup is playback time.** `record-session.sh` waits 12 s
  for xmacrorec2 to arm and the driver waits again for the first frame, and the
  clip plays throughout. The first mpv recording paused block 1 at 22.9 s into
  the clip. Block 1 now ends by seeking back to the start with the entrant's own
  position bar, so every recording in the group begins on the same frame.
