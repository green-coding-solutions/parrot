#!/usr/bin/env bash
# Install the Eclipse IDE for Java Developers 2025-06 from the Eclipse Foundation's
# archive.
#
# archive.eclipse.org rather than www.eclipse.org/downloads: the download page
# hands out a mirror redirect that resolves differently by geography and stops
# resolving at all once a release ages out, while the archive keeps every past
# release at a stable path forever.  That is the property a recording needs.
#
# WHICH PACKAGE, AND WHAT IT MEANS FOR A PYTHON FILE
#
# "Eclipse" on its own is not a product - the Foundation ships a dozen EPP
# packages off the same platform.  This is `eclipse-java`, the Eclipse IDE for
# Java Developers, which is the one the download page offers first and the one
# most people mean.  It has no Python tooling, so src/price_calculator.py opens
# in the platform's generic text editor: no syntax highlighting, no auto-indent,
# no symbol index.  That is a real and visible difference from PyCharm, which is
# the same company's answer to the same question one row up in the table, and it
# is left alone rather than fixed by installing PyDev - see MEASUREMENTS.md.
#
# NOTHING IS CONFIGURED.  No workspace is pre-created and no preference is
# seeded, so the launcher's "Select a directory as workspace" dialog and the
# Welcome page both appear on first start and the macro clicks through them the
# way a person would.
set -euo pipefail

ECLIPSE_RELEASE='2025-06'
ECLIPSE_SHA256='1f7b75c983ea598acf77793a3305308fce88e060f094185a9aaadb09871228ec'
ECLIPSE_URL="https://archive.eclipse.org/technology/epp/downloads/release/${ECLIPSE_RELEASE}/R/eclipse-java-${ECLIPSE_RELEASE}-R-linux-gtk-x86_64.tar.gz"

log() { printf '[install-eclipse] %s\n' "$*"; }

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

# The tarball bundles its own JRE - JustJ OpenJDK 21, under plugins/ - and
# eclipse.ini already points -vm at it, so there is no JDK from apt here.
#
# What it does not bundle is GTK.  SWT is a thin binding over the system GTK 3,
# and libwebkit2gtk is not optional either: the Welcome page is an SWT Browser
# widget, and without WebKit Eclipse puts up a "Could not initialize the
# browser" error instead.  That error is a property of a broken install rather
# than of Eclipse, and measuring it would be measuring the harness.
log "installing runtime dependencies"
apt-get install -y -qq --no-install-recommends \
    libgtk-3-0 libwebkit2gtk-4.1-0 libxtst6 libxi6 libsecret-1-0 \
    libfreetype6 libfontconfig1 fontconfig fonts-dejavu-core fonts-liberation \
    ca-certificates wget >/dev/null

# Skip the 350 MB download when this exact release is already unpacked.  In a
# fresh container - which is what every benchmark and every replay runs in - the
# marker never exists and the download always happens, so the production path is
# unchanged.  It only pays off while iterating in a container kept alive.
MARKER="/opt/eclipse/.parrot-${ECLIPSE_RELEASE}"
if [[ -f "$MARKER" ]]; then
    log "Eclipse ${ECLIPSE_RELEASE} already unpacked, skipping download"
else
    log "downloading Eclipse IDE for Java Developers ${ECLIPSE_RELEASE} (~350 MB)"
    wget -q -O /tmp/eclipse.tar.gz "$ECLIPSE_URL"

    log "verifying checksum"
    echo "${ECLIPSE_SHA256}  /tmp/eclipse.tar.gz" | sha256sum -c -

    log "unpacking to /opt/eclipse"
    rm -rf /opt/eclipse
    mkdir -p /opt/eclipse
    tar -xzf /tmp/eclipse.tar.gz -C /opt/eclipse --strip-components=1
    rm -f /tmp/eclipse.tar.gz
    # A copy of configuration/ exactly as shipped, taken before Eclipse has ever
    # run - see the reset below for what it is for.
    cp -a /opt/eclipse/configuration /opt/eclipse/.configuration-pristine
    touch "$MARKER"
fi
fc-cache -f >/dev/null 2>&1 || true

# Everything Eclipse remembers between runs, cleared so run N starts where run 1
# did.  Setup-commands run before every replay, and every one of these would
# otherwise change the first block:
#
#   ~/eclipse-workspace   the workspace itself.  .metadata/ holds the editors
#                         that were open at exit, so a second run would reopen
#                         the 10 MB file before the macro asked for it.
#   ~/.eclipse            the launcher's per-user state.
#   configuration/        the OSGi bundle cache, the Oomph setup state, the
#                         Welcome page's "already seen" flag - and the recent
#                         workspace list.
#
# THE LAST ONE IS THE TRAP, and it cost a run to find.  Eclipse keeps
# RECENT_WORKSPACES in configuration/.settings/org.eclipse.ui.ide.prefs, under
# the INSTALL directory rather than under $HOME - so clearing the home directory
# is not enough.  On the second start the launcher dialog grows a "Recent
# Workspaces" twisty above the buttons, which moves nothing but is plainly
# visible, and the reference image recorded for block 1 no longer matches.
#
# Restoring the whole directory from the copy taken at unpack time, rather than
# deleting the four subdirectories that are known to matter today: this is the
# only way that stays correct when a future release writes a fifth.
rm -rf /root/eclipse-workspace /root/.eclipse
rm -rf /opt/eclipse/configuration
cp -a /opt/eclipse/.configuration-pristine /opt/eclipse/configuration

# cd into the project first, because SWT's FileDialog opens on the process's
# working directory when no filterPath has been set - which is the state on a
# fresh profile, and block 2 is a File > Open File away.
cat > /usr/local/bin/eclipse-run <<'WRAPPER'
#!/bin/sh
cd /root/project || exit 1
exec /opt/eclipse/eclipse "$@"
WRAPPER
chmod +x /usr/local/bin/eclipse-run

log "installed: $(grep -m1 '^version=' /opt/eclipse/.eclipseproduct 2>/dev/null || echo 'Eclipse IDE')"
