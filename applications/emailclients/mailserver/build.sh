#!/usr/bin/env bash
# Build the benchmark mailbox: install Dovecot and Postfix, create the account,
# write the configuration and generate the ~500 MB corpus.
#
# This is the slow half of the mail container - a few minutes, most of it corpus
# generation. The prebuilt image runs it once at build time; start.sh then does
# the fast runtime part on every benchmark.
#
# Nothing here starts a daemon, so it is safe to run inside a Dockerfile.
set -euo pipefail

# readlink -f, so this still resolves when the script is reached through a
# symlink: BASH_SOURCE is then the link's path and ../account.env would not
# exist next to it.  The prebuilt image relies on this - it puts start.sh on
# PATH as /usr/local/bin/parrot-mailserver-start.
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=../account.env
source "${HERE}/../account.env"

TARGET_MB="${PARROT_MAIL_TARGET_MB:-500}"

# Pinned against the ubuntu:24.04 (noble) archive, like the rest of this repo.
PKG_DOVECOT='1:2.3.21+dfsg1-2ubuntu6.5'
PKG_POSTFIX='3.8.6-1ubuntu0.1'
PKG_OPENSSL='3.0.13-0ubuntu3.11'

log() { printf '[mailserver-build] %s\n' "$*"; }

# --------------------------------------------------------------------------
log "installing packages"
# --------------------------------------------------------------------------
export DEBIAN_FRONTEND=noninteractive
# Postfix would otherwise stop and ask for a mail configuration type.
echo "postfix postfix/main_mailer_type select No configuration" | debconf-set-selections
echo "postfix postfix/mailname string ${PARROT_MAIL_HOST}" | debconf-set-selections

apt-get update -qq
apt-get install -y --no-install-recommends \
    "dovecot-imapd=${PKG_DOVECOT}" \
    "dovecot-lmtpd=${PKG_DOVECOT}" \
    "postfix=${PKG_POSTFIX}" \
    "openssl=${PKG_OPENSSL}" \
    python3 ca-certificates libsasl2-modules

# --------------------------------------------------------------------------
log "creating mail user ${PARROT_MAIL_USER}"
# --------------------------------------------------------------------------
# No fixed UID: ubuntu:24.04 already ships a user at 1000.
if ! id "$PARROT_MAIL_USER" >/dev/null 2>&1; then
    useradd --create-home --shell /bin/bash "$PARROT_MAIL_USER"
fi
echo "${PARROT_MAIL_USER}:${PARROT_MAIL_PASS}" | chpasswd
MAIL_HOME="$(getent passwd "$PARROT_MAIL_USER" | cut -d: -f6)"
log "mail home is ${MAIL_HOME} (uid $(id -u "$PARROT_MAIL_USER"))"

# --------------------------------------------------------------------------
log "generating ~${TARGET_MB} MB mail corpus"
# --------------------------------------------------------------------------
# Done before the configuration is written so that editing a config file does
# not invalidate the (large, slow) corpus layer in the Docker build cache.
runuser -u "$PARROT_MAIL_USER" -- python3 "${HERE}/generate_corpus.py" \
    --root "${MAIL_HOME}/Maildir" \
    --target-mb "$TARGET_MB" \
    --manifest "${MAIL_HOME}/corpus-manifest.json" \
    --aliases "${MAIL_HOME}/local-aliases.txt" \
    --fresh

# --------------------------------------------------------------------------
log "installing dovecot configuration"
# --------------------------------------------------------------------------
install -m 644 "${HERE}/conf/dovecot-parrot.conf" /etc/dovecot/conf.d/99-parrot.conf
printf '%s\n' "${PARROT_MAIL_USER}:{PLAIN}${PARROT_MAIL_PASS}" > /etc/dovecot/parrot-users
chmod 640 /etc/dovecot/parrot-users
chown root:dovecot /etc/dovecot/parrot-users
touch /var/log/dovecot.log
chown dovecot:dovecot /var/log/dovecot.log

# --------------------------------------------------------------------------
log "installing postfix configuration"
# --------------------------------------------------------------------------
install -m 644 "${HERE}/conf/postfix-main.cf" /etc/postfix/main.cf
install -m 644 "${HERE}/conf/postfix-master.cf" /etc/postfix/master.cf
echo "$PARROT_MAIL_HOST" > /etc/mailname
# postlogd writes here; without it Postfix logs to syslog, which is not running.
postconf -e "maillog_file = /var/log/postfix.log"
touch /var/log/postfix.log

# A catch-all for every domain in the corpus, all resolving to the one real
# mailbox, so anything the scenario sends is delivered rather than bounced.
#
# This has to cover the external domains too, not just @parrot.test.  Replying
# to a corpus message sends to e.g. dmitri.sokolov@northwind-hosting.test; with
# no route for that domain Postfix bounces it, and the bounce lands in the inbox
# mid-run - shifting every anchor position by one and breaking the screenshot
# assertions in the steps that follow.
{
    printf '%s %s\n' "$PARROT_MAIL_ADDRESS" "$PARROT_MAIL_ADDRESS"
    if [[ -f "${MAIL_HOME}/local-aliases.txt" ]]; then
        while read -r d; do
            [[ -n "$d" ]] && printf '%s %s\n' "$d" "$PARROT_MAIL_ADDRESS"
        done < "${MAIL_HOME}/local-aliases.txt"
    fi
    printf 'postmaster@%s %s\n' "$PARROT_MAIL_DOMAIN" "$PARROT_MAIL_ADDRESS"
} > /etc/postfix/virtual
postmap /etc/postfix/virtual
newaliases 2>/dev/null || true
log "virtual aliases cover: $(awk '{print $1}' /etc/postfix/virtual | tr '\n' ' ')"

log "build complete - run start.sh to serve it"
