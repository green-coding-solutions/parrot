#!/usr/bin/env bash
# Install xterm and seed the X resources that make it comparable to the others.
#
#   install.sh                 full install
#   install.sh --profile-only  re-seed the resources only, for measuring
#
# xterm is the reference implementation: no widget toolkit, straight Xlib, and
# the thing every other entrant is bug-compatible with. It is also the only one
# whose entire configuration is X resources, which is why it is the first app in
# the group - there is nothing between the setting and the effect.
set -euo pipefail

PROFILE_ONLY=0
[[ "${1:-}" == "--profile-only" ]] && PROFILE_ONLY=1

log() { printf '[install-xterm] %s\n' "$*"; }

COMMON=/tmp/repo/applications/terminals/common/install-common.sh
if [[ $PROFILE_ONLY -eq 0 ]]; then
    # shellcheck source=/dev/null
    source "$COMMON"
    log "installing xterm"
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends xterm >/dev/null
else
    COMMON_PROFILE_ONLY=1
    # shellcheck source=/dev/null
    source "$COMMON"
fi

# --- X resources ---------------------------------------------------------
#
# xterm's defaults would not do: a 6x13 bitmap font, a 64-line scrollback and an
# audible bell. Every line below is here to make it draw what the other six draw.
#
#   faceName/faceSize   DejaVu Sans Mono at the group-wide size.
#   cursorBlink         false. Already xterm's default - unlike kitty's - but
#                       set explicitly, because an idle window that is not
#                       byte-identical to itself cannot be replay-verified and
#                       that is far too important to leave to a default that
#                       could change with a package update.
#   saveLines           20000, so block 3 has somewhere to scroll back to after
#                       block 2 has pushed 5,000 lines past.
#   scrollTtyOutput     false. Do NOT jump to the bottom on output: with it on,
#                       any stray write would undo block 3's scroll position
#                       between the scroll and the checkpoint.
#   every bell off      a visual bell inverts the whole window for a moment. If
#                       one fired during a capture the reference screenshot
#                       would be a photograph of the flash, and it would never
#                       reproduce.
#
# NOT set: any colour override. Block 6 renders the sixteen ANSI colours, and
# each emulator's own palette is part of what is being compared - so palettes
# are left alone and the reference screenshots differ between apps on purpose.
log "seeding X resources"
cat > /root/.Xresources <<'XRES'
XTerm*faceName:           DejaVu Sans Mono
XTerm*faceSize:           11
XTerm*cursorBlink:        false
XTerm*cursorUnderLine:    false
XTerm*saveLines:          20000
XTerm*scrollBar:          false
XTerm*scrollTtyOutput:    false
XTerm*bellIsUrgent:       false
XTerm*visualBell:         false
XTerm*marginBell:         false
XTerm*metaSendsEscape:    true
XTerm*termName:           xterm-256color
XTerm*internalBorder:     2
XTerm*utf8:               1
XTerm*locale:             true
XRES

# --- launch wrapper ------------------------------------------------------
# xrdb needs a running display, and X is started by entrypoint.sh AFTER
# install.sh. Loading the resources here would silently do nothing, so they are
# loaded by this wrapper at launch instead - which is also what replay.py
# relaunches, so a replay gets them too.
#
# write_launcher sources /etc/parrot-env first, which is what puts xterm into
# UTF-8 mode. `XTerm*utf8: 1` above says the same thing a second way; either
# alone is enough, and the cost of both is nothing against a whole group
# re-recorded because the box-drawing block was mojibake.
write_launcher xterm \
    'xrdb -load /root/.Xresources' \
    'exec xterm'

log "installed: xterm $(dpkg-query -W -f='${Version}' xterm 2>/dev/null || echo '?')"
