#!/usr/bin/env bash
# Install BlueMail 1.140.14 from packages.bluemail.me.
#
# The .deb is not installed with apt/dpkg, on purpose:
#
# 1. It declares `Depends: libgconf-2-4`, a package that was dropped after
#    Ubuntu 22.04 and does not exist on 24.04.  The dependency is spurious -
#    nothing in the binary references gconf - but it makes `apt install` fail.
#
# 2. Its postinst runs apt-get install, apt-get update, and pipes a key through
#    the removed `apt-key add`, all against the network.  In a benchmark image
#    that means surprise downloads at build time and a broken apt state.
#
# Extracting the payload sidesteps both and produces exactly the same tree
# under /opt/BlueMail.
set -euo pipefail

BM_VERSION='1.140.14'
BM_DEB="https://packages.bluemail.me/repos/debian/BlueMail-${BM_VERSION}.deb"
BM_SHA256='6f3d384e187dafa0ea053861705671ca704914106d5cb8d632a169119a778d8d'

log() { printf '[install-bluemail] %s\n' "$*"; }

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

log "installing runtime dependencies"
# Taken from `readelf -d /opt/BlueMail/bluemail`, not from the .deb's Depends,
# which lists only the bogus libgconf-2-4.
apt-get install -y -qq --no-install-recommends \
    libglib2.0-0t64 libgtk-3-0t64 libnss3 libnspr4 \
    libatk1.0-0t64 libatk-bridge2.0-0t64 libatspi2.0-0t64 \
    libdbus-1-3 libdrm2 libgbm1 libgdk-pixbuf-2.0-0 \
    libpango-1.0-0 libcairo2 libexpat1 libxkbcommon0 \
    libx11-6 libxcb1 libxcomposite1 libxdamage1 libxext6 libxfixes3 \
    libxrandr2 libxshmfence1 libasound2t64 libcups2t64 libgcc-s1 \
    dbus-x11 \
    fonts-liberation ca-certificates wget binutils xz-utils zstd >/dev/null

log "downloading BlueMail ${BM_VERSION} (~80 MB)"
wget -q -O /tmp/bluemail.deb "$BM_DEB"

log "verifying checksum"
echo "${BM_SHA256}  /tmp/bluemail.deb" | sha256sum -c -

log "extracting the payload (bypassing dpkg and its postinst)"
workdir=/tmp/bluemail-extract
rm -rf "$workdir"
mkdir -p "$workdir"
cd "$workdir"
ar x /tmp/bluemail.deb
# The data member may be .tar.xz, .tar.gz or .tar.zst depending on the build.
data="$(ls data.tar.* | head -1)"
tar -xf "$data" -C /
cd /
rm -rf "$workdir" /tmp/bluemail.deb

if [[ ! -x /opt/BlueMail/bluemail ]]; then
    log "ERROR: /opt/BlueMail/bluemail is missing after extraction"
    exit 1
fi

fc-cache -f >/dev/null 2>&1 || true

# BlueMail ships chrome-sandbox mode 0755 rather than 4755, and the container
# runs as root, so the sandbox cannot be used either way.
cat > /usr/local/bin/bluemail <<'WRAPPER'
#!/bin/sh
# --no-sandbox: chrome-sandbox is not setuid in this package, and Electron
#   refuses the sandbox as root regardless.
# --disable-dev-shm-usage: Docker's 64 MB /dev/shm is too small for Chromium.
# Hardware acceleration is already off - BlueMail calls
# app.disableHardwareAcceleration() itself - so --disable-gpu is not needed.
# --disable-gpu-sandbox: Electron 13.3.0 predates the glibc >= 2.34 seccomp fix
#   (electron#31091, released in 13.5.0).  Noble ships glibc 2.39, so sandboxed
#   child processes take SIGSYS and die with exit code 159.  BlueMail calls
#   app.disableHardwareAcceleration() itself but still spawns a GPU child, so
#   that child needs the sandbox off too.
exec /opt/BlueMail/bluemail \
    --no-sandbox \
    --disable-gpu-sandbox \
    --disable-dev-shm-usage \
    "$@"
WRAPPER
chmod +x /usr/local/bin/bluemail

log "installed BlueMail ${BM_VERSION} to /opt/BlueMail"
log "note: this build bundles Electron 13 / Chrome 91 (dated 2024) - by far the"
log "      oldest engine in this comparison, which is itself a finding."
log "note: accounts live in Chromium LevelDB/IndexedDB under ~/.config/BlueMail"
log "      and cannot be seeded.  Add the account in the recording, or capture a"
log "      configured home as bluemail/profile.tar.zst."
