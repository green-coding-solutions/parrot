#!/usr/bin/env bash
# Install GNOME Evolution 3.52.3 from the Ubuntu 24.04 archive.
set -euo pipefail

EVO_VERSION='3.52.3-0ubuntu1.1'
# evolution-data-server is at a different Ubuntu revision than evolution itself.
EDS_VERSION='3.52.3-0ubuntu1.2'

log() { printf '[install-evolution] %s\n' "$*"; }

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

log "installing Evolution ${EVO_VERSION}"
# evolution-data-server holds the account registry Evolution reads at startup.
# gnome-keyring + libsecret-tools are what store the IMAP password: Evolution
# has no plaintext password store, so without a running secret service it
# prompts on every connection.
# dbus-x11 provides dbus-launch, which the data server needs to be reachable.
apt-get install -y -qq --no-install-recommends \
    "evolution=${EVO_VERSION}" \
    "evolution-data-server=${EDS_VERSION}" \
    gnome-keyring libsecret-1-0 libsecret-tools \
    dbus-x11 dconf-cli \
    fonts-liberation ca-certificates >/dev/null

fc-cache -f >/dev/null 2>&1 || true

log "installed: $(evolution --version 2>/dev/null | head -1 || echo 'version query failed')"
