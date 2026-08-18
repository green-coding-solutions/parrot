#!/usr/bin/env bash
# Set the account's MSC4278 media-preview policy on the homeserver.
#
#   seed-media-previews.sh [on|private|off] [user] [password]
#
# RUNS ON matrix-container, as a setup-command, before the window container
# starts its client.
#
# WHY THIS EXISTS
#
# Fractal 14.1 implements MSC4278 media previews and ships defaulting to
# "Show only in private rooms". `Field Photos` is a PUBLIC room, so on the
# default Fractal renders 400 "Click to show preview" placeholders where the
# other four clients decode 400 thumbnails. script.md blocks 8 and 10 are
# precisely "wait for the thumbnails to finish decoding", so left alone those
# two blocks would measure image decoding in four clients and scrolling past
# grey rectangles in the fifth. See ../fractal/MEASUREMENTS.md for the decision.
#
# WHY IT IS SEEDED RATHER THAN CLICKED
#
# The radio button in Settings -> Safety writes NOTHING to disk. It writes
# account data to the homeserver:
#
#   /_matrix/client/v3/user/<mxid>/account_data/io.element.msc4278.media_preview_config
#   {"media_previews": "on"}
#
# and GMT rebuilds the homeserver on every run, so a setting flipped by hand is
# gone by the next run. Seeding it here is a per-run write against the freshly
# built server: it does not touch the parrot-matrixserver image and does not
# reseed the corpus, so the finished nheko, Element and SchildiChat recordings
# are unaffected.
#
# It also keeps the block boundaries honest. Driving the preferences dialog
# inside the recording would put a settings round-trip inside a measured block,
# and script.md has no such step.
#
# THIS IS NOT THE REJECTED "SEED A SESSION" ROUTE. That one captured an access
# token from an earlier run and replayed it against a server that never issued
# it - see ../fractal/usage_scenario.yml. This logs in live, against the server
# that is running right now, and stores nothing.
#
# NOT A DEFAULT FOR THE GROUP. Only Fractal implements MSC4278; the other four
# ignore this account data entirely. It is wired into fractal/usage_scenario.yml
# alone, so the other clients keep measuring their own shipped behaviour.
set -euo pipefail

VALUE="${1:-on}"
USER="${2:-parrot}"
PASSWORD="${3:-parrot}"
HOMESERVER="${HOMESERVER:-http://127.0.0.1:8008}"

case "$VALUE" in
    on|private|off) ;;
    *) echo "[seed-media-previews] bad value '${VALUE}' - want on|private|off" >&2; exit 1 ;;
esac

python3 - "$HOMESERVER" "$USER" "$PASSWORD" "$VALUE" <<'PY'
import json
import sys
import urllib.error
import urllib.request

homeserver, user, password, value = sys.argv[1:5]

# Fractal 14.1 writes the UNSTABLE key only; the stable m.media_preview_config
# stays absent. Verified by reading both back after clicking the radio button.
# If a later Fractal moves to the stable key this write becomes a no-op that
# looks like it worked - which is why the read-back at the bottom is not
# optional.
KEY = 'io.element.msc4278.media_preview_config'


def request(method, url, body=None, token=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header('Content-Type', 'application/json')
    if token:
        req.add_header('Authorization', f'Bearer {token}')
    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            return json.loads(response.read() or b'{}')
    except urllib.error.HTTPError as error:
        detail = error.read().decode('utf-8', 'replace')[:300]
        raise SystemExit(f'[seed-media-previews] {method} {url} -> {error.code}: {detail}')


login = request('POST', f'{homeserver}/_matrix/client/v3/login', {
    'type': 'm.login.password',
    'identifier': {'type': 'm.id.user', 'user': user},
    'password': password,
})
token, mxid = login['access_token'], login['user_id']

url = f'{homeserver}/_matrix/client/v3/user/{mxid}/account_data/{KEY}'
request('PUT', url, {'media_previews': value}, token)

# Read it back. A PUT that 200s and stores something else is exactly the class
# of defect this project keeps finding, and account data is invisible on screen.
got = request('GET', url, None, token)
if got.get('media_previews') != value:
    raise SystemExit(f'[seed-media-previews] FAILED: {mxid} has {got!r}, wanted {value!r}')

# LOG OUT, or this leaves an extra unverified device on the account for the
# whole run. That is not cosmetic: Fractal does cross-signing in block 3, and an
# unverified device sitting on the account is exactly what makes a client raise
# a "verify this session" prompt that script.md does not describe and the other
# clients never see. /logout drops only this token's device, so it cannot affect
# the client's own login later.
request('POST', f'{homeserver}/_matrix/client/v3/logout', {}, token)

print(f'[seed-media-previews] {mxid} media_previews={value}')
PY
