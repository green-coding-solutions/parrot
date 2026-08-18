#!/usr/bin/env bash
# Install GNOME Terminal and seed its dconf profile.
#
# TWO THINGS MAKE THIS THE AWKWARD ENTRANT, and both were measured:
#
#   1. IT REFUSES TO START WITHOUT A UTF-8 LOCALE.
#        Non UTF-8 locale (ANSI_X3.4-1968) is not supported!
#      and no window ever appears. The container image ships no locales at all,
#      which is why install-common.sh runs locale-gen for the whole group.
#
#   2. THE WINDOW BELONGS TO gnome-terminal-server, NOT TO gnome-terminal.
#        WM_CLASS(STRING) = "gnome-terminal-server", "Gnome-terminal"
#      so the fluxbox pin rule takes `gnome-terminal-server` and xdotool takes
#      `gnome-terminal`. Two different strings for one window; neither works in
#      the other's place.
#
# It also needs a session bus, which the startcommand provides with
# dbus-run-session - see usage_scenario.yml.
set -euo pipefail
PROFILE_ONLY=0
[[ "${1:-}" == "--profile-only" ]] && PROFILE_ONLY=1
log() { printf '[install-gnome-terminal] %s\n' "$*"; }

COMMON=/tmp/repo/applications/terminals/common/install-common.sh
if [[ $PROFILE_ONLY -eq 0 ]]; then
    source "$COMMON"
    log "installing gnome-terminal"
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
        gnome-terminal dbus-x11 dconf-cli >/dev/null
else
    COMMON_PROFILE_ONLY=1; source "$COMMON"
fi

# Seeded through the dconf SYSTEM database rather than the user one, for exactly
# the reason the spreadsheet group seeded Gnumeric that way: READING dconf needs
# no bus, WRITING it does, and there is no bus at install time. A system-db
# keyfile plus `dconf update` needs neither.
PROFILE_ID=b1dcc9dd-5262-4d8d-a863-c897e6d979b9
log "seeding the dconf system database"
mkdir -p /etc/dconf/db/local.d /etc/dconf/profile
cat > /etc/dconf/profile/user <<'DP'
user-db:user
system-db:local
DP
cat > /etc/dconf/db/local.d/00-parrot <<CONF
[org/gnome/terminal/legacy]
default-show-menubar=false
theme-variant='dark'
schema-version=uint32 3

[org/gnome/terminal/legacy/profiles:]
default='${PROFILE_ID}'
list=['${PROFILE_ID}']

[org/gnome/terminal/legacy/profiles:/:${PROFILE_ID}]
visible-name='Parrot'
use-system-font=false
font='DejaVu Sans Mono 11'
cursor-blink-mode='off'
cursor-shape='block'
scrollback-unlimited=false
scrollback-lines=20000
scrollbar-policy='never'
scroll-on-output=false
scroll-on-keystroke=true
audible-bell=false
use-theme-colors=true
default-size-columns=160
default-size-rows=45
CONF
dconf update
log "dconf seeded: $(dconf read /org/gnome/terminal/legacy/profiles:/:${PROFILE_ID}/font 2>/dev/null || echo '<unreadable>')"

# --- launch wrapper ------------------------------------------------------
# GNOME Terminal needs a session bus and there is none in the container.
# --wait keeps the launching process alive until the window closes, so that
# replay.py's process supervision sees the terminal rather than a client that
# exits immediately after handing off to gnome-terminal-server.
#
# The locale from /etc/parrot-env is not optional for this one: without a UTF-8
# locale gnome-terminal prints `Non UTF-8 locale (ANSI_X3.4-1968) is not
# supported!` and exits, and no window ever appears.
write_launcher gnome-terminal \
    'exec dbus-run-session -- gnome-terminal --wait'

log "installed: gnome-terminal $(dpkg-query -W -f='${Version}' gnome-terminal 2>/dev/null || echo '?')"
