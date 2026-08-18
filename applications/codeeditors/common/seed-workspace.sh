#!/usr/bin/env bash
# Put the project every editor recording edits at a known path, in a known state.
#
#   seed-workspace.sh [dest]        default: /root/project
#
# Runs as a setup-command, which means it runs before recording AND before every
# replay.  That is the point: the scenario mutates files on disk - it inserts a
# line into src/price_calculator.py and saves it, and it rewrites the three files
# under src/legacy/ - so without a reseed the second replay would start from a
# tree that already had the edits in it, and the checkpoints would be comparing
# against the wrong buffers.  Same reason the mail benchmark regenerates its
# corpus on every run.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${HERE}/../workspace"
DEST="${1:-/root/project}"

log() { printf '[seed-workspace] %s\n' "$*"; }

rm -rf "$DEST"
mkdir -p "$DEST"
cp -a "${SRC}/." "$DEST/"

# The 10 MB file the large-file steps work on, built here rather than committed.
# It is pure ASCII produced by integer arithmetic, so every machine generates the
# same bytes - see generate-large-file.py for why that is worth more than
# shipping the blob.
python3 "${HERE}/generate-large-file.py" "${DEST}/src/component_library.py"

# Nothing git-ignored may survive the copy.  Both of these are invisible to a
# fresh clone and present on the machine a recording is made on, which is the
# worst shape a difference can have: the file tree the macro was recorded
# against has an entry the tree it replays against does not, every row below it
# is one row lower, and the click that opened a file opens its neighbour.
#
# .git also changes how the tree is drawn even when it is closed - VS Code,
# IntelliJ and Eclipse all colour a tracked file differently from an untracked
# one and add a badge counting changes.  __pycache__ is one extra folder in the
# explorer, which is enough.
rm -rf "${DEST}/.git"
find "$DEST" -name '__pycache__' -type d -prune -exec rm -rf {} + 2>/dev/null || true
find "$DEST" -name '*.pyc' -delete 2>/dev/null || true

# A fixed mtime on every file, because several of these editors show one.  VS
# Code's explorer does not, but IntelliJ's "Recent Files", Eclipse's properties
# view and anything that sorts by date do - and a timestamp that moves with the
# wall clock is a moving pixel inside a reference screenshot.  Not the repo
# checkout time either: that differs between the machine a recording was made on
# and the machine replaying it.  Last, so it covers the generated file too.
find "$DEST" -exec touch -d '2026-01-05 09:00:00 UTC' {} +

log "workspace at ${DEST}:"
find "$DEST" -type f -printf '  %10s  %P\n' | sort -k2
log "$(wc -l < "${DEST}/src/price_calculator.py") lines in src/price_calculator.py"
