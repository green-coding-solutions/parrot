#!/usr/bin/env bash
# Restore a pre-made client profile so the benchmark starts from a configured
# account instead of an account-setup wizard.
#
#   seed-profile.sh <client-dir> [home]
#
# Looks for <client-dir>/profile.tar.zst (or .tar.gz) and unpacks it over the
# home directory.  If no tarball is committed the script says so and exits 0:
# the account then has to be configured as part of the recorded macro, which
# works but makes the first block of the recording client-specific.
#
# Why a tarball at all: Thunderbird keeps passwords in an NSS key4.db, KMail in
# KWallet, and the Electron clients in an OS keyring - none of which can be
# authored from a shell script.  Capturing a working profile once and replaying
# it is the only way to get all eight clients to the same starting state.
#
# To create one, see the "Seeding an account" section of the README.
set -euo pipefail

CLIENT_DIR="${1:?usage: seed-profile.sh <client-dir> [home]}"
TARGET_HOME="${2:-$HOME}"

log() { printf '[seed-profile] %s\n' "$*"; }

tarball=''
for candidate in "${CLIENT_DIR}/profile.tar.zst" "${CLIENT_DIR}/profile.tar.gz"; do
    if [[ -f "$candidate" ]]; then
        tarball="$candidate"
        break
    fi
done

if [[ -z "$tarball" ]]; then
    log "no profile.tar.zst or profile.tar.gz in ${CLIENT_DIR}"
    log "the account will have to be set up inside the recorded macro"
    exit 0
fi

log "restoring $(basename "$tarball") into ${TARGET_HOME}"
mkdir -p "$TARGET_HOME"
case "$tarball" in
    *.zst)
        command -v zstd >/dev/null 2>&1 || {
            log "ERROR: zstd is not installed but ${tarball} needs it"
            exit 1
        }
        tar --zstd -xf "$tarball" -C "$TARGET_HOME"
        ;;
    *.gz)
        tar -xzf "$tarball" -C "$TARGET_HOME"
        ;;
esac

# The tarball is created as root but the client may run as another user.
if [[ -n "${PARROT_CLIENT_USER:-}" ]] && id "$PARROT_CLIENT_USER" >/dev/null 2>&1; then
    chown -R "$PARROT_CLIENT_USER" "$TARGET_HOME"
    log "chowned ${TARGET_HOME} to ${PARROT_CLIENT_USER}"
fi

log "done"
