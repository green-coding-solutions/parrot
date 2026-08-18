#!/usr/bin/env bash
# Put the scenario's upload image on the X clipboard and keep it there.
#
#   seed-clipboard.sh [path]        default: /tmp/parrot.png
#
# RUNS ON window-container, as the LAST setup-command - after entrypoint.sh,
# because it needs the X server that entrypoint.sh starts. Ordering it before
# entrypoint.sh gives "Error: Can't open display: :99" and an empty clipboard,
# which block 17 cannot tell apart from a working one.
#
# WHY THE CLIPBOARD AND NOT THE FILE CHOOSER
#
# Block 17 of script.md attaches an image to the composer. For the two Electron
# clients and for nheko that is the client's file chooser. For Fractal - GTK4 in
# a Flatpak - the chooser is the XDG portal, and the portal hands the file over
# through the document portal, which is a FUSE filesystem whose mount needs
# CAP_SYS_ADMIN. This group runs its containers WITHOUT SYS_ADMIN on purpose
# (commit cbe1099), and buying block 17 back with it would undo that for the
# Flatpak entrants.
#
# Pasting measures the part of the block that matters - the client encodes and
# uploads the same 762 kB image and renders the same thumbnail - without the
# capability. What it does NOT measure is the file chooser itself, and the event
# arrives named `image.png` rather than `parrot.png` because a clipboard image
# has no filename. Both are stated in ../fractal/MEASUREMENTS.md and both have
# to be stated in the results: this block is not like-for-like with the clients
# that go through a chooser.
#
# WHY IT MUST KEEP RUNNING
#
# X11 has no clipboard daemon. The selection is owned by a live client, and when
# that client exits the clipboard is EMPTY - there is no stored copy. So xclip
# is left running for the whole session rather than being fired and forgotten.
# If it dies, block 17 pastes nothing, the composer stays empty, and the run
# looks fine right up until the ground-truth check finds no m.image event.
set -euo pipefail

IMAGE="${1:-/tmp/parrot.png}"
export DISPLAY="${DISPLAY:-:99}"

[[ -f "$IMAGE" ]] || { echo "[seed-clipboard] no such file: $IMAGE" >&2; exit 1; }

if ! command -v xclip >/dev/null 2>&1; then
    echo "[seed-clipboard] installing xclip"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq >/dev/null 2>&1
    apt-get install -y -qq --no-install-recommends xclip >/dev/null 2>&1
fi

# Owned by the same uid the application runs as. A selection owned by root and
# requested by uid 1001 is served fine by X, but keeping them the same avoids a
# difference that would only ever show up as an empty paste.
APP_UID=1001
if ! id -u "$APP_UID" >/dev/null 2>&1; then
    echo "[seed-clipboard] uid ${APP_UID} does not exist - run install-flatpak.sh first" >&2
    exit 1
fi
chmod 644 "$IMAGE"

# Start it, then READ IT BACK, and retry the pair until it takes.
#
# The retry is because the X server may still be seconds away: entrypoint.sh
# backgrounds Xvfb, and an xclip that starts too early just exits. Deliberately
# NOT gated on `xdpyinfo` first - that lives in x11-utils, which only the
# --measure path of setup-container.sh installs, so a check written that way
# would work while measuring and fail in the benchmark it is supposed to guard.
#
# The read-back is the point. `xclip -i` forks and returns 0 whether or not it
# ever took ownership of the selection, so its exit code proves nothing. This
# loop is the only thing standing between a dead clipboard and a block 17 that
# pastes into an empty composer and reports success.
ok=
for _ in $(seq 1 20); do
    pkill -u "$APP_UID" -x xclip >/dev/null 2>&1 || true
    setsid setpriv --reuid "$APP_UID" --regid "$APP_UID" --init-groups \
        env DISPLAY="$DISPLAY" xclip -selection clipboard -t image/png -i "$IMAGE" \
        >/dev/null 2>&1 < /dev/null &
    sleep 2
    if xclip -selection clipboard -t TARGETS -o 2>/dev/null | grep -qx 'image/png'; then
        ok=1
        break
    fi
done
[[ -n "$ok" ]] || { echo "[seed-clipboard] FAILED: no image/png on the clipboard after 20 tries" >&2; exit 1; }

bytes="$(xclip -selection clipboard -t image/png -o 2>/dev/null | wc -c)"
if [[ "${bytes:-0}" -lt 1000 ]]; then
    echo "[seed-clipboard] FAILED: clipboard image is ${bytes} bytes" >&2
    exit 1
fi

echo "[seed-clipboard] image/png on the clipboard, ${bytes} bytes, from ${IMAGE}"
