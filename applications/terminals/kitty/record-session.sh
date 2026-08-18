#!/usr/bin/env bash
# Record applications/terminals/kitty/kitty.parrot end to end.
exec bash "$(dirname "$0")/../common/record-session.sh" kitty
