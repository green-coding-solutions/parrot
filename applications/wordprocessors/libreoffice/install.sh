#!/usr/bin/env bash
# Install LibreOffice Writer from Ubuntu 24.04, pinned, and seed a profile.
#
# apt rather than upstream: 24.2.7 is what a Ubuntu user actually gets, and it is
# the version the README's popcon figures are about.  The Document Foundation's
# own deb bundles a second, newer LibreOffice under /opt and would measure
# something 117k Debian installs do not have.
set -euo pipefail

LO_VERSION='4:24.2.7-0ubuntu0.24.04.6'

log() { printf '[install-libreoffice] %s\n' "$*"; }

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

# fonts-liberation is not optional.  The document is written in Liberation Serif
# and Liberation Sans; without them fontconfig substitutes something else, the
# document repaginates, and the fixed Page Down counts in the driver land on
# different content than they did when the reference screenshots were taken.
log "installing libreoffice-writer ${LO_VERSION}"
apt-get install -y -qq --no-install-recommends \
    "libreoffice-writer=${LO_VERSION}" \
    fonts-liberation \
    libreoffice-core \
    >/dev/null

fc-cache -f >/dev/null 2>&1 || true

# --- profile -------------------------------------------------------------
#
# LibreOffice merges registrymodifications.xcu over its defaults at startup, so
# the file only has to carry the settings that differ.  Four things are turned
# off, and each one is here because leaving it on breaks a measurement rather
# than because it is untidy:
#
#   FirstStartWizardCompleted  otherwise a modal wizard covers the document and
#                              the first checkpoint photographs it
#   ShowTipOfTheDay            a 535x215 modal titled "Tip of the Day: 1/225"
#                              opens centred over the document on every start
#   ooSetupLastVersion         without it Writer decides it is running 24.2 for
#                              the first time and draws a blue "learn what's
#                              new" infobar under the toolbar, which pushes the
#                              whole document area down 30 px
#   AutoSave / AutoSaveTime    a background save landing mid-run puts a write
#                              into whichever block happens to be running
#   Recovery / CrashReport     if Writer is ever killed rather than quit - which
#                              is what happens between measuring passes, and
#                              what a timed-out replay does - the next start
#                              opens a "LibreOffice 24.2 Document Recovery"
#                              window INSTEAD of the document.  It reports
#                              WM_CLASS "libreoffice", "LibreOffice 24.2", so it
#                              is not even caught by the document window's pin
#                              rule.  Turning recovery off makes the next start
#                              identical whatever ended the last one
#   LastTimeDonateShown        the donate and get-involved infobars appear on a
#   LastTimeGetInvolvedShown   schedule derived from the wall clock, so they turn
#                              up in some replays and not others - a moving
#                              region in an otherwise deterministic screenshot
#
# Autocorrect is deliberately NOT disabled.  The typed block in script.md is
# built so that no autocorrect rule fires on it (see the group README), and
# every app in this group would need a different mechanism to turn it off.
# Leaving it on measures what a user actually runs.
PROFILE=/root/.config/libreoffice/4/user
log "seeding profile at ${PROFILE}"
mkdir -p "$PROFILE"
cat > "${PROFILE}/registrymodifications.xcu" <<'XCU'
<?xml version="1.0" encoding="UTF-8"?>
<oor:items xmlns:oor="http://openoffice.org/2001/registry" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
 <item oor:path="/org.openoffice.Setup/Office"><prop oor:name="FirstStartWizardCompleted" oor:op="fuse"><value>true</value></prop></item>
 <item oor:path="/org.openoffice.Setup/Office"><prop oor:name="LastTimeDonateShown" oor:op="fuse"><value>9999999999</value></prop></item>
 <item oor:path="/org.openoffice.Setup/Office"><prop oor:name="LastTimeGetInvolvedShown" oor:op="fuse"><value>9999999999</value></prop></item>
 <item oor:path="/org.openoffice.Office.Common/Save/Document"><prop oor:name="AutoSave" oor:op="fuse"><value>false</value></prop></item>
 <item oor:path="/org.openoffice.Office.Common/Save/Document"><prop oor:name="AutoSaveTime" oor:op="fuse"><value>0</value></prop></item>
 <item oor:path="/org.openoffice.Office.Common/Misc"><prop oor:name="FirstRun" oor:op="fuse"><value>false</value></prop></item>
 <item oor:path="/org.openoffice.Office.Common/Misc"><prop oor:name="ShowTipOfTheDay" oor:op="fuse"><value>false</value></prop></item>
 <item oor:path="/org.openoffice.Setup/Product"><prop oor:name="ooSetupLastVersion" oor:op="fuse"><value>24.2</value></prop></item>
 <item oor:path="/org.openoffice.Office.Recovery/RecoveryInfo"><prop oor:name="Enabled" oor:op="fuse"><value>false</value></prop></item>
 <item oor:path="/org.openoffice.Office.Recovery/AutoSave"><prop oor:name="Enabled" oor:op="fuse"><value>false</value></prop></item>
 <item oor:path="/org.openoffice.Office.Common/Misc"><prop oor:name="CrashReport" oor:op="fuse"><value>false</value></prop></item>
</oor:items>
XCU

# The document the scenario opens is copied, not symlinked: the scenario saves
# over it, and a symlink would write straight back into the repository checkout.
log "staging the document"
cp /tmp/repo/applications/wordprocessors/parrot-report.odt /tmp/parrot-report.odt
cp /tmp/repo/applications/wordprocessors/parrot.png        /tmp/parrot.png
chmod 644 /tmp/parrot-report.odt /tmp/parrot.png

log "installed: $(dpkg-query -W -f='${Version}' libreoffice-writer)"
