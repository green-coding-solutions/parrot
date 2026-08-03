#!/usr/bin/env bash
# Install Betterbird (a Thunderbird fork) 140.12.0esr-bb24.
#
# Betterbird publishes only tarballs, and betterbird.eu keeps just the current
# and previous build in LinuxArchive/ - a pinned tarball URL 404s within about
# two releases, which is fatal for a benchmark that has to be reproducible next
# year.  The New Life Linux PPA that the Betterbird FAQ points at packages the
# same builds as signed .debs and retains old versions, so that is what is used
# here.  It trails upstream by roughly one release.
#
# To use the upstream tarball instead, see UPSTREAM_TARBALL below - but expect
# to re-pin it regularly.
set -euo pipefail

BB_VERSION='140.12.0esr-bb24'
# Plain HTTP because the PPA answers 503 on HTTPS.  Integrity comes from the
# checksum below, which is verified before anything is installed.
BB_DEB="http://ppa.newlifelinux.org/ubuntu/pool/main/b/betterbird/betterbird_${BB_VERSION}_amd64.deb"
BB_SHA256='4044c4f3214462e5b23eafa9321139e5d27d48d382d8c6b1c41a2e017b495be3'

# Upstream, for reference.  Rots quickly - only the latest two builds stay up:
# UPSTREAM_TARBALL="https://www.betterbird.eu/downloads/LinuxArchive/betterbird-140.13.0esr-bb25.en-US.linux-x86_64.tar.xz"

log() { printf '[install-betterbird] %s\n' "$*"; }

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

log "installing runtime dependencies"
# The .deb's Depends names the pre-time_t64 packages (libgtk-3-0, libasound2,
# libxt6); on noble those are satisfied through Provides: from the *t64
# packages, so apt resolves it without help.  Installed explicitly anyway so a
# missing library shows up here rather than as a silent launch failure.
apt-get install -y -qq --no-install-recommends \
    libgtk-3-0t64 libglib2.0-0t64 libdbus-1-3 libasound2t64 \
    libstdc++6 libgcc-s1 libxt6t64 \
    libx11-6 libx11-xcb1 libxcb1 libxcb-shm0 libxcomposite1 libxdamage1 \
    libxext6 libxfixes3 libxrandr2 libxrender1 libxcursor1 libxi6 libxtst6 \
    libatk1.0-0t64 libatk-bridge2.0-0t64 libcairo2 libcairo-gobject2 \
    libpango-1.0-0 libpangocairo-1.0-0 libgdk-pixbuf-2.0-0 \
    libfontconfig1 libfreetype6 fontconfig fonts-liberation \
    libnotify4 libsecret-1-0 libnss3-tools \
    ca-certificates wget >/dev/null

log "downloading Betterbird ${BB_VERSION}"
wget -q -O /tmp/betterbird.deb "$BB_DEB"

log "verifying checksum"
echo "${BB_SHA256}  /tmp/betterbird.deb" | sha256sum -c -

log "installing"
apt-get install -y -qq /tmp/betterbird.deb >/dev/null
rm -f /tmp/betterbird.deb

fc-cache -f >/dev/null 2>&1 || true

cat > /usr/local/bin/betterbird <<'WRAPPER'
#!/bin/sh
# MOZ_APP_REMOTINGNAME: Betterbird derives its X11 class from its remoting name,
#   eu.betterbird.Betterbird, which yields an awkward WM_CLASS of roughly
#   "Mail", "Eu.betterbird.betterbird".  Overriding it gives the stable,
#   matchable class "Betterbird" that xdotool and replay.py can find.
# -profile: on first start Betterbird creates its own profile and writes an
#   [InstallXXXXXXXX] section into profiles.ini naming it as the default.  That
#   section outranks Profile0's Default=1, so the seeded profile is ignored and
#   the account-setup wizard appears instead of the mailbox.
MOZ_APP_REMOTINGNAME=betterbird exec /opt/betterbird/betterbird \
    -profile /root/.thunderbird/parrot \
    -no-remote "$@"
WRAPPER
chmod +x /usr/local/bin/betterbird

# Read the version from application.ini rather than running the binary:
# `betterbird --version` opens an About window under X, and a stray window left
# on the desktop would end up in the recording's reference screenshots.
log "installed: Betterbird $(awk -F= '/^Version=/{print $2; exit}' /opt/betterbird/application.ini 2>/dev/null)"
log "note: Betterbird shares Thunderbird's profile root, ~/.thunderbird"
