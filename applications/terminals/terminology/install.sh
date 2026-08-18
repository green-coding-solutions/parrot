#!/usr/bin/env bash
# Install Terminology and configure it to match the group.
#
#   install.sh                 full install
#   install.sh --profile-only  re-seed the config only, for measuring
#
# Terminology is in the group for its rendering stack: Enlightenment's EFL/Evas,
# which nothing else here uses. It is also the entrant most likely to need
# things turned OFF - its defaults include background media, a translucent
# theme and animated effects, none of which can be replay-verified.
set -euo pipefail

PROFILE_ONLY=0
[[ "${1:-}" == "--profile-only" ]] && PROFILE_ONLY=1
log() { printf '[install-terminology] %s\n' "$*"; }

COMMON=/tmp/repo/applications/terminals/common/install-common.sh
if [[ $PROFILE_ONLY -eq 0 ]]; then
    # shellcheck source=/dev/null
    source "$COMMON"
    log "installing terminology"
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends terminology dbus dbus-x11 >/dev/null
else
    COMMON_PROFILE_ONLY=1
    # shellcheck source=/dev/null
    source "$COMMON"
fi

# Terminology's own options are the ones that matter here. The probe found its
# idle screen steady out of the box, but that was with the default theme; the
# flags below pin the parts that are known to animate or sample the desktop.
log "terminology is configured on the command line; see the launcher"

# NOTE THE PIN STRING. Terminology's WM_CLASS is `"main", "terminology"` - its
# res_name is `main`, which is what fluxbox matches, so usage_scenario.yml pins
# `main`. Measured; `terminology` would match nothing.
# EFL needs BOTH buses. dbus-run-session alone was not enough: the error names
# bus type 2, the SYSTEM bus, and the container has no
# /run/dbus/system_bus_socket at all - eldbus aborts with a backtrace before any
# window is mapped. So the system bus is started first and the session bus is
# wrapped around the app.
# `dbus` and not just `dbus-x11`: the system bus refuses to start without
# /usr/share/dbus-1/system.conf, which only the former ships. dbus-uuidgen
# --ensure is needed too - the daemon wants a machine id before it will listen.
write_launcher terminology \
    'mkdir -p /run/dbus' \
    'dbus-uuidgen --ensure >/dev/null 2>&1 || true' \
    'dbus-daemon --system --fork >/dev/null 2>&1 || true' \
    'exec dbus-run-session -- terminology --font "DejaVu Sans Mono/11" --no-wizard --disable-visual-bell --disable-media-visualize'

log "installed: terminology $(dpkg-query -W -f='${Version}' terminology 2>/dev/null || echo '?')"
