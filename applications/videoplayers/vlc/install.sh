#!/usr/bin/env bash
# Install VLC and write its configuration.
#
# Two things about this entrant are not like the others.
#
# VLC REFUSES TO RUN AS ROOT - it exits before mapping a window, which looks
# exactly like a slow start - so it gets its own unprivileged user and the
# launcher drops to it. That is also why install-common.sh stages the corpus
# into /opt with world-readable permissions.
#
# Its first-run "Privacy and Network Access Policy" dialog SHARES WM_CLASS with
# the main window ("vlc", "vlc"), which is the trap AGENTS.md describes: the
# fluxbox rule that pins the main window would match the dialog too and stack it
# underneath, invisible and modal. Two independent defences below.
set -euo pipefail
PROFILE_ONLY=0
[[ "${1:-}" == "--profile-only" ]] && PROFILE_ONLY=1
log() { printf '[install-vlc] %s\n' "$*"; }

COMMON="$(dirname "$(readlink -f "$0")")/../common/install-common.sh"
if [[ $PROFILE_ONLY -eq 0 ]]; then
    source "$COMMON"
    log "installing vlc"
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends vlc >/dev/null
else
    COMMON_PROFILE_ONLY=1; source "$COMMON"
fi

id -u vlcuser >/dev/null 2>&1 || useradd -m -s /bin/bash vlcuser
mkdir -p /home/vlcuser/.config/vlc /tmp/rt-vlc
chown -R vlcuser:vlcuser /home/vlcuser /tmp/rt-vlc

# Defence 1: --no-qt-privacy-ask on the command line. MEASURED, because seeding
# qt-privacy-ask=0 into vlcrc did NOT work - VLC showed the dialog anyway - and
# the flag does. Defence 2 is the role argument to pin-windows.sh in
# usage_scenario.yml: VLC gives the main window WM_WINDOW_ROLE "vlc-main" and the
# dialog "vlc-privacy", so the pin rule is scoped to the former either way.
#
# --no-video-title-show is not cosmetic. Without it VLC draws the file name over
# the top of the video for a few seconds whenever a clip starts, so the frame at
# a checkpoint depends on how long ago the playlist advanced - a moving overlay
# in six of the twenty-two blocks.
#
# --no-qt-video-autoresize keeps VLC from growing its own window. Without it the
# window came up 1440x974 - the 1440x900 video plus its control bar - with the
# bottom 74 px off the screen, and the fluxbox pin did not hold it, because
# fluxbox applies a rule when a window MAPS and VLC resized afterwards. Same
# class of problem as mpv's autofit and Celluloid's GL surface.
#
# PULSE_SERVER is set explicitly, and has to be. VLC runs as its own user, and
# although /etc/pulse/client.conf names the socket and `pactl info` works for
# vlcuser, VLC itself reported
# `PulseAudio server connection failure: Connection refused` and fell through to
# ALSA, which has no device - `main audio output error: module not functional`,
# i.e. this entrant silently not decoding audio at all while the others did.
# With PULSE_SERVER in the environment it connects, and `pactl list short
# sink-inputs` shows it as float32le 2ch 48000Hz.
#
# --no-qt-updates-notif is NOT a VLC option, whatever it looks like. VLC 3.0.20
# refuses to start with it: `unknown option or missing mandatory argument`, and
# the launcher exits before mapping a window - which looks exactly like a slow
# start. `--no-qt-privacy-ask` is real; check with `vlc --longhelp --advanced`.
#
# --vout xcb_x11 pins the video output, because under Xvfb VLC's automatic
# choice is not stable and the video output path is a large part of what this
# group is measuring; it has to be recorded, not left to a probe.
cat > /usr/local/bin/parrot-vlc <<LAUNCH
#!/usr/bin/env bash
exec su -m vlcuser -c "XDG_RUNTIME_DIR=/tmp/rt-vlc DISPLAY=:99 \\
    PULSE_SERVER=unix:/tmp/pulse-socket exec vlc \\
    --no-qt-privacy-ask --no-video-title-show --no-qt-video-autoresize \\
    --vout xcb_x11 --no-loop --no-repeat ${CLIPS}"
LAUNCH
chmod +x /usr/local/bin/parrot-vlc
log "launcher written"
