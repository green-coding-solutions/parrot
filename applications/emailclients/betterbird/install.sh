#!/usr/bin/env bash
# Install Betterbird (a Thunderbird fork) 140.13.0esr-bb25 from the upstream
# tarball.
#
# THIS PIN WILL ROT.  Betterbird publishes only tarballs, and betterbird.eu keeps
# just the current and previous build in LinuxArchive/ - a pinned tarball URL
# 404s within about two releases.  Expect to re-pin, and to replay-verify the
# recording, every time a scheduled run fails in this script.
#
# Until 2026-09 this installed 140.12.0esr-bb24 as a .deb from the New Life
# Linux PPA that the Betterbird FAQ points at, because it retained old versions.
# By 2026-09-29 the PPA answered 403 to everything, its Packages index included,
# and bb24 was gone from upstream too, so there was no source left for the
# version the recording was made on.  The PPA .deb unpacked to /opt/betterbird,
# the same path the tarball does, so the wrapper below is unchanged.
set -euo pipefail

BB_VERSION='140.13.0esr-bb25'
BB_URL="https://www.betterbird.eu/downloads/LinuxArchive/betterbird-${BB_VERSION}.en-US.linux-x86_64.tar.xz"
# From https://www.betterbird.eu/downloads/sha256-140.txt, and matched against
# a download on 2026-09-29.
BB_SHA256='d346c0c6c4f8dcde204f97f2d780d685530b9163d864bccd5c149456394ba1c0'

log() { printf '[install-betterbird] %s\n' "$*"; }

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

log "installing runtime dependencies"
# The tarball declares no dependencies, so this list is all there is:
# Thunderbird's, plus libxt6.  Installed explicitly so a missing library shows
# up here rather than as a silent launch failure.
apt-get install -y -qq --no-install-recommends \
    libgtk-3-0t64 libglib2.0-0t64 libdbus-1-3 libasound2t64 \
    libstdc++6 libgcc-s1 libxt6t64 \
    libx11-6 libx11-xcb1 libxcb1 libxcb-shm0 libxcomposite1 libxdamage1 \
    libxext6 libxfixes3 libxrandr2 libxrender1 libxcursor1 libxi6 libxtst6 \
    libatk1.0-0t64 libatk-bridge2.0-0t64 libcairo2 libcairo-gobject2 \
    libpango-1.0-0 libpangocairo-1.0-0 libgdk-pixbuf-2.0-0 \
    libfontconfig1 libfreetype6 fontconfig fonts-liberation \
    libnotify4 libsecret-1-0 libnss3-tools \
    ca-certificates wget xz-utils >/dev/null

log "downloading Betterbird ${BB_VERSION}"
wget -q -O /tmp/betterbird.tar.xz "$BB_URL"

log "verifying checksum"
echo "${BB_SHA256}  /tmp/betterbird.tar.xz" | sha256sum -c -

log "unpacking to /opt"
rm -rf /opt/betterbird
tar -xJf /tmp/betterbird.tar.xz -C /opt
rm -f /tmp/betterbird.tar.xz

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
