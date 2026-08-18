#!/usr/bin/env bash
# Install Android Studio 2025.1.3, "Narwhal 3 Feature Drop", from Google's
# pinned tarball.
#
# dl.google.com/dl/android/studio/ide-zips/<version>/ keeps every past build at a
# stable URL.  The developer.android.com download page does not: it is rendered
# by JavaScript and hands out whatever is current, which is the opposite of what
# a recording needs.
#
# WHY THIS VERSION AND NOT THE HIGHEST ONE THAT RESOLVES
#
# ide-zips serves release candidates alongside releases, and nothing in the URL
# says which is which.  The highest version that answered a HEAD request was
# 2025.2.3.7, and it installs and runs perfectly well - as "Otter 3 Feature Drop
# | 2025.2.3 RC 2".  Every other editor in this group is pinned to a stable
# release, so benchmarking a release candidate here would have been a difference
# between the rows that had nothing to do with the editors.
#
# The label is in the tarball and can be read without installing it:
#
#   tar -xzOf android-studio-<v>-linux.tar.gz android-studio/lib/resources.jar \
#     | unzip -p /dev/stdin idea/AndroidStudioApplicationInfo.xml | grep '<version'
#
#   2025.2.3.7  full="Otter 3 Feature Drop | {0}.{1}.{2} RC 2"   <- rejected
#   2025.1.3.7  full="Narwhal 3 Feature Drop | {0}.{1}.{2}"      <- this one
#
# Worth re-running when the pin is next moved: the current stable line at the
# time of writing is Quail (2026.1.x), which has no ide-zips build at all.
#
# Android Studio is IntelliJ IDEA with Google's Android plugins on top - same
# platform, same key bindings, same first-run dialogs - so most of what
# ../intellij/MEASUREMENTS.md records applies here too.  It is in the comparison
# for what the extra weight costs: a 1.5 GB download against IDEA's 1.5 GB, and
# a first run that wants to fetch an SDK before it will show you an editor.
#
# NOTHING IS CONFIGURED.  No idea.properties, no seeded SDK, no suppressed
# wizard.  Whatever Android Studio puts in front of a new install is what the
# macro clicks through.
set -euo pipefail

STUDIO_VERSION='2025.1.3.7'
STUDIO_BUILD='AI-251.26094.121.2513.14007798'
STUDIO_SHA256='a5eb77b9398be2943f171076a8abfe219371e78d20302ee199f39a43c88b4294'
STUDIO_URL="https://dl.google.com/dl/android/studio/ide-zips/${STUDIO_VERSION}/android-studio-${STUDIO_VERSION}-linux.tar.gz"

log() { printf '[install-androidstudio] %s\n' "$*"; }

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
MARKER="/opt/android-studio/.parrot-${STUDIO_VERSION}"
if [[ -f "$MARKER" ]]; then
    log "Android Studio ${STUDIO_VERSION} already unpacked, skipping download"
else
    log "downloading Android Studio ${STUDIO_VERSION} (~1.5 GB)"
    wget -q -O /tmp/studio.tar.gz "$STUDIO_URL"

    log "verifying checksum"
    echo "${STUDIO_SHA256}  /tmp/studio.tar.gz" | sha256sum -c -

    log "unpacking to /opt/android-studio"
    rm -rf /opt/android-studio
    mkdir -p /opt/android-studio
    tar -xzf /tmp/studio.tar.gz -C /opt/android-studio --strip-components=1
    rm -f /tmp/studio.tar.gz
    touch "$MARKER"
fi
fc-cache -f >/dev/null 2>&1 || true

# Everything Android Studio remembers between runs.  Google's build writes under
# a vendor directory of its own rather than JetBrains/ - the product-info.json
# gives dataDirectoryName "AndroidStudio2025.1.3" and productVendor "Google", so
# the paths are ~/.config/Google/..., ~/.local/share/Google/... and
# ~/.cache/Google/... .  ~/.android is separate again and holds the SDK
# location, the analytics consent and the emulator state.
#
# All of it goes, because setup-commands run before every replay and a profile
# left over from the previous run has the wizard already answered - which is a
# completely different first block.
rm -rf /root/.config/Google /root/.local/share/Google /root/.cache/Google \
       /root/.android /root/.java/.userPrefs

cat > /usr/local/bin/androidstudio <<'WRAPPER'
#!/bin/sh
exec /opt/android-studio/bin/studio "$@"
WRAPPER
chmod +x /usr/local/bin/androidstudio

log "installed: ${STUDIO_BUILD}"
