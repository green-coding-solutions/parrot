#!/usr/bin/env bash
# Record applications/terminals/konsole/konsole.parrot end to end.
exec bash "$(dirname "$0")/../common/record-session.sh" konsole
