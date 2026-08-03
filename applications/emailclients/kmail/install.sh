#!/usr/bin/env bash
# Install KMail / Kontact 23.08.5 from the Ubuntu 24.04 archive.
#
# KMail is the heaviest of the eight to set up because it does not own its own
# mail storage: Akonadi does, backed by a database that Akonadi launches and
# manages itself.  All of it has to be running before KMail shows a mailbox.
#
# The backend is MariaDB, not SQLite.  Akonadi's SQLite backend deadlocks under
# the concurrent access its own agents generate - starting KMail with it
# produces a stream of
#
#   Database error: DataStore::rollbackTransaction
#   "database is locked Unable to fetch row"
#   General exception ... Database deadlock, unsuccessful after multiple retries
#
# and no window ever appears.  MariaDB works without systemd because Akonadi
# starts its own mysqld with its own socket and datadir, so nothing needs to be
# managed as a service.
set -euo pipefail

KMAIL_VERSION='4:23.08.5-0ubuntu5.1'
KONTACT_VERSION='4:23.08.5-0ubuntu4.2'
# accountwizard is only a Recommends of kmail, so --no-install-recommends drops
# it - and then KMail's first run dies with "Could not start the account wizard.
# Please make sure you have AccountWizard properly installed" and no main window
# ever appears.  It is the only way to add an account to KMail.
WIZARD_VERSION='4:23.08.5-0ubuntu3'

log() { printf '[install-kmail] %s\n' "$*"; }

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

log "installing KMail ${KMAIL_VERSION} and Kontact ${KONTACT_VERSION}"
apt-get install -y -qq --no-install-recommends \
    "kmail=${KMAIL_VERSION}" \
    "kontact=${KONTACT_VERSION}" \
    "accountwizard=${WIZARD_VERSION}" \
    akonadi-backend-mysql mariadb-server \
    kwalletmanager \
    kross \
    libsasl2-modules \
    dbus-x11 \
    fonts-liberation ca-certificates >/dev/null

# libsasl2-modules is not optional either, and its absence is just as quiet as
# kross's.
#
# KMail sends through ksmtp, which authenticates with Cyrus SASL.  libsasl2-2
# arrives as a dependency but ships no *mechanism* plugins, so PLAIN and LOGIN
# do not exist and the AUTH negotiation ends with
#
#     org.kde.pim.ksmtp: sasl_client_start failed with: -4
#     "SASL(-4): no mechanism available: No worthy mechs found"
#     org.kde.pim.ksmtp: SMTP Socket error: RemoteHostClosedError
#
# The composer closes as if the message had gone, the message sits in the
# outbox, and nothing on screen says why.  IMAP is unaffected - KIMAP logs in
# with a plain LOGIN command and never asks SASL - so the mailbox downloads
# perfectly while every send fails.

# kross is not optional, and it is not a dependency of accountwizard either.
#
# The Account Assistant's per-protocol pages are Kross scripts - the IMAP one is
# /usr/share/akonadi/accountwizard/imap/imapwizard.es, an ECMAScript file.
# accountwizard depends on libkf5krosscore5, the Kross *framework*, but nothing
# pulls in an interpreter for it, and with --no-install-recommends none arrives.
# The wizard then reaches "Select Account Type", accepts "Generic IMAP Email
# Server", and dead-ends on
#
#     Failed to load script: ''.
#
# with Next greyed out and no way forward.  The `kross` package supplies
# krossqts.so, the QtScript interpreter, which is what makes the .es script
# loadable.  Ubuntu does not package a JavaScript interpreter for Kross under any
# other name; krossruby is Ruby and does not help.

fc-cache -f >/dev/null 2>&1 || true

mkdir -p "${HOME}/.config/akonadi" "${HOME}/.local/share/akonadi"
cat > "${HOME}/.config/akonadi/akonadiserverrc" <<'RC'
[%General]
Driver=QMYSQL

[Debug]
Tracer=null
RC

# Akonadi merges this over /usr/share/akonadi/mysql-global.conf when it starts
# mysqld.  user=root is required because the benchmark container runs as root
# and MariaDB refuses to start as root unless told to explicitly.
cat > "${HOME}/.config/akonadi/mysql-local.conf" <<'MYCNF'
[mysqld]
user=root
MYCNF

log "configured Akonadi to use the MariaDB backend"

log "installed kmail ${KMAIL_VERSION} (Akonadi on MariaDB)"
log "note: the account itself comes from kmail/profile.tar.gz, and the two"
log "      settings that are Akonadi collection ids - the identity's sent folder"
log "      and the resource's trash folder - are resolved at run time by"
log "      kmail/seed-account.sh.  See kmail/MEASUREMENTS.md."
