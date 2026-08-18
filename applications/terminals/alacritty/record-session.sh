#!/usr/bin/env bash
# Record applications/terminals/alacritty/alacritty.parrot end to end.
exec bash "$(dirname "$0")/../common/record-session.sh" alacritty
