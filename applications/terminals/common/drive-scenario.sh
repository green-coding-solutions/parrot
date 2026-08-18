#!/usr/bin/env bash
# Drive one terminal emulator through applications/terminals/script.md while
# record-macro.py records the input. One block per script line, each ending in a
# checkpoint.
#
#   common/drive-scenario.sh <app>
#
# ONE DRIVER FOR ALL SEVEN, unlike the spreadsheet group. There, every
# application put its commands in a different menu and the drivers had almost
# nothing in common. Here all sixteen blocks are literally the same keystrokes
# and the same corpus commands in every entrant - that is the point of the group,
# since anything that differed would be measuring the difference rather than the
# emulator. So the sequence lives here once and each app contributes only the
# handful of values that genuinely differ, in its own driver.conf.
#
# It is sixteen and not eighteen because the two scrollback blocks were removed:
# no gesture scrolls the scrollback in all seven. Shift+Page Up works in 2 of 7,
# the mouse wheel in 4 of 7. The full finding is in README.md.
#
# Runs on the host and sends events into the container with xdotool, so that
# xmacrorec2 - watching the same X display from inside - records real input
# events. There is no `xdotool windowactivate`, `windowfocus` or `windowsize`
# here: none of those is an input event, so xmacrorec2 would not record them and
# they would silently not happen on replay. The window is pinned by the window
# manager instead (see each usage_scenario.yml).
#
# Every landmark was measured by driving this sequence by hand against a live
# xterm; the per-app values are in each app's MEASUREMENTS.md. Do not edit this
# file while it is running: bash reads a script incrementally, and an edit that
# moves byte offsets corrupts the run in flight.
set -euo pipefail

REPO=/home/didi/code/parrot
APP="${1:?usage: drive-scenario.sh <app>}"
CONF="${REPO}/applications/terminals/${APP}/driver.conf"
[[ -f "$CONF" ]] || { echo "no driver.conf for ${APP} at ${CONF}" >&2; exit 1; }

# CLASS  - what xdotool matches to find the window (its match is case-insensitive)
# WANT_W - the window's measured width
# WANT_H - the window's measured height
# LOAD_WAIT - seconds to wait for the first prompt in block 1
# shellcheck source=/dev/null
source "$CONF"
: "${CLASS:?driver.conf must set CLASS}"
: "${WANT_W:?driver.conf must set WANT_W}"
: "${WANT_H:?driver.conf must set WANT_H}"
LOAD_WAIT="${LOAD_WAIT:-6}"

X() { docker exec -e DISPLAY=:99 window-container xdotool "$@" >/dev/null 2>&1; }
Q() { docker exec -e DISPLAY=:99 window-container bash -c "$1" 2>/dev/null; }

T() { X type --delay 25 -- "$1"; }
K() { X key --clearmodifiers "$1"; }

# Park the pointer somewhere inert before every capture. xdotool leaves it
# wherever it last moved, and in a terminal the pointer is an I-beam drawn into
# the window - so a pointer left over text is baked into the reference screenshot
# at that exact cell.
#
# A mousemove and NOT a click: a click clears the X PRIMARY selection, and block
# 14's entire ground truth is that selection surviving to block 16.
park() { X mousemove 1400 860; sleep 1; }

# Checkpoint: settle, park, assert what would be captured, then press the
# recorder's hotkey.
#
# THE SIZE IS 1440x900 BECAUSE THE HARNESS FORCES IT, not because the emulator
# chose it. Left alone a terminal sizes itself to whole character cells and adds
# its border - xterm and st both land on 1435x897 - but record-macro.py resizes
# the window to the display size before recording and replay.py resizes it to the
# reference image's size on replay, so both ends agree on 1440x900.
#
# It is still declared per-app in driver.conf rather than hard-coded here,
# because an emulator that snaps BACK to a cell boundary after being resized is
# exactly what this assertion should catch - as a warning at record time rather
# than as sixteen unreproducible screenshots.
CP() {
    sleep "${2:-3}"
    park
    geo="$(Q "w=\$(xdotool search --onlyvisible --class ${CLASS} | head -n1);
              xdotool getwindowgeometry --shell \$w | grep -E '^(WIDTH|HEIGHT)='" | tr '\n' ' ')"
    case "$geo" in
        *"WIDTH=${WANT_W}"*"HEIGHT=${WANT_H}"*) ;;
        *) echo "  WARNING: '$1' would capture ${geo} (want ${WANT_W}x${WANT_H})" ;;
    esac
    K Scroll_Lock
    sleep 2
    echo "  [checkpoint] $1"
}

# Run a corpus command, wait a FIXED generous time, then assert it finished.
#
# The sleep is fixed rather than a poll-until-done on purpose. A dynamic wait is
# not an input event, so it is not recorded - the macro keeps only the delay that
# actually elapsed while recording, and a replay on a slower machine would reach
# the checkpoint early regardless of how carefully the recording waited. So the
# sleep is sized from the measurement with a wide margin and the SAME number is
# what the replay gets.
#
# The assertion afterwards is the safety net, and it has already earned its
# keep: it caught a block whose expected log name was mistyped in the driver.
# Every corpus script appends its own line to the session log as it finishes, so
# if the margin is ever too thin this prints a warning at record time rather than
# producing a recording whose reference screenshot is a half-drawn screen.
#
# WHY NOT WAIT FOR THE SCREEN TO STOP CHANGING. That was tried first and it is
# not safe here: the corpus repeats its content, so a still-scrolling window can
# read as settled. It reported block 2 finished after 1.0 s when the block takes
# 2.0 s, and the screenshot taken on that signal was a half-drawn screen with no
# prompt on it. The session log is deterministic; the screen is not.
#
# Measured on xterm, scaled corpus: every block finishes in 1.4-2.0 s. The
# default of 8 s is four times the worst of them.
RUN() {
    local cmd="$1" want="$2" wait="${3:-${BLOCK_WAIT:-8}}"
    T "$cmd"; K Return
    sleep "$wait"
    if ! Q "grep -qx 'BLOCK ${want}' /tmp/parrot-term.log" ; then
        echo "  WARNING: '${cmd}' had not logged 'BLOCK ${want}' after ${wait}s"
    fi
}

echo "=== driving ${APP} (${CLASS}, ${WANT_W}x${WANT_H}) ==="

# --- 1. Load app -------------------------------------------------------------
# record-macro.py has already launched the app's parrot-<app> wrapper through the
# startcommand and waited for the window. What it cannot wait for is the shell
# inside reading .bashrc and printing the prompt, and the prompt is in every
# reference screenshot.
#
# LOAD_WAIT is per-app: xterm and st draw their first frame essentially
# instantly, GNOME Terminal has to bring up a session bus and hand off to
# gnome-terminal-server first.
#
# Nothing has to be dismissed in any of the seven: every entrant was configured
# with its menu bar, scrollbar and first-run dialogs off in its install.sh.
sleep "$LOAD_WAIT"
CP "1 load app"

# --- 2. Print a file ---------------------------------------------------------
# 675,000 lines of plain ASCII - plain.txt repeated 135 times. The repetition is
# what makes this a measurement rather than a rounding error: one pass costs 13ms
# because an emulator never has to paint a frame it can prove is about to be
# overwritten, so a fast scroll is optimised away almost entirely. How much of it
# each entrant manages to skip is exactly what this block compares.
#
# The end state is deterministic: the last line of the last pass is `05000  ...`
# and under it a fresh `parrot$ ` prompt.
RUN 'corpus/plain.sh' '02 plain'
CP "2 print a file"

# --- 3. Text attributes ------------------------------------------------------
# Bold, dim, italic, underline, reverse, strikethrough, double underline,
# overline and four combinations. NO SGR 5 (blink) anywhere - a blinking cell is
# not identical to itself between the capture and the replay, and would fail
# every checkpoint after it. generate_corpus.py --check asserts its absence.
RUN 'corpus/attributes.sh' '03 attributes'
CP "3 text attributes"

# --- 4. 256 colours ----------------------------------------------------------
# The indexed palette as background blocks. The sixteen ANSI colours differ per
# emulator by default and are deliberately NOT overridden, so this block's
# reference screenshot is different for every entrant on purpose.
RUN 'corpus/colours-256.sh' '04 colours-256'
CP "4 256 colours"

# --- 5. True colour ----------------------------------------------------------
# 24-bit direct colour. Every entrant was probed for this before the script was
# written and all seven render #119955 exactly - including rxvt-unicode, which I
# expected to lack it. Had that been taken on trust the block would have been
# dropped for no reason.
RUN 'corpus/colours-true.sh' '05 colours-true'
CP "5 true colour"

# --- 6. Unicode --------------------------------------------------------------
# Latin, combining marks, Greek, Cyrillic, Hebrew, double-width CJK, half- and
# full-width kana, symbols, arrows, blocks and Braille. No colour emoji: it is
# the one class the entrants genuinely disagree on, both in coverage and in cell
# width.
#
# This is the block that catches a mis-configured locale. Launched without LANG
# an emulator draws Latin-1 mojibake here - `â` where `│` belongs - and the
# recording would be a recording of mojibake, failing every later checkpoint
# with nothing in the macro pointing at the cause.
RUN 'corpus/unicode.sh' '06 unicode'
CP "6 unicode"

# --- 7. Line art -------------------------------------------------------------
RUN 'corpus/boxes.sh' '07 boxes'
CP "7 line art"

# --- 8. Cursor addressing ---------------------------------------------------
# The only block that does NOT scroll: absolute cursor addressing, repainting
# twenty rows in place, which is the path a TUI takes and a completely different
# code path in the emulator from appending at the bottom.
#
# It is by far the most expensive thing per byte in the corpus - 23 ms per
# iteration against 2.6 microseconds per line of plain scrolling - because an
# in-place repaint is the one case an emulator cannot skip a frame of. Its
# iteration count was reduced from 200 to 65 for exactly that reason: at 200 it
# was 90% of the whole session.
RUN 'corpus/redraw.sh' '08 redraw'
CP "8 cursor addressing"

# --- 9. Long lines ----------------------------------------------------------
# Lines 620 characters wide against a 159-column window, so every line wraps
# roughly four times. Wrapping depends on the column count, which is per-app and
# recorded in each MEASUREMENTS.md - an entrant with a different cell size gets a
# different number of columns and wraps the same corpus line differently.
RUN 'corpus/longlines.sh' '09 longlines'
CP "9 long lines"

# --- 10. Fast scroll ---------------------------------------------------------
RUN 'corpus/seq.sh' '10 seq'
CP "10 fast scroll"

# --- 11. Coloured listing ----------------------------------------------------
# 1,000 files in 40 directories through `ls --color=always -R`, with a fixed
# LS_COLORS so the colours are the same in every entrant. Colour interleaved with
# a real program's output rather than a synthetic block of escape sequences.
RUN 'corpus/ls-tree.sh' '11 ls-tree'
CP "11 coloured listing"

# --- 12. Page a file ---------------------------------------------------------
# `less` and not the emulator's own pager: it is the same program in every run,
# so this block compares the emulators rather than their pagers. It also switches
# to the alternate screen, which is its own code path.
#
# Plain Page Down here, not Shift+Page Up - inside the pager the keystrokes go to
# less, not to the emulator. All ten were verified to produce distinct screens.
T 'less corpus/plain.txt'; K Return
sleep 4
for i in 1 2 3 4 5 6 7 8 9 10; do
    K Next
    sleep 0.5
done
CP "12 page a file"

# --- 13. Search in the pager -------------------------------------------------
# less's search, not the emulator's - again so that the same program runs in
# every entrant. `beacon` appears exactly 120 times in plain.txt and in no other
# corpus file, so a search that silently matched something else shows up as a
# wrong screen rather than as a plausible one.
#
# Verified: the match is drawn in reverse video, `n` advances, and `q` returns to
# the shell leaving the alternate screen.
T '/beacon'
sleep 1
K Return
sleep 1.5
for i in 1 2 3; do
    K n
    sleep 1
done
K q
sleep 1.5
CP "13 search in the pager"

# --- 14. Select text ---------------------------------------------------------
# The one block with no command behind it, and therefore the one block whose
# ground truth is not the session log: the drag leaves its text in the X PRIMARY
# selection and verify.sh reads it back with `xclip -o -selection primary`.
#
# Verified to hold 200 characters spanning several lines after this drag, and -
# importantly - to SURVIVE block 15's `clear`, which is why the selection check
# can run as late as block 16.
#
# The intermediate mousemove is not decoration. A press at one point and a
# release at another with nothing in between is not a drag as far as the
# emulator's selection tracking is concerned.
X mousemove 72 190; sleep 0.5
X mousedown 1;      sleep 0.5
X mousemove 400 240; sleep 0.5
X mousemove 700 300; sleep 0.7
X mouseup 1
sleep 1.5
CP "14 select text"

# --- 15. Clear the screen ----------------------------------------------------
# `clear` and not Ctrl+L: the two are not the same. Ctrl+L is a readline binding
# that repaints, `clear` writes the terminal's own clear sequence, and only the
# second is the emulator's code path.
#
# park() moves the pointer without clicking, so the PRIMARY selection from block
# 14 is still intact when block 16 checks for it.
T 'clear'; K Return
sleep 2
CP "15 clear the screen"

# --- 16. Verify --------------------------------------------------------------
# The ground truth, on screen. verify.sh re-reads the session log and the PRIMARY
# selection and prints one ok/FAIL line per block plus a final RESULT line.
#
# A terminal emulator writes no document, so this is the whole of the evidence
# that the run did the work: a screenshot of a terminal whose output has scrolled
# past looks exactly like a screenshot of a terminal that printed nothing.
T 'corpus/verify.sh'; K Return
sleep 4
CP "16 verify"

# Stop the recorder. Without this record-macro.py keeps recording and
# record-session.sh's `wait` never returns - the run looks finished, all
# sixteen checkpoints and screenshots are on disk, and nothing says the
# recorder is still armed. Found exactly that way on the first xterm recording.
#
# The keystroke itself does not land in the macro: record-macro.py stops on it
# and does not emit the idle that preceded it, so the file ends exactly at the
# last `check` with no trailing wait. Verified on this recording.
echo "=== done - stopping the recorder ==="
K Pause
sleep 2

echo
echo "ground truth:"
Q '/opt/parrot/corpus/verify.sh' | sed 's/^/  /'
