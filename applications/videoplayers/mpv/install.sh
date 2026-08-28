#!/usr/bin/env bash
# Install mpv and write its configuration.
#
# The reference entrant: libmpv driven directly, with no toolkit at all. Its
# only chrome is the OSC, a Lua script that draws the controls INTO the video
# frame, which is why it is the one entrant whose window has no widgets for
# check-image.sh to compare - the controls are pixels of the video.
set -euo pipefail
PROFILE_ONLY=0
[[ "${1:-}" == "--profile-only" ]] && PROFILE_ONLY=1
log() { printf '[install-mpv] %s\n' "$*"; }

COMMON="$(dirname "$(readlink -f "$0")")/../common/install-common.sh"
if [[ $PROFILE_ONLY -eq 0 ]]; then
    source "$COMMON"
    log "installing mpv"
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends mpv >/dev/null
else
    COMMON_PROFILE_ONLY=1; source "$COMMON"
fi

# osc=yes is explicit rather than assumed: the OSC is the ONLY seek bar mpv has,
# and the "Seek on the bar" block clicks it. It auto-hides after a second of
# pointer stillness, which is what makes it safe in a checkpoint - the driver
# parks the pointer and waits, so every capture is taken with the OSC faded out.
#
# keep-open=no is the default and is pinned anyway, because the "Play to the end
# of a clip" block depends on it: with keep-open=yes mpv holds the last frame
# instead of advancing, and that block would silently do nothing.
#
# save-position-on-quit=no keeps a recording from resuming a previous run's
# position - which would make block 1 start somewhere other than the first frame.
log "writing mpv.conf"
mkdir -p /root/.config/mpv
# autofit is the single most load-bearing line in this file, and it took two
# wrong answers to find.
#
# mpv SIZES ITS OWN WINDOW TO THE VIDEO, and fluxbox applies a pin rule only when
# a window is MAPPED - so every later resize stands. With the corpus at 1440x810
# in a 1440x900 window, the window followed the video to 1440x810, then to
# 640x360 on the small clip, all with the pin in force. Three silent
# consequences: reference images that change size mid-recording, an OSC seek bar
# that moves with the window so later bar clicks land outside it, and a block 19
# that stops testing upscaling at all, because mpv shrinks the window to the
# video instead of scaling the video to the window.
#
# `auto-window-resize=no` does NOT fix it - measured, mpv 0.37 still went to
# 640x360 across a playlist change with the option set. Two things together do:
# the corpus is 1440x900, exactly the pinned window, so five of the six clips
# give mpv nothing to resize to; and `autofit=1440x900` scales the sixth - the
# 640x400 clip - up to the window instead of shrinking the window to it, which
# is precisely what block 19 is supposed to measure.
#
# One exception remains and is expected: the aspect-override blocks ask for 4:3,
# mpv fits that inside 1440x900 as 1200x900, and blocks 11 and 12 are the only
# ones in this entrant whose window is not 1440x900.
cat > /root/.config/mpv/mpv.conf <<'CONF'
autofit=1440x900
osc=yes
keep-open=no
save-position-on-quit=no
resume-playback=no
screenshot-directory=/tmp
CONF

# --sid=no is MEASURED, not defensive. The corpus deliberately flags neither
# subtitle track default so that every entrant starts with subtitles off - and
# mpv selects the first subtitle track anyway. Its OSC read "1/2" on a clip whose
# subtitle streams both carry default=0. Without this flag mpv would be the one
# entrant drawing subtitles through blocks 2 to 7, which is a text renderer's
# worth of work per frame that no other entrant is doing.
#
# --no-terminal so mpv does not put its status line on the recorder's stdout.
# CLIPS comes from install-common.sh, which is sourced above in both branches.
cat > /usr/local/bin/parrot-mpv <<LAUNCH
#!/usr/bin/env bash
exec mpv --no-terminal --sid=no ${CLIPS}
LAUNCH
chmod +x /usr/local/bin/parrot-mpv
log "launcher written"
