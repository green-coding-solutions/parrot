#!/usr/bin/env bash
# Install GNU Emacs from Ubuntu 24.04, pinned to the exact archive version.
#
# emacs-gtk rather than emacs-nox: Emacs has a real X11 window, so it is driven
# as a windowed application like VS Code or IntelliJ rather than inside an
# xterm.  The terminal editors in this group - Vim, Neovim, nano - are the ones
# with no window of their own.
#
# NOTHING IS CONFIGURED.  No init.el is written; Emacs runs on its defaults,
# which means the splash screen on startup and no syntax theme beyond the
# built-in one.
set -euo pipefail

EMACS_VERSION='1:29.3+1-1ubuntu2'

log() { printf '[install-emacs] %s\n' "$*"; }

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

log "installing emacs-gtk ${EMACS_VERSION}"
apt-get install -y -qq --no-install-recommends \
    "emacs-gtk=${EMACS_VERSION}" \
    fonts-dejavu-core fonts-liberation >/dev/null
fc-cache -f >/dev/null 2>&1 || true

# A profile from scratch on every setup pass.
rm -rf /root/.emacs.d /root/.emacs /root/.config/emacs

log "installed: $(emacs --version | head -n1)"

# Launch from inside the project, so C-x C-f offers /root/project as its default
# directory - the terminal equivalent of the GUI editors being started on the
# project folder.
cat > /usr/local/bin/emacs-run <<'WRAPPER'
#!/bin/sh
cd /root/project || exit 1
exec /usr/bin/emacs "$@"
WRAPPER
chmod +x /usr/local/bin/emacs-run
