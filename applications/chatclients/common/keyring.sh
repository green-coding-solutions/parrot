#!/usr/bin/env bash
# Create and unlock a GNOME keyring, so clients that store their access token in
# the Secret Service find one running.
#
#   keyring.sh [password]
#
# WHY THIS GROUP NEEDS IT AND THE EMAIL GROUP MOSTLY DID NOT
#
# Four of the six clients here put the access token - or the key that decrypts
# it - in the Secret Service rather than in a file. With no secret service on
# the bus, the behaviour is NOT an error: the client starts, finds no stored
# session, and shows its login screen. The seeded profile is present and
# ignored. That is a plausible-looking screen with nothing wrong in any log,
# which is the failure mode AGENTS.md is built around, and it would turn block
# 1 into "log in by hand" for some clients and "the mailbox is already there"
# for others.
#
# THE CONSTRAINT THAT MAKES THIS AWKWARD - READ BEFORE WIRING IT UP
#
# gnome-keyring-daemon registers on the SESSION bus. A client only finds it if
# it shares that bus. That is fine for the apt-installed clients, which this
# script can serve directly. It is NOT fine for the three Flatpak clients:
# `flatpak run` goes through `dbus-run-session`, which creates a NEW session
# bus, so a daemon started here is invisible inside the sandbox - and a Flatpak
# reaches the Secret Service through the portal, which needs the daemon on the
# bus the sandbox was given.
#
# So for the Flatpak clients this has to be started INSIDE the session, i.e.
# from within flatpak-session's `dbus-run-session -- ...` invocation, not as a
# separate setup-command. That wiring is left to each client's install/seed
# step rather than guessed at here, because whether a given client uses the
# portal or talks to the host service depends on its Flatpak permissions.
#
# NOT VERIFIED. Nothing in this file has been run - no container has been built
# yet. Treat it as the intended shape, and expect the first real run to correct
# it.
set -euo pipefail

KEYRING_PASS="${1:-parrot}"

log() { printf '[keyring] %s\n' "$*"; }

if ! command -v gnome-keyring-daemon >/dev/null 2>&1; then
    log "installing gnome-keyring"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq --no-install-recommends \
        gnome-keyring libsecret-1-0 libsecret-tools dbus-x11 >/dev/null
fi

# A login keyring whose password is known, so it can be unlocked
# non-interactively. Without one, --unlock creates it on the fly with the
# password supplied on stdin, which is what happens on first run here.
install -d -m 0700 "${HOME}/.local/share/keyrings"

if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    log "WARNING: no DBUS_SESSION_BUS_ADDRESS - starting one"
    log "         a client on a DIFFERENT session bus will not see this keyring"
    eval "$(dbus-launch --sh-syntax)"
    export DBUS_SESSION_BUS_ADDRESS DBUS_SESSION_BUS_PID
fi

log "unlocking the login keyring on ${DBUS_SESSION_BUS_ADDRESS}"
printf '%s' "$KEYRING_PASS" | gnome-keyring-daemon --unlock --replace --daemonize \
    --components=secrets,pkcs11 >/dev/null 2>&1 || {
        log "ERROR: gnome-keyring-daemon refused to start"
        exit 1
    }

# Prove the service is actually on the bus. Starting the daemon and having it
# fail to own org.freedesktop.secrets looks identical to success from the shell.
if command -v secret-tool >/dev/null 2>&1; then
    if printf 'probe' | secret-tool store --label=parrot-probe parrot probe >/dev/null 2>&1 \
       && [[ "$(secret-tool lookup parrot probe 2>/dev/null)" == 'probe' ]]; then
        log "secret service answers: store and lookup both work"
        secret-tool clear parrot probe >/dev/null 2>&1 || true
    else
        log "ERROR: the secret service did not answer a store/lookup probe"
        log "       clients will fall back to their login screen"
        exit 1
    fi
else
    log "WARNING: secret-tool not installed, cannot prove the service answers"
fi

log "ready"
