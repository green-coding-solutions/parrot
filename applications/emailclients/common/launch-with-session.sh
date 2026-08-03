#!/usr/bin/env bash
# Launch a mail client inside a D-Bus session with an unlocked keyring.
#
#   launch-with-session.sh evolution
#   launch-with-session.sh mailspring
#
# Use this as the `--startcommand` when recording any client that needs D-Bus or
# a secret service - Evolution, Geary, KMail and Mailspring all do.  The command
# is stored in the .parrot file and replay.py runs it verbatim, so whatever is
# passed here is what every later replay executes.
#
# Why it is needed: the container has no session bus and no login session.
# Evolution's data server and Akonadi are D-Bus activated, and Evolution, Geary
# and Mailspring all read the IMAP password from a secret service.  Without
# this, they either fail to start or prompt for a password mid-measurement.
#
# The keyring is unlocked with an empty passphrase.  That is fine here and
# nowhere else: the container is disposable and holds one synthetic password.
set -euo pipefail

[[ $# -gt 0 ]] || { echo "usage: launch-with-session.sh <command> [args...]" >&2; exit 2; }

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-root}"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

export DISPLAY="${DISPLAY:-:99}"
export LANG="${LANG:-C.UTF-8}"

# Some GNOME components take a different code path when they think no desktop
# is present; claiming GNOME keeps Evolution and Geary on the normal one.
export XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-GNOME}"

# Evolution and Geary render messages with WebKitGTK, which sandboxes its web
# process with bubblewrap.  bwrap needs unprivileged user namespaces, which a
# default Docker container does not grant, and WebKit treats the failure as
# fatal:
#
#   bwrap: Creating new namespace failed: Operation not permitted
#   ERROR **: Failed to fully launch dbus-proxy: Child process exited with code 1
#
# Evolution dies on startup; Geary starts but cannot display a message.  The
# alternative is running the container with --cap-add SYS_ADMIN, which is a
# bigger concession than turning off a sandbox around synthetic mail on an
# isolated network.
export WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1

# No GPU behind Xvfb.  Without these, WebKit tries the DMA-BUF renderer, logs
# "DRI3 error: Could not get DRI3 device", and can hang instead of falling back.
export WEBKIT_DISABLE_DMABUF_RENDERER=1
export WEBKIT_DISABLE_COMPOSITING_MODE=1
export LIBGL_ALWAYS_SOFTWARE=1

# KMail renders messages with QtWebEngine, which is Chromium, which refuses to
# start its zygote as root:
#
#   ERROR:zygote_host_impl_linux.cc(90)] Running as root without --no-sandbox
#   is not supported.
#
# KMail exits rather than falling back, so without this there is no window at
# all.  QtWebEngine takes its Chromium arguments only from this variable.
export QTWEBENGINE_CHROMIUM_FLAGS="--no-sandbox --disable-gpu --disable-dev-shm-usage"

if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    eval "$(dbus-launch --sh-syntax)"
    export DBUS_SESSION_BUS_ADDRESS DBUS_SESSION_BUS_PID
fi

if command -v gnome-keyring-daemon >/dev/null 2>&1; then
    mkdir -p "${HOME}/.local/share/keyrings"
    # An empty passphrase leaves the login keyring unlocked for the daemon's
    # lifetime, which is what lets a pre-seeded password be read back.
    eval "$(printf '\n' | gnome-keyring-daemon --unlock --components=secrets,pkcs11 \
        --daemonize 2>/dev/null || true)"
    export GNOME_KEYRING_CONTROL SSH_AUTH_SOCK
fi

exec "$@"
