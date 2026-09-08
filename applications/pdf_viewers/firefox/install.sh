#!/usr/bin/env bash
# Install Firefox 151.0 from Mozilla's release archive.
#
# NOT `apt-get install firefox=151.0~build2` from packages.mozilla.org, which is
# what this file did first.  That repository keeps only the last handful of
# builds, so the pin rots - and it has:
#
#   E: Version '151.0~build2' for 'firefox' was not found
#
# with apt then reporting "Package firefox is not available, but is referred to
# by another package", which is Ubuntu's transitional stub talking.  Every run in
# the firefox and pdf_viewers groups failed in setup on that line.
#
# ftp.mozilla.org keeps every release forever and publishes a SHA256SUMS file
# next to each one, so the same 151.0 the reference screenshots were recorded
# against stays installable.  The version is deliberately unchanged: a newer
# Firefox is a different browser to the pixel, and the checks in this group
# compare pixels.  applications/codeeditors/jupyterlab/install.sh takes the same
# route for the same reason.
#
# Ubuntu's own `firefox` package is not an option either: on 24.04 it is a
# transitional stub that installs a snap, and snapd does not run here.
set -euo pipefail

FIREFOX_VERSION='151.0'
FIREFOX_SHA256='8ff8557a5ca3903ebbc1d18570684075f623465be5e362d63a95b3acc523f824'
FIREFOX_URL="https://ftp.mozilla.org/pub/firefox/releases/${FIREFOX_VERSION}/linux-x86_64/en-US/firefox-${FIREFOX_VERSION}.tar.xz"

log() { printf '[install-firefox] %s\n' "$*"; }

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

# The tarball bundles everything Gecko needs except the system GTK stack.
log "installing runtime dependencies"
apt-get install -y -qq --no-install-recommends \
    libgtk-3-0 libdbus-glib-1-2 libasound2t64 libxt6 libx11-xcb1 libxcb-shm0 \
    libfreetype6 libfontconfig1 fontconfig fonts-dejavu-core fonts-liberation \
    xz-utils ca-certificates wget >/dev/null
fc-cache -f >/dev/null 2>&1 || true

# Skip the download when this exact build is already unpacked.  In a fresh
# container - which is what every benchmark run gets - the marker never exists
# and the download always happens, so the production path is unchanged.  It only
# pays off while iterating in a container kept alive.
MARKER="/opt/firefox/.parrot-${FIREFOX_VERSION}"
if [[ -f "$MARKER" ]]; then
    log "Firefox ${FIREFOX_VERSION} already unpacked, skipping download"
else
    log "downloading Firefox ${FIREFOX_VERSION}"
    wget -q -O /tmp/firefox.tar.xz "$FIREFOX_URL"

    log "verifying checksum"
    echo "${FIREFOX_SHA256}  /tmp/firefox.tar.xz" | sha256sum -c -

    log "unpacking to /opt/firefox"
    rm -rf /opt/firefox
    mkdir -p /opt/firefox
    tar -xJf /tmp/firefox.tar.xz -C /opt/firefox --strip-components=1
    rm -f /tmp/firefox.tar.xz
    touch "$MARKER"
fi

# The recordings launch the browser as plain `firefox`, which is what the apt
# package put on the PATH.  Keep that name.
cat > /usr/local/bin/firefox <<'WRAPPER'
#!/bin/sh
exec /opt/firefox/firefox "$@"
WRAPPER
chmod +x /usr/local/bin/firefox

log "installed: $(/opt/firefox/firefox --version 2>/dev/null)"
