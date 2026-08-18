#!/usr/bin/env bash
# Install SchildiChat Desktop from the project's GitHub release.
#
# NOT from an APT repository. schildi.chat serves a website and nothing else -
# there is no dists/ tree under it at any suite name - so the .deb attached to
# the GitHub release is the only Linux channel for the desktop client.
#
# WHY A SECOND ELECTRON CLIENT IS IN THE GROUP
#
# SchildiChat Desktop is a fork of Element Desktop: same Electron, same
# matrix-js-sdk, a different UI layer on top. That makes it the nearest thing
# this group has to a control. Every other pairing differs by runtime AND by
# implementation at once, so a gap between Element and Fractal cannot be
# attributed to Electron rather than to everything else that differs.
#
# THE CONTROL IS NOT EXACT, AND THIS MATTERS WHEN READING THE RESULTS
#
# SchildiChat 1.11.36-sc.3 is built on Element 1.11.36, while element/install.sh
# pins Element 1.12.25. The fork trails upstream by roughly a minor release, so
# the pair holds the runtime and the SDK family fixed but NOT the Element
# version. Anything attributed to "the fork's UI layer" therefore carries about
# one Element minor release of upstream change inside it.
#
# Pinning Element back to 1.11.36 would make the control exact, and is not
# possible from element.io's repository - it publishes only the current release.
# It would need the 1.11.36 .deb from Element's own GitHub releases, which is a
# deliberate choice about what the group is for: current Element as a user gets
# it, or an exact fork comparison. This file takes the first.
#
# The version below was read from the GitHub releases API on 2026-08-08.
set -euo pipefail

SCHILDICHAT_VERSION='1.11.36-sc.3'
SCHILDICHAT_DEB="schildichat-desktop_${SCHILDICHAT_VERSION}_amd64.deb"
SCHILDICHAT_URL="https://github.com/SchildiChat/schildichat-desktop/releases/download/v${SCHILDICHAT_VERSION}/${SCHILDICHAT_DEB}"

# UNRESOLVED. The GitHub releases API does not publish a digest for this asset,
# and the .deb is 87 MB - too much to pull just to hash it while another
# benchmark was running on this machine. Fill it in with:
#
#   curl -fsSL "$SCHILDICHAT_URL" | sha256sum
#
# Until then the download is unverified, which is the one place in this group
# where an install is not pinned to content. Every other client is pinned to a
# version string or an OSTree hash.
SCHILDICHAT_SHA256=''

log() { printf '[install-schildichat] %s\n' "$*"; }

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
    ca-certificates curl fonts-liberation fonts-noto-color-emoji \
    fontconfig libsecret-1-0 libnotify4 libnss3 libxtst6 xdg-utils >/dev/null

# fonts-noto-color-emoji is load-bearing, not cosmetic: the scenario adds a
# reaction through the emoji picker, and without a colour emoji font that
# picker is a grid of boxes. The reference screenshot would then record which
# box was clicked rather than which emoji.

log "downloading SchildiChat Desktop ${SCHILDICHAT_VERSION}"
curl -fsSL -o "/tmp/${SCHILDICHAT_DEB}" "$SCHILDICHAT_URL"

if [[ -n "$SCHILDICHAT_SHA256" ]]; then
    log "verifying checksum"
    echo "${SCHILDICHAT_SHA256}  /tmp/${SCHILDICHAT_DEB}" | sha256sum -c -
else
    log "WARNING: no checksum pinned - see the note at the top of this file"
    log "         got sha256 $(sha256sum "/tmp/${SCHILDICHAT_DEB}" | cut -d' ' -f1)"
fi

log "installing"
apt-get install -y -qq "/tmp/${SCHILDICHAT_DEB}" >/dev/null
rm -f "/tmp/${SCHILDICHAT_DEB}"

# EVERYTHING BELOW WAS MEASURED ON ELEMENT FIRST
#
# SchildiChat is the same Electron shell, so it inherits the same three
# container problems, and each of them looks like something other than what it
# is. element/install.sh carries the long form; the short form is:
#
#   * As root it crash-loops with no window even WITH --no-sandbox, because the
#     flag reaches the browser process but not the utility process Electron
#     re-execs. So it runs as uid 1001.
#   * With no secret service it stops on an "unsupported keyring" modal. A
#     running gnome-keyring is necessary but not sufficient - with no desktop
#     environment to detect, Electron also has to be told the backend with
#     --password-store=gnome-libsecret.
#   * The unlock has to happen inside the application's OWN session bus. A
#     setup-command gets a different bus and the application never sees it.
#
# Keeping the two Electron clients on identical launch conditions is the point
# of having both: any difference measured between them should be the fork's UI
# layer, not one of them running as a different user or with a different
# secret-storage backend.
APP_USER=parrot
APP_UID=1001

if ! id -u "$APP_USER" >/dev/null 2>&1; then
    log "creating ${APP_USER} (uid ${APP_UID}) to run SchildiChat as"
    useradd -m -u "$APP_UID" -s /bin/sh "$APP_USER"
fi

apt-get install -y -qq --no-install-recommends gnome-keyring dbus-x11 >/dev/null

# The real binary's path is read back from the package rather than assumed: if
# it is not where this expects, the wrapper would exec a path that does not
# exist and the container would come up with no window and no error naming
# SchildiChat.
REAL="$(dpkg -L schildichat-desktop | grep -E '^/opt/.*/schildichat-desktop$' | head -1)"
if [[ -z "$REAL" ]]; then
    echo "[install-schildichat] FAILED: no schildichat-desktop binary in the package" >&2
    dpkg -L schildichat-desktop | grep -E '^/opt/' | head -20 >&2
    exit 1
fi
log "packaged binary is ${REAL}"
cat > /usr/local/bin/schildichat-desktop <<WRAPPER
#!/bin/sh
# SchildiChat, as uid ${APP_UID}, with a session bus and an unlocked secret
# service. All three parts are load-bearing; see the comments above.
exec runuser -u ${APP_USER} -- env HOME=/home/${APP_USER} DISPLAY="\${DISPLAY:-:99}" \\
    dbus-run-session -- sh -c '
      eval "\$(printf %s "\${PARROT_KEYRING_PASS:-parrot}" | \\
          gnome-keyring-daemon --unlock --daemonize --components=secrets 2>/dev/null)"
      export GNOME_KEYRING_CONTROL
      exec ${REAL} --no-sandbox --password-store=gnome-libsecret "\$@"
    ' schildichat-desktop "\$@"
WRAPPER
chmod +x /usr/local/bin/schildichat-desktop

fc-cache -f >/dev/null 2>&1 || true

# The upload block attaches from local disk, and the file chooser opens on
# $HOME. Running as uid ${APP_UID} means /tmp alone is not enough - without a
# copy in that user's home the block silently attaches nothing.
log "staging the upload image"
cp /tmp/repo/applications/chatclients/parrot.png /tmp/parrot.png
chmod 644 /tmp/parrot.png
cp /tmp/repo/applications/chatclients/parrot.png "/home/${APP_USER}/parrot.png"
chown "${APP_USER}:${APP_USER}" "/home/${APP_USER}/parrot.png"
chmod 644 "/home/${APP_USER}/parrot.png"

log "installed: $(dpkg-query -W -f='${Version}' schildichat-desktop 2>/dev/null || echo 'version query failed')"
