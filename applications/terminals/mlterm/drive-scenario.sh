#!/usr/bin/env bash
# Drive mlterm through applications/terminals/script.md.
# The sixteen blocks are identical in every entrant; see common/drive-scenario.sh.
exec bash "$(dirname "$0")/../common/drive-scenario.sh" mlterm
