#!/usr/bin/env bash
# Record applications/terminals/urxvt/urxvt.parrot end to end.
exec bash "$(dirname "$0")/../common/record-session.sh" urxvt
