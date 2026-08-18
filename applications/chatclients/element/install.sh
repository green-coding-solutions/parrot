#!/usr/bin/env bash
# Install Element Desktop from element.io's own APT repository.
#
# Not from Ubuntu: there is no element-desktop package in the 24.04 archive at
# all. Not from Flathub either, unlike three of the other clients in this group
# - element.io publishes the .deb as the primary Linux artifact, so this is how
# a user on Ubuntu installs it, and the Flatpak would put an extra runtime in
# the figure that a .deb user never pays for.
#
# The version below was read from the repository's own Packages index on
# 2026-08-08. element.io publishes only the current release there, so this pin
# will stop resolving when they publish the next one - that is the intended
# behaviour: a failed install is a prompt to re-record deliberately, not a
# silent upgrade under a recording that no longer matches.
set -euo pipefail

ELEMENT_VERSION='1.12.25'

log() { printf '[install-element] %s\n' "$*"; }

pin() {
    if [[ "${PARROT_ALLOW_UNPINNED:-0}" == "1" ]]; then printf '%s' "$1"
    else printf '%s=%s' "$1" "$2"; fi
}

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
    ca-certificates curl gnupg fonts-liberation fonts-noto-color-emoji \
    fontconfig libsecret-1-0 >/dev/null

# fonts-noto-color-emoji is load-bearing, not cosmetic: the scenario adds a
# reaction through the emoji picker, and without a colour emoji font that
# picker is a grid of boxes. The reference screenshot would then record which
# box was clicked rather than which emoji.

log "adding the element.io repository"
curl -fsSL https://packages.element.io/debian/element-io-archive-keyring.gpg \
    -o /usr/share/keyrings/element-io-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/element-io-archive-keyring.gpg] https://packages.element.io/debian/ default main" \
    > /etc/apt/sources.list.d/element-io.list
apt-get update -qq

log "installing Element Desktop ${ELEMENT_VERSION}"
apt-get install -y -qq --no-install-recommends \
    "$(pin element-desktop "$ELEMENT_VERSION")" >/dev/null

# RUNNING AS ROOT DOES NOT WORK, EVEN WITH --no-sandbox
#
# Measured. With `--no-sandbox` on the main process, Element gets as far as
# "Opening main window" and then never maps one, while the log fills with:
#
#   ERROR:network_service_instance_impl.cc: Network service crashed or was
#         terminated, restarting service.
#   FATAL:electron_main_delegate.cc:224 Running as root without --no-sandbox
#         is not supported.
#
# The flag reaches the browser process but not the utility process Electron
# re-execs, so the network service dies and is restarted forever. There is no
# window and nothing in the output says "Element" - it looks like a hang.
#
# So Element runs as uid 1001, the same non-root user the three Flatpak clients
# use, and the whole problem disappears. That is also what a real user does:
# nobody runs a chat client as root. nheko remains the odd one out because a
# plain Qt binary genuinely does not care.
APP_USER=parrot
APP_UID=1001

if ! id -u "$APP_USER" >/dev/null 2>&1; then
    log "creating ${APP_USER} (uid ${APP_UID}) to run Element as"
    useradd -m -u "$APP_UID" -s /bin/sh "$APP_USER"
fi

# THE KEYRING, AND WHY THE OBVIOUS FIX IS NOT ENOUGH
#
# Launched with no secret service, Element puts up a modal and stops:
#
#   System unsupported - Your system has an unsupported keyring meaning the
#   database cannot be opened.
#   [Cancel]  [Use weaker encryption]
#
# Taking "Use weaker encryption" would be measuring a different program: it
# stores secrets in plaintext, which is not what an Ubuntu user with
# gnome-keyring running gets.
#
# Starting a secret service is necessary but NOT sufficient - measured, the
# dialog came back unchanged with gnome-keyring running. Electron picks its
# backend from the desktop environment, and there is no desktop environment
# here, so detection fails whatever is listening on the bus. It needs to be
# told which backend to use:
#
#   --password-store=gnome-libsecret
#
# With that plus a running, unlocked gnome-keyring inside the app's own session
# bus, Element comes up on its welcome screen with no prompt at all.
apt-get install -y -qq --no-install-recommends gnome-keyring dbus-x11 >/dev/null

# ELECTRON IN A CONTAINER
#
# Two more things stop Electron dead here and neither error mentions Electron:
#
#   --no-sandbox           Chromium's setuid sandbox needs user namespaces the
#                          container does not grant. Still required even as
#                          uid 1001.
#   /dev/shm               Docker's default is 64 MB. Chromium's renderer maps
#                          shared memory for every surface it composites and
#                          dies partway through a large room. Raised in the
#                          scenario's docker-run-args rather than papered over
#                          with --disable-dev-shm-usage, because that flag moves
#                          the allocation to disk and would change what is being
#                          measured.
#
# The wrapper goes on PATH ahead of the packaged binary so the recording's
# startcommand stays a bare `element-desktop`. Recordings store that string
# verbatim and replay.py relaunches it, so it must not change after recording.
#
# The real binary's path is read back from the package rather than assumed to
# be /opt/Element: if it ever moves, the wrapper would otherwise exec a path
# that does not exist and the container would come up with no window and no
# error that names Element.
REAL="$(dpkg -L element-desktop | grep -E '^/opt/.*/element-desktop$' | head -1)"
if [[ -z "$REAL" ]]; then
    echo "[install-element] FAILED: no element-desktop binary in the package" >&2
    dpkg -L element-desktop | grep -E '^/opt/' | head -20 >&2
    exit 1
fi
log "packaged binary is ${REAL}"
cat > /usr/local/bin/element-desktop <<WRAPPER
#!/bin/sh
# Element, as uid ${APP_UID}, with a session bus and an unlocked secret service.
#
# All three parts are load-bearing and each was measured separately; see the
# comments in install.sh. The unlock has to happen INSIDE this session because
# a setup-command would get its own bus that the application never sees.
exec runuser -u ${APP_USER} -- env HOME=/home/${APP_USER} DISPLAY="\${DISPLAY:-:99}" \\
    dbus-run-session -- sh -c '
      eval "\$(printf %s "\${PARROT_KEYRING_PASS:-parrot}" | \\
          gnome-keyring-daemon --unlock --daemonize --components=secrets 2>/dev/null)"
      export GNOME_KEYRING_CONTROL
      exec ${REAL} --no-sandbox --password-store=gnome-libsecret "\$@"
    ' element-desktop "\$@"
WRAPPER
chmod +x /usr/local/bin/element-desktop

fc-cache -f >/dev/null 2>&1 || true

# THE UPLOAD BLOCK NEEDS THE FILE WHERE THE APP USER CAN READ IT
#
# The scenario attaches parrot.png from local disk. Element runs as uid
# ${APP_UID}, so it goes in that user's home as well as /tmp - the file chooser
# opens on $HOME, and without a copy there the block silently attaches nothing.
log "staging the upload image"
cp /tmp/repo/applications/chatclients/parrot.png /tmp/parrot.png
chmod 644 /tmp/parrot.png
cp /tmp/repo/applications/chatclients/parrot.png "/home/${APP_USER}/parrot.png"
chown "${APP_USER}:${APP_USER}" "/home/${APP_USER}/parrot.png"
chmod 644 "/home/${APP_USER}/parrot.png"

log "installed: $(dpkg-query -W -f='${Version}' element-desktop 2>/dev/null || echo 'version query failed')"
