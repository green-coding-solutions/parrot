#!/usr/bin/env bash
# Record applications/chatclients/fluffychat/fluffychat.parrot end to end.
#
# Tears both containers down and rebuilds them through the scenario's own
# setup-commands first. A recording made against containers that have already
# been driven once is a recording of the second run: the account has already
# joined the lobby, the reply and the reaction are already on the anchor
# message, the drip burst is already in the firehose room, and the reference
# images show a state the first replay will never be in.
#
# That matters more here than in the other groups, because the state lives on
# the SERVER. FluffyChat's block 3 sets up a crypto identity - "Skip" skips only
# the passphrase - and that identity is server state, so a second run would meet
# a different block 3 from the one that was recorded. Rebuilding the homeserver
# is the only thing that puts it back, which is what this script does first.
set -euo pipefail

REPO=/home/didi/code/parrot
CLIENT=fluffychat
cd "$REPO"

echo "=== rebuilding both containers from usage_scenario.yml ==="
bash "applications/chatclients/common/setup-container.sh" "$CLIENT"

echo "=== starting the recorder ==="
# windowclass `fluffychat` is the MAIN window's res_name, read back off the
# running window: WM_CLASS(STRING) = "fluffychat", "Fluffychat". THE TWO HALVES
# DIFFER IN CASE here, unlike Fractal, and pin-windows.sh matches
# res_name, so it needs the lowercase one. `Fluffychat` or the Flatpak ref
# would match nothing - and matching nothing is silent: fluxbox applies no rule
# and the window maps at 864x720 at (288, 121) instead of 1440x900 at the
# origin. Measured.
#
# The startcommand is the flatpak-session wrapper from
# ../common/install-flatpak.sh: it drops to uid 1001 (which is what lets the
# container keep Docker's default capability set), starts a session bus, unlocks
# a secret service on that same bus, and sets XDG_CURRENT_DESKTOP so
# xdg-desktop-portal picks an implementation. FluffyChat starts cleanly with all
# of it in place - the portal work that Fractal forced carries over unchanged.
./record-macro.py \
    --script applications/chatclients/script.md \
    --startcommand 'flatpak-session flatpak run im.fluffychat.Fluffychat' \
    --windowtitle 'FluffyChat' \
    --windowclass fluffychat \
    "applications/chatclients/${CLIENT}/${CLIENT}.parrot" &
RECORDER=$!

# The recorder launches the client and arms xmacrorec2; give both time to come
# up before any event is sent, or the first block is recorded without its
# opening keystrokes. Same 20 s as the other three, deliberately: this is
# measured time, so a client with a longer head burns more energy for no reason
# of its own. FluffyChat's actual readiness is waited for in drive-scenario.sh,
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
# image carries no filename - and in THIS client the body is empty entirely,
# where Fractal's is `image.png`.
echo "-- the upload (an m.image event is the ONLY proof block 17 did anything)"
TRUTH sent --room windvane-deployment | grep -F '[m.image' | sed 's/^/    /' \
    || echo "    NO m.image EVENT - block 17 attached nothing"
