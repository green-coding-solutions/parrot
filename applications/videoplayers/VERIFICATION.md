# Replay verification

The group is **five entrants**: mpv, VLC, SMPlayer, Parole and Totem. Celluloid
and Kaffeine were dropped - see their sections below.

`common/verify-app.sh <app>` rebuilds a fresh container from the entrant's own
`usage_scenario.yml`, replays its `.parrot`, and reports the checkpoint results,
the worst RMSE values, identical consecutive references, the RMSE *between*
consecutive references, and whether the player was connected to the audio sink.

## THE PASS COUNT IS NOT EVIDENCE. THE BURNT-IN LABELS ARE.

This is the most important thing on this page, and it was learned the hard way.

Three of the seven recordings in one sweep were visibly, badly broken - and this
is what `verify-app.sh` said about them:

| entrant | what the recording actually was | what the replay reported |
|---|---|---|
| totem | blocks 15-22 one frozen dead frame | **22 PASS / 0 FAIL** |
| kaffeine | 13/14 grey garbage, 19 reads "Stopped", 20-22 black | **22 PASS / 0 FAIL** |
| celluloid | twelve blocks a black video area | 20 PASS / 1 FAIL |

The references and the captures agree because **both are equally dead**. A
reference screenshot of a frozen player replays perfectly against a frozen
player. The pass count cannot tell a working block from a corpse.

The identical-consecutive-reference check does not catch it either, and it is
worth knowing why: ten black Celluloid frames are not byte-identical, because
each carries a different seek-bar position in the control bar. They differ by
just enough to slip through a test looking for exact matches.

**Only reading the clip name and timecode burnt into every reference caught any
of it.** Do that after every recording, block by block, against `script.md`.
"22 checkpoints, 22 screenshots, 22 PASS" is not evidence that anything played.

## Three "upstream defects" were reinvestigated, and two of them were ours

This file previously said that Totem, Celluloid and Kaffeine were each blocked by
a defect in the entrant. Three defects in one group of seven widely-shipped
players is not a plausible reading, and it did not survive being checked.

| was called | actually was |
|---|---|
| Kaffeine plays the 60 fps clip at 1.46x | it plays at **0.96x** - the measurement was taken against a stale instance |
| Kaffeine's `f` does not leave fullscreen | **it does**; its Playback menu binds F to Full Screen Mode, a toggle |
| Kaffeine's blocks 13/14 are grey | **the corpus**: paused seeks far from a keyframe |
| Totem loses its video output after a subtitle change plus a fullscreen cycle | **a click landing on "Keyboard Shortcuts"**, which opens a window that takes the keyboard |

Each is written up below with what was measured.

## The corpus had no keyframe cadence, and that was two bugs at once

`make-corpus.sh` set no GOP, so every encoder used its own default:

| clip | keyframes | mean gap | now |
|---|---|---|---|
| 02 h264 60p | 5 | 3.00 s | 15 |
| 03 vp9 | 4 | 3.76 s | 15 |
| 05 av1 | 3 | 5.01 s | 15 |
| **04 hevc** | **2** | **7.51 s** | 15 |
| 01 h264 30p (50 s) | 13 | 3.85 s | 50 |
| 06 h264 SD | 4 | 3.76 s | 15 |

The HEVC clip had keyframes at 0.00 s and 8.33 s and nothing else.

**It is a fairness bug.** A seek into that clip made the decoder work through up
to 8.3 s of frames where the same seek into the 60 fps H.264 clip cost at most
4.2 s of much cheaper ones. This scenario seeks more than twenty times, so part
of "HEVC costs more than VP9" was a statement about x265's default keyint - a
confound sitting directly on the axis the group exists to measure.

**It is also what broke the reference images**, which is how it was found. Seek
while PAUSED to a position far from a keyframe and some players draw the target
frame decoded without its references: a flat grey field with scattered blocks of
garbage. Kaffeine does it every time. Re-encoding one clip at a one-second
cadence and changing nothing else, the same seek sequence came back clean and
both forward steps landed - measured before the corpus was rebuilt.

The cadence is now forced with `-force_key_frames` - the one spelling all four
encoders honour identically - plus per-encoder scene-cut suppression, and
`make-corpus.sh` **asserts the result** after encoding. A silently-ignored
`-x265-params` would put the group straight back where it started and nothing
downstream would say so.

## Totem: the video output was never dead

The old reproduction was "change the subtitle track, cycle fullscreen, advance
the playlist". Run directly, that sequence works - video drawing throughout, two
playlist advances, clips 02, 03 and 04 all rendering. It does not reproduce.

What actually happened is this. `do_aspect_43` clicked a measured coordinate for
the aspect submenu's "4:3 (TV)" row. **The submenu's rows are not at a fixed
place** - the same row was captured at y=126 in one run and y=167 in another,
because the popover is sized and positioned per opening. And the coordinate it
used is, in the parent menu, **"Keyboard Shortcuts"**. So a run where the submenu
did not open clicked that instead:

    visible totem windows: [01-h264-1440x900p30] [Videos]
    focused: Videos

A second top-level window opens and takes the keyboard. Every key after that is
typed into its search box - `p`, `n`, `f`, the arrows - while the player runs on
alone, reaches the end of its clip and advances. From outside that looks exactly
like "the picture froze while the title bar kept moving". Six `p` presses later
the shortcuts window was standing there with `pppppp` in its search field and
"No Results Found" underneath it.

### The fix: Tab, not coordinates

Both popovers are now driven by Tab, which moves focus one row from a known
start, so a step that does not land leaves the selection short rather than
somewhere destructive. Measured directly:

| Tab | languages popover | | Tab | aspect submenu |
|---|---|---|---|---|
| 0 | English audio (initial focus) | | 1 | Auto |
| 1 | German audio | | 2 | Square |
| 2 | Subtitles None | | 3 | 4:3 (TV) |
| 3 | Subtitles English | | 4 | 16:9 |
| 4 | Subtitles German | | 5 | 2.11:1 |
| 5 | *Select Text Subtitles...* - opens a file chooser | | | |

The outer "Aspect Ratio" row is still a **click**, deliberately: the parent
menu's rows do not move, and a click there that misses opens nothing. It is only
the inner rows that shift. `Down` then `Return` was tried for the outer row and
is worse - the popover sometimes opens with focus already on that row and
sometimes above it, so `Down` lands on the row in one case and on Preferences in
the other.

What that bought, measured on the same blocks 8-16 that used to fail:

| block | before | after |
|---|---|---|
| 9 subtitles off | stuck at 17.500, seek lost | **07.500**, correct |
| 12 aspect back | still letterboxed | **full width**, correct |
| 13 fullscreen | captured windowed - fullscreen never happened | **fullscreen**, at exactly 00:00:30.000 |

Blocks 8 to 14 are now all correct.

### The second Totem defect: a playlist advance with subtitles OFF

Fixing the popovers exposed a second, unrelated failure, and this one IS Totem's.

**Advancing the playlist while the subtitle track is disabled kills Totem's video
output permanently.** Minimal reproduction, three steps from a fresh container:

1. open the six-clip playlist
2. Subtitles -> None
3. press `n`

The title bar advances, audio keeps playing, and nothing in the window is ever
repainted again - not the video, not the control bar. The GTK main loop is still
alive: `n` keeps moving the playlist on and the title keeps changing. Nothing
recovers it. Measured: seek, play/pause, a fullscreen cycle, moving the window,
resizing it, and minimise-plus-restore all leave it dead.

It was bisected by running each candidate action alone before one advance and
asking only whether the picture still moved:

| before the advance | repaint |
|---|---|
| nothing | 0.403 alive |
| audio track changed | 0.380 alive |
| aspect changed there and back | 0.375 alive |
| **subtitles set to None** | **0 DEAD** |
| None, then switched back on | 0.290 alive |

So it is not the menu, not the route, and **not fullscreen**. An earlier version
of this file blamed "a subtitle change and a fullscreen cycle"; the subtitle half
was right and the fullscreen half was never needed. It also explains why every
recording died at block 15 and not before: `dismiss_startup` turns subtitles off
in block 1, so the player is poisoned from the start, and block 15 is simply the
first block that advances the playlist.

**The fix** is Totem's own `Shift+V` "Toggle subtitles" binding wrapped around
every playlist change - two keystrokes and about three seconds, against four menu
clicks and twelve seconds through the popover. Both were measured over three
consecutive advances; both work, and the cheap one was kept. Block 21's advance
happens on its own inside a sleep, so it is guarded through two hooks in
`drive-scenario.sh` that default to doing nothing for every other entrant.

The cost is real and belongs in the numbers: blocks 15 to 19 cost this entrant
two extra keystrokes each that no other entrant pays.

**Result: Totem records and replays all 22 blocks - 22 PASS / 0 FAIL, worst RMSE
0.084**, with every clip label read against the scenario.

## Celluloid: an intermittent black GL surface - DROPPED FROM THE GROUP

**This entrant was removed.** What follows is why, kept so the next person does
not have to rediscover it.

Not a capture problem, which is what it looked like. Captured the ROOT window and
the WINDOW DRAWABLE at the same instant, repeatedly: they agree exactly - 0.329
against 0.329 when it renders, 0 against 0 when it does not. The pixels really
are black.

What it is: the GL surface goes black, and **every reconfigure re-rolls the
dice**. Measured both directions -

* in a recording it launched black and the aspect toggle in block 11 FIXED it
* in a diagnostic it launched fine and the same aspect toggle BROKE it
* hammering the aspect cycle: 1 black in 12 toggles

Once black, nothing short of another reconfigure recovers it. Measured: seek,
play/pause and a fullscreen cycle all leave it black; one more `shift+a` restores
it. `GSK_RENDERER=cairo` does not help (2 in 12, no better than baseline).

The frustrating part is that it does not reproduce in isolation: **six launches
out of six rendered** when launched and screenshotted directly, while **both
recordings launched black**. Whatever block 1 does - it pauses, then seeks to the
start - is the untested difference and is where to look next.

Two recordings, both half black: blocks 1-10 and 19-20 in the first, blocks 1-11
and 20 in the second. Both replayed at 20/1 and 18/1, because black references
match black captures.

## Kaffeine: paused seeks are dropped - DROPPED FROM THE GROUP

**This entrant was removed.** What follows is why, kept so the next person does
not have to rediscover it.

Deterministic, not intermittent - two recordings failed identically.

**Blocks 13 and 14 capture a grey partially-decoded frame.** The cause is now
narrowed to the FORWARD seeks specifically, and only while paused in fullscreen:

    5 backward seeks, 1.5 s apart, paused, fullscreen   clean picture
    + 2 forward seeks                                   GREY

A backward seek clears it again, and so does a 1.5 s resume - so the decoder
recovers, it simply will not render a forward paused seek. The one-second
keyframe cadence fixed this in a WINDOWED test and did not fix it in fullscreen.

**The deeper problem is that Kaffeine's paused seeks are not deterministic at
all.** Three forward seeks three seconds apart left the position reading
00:00:39.333 for all three captures - the presses are coalesced and applied in
bursts. `seek_abs_keys` cannot produce a fixed position in this entrant, which is
what block 13 needs.

That drift is what kills the run: block 15 captured 00:00:09.933 where its mark
is 3.0, block 17 captured 09.167 where its mark is 2.25, and by block 19 the
playlist has run out and the reference reads **"Stopped"**. Blocks 20 to 22 are
black.

Its bar clicks are NOT the problem - measured directly after a fullscreen cycle,
a bar click landed and a second click on the same spot was idempotent.

A deterministic route exists and was not taken: Kaffeine's Playback menu offers
**Jump to Position (Ctrl+J)**, a dialog that takes an exact timestamp. It would
make block 13 exact, at the cost of that block no longer being "the player's own
seek keys" as `script.md` describes it - which is a decision about the group, not
a driving problem.

## What passes is worth stating too

* SMPlayer's replay matched **every** reference exactly - worst RMSE 0.
* Parole went from failing block 1 outright to a clean 22, after its menus were
  moved to the keyboard and its subtitles turned off through xfconf rather than
  through a hover-dependent submenu. Kaffeine's menus went the same way, and now
  Totem's have too - three of the seven needed the same answer, which is worth
  noticing: **coordinates into a menu are the fragile part of driving a GUI, and
  relative keyboard navigation is the robust one.**
* The audio ground truth works: after mpv's replay the sink-input reads
  `float32le 6ch 48000Hz`, the German 5.1 track. No screenshot can show that
  block 10 did what it claims.
* The channel count is **not** comparable across entrants. mpv sends 6ch; the
  GStreamer and Qt front ends negotiate stereo with the null sink and report
  `2ch` whichever track is selected, so for those it says only that audio was
  flowing.

## Design notes that still hold

### Every play block ends on a seek

Ten blocks used to have the shape *resume, play N seconds, pause*, and where that
pause lands is decided by the wall clock and the decoder's speed on the day. Each
now ends on a **seek to a fixed mark**, so the frame is a property of the click
rather than of the clock.

**Those checkpoints no longer prove that playback happened.** A block whose
resume was swallowed seeks to the same mark and passes. What still proves
playback is block 21, which can only be on clip 06 by having played off the end
of clip 05, and the sink-input line at the end of every run. It is also why the
clip name and timecode burnt into every reference are read block by block after
each recording: "22 checkpoints, 22 screenshots" is not evidence, the labels are.

### The marks are chosen off the corpus

The film cuts to black between about 3.5 s and 5.5 s into the fifteen-second
clips, and the first attempt ended block 15 at 4.5 s - a black screen with two
lines of white text, which every player renders identically. Consecutive marks
also sit in different scenes so that consecutive references do not look alike.

### Two blocks still cannot fail, and one of them is fixable

`verify-app.sh` prints the RMSE between each pair of consecutive references. Two
references that differ by less than the ceiling accept each other's captures, so
the second block cannot fail.

The by-design low pairs are 5-6 and 6-7 (volume and mute change no pixel of the
video) and 21-22 (the idle block is defined as changing nothing).

**The aspect pair is still low: 10-11 and 11-12 at 0.1928 in mpv**, just under
the 0.2 ceiling, so blocks 11 and 12 cannot really fail. The cause is now clear
and it is the one place the design is not applied consistently: **blocks 11 and
12 are the only blocks that do not end on a seek.** Block 10 leaves the position
at 0.55 and neither aspect block moves it, so all three are the same frame of the
same clip differing only by the pillarbox. Giving 11 and 12 closing marks of
their own, exactly as every other block has, would separate them.

That was NOT done in this pass, deliberately. `script.md` and
`drive-scenario.sh` are read incrementally by a recording that is already
running, and changing the script would invalidate the recordings already made. It
is a one-line change for the next re-record, not a change to make during one.

**Block 13-14 is byte-identical in mpv** (RMSE 0), which is new and is a property
of the entrant rather than of the script: mpv has no window decorations and its
window is already exactly 1440x900, so leaving fullscreen changes no pixel. Block
14 therefore cannot fail in mpv. It can in every entrant that draws chrome.
