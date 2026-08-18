#!/usr/bin/env bash
# Install nheko from the Ubuntu 24.04 archive.
#
# From apt rather than Flathub, deliberately. nheko is the lean native client in
# this group - Qt widgets, C++, no web layer and no runtime - and installing the
# Flatpak would add a ~1 GB org.kde.Platform runtime to the one client whose
# whole point is not having one. The archive build is what a user on Ubuntu
# actually gets.
#
# The version below was read from the Ubuntu noble archive (Launchpad's
# published-binaries API) on 2026-08-08. The `+~` segments are npm-style
# embedded dependency versions, not a typo.
set -euo pipefail

NHEKO_VERSION='0.11.3+~0.9.2+~1.0.0+~0.3.0-1build4'

log() { printf '[install-nheko] %s\n' "$*"; }

pin() {
    if [[ "${PARROT_ALLOW_UNPINNED:-0}" == "1" ]]; then printf '%s' "$1"
    else printf '%s=%s' "$1" "$2"; fi
}

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

log "installing nheko ${NHEKO_VERSION}"
# qml6-module-* are not pulled in by every nheko build's dependencies, and a
# missing QML module does not stop the process: nheko starts, draws an empty
# window and logs the failure to stderr. That is precisely the "plausible
# screen, no error anywhere" case AGENTS.md warns about, so they are explicit.
apt-get install -y -qq --no-install-recommends \
    "$(pin nheko "$NHEKO_VERSION")" \
    qml6-module-qtquick qml6-module-qtquick-controls \
    qml6-module-qtquick-layouts qml6-module-qtquick-window \
    qt6-qpa-plugins \
    fonts-liberation fonts-noto-color-emoji fontconfig \
    libsecret-1-0 dbus-x11 ca-certificates >/dev/null

# nheko keeps the access token in the platform secret store. With no running
# secret service it starts at the login screen on every launch regardless of
# what the profile holds.
apt-get install -y -qq --no-install-recommends gnome-keyring libsecret-tools >/dev/null

# THE LAUNCHER, AND WHY IT IS NOT A SETUP-COMMAND
#
# Measured, not assumed: launching /usr/bin/nheko directly against a seeded
# profile puts a "Unlock Login Keyring - Authentication required" GTK prompt on
# screen and stops there. The container has no session bus of its own, so nheko
# gets one from dbus activation, gnome-keyring starts inside it LOCKED, and
# nothing can unlock it because there is no desktop session to have done so at
# login.
#
# Unlocking the keyring from a setup-command does not fix it. That runs in its
# own short-lived shell with its own DBUS_SESSION_BUS_ADDRESS; nheko launches
# later on a different bus and never sees it. The unlock has to happen INSIDE
# the same session as the application, which means inside the launcher.
#
# The wrapper takes the name `nheko` on PATH so the recording's startcommand
# stays a bare `nheko`. Recordings store that string verbatim and replay.py
# relaunches it, so it must not change after recording.
cat > /usr/local/bin/nheko <<'WRAPPER'
#!/bin/sh
# nheko, with a session bus and an already-unlocked secret service.
exec dbus-run-session -- sh -c '
  eval "$(printf %s "${PARROT_KEYRING_PASS:-parrot}" | \
      gnome-keyring-daemon --unlock --daemonize --components=secrets 2>/dev/null)"
  export GNOME_KEYRING_CONTROL
  exec /usr/bin/nheko "$@"
' nheko "$@"
WRAPPER
chmod +x /usr/local/bin/nheko

fc-cache -f >/dev/null 2>&1 || true

# THE UPLOAD BLOCK NEEDS THE FILE ON LOCAL DISK
#
# The scenario attaches parrot.png from /tmp. The Flatpak entrants get this
# from common/install-flatpak.sh, which also has to punch it through the
# sandbox; nheko runs unsandboxed, so a copy is all it needs. Without it the
# file dialog opens on an empty /root and the block silently attaches nothing.
log "staging the upload image"
cp /tmp/repo/applications/chatclients/parrot.png /tmp/parrot.png
chmod 644 /tmp/parrot.png

log "installed: $(nheko --version 2>/dev/null | head -1 || dpkg-query -W -f='${Version}' nheko)"
