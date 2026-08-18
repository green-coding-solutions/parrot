#!/usr/bin/env bash
# Capture a signed-in session out of a running window-container into
# <client>/profile.tar.gz, so the benchmark starts logged in.
#
#   capture-profile.sh <client> [home]
#
# Run it after logging the client in by hand and closing it cleanly. What comes
# out is restored by seed-profile.sh as a setup-command.
#
# LOGGED IN BUT NOT SYNCED
#
# Block 2 of the scenario measures the initial sync, which is the sharpest
# difference between these clients. A profile carrying a warm cache turns that
# block into a few hundred milliseconds of nothing that still screenshots
# correctly - a passing run that measured the wrong thing.
#
# Two ways to get there, and which one applies depends on the client:
#
#   SEPARABLE   The session lives in a config file and the cache in its own
#               directory, so the cache can simply be left out of the tarball.
#               nheko is like this: measured, its access_token is in
#               ~/.config/nheko/nheko.conf and its LMDB cache is a separate
#               tree under ~/.local/share/nheko. Capture whenever you like.
#
#   INSEPARABLE The session and the synced state are in one store - Electron's
#               IndexedDB holds both, and so does a Flutter Hive box. Nothing
#               can be excluded without corrupting the login. For these, the
#               capture has to be TIMED: log in, then close the client as soon
#               as it is signed in, before the first sync finishes.
#
# The table below records which is which. An entry with no EXCLUDE is one where
# the timing matters.
set -euo pipefail

REPO=/home/didi/code/parrot
CLIENT="${1:?usage: capture-profile.sh <client> [home]}"
HOME_DIR="${2:-/root}"
OUT="${REPO}/applications/chatclients/${CLIENT}/profile.tar.gz"

log() { printf '[capture-profile] %s\n' "$*"; }

# INCLUDE and EXCLUDE are paths relative to the home directory.
case "$CLIENT" in
    nheko)
        # Separable. access_token is in nheko.conf; the keyring carries the
        # E2EE pickle key, which the launcher unlocks.
        INCLUDE=(".config/nheko" ".local/share/keyrings")
        EXCLUDE=(".local/share/nheko")
        ;;
    element|schildichat)
        # Inseparable: the access token lives in IndexedDB alongside the synced
        # state. Cache/ and GPUCache/ are Chromium's HTTP and shader caches and
        # are safe to drop - they are not the sync store.
        INCLUDE=(".config/Element" ".config/SchildiChat" ".local/share/keyrings")
        EXCLUDE=(".config/Element/Cache" ".config/Element/GPUCache"
                 ".config/SchildiChat/Cache" ".config/SchildiChat/GPUCache")
        ;;
    fractal)
        INCLUDE=(".local/share/fractal" ".config/fractal" ".local/share/keyrings")
        EXCLUDE=(".local/share/fractal/cache")
        ;;
    fluffychat)
        # Inseparable: Hive boxes hold the session and the timeline together.
        INCLUDE=(".local/share/chat.fluffy.fluffychat" ".local/share/keyrings")
        EXCLUDE=()
        ;;
    *)
        echo "unknown client: ${CLIENT}" >&2
        exit 1
        ;;
esac

# Flatpak clients keep everything under ~/.var/app/<app-id>; add it when it is
# there rather than maintaining a second table.
FLATPAK_DIR="$(docker exec window-container sh -c \
    "ls -d ${HOME_DIR}/.var/app/* 2>/dev/null | head -1" || true)"
if [[ -n "$FLATPAK_DIR" ]]; then
    log "flatpak data directory: ${FLATPAK_DIR}"
    INCLUDE+=(".var/app/$(basename "$FLATPAK_DIR")")
fi

log "capturing ${CLIENT} from ${HOME_DIR} in window-container"

present=()
for path in "${INCLUDE[@]}"; do
    if docker exec window-container test -e "${HOME_DIR}/${path}"; then
        present+=("$path")
        log "  + ${path}"
    else
        log "  - ${path} (absent)"
    fi
done

if [[ ${#present[@]} -eq 0 ]]; then
    log "ERROR: none of the expected paths exist - did the client actually log in?"
    exit 1
fi

exclude_args=()
for path in "${EXCLUDE[@]}"; do
    exclude_args+=("--exclude=./${path}")
    log "  ! excluding ${path}"
done

docker exec window-container tar -czf /tmp/profile.tar.gz \
    -C "$HOME_DIR" "${exclude_args[@]}" "${present[@]}"
docker cp window-container:/tmp/profile.tar.gz "$OUT" >/dev/null
docker exec window-container rm -f /tmp/profile.tar.gz

log "wrote ${OUT} ($(du -h "$OUT" | cut -f1))"
log "contents:"
tar -tzf "$OUT" | head -20 | sed 's/^/    /'
total=$(tar -tzf "$OUT" | wc -l)
log "  ... ${total} entries"

# A tarball that accidentally carries the cache is the failure this script
# exists to prevent, and size is the cheapest signal: a warm nheko cache is
# megabytes, a cold session is kilobytes.
size_kb=$(du -k "$OUT" | cut -f1)
if [[ "$size_kb" -gt 20480 ]]; then
    log "WARNING: ${size_kb} KB is large for a session-only profile."
    log "         Check that a sync cache did not get captured - see the note"
    log "         at the top of this file."
fi
