#!/usr/bin/env bash
# Install IntelliJ IDEA 2025.3 from JetBrains' pinned tarball.
#
# Not from the JetBrains apt repository or the Toolbox: neither pins a version
# that stays resolvable, and the Toolbox wants a network and an account at first
# run.  download.jetbrains.com keeps every past release at a stable URL, and
# publishes a .sha256 next to each one.
#
# 2025.3 is the release where Community and Ultimate became one distribution, so
# there is no ideaIC- tarball any more; `idea-2025.3.tar.gz` is the whole IDE and
# runs on the free tier without a licence for what this scenario does.
#
# NOTHING IS CONFIGURED.  IDEA runs on its own defaults, so the user agreement,
# the data-sharing consent and the project-trust prompt all appear on first
# start, and the macro clicks through them the way a person would.  An earlier
# version of this file suppressed all three with -Djb.privacy.policy.text and a
# seeded trusted-paths.xml; that made IDEA's startup look like an editor nobody
# has ever installed, and hid a real cost of using it.
set -euo pipefail

IDEA_VERSION='2025.3'
IDEA_SHA256='13f4174ba16c1cef04871cb261433536d002586c269a809392c20ee3f94959f5'
IDEA_URL="https://download.jetbrains.com/idea/idea-${IDEA_VERSION}.tar.gz"

log() { printf '[install-intellij] %s\n' "$*"; }

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
MARKER="/opt/idea/.parrot-${IDEA_VERSION}"
if [[ -f "$MARKER" ]]; then
    log "IntelliJ IDEA ${IDEA_VERSION} already unpacked, skipping download"
else
    log "downloading IntelliJ IDEA ${IDEA_VERSION} (~1.5 GB)"
    wget -q -O /tmp/idea.tar.gz "$IDEA_URL"

    log "verifying checksum"
    echo "${IDEA_SHA256}  /tmp/idea.tar.gz" | sha256sum -c -

    log "unpacking to /opt/idea"
    rm -rf /opt/idea
    mkdir -p /opt/idea
    tar -xzf /tmp/idea.tar.gz -C /opt/idea --strip-components=1
    rm -f /tmp/idea.tar.gz
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

cat > /usr/local/bin/intellij <<'WRAPPER'
#!/bin/sh
exec /opt/idea/bin/idea "$@"
WRAPPER
chmod +x /usr/local/bin/intellij

log "installed: $(grep -o '"version"[^,]*' /opt/idea/product-info.json 2>/dev/null | head -1)"
