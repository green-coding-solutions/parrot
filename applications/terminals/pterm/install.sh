#!/usr/bin/env bash
# Install pterm - PuTTY's X11 terminal - and configure it like the rest.
#
#   install.sh                 full install
#   install.sh --profile-only  re-seed the config only, for measuring
#
# pterm is in the group because its terminal core is PuTTY's, written for Windows
# and ported to X11, and shares no ancestry with either the xterm lineage or VTE.
# It is the only entrant whose escape-sequence handling was developed largely
# independently of the Unix ones.
set -euo pipefail

PROFILE_ONLY=0
[[ "${1:-}" == "--profile-only" ]] && PROFILE_ONLY=1
log() { printf '[install-pterm] %s\n' "$*"; }

COMMON=/tmp/repo/applications/terminals/common/install-common.sh
if [[ $PROFILE_ONLY -eq 0 ]]; then
    # shellcheck source=/dev/null
    source "$COMMON"
    log "installing pterm"
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends pterm >/dev/null
else
    COMMON_PROFILE_ONLY=1
    # shellcheck source=/dev/null
    source "$COMMON"
fi

# pterm keeps its settings in PuTTY's registry-shaped file tree rather than a
# config file, so the reliable way to set them is command-line options on the
# launcher. -fn takes an Xft name; -sl is the scrollback length.
# -fn takes a PANGO font description here, not an Xft name. pterm is a GTK
# program, and `DejaVu Sans Mono:size=11` - which works for st and mlterm - makes
# it exit with `unable to load font` before mapping a window. The Pango spelling
# puts the size after a space and no colon.
log "pterm is configured on the command line; see the launcher"

# `-e /bin/bash -l` IS NOT OPTIONAL. Left alone pterm starts the shell from
# /etc/passwd, which in this image is dash - it came up as `-sh` with the working
# directory at `/`, so /root/.bashrc never ran, the prompt was not `parrot$ ` and
# `corpus/boxes.sh` was simply not found.
#
# That would have broken the premise of the whole group. Every entrant is
# supposed to run the SAME bash, the same less and the same corpus, so that the
# only thing differing between recordings is the emulator; an entrant quietly
# running a different shell compares the shells instead.
write_launcher pterm \
    'exec pterm -fn "DejaVu Sans Mono 11" -sl 20000 -e /bin/bash -l'

log "installed: pterm $(dpkg-query -W -f='${Version}' pterm 2>/dev/null || echo '?')"
