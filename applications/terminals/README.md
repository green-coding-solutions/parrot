# Benchmarking terminal emulators

Nine terminal emulators driven through the same sixteen-block session against the
same committed corpus. Nothing is downloaded at measurement time, so a recording
made today replays identically next year and on another machine.

**Status: all nine recorded against the settled 16-block script — 16 checkpoints
and ground truth `RESULT PASS` each. Replay verification, per-app
`MEASUREMENTS.md`, time-normalized variants and GMT runs are still to do.**

## The script

The sixteen blocks are in [script.md](script.md), and that file contains
**nothing but the blocks**. `record-macro.py` passes it to
`load_checkpoint_notes`, which takes *every* non-blank line that does not begin
with `#` as the note for the next checkpoint, in order. A paragraph of
explanation in there is not ignored — it becomes checkpoint 2's note, and every
block after it is labelled with the wrong text. So the reasoning lives here
instead, and `script.md` stays machine-readable.

### Why the script looks the way it does

**Everything that runs *inside* the terminal is identical by construction.** The
same `bash`, the same `less`, the same `ls`, the same bytes from the same
committed corpus. What differs between the entrants is only what a terminal
emulator actually is: how fast it turns that byte stream into pixels, and how it
handles keystrokes and the mouse. That is why so much of the script is "run a
command and wait for it to draw" — for this group that *is* the workload, where
for the spreadsheet group it would have been a cop-out.

The ten content blocks are ten different things to render, chosen because
emulators are known to differ on them: plain ASCII throughput, SGR attributes,
indexed colour, direct colour, multi-byte and double-width glyphs, box-drawing
glyphs, in-place cursor addressing against scrolling, line wrapping, raw scroll
rate, and colour interleaved with a real program's output. The pager blocks add
the alternate screen.

**Nothing in the corpus blinks, and nothing is timed.** SGR 5 (blink) is
deliberately absent: a blinking cell changes the screen between the capture and
the replay and would fail every checkpoint after it. `generate_corpus.py --check`
asserts its absence. For the same reason the corpus carries no clock, no
hostname, no path that varies and no progress bar driven by elapsed time —
`redraw.sh` counts iterations, not seconds.

**No colour emoji.** Emoji are the one Unicode class the entrants genuinely do
not agree on — several have no colour glyph support at all, and the ones that do
disagree about the cell width. The Unicode block stays with scripts every
entrant can draw, and deliberately does include double-width CJK and combining
marks, because that is where emulators differ even when every glyph is present.

**No emulator keybindings at all.** Tabs, splits, font resizing and copy/paste
are each missing from at least one entrant or bound to a different key in every
one — and, as it turned out, so is scrolling the scrollback. The script now uses
no emulator keybinding whatsoever. Every key it presses goes to a program running
*inside* the terminal: `less`'s Page Down and its search, and the shell's Return.
The search in block 13 is `less`'s search, not the emulator's, so it is the same
program in every run.

**The mouse selection is checkable.** Block 14 leaves its text in the X PRIMARY
selection, which `xclip -o -selection primary` reads back — so the one block
that is pure UI is not verified by its screenshot alone.

**One driver, not nine.** All sixteen blocks are literally the same keystrokes
and the same corpus commands in every entrant — that is the point of the group,
since anything that differed would be measuring the difference rather than the
emulator. So the sequence lives once in `common/drive-scenario.sh` and each app
contributes only a `driver.conf`: its window class, its measured size, and how
long it takes to show a prompt. This is the opposite of the spreadsheet group,
where every application buried its commands in a different menu and the drivers
had almost nothing in common.

**Wait on the log line, not on the screen.** The obvious way to tell a block has
finished is to wait until the window stops changing. It does not work here, and
the reason is the corpus itself: the content repeats, so a *still-scrolling*
window can read as settled. Measured, it reported block 2 finished after 1.0 s
when the block takes 2.0 s, and the screenshot taken on that signal was a
half-drawn screen with no prompt on it. Every corpus script appends its line to
the session log as it finishes; that is deterministic and the screen is not.

The driver still uses a *fixed* sleep rather than polling the log, because a
dynamic wait is not an input event and so is never recorded — the macro keeps
only the delay that actually elapsed. The log check runs afterwards as a safety
net, printing a warning at record time if the margin was ever too thin. It has
already earned its keep by catching a mistyped block name in the driver.

**Block 16 is the ground truth.** Each command block appends one line to
`/tmp/parrot-term.log` as it completes, and `verify.sh` re-reads that log and
the selection and prints a pass or fail per block. A terminal emulator writes no
document, so without this the only evidence a block did anything would be a
screenshot — and a screenshot of a terminal whose output has scrolled past looks
exactly like a screenshot of a terminal that printed nothing.

### How big each block had to be, and why that is not a detail

The first corpus could not have told the entrants apart. Timed inside
xterm, one pass of each block cost:

| plain (5,000 lines) | attributes | colours‑256 | colours‑true | unicode |
| --- | --- | --- | --- | --- |
| 13 ms | 3 ms | 183 ms | 172 ms | 3 ms |

| boxes | **redraw (200×20)** | longlines | seq (200,000) | ls‑tree (1,000 files) |
| --- | --- | --- | --- | --- |
| 3 ms | **4,596 ms** | 6 ms | 151 ms | 7 ms |

Nine blocks together came to about half a second, and one block was 90% of the
session. Almost the entire run was idle, and anything that distinguishes one
emulator from another would have been lost in the measurement noise.

The reason `cat`-ing 5,000 lines costs 13 ms is the whole design constraint
here: **an emulator does not have to paint a frame it can prove is about to be
overwritten**, so a fast scroll is optimised away almost entirely. Only
`redraw.sh`, which addresses the cursor and repaints in place, forces every
frame to be drawn — which is exactly why it was three orders of magnitude more
expensive than everything else.

So each block now repeats its content, by a count tuned from its measured cost,
until it takes about a second and a half. Measured again after tuning:

| block | 1 pass | repeats | scaled |
| --- | --- | --- | --- |
| plain | 13 ms | ×135 | 1,501 ms |
| attributes | 3 ms | ×30,000 | 1,414 ms |
| colours‑256 | 183 ms | ×100 | 1,429 ms |
| colours‑true | 172 ms | ×9 | 1,467 ms |
| unicode | 3 ms | ×1,000 | 1,428 ms |
| boxes | 3 ms | ×1,050 | 1,472 ms |
| redraw | 4,596 ms | ×65 ⟵ *down* | 1,407 ms |
| longlines | 6 ms | ×375 | 1,471 ms |
| seq | 151 ms | to 2,000,000 | 1,487 ms |
| ls‑tree | 7 ms | ×325 | 1,480 ms |

1,407–1,501 ms across all ten, 14.6 s of work in total. `redraw`'s count went
*down*, for the same reason the others went up.

Two things about the mechanism. **Repetition, not bigger files** — the committed
corpus stays at 505 KiB instead of growing to tens of megabytes, and the bytes
are identical on every pass. And the repeat counts had to be tuned from the
*scaled* measurement rather than extrapolated from one pass: `attributes` came
back six times light on the first attempt, because bash's `printf` builtin is far
cheaper per line than one pass suggested once the emulator stopped being the
bottleneck. `generate_corpus.py --check` now asserts that every block carries its
repeat count into the script it generates, and that each still logs itself
exactly once — a block that quietly reverts to one pass contributes nothing to
the comparison and *nothing else about the run looks wrong*.

## The candidates

Every one of these was installed into the container image and launched under
Xvfb + fluxbox before it went on the list. Nothing here is aspirational.

| Emulator | Version | Toolkit / rendering | Why it is in |
| --- | --- | --- | --- |
| [xterm](https://invisible-island.net/xterm/) | 390-1ubuntu3 | none — raw Xlib | the reference implementation everything else is measured against |
| [rxvt-unicode](https://software.schmorp.de/pkg/rxvt-unicode.html) | 9.31-3build2 | none — raw Xlib | the classic lightweight alternative, still the daemon-mode benchmark |
| [GNOME Terminal](https://gitlab.gnome.org/GNOME/gnome-terminal) | 3.52.0-1ubuntu2 | VTE / GTK 3 | by a distance the most-used Linux terminal; stands for the whole VTE family |
| [Konsole](https://konsole.kde.org/) | 4:23.08.5-0ubuntu4 | Qt 5 / KDE | the other desktop-default, and the only Qt entrant |
| [Alacritty](https://alacritty.org/) | 0.13.2-1ubuntu1 | OpenGL, Rust | GPU rendering, deliberately minimal feature set |
| [kitty](https://sw.kovidgoyal.net/kitty/) | 0.32.2-1ubuntu0.4 | OpenGL, C/Python | GPU rendering, deliberately maximal feature set |
| [st](https://st.suckless.org/) | 0.9-1 (`stterm`) | none — raw Xlib | suckless minimalism; ~2k lines against xterm's ~65k |
| [mlterm](https://mlterm.sourceforge.net/) | 3.9.3-1build2 | own renderer over Xft | a wholly independent implementation — not VTE, not an xterm fork; built around multilingual text, which the Unicode block exercises hard |
| [pterm](https://www.chiark.greenend.org.uk/~sgtatham/putty/) | 0.81-1 | GTK 3, PuTTY's own terminal core | the only entrant whose escape-sequence handling grew up largely outside the Unix lineage — PuTTY's core, ported to X11 |

Nine, spanning four rendering paths — raw Xlib, an independent codebase, a widget
toolkit, and the GPU — with more than one entrant in each so a difference can be
attributed to the architecture rather than to one project's choices.

Both later additions needed a fix that no amount of reading would have found, and
both are the kind that produce a *plausible* recording rather than an obvious
failure:

- **mlterm's `fontsize` is in pixels, not points.** At 11 — the number every
  other entrant is configured with — it came up with a 205×68 grid against
  xterm's 159×47, so it would have been rendering a completely different amount
  of text per screen. At 15 it lands on 159 columns, the same as xterm.
- **pterm was running the wrong shell.** It starts the shell named in
  `/etc/passwd`, which is dash in this image, so it came up as `-sh` with the
  working directory at `/`: `/root/.bashrc` never ran, the prompt was not
  `parrot$ `, and `corpus/boxes.sh` was not found. That breaks the premise the
  whole group rests on — every entrant running the *same* bash, less and corpus —
  so it is launched with `-e /bin/bash -l`.

### Probed and available, but not in the group

All of these install and start cleanly in the container; they are left out
because they would add a fourth and fifth VTE entrant rather than a new
architecture. They are listed because adding one back is a one-file job:

| | |
| --- | --- |
| Xfce Terminal 1.1.3, MATE Terminal 1.26.1, LXTerminal 0.4.0, sakura 3.8.7 | VTE, like GNOME Terminal |
| Terminator 2.1.3, Tilix 1.9.6 | VTE with tiling on top; Tilix also opens a second transient window |
| QTerminal 1.4.0 | Qt, like Konsole |
| zutty 0.14.8 | OpenGL ES — architecturally interesting, but **bitmap fonts only**, so it cannot render the same font as the other entrants and the comparison would not be like-for-like |
| cool-retro-term 1.2.0 | animated shader effects — the screen changes continuously, so it cannot be replay-verified at all |

Not packaged for 24.04 and therefore not considered without an upstream pin:
**WezTerm**, **Ghostty**, **Contour**, **foot** (Wayland-only, and this harness
is X11).

## The capability probe

Two questions decide both the app list and the script, and both were answered
empirically rather than from documentation — because **both of my expectations
turned out to be wrong**:

| | expected | measured |
| --- | --- | --- |
| rxvt-unicode 24-bit colour | absent | **present** — Ubuntu's 9.31 renders `#119955` exactly |

Had that been taken on trust, the true-colour block would have been narrowed for
no reason. The probe, re-run against a live window in the container:

| | starts | `WM_CLASS` (res_name, res_class) | steady screen | truecolour | scrolls on Shift+PageUp ³ | on the wheel ³ |
| --- | --- | --- | --- | --- | --- | --- |
| xterm | ✅ | `xterm`, `XTerm` | ✅ | ✅ | ✅ | ✅ |
| rxvt-unicode | ✅ | `urxvt`, `URxvt` | ✅ | ✅ | ❌ | ❌ |
| GNOME Terminal | ✅ ¹ | `gnome-terminal-server`, `Gnome-terminal` | ✅ | ✅ | ✅ | ✅ |
| Konsole | ✅ | `konsole`, `konsole` | ✅ | ✅ | ⚠ no return | ⚠ no return |
| Alacritty | ✅ ⁴ | `Alacritty`, `Alacritty` | ✅ | ✅ | ❌ | ✅ |
| kitty | ✅ | `kitty`, `kitty` | ❌ → ✅ ² | ✅ | ❌ | ✅ |
| st | ✅ | `st-256color`, `st-256color` | ✅ | ✅ | ❌ | ❌ |
| mlterm | ✅ | `xterm`, `mlterm` ⚠ | ✅ | ✅ | not tested ⁵ | not tested ⁵ |
| pterm | ✅ ³ | `pterm`, `Pterm` | ✅ | ✅ | not tested ⁵ | not tested ⁵ |

¹ needs a UTF-8 locale **and** a session bus. Without the locale it refuses to
start at all — `Non UTF-8 locale (ANSI_X3.4-1968) is not supported!` — and the
container image has none, so `install.sh` must `locale-gen`. Note also that the
window belongs to `gnome-terminal-server`, not to `gnome-terminal`.

² **kitty's cursor blinks by default**, which is fatal here: two screenshots of
an idle window 1.5 s apart are not identical, so every checkpoint after the
first would fail on replay. `cursor_blink_interval 0` in `kitty.conf` fixes it,
confirmed by re-running the same test. Every other entrant is steady out of the
box.

³ **These two columns are why the script has sixteen blocks and not eighteen —
and the first version of this table got them wrong.** It claimed all seven
scrolled on Shift+Page Up. See below.

⁵ mlterm and pterm joined after the scrollback blocks had already been removed,
so there was no longer any reason to test a scrollback gesture on them. Their
`WM_CLASS` and steady-screen results were measured the same way as the rest.
mlterm's res_name really is `xterm`, which is what fluxbox pins on.

⁴ Alacritty needs `libxkbcommon-x11-0`, which `--no-install-recommends` drops.
Without it the process panics with `Library libxkbcommon-x11.so could not be
loaded` and exits before mapping a window, so the symptom is simply that no
window ever appears — indistinguishable from a slow start. The first probe
recorded it as starting fine.

### There is no scrollback gesture the entrants share

The script used to open with *print a file → scroll back → scroll to the end*.
It could not survive contact with the entrants, and finding that out took two
bad recordings.

**Shift+Page Up scrolls in 2 of 7. The mouse wheel scrolls in 4 of 7.** Neither
is a majority, let alone universal, and no other candidate did better. So both
scrollback blocks were removed rather than given a per-app keybinding: a block
driven by a different gesture in each application compares the gestures, not the
emulators.

The failure mode in st is the one worth remembering, because it is silent and it
corrupts the *next* block rather than its own. Shift+Page Up is not a binding
there at all — the key is passed through to the application as `ESC[5;2~`,
readline swallows the `ESC[`, and `2~` is left sitting on the command line.
Twenty presses left this on the prompt:

    parrot$ 2~2~2~2~2~2~2~2~2~2~2~2~2~2~2~2~2~2~2~2~

The next block's command was typed onto the end of that, so it never ran. The
recording still produced a full set of checkpoints and reference screenshots and
looked entirely normal; only the session log showed anything was wrong. Konsole
has a subtler version — it scrolls, but the down key does not return to the same
screen, so every following block starts from an unknown position.

**How the original probe got it wrong**, because the mistake is easy to repeat:
it hashed the *whole window*. A key that types junk onto the prompt line changes
that hash exactly like a key that scrolls. `common/probe-scrollkeys.sh` hashes
only the content region above the prompt, and relaunches the emulator between
candidates — without a reset, every candidate after the first successful scroll
also differs from the baseline and looks like it worked.

One consequence worth stating plainly: **the script now uses no emulator
keybinding at all.** Every key it presses goes to a program running inside the
terminal. That is a stronger guarantee of like-for-like than the original design
had, and it came out of a failure rather than foresight.

### The locale is set twice, on purpose

An emulator decides whether it is a UTF‑8 terminal from **its own environment at
startup** — before the shell inside it exists, so a `LANG` in `/root/.bashrc`
comes far too late to help. Launched without it, xterm draws `â` where `│`
belongs and turns the box‑drawing, Unicode and line‑art blocks into Latin‑1
mojibake. GNOME Terminal is blunter and refuses to start at all.

This was found by looking at a screenshot of block 9, not by reasoning about it,
and it is the failure mode this group is most exposed to: a recording made in a
mis-configured container is a *recording of mojibake*, and replaying it against a
correctly-drawn benchmark fails every checkpoint from block 8 onward with nothing
in the macro pointing at the cause.

So it is set on two independent paths — the scenarios' `environment:` block, and
`/etc/parrot-env`, which every `parrot-<app>` launcher sources before it execs.
Either alone is sufficient; the point is that both would have to fail.

Related, and the reason it went unnoticed for a while: `setup-container.sh` now
reads the `environment:` block out of the scenario the same way it already read
`docker-run-args` and `setup-commands`. It used to pass only `RESOLUTION`, so the
container it built for verification was **not** the container GMT builds — and a
verification whose setup differs from the benchmark's verifies nothing.

### Every entrant launches as `parrot-<app>`

All of them get a generated launcher, even the ones that need no pre-exec step of
their own, so the drivers differ nowhere except in the app name. `install-common.sh`
writes them through one `write_launcher` helper. The pre-exec steps that do exist:
`xrdb -load` for xterm and urxvt (X is not running at install time, so loading the
resources during install would silently do nothing), and `dbus-run-session` for
GNOME Terminal. Konsole gets `--separate` so a relaunch cannot attach to a running
instance as a tab, and st's launcher *is* its entire configuration — it has no
config file, so `-f "DejaVu Sans Mono:size=11"` is the whole surface.

### A CJK font is required, and DejaVu is not one

The first xterm recording drew `日本語のテキスト` and the whole kana row as rows of
empty boxes. DejaVu Sans Mono has no CJK coverage at all, and the container image
ships no fallback font, so every CJK and kana glyph in block 8 was tofu.

The double-width *cell* handling was still being exercised — the boxes were
correctly two cells wide — but no CJK glyph was ever drawn, and the block exists
precisely because cell-width rules are where emulators disagree *even when every
glyph is present*. `fonts-wqy-microhei` (≈5 MB, against fonts-noto-cjk's ≈50 MB)
covers the Han, kana and Hangul this corpus uses. Every entrant gets the same
font, so whatever difference remains is the emulator's font **fallback** — which
is a genuine property of the emulator and one of the more interesting things this
block can show.

Worth noting how this was caught: not by any check, but by *looking at the
reference screenshot* after the first recording. `verify.sh` passed, all
every checkpoint was written, and the log was complete — the run was
correct in every way the automation could see, and still the block was not
testing what it claimed to.

### The recorder needs a stop key, and forgetting it looks like success

`record-macro.py` stops on `Pause`. The first xterm driver did not send it, and
the failure is a quiet one: every checkpoint and screenshot lands on
disk, the ground truth passes, the driver prints `=== done ===` — and
`record-session.sh`'s `wait` never returns, because the recorder is still armed.
Nothing in the output says so. The shared driver now ends with `K Pause`, as the
spreadsheet drivers already did.

The keystroke itself does not land in the macro: the recorder stops on it and
does not emit the idle that preceded it, so the file ends exactly at the last
`check` with no trailing wait.

### The steady-screen test is the one to run first on any new entrant

```bash
import -window "$w" /tmp/a.png; sleep 1.5; import -window "$w" /tmp/b.png
cmp -s /tmp/a.png /tmp/b.png && echo steady || echo CHANGES
```

An idle terminal that is not byte-identical to itself cannot be replay-verified,
and the cause is almost always a blinking cursor. It is a five-second check and
it ruled kitty's default configuration out and cool-retro-term out entirely.

## What every entrant has to be configured to do

A terminal's appearance is nearly all configuration, so a fair comparison needs
the same configuration everywhere — and each entrant expresses it
differently. This is the per-app `install.sh` work:

| setting | why it matters |
| --- | --- |
| **font family and size** | identical everywhere, or the entrants are not rendering the same thing. DejaVu Sans Mono, one size |
| **cursor blink off** | see above |
| **cursor style** | a block and a bar are different pixel counts |
| **scrollback length** | fixed, and long enough for block 3 to have somewhere to scroll |
| **bell off** | a visual bell flashes the window and fails the next checkpoint |
| **colour palette** | the sixteen ANSI colours differ per emulator by default; block 6 renders them |
| **no transparency, no background image** | both would sample the desktop |
| **`PS1`** | fixed, no hostname, no path, no clock, no colour |

The mechanisms, all different: X resources (xterm, urxvt), `kitty.conf`,
`alacritty.toml`, a KDE profile file (Konsole), dconf/gsettings (GNOME
Terminal), and for st **command-line flags only**, because its configuration is
compile-time — `st -f 'DejaVu Sans Mono:pixelsize=16'` is the whole surface.

## Progress

| | xterm | urxvt | mlterm | pterm | st | gnome-term | konsole | alacritty | kitty |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| installs & launches | ✅ | ✅ | ✅ | ✅ ³ | ✅ | ✅ | ✅ | ✅ ² | ✅ |
| pin string measured | ✅ | ✅ | ✅ ⁴ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| steady screen | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ ¹ |
| recorded, 16 checkpoints | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| ground truth PASS | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| replay-verified | — | — | — | — | — | — | — | — | — |
| `MEASUREMENTS.md` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

¹ only with `cursor_blink_interval 0`.

² only with `libxkbcommon-x11-0`; see footnote 4 on the probe table.

³ only with `-e /bin/bash -l`; by default it starts dash, not bash.

⁴ the pin string is **`xterm`**, not `mlterm` — its `WM_CLASS` res_name really is
`xterm`. Pinning `mlterm` matches nothing.

**Blocked and documented, not in the table:** Terminology (EFL needs
`SO_REUSEPORT`, which the container's network namespace refuses — see
[terminology/MEASUREMENTS.md](terminology/MEASUREMENTS.md)) and GNOME Console
(its idle screen is not byte-identical to itself, so it cannot be
replay-verified).

### Per-block wait times are per-app, and that is a finding

Two entrants needed a longer wait than the 8 s default, and the driver's log
assertion is what caught both rather than a failed screenshot:

| block | xterm | konsole |
| --- | --- | --- |
| plain | 1,501 ms | 5,087 ms |
| longlines | 1,471 ms | 3,750 ms |
| seq | 1,487 ms | **9,588 ms** |

Konsole is three to six times slower than the Xlib entrants across the board —
a real result about Qt rendering rather than a problem to hide — and pterm is in
the same class. Both carry a `BLOCK_WAIT` in their `driver.conf`, sized from
measurement. It does not bias the comparison: the recordings are time-normalized
afterwards, which pads every block to the group maximum anyway.

## Still open

1. **`TERM` differs by design** — `xterm-256color`, `rxvt-unicode-256color`,
   `alacritty`, `xterm-kitty`, `st-256color`. Programs inside behave slightly
   differently as a result. That is a genuine property of the emulator and
   should not be normalised away, but it must be recorded per app. Measured so
   far: xterm and st are `xterm-256color` and `st-256color`, both 256 colours.
2. **st's asymmetry.** Its scrollback length, palette and cursor shape are
   compile-time and cannot be set from the command line, so they stay at
   Debian's defaults while the other six are configured. That is a finding to
   record in its `MEASUREMENTS.md`, not something to work around.
3. **No GMT runs yet**, and no time-normalized variants. The other groups both
   have them; this one has neither.

## A wrong turn worth recording: the window size

For most of the build I believed each app's driver would have to assert its own
measured window size, because a terminal cannot be pinned to an exact pixel size
— it sizes itself to whole character cells and then adds its border.

That part is true and measured. `pin-windows.sh xterm 1440 900` gives back
**1435x897**: 159 columns × 47 rows of a 9 × 19 px cell plus a 2 px border, and
st lands on exactly the same numbers because it is also raw Xlib rendering DejaVu
Sans Mono at size 11 with a 2 px border. Six consecutive relaunches gave 1435x897
every time, so it is stable rather than racy.

**But the harness overrides it at both ends.** `record-macro.py` resizes the
window to the display size before recording, and `replay.py` reads the first
reference image's dimensions and forces the replay window to match. So both ends
land on 1440x900 regardless of what the emulator would choose for itself, and
every entrant is measured at the same size after all.

The mechanism was already there for a different reason. `tools/position-window.sh`
resizes, reads the geometry back, and falls back to `freeze-window-size.py` when
the window does not comply — a path written for xpdf, which re-asserted its size
hints after load. A terminal is the same problem in a purer form: it advertises
`WM_NORMAL_HINTS` with resize increments of one character cell, which is exactly
what makes it round to 1435x897 when anything respects those hints.

The symptom that exposed this was the driver warning on every block of
the first recording — `would capture WIDTH=1440 HEIGHT=900 (want 1435x897)`. The
recording itself was fine and replayed at RMSE 0; the assertion was simply
checking against the wrong number.

The size is still declared per app in `driver.conf` rather than hard-coded in the
shared driver, because an emulator that snaps *back* to a cell boundary after
being resized is exactly the kind of thing worth catching — and it would show up
as a warning at record time rather than as a set of unreproducible screenshots.
`common/measure-window.sh <app>` reports an app's natural size, grid, `TERM`,
colour depth and steadiness in one command.
