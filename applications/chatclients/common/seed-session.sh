#!/usr/bin/env bash
# Put a signed-in session into a client's config, by logging in through the API
# at setup time and writing the token where the client reads it.
#
#   seed-session.sh <client> [home]
#
# WHY THIS EXISTS AND seed-profile.sh DOES NOT COVER IT
#
# A captured profile.tar.gz cannot carry a Matrix session across a container
# rebuild, and this was measured rather than guessed:
#
#   Restoring a profile captured from an earlier container gives
#     nheko: dropping to the login page: Failed to setup encryption keys.
#            Server response: Invalid access token passed. 401.
#
# The reason is that an access token is SERVER state. Logging in writes a row to
# the homeserver's database, and that write happens in the running container -
# it is not in the image. GMT builds fresh containers for every run, so the
# homeserver comes back from the image with no memory of the token, and the
# captured profile points at a session that no longer exists. Nothing about the
# client is wrong; the credential was simply revoked by rebuilding the server.
#
# So the session has to be created in the SAME run that uses it. This script
# does that: it logs in over the client-server API as a setup-command and writes
# the resulting token into the client's own config. Every run gets its own
# session, and there is nothing stale to go bad.
#
# WHICH CLIENTS THIS WORKS FOR
#
# Only the ones that keep their session in a file a script can write. nheko does
# - measured: ~/.config/nheko/nheko.conf is a plain QSettings INI holding
# access_token, device_id, user_id and home_server.
#
# Element, SchildiChat and FluffyChat do NOT: their sessions live in Electron's
# IndexedDB and a Flutter Hive box, which are databases, not config. For those
# the session has to be established some other way - see the note at the bottom.
set -euo pipefail

HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=../account.env
source "${HERE}/../account.env"

CLIENT="${1:?usage: seed-session.sh <client> [home]}"
HOME_DIR="${2:-/root}"

log() { printf '[seed-session] %s\n' "$*"; }

# --------------------------------------------------------------------------
# Log in
# --------------------------------------------------------------------------
log "logging in as ${PARROT_MATRIX_USER} at ${PARROT_MATRIX_URL}"
SESSION_JSON=$(PARROT_MATRIX_URL="$PARROT_MATRIX_URL" \
               PARROT_MATRIX_USER="$PARROT_MATRIX_USER" \
               PARROT_MATRIX_PASS="$PARROT_MATRIX_PASS" python3 - <<'PY'
import json, os, sys, urllib.error, urllib.request

url = os.environ['PARROT_MATRIX_URL'].rstrip('/') + '/_matrix/client/v3/login'
body = json.dumps({
    'type': 'm.login.password',
    'identifier': {'type': 'm.id.user', 'user': os.environ['PARROT_MATRIX_USER']},
    'password': os.environ['PARROT_MATRIX_PASS'],
    # A fixed display name so the device list is the same shape every run.
    'initial_device_display_name': 'parrot-benchmark',
}).encode()
request = urllib.request.Request(url, data=body, method='POST')
request.add_header('Content-Type', 'application/json')
try:
    with urllib.request.urlopen(request, timeout=60) as response:
        result = json.loads(response.read())
except urllib.error.HTTPError as error:
    print(f'login failed: {error.code} {error.read().decode()[:200]}', file=sys.stderr)
    sys.exit(1)
print(json.dumps({k: result[k] for k in ('access_token', 'device_id', 'user_id')}))
PY
)

ACCESS_TOKEN=$(printf '%s' "$SESSION_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')
DEVICE_ID=$(printf '%s' "$SESSION_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["device_id"])')
USER_ID=$(printf '%s' "$SESSION_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["user_id"])')
log "session for ${USER_ID}, device ${DEVICE_ID}"

# --------------------------------------------------------------------------
# Write it where the client looks
# --------------------------------------------------------------------------
case "$CLIENT" in
    nheko)
        CONF_DIR="${HOME_DIR}/.config/nheko"
        mkdir -p "$CONF_DIR"
        # The settings below the [auth] block are nheko's own defaults as
        # written by a real first run, with three changed on purpose:
        #
        #   theme=light        the default, stated so a future default change
        #                      does not silently restyle every reference image
        #   presence=...       left at the default; the server has presence off
        #   font_size=9        as shipped - do not "fix" this, every click
        #                      coordinate in the recording depends on it
        #
        # user_id is written with a DOUBLED leading @. That is not a typo:
        # QSettings treats a leading @ as the start of a special value such as
        # @Invalid(), so it escapes it by doubling. Writing a single @ makes
        # nheko read an empty user id and drop to the login page.
        cat > "${CONF_DIR}/nheko.conf" <<CONF
[General]
disable_certificate_validation=false

[auth]
access_token=${ACCESS_TOKEN}
device_id=${DEVICE_ID}
home_server=${PARROT_MATRIX_URL}
user_id=@${USER_ID}

[user]
alert_on_notification=false
animate_images_on_hover=false
automatically_share_keys_with_trusted_users=false
avatar_circles=true
bubbles_enabled=false
decrypt_notificatons=true
decrypt_sidebar=true
desktop_notifications=true
emoji_font_family=emoji
expose_dbus_api=false
fancy_effects=true
font_size=9
group_view=true
invert_enter_key=false
markdown_enabled=true
minor_events=true
mobile_mode=false
muted_tags=global
online_key_backup=true
only_share_keys_with_verified_users=false
open_image_external=false
open_video_external=false
presence=AutomaticPresence
privacy_screen=false
privacy_screen_timeout=0
read_receipts=true
reduced_motion=false
ringtone=Default
scrollbars_in_roomlist=false
sidebar\\community_list_width=40
sidebar\\room_list_width=183
small_avatars_enabled=false
sort_by_unread=true
space_notifications=true
theme=light
timeline\\buttons=true
timeline\\enlarge_emoji_only_msg=false
timeline\\max_width=0
timeline\\message_hover_highlight=false
typing_notifications=true
use_identicon=true
use_stun_server=false
window\\start_in_tray=false
window\\tray=false
CONF
        log "wrote ${CONF_DIR}/nheko.conf"
        # No cache is written, deliberately: block 2 of the scenario measures
        # the initial sync, and nheko's LMDB cache under
        # ~/.local/share/nheko would make it a no-op.
        ;;
    *)
        log "ERROR: ${CLIENT} does not keep its session in a writable config file."
        log "       Element and SchildiChat keep it in Electron's IndexedDB;"
        log "       FluffyChat in a Hive box. Those are databases, and the"
        log "       session for them has to be established by driving the login"
        log "       inside the recording instead."
        exit 1
        ;;
esac

log "done"
