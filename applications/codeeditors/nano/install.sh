#!/usr/bin/env bash
# Install GNU nano and the xterm it runs in, from Ubuntu 24.04.
#
# Both versions are pinned to the exact package the 24.04 archive holds, so a
# rebuild next year installs the same editor rather than whatever has landed in
# the pocket since.  The base image is pinned by digest, so these keep resolving.
#
# NOTHING IS CONFIGURED.  No .nanorc is written: nano runs on its compiled-in
# defaults plus Debian's /etc/nanorc, which is what you get from `apt install
# nano` followed by `nano`.  That means no syntax highlighting and no line
# numbers - which is nano, and is part of what is being measured.
set -euo pipefail

NANO_VERSION='7.2-2ubuntu0.2'
XTERM_VERSION='390-1ubuntu3'

log() { printf '[install-nano] %s\n' "$*"; }

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

# xterm needs a font it can actually render.  fonts-dejavu-core carries DejaVu
# Sans Mono, which the launch command below names explicitly - a terminal whose
# cell size depends on which fonts happen to be installed has a different number
# of columns on every machine, and every screenshot would differ.
log "installing xterm ${XTERM_VERSION} and nano ${NANO_VERSION}"
apt-get install -y -qq --no-install-recommends \
    "xterm=${XTERM_VERSION}" \
    "nano=${NANO_VERSION}" \
    fonts-dejavu-core >/dev/null
fc-cache -f >/dev/null 2>&1 || true

# The terminal the scenario is driven through.  Vim itself is started by typing
# `vim` at this shell, because that is what "start the application" means for an
# editor that lives in a terminal - and it is the step the benchmark is timing.
#
# -fa/-fs pin the face and size so the character cell, and therefore the number
# of columns and rows, is the same on every machine.
# +sb removes the scrollbar, which would otherwise take a column-width strip out
# of the left edge and shift every coordinate.
# -bg/-fg are stated rather than left to the X defaults database, which xterm
# reads from ~/.Xresources and which is not present in a fresh container.
#
# The shell starts in /root/project, which is the terminal equivalent of the
# other editors being launched on the project folder.  --noprofile --norc keeps
# the prompt and the environment out of the hands of whatever bash would
# otherwise read, so the first screenshot is the same on every machine.
cat > /usr/local/bin/nano-term <<'WRAPPER'
#!/bin/sh
exec xterm \
    -fa 'DejaVu Sans Mono' -fs 11 \
    +sb \
    -bg black -fg white \
    -title nano-benchmark \
    -e /bin/sh -c 'cd /root/project && exec /bin/bash --noprofile --norc'
WRAPPER
chmod +x /usr/local/bin/nano-term

log "installed: $(nano --version | head -n1)"
log "installed: $(xterm -version)"
