#!/usr/bin/env bash
# Record applications/chatclients/fractal/fractal.parrot end to end.
#
# Tears both containers down and rebuilds them through the scenario's own
# setup-commands first. A recording made against containers that have already
# been driven once is a recording of the second run: the account has already
# joined the lobby, the reply and the reaction are already on the anchor
# message, the drip burst is already in the firehose room, and the reference
# images show a state the first replay will never be in.
#
# That matters more here than in the other groups, because the state lives on
# the SERVER - and more again for Fractal than for the other four, because its
# account-recovery state is server state too. Touch the recovery prompt once and
# every later launch opens block 3 on "Reset Account Recovery" instead of "Set
# Up Account Recovery", with different buttons in different places. Wiping the
# Flatpak profile does NOT undo it; only rebuilding the homeserver does, which
# is what this script does before anything else.
set -euo pipefail

REPO=/home/didi/code/parrot
CLIENT=fractal
cd "$REPO"

echo "=== rebuilding both containers from usage_scenario.yml ==="
bash "applications/chatclients/common/setup-container.sh" "$CLIENT"

echo "=== starting the recorder ==="
# windowclass `fractal` is the MAIN window's res_name, read back off the running
# window: WM_CLASS(STRING) = "fractal", "fractal". NOT the Flatpak ref
# `org.gnome.Fractal`, which would match nothing - and matching nothing is
# silent: fluxbox applies no rule and the window maps at 766x639 wherever it
# likes instead of 1440x900 at the origin. Measured.
#
# The startcommand is the flatpak-session wrapper from
# ../common/install-flatpak.sh: it drops to uid 1001 (which is what lets the
# container keep Docker's default capability set), starts a session bus, unlocks
# a secret service on that same bus, and sets XDG_CURRENT_DESKTOP so
# xdg-desktop-portal picks an implementation. Without the last one Fractal stops
# on a full-window "Secret Portal Error" and never reaches its welcome screen.
./record-macro.py \
    --script applications/chatclients/script.md \
    --startcommand 'flatpak-session flatpak run org.gnome.Fractal' \
    --windowtitle 'Fractal' \
    --windowclass fractal \
    "applications/chatclients/${CLIENT}/${CLIENT}.parrot" &
RECORDER=$!

# The recorder launches the client and arms xmacrorec2; give both time to come
# up before any event is sent, or the first block is recorded without its
# opening keystrokes. Same 20 s as the other three, deliberately: this is
# measured time, so a client with a longer head burns more energy for no reason
# of its own. Fractal's actual readiness is waited for in drive-scenario.sh,
# which polls the screen rather than guessing.
sleep 20

bash "applications/chatclients/${CLIENT}/drive-scenario.sh"

# STOP THE RECORDER. xmacrorec2 exits on the stop keysym and on nothing else, so
# without this `wait` below blocks forever and the run looks like it is still
# recording long after the last checkpoint was written. That happened once and
# cost a night: the driver had finished at 23:12 and the script was still
# sitting in `wait` the next morning.
#
# The settle first, because the stop key must not arrive before the last
# checkpoint's screenshot has been captured.
sleep 5
docker exec -e DISPLAY=:99 window-container \
    xdotool key --clearmodifiers "${STOP_KEYSYM:-Pause}" || true

wait "$RECORDER" || true
echo "=== recorded ==="
grep -c '^check ' "applications/chatclients/${CLIENT}/${CLIENT}.parrot" \
    | sed 's/^/  checkpoints: /'
ls -1 "applications/chatclients/${CLIENT}/${CLIENT}"-check-*.png 2>/dev/null \
    | wc -l | sed 's/^/  screenshots: /'

echo "=== ground truth (the server, not the screenshots) ==="
TRUTH() {
    docker exec matrix-container python3 \
        /tmp/repo/applications/chatclients/common/matrix-truth.py \
        --homeserver http://127.0.0.1:8008 "$@" 2>&1
}
echo "-- what the account sent in Windvane Deployment"
TRUTH sent --room windvane-deployment | sed 's/^/    /'
echo "-- reactions"
TRUTH reactions --room windvane-deployment | sed 's/^/    /'
echo "-- edits"
TRUTH edits --room windvane-deployment | sed 's/^/    /'
# WHICH event the reply, reaction and edit landed on. Everything above passes
# when a reaction is attached to the reply's quoted copy of the anchor instead
# of the anchor itself, and nothing on screen shows the difference. The anchor
# is from @nadia:parrot.test; the reply is from the account.
echo "-- what the reply/reaction/edit actually TARGET"
TRUTH targets --room windvane-deployment | sed 's/^/    /'
echo "-- join/leave"
TRUTH membership | sed 's/^/    /'
echo "-- the drip burst"
TRUTH drip | sed 's/^/    /'

# Block 17 is the one that fails silently in this client, so it gets its own
# line. It pastes rather than using the file chooser (see MEASUREMENTS.md), and
# if the clipboard was empty the composer simply stays empty: no dialog, no
# error, an unchanged timeline. An m.image event is the only proof it did
# anything at all. Note the body is `image.png`, not `parrot.png` - a clipboard
# image carries no filename.
echo "-- the upload (an m.image event is the ONLY proof block 17 did anything)"
TRUTH sent --room windvane-deployment | grep -F '[m.image' | sed 's/^/    /' \
    || echo "    NO m.image EVENT - block 17 attached nothing"
