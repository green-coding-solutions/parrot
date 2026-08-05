#!/usr/bin/env bash
# Install Mailspring 1.23.0 from the upstream GitHub release.
#
# Two things about Mailspring that shape this script and the recording:
#
# 1. It needs a working secret service.  Mailspring stores credentials through
#    Electron's safeStorage, and its own code treats
#    safeStorage.isEncryptionAvailable() === false as a fatal error that quits
#    the app.  --password-store=basic does not help, because Mailspring never
#    calls setUsePlainTextEncryption().  So gnome-keyring has to be installed
#    and running, and the IMAP password cannot be seeded as plaintext.
#
# 2. Onboarding is served remotely.  The "Skip Mailspring ID" link that lets you
#    use a plain IMAP account without registering is rendered by
#    id.getmailspring.com, so the container needs outbound internet access on
#    the very first run - or a profile captured after onboarding, restored from
#    mailspring/profile.tar.zst.
#
# Both are documented in the README; neither can be worked around locally.
set -euo pipefail

MS_VERSION='1.23.0'
MS_DEB="https://github.com/Foundry376/Mailspring/releases/download/${MS_VERSION}/mailspring-${MS_VERSION}-amd64.deb"
MS_SHA256='f6f629375230057b1b6123a5c55b00e1f7ed606b04079a6eaea75d681933e5c9'

log() { printf '[install-mailspring] %s\n' "$*"; }

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

log "installing runtime dependencies"
# The .deb's Depends lists pre-t64 names (libasound2, libcurl4, libssl3); on
# noble those resolve through Provides:.  Listed explicitly so a missing
# library fails here instead of at launch.
apt-get install -y -qq --no-install-recommends \
    libasound2t64 libatk-bridge2.0-0t64 libatspi2.0-0t64 libcurl4t64 \
    libgbm1 libgcrypt20 libglib2.0-bin libgtk-3-0t64 libnotify4 libnss3 \
    libsasl2-2 libsasl2-modules libsecret-1-0 libssl3t64 libtidy5deb1 \
    libudev1 libxss1 libxtst6 xdg-utils \
    gnome-keyring dbus-x11 \
    fonts-liberation ca-certificates wget >/dev/null

log "downloading Mailspring ${MS_VERSION} (~138 MB)"
wget -q -O /tmp/mailspring.deb "$MS_DEB"

log "verifying checksum"
echo "${MS_SHA256}  /tmp/mailspring.deb" | sha256sum -c -

log "installing"
apt-get install -y -qq /tmp/mailspring.deb >/dev/null
rm -f /tmp/mailspring.deb

fc-cache -f >/dev/null 2>&1 || true

# Electron refuses to run its setuid sandbox as root, and the benchmark
# container runs as root.  Wrap the binary so every launch - including the one
# replay.py performs - gets the flags it needs.
cat > /usr/local/bin/mailspring <<'WRAPPER'
#!/bin/sh
# --no-sandbox: Electron's setuid sandbox will not run as root.
# --disable-dev-shm-usage: Docker's default /dev/shm is 64 MB, too small for
#   Chromium's shared memory and a common cause of renderer crashes.
# --disable-gpu: there is no GPU behind Xvfb.
exec /usr/bin/mailspring \
    --no-sandbox \
    --disable-dev-shm-usage \
    --disable-gpu \
    --ozone-platform=x11 \
    "$@"
WRAPPER
chmod +x /usr/local/bin/mailspring

log "installed Mailspring ${MS_VERSION} (Electron 41 / Chrome 146)"
log "note: first run needs outbound access to id.getmailspring.com to reach the"
log "      'Skip Mailspring ID' link, and a running gnome-keyring for its"
log "      credential store.  See the README."
