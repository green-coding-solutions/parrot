#!/usr/bin/env bash
# Build the six-clip video-player corpus from Big Buck Bunny.
#
# AUTHOR TIME, NOT MEASUREMENT TIME. Run this once, commit what it writes into
# corpus/, and never run it again unless the corpus is deliberately changing -
# a re-encode changes every bitstream, and with it every decode cost and every
# reference screenshot in the group.
#
# Run it inside the benchmark image so the encoder is the one that is pinned:
#
#   docker run --rm -v "$PWD:/w" -w /w ribalba/xwindow-server \
#       bash applications/videoplayers/make-corpus.sh
#
# Source: Big Buck Bunny (c) 2008 Blender Foundation, CC BY 3.0,
# https://peach.blender.org - the "Sunflower" re-render, which is the only
# official release that is natively 60 fps and carries two audio tracks.
set -euo pipefail

HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
OUT="$HERE/corpus"
WORK="${WORK:-/tmp/parrot-video-master}"

URL="https://download.blender.org/demo/movies/BBB/bbb_sunflower_1080p_60fps_normal.mp4.zip"
ZIP_SHA256="68c456673409f8df09b80d0afe29ecb38ef110551fa8a93c83e54a96ebdaec78"
MASTER="$WORK/bbb_sunflower_1080p_60fps_normal.mp4"

# THE VIDEO IS EXACTLY THE SCREEN: 1440x900, the size pin-windows.sh pins every
# entrant's window to. That is not tidiness, it is what keeps the group stable.
# A 16:9 frame in a 16:10 window leaves a letterbox, and a letterbox means the
# video's size and the window's size are two different numbers - which mpv
# resolves by RESIZING ITS OWN WINDOW to the video. Measured: with a 1440x810
# corpus mpv's window went to 1440x810, to 640x360 on the small clip and to
# 1200x900 on the aspect-override block, all with the fluxbox pin still in force,
# because fluxbox applies a pin when a window is MAPPED and mpv resized later.
# At 1440x900 the video fills the window exactly and there is nothing to resize
# to.
#
# BBB is 16:9, so getting there means a centre crop to 16:10 (1728x1080 out of
# 1920x1080) and then a scale. That drops 10% of the width. The alternative -
# stretching - would change every shape on screen, and a benchmark that measures
# a scaler should not also be measuring a distortion.
#
# Nothing in the group is 4K: the point is to measure decoding and drawing, not
# to measure a downscaler that only one clip would have exercised.
W=1440; H=900
CROP=1728:1080          # 16:10 out of the master's 16:9, centred

# 300 s in is forest canopy - dense foliage, camera motion, no cuts. It encodes
# like real footage instead of like a synthetic pattern, which is the whole
# reason for using a film rather than `testsrc2`.
# Durations are the size knob, and they are the RIGHT size knob. Quality is not
# touched: at CRF 26 these run around 1.6 Mbit/s, which is what film content at
# this size really costs to decode, and lowering it would quietly make every
# entrant look better. Shortening the clips costs measurement time instead, and
# the whole corpus fits in ~24 MB - about what one existing group's assets take.
# LONG is 50 and not 30 because FIVE blocks play from clip 01 - 02, 05, 08, 10
# and 13 - and the seek blocks move the position around between them. At 30 s the
# clip ran out during block 5, the playlist advanced on its own, and every block
# after it was recorded against the wrong file while every automated signal still
# looked healthy. The burnt-in clip labels are what caught it. The worst case is
# now: block 4 leaves the position at a quarter (12.5 s), then 6+6+6+10 s of
# playing lands at 40.5 s, 9.5 s clear of the end.
START=300
LONG=50      # clip 01: blocks 2, 5, 8, 10 and 13 all play from it
SHORT=15     # clips 02-06: their blocks play 10 s each

# ONE KEYFRAME PER SECOND IN EVERY CLIP, AND THE SAME ONE IN EVERY CODEC.
#
# The first corpus set no GOP at all, so each encoder used its own default and
# the six clips ended up with keyframes this far apart:
#
#   02-h264-60p   5 keyframes   mean gap 3.00 s
#   03-vp9        4 keyframes   mean gap 3.76 s
#   05-av1        3 keyframes   mean gap 5.01 s
#   04-hevc       2 keyframes   mean gap 7.51 s   <- 0.00 s and 8.33 s, nothing else
#
# That is a confound sitting directly on the axis this group exists to measure.
# A seek into the HEVC clip makes the decoder chew through up to 8.3 s of frames
# to reach the target; the same seek into the 60 fps H.264 clip costs at most
# 4.2 s of much cheaper ones. Blocks 2 to 21 seek twenty-odd times, so "HEVC
# costs more than VP9" was partly a statement about x265's default keyint.
#
# IT ALSO BROKE THE REFERENCE IMAGES, which is what found it. Seek while PAUSED
# to a position far from a keyframe and some players show the target frame
# decoded without its references: a flat grey field with scattered blocks of
# garbage. Kaffeine does it every time, and blocks 13 and 14 of its recording
# were two identical pictures of that. Re-encoding one clip with the cadence
# below and changing nothing else, the same seeks render clean frames and the
# forward steps all land - measured, before this line was written.
#
# force_key_frames is used rather than -g because it is the one spelling all four
# encoders honour identically; -g means subtly different things to x264, x265,
# vpx and svt-av1. Scene detection is disabled alongside it so the cadence is
# exactly this and not this plus whatever each encoder thought was a cut.
KEYINT=1
FORCE_KEY=(-force_key_frames "expr:gte(t,n_forced*${KEYINT})")

FONT=/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf

log() { printf '[make-corpus] %s\n' "$*"; }

for bin in ffmpeg ffprobe curl unzip sha256sum; do
    command -v "$bin" >/dev/null || { echo "missing: $bin" >&2; exit 1; }
done
[[ -f "$FONT" ]] || { echo "missing font: $FONT (apt-get install fonts-dejavu-core)" >&2; exit 1; }

mkdir -p "$OUT" "$WORK"

# --- the master ------------------------------------------------------------
if [[ ! -f "$MASTER" ]]; then
    log "fetching the master (355 MB, once)"
    curl -fSL -A "Mozilla/5.0" -o "$WORK/master.zip" "$URL"
    echo "$ZIP_SHA256  $WORK/master.zip" | sha256sum -c -
    unzip -o -q "$WORK/master.zip" -d "$WORK"
    rm -f "$WORK/master.zip"
fi
log "master: $(ffprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate -of csv=p=0 "$MASTER")"

# --- subtitles -------------------------------------------------------------
# Two tracks, generated rather than borrowed, because they have to be legible at
# a glance in a reference screenshot and they have to say WHERE they are. A cue
# every five seconds carries its own start time, so a paused frame with a
# subtitle on it proves both that subtitles are on and which one is showing.
write_srt() {
    local path="$1" dur="$2" lang="$3" n=1 t=0
    : > "$path"
    while (( t < dur )); do
        printf '%d\n' "$n"                                     >> "$path"
        printf '00:%02d:%02d,500 --> 00:%02d:%02d,500\n' \
            $((t/60)) $((t%60)) $(((t+4)/60)) $(((t+4)%60))     >> "$path"
        if [[ "$lang" == eng ]]; then
            printf 'English subtitle %d - %02d:%02d\n\n' "$n" $((t/60)) $((t%60)) >> "$path"
        else
            printf 'Deutscher Untertitel %d - %02d:%02d\n\n' "$n" $((t/60)) $((t%60)) >> "$path"
        fi
        n=$((n+1)); t=$((t+5))
    done
}

# --- one clip --------------------------------------------------------------
# NEITHER SUBTITLE TRACK IS FLAGGED DEFAULT. ffmpeg marks the first stream of
# each type default unless told otherwise, and a default-flagged subtitle track
# is auto-selected by mpv, Totem and others - so blocks 2 to 7 would have run
# with subtitles drawn in some entrants and not in others, which is a rendering
# difference the script never asked for. Clearing the flag makes every entrant
# start with subtitles off; block 8 is what turns them on. The first AUDIO track
# is flagged default and the second explicitly is not, because every entrant is
# meant to start on the English stereo track. Both had to be set: the master's
# own tracks are both flagged default and ffmpeg carries that through, so
# without the second half of the pair the entrants were free to pick either.
#
# Every clip carries the same burnt-in label and running timecode. The label is
# what makes five otherwise identical codec blocks distinguishable in a
# screenshot; the timecode is what makes a paused frame say which frame it is.
# The content underneath is the same seconds of film in every clip, so the codec
# axis is not confounded by what is happening on screen.
encode() {
    local name="$1" dur="$2" fps="$3" w="$4" h="$5"; shift 5
    local eng="$WORK/$name.eng.srt" ger="$WORK/$name.ger.srt"
    write_srt "$eng" "$dur" eng
    write_srt "$ger" "$dur" ger

    local label="${name%.mkv}"
    local vf="fps=${fps},crop=${CROP},scale=${w}:${h}:flags=lanczos"
    vf+=",drawtext=fontfile=${FONT}:text='${label}':x=16:y=16:fontsize=$((h/34))"
    vf+=":fontcolor=white:box=1:boxcolor=black@0.65:boxborderw=8"
    vf+=",drawtext=fontfile=${FONT}:text='%{pts\\:hms}':x=16:y=$((16+h/22)):fontsize=$((h/34))"
    vf+=":fontcolor=white:box=1:boxcolor=black@0.65:boxborderw=8"

    log "encoding $name"
    ffmpeg -y -loglevel error -nostats \
        -ss "$START" -t "$dur" -i "$MASTER" -i "$eng" -i "$ger" \
        -map 0:v:0 -map 0:a:0 -map 0:a:1 -map 1:0 -map 2:0 \
        -vf "$vf" -pix_fmt yuv420p "${FORCE_KEY[@]}" "$@" \
        -c:a:0 aac -b:a:0 96k -ac:0 2 \
        -c:a:1 aac -b:a:1 160k \
        -c:s srt \
        -disposition:a:0 default -disposition:a:1 0 \
        -disposition:s:0 0 -disposition:s:1 0 \
        -map_metadata -1 \
        -metadata title="$label" \
        -metadata:s:a:0 language=eng -metadata:s:a:1 language=ger \
        -metadata:s:s:0 language=eng -metadata:s:s:1 language=ger \
        -metadata:s:v:0 title="$label" \
        "$OUT/$name"
}

# The per-encoder half of the keyframe cadence. force_key_frames above puts a
# keyframe on every whole second; these stop each encoder ADDING more of its own
# at scene cuts, which would put the six clips back on different cadences - the
# film cuts in the same places in all of them, but x264, x265, vpx and svt-av1
# disagree about what counts as a cut.
X264_KEY=(-x264-params "keyint=30:min-keyint=30:scenecut=0")
X264_KEY60=(-x264-params "keyint=60:min-keyint=60:scenecut=0")
X265_KEY=(-x265-params "keyint=30:min-keyint=30:scenecut=0")
VP9_KEY=(-g 30 -keyint_min 30)
AV1_KEY=(-svtav1-params "keyint=30:scd=0")

# 01 baseline: native size, 30 fps, the codec everything decodes
encode 01-h264-1440x900p30.mkv "$LONG"  30 $W $H -c:v libx264 -preset slow -crf 26 "${X264_KEY[@]}"
# 02 frame rate: the same seconds at twice the frames, natively 60 fps in the master
encode 02-h264-1440x900p60.mkv "$SHORT" 60 $W $H -c:v libx264 -preset slow -crf 26 "${X264_KEY60[@]}"
# 03-05 decoder: same content, same size, same frame rate, three other bitstreams
encode 03-vp9-1440x900p30.mkv  "$SHORT" 30 $W $H -c:v libvpx-vp9 -crf 34 -b:v 0 -cpu-used 2 -row-mt 1 "${VP9_KEY[@]}"
encode 04-hevc-1440x900p30.mkv "$SHORT" 30 $W $H -c:v libx265 -preset slow -crf 28 "${X265_KEY[@]}"
encode 05-av1-1440x900p30.mkv  "$SHORT" 30 $W $H -c:v libsvtav1 -preset 6 -crf 38 "${AV1_KEY[@]}"
# 06 scaling: cheap to decode, but every player has to upscale it 2.25x to the
# window - and it is 16:10 like the rest, so the upscale is the only difference
encode 06-h264-640x400p30.mkv  "$SHORT" 30 640 400 -c:v libx264 -preset slow -crf 26 "${X264_KEY[@]}"

# The cadence is ASSERTED, not assumed. A silently-ignored -x265-params would put
# the group straight back where it started, and nothing downstream would say so.
log "keyframe cadence:"
for f in "$OUT"/*.mkv; do
    n=$(ffprobe -v error -select_streams v:0 -show_entries packet=pts_time,flags \
        -of csv=p=0 "$f" | awk -F, '$2 ~ /^K/ {c++} END {print c+0}')
    d=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$f")
    printf '  %-32s %3d keyframes in %5.1f s\n' "$(basename "$f")" "$n" "$d"
done

log "corpus:"
( cd "$OUT" && ls -l *.mkv && echo "total $(du -sh . | cut -f1)" )
