#!/usr/bin/env bash
# Install Claws Mail 4.2.0 from the Ubuntu 24.04 archive.
set -euo pipefail

CLAWS_VERSION='4.2.0-2build7'

log() { printf '[install-clawsmail] %s\n' "$*"; }

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

log "installing Claws Mail ${CLAWS_VERSION}"
# claws-mail-pgpmime etc. are deliberately left out: the benchmark measures a
# plain mailbox, and every extra plugin is extra startup work that differs from
# what the other clients do.
apt-get install -y -qq --no-install-recommends \
    "claws-mail=${CLAWS_VERSION}" \
    fonts-liberation ca-certificates >/dev/null

fc-cache -f >/dev/null 2>&1 || true

log "installed: $(claws-mail --version 2>/dev/null | head -1 || echo 'version query failed')"
