#!/usr/bin/env bash
# Install Firefox 155.0.1 from Mozilla's release archive into the websites image.
#
# WHY THIS IS NOT applications/pdf_viewers/firefox/install.sh
#
# That script is the canonical Firefox installer for the *application* groups and
# it pins 155.0.1's predecessor, because those groups compare screenshots and a
# newer Firefox is a different browser to the pixel. This group has no reference
# screenshots at all: it renders whatever URL it is handed, so it is free to
# track a current browser, and it must be free to do so independently. Sharing
# one file would mean that re-pinning Firefox for a pdf_viewers re-record
# silently changes what every website measurement was taken with.
#
# The two files are otherwise the same, and the reasoning in the other one is
# worth reading before touching this one. The short version:
#
#   * NOT `apt-get install firefox` from packages.mozilla.org. That repository
#     keeps only the last handful of builds, so a version pin rots and every run
#     in the group then fails in setup with "Version ... was not found".
#   * NOT Ubuntu's own `firefox` package. On 24.04 it is a transitional stub
#     that installs a snap, and snapd does not run here.
#   * ftp.mozilla.org keeps every release forever and publishes a SHA256SUMS
#     file next to each one, so this pin stays installable.
#
# Runtime libraries are NOT installed here. They are apt-pinned in the
# Dockerfile, because this script runs at image build time, not as a
# setup-command, and the image is where a pinned dependency belongs.
set -euo pipefail

FIREFOX_VERSION='155.0.1'
# From https://ftp.mozilla.org/pub/firefox/releases/155.0.1/SHA256SUMS
FIREFOX_SHA256='642ab731354a5ca790b894d4556dfb5028c61d0c24eb10d10e10a111a69c89bf'
FIREFOX_URL="https://ftp.mozilla.org/pub/firefox/releases/${FIREFOX_VERSION}/linux-x86_64/en-US/firefox-${FIREFOX_VERSION}.tar.xz"

log() { printf '[install-firefox] %s\n' "$*"; }

log "downloading Firefox ${FIREFOX_VERSION}"
wget -q -O /tmp/firefox.tar.xz "$FIREFOX_URL"

log "verifying checksum"
echo "${FIREFOX_SHA256}  /tmp/firefox.tar.xz" | sha256sum -c -

log "unpacking to /opt/firefox"
rm -rf /opt/firefox
mkdir -p /opt/firefox
tar -xJf /tmp/firefox.tar.xz -C /opt/firefox --strip-components=1
rm -f /tmp/firefox.tar.xz

# The macros launch the browser as plain `firefox`, which is the name the apt
# package would have put on the PATH. Keep that name.
cat > /usr/local/bin/firefox <<'WRAPPER'
#!/bin/sh
exec /opt/firefox/firefox "$@"
WRAPPER
chmod +x /usr/local/bin/firefox

log "installed: $(/opt/firefox/firefox --version)"
