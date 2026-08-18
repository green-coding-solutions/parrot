#!/usr/bin/env bash
# Drive alacritty through applications/terminals/script.md.
#
# The eighteen blocks are identical in all seven entrants - same keystrokes, same
# corpus commands - so the sequence lives in common/drive-scenario.sh and this
# app contributes only driver.conf.
exec bash "$(dirname "$0")/../common/drive-scenario.sh" alacritty
