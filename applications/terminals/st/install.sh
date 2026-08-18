#!/usr/bin/env bash
# Install st (Debian's `stterm`).
#
# THE ONLY ENTRANT WITH NO CONFIGURATION FILE. st is configured at compile time
# in config.h, which means everything the other six set in a profile has to be
# either a command-line flag or a property of the Debian build. What that leaves:
#
#   font            `-f` takes an Xft string. This is the whole surface.
#   cursor blink    not settable - and does not need to be, because st's cursor
#                   is steady. Verified with the two-screenshot test rather than
#                   assumed, because there would be no way to fix it if it blinked.
#   scrollback      Debian PATCHES ST TO ADD IT. Upstream st has none at all, so
#                   block 3 would be impossible against a self-built st. Verified
#                   working with Shift+PageUp before st went on the list.
#   bell            st has no visual bell, so there is nothing to turn off.
#
# The version therefore matters more here than anywhere else in the group: this
# is Debian's st, not st.
set -euo pipefail
PROFILE_ONLY=0
[[ "${1:-}" == "--profile-only" ]] && PROFILE_ONLY=1
log() { printf '[install-st] %s\n' "$*"; }

COMMON=/tmp/repo/applications/terminals/common/install-common.sh
if [[ $PROFILE_ONLY -eq 0 ]]; then
    source "$COMMON"
    log "installing stterm"
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends stterm >/dev/null
else
    COMMON_PROFILE_ONLY=1; source "$COMMON"
fi

# --- launch wrapper ------------------------------------------------------
# st has no configuration file at all - upstream's answer is to edit config.h and
# recompile - so the launcher IS st's entire configuration, and every setting the
# other six get from a config file has to be a flag here or be left at Debian's
# compiled-in default.
#
# `size=11` and not `pixelsize=`: an Xft name accepts either, and points are what
# the other six are configured in, so points is what keeps the group comparable.
# A pixelsize here would be a different glyph size from the rest of the group and
# the comparison would quietly stop being like-for-like.
#
# What cannot be set from the command line, and is therefore Debian's default:
# the scrollback length (the patch's own SCROLLBACK), the sixteen palette colours
# and the cursor shape. That is a real asymmetry with the other six rather than
# something to work around, and it belongs in st's MEASUREMENTS.md.
write_launcher st \
    'exec st -f "DejaVu Sans Mono:size=11"'

log "installed: stterm $(dpkg-query -W -f='${Version}' stterm 2>/dev/null || echo '?')"
