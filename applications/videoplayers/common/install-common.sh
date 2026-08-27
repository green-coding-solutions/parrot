#!/usr/bin/env bash
# Everything the seven players need in common. Each app's install.sh sources
# this and then adds only its own packages and configuration, because the shared
# half is not a detail: if the entrants do not get the same decoders, the same
# audio device and the same corpus, the benchmark measures those instead of the
# player.
#
#   source install-common.sh          install the shared half
#   COMMON_PROFILE_ONLY=1 source ...  re-stage the corpus only
set -euo pipefail

clog() { printf '[install-common] %s\n' "$*"; }

if [[ "${COMMON_PROFILE_ONLY:-0}" -eq 0 ]]; then
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

# gstreamer1.0-plugins-bad is NOT optional and it is NOT a recommend of either
# GStreamer entrant. Without it Totem and Parole fail the AV1 clip outright -
#
#   Missing plugin: gstreamer|1.0|totem|AV1 decoder
#
# - while VLC and every mpv-based entrant play it, because those carry their own
# dav1d. The symptom is a blank window on one block in two of seven entrants,
# which reads as "the player is slow to load" rather than as a missing codec.
# HEVC and VP9 need only gstreamer1.0-libav, which both already pull in.
#
# alsa-utils is kept for `aplay -l`, which is how you confirm there is still no
# sound card - the point being that the entrants reach a working device anyway.
clog "installing the shared dependencies"
apt-get install -y -qq --no-install-recommends \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-libav \
    fonts-dejavu-core fontconfig \
    alsa-utils \
    x11-xserver-utils \
    >/dev/null

# --- the audio device ------------------------------------------------------
#
# The container has no sound card, and without a working device that fact reaches
# the entrants in seven different ways: VLC and Kaffeine probe PulseAudio, fail,
# try ALSA, fail, and print `main audio output error: no suitable audio output
# module`, at which point they are not decoding audio at all; mpv fails
# differently; Totem and Parole take a third path through autoaudiosink. Whether
# the second audio track is even decoded stops being the same question in each
# entrant, and that difference would sit inside the numbers.
#
# A NULL ALSA DEVICE IS NOT THE ANSWER, THOUGH IT LOOKS LIKE ONE. With
# `pcm.!default { type null }` every entrant does open a device - mpv reports
# `AO: [alsa]` and speaker-test succeeds - and mpv plays correctly. Totem does
# not: it froze at 00:00:29.967 and stayed there for thirty seconds of
# observation. Removing the file and changing nothing else, the same clip played
# straight through: 6.1 s, 13.6 s, 21.0 s at six-second intervals. ALSA's null
# plugin discards the samples without pacing them, and GStreamer slaves the
# pipeline clock to the audio sink, so the clock stalls and the video stops with
# it. The failure is silent, it looks exactly like a slow decoder, and it would
# have been baked into the reference images of both GStreamer entrants.
#
# PulseAudio's null sink is a real sink with a real timer-based clock. Measured
# against the same clip: 4.3 s, 11.0 s, 18.2 s at six-second intervals, and
# `pactl list short sink-inputs` shows the player connected as
# `float32le 2ch 48000Hz` - which is also the only ground truth in this group
# that audio is being decoded at all, since no screenshot can show it.
#
# auth-anonymous=1 on a fixed socket is what lets VLC reach it: VLC refuses to
# run as root and so runs as its own user, which has no access to root's session.
clog "installing pulseaudio"
apt-get install -y -qq --no-install-recommends pulseaudio pulseaudio-utils >/dev/null

mkdir -p /etc/pulse
cat > /etc/pulse/parrot.pa <<'PA'
.fail
load-module module-null-sink sink_name=parrot sink_properties=device.description=Parrot
set-default-sink parrot
load-module module-native-protocol-unix auth-anonymous=1 socket=/tmp/pulse-socket
PA

# Every PulseAudio client reads client.conf, including the one running as
# vlcuser, so the server address is configured once here rather than exported in
# seven launchers. autospawn=no keeps a client from starting a second, private
# daemon when it cannot reach this one - which would look like it worked and
# would not be the same sink.
cat > /etc/pulse/client.conf <<'PC'
default-server = unix:/tmp/pulse-socket
autospawn = no
PC

# Nothing here writes /etc/asound.conf. If an earlier install left one, it has to
# go: ALSA's default would otherwise still be the null device for anything that
# reaches for ALSA directly.
rm -f /etc/asound.conf

clog "starting the null sink"
pkill -x pulseaudio 2>/dev/null || true
sleep 1
pulseaudio --system --daemonize --disallow-exit --exit-idle-time=-1 \
    -n --file=/etc/pulse/parrot.pa --log-target=file:/tmp/pulseaudio.log >/dev/null 2>&1
sleep 3

if ! pactl info >/dev/null 2>&1; then
    echo "[install-common] the null sink did not come up; see /tmp/pulseaudio.log" >&2
    exit 1
fi
clog "null sink is live: $(pactl info | sed -n 's/^Default Sink: //p')"
fi   # end of the install half

# --- the corpus ------------------------------------------------------------
#
# Staged out of the repository mount and into the image, for two reasons. The
# path stops depending on where GMT happened to mount the checkout, and - the
# one that actually forced it - VLC runs as its own unprivileged user, so the
# files have to be readable by somebody other than root.
#
# Copied rather than symlinked: a player that follows a symlink out of /opt and
# into /tmp/repo would be reading across a bind mount, and the first block of
# every recording would be timing the mount rather than the demuxer.
CORPUS_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/corpus"
CORPUS=/opt/parrot/video-corpus
clog "staging the corpus into ${CORPUS}"
mkdir -p "$CORPUS"
cp -f "$CORPUS_SRC"/*.mkv "$CORPUS/"
chmod 755 /opt/parrot "$CORPUS"
chmod 644 "$CORPUS"/*.mkv

# The playlist every entrant is launched with, in this order, as one string.
# Sourcing this file gives a launcher $CLIPS to hand to the player - so the
# playlist is defined once, and an entrant cannot quietly get a different one.
CLIPS="$CORPUS/01-h264-1440x900p30.mkv $CORPUS/02-h264-1440x900p60.mkv"
CLIPS="$CLIPS $CORPUS/03-vp9-1440x900p30.mkv $CORPUS/04-hevc-1440x900p30.mkv"
CLIPS="$CLIPS $CORPUS/05-av1-1440x900p30.mkv $CORPUS/06-h264-640x400p30.mkv"
export CORPUS CLIPS

ls "$CORPUS"/*.mkv >/dev/null || { echo "[install-common] corpus staging failed" >&2; exit 1; }
clog "corpus staged: $(ls -1 "$CORPUS"/*.mkv | wc -l) clips"
