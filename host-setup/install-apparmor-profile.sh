#!/usr/bin/env bash
# Load the parrot-flatpak AppArmor profile on a measurement host, and prove it
# works before a benchmark run depends on it.
#
# Run this ON THE HOST, as root. Nothing here goes into the container image -
# AppArmor profiles are host state, and Docker only ever names one.
#
# Needed on AppArmor hosts (Ubuntu, Debian) for the Flatpak entrants only; on a
# host with no AppArmor this script is a no-op and says so. The full reasoning is
# in apparmor/parrot-flatpak.
set -euo pipefail

PROFILE_NAME=parrot-flatpak
PROFILE_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/apparmor/${PROFILE_NAME}"
PROFILE_DST="/etc/apparmor.d/${PROFILE_NAME}"
TEST_IMAGE="${TEST_IMAGE:-ubuntu:24.04}"

log() { printf '[apparmor] %s\n' "$*"; }

if [[ ! -e /sys/module/apparmor/parameters/enabled ]]; then
    log "no AppArmor on this host - nothing to install, and nothing to work around."
    exit 0
fi

if [[ $EUID -ne 0 ]]; then
    log "must run as root (it writes ${PROFILE_DST})" >&2
    exit 1
fi

if ! command -v apparmor_parser >/dev/null; then
    log "apparmor_parser not found - install the 'apparmor' package" >&2
    exit 1
fi

# `userns,` is an AppArmor 4 rule and an AppArmor 3 parse error:
#   syntax error, unexpected TOK_END_OF_RULE, expecting TOK_MODE
# Dropping it on 3.x costs nothing - user namespace creation is not mediated
# there, and kernel.apparmor_restrict_unprivileged_userns does not exist - while
# keeping one profile file for both. Measured with apparmor_parser -Q on
# ubuntu:24.04 (4.0.1, parses) and ubuntu:22.04 (3.0.4, does not).
parser_major="$(apparmor_parser --version | sed -n 's/.*version \([0-9]\+\).*/\1/p' | head -1)"
log "installing ${PROFILE_SRC} -> ${PROFILE_DST} (apparmor_parser ${parser_major:-?})"
if [[ -n "$parser_major" && "$parser_major" -lt 4 ]]; then
    log "AppArmor ${parser_major}: dropping the 'userns,' rule, which is 4-only"
    grep -v '^[[:space:]]*userns,[[:space:]]*$' "$PROFILE_SRC" >"$PROFILE_DST"
    chmod 0644 "$PROFILE_DST"
else
    install -m 0644 "$PROFILE_SRC" "$PROFILE_DST"
fi

log "loading the profile"
apparmor_parser -r -W "$PROFILE_DST"

if ! aa-status 2>/dev/null | grep -q "^\s*${PROFILE_NAME}$"; then
    log "FAILED: ${PROFILE_NAME} is not in aa-status after loading it" >&2
    exit 1
fi
log "loaded: ${PROFILE_NAME}"

# THE PROOF, and it is worth running every time rather than trusting the load.
#
# This is the exact call bwrap dies on - mount(NULL, "/", NULL, MS_SLAVE|MS_REC)
# from inside a fresh unprivileged user namespace - reduced to one shell line so
# that a failure is legible without a Flatpak, a display or a benchmark run.
# Under docker-default it fails at the mount; unconfined, it fails earlier at
# /proc/self/uid_map. Both messages are in apparmor/parrot-flatpak.
log "verifying with ${TEST_IMAGE}"
if docker run --rm \
        --security-opt seccomp=unconfined \
        --security-opt systempaths=unconfined \
        --security-opt "apparmor=${PROFILE_NAME}" \
        "$TEST_IMAGE" \
        sh -c 'unshare --user --map-root-user --mount sh -c "mount --make-rslave / && echo MOUNT_OK"' \
        2>&1 | grep -q MOUNT_OK; then
    log "OK: bwrap's mount succeeds under ${PROFILE_NAME}"
else
    log "FAILED: the mount is still denied under ${PROFILE_NAME}" >&2
    log "re-run the docker command above without the grep to see which call was refused" >&2
    exit 1
fi

log "done. Allowlist this in the GMT user's capabilities:"
log "  capabilities.measurement.orchestrators.docker.allowed_run_args:"
log "    --security-opt apparmor=${PROFILE_NAME}"
