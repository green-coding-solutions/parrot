#!/usr/bin/env bash
# Install Mozilla Thunderbird 153.0.1 ESR from the official tarball.
#
# Not from apt: Ubuntu 24.04's `thunderbird` package is version 2:1snap1-0ubuntu3,
# a transitional stub that installs the snap.  There is no snapd in this
# container, so the deb is useless here.  Mozilla's own apt repository
# (packages.mozilla.org) only publishes Firefox, not Thunderbird.
#
# The tarball from ftp.mozilla.org is pinnable in a way the alternatives are
# not: Mozilla keeps every past release there permanently, so this URL will
# still resolve years from now.
set -euo pipefail

TB_VERSION='153.0.1esr'
TB_SHA256='80803c07b6a001a4ba86c8856505ea5db1b36c3d6d16f218fad4f3e683658618'
TB_URL="https://ftp.mozilla.org/pub/thunderbird/releases/${TB_VERSION}/linux-x86_64/en-US/thunderbird-${TB_VERSION}.tar.xz"

log() { printf '[install-thunderbird] %s\n' "$*"; }

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

# Gecko's runtime dependencies.  NSS, NSPR and sqlite are bundled in the
# tarball, so they are deliberately not installed from apt.  libnss3-tools is,
# because certutil is needed to trust the benchmark CA when the account is
# configured for TLS.
log "installing runtime dependencies"
apt-get install -y -qq --no-install-recommends \
    libgtk-3-0t64 libglib2.0-0t64 libdbus-1-3 libasound2t64 \
    libstdc++6 libgcc-s1 \
    libx11-6 libx11-xcb1 libxcb1 libxcb-shm0 libxcomposite1 libxdamage1 \
    libxext6 libxfixes3 libxrandr2 libxrender1 libxcursor1 libxi6 libxtst6 \
    libatk1.0-0t64 libatk-bridge2.0-0t64 libcairo2 libcairo-gobject2 \
    libpango-1.0-0 libpangocairo-1.0-0 libgdk-pixbuf-2.0-0 \
    libfontconfig1 libfreetype6 fontconfig fonts-liberation \
    libnotify4 libsecret-1-0 libnss3-tools \
    ca-certificates wget xz-utils >/dev/null

log "downloading Thunderbird ${TB_VERSION}"
wget -q -O /tmp/thunderbird.tar.xz "$TB_URL"

log "verifying checksum"
echo "${TB_SHA256}  /tmp/thunderbird.tar.xz" | sha256sum -c -

log "unpacking to /opt"
rm -rf /opt/thunderbird
tar -xJf /tmp/thunderbird.tar.xz -C /opt
rm -f /tmp/thunderbird.tar.xz

# Launch the seeded profile explicitly rather than relying on profiles.ini.
# On first start Thunderbird creates its own profile and writes an
# [InstallXXXXXXXX] section naming it as the default; that section outranks
# Profile0's Default=1, so a hand-written profiles.ini entry is ignored and the
# account-setup wizard appears instead of the mailbox.  -profile sidesteps
# profiles.ini altogether.
cat > /usr/local/bin/thunderbird <<'WRAPPER'
#!/bin/sh
exec /opt/thunderbird/thunderbird \
    -profile /root/.thunderbird/parrot \
    -no-remote "$@"
WRAPPER
chmod +x /usr/local/bin/thunderbird

# Without at least one usable font every string renders as boxes, which makes
# screenshot assertions meaningless.
fc-cache -f >/dev/null 2>&1 || true

# From application.ini, not from the binary: running it under X can open an
# About window, and a stray window would end up in reference screenshots.
log "installed: Thunderbird $(awk -F= '/^Version=/{print $2; exit}' /opt/thunderbird/application.ini 2>/dev/null)"
