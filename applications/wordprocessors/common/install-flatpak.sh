#!/usr/bin/env bash
# Install a Flatpak application into the window container, pinned to a commit.
#
#   install-flatpak.sh <ref> <app-commit> [runtime-ref] [runtime-commit]
#   install-flatpak.sh org.kde.calligra 3aed0380... org.kde.Platform//6.10 d0d8f788...
#
# WHY THE COMMITS
#
# A Flatpak ref names a BRANCH - `app/org.kde.calligra/x86_64/stable` - and that
# branch moves. Installing it unpinned is the same mistake as installing from an
# APT repository without a version: the benchmark would measure a different
# application every few weeks and no recording would survive it. An OSTree
# commit is immutable and is the Flatpak equivalent of a SHA-256.
#
# `flatpak install` has no --commit, so this is a two-step: install the branch,
# then `flatpak update --commit=` onto the pin. When the pin IS the current
# commit - which it is at the moment each of these was recorded - the second
# step downloads nothing.
#
# The RUNTIME is pinned too. It is the larger half of the download (about 1 GB
# installed for org.kde.Platform 6.10) and it is just as much a part of what is
# being measured as the application: a runtime update changes the Qt, the theme
# and the fonts the app draws with, which changes the reference screenshots.
#
# The Flatpak runtime cost stays in the measurement. Calligra Words and
# Collabora Office are installed the way their projects ship them, and what the
# runtime costs to pull in and start is part of what a user pays for choosing
# them - see the group README. It is deliberately NOT shared with anything else
# and not warmed outside the measured flow beyond what installation requires.
set -euo pipefail

REF="${1:?usage: install-flatpak.sh <ref> <app-commit> [runtime-ref] [runtime-commit]}"
COMMIT="${2:?a commit is required - see the note above}"
RUNTIME_REF="${3:-}"
RUNTIME_COMMIT="${4:-}"

# The application does not run as root. This is what lets the container drop
# CAP_SYS_ADMIN and CAP_NET_ADMIN - see the note in flatpak-session below.
# 1000 is taken in this image (`ubuntu`), so 1001.
APP_USER=parrot
APP_UID=1001

log() { printf '[install-flatpak] %s\n' "$*"; }

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

log "installing flatpak"
apt-get install -y -qq --no-install-recommends \
    flatpak ca-certificates dbus dbus-x11 \
    fonts-liberation fontconfig >/dev/null

# THE USER THE APPLICATION RUNS AS
#
# Everything else in this container runs as root, and these two do not. That is
# not tidiness - it is what removes CAP_SYS_ADMIN and CAP_NET_ADMIN from the
# container. See the long note in flatpak-session below.
if ! getent passwd "$APP_USER" >/dev/null; then
    log "creating ${APP_USER} (uid ${APP_UID}) - the user the application runs as"
    useradd -m -u "$APP_UID" -s /bin/sh "$APP_USER"
fi

# dbus and dbus-x11 are not optional and the image has neither. Without a bus
# `flatpak run` stops at
#   error: Could not connect: No such file or directory
# before it reaches bubblewrap, so it looks nothing like a sandbox problem.
# /usr/local/bin/flatpak-session below supplies both buses and the
# XDG_RUNTIME_DIR flatpak expects, and is what usage_scenario.yml's
# startcommand goes through.
cat > /usr/local/bin/flatpak-session <<WRAP
#!/bin/sh
# Run its arguments with the session a \`flatpak run\` needs, as an
# UNPRIVILEGED user.
#
#   flatpak-session flatpak run --command=calligrawords org.kde.calligra
#
# The window container has no init, no logind and no D-Bus. flatpak wants a
# system bus and a session bus, and an XDG_RUNTIME_DIR that exists.
#
# WHY IT DROPS PRIVILEGES, AND WHY HERE
#
# bwrap - and so every \`flatpak run\` - can build its sandbox two ways: the
# privileged path, which needs CAP_SYS_ADMIN, and the unprivileged one, which
# unshares a USER namespace first and so holds both CAP_SYS_ADMIN and
# CAP_NET_ADMIN inside it for free. bwrap chooses by looking at the real uid:
# as root it takes the privileged path, because root normally HAS those
# capabilities. A Docker container is precisely the case that breaks the
# assumption - uid 0, but CapEff 00000000a80425fb, with neither capability in
# it - so bwrap commits to a path it cannot finish, and the only way to rescue
# it is to hand the whole container SYS_ADMIN and NET_ADMIN.
#
# Running the application as uid ${APP_UID} makes bwrap take the unprivileged
# path instead, and then the container needs no capabilities at all. Confirmed
# rather than assumed: as root, \`bwrap --unshare-all\` reports "Creating new
# namespace failed"; as ${APP_USER}, in the same container, it reports the
# unprivileged-userns message and then succeeds. See the docker-run-args
# comment in either scenario file for the full matrix.
#
# The buses and the runtime directory still have to be created as root, which
# is why the drop happens inside this wrapper rather than in the scenario's
# startcommand: the recordings store that string verbatim and replay.py
# relaunches it, so changing it would invalidate every .parrot in the group.
set -e

export XDG_RUNTIME_DIR=/run/user/${APP_UID}
mkdir -p "\$XDG_RUNTIME_DIR"
chown ${APP_UID}:${APP_UID} "\$XDG_RUNTIME_DIR"
chmod 700 "\$XDG_RUNTIME_DIR"

if [ ! -S /run/dbus/system_bus_socket ]; then
    mkdir -p /run/dbus
    # A pid file left behind by a bus that died with the container makes
    # dbus-daemon refuse to start, and the error names the pid file rather than
    # anything to do with flatpak.
    rm -f /run/dbus/pid
    dbus-daemon --system --fork
fi

exec setpriv --reuid ${APP_UID} --regid ${APP_UID} --init-groups \\
     env HOME=/home/${APP_USER} XDG_RUNTIME_DIR="\$XDG_RUNTIME_DIR" \\
     dbus-run-session -- "\$@"
WRAP
chmod +x /usr/local/bin/flatpak-session

# fonts-liberation is for the host side of the container; the Flatpak runtime
# carries its own fonts, and whether the document's typefaces resolve inside the
# sandbox has to be checked per app rather than assumed.
fc-cache -f >/dev/null 2>&1 || true

log "adding flathub"
flatpak remote-add --if-not-exists flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo

log "installing ${REF} (this pulls a runtime and is large)"
flatpak install -y --noninteractive flathub "$REF"

if [[ -n "$RUNTIME_REF" && -n "$RUNTIME_COMMIT" ]]; then
    log "pinning ${RUNTIME_REF} to ${RUNTIME_COMMIT:0:12}"
    flatpak update -y --noninteractive --commit="$RUNTIME_COMMIT" "$RUNTIME_REF"
fi

log "pinning ${REF} to ${COMMIT:0:12}"
flatpak update -y --noninteractive --commit="$COMMIT" "$REF"

# Read the commit back. An unpinned install is completely silent otherwise, in
# exactly the way an unmatched fluxbox rule is.
GOT="$(flatpak info --show-commit "$REF" 2>/dev/null || true)"
if [[ "$GOT" != "$COMMIT" ]]; then
    echo "[install-flatpak] FAILED: ${REF} is at ${GOT:-<none>}, wanted ${COMMIT}" >&2
    exit 1
fi
log "commit ok: ${GOT}"

log "staging the document"
# Flatpak sandboxes the filesystem. The document has to live somewhere the app
# can reach; /tmp is NOT shared into a Flatpak sandbox by default - the sandbox
# gets its own - so the app is granted it explicitly rather than the path being
# assumed to work.
flatpak override --filesystem=/tmp "$REF"
cp /tmp/repo/applications/wordprocessors/parrot-report.odt /tmp/parrot-report.odt
cp /tmp/repo/applications/wordprocessors/parrot.png        /tmp/parrot.png
chmod 644 /tmp/parrot-report.odt /tmp/parrot.png

# The application runs as ${APP_USER}, so it has to be able to save over the
# document and write the exported PDF beside it. `chmod 644` alone is not
# enough: the apps save by writing a temporary file and renaming it over the
# original, and /tmp carries the sticky bit, so the RENAME needs ownership of
# the file being replaced. Group-readable is deliberate - check-result.sh reads
# both files back as root.
chown "${APP_UID}:${APP_UID}" /tmp/parrot-report.odt /tmp/parrot.png

log "installed: $(flatpak info "$REF" 2>/dev/null | grep -E '^\s*Version:' | tr -s ' ')"
