#!/usr/bin/env bash
# Install PyCharm 2025.3 from JetBrains' pinned tarball.
#
# Not from the JetBrains apt repository or the Toolbox: neither pins a version
# that stays resolvable, and the Toolbox wants a network and an account at first
# run.  download.jetbrains.com keeps every past release at a stable URL, and
# publishes a .sha256 next to each one.
#
# PyCharm 2025.3 is likewise a single distribution now, running on the free tier
# without a licence for what this scenario does.
#
# It is in the comparison alongside IntelliJ IDEA on purpose: the two share a
# platform, so the difference between them is the language support rather than
# the editor.  IDEA in its free tier treats a .py file as plain text - it has no
# Python plugin - while PyCharm indexes, inspects and completes it.  Whatever
# that costs shows up as the difference between two otherwise identical rows.
#
# NOTHING IS CONFIGURED.  IDEA runs on its own defaults, so the user agreement,
# the data-sharing consent and the project-trust prompt all appear on first
# start, and the macro clicks through them the way a person would.  An earlier
# version of this file suppressed all three with -Djb.privacy.policy.text and a
# seeded trusted-paths.xml; that made IDEA's startup look like an editor nobody
# has ever installed, and hid a real cost of using it.
set -euo pipefail

PYCHARM_VERSION='2025.3'
PYCHARM_SHA256='a410c9c5834ede16373325ea21b850e309557db5d9dcca3674caf92ea7c5bf05'
PYCHARM_URL="https://download.jetbrains.com/python/pycharm-${PYCHARM_VERSION}.tar.gz"

log() { printf '[install-pycharm] %s\n' "$*"; }

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

# The tarball bundles its own JetBrains Runtime, so no JDK from apt.  What it
# does not bundle is the X and font stack that runtime links against.
log "installing runtime dependencies"
apt-get install -y -qq --no-install-recommends \
    libx11-6 libxext6 libxrender1 libxtst6 libxi6 libxrandr2 libxcursor1 \
    libfreetype6 libfontconfig1 fontconfig fonts-dejavu-core fonts-liberation \
    libsecret-1-0 ca-certificates wget >/dev/null

# Skip the 1.5 GB download when this exact build is already unpacked.  In a
# fresh container - which is what every benchmark and every replay runs in - the
# marker never exists and the download always happens, so the production path is
# unchanged.  It only pays off while iterating in a container kept alive.
MARKER="/opt/pycharm/.parrot-${PYCHARM_VERSION}"
if [[ -f "$MARKER" ]]; then
    log "PyCharm ${PYCHARM_VERSION} already unpacked, skipping download"
else
    log "downloading PyCharm ${PYCHARM_VERSION} (~1.5 GB)"
    wget -q -O /tmp/pycharm.tar.gz "$PYCHARM_URL"

    log "verifying checksum"
    echo "${PYCHARM_SHA256}  /tmp/pycharm.tar.gz" | sha256sum -c -

    log "unpacking to /opt/pycharm"
    rm -rf /opt/pycharm
    mkdir -p /opt/pycharm
    tar -xzf /tmp/pycharm.tar.gz -C /opt/pycharm --strip-components=1
    rm -f /tmp/pycharm.tar.gz
    touch "$MARKER"
fi
fc-cache -f >/dev/null 2>&1 || true

# Everything IDEA writes lives under the default per-version paths in
# ~/.config, ~/.local/share and ~/.cache.  Clear them so run N starts where run
# 1 did - setup-commands run before every replay, and a profile left over from
# the previous run has the agreement already accepted and the project already
# trusted, which is a different first block entirely.
rm -rf /root/.config/JetBrains /root/.local/share/JetBrains /root/.cache/JetBrains \
       /root/.java/.userPrefs

cat > /usr/local/bin/pycharm <<'WRAPPER'
#!/bin/sh
exec /opt/pycharm/bin/pycharm "$@"
WRAPPER
chmod +x /usr/local/bin/pycharm

log "installed: $(grep -o '"version"[^,]*' /opt/pycharm/product-info.json 2>/dev/null | head -1)"
