#!/usr/bin/env bash
# Install Apache OpenOffice 4.1.16 from the upstream deb tarball, pinned by
# SHA-256, and seed a profile.
#
# Debian and Ubuntu both dropped OpenOffice years ago - `apt-get install
# openoffice.org` gets you nothing - so upstream is the only route.  The tarball
# comes from archive.apache.org rather than a SourceForge mirror: the archive is
# permanent and the mirror redirector is not, and a benchmark that stops being
# installable is not reproducible.
#
# The digest below is the one Apache publishes beside the tarball
# (.../4.1.16/binaries/en-US/Apache_OpenOffice_4.1.16_Linux_x86-64_install-deb_en-US.tar.gz.sha256).
# It is checked before anything is unpacked.
#
#   install.sh                  install and seed the profile
#   install.sh --profile-only   re-seed the profile, install nothing
#
# --profile-only exists for measuring.  Killing soffice - which is what happens
# between measuring passes, and what a timed-out replay does - leaves a
# RecoveryList entry in the profile, and the NEXT start opens "OpenOffice
# Document Recovery" instead of the document.  Resetting between passes needs
# the profile that the benchmark actually installs, not a second copy of it kept
# in a helper script, because that copy drifts and then the thing being measured
# is not the thing being recorded.
set -euo pipefail

AOO_VERSION=4.1.16
AOO_TARBALL="Apache_OpenOffice_${AOO_VERSION}_Linux_x86-64_install-deb_en-US.tar.gz"
AOO_URL="https://archive.apache.org/dist/openoffice/${AOO_VERSION}/binaries/en-US/${AOO_TARBALL}"
AOO_SHA256=febd01695bbd9ff68d509dbb973bfd714dff0e0a99e50abb4ea32a37eb6aa2ce

PROFILE_ONLY=0
[[ "${1:-}" == "--profile-only" ]] && PROFILE_ONLY=1

log() { printf '[install-openoffice] %s\n' "$*"; }

if [[ $PROFILE_ONLY -eq 0 ]]; then

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

# The upstream debs declare almost no dependencies - they are built by
# OpenOffice's own packaging, not by Debian - so the shared libraries have to be
# named here.  Everything below was found by running `ldd` over
# /opt/openoffice4/program/soffice.bin and its vcl plugin after a first attempt
# that installed cleanly and then failed to start with no message at all.
#
# fonts-liberation is not optional.  The document is written in Liberation Serif
# and Liberation Sans; without them fontconfig substitutes something else, the
# document repaginates, and the fixed Page Down counts in the driver land on
# different content than they did when the reference screenshots were taken.
log "installing runtime dependencies"
apt-get install -y -qq --no-install-recommends \
    curl ca-certificates \
    fonts-liberation fontconfig \
    libxinerama1 libxrandr2 libxext6 libxrender1 libx11-6 libsm6 libice6 \
    libcups2t64 libfreetype6 libglib2.0-0t64 libnss3 \
    >/dev/null

log "downloading ${AOO_TARBALL}"
cd /tmp
curl -fsSL -o "$AOO_TARBALL" "$AOO_URL"
echo "${AOO_SHA256}  ${AOO_TARBALL}" | sha256sum -c - >/dev/null
log "sha256 ok"

# The tarball unpacks to en-US/DEBS/ with the suite's debs at the top level and
# the menu-integration deb in a subdirectory.  The glob deliberately does not
# recurse: desktop integration installs menu entries and MIME associations that
# nothing in this container reads, and it pulls in a dependency chain to do it.
log "unpacking and installing"
tar -xzf "$AOO_TARBALL"
dpkg -i en-US/DEBS/*.deb >/dev/null
rm -rf /tmp/en-US "/tmp/${AOO_TARBALL}"

# The debs install under /opt/openoffice4 and create no symlink on PATH.
ln -sf /opt/openoffice4/program/soffice /usr/local/bin/soffice

fc-cache -f >/dev/null 2>&1 || true

fi   # end of the install half; --profile-only resumes here

# --- profile -------------------------------------------------------------
#
# AOO uses the same registry mechanism as LibreOffice - registrymodifications.xcu
# merged over the defaults at startup - so the file only carries what differs.
# The path is /root/.openoffice/4/user, NOT .config/libreoffice.
#
#   FirstStartWizardCompleted  otherwise the "Welcome to Apache OpenOffice"
#                              registration wizard opens modal over the document
#   AutoSave / AutoSaveTime    a background save landing mid-run puts a write
#                              into whichever block happens to be running
#   Recovery Enabled x2        turns the autorecovery timer off, which is the
#                              part that would write mid-block.  It does NOT
#                              stop the Document Recovery dialog - see below
#   JavaEnable                 no JRE is installed, and AOO puts up a modal
#                              "OpenOffice requires a Java runtime environment"
#                              the first time anything touches a Java code path
#   ooSetupLastVersion         belt and braces against a version-change infobar
#   ShowOfficeUpdateDialog     THE IMPORTANT ONE.  parrot-report.odt declares
#                              office:version="1.3" and AOO 4.1 implements ODF
#                              1.2, so opening it raises a modal "ODF Version
#                              Conflict - This document uses an unsupported
#                              version of the Open Document Format" in the
#                              middle of block 2, whose DEFAULT button is
#                              "Update Now..." and runs an online update check.
#                              A network call inside a measured block is not
#                              something to leave to a click landing correctly
#   AutoCheckEnabled           the weekly online update check, for the same
#                              reason: nothing in a benchmark run should reach
#                              the network on a schedule derived from the clock
#
# ON THE RECOVERY DIALOG, which is worth being precise about because the obvious
# reading of these two keys is wrong.  Both were seeded, both were verified
# present in the profile AOO rewrote - and killing soffice still produced
# "OpenOffice Document Recovery" 566x387 on the next start, with `Untitled 1`
# listed as "Not recovered yet".
#
# Recovery/AutoSave/Enabled is the autosave TIMER.  Session tracking is separate:
# AOO writes an /org.openoffice.Office.Recovery/RecoveryList node for every open
# document regardless of that flag, and the dialog is driven by that list being
# non-empty at startup.  There is no seedable key that turns it off.
#
# It cannot fire in a benchmark run, which is why this is a comment and not a
# workaround: install.sh seeds a fresh profile with an empty RecoveryList and the
# app is launched exactly once.  It fires constantly while measuring by hand,
# where `install.sh --profile-only` between passes is the answer.
#
# Autocorrect is deliberately NOT disabled.  The typed block in script.md is
# built so that no autocorrect rule fires on it (see the group README), and
# leaving it on measures what a user actually runs.
PROFILE=/root/.openoffice/4/user
log "seeding profile at ${PROFILE}"
mkdir -p "$PROFILE"
cat > "${PROFILE}/registrymodifications.xcu" <<'XCU'
<?xml version="1.0" encoding="UTF-8"?>
<oor:items xmlns:oor="http://openoffice.org/2001/registry" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
 <item oor:path="/org.openoffice.Setup/Office"><prop oor:name="FirstStartWizardCompleted" oor:op="fuse"><value>true</value></prop></item>
 <item oor:path="/org.openoffice.Setup/Office"><prop oor:name="LicenseAcceptDate" oor:op="fuse"><value>2020-01-01T00:00:00</value></prop></item>
 <item oor:path="/org.openoffice.Setup/Product"><prop oor:name="ooSetupLastVersion" oor:op="fuse"><value>4.1</value></prop></item>
 <item oor:path="/org.openoffice.Office.Common/Save/Document"><prop oor:name="AutoSave" oor:op="fuse"><value>false</value></prop></item>
 <item oor:path="/org.openoffice.Office.Common/Save/Document"><prop oor:name="AutoSaveTime" oor:op="fuse"><value>0</value></prop></item>
 <item oor:path="/org.openoffice.Office.Common/Misc"><prop oor:name="FirstRun" oor:op="fuse"><value>false</value></prop></item>
 <item oor:path="/org.openoffice.Office.Recovery/RecoveryInfo"><prop oor:name="Enabled" oor:op="fuse"><value>false</value></prop></item>
 <item oor:path="/org.openoffice.Office.Recovery/AutoSave"><prop oor:name="Enabled" oor:op="fuse"><value>false</value></prop></item>
 <item oor:path="/org.openoffice.Office.Java/VirtualMachine"><prop oor:name="JavaEnable" oor:op="fuse"><value>false</value></prop></item>
 <item oor:path="/org.openoffice.Office.Common/Load"><prop oor:name="ShowOfficeUpdateDialog" oor:op="fuse"><value>false</value></prop></item>
 <item oor:path="/org.openoffice.Office.Jobs/Jobs['UpdateCheck']/Arguments"><prop oor:name="AutoCheckEnabled" oor:op="fuse"><value>false</value></prop></item>
</oor:items>
XCU

# The document the scenario opens is copied, not symlinked: the scenario saves
# over it, and a symlink would write straight back into the repository checkout.
log "staging the document"
cp /tmp/repo/applications/wordprocessors/parrot-report.odt /tmp/parrot-report.odt
cp /tmp/repo/applications/wordprocessors/parrot.png        /tmp/parrot.png
chmod 644 /tmp/parrot-report.odt /tmp/parrot.png

log "installed: openoffice-writer $(dpkg-query -W -f='${Version}' openoffice-writer)"
