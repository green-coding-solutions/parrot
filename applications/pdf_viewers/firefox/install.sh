#!/usr/bin/env bash
# The pdf_viewers group measures the same browser the firefox group does, so it
# installs it with the same script rather than a copy of it.  usage_scenario.yml
# in this directory has always called ../../firefox/install.sh directly; this
# file was a duplicate of the old apt one-liner and rotted with it.
set -euo pipefail

exec bash "$(dirname "$(readlink -f "$0")")/../../firefox/install.sh" "$@"
