#!/usr/bin/env bash
# Pre-configure the benchmark IMAP account in Evolution.
#
# Evolution keeps accounts as GKeyFile "source" files under
# ~/.config/evolution/sources/, which are plain text and can be written from a
# shell.  The password is the one part that is not: it goes into the GNOME
# keyring, so this script starts a keyring daemon and stores it with
# secret-tool, using the attribute layout evolution-data-server looks up.
#
# Result: launching Evolution goes straight to a mailbox, with no account
# assistant and no password prompt.
set -euo pipefail

# readlink -f, so this still resolves when the script is reached through a
# symlink: BASH_SOURCE is then the link's path and ../account.env would not
# exist next to it.  The prebuilt image relies on this - it puts start.sh on
# PATH as /usr/local/bin/parrot-mailserver-start.
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=../account.env
source "${HERE}/../account.env"

log() { printf '[seed-evolution] %s\n' "$*"; }

SOURCES="${HOME}/.config/evolution/sources"
mkdir -p "$SOURCES" "${HOME}/.local/share/evolution/mail"

# Stable UIDs: the file name is the source UID, and the mail source references
# the collection by that name.
ACCOUNT_UID='parrot-benchmark'

# [Security] Method takes the GEnum *nick* of CamelNetworkSecurityMethod, not a
# friendly name: "none", "starttls-on-standard-port", "ssl-on-alternate-port".
# Anything else is silently treated as none, which would quietly turn a TLS run
# into a plaintext one.
#
# [Imapx Backend] is the ESourceCamel extension for the imapx provider - the
# group name is "<Protocol> Backend" and the keys are the CamelCase form of the
# Camel property names (use-real-trash-path -> UseRealTrashPath).  See
# libcamelimapx.so, which carries them as "Backend:Imapx Backend:...".
case "${PARROT_MAIL_SECURITY:-none}" in
    none)     IMAP_PORT="$PARROT_IMAP_PORT";  IMAP_METHOD='none'
              SMTP_PORT="$PARROT_SUBMISSION_PORT"; SMTP_METHOD='none' ;;
    starttls) IMAP_PORT="$PARROT_IMAP_PORT";  IMAP_METHOD='starttls-on-standard-port'
              SMTP_PORT="$PARROT_SUBMISSION_PORT"; SMTP_METHOD='starttls-on-standard-port' ;;
    tls)      IMAP_PORT="$PARROT_IMAPS_PORT"; IMAP_METHOD='ssl-on-alternate-port'
              SMTP_PORT="$PARROT_SMTPS_PORT"; SMTP_METHOD='ssl-on-alternate-port' ;;
    *) log "ERROR: PARROT_MAIL_SECURITY must be none, starttls or tls"; exit 1 ;;
esac

# ---- the account itself ---------------------------------------------------
cat > "${SOURCES}/${ACCOUNT_UID}.source" <<SRC
[Data Source]
DisplayName=Parrot benchmark
Enabled=true
Parent=
[Authentication]
Host=${PARROT_MAIL_HOST}
Method=PLAIN
Port=${IMAP_PORT}
ProxyUid=system-proxy
RememberPassword=true
User=${PARROT_MAIL_USER}
[Security]
Method=${IMAP_METHOD}
[Mail Account]
BackendName=imapx
IdentityUid=${ACCOUNT_UID}-identity
# Without this the Archive action is a silent no-op: the menu item is enabled, the
# click is accepted, and nothing moves.  Evolution needs the destination named as
# a folder URI, "folder://<account-uid>/<path>", before it will file anything.
ArchiveFolder=folder://${ACCOUNT_UID}/Archive
NeedsInitialSetup=false
[Offline]
StaySynchronized=false
[Refresh]
Enabled=true
IntervalMinutes=10
[Imapx Backend]
# Use the server's real Trash and Junk folders instead of Evolution's virtual
# ones.  This is not cosmetic - it changes what Delete does.
#
# With the default (virtual) trash, Delete only sets the IMAP \Deleted flag on
# the message *where it is*: the inbox count does not change, the server's Trash
# folder does not change, and the message merely disappears from the list.  The
# "Trash" the scenario then empties would be a saved search over \Deleted
# messages, not a mailbox - so "empty the trash" could never reach the Trash 0
# that every other client in this benchmark ends at.  Verified on the server:
# after Delete, INBOX stayed at 2099 and Trash at 130, with one \Deleted message
# still sitting in INBOX.
#
# With these set, Delete performs a real IMAP move into Trash, which is what
# Thunderbird, Betterbird, BlueMail and the rest do, and what makes the mailbox
# end state comparable.  It also removes the duplicate virtual folders from the
# tree: without it Evolution shows two "Trash" rows and two "Junk" rows, and
# only one of each is the server's.
UseRealTrashPath=true
RealTrashPath=Trash
UseRealJunkPath=true
RealJunkPath=Junk
SRC

# [Mail Submission] belongs HERE, on the identity, not on a source of its own.
#
# The composer builds its From list from the identity sources, and for each one
# it needs a transport to send through - which it takes from that identity's
# [Mail Submission] TransportUid.  An identity without the extension has no
# transport, so it is not offered at all: the From field comes up empty and Send
# fails with "This message cannot be sent because there is no mail account
# configured", even though the IMAP side of the same account is working and the
# mailbox is on screen behind the composer.
#
# This file previously wrote the extension into a separate
# <uid>-submission.source, which nothing referenced and which therefore did
# nothing at all.
cat > "${SOURCES}/${ACCOUNT_UID}-identity.source" <<SRC
[Data Source]
DisplayName=${PARROT_MAIL_REALNAME}
Enabled=true
Parent=${ACCOUNT_UID}
[Mail Identity]
Address=${PARROT_MAIL_ADDRESS}
Name=${PARROT_MAIL_REALNAME}
ReplyTo=
Organization=
SignatureUid=
[Mail Submission]
SentFolder=folder://${ACCOUNT_UID}/Sent
TransportUid=${ACCOUNT_UID}-transport
RepliesToOriginFolder=false
SRC

cat > "${SOURCES}/${ACCOUNT_UID}-transport.source" <<SRC
[Data Source]
DisplayName=Parrot benchmark submission
Enabled=true
Parent=${ACCOUNT_UID}
[Authentication]
Host=${PARROT_MAIL_HOST}
Method=PLAIN
Port=${SMTP_PORT}
ProxyUid=system-proxy
RememberPassword=true
User=${PARROT_MAIL_USER}
[Security]
Method=${SMTP_METHOD}
[Mail Transport]
BackendName=smtp
SRC

log "wrote 3 source files to ${SOURCES}"

# ---- the password ---------------------------------------------------------
# evolution-data-server looks the password up by these two attributes.  An
# unlocked "login" keyring with an empty password is enough; the daemon has to
# be running under the same D-Bus session Evolution will use.
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-root}"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    log "starting a D-Bus session"
    eval "$(dbus-launch --sh-syntax)"
    export DBUS_SESSION_BUS_ADDRESS DBUS_SESSION_BUS_PID
fi

log "unlocking the login keyring"
mkdir -p "${HOME}/.local/share/keyrings"
# --unlock reads the passphrase from stdin; an empty one keeps it unlocked for
# the life of the daemon, which is all the benchmark needs.
printf '\n' | gnome-keyring-daemon --unlock --components=secrets >/dev/null 2>&1 || true
eval "$(printf '\n' | gnome-keyring-daemon --start --components=secrets 2>/dev/null)" || true
export GNOME_KEYRING_CONTROL

# printf, NOT a here-string.  `<<<"$PASS"` appends a newline, and secret-tool
# stores stdin verbatim - so the keyring ends up holding "parrot\n".  Evolution
# then looks the secret up successfully and authenticates with a password one
# byte too long, which dovecot rejects.  The symptom is a re-appearing password
# prompt and "Failed to authenticate: IMAP server said BYE", i.e. it reads like a
# keyring or timeout problem rather than a wrong password.
if printf '%s' "$PARROT_MAIL_PASS" | secret-tool store --label="Parrot benchmark IMAP" \
        e-source-uid "$ACCOUNT_UID" \
        eds-origin "${PARROT_MAIL_HOST}" 2>/dev/null; then
    log "stored the IMAP password in the keyring"
else
    log "WARNING: could not store the password in the keyring"
    log "Evolution will prompt for it once - tick 'remember' in the recording"
fi

# The transport authenticates separately and looks its password up under its OWN
# source UID, so the IMAP secret above does not cover it.  Without this the first
# send stops on a "Mail authentication request" dialog in the middle of the
# measured "Reply and send" block.  The scenario allows answering that prompt
# ("...only if the outgoing server asks"), but seeding it keeps Evolution
# consistent with its own IMAP side, which is already seeded.
if printf '%s' "$PARROT_MAIL_PASS" | secret-tool store --label="Parrot benchmark SMTP" \
        e-source-uid "${ACCOUNT_UID}-transport" \
        eds-origin "${PARROT_MAIL_HOST}" 2>/dev/null; then
    log "stored the SMTP password in the keyring"
else
    log "WARNING: could not store the SMTP password; the first send will prompt"
fi

# ---- the message-preview pane -------------------------------------------
# org.gnome.evolution.mail paned-size is where Evolution stores the divider
# between the message list and the preview pane.  At the benchmark's 1440x900 the
# shipped default leaves the preview 41 px tall: the From/To lines fit and
# nothing else.  No message body renders, and the attachment bar - which the
# scenario's PDF step has to click - is off the bottom of the window.
#
# 1409470 is not a pixel count.  Evolution stores this as an opaque encoding of
# the divider's proportion, so the value was obtained the only way that is
# reliable: drag the divider to where it should be, then read the key back.  At
# 1440x900 it puts the divider at y=560, which leaves 16 message rows and a
# preview big enough to render a body.  It is reproducible because
# pin-windows.sh fixes the window at 1440x900 for recording and replay alike;
# at any other window size it would need re-deriving the same way.
#
# dconf needs the session bus started above.  Failing here is not fatal - it
# only costs the preview pane - so it warns rather than exits.
if command -v dconf >/dev/null 2>&1; then
    if dconf write /org/gnome/evolution/mail/paned-size 1409470 2>/dev/null; then
        log "set the message-preview pane size"
    else
        log "WARNING: could not set paned-size; the preview pane will be 41 px tall"
    fi
fi

log "done"
