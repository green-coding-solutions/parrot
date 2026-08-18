#!/usr/bin/env bash
# Install Konsole and seed a profile.
#
# The only Qt entrant, and the other desktop default. Its configuration is two
# files: a profile describing the terminal, and konsolerc pointing at it and
# stripping the window chrome. Setting the profile without making it the default
# in konsolerc is the classic silent no-op here.
set -euo pipefail
PROFILE_ONLY=0
[[ "${1:-}" == "--profile-only" ]] && PROFILE_ONLY=1
log() { printf '[install-konsole] %s\n' "$*"; }

COMMON=/tmp/repo/applications/terminals/common/install-common.sh
if [[ $PROFILE_ONLY -eq 0 ]]; then
    source "$COMMON"
    log "installing konsole"
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends konsole >/dev/null
else
    COMMON_PROFILE_ONLY=1; source "$COMMON"
fi

log "seeding the Konsole profile"
mkdir -p /root/.local/share/konsole /root/.config
cat > /root/.local/share/konsole/Parrot.profile <<'PROF'
[Appearance]
Font=DejaVu Sans Mono,11,-1,5,50,0,0,0,0,0
ColorScheme=Breeze

[Cursor Options]
CursorShape=0
BlinkingCursorEnabled=false

[General]
Name=Parrot
Parent=FALLBACK/
TerminalColumns=160
TerminalRows=45
TerminalMargin=2
TerminalCenter=false

[Scrolling]
HistoryMode=2
HistorySize=20000
ScrollBarPosition=2

[Terminal Features]
BellMode=3
BlinkingTextEnabled=false
UrlHintsModifiers=0
PROF

# Without this the profile above exists and is never used - Konsole keeps
# starting the built-in default and every setting looks like it did nothing.
cat > /root/.config/konsolerc <<'RC'
[Desktop Entry]
DefaultProfile=Parrot.profile

[KonsoleWindow]
ShowMenuBarByDefault=false
RememberWindowSize=false

[MainWindow]
MenuBar=Disabled
StatusBar=Disabled
ToolBarsMovable=Disabled
RC

# --- launch wrapper ------------------------------------------------------
# Konsole needs no pre-exec step of its own, but it gets a launcher anyway so
# that every driver in the group starts its app the same way - `parrot-<app>` -
# and so that the locale in /etc/parrot-env is applied here too.
#
# --separate skips the "reuse an existing Konsole instance" path. Without it a
# second launch attaches to the first process and the new window is a tab of the
# old one, which is not what replay.py relaunched and not what was recorded.
write_launcher konsole \
    'exec konsole --separate --hide-menubar --hide-tabbar'

log "installed: konsole $(dpkg-query -W -f='${Version}' konsole 2>/dev/null || echo '?')"
