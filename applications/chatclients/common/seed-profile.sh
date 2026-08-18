#!/usr/bin/env bash
# Restore a pre-made client profile so the benchmark starts from a signed-in
# session instead of a login screen.
#
#   seed-profile.sh <client-dir> [home]
#
# Looks for <client-dir>/profile.tar.zst (or .tar.gz) and unpacks it over the
# home directory.  If no tarball is committed the script says so and exits 0:
# the session then has to be established as part of the recorded macro, which
# works but makes the first block of the recording client-specific.
#
# WHY A TARBALL, AND WHY IT IS WORSE HERE THAN FOR EMAIL
#
# None of these five clients keeps its session anywhere a shell script can
# author it:
#
#   Element, SchildiChat   an access token in Electron's IndexedDB (a LevelDB
#                          directory), plus a pickle key in the OS keyring
#   Fractal                its own state directory plus the Secret Service
#   nheko                  its own cache plus the Secret Service
#   FluffyChat             a Hive/SQLite store under the Flutter data directory
#
# Capturing a working session once and replaying it is the only way to get all
# five to the same starting state.  See the group README for the capture
# procedure - the short version is: log in by hand, close the client cleanly,
# then tar the paths listed in the client's own notes.
#
# THE SESSION MUST BE LOGGED IN BUT NOT SYNCED
#
# This is the one thing to get right, and it is easy to get wrong.  Block 2 of
# the scenario measures the INITIAL SYNC, which is the sharpest difference
# between these clients.  If the captured profile carries a warm cache, the
# client comes up with the corpus already local and block 2 measures a few
# hundred milliseconds of nothing.  Capture after the login completes and
# before the first sync finishes, or delete the client's cache directory from
# the tarball afterwards - the credential store is what has to survive, not the
# database.
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
    log "the session will have to be established inside the recorded macro"
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

# The tarball is created as root but the Flatpak clients run as uid 1001.
if [[ -n "${PARROT_CLIENT_USER:-}" ]] && id "$PARROT_CLIENT_USER" >/dev/null 2>&1; then
    chown -R "$PARROT_CLIENT_USER" "$TARGET_HOME"
    log "chowned ${TARGET_HOME} to ${PARROT_CLIENT_USER}"
fi

log "done"
