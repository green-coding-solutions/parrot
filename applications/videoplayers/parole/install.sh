#!/usr/bin/env bash
# Install Parole and write its configuration.
#
# The second GStreamer entrant, GTK3 and Xfce's default. It is the reason the
# script has no playback-speed and no screenshot block: it has neither, and
# dropping two blocks was the right trade against dropping an entrant with
# 24,983 installs.
set -euo pipefail
PROFILE_ONLY=0
[[ "${1:-}" == "--profile-only" ]] && PROFILE_ONLY=1
log() { printf '[install-parole] %s\n' "$*"; }

COMMON="$(dirname "$(readlink -f "$0")")/../common/install-common.sh"
if [[ $PROFILE_ONLY -eq 0 ]]; then
    source "$COMMON"
    log "installing parole"
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends parole >/dev/null
else
    COMMON_PROFILE_ONLY=1; source "$COMMON"
fi

# Parole reads its settings through xfconf, which needs a session bus of its
# own; without one it falls back to defaults every run, which is at least
# consistent but leaves the playlist pane open on some starts and not others.
# SUBTITLES OFF AT STARTUP, written before the first run.
#
# Parole selects the first subtitle track even though the corpus flags neither
# track default, so without this it draws English subtitles through blocks 2 to
# 7 while the other entrants draw none - a rendering difference the script never
# asked for. mpv solves the same problem with --sid=no; Parole's equivalent is
# the xfconf property its own preferences dialog writes.
#
# It used to be done in block 1 instead, with three clicks through
# Video -> Subtitles -> None, and that is what made this entrant the one
# recording in the group that would not replay AT ALL: xmacrorec2 records the
# pointer's arrival and the button press as one event about 25 us apart, so the
# 0.8 s the driver dwells over a menu item is folded into the wait BEFORE the
# move and is not replayed. The submenu that had opened on hover while recording
# was not open on replay, the click for "None" missed, the menu kept the grab,
# and the Space and the seek that followed went into it. Block 1 ended 38 s into
# a clip that should have been at 00:00:00.000.
#
# A setting has no hover.
mkdir -p /root/.config/xfce4/xfconf/xfce-perchannel-xml
cat > /root/.config/xfce4/xfconf/xfce-perchannel-xml/parole.xml <<'XFCONF'
<?xml version="1.0" encoding="UTF-8"?>

<channel name="parole" version="1.0">
  <property name="subtitles" type="empty">
    <property name="enabled" type="bool" value="false"/>
  </property>
</channel>
XFCONF
log "subtitles disabled at startup"

cat > /usr/local/bin/parrot-parole <<LAUNCH
#!/usr/bin/env bash
exec dbus-run-session -- parole ${CLIPS}
LAUNCH
chmod +x /usr/local/bin/parrot-parole
log "launcher written"
