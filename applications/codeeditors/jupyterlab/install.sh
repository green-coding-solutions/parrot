#!/usr/bin/env bash
# Install JupyterLab 4.6.2 and the browser it is displayed in.
#
# JupyterLab is the only editor in this group that is not a program with a
# window.  It is a server plus a web application, so "the editor" here is
# JupyterLab rendered by Firefox, and both halves have to be pinned.
#
#   Firefox        153.0.3 from ftp.mozilla.org/pub/firefox/releases/, as a
#                  tarball with a published SHA256.
#   JupyterLab     4.6.2 from PyPI, into a virtualenv.
#
# NOT `apt-get install firefox=<version>` from packages.mozilla.org, which is
# what ../../firefox/install.sh does and what this file did first.  That
# repository keeps only the last handful of builds, so the pin rots:
#
#   E: Version '151.0~build2' for 'firefox' was not found
#
# is what that install.sh's pin produces today - five versions later, the
# repository is down to 152.0.5 and newer.  ftp.mozilla.org keeps every release
# forever and publishes a SHA256SUMS file next to each one, which is the same
# property that makes VS Code's version-pinned download URL usable where
# packages.microsoft.com is not.
#
# Ubuntu's own `firefox` package is not an option either: on 24.04 it is a
# transitional stub that installs a snap, and snapd does not run here.
#
# HOW TIGHT THE JUPYTERLAB PIN ACTUALLY IS
#
# `jupyterlab==4.6.2` pins JupyterLab and nothing else: pip resolves jupyter
# -server, notebook-shim, tornado, traitlets and about forty more at install
# time, so two installs months apart get the same JupyterLab and possibly
# different dependencies.  That is weaker than the tarball-plus-sha256 pins the
# rest of this group uses, and it is a property of pip rather than of anything
# fixable here.  A full `pip freeze` lock would close it; it is not committed
# because it would have to be regenerated on every Python or platform change,
# and the thing being measured - JupyterLab's editor - is pinned exactly.
#
# NOTHING IS CONFIGURED in the editor.  No settings overrides, no disabled
# extensions, no Firefox prefs.  The two server flags below are harness, not
# preference, and are explained where they are set.
set -euo pipefail

JUPYTERLAB_VERSION='4.6.2'
FIREFOX_VERSION='153.0.3'
FIREFOX_SHA256='22b312280900bfb174b685ece32c7b3c6d72e7f8e53d6d30f21ac41a8dc500a2'
FIREFOX_URL="https://ftp.mozilla.org/pub/firefox/releases/${FIREFOX_VERSION}/linux-x86_64/en-US/firefox-${FIREFOX_VERSION}.tar.xz"

log() { printf '[install-jupyterlab] %s\n' "$*"; }

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

# The tarball bundles everything Gecko needs except the system GTK stack.
log "installing runtime dependencies and Python"
apt-get install -y -qq --no-install-recommends \
    libgtk-3-0 libdbus-glib-1-2 libasound2t64 libxt6 libx11-xcb1 libxcb-shm0 \
    libfreetype6 libfontconfig1 fontconfig fonts-dejavu-core fonts-liberation \
    python3 python3-venv python3-pip xz-utils ca-certificates wget >/dev/null
fc-cache -f >/dev/null 2>&1 || true

FF_MARKER="/opt/firefox/.parrot-${FIREFOX_VERSION}"
if [[ -f "$FF_MARKER" ]]; then
    log "Firefox ${FIREFOX_VERSION} already unpacked, skipping download"
else
    log "downloading Firefox ${FIREFOX_VERSION}"
    wget -q -O /tmp/firefox.tar.xz "$FIREFOX_URL"

    log "verifying checksum"
    echo "${FIREFOX_SHA256}  /tmp/firefox.tar.xz" | sha256sum -c -

    log "unpacking to /opt/firefox"
    rm -rf /opt/firefox
    mkdir -p /opt/firefox
    tar -xJf /tmp/firefox.tar.xz -C /opt/firefox --strip-components=1
    rm -f /tmp/firefox.tar.xz
    touch "$FF_MARKER"
fi

# --- JupyterLab, into a virtualenv -------------------------------------------
# A venv rather than `pip install --break-system-packages`: Ubuntu 24.04 marks
# its Python as externally managed (PEP 668), and overriding that puts pip's
# packages where apt's live.
MARKER="/opt/jupyter/.parrot-${JUPYTERLAB_VERSION}"
if [[ -f "$MARKER" ]]; then
    log "JupyterLab ${JUPYTERLAB_VERSION} already installed, skipping"
else
    log "installing JupyterLab ${JUPYTERLAB_VERSION}"
    rm -rf /opt/jupyter
    python3 -m venv /opt/jupyter
    /opt/jupyter/bin/pip install -q --no-cache-dir "jupyterlab==${JUPYTERLAB_VERSION}"
    touch "$MARKER"
fi

# A profile from scratch on every setup pass, so run N starts where run 1 did.
# Firefox's own state is the bigger half of this: a profile that has been used
# once has the onboarding already shown, the session ready to restore, and
# 127.0.0.1:8888 in its history, so the URL bar autocompletes as the macro
# types.  JupyterLab's own state - which files were open, the layout - lives
# under ~/.jupyter and ~/.local/share/jupyter.
rm -rf /root/.mozilla /root/.cache/mozilla
rm -rf /root/.jupyter /root/.local/share/jupyter /root/.ipython

# The server, started in the background and left running for the whole session.
# Two flags, both harness rather than preference:
#
#   --IdentityProvider.token=''  JupyterLab otherwise mints a random token per
#                                start and puts it in the URL.  That URL is
#                                typed by the macro and shown in the URL bar of
#                                every screenshot, so a fresh token every run
#                                would make both unreproducible.
#   --ServerApp.root_dir         the project, so the file browser opens on it -
#                                the equivalent of the folder argument every
#                                other editor in this group is given.
#
# --no-browser because the macro opens Firefox itself, as its first block.
cat > /usr/local/bin/jupyter-server-start <<'SERVER'
#!/bin/sh
mkdir -p /var/log
nohup /opt/jupyter/bin/jupyter lab \
    --no-browser \
    --allow-root \
    --ip=127.0.0.1 --port=8888 \
    --IdentityProvider.token='' \
    --ServerApp.root_dir=/root/project \
    >/var/log/jupyter.log 2>&1 &
# Wait for the port, so that "the server was not up yet" can never be one of the
# things a recording accidentally measures.
for _ in $(seq 1 120); do
    if (echo > /dev/tcp/127.0.0.1/8888) 2>/dev/null; then
        echo "[jupyter] server listening on 127.0.0.1:8888"
        exit 0
    fi
    sleep 1
done
echo "[jupyter] server did not come up; last log lines:" >&2
tail -20 /var/log/jupyter.log >&2
exit 1
SERVER
chmod +x /usr/local/bin/jupyter-server-start

cat > /usr/local/bin/jupyterlab <<'WRAPPER'
#!/bin/sh
exec /opt/firefox/firefox "http://127.0.0.1:8888/lab" "$@"
WRAPPER
chmod +x /usr/local/bin/jupyterlab

log "installed: JupyterLab $(/opt/jupyter/bin/jupyter lab --version 2>/dev/null) / $(/opt/firefox/firefox --version 2>/dev/null)"
