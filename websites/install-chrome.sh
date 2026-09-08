#!/usr/bin/env bash
# Install Google Chrome for Testing 152.0.7977.82 into the websites image.
#
# WHY "CHROME FOR TESTING" AND NOT THE google-chrome-stable .deb
#
# Chrome for Testing is the same Chrome build with the auto-updater and the
# first-run/branding machinery taken out, published by Google specifically so
# that automation can pin a version. Every version stays archived at a stable
# URL forever.
#
# The .deb is the alternative and it is a trap this repository has already paid
# for once, in applications/pdf_viewers/firefox/install.sh: Google's apt pool
# prunes old versions, so
#
#   https://dl.google.com/linux/chrome/deb/pool/main/g/google-chrome-stable/\
#     google-chrome-stable_<version>-1_amd64.deb
#
# serves a given version today and 404s later. A benchmark whose installer
# 404s does not degrade, it stops: every run in the group fails during
# setup-commands, before anything is measured.
#
# Consequences of the choice, so that nobody has to rediscover them:
#
#   * The binary reports itself as "Google Chrome for Testing" and its
#     WM_CLASS is not google-chrome's. The macros name the class this build
#     actually maps under, read off a running window, not the one the branded
#     build uses.
#   * There is no auto-update, which is what we want: an update mid-run would
#     be measured, and an update between runs would silently change the browser.
#
# Runtime libraries are apt-pinned in the Dockerfile, not here. See
# install-firefox.sh for why.
set -euo pipefail

CHROME_VERSION='152.0.7977.82'
# sha256 of the linux64 archive named in
# https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json
CHROME_SHA256='0704631fb3e4f741092e08f55272f90abc3e307f991f05f332924364415b02e0'
CHROME_URL="https://storage.googleapis.com/chrome-for-testing-public/${CHROME_VERSION}/linux64/chrome-linux64.zip"

log() { printf '[install-chrome] %s\n' "$*"; }

log "downloading Chrome for Testing ${CHROME_VERSION}"
wget -q -O /tmp/chrome.zip "$CHROME_URL"

log "verifying checksum"
echo "${CHROME_SHA256}  /tmp/chrome.zip" | sha256sum -c -

log "unpacking to /opt/chrome"
rm -rf /opt/chrome /tmp/chrome-unpack
mkdir -p /tmp/chrome-unpack
unzip -q /tmp/chrome.zip -d /tmp/chrome-unpack
mv /tmp/chrome-unpack/chrome-linux64 /opt/chrome
rm -rf /tmp/chrome.zip /tmp/chrome-unpack
chmod +x /opt/chrome/chrome

# The macros launch the browser as plain `google-chrome`, the name the branded
# package puts on the PATH, so that a future switch back to the .deb is a change
# to this file alone.
cat > /usr/local/bin/google-chrome <<'WRAPPER'
#!/bin/sh
exec /opt/chrome/chrome "$@"
WRAPPER
chmod +x /usr/local/bin/google-chrome

log "installed: $(/opt/chrome/chrome --version)"
