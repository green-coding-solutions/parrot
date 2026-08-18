#!/usr/bin/env bash
# Drive LibreOffice Calc through applications/spreadsheets/script.md while
# record-macro.py records the input. One block per script line, each ending in a
# checkpoint.
#
# Runs on the host and sends events into the container with xdotool, so that
# xmacrorec2 - watching the same X display from inside - records real input
# events. There is no `xdotool windowactivate`, `windowfocus` or `windowsize`
# here: none of those is an input event, so xmacrorec2 would not record them and
# they would silently not happen on replay. The window is pinned by the window
# manager instead (see usage_scenario.yml).
#
# Every landmark is in MEASUREMENTS.md, measured by driving this sequence by
# hand and checking common/check-result.sh at the end of it. Do not edit this
# file while it is running: bash reads a script incrementally, and an edit that
# moves byte offsets corrupts the run in flight.
set -euo pipefail

CLASS=libreoffice
X() { docker exec -e DISPLAY=:99 window-container xdotool "$@" >/dev/null 2>&1; }
Q() { docker exec -e DISPLAY=:99 window-container bash -c "$1" 2>/dev/null; }

T()  { X type --delay 45 -- "$1"; }
K()  { X key --clearmodifiers "$1"; }
CLICK()  { X mousemove "$1" "$2"; sleep 0.4; X click 1; }
CLICK3() { X mousemove "$1" "$2"; sleep 0.4; X click --repeat 3 1; }

# Select a range through the Name Box. Every selection in this driver goes
# through here.
#
# A spreadsheet's address space is identical in all six applications, so naming
# cells is portable in a way that dragging is not: a drag depends on rendered row
# heights, and Ctrl+Shift+Down from a cell with nothing under it runs to the
# sheet's last row - which these applications do not agree about.
#
# One click, because Calc's Name Box selects its whole contents on focus. No
# triple-click and no Ctrl+A; both were checked.
NAME() { CLICK 72 89; sleep 1; T "$1"; K Return; }

# Park the pointer somewhere inert before every capture. xdotool leaves it
# wherever it last clicked, and a pointer resting on a toolbar button raises a
# tooltip - which would be baked into the reference screenshot and then fail to
# reappear on replay.
#
# 1200,700 is empty grid: not the toolbar, not the sheet tabs, not the sidebar.
park() { X mousemove 1200 700; sleep 1; }

# Checkpoint: settle, park, assert what would be captured, then press the
# recorder's hotkey.
#
# The assertion matters. record-macro.py captures
# `xdotool search --onlyvisible --class <class> | head -n1` - the FIRST match,
# not the largest - and every Calc dialog shares the document's WM_CLASS. A
# checkpoint taken with one still on screen becomes a photograph of a modal, and
# that image is what every future replay is measured against. Block 15 opens two
# windows and closes both for exactly this reason.
CP() {
    sleep "${2:-3}"
    park
    geo="$(Q "w=\$(xdotool search --onlyvisible --class ${CLASS} | head -n1);
              xdotool getwindowgeometry --shell \$w | grep -E '^(WIDTH|HEIGHT)='" | tr '\n' ' ')"
    case "$geo" in
        *"WIDTH=1440"*"HEIGHT=900"*) ;;
        *) echo "  WARNING: '$1' would capture ${geo}" ;;
    esac
    K Scroll_Lock
    sleep 2
    echo "  [checkpoint] $1"
}

echo "=== driving LibreOffice Calc ==="

# --- 1. Load app -------------------------------------------------------------
# record-macro.py has already launched `soffice --calc` through the startcommand
# and waited for the window. What it cannot wait for is Calc finishing its first
# paint, which is around 45 s cold in this container.
#
# Nothing has to be dismissed: the seeded profile turns off the first-run
# wizard, Tip of the Day, the version infobar and document recovery.
sleep 50
CP "Load app" 5

# --- 2. Open workbook --------------------------------------------------------
# The Open dialog's filename field has focus when it appears, so nothing is
# clicked. The empty `Untitled 1` window is REPLACED rather than added to - Calc
# reuses an unmodified blank document - so there is still exactly one window
# afterwards.
#
# No "recalculate formulas?" prompt appears: ODFRecalcMode=1 in the profile. The
# workbook ships cached values, so the Summary sheet is correct on screen from
# here until block 11 recomputes it.
K ctrl+o; sleep 5
T '/tmp/parrot-ledger.ods'; sleep 2
K Return
CP "Open workbook" 45

# --- 3. Jump to end ----------------------------------------------------------
# Lands on H20001. One press: there is no table for the cursor to stop at, so
# pressing it twice would be wrong.
K ctrl+End
CP "Jump to end" 10

# --- 4. Freeze the header ----------------------------------------------------
# Freezing is relative to the cursor, so the cursor goes to A2 first and row 1 is
# what gets frozen. No keyboard shortcut exists for this in 24.2, so it is the
# View menu.
K ctrl+Home; sleep 4
K Down; sleep 1
CLICK 82 9; sleep 2
CLICK 171 323
CP "Freeze the header" 5

# --- 5. Page through ---------------------------------------------------------
# Ends on A412: 41 rows per press with row 1 frozen above.
for _ in $(seq 1 10); do K Next; sleep 0.6; done
CP "Page through" 5

# --- 6. Switch sheets --------------------------------------------------------
# Each sheet keeps its own scroll position, so Readings comes back at row 412.
CLICK 228 864; sleep 5
CLICK 293 864; sleep 5
CLICK 162 864
CP "Switch sheets" 6

# --- 7. Sort -----------------------------------------------------------------
# Two keystrokes inside the dialog and no clicks in it at all.
#
# `r` selects Reading in the focused Sort Key 1 listbox - the only column
# beginning with R, where S would be ambiguous between Site, Sensor and Status.
# Clicking the combo instead opens a popup that positions the SELECTED entry
# under the pointer, which is the failure that cost the word processor group a
# pass on three separate applications.
#
# "Range contains column labels" is already ticked - Calc detects the header row.
# Screenshotted, not assumed.
NAME 'A1:H20001'; sleep 5
CLICK 305 9; sleep 2
CLICK 337 30; sleep 5
K r; sleep 2
K Return
CP "Sort" 25

# --- 8. Enter formula --------------------------------------------------------
# The comma is the argument separator: the container runs an English (USA)
# locale and Calc's UI accepts `=ROUND(E2*F2,2)` verbatim. I2 shows 10.5.
#
# AutoInput is off in the profile, so nothing completes the function name and
# the Return that ends the entry commits what was typed rather than a suggestion.
NAME 'I2'; sleep 3
T '=ROUND(E2*F2,2)'; sleep 2
K Return
CP "Enter formula" 5

# --- 9. Fill down ------------------------------------------------------------
# 20,000 formulas. The status bar afterwards reads Sum: 74641377.6700004, which
# is what generate_workbook.py --expected computes independently.
NAME 'I2:I20001'; sleep 6
K ctrl+d
CP "Fill down" 30

# --- 10. Total ---------------------------------------------------------------
NAME 'K1'; sleep 3
T '=SUM(I2:I20001)'; sleep 2
K Return
CP "Total" 8

# --- 11. Recalculate ---------------------------------------------------------
# Hard recalculation of the whole workbook.
#
# This is the keystroke fluxbox's default keys file would eat - it grabs
# Control+F1..F12 at the X server for workspace switching, and the failure looks
# exactly like a crash. pin-windows.sh writes a keys file with no keyboard
# bindings at all, so it reaches the application.
K ctrl+shift+F9
CP "Recalculate" 25

# --- 12. Filter --------------------------------------------------------------
# Ctrl+Shift+L is Data > AutoFilter. The Category dropdown is at 443,132.
#
# The popup opens with its "Search items" box focused, so typing narrows the list
# to Turbine and ticks it - no checkbox coordinates and no "untick All first".
NAME 'A1:H20001'; sleep 5
K ctrl+shift+l; sleep 8
CLICK 443 132; sleep 4
T 'Turbine'; sleep 3
CLICK 485 513
CP "Filter" 18

# --- 13. Clear filter --------------------------------------------------------
# Toggling AutoFilter off removes it AND unhides every row - verified, because
# the equivalent through the UNO API does not, and a replace-all over a sheet
# with hidden rows silently skips them.
K ctrl+shift+l
CP "Clear filter" 15

# --- 14. Format numbers ------------------------------------------------------
# The Format as Number toolbar button. E2 goes from 10 to 10.00.
NAME 'E2:E20001'; sleep 6
CLICK 756 60
CP "Format numbers" 12

# --- 15. Replace all ---------------------------------------------------------
# THE SINGLE-CELL SELECTION IS LOAD-BEARING. Calc ticks "Current selection only"
# whenever a multi-cell range is selected, and block 14 leaves E2:E20001
# selected - a column with no text in it. The replace would have searched that,
# changed nothing, and reported it in a small dialog with every screenshot
# looking correct. With one cell selected the box is unticked. Verified both ways.
#
# Replace All opens a Search Results window reporting "500 results found". Both
# it and Find and Replace are closed before the checkpoint: they share the
# document's WM_CLASS and would be photographed instead of it.
NAME 'A1'; sleep 3
K ctrl+h; sleep 6
T 'Cormorant'; sleep 2
CLICK 733 365; sleep 1
T 'Shearwater'; sleep 2
CLICK 939 411; sleep 15
CLICK 837 597; sleep 3
CLICK 950 627
CP "Replace all" 6

# --- 16. Insert chart --------------------------------------------------------
# Column is the wizard's default and ODF stores it as chart:class="chart:bar",
# so "a bar chart accepting the app's defaults" needs no click in the type list.
#
# Inserting a chart puts the WHOLE APPLICATION into chart-edit mode - the menu
# bar loses Sheet, Data and Styles. The click at 1200,700 leaves it; without that
# the next checkpoint photographs a different application.
CLICK 293 864; sleep 5
NAME 'A1:B7'; sleep 3
CLICK 123 9; sleep 2
CLICK 155 49; sleep 14
CLICK 948 584; sleep 8
CLICK 1200 700
CP "Insert chart" 8

# --- 17. Save ----------------------------------------------------------------
# No format dialog: the workbook was opened as ODS and is saved as ODS.
K ctrl+s
CP "Save" 20

# --- 18. Export PDF ----------------------------------------------------------
# PDF Options opens with Range = "Selection/Selected sheet(s)", which would
# export the Summary sheet alone - a one-page PDF where the ground truth expects
# nine. `All` at 412,313 is not optional.
#
# The file dialog already points at /tmp with the right name and filter; the full
# path is typed anyway so this does not depend on that.
CLICK 15 9; sleep 2
CLICK 77 324; sleep 10
CLICK 412 313; sleep 2
CLICK 1004 619; sleep 8
CLICK3 696 543; sleep 1
T '/tmp/parrot-ledger.pdf'; sleep 2
K Return
CP "Export PDF" 30

# Stop the recorder. Without this record-macro.py keeps recording and
# record-session.sh's `wait` never returns - the run looks finished, the log
# stops at "driver finished", and nothing says the recorder is still armed.
#
# The keystroke itself does not land in the macro: record-macro.py stops on it
# and does not emit the idle that preceded it, so the file ends exactly at the
# last `check` with no trailing wait. Verified on this recording.
echo "=== done - stopping the recorder ==="
K Pause
sleep 2
