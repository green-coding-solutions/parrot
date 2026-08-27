#!/usr/bin/env bash
# Install Totem (GNOME Videos) and write its configuration.
#
# GStreamer playbin behind GTK4. The most installed player in the table by a
# wide margin, and one of the two entrants that needs
# gstreamer1.0-plugins-bad from install-common.sh to decode the AV1 clip at all.
set -euo pipefail
PROFILE_ONLY=0
[[ "${1:-}" == "--profile-only" ]] && PROFILE_ONLY=1
log() { printf '[install-totem] %s\n' "$*"; }

COMMON="$(dirname "$(readlink -f "$0")")/../common/install-common.sh"
if [[ $PROFILE_ONLY -eq 0 ]]; then
    source "$COMMON"
    log "installing totem"
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
        totem adwaita-icon-theme libglib2.0-bin >/dev/null
else
    COMMON_PROFILE_ONLY=1; source "$COMMON"
fi

# Totem stores everything in dconf, so the launcher needs a session bus. Without
# dbus-run-session it still starts, but it also emits a stream of
# `Error retrieving accessibility bus address` warnings and its settings do not
# persist within the run.
#
# THE PLAYLIST IS ENQUEUED ONE FILE AT A TIME, and that is not a stylistic
# choice. Handing Totem all six paths at once produces a NON-DETERMINISTIC
# playlist: measured over three identical runs it started on clip 01 twice and on
# clip 02 once, having silently dropped the first item to the back. A recording
# made on a run that started on 02 would replay against one that started on 01,
# and every checkpoint in it would be wrong.
#
# `totem --enqueue` activates the running instance over D-Bus and appends exactly
# one file, so the order is the order of these lines. Two runs of the launcher
# below gave 01, 02, 03, 04 both times. The sleep before the first enqueue is
# what lets the first instance own the D-Bus name; without it the enqueues race
# the startup they are meant to follow.
# THE LAUNCHER, AND WHY ITS EXPLANATION LIVES OUT HERE
#
# Everything between the quotes below is the body of a single-quoted `bash -c`,
# so an apostrophe anywhere inside it - even in a comment - ends the string and
# the rest of the script is reparsed as something else. That is not theoretical.
# A comment in there once quoted a dbus-daemon line containing 'org.gnome.Totem'
# and the launcher went on to run `totem complai`: Totem started, mapped a
# window, played nothing, and all twenty-two reference images came out black
# while every automated signal - window present, 22 checkpoints, 22 screenshots -
# read healthy. So the body is kept free of prose and the prose is kept here.
#
# WAIT BY ASKING THE BUS WHICH NAMES EXIST; DO NOT PING THE NAME.
#
# The launcher starts Totem with the first clip and then enqueues the other five
# over D-Bus, so it has to wait for the instance to own org.gnome.Totem first. A
# fixed sleep was tried and was not long enough once: nothing was enqueued, the
# playlist stayed one item long, `n` did nothing for the rest of the recording,
# and all eight clip-change blocks captured clip 01.
#
# The obvious replacement - ping org.gnome.Totem until it answers - is worse,
# because that name is D-BUS ACTIVATABLE. A call addressed to it does not wait
# for the instance above; it STARTS A SECOND ONE. The two race for the name and
# the loser exits:
#
#   dbus-daemon: Activating service name=org.gnome.Totem requested by :1.0
#                (comm="gdbus call --session --dest org.gnome.Totem ...")
#   Totem-WARNING: Failed to register application:
#                  Unable to acquire bus name org.gnome.Totem
#
# Sometimes the loser is the activated one and nothing is wrong; sometimes it is
# the one holding the playlist, and then there is no window at all. Three
# recordings out of five died that way, each leaving a <defunct> totem and a
# .parrot with twenty events, and the only complaint anywhere was one line from
# the recorder: screenshot capture failed: window not found.
#
# ListNames is a call to the BUS, not to Totem, so it activates nothing.
cat > /usr/local/bin/parrot-totem <<'LAUNCH'
#!/usr/bin/env bash
C=/opt/parrot/video-corpus
exec dbus-run-session -- bash -c '
    totem "$1" &
    shift
    for _ in $(seq 60); do
        gdbus call --session --dest org.freedesktop.DBus \
            --object-path /org/freedesktop/DBus \
            --method org.freedesktop.DBus.ListNames 2>/dev/null \
            | grep -q "org.gnome.Totem" && break
        sleep 0.5
    done
    sleep 2
    for f in "$@"; do totem --enqueue "$f"; sleep 1; done
    wait' _ \
    "$C/01-h264-1440x900p30.mkv" "$C/02-h264-1440x900p60.mkv" \
    "$C/03-vp9-1440x900p30.mkv"  "$C/04-hevc-1440x900p30.mkv" \
    "$C/05-av1-1440x900p30.mkv"  "$C/06-h264-640x400p30.mkv"
LAUNCH
chmod +x /usr/local/bin/parrot-totem
log "launcher written"
