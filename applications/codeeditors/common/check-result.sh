#!/usr/bin/env bash
# Ground truth for the code-editor scenario: what the project on disk must look
# like once the recording has run.
#
#   check-result.sh [project-dir]      default: /root/project
#
# Runs inside the window container, after the replay.
#
# WHY THIS EXISTS
#
# Screenshots cannot tell a real edit from a convincing one.  Nearly every step
# in this scenario has a way of looking right and being wrong:
#
#   the paste        lands in the file but one line too low, or replaces the
#                    selection instead of following it
#   the first undo   is swallowed because the editor put the paste and the copy
#                    in one undo group, so it reverts the selection too
#   replace-all      silently matches nothing, because the find field still had
#                    "whole word" set or a previous term in it - a no-op renders
#                    exactly like a replacement that was undone
#   the second undo  undoes one occurrence instead of the batch, leaving
#                    `vat_rate` in three places the screenshot does not show
#   the save         goes to a different file, because the editor reopened the
#                    buffer under a temp path
#   global replace   hits one file of the three, or edits all three in memory
#                    and writes none of them - the search panel says "9
#                    occurrences replaced" either way
#
# Most of those produce a final screenshot pixel-identical to a correct run.
# The files are the only witness.
set -euo pipefail

PROJECT="${1:-/root/project}"
FILE="${PROJECT}/src/price_calculator.py"
SEED_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../workspace" && pwd)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

fail=0
ok()  { printf '  [ ok ] %s\n' "$*"; }
bad() { printf '  [FAIL] %s\n' "$*"; fail=1; }

printf '=== ground truth: %s ===\n' "$PROJECT"

[[ -f "$FILE" ]] || { bad "${FILE} does not exist"; exit 1; }

# --- src/price_calculator.py -------------------------------------------------
echo "--- src/price_calculator.py ---"

lines=$(wc -l < "$FILE")
[[ "$lines" -eq 129 ]] \
    && ok "129 lines (128 original + 1 inserted)" \
    || bad "expected 129 lines, found ${lines}"

# The inserted comment.  The indentation is deliberately NOT asserted: each
# editor runs on its own defaults, and they disagree about it - VS Code's
# "insert line above" indents to match the statement below, IntelliJ pulls a
# Python line comment out to column 0.  Both inserted the line the script asked
# for, immediately before the line the script named; where the '#' lands is the
# editor's own convention and Python tokenises it identically either way.
#
# What IS asserted is that there is exactly one of them, and what it precedes.
inserted=$( { grep -c '^[[:space:]]*# benchmark complete$' "$FILE" || true; } )
if [[ "$inserted" -eq 1 ]]; then
    indent=$(grep -o '^[[:space:]]*# benchmark complete$' "$FILE" | sed 's/#.*//' | wc -c)
    ok "'# benchmark complete' present exactly once (indented $((indent - 1)) columns)"
else
    bad "'# benchmark complete' found ${inserted} times; lines mentioning it:"
    grep -n 'benchmark complete' "$FILE" | sed 's/^/         /' || true
fi

# ...and immediately before the return, which is the half of "insert a line
# before X" that a line count cannot check.
after=$(grep -A1 '^[[:space:]]*# benchmark complete$' "$FILE" | tail -n1 || true)
[[ "$after" == "    return subtotal + tax" ]] \
    && ok "followed directly by 'return subtotal + tax'" \
    || bad "line after the comment is '${after}', wanted '    return subtotal + tax'"

# The replacement was undone.  A single leftover is the failure mode a
# screenshot of one screenful of the file cannot show.
vat=$(grep -c 'vat_rate' "$FILE" || true)
[[ "$vat" -eq 0 ]] \
    && ok "no 'vat_rate' left (replace-all was undone)" \
    || bad "'vat_rate' still on ${vat} lines:
$(grep -n 'vat_rate' "$FILE" | sed 's/^/         /')"

# ...and it had something to undo.  Four is the count in the seeded file, so
# this catches a replace-all that matched nothing as well as one only partly
# reverted.
tax=$(grep -c 'tax_rate' "$FILE" || true)
[[ "$tax" -eq 4 ]] \
    && ok "'tax_rate' back on all 4 original lines" \
    || bad "'tax_rate' on ${tax} lines, expected 4"

dup=$(grep -c '^    tax = subtotal \* tax_rate$' "$FILE" || true)
[[ "$dup" -eq 1 ]] \
    && ok "'tax = subtotal * tax_rate' present once (paste was undone)" \
    || bad "'tax = subtotal * tax_rate' present ${dup} times, expected 1"

# Cheap, and it catches damage the greps above would miss entirely - a stray
# character typed while a modal editor was in the wrong mode lands somewhere
# none of these patterns look.
#
# compile() rather than `python3 -m py_compile`, which writes a __pycache__
# directory next to the file it checks.  That is a new folder in the editor's
# file tree, created by the verification, present on the machine that ran a
# check and absent everywhere else - which is the exact shape of difference
# seed-workspace.sh strips .git and __pycache__ to avoid.  A check must not
# change the thing it is checking.
if python3 -c 'import sys; compile(open(sys.argv[1]).read(), sys.argv[1], "exec")' "$FILE" 2>/dev/null; then
    ok "still valid Python"
else
    bad "no longer parses:"
    python3 -c 'import sys; compile(open(sys.argv[1]).read(), sys.argv[1], "exec")' "$FILE" 2>&1 | sed 's/^/         /' || true
fi

# Everything else byte-identical to the seed.  The checks above name the lines
# the scenario may touch; this one catches an edit anywhere it may not - a
# character typed into the wrong buffer position, an auto-formatter that
# reflowed on save, a trailing-whitespace stripper.
if diff <(grep -v '^[[:space:]]*# benchmark complete$' "$FILE") "${SEED_DIR}/src/price_calculator.py" >/tmp/ce-diff.txt 2>&1; then
    ok "identical to the seed apart from the inserted line"
else
    bad "differs from the seed beyond the inserted line:"
    sed 's/^/         /' /tmp/ce-diff.txt | head -40
fi

# --- src/legacy/ - the project-wide replace ----------------------------------
echo "--- src/legacy/ (global replace) ---"

# `|| true` is not cosmetic.  Under `set -euo pipefail` a grep that legitimately
# matches nothing - which is the PASSING case here - kills the script, and it
# dies at exactly the point where the remaining ground-truth checks would have
# run.  A green partial report that stops halfway is the failure shape this
# whole file exists to prevent, and this line produced one the first time it ran.
# --include='*.py', because the assertion is about the three source files and
# not about everything an editor may have left beside them.  Emacs writes
# orders.py~, pricing.py~ and shipping.py~ on first save - make-backup-files is
# on by default - and those hold the pre-replace text, so an unscoped grep
# reports twelve LEGACY_SKU still present while all three real files are
# correct.  The backups are listed below as information rather than treated as
# a failure: leaving them is what Emacs does, and it is worth seeing.
left=$( { grep -ro --include='*.py' 'LEGACY_SKU' "${PROJECT}/src/legacy/" 2>/dev/null || true; } | wc -l)
[[ "$left" -eq 0 ]] \
    && ok "no 'LEGACY_SKU' left under src/legacy/" \
    || bad "'LEGACY_SKU' still present:
$(grep -rn 'LEGACY_SKU' "${PROJECT}/src/legacy/" | sed 's/^/         /')"

# Four per file, checked per file: a replace that reached the open file and
# stopped still totals twelve if you only add the three up, and "more than
# zero" would pass on one file out of three.
#
# grep -o, not grep -c.  -c counts matching LINES, and orders.py has a line with
# two occurrences on it - so -c reported 3 where the truth was 4, and the check
# was quietly one occurrence looser than it claimed to be on every file.
for f in orders pricing shipping; do
    n=$( { grep -o 'ARCHIVE_SKU' "${PROJECT}/src/legacy/${f}.py" 2>/dev/null || true; } | wc -l)
    [[ "$n" -eq 4 ]] \
        && ok "src/legacy/${f}.py: 4 occurrences replaced and written to disk" \
        || bad "src/legacy/${f}.py: ${n} occurrences of ARCHIVE_SKU, expected 4"
done

# And nothing else in those files moved.
for f in orders pricing shipping; do
    if diff <(sed 's/ARCHIVE_SKU/LEGACY_SKU/g' "${PROJECT}/src/legacy/${f}.py") \
            "${SEED_DIR}/src/legacy/${f}.py" >/tmp/ce-legacy-diff.txt 2>&1; then
        ok "src/legacy/${f}.py: identical to the seed apart from the identifier"
    else
        bad "src/legacy/${f}.py: changed beyond the identifier:"
        sed 's/^/         /' /tmp/ce-legacy-diff.txt | head -20
    fi
done

# Anything the editor left beside the three source files.  Emacs leaves ~
# backups; nothing else in the group does.
extras=$( { find "${PROJECT}/src/legacy" -type f ! -name '*.py' 2>/dev/null || true; } | sort)
if [[ -n "$extras" ]]; then
    printf '  [info] this editor also left:\n'
    printf '%s\n' "$extras" | sed 's|.*/|         |'
fi

# --- src/component_library.py - the large file ------------------------------------
echo "--- src/component_library.py (large file) ---"

# REPORTED, NOT ASSERTED.
#
# The scenario types ten lines into this file and never asks for a save, so
# whether those ten lines reach the disk is a property of the editor: VS Code
# holds them in a dirty buffer, IntelliJ writes them out on a timer of its own.
# Both are correct behaviour for the editor in question and every editor here
# runs on its own defaults, so this is a difference to record rather than one to
# configure away - it is part of what the benchmark is measuring.
#
# It is still worth printing, because "the editor autosaved" is also the
# explanation for a "Save file" step that appears to cost nothing.
python3 "${HERE}/generate-large-file.py" /tmp/ce-catalog-expected.py >/dev/null
if cmp -s "${PROJECT}/src/component_library.py" /tmp/ce-catalog-expected.py; then
    printf '  [info] unchanged on disk (%s bytes) - this editor does not autosave\n' \
        "$(wc -c < "${PROJECT}/src/component_library.py")"
else
    typed=$( { grep -c -f <(printf '%s\n' 'BATCH_SIZE = 500' 'FLUSH_INTERVAL = 60') \
        "${PROJECT}/src/component_library.py" 2>/dev/null || true; } )
    printf '  [info] written to disk - this editor autosaves\n'
    printf '         on disk:  %s bytes, %s lines\n' \
        "$(wc -c < "${PROJECT}/src/component_library.py")" "$(wc -l < "${PROJECT}/src/component_library.py")"
    printf '         seeded:   %s bytes, %s lines\n' \
        "$(wc -c < /tmp/ce-catalog-expected.py)" "$(wc -l < /tmp/ce-catalog-expected.py)"

    # ASSERTED, not reported - and this is the line that should have existed
    # from the start.  Whether the ten lines reach the disk at all is the
    # editor's business, so the branch above stays informational; but once an
    # editor HAS written the file out, what it wrote has to be what block 17
    # typed.
    #
    # All three JetBrains editors wrote a file that was exactly ten BYTES larger
    # than the seed: ten newlines and not one character.  The checkpoint before
    # block 17 calls `xdotool windowfocus` on the frame, which clears Swing's
    # focus owner, and IntelliJ then routes Return through its action system
    # while dropping every printable character on the floor.  337547 lines
    # against a seeded 337537 is what that looks like from here - the arithmetic
    # a human checks, agreeing perfectly, while the content is empty.
    if [[ "$typed" -eq 2 ]]; then
        ok "both sentinel lines of the typed block are on disk"
    else
        bad "only ${typed} of the 2 sentinel typed lines are on disk - block 17 typed newlines but no text:
$(sed -n '1,10p' "${PROJECT}/src/component_library.py" | cat -A | sed 's/^/         |/')"
    fi
fi
rm -f /tmp/ce-catalog-expected.py

if [[ "$fail" -eq 0 ]]; then
    echo "=== GROUND TRUTH OK ==="
else
    echo "=== GROUND TRUTH FAILED ==="
fi
exit "$fail"
