#!/usr/bin/env bash
# Resolve the two KMail settings that cannot be shipped in a profile, because
# they are Akonadi collection ids and Akonadi hands those out at run time.
#
#   seed-account.sh
#
# Run it AFTER common/seed-profile.sh (it edits files that profile carries) and
# AFTER entrypoint.sh (kwalletd5 is a Qt program and wants a display).
#
# ---------------------------------------------------------------------------
# Why this script exists
# ---------------------------------------------------------------------------
#
# KMail stores "where does sent mail go" and "where does Delete put things" as
# bare Akonadi collection ids:
#
#   ~/.config/emailidentities              [Identity #0] Fcc=12
#   ~/.config/akonadi_imap_resource_0rc    [cache] TrashCollection=9
#
# Those numbers are a per-database sequence, and the order collections are
# created in is a race between the maildir resource (Local Folders and the six
# special folders it makes on demand) and the IMAP resource (the account and
# every folder on the server).  Two runs of the identical setup produced
#
#   run A   5 Local Folders  6 outbox  7 sent-mail  8 IMAP Account 1  ... 16 INBOX
#   run B   5 Local Folders  6 IMAP Account 1  ...  8 INBOX  ...  23 outbox
#
# so a number captured in profile.tar.gz points at a *different folder* on the
# next machine.  Shipping one would be worse than shipping none: the number is
# always valid, so the wrong folder is used silently.  Sent mail would be filed
# into whatever collection happened to take that id.
#
# With neither key set, KMail falls back to Local Folders - a maildir under
# ~/.local/share/local-mail that the server never sees.  Both defects are silent
# and neither shows up in the message counts the way you would expect:
#
#   Delete       INBOX drops by one, the row disappears, Trash stays at 130.
#   Send         the message really is delivered (INBOX goes up by one), the
#                composer closes, and Sent stays at 940.
#
# So: bring Akonadi up once here, let the IMAP resource enumerate the account,
# read the two ids out of Akonadi's own database, write them into the config,
# and shut Akonadi down again.  Every run resolves its own ids, which is the
# only form of this that is portable.
#
# What this does NOT do is download any mail.  Only the folder list is fetched;
# PimItemTable is left empty, and the 2,100-message INBOX sync still happens
# inside the measured run, where it belongs.
set -euo pipefail

export HOME="${HOME:-/root}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-root}"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
export DISPLAY="${DISPLAY:-:99}"
export LANG="${LANG:-C.UTF-8}"
export XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-KDE}"

log() { printf '[seed-kmail] %s\n' "$*"; }

CONF="${HOME}/.config"
IDENTITIES="${CONF}/emailidentities"
RESOURCERC="${CONF}/akonadi_imap_resource_0rc"

[[ -f "$IDENTITIES" ]] || { log "ERROR: ${IDENTITIES} is missing - was profile.tar.gz restored?"; exit 1; }
[[ -f "$RESOURCERC" ]] || { log "ERROR: ${RESOURCERC} is missing - was profile.tar.gz restored?"; exit 1; }

# Akonadi is D-Bus activated and the IMAP password lives in KWallet, which is
# also D-Bus activated, so a session bus has to exist before anything starts.
if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    eval "$(dbus-launch --sh-syntax)"
    export DBUS_SESSION_BUS_ADDRESS DBUS_SESSION_BUS_PID
fi

SOCKET="${XDG_RUNTIME_DIR}/akonadi/mysql.socket"

log "starting Akonadi to enumerate the account"
akonadictl start >/dev/null 2>&1

# The socket appears when Akonadi's own mysqld is up; the schema follows.
for _ in $(seq 1 60); do
    [[ -S "$SOCKET" ]] && break
    sleep 2
done
[[ -S "$SOCKET" ]] || { log "ERROR: Akonadi's mysqld never came up at ${SOCKET}"; akonadictl stop >/dev/null 2>&1 || true; exit 1; }

q() { mysql --socket="$SOCKET" -u root akonadi -N -B -e "$1" 2>/dev/null || true; }

# The IMAP account's own folders, identified by their parent's remoteId rather
# than by any id - that is the whole point of this script.  Note that Akonadi
# stores IMAP remoteIds with a leading separator (".Sent", ".Trash"); the names
# are what to match on.
imap_child() {
    q "SELECT c.id FROM CollectionTable c
         JOIN CollectionTable p ON p.id = c.parentId
        WHERE p.remoteId LIKE 'imap://%' AND c.name = '$1'
        LIMIT 1;"
}

SENT=''
TRASH=''
for i in $(seq 1 90); do
    SENT="$(imap_child Sent)"
    TRASH="$(imap_child Trash)"
    [[ -n "$SENT" && -n "$TRASH" ]] && break
    sleep 2
    if (( i % 15 == 0 )); then
        log "still waiting for the folder list (${i}0s)"
    fi
done

if [[ -n "$TRASH" ]]; then
    # TrashCollection above is not what KMail's Delete actually follows.  It asks
    # MailCommon::Kernel::trashCollectionFromResource(), which looks the folder up
    # through Akonadi's SpecialMailCollections - i.e. by a SpecialCollectionAttribute
    # ON THE COLLECTION - and the IMAP resource never sets one, because Akonadi
    # 23.08 does not map IMAP SPECIAL-USE onto special collections.  Only the
    # maildir resource's own `trash` carries the attribute, so Delete silently
    # files into Local Folders however the resource is configured.
    #
    # Writing the attribute here is the fix, and it has to be a direct write:
    # there is no D-Bus call for it, and KMail only registers a collection it has
    # already loaded, which is never true at startup.  Akonadi is still up at this
    # point, and is stopped immediately afterwards, so the client's first read is
    # from a settled database.
    log "registering collection ${TRASH} as the account's trash"
    mysql --socket="$SOCKET" -u root akonadi >/dev/null 2>&1 <<SQL || log "WARNING: could not write the trash attribute"
DELETE FROM CollectionAttributeTable
      WHERE collectionId = ${TRASH} AND type = 'SpecialCollectionAttribute';
INSERT INTO CollectionAttributeTable (collectionId, type, value)
      VALUES (${TRASH}, 'SpecialCollectionAttribute', 'trash');
SQL
fi

log "stopping Akonadi"
akonadictl stop >/dev/null 2>&1 || true
# The resource rewrites its own config as it shuts down, so the edits below have
# to happen after it is gone or they are silently reverted.
for _ in $(seq 1 30); do
    pgrep -f akonadi_control >/dev/null 2>&1 || break
    sleep 2
done
pkill -f akonadi_control >/dev/null 2>&1 || true
pkill -f akonadiserver >/dev/null 2>&1 || true
sleep 3

if [[ -z "$SENT" || -z "$TRASH" ]]; then
    log "ERROR: the IMAP resource never produced Sent/Trash collections."
    log "       Sent='${SENT}' Trash='${TRASH}'"
    log "       Check that mail.parrot.test resolves and that the wallet opens."
    exit 1
fi
log "resolved collections: Sent=${SENT} Trash=${TRASH}"

# Plain INI edits.  kwriteconfig5 would need a running KDE session; sed does not.
set_key() {  # set_key <file> <group> <key> <value>
    python3 - "$@" <<'PY'
import sys
path, group, key, value = sys.argv[1:5]
with open(path, encoding='utf-8') as fh:
    lines = fh.read().split('\n')
out, in_group, done = [], False, False
for line in lines:
    stripped = line.strip()
    if stripped.startswith('['):
        if in_group and not done:
            out.append(f'{key}={value}')
            done = True
        in_group = stripped == group
    elif in_group and stripped.split('=', 1)[0].strip() == key:
        line = f'{key}={value}'
        done = True
    out.append(line)
if not done:
    if not in_group:
        out.append(group)
    out.append(f'{key}={value}')
with open(path, 'w', encoding='utf-8') as fh:
    fh.write('\n'.join(out))
PY
}

# The identity group is "[Identity #0]" - profile.tar.gz ships exactly one.
set_key "$IDENTITIES" '[Identity #0]' Fcc "$SENT"
set_key "$RESOURCERC" '[cache]' TrashCollection "$TRASH"

log "emailidentities            Fcc=${SENT}          (IMAP Account 1/Sent)"
log "akonadi_imap_resource_0rc  TrashCollection=${TRASH}  (IMAP Account 1/Trash)"
log "done"
