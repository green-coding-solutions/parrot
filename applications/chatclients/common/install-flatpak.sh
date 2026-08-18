#!/usr/bin/env bash
# Install a Flatpak chat client into the window container, pinned to a commit.
#
#   install-flatpak.sh <ref> <app-commit> [runtime-ref] [runtime-commit]
#   install-flatpak.sh org.gnome.Fractal 3aed0380... org.gnome.Platform//48 d0d8f788...
#
# Adapted from applications/wordprocessors/common/install-flatpak.sh, which
# carries the full explanation of why the application runs as uid 1001 and why
# that is what lets the container drop CAP_SYS_ADMIN and CAP_NET_ADMIN. The
# short version is below; read that file before changing anything here.
#
# WHY THE COMMITS
#
# A Flatpak ref names a BRANCH - `app/org.gnome.Fractal/x86_64/stable` - and
# that branch moves. Installing it unpinned is the same mistake as installing
# from an APT repository without a version: the benchmark would measure a
# different application every few weeks and no recording would survive it. An
# OSTree commit is immutable and is the Flatpak equivalent of a SHA-256.
#
# RESOLVING A COMMIT
#
# Pass the literal string RESOLVE as the commit to install the current branch
# and have this script print the commit it landed on, ready to be pasted back
# into the client's install.sh. That is a bootstrapping step, not a benchmark:
# a RESOLVE install is unpinned by definition.
#
#   flatpak remote-info flathub org.gnome.Fractal      # the same thing, remotely
set -euo pipefail

REF="${1:?usage: install-flatpak.sh <ref> <app-commit> [runtime-ref] [runtime-commit]}"
COMMIT="${2:?a commit is required - pass RESOLVE to discover it}"
RUNTIME_REF="${3:-}"
RUNTIME_COMMIT="${4:-}"

# The application does not run as root. This is what lets the container drop
# CAP_SYS_ADMIN and CAP_NET_ADMIN. 1000 is taken in this image (`ubuntu`), so 1001.
APP_USER=parrot
APP_UID=1001

log() { printf '[install-flatpak] %s\n' "$*"; }

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

# A SANDBOXED APP NEEDS A PORTAL, NOT JUST A SECRET SERVICE
#
# xdg-desktop-portal is here because Fractal will not start without it, and the
# failure names the wrong thing. Fractal 14 puts up a full-window "Secret Portal
# Error - Could not restore previous sessions", and its own advice is to run
#
#   flatpak override --talk-name=org.freedesktop.secrets org.gnome.Fractal
#
# which does NOT work - measured. The reason is oo7, the secret library Fractal
# uses: inside a Flatpak it always takes its file backend, and that backend gets
# its encryption key from org.freedesktop.portal.Secret. With no portal on the
# bus there is nothing to fall back to, whatever the app is allowed to talk to:
#
#   ERROR fractal::secret::linux: Could not restore previous sessions: secret
#   error: File backend error Portal communication failed ... The name
#   org.freedesktop.portal.Desktop was not provided by any .service files
#
# xdg-desktop-portal-gtk is the frontend backend; the Secret implementation
# comes from gnome-keyring, which is already installed above. Both are D-Bus
# activated, so nothing has to be started by hand - but XDG_CURRENT_DESKTOP has
# to be set for the portal to pick an implementation at all, which is done in
# flatpak-session below.
log "installing flatpak"
apt-get install -y -qq --no-install-recommends \
    flatpak ca-certificates dbus dbus-x11 gnome-keyring \
    xdg-desktop-portal xdg-desktop-portal-gtk \
    fonts-liberation fonts-noto-color-emoji fontconfig >/dev/null

# fonts-noto-color-emoji is not cosmetic here, unlike in the word-processor
# group. The scenario adds a reaction through the client's emoji picker, and
# every one of these clients renders that picker with the host or runtime emoji
# font. Without a colour emoji font the picker is a grid of boxes, and the
# reference screenshots record which box was clicked rather than which emoji.

if ! getent passwd "$APP_USER" >/dev/null; then
    log "creating ${APP_USER} (uid ${APP_UID}) - the user the application runs as"
    useradd -m -u "$APP_UID" -s /bin/sh "$APP_USER"
fi

# The session a `flatpak run` needs, as an unprivileged user. See the long note
# in the word-processor group's copy for why bwrap needs this and why running
# as root is the thing that breaks it.
#
# THE SECRET SERVICE HAS TO BE STARTED INSIDE THIS SESSION, not before it.
#
# Every client in this group stores its Matrix access token in the Secret
# Service - Fractal through libsecret,
# FluffyChat through flutter_secure_storage, which is libsecret. With nothing
# answering on org.freedesktop.secrets they either refuse to complete sign-in or
# put a keyring prompt on screen, and block 2 ends somewhere other than where
# script.md says it ends.
#
# Unlocking it from a setup-command does NOT work and was measured not to on
# nheko: that shell gets its own DBUS_SESSION_BUS_ADDRESS from its own
# dbus-run-session, and the application launches later on a different bus. The
# daemon has to come up on the same bus the application uses, which means inside
# this wrapper, after dbus-run-session and before the exec. Flatpak's default
# policy already lets a sandboxed app talk to org.freedesktop.secrets on the
# session bus, so nothing extra is needed on the sandbox side.
#
# This is the same shape as the two Electron clients' wrappers - deliberately,
# so that all six sign in against an unlocked secret service rather than four of
# them measuring a keyring prompt.
cat > /usr/local/bin/flatpak-session <<WRAP
#!/bin/sh
set -e

export XDG_RUNTIME_DIR=/run/user/${APP_UID}
mkdir -p "\$XDG_RUNTIME_DIR"
chown ${APP_UID}:${APP_UID} "\$XDG_RUNTIME_DIR"
chmod 700 "\$XDG_RUNTIME_DIR"

if [ ! -S /run/dbus/system_bus_socket ]; then
    mkdir -p /run/dbus
    rm -f /run/dbus/pid
    dbus-daemon --system --fork
fi

# XDG_CURRENT_DESKTOP is what lets xdg-desktop-portal choose an implementation.
# Unset, the portal activates and then serves nothing, which looks exactly like
# the portal not being installed:
#   Choosing gnome-keyring.portal for org.freedesktop.impl.portal.Secret
# is the line that says it worked.
exec setpriv --reuid ${APP_UID} --regid ${APP_UID} --init-groups \\
     env HOME=/home/${APP_USER} XDG_RUNTIME_DIR="\$XDG_RUNTIME_DIR" \\
         XDG_CURRENT_DESKTOP=GNOME \\
     dbus-run-session -- sh -c '
       eval "\$(printf %s "\${PARROT_KEYRING_PASS:-parrot}" | \\
           gnome-keyring-daemon --unlock --daemonize --components=secrets 2>/dev/null)"
       export GNOME_KEYRING_CONTROL
       exec "\$@"
     ' flatpak-session "\$@"
WRAP
chmod +x /usr/local/bin/flatpak-session

fc-cache -f >/dev/null 2>&1 || true

log "adding flathub"
flatpak remote-add --if-not-exists flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo

log "installing ${REF} (this pulls a runtime and is large)"
flatpak install -y --noninteractive flathub "$REF"

if [[ "$COMMIT" == "RESOLVE" ]]; then
    RESOLVED="$(flatpak info --show-commit "$REF")"
    log "UNPINNED. Paste this back into the client's install.sh:"
    log "  COMMIT=${RESOLVED}"
    if [[ -n "$RUNTIME_REF" ]]; then
        log "  RUNTIME_COMMIT=$(flatpak info --show-commit "$RUNTIME_REF" 2>/dev/null || echo '<runtime not installed>')"
    fi
else
    if [[ -n "$RUNTIME_REF" && -n "$RUNTIME_COMMIT" && "$RUNTIME_COMMIT" != "RESOLVE" ]]; then
        log "pinning ${RUNTIME_REF} to ${RUNTIME_COMMIT:0:12}"
        flatpak update -y --noninteractive --commit="$RUNTIME_COMMIT" "$RUNTIME_REF"
    fi

    log "pinning ${REF} to ${COMMIT:0:12}"
    flatpak update -y --noninteractive --commit="$COMMIT" "$REF"

    # Read the commit back. An unpinned install is completely silent otherwise.
    GOT="$(flatpak info --show-commit "$REF" 2>/dev/null || true)"
    if [[ "$GOT" != "$COMMIT" ]]; then
        echo "[install-flatpak] FAILED: ${REF} is at ${GOT:-<none>}, wanted ${COMMIT}" >&2
        exit 1
    fi
    log "commit ok: ${GOT}"
fi

# THE UPLOAD BLOCK NEEDS A FILE THE SANDBOX CAN SEE
#
# Flatpak sandboxes the filesystem, and /tmp is NOT shared in - the sandbox gets
# its own. The scenario attaches parrot.png from local disk, so the path has to
# be granted explicitly rather than assumed to work.
#
# It also goes in the application user's home, because that is where a file
# chooser opens. /tmp alone means the block silently attaches nothing unless the
# chooser is navigated there by hand, which is not what script.md describes.
log "staging the upload image"
flatpak override --filesystem=/tmp "$REF"
cp /tmp/repo/applications/chatclients/parrot.png /tmp/parrot.png
chmod 644 /tmp/parrot.png
chown "${APP_UID}:${APP_UID}" /tmp/parrot.png
cp /tmp/repo/applications/chatclients/parrot.png "/home/${APP_USER}/parrot.png"
chown "${APP_UID}:${APP_UID}" "/home/${APP_USER}/parrot.png"
chmod 644 "/home/${APP_USER}/parrot.png"

log "installed: $(flatpak info "$REF" 2>/dev/null | grep -E '^\s*Version:' | tr -s ' ')"
