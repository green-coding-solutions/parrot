#!/usr/bin/env bash
# Record applications/terminals/gnome-terminal/gnome-terminal.parrot end to end.
exec bash "$(dirname "$0")/../common/record-session.sh" gnome-terminal
