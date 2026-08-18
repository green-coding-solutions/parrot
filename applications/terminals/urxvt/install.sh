#!/usr/bin/env bash
# Install rxvt-unicode and seed its X resources.
#
# The other raw-Xlib entrant, and the one that corrected an assumption: I
# expected 9.31 to lack 24-bit colour and it does not - Ubuntu's build renders
# #119955 exactly. Had that been taken on trust, block 7 would have been cut
# from the script for the whole group for no reason. See the group README.
set -euo pipefail
PROFILE_ONLY=0
[[ "${1:-}" == "--profile-only" ]] && PROFILE_ONLY=1
log() { printf '[install-urxvt] %s\n' "$*"; }

COMMON=/tmp/repo/applications/terminals/common/install-common.sh
if [[ $PROFILE_ONLY -eq 0 ]]; then
    source "$COMMON"
    log "installing rxvt-unicode"
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends rxvt-unicode >/dev/null
else
    COMMON_PROFILE_ONLY=1; source "$COMMON"
fi

# urxvt takes its font as an Xft string rather than a name and a size, and it
# needs boldFont set separately or it synthesises bold by overstriking - which
# looks different from DejaVu's real bold face and would show in block 5.
#
# scrollBar off and scrollTtyOutput off for the same reasons as xterm's.
# urgentOnBell/visualBell off: urxvt's visual bell inverts the window.
log "seeding X resources"
cat > /root/.Xresources <<'XRES'
URxvt.font:               xft:DejaVu Sans Mono:size=11
URxvt.boldFont:           xft:DejaVu Sans Mono:bold:size=11
URxvt.italicFont:         xft:DejaVu Sans Mono:italic:size=11
URxvt.cursorBlink:        false
URxvt.cursorUnderline:    false
URxvt.saveLines:          20000
URxvt.scrollBar:          false
URxvt.scrollTtyOutput:    false
URxvt.urgentOnBell:       false
URxvt.visualBell:         false
URxvt.internalBorder:     2
URxvt.termName:           rxvt-unicode-256color
URxvt.intensityStyles:    false
XRES

# --- launch wrapper ------------------------------------------------------
# Same reason as xterm's: xrdb has no display at install time. The locale comes
# from /etc/parrot-env, which write_launcher sources - urxvt, like xterm, decides
# its UTF-8 mode from its own environment at startup and draws mojibake without
# it.
write_launcher urxvt \
    'xrdb -load /root/.Xresources' \
    'exec urxvt'

log "installed: rxvt-unicode $(dpkg-query -W -f='${Version}' rxvt-unicode 2>/dev/null || echo '?')"
