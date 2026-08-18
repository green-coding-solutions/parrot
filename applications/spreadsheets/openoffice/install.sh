#!/usr/bin/env bash
# Install Apache OpenOffice Calc 4.1.16 from the upstream deb tarball, pinned by
# SHA-256, and seed a profile.
#
# Debian dropped OpenOffice, so there is no apt route. 4.1.16 is a maintenance
# update; there has been no feature release since 2014. It is in this group for
# the historical comparison, not because anyone should use it - and it is the
# reason the workbook is written as ODF 1.2 rather than 1.3, because AOO puts a
# modal "ODF Version Conflict" in front of anything newer.
#
#   install.sh                 full install
#   install.sh --profile-only  re-seed the profile only, for measuring
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

log "unpacking and installing"
tar -xzf "$AOO_TARBALL"
dpkg -i en-US/DEBS/*.deb >/dev/null
rm -rf /tmp/en-US "/tmp/${AOO_TARBALL}"
ln -sf /opt/openoffice4/program/soffice /usr/local/bin/soffice

fc-cache -f >/dev/null 2>&1 || true
fi   # end of the install half; --profile-only resumes here

# --- profile -------------------------------------------------------------
#
# AOO merges registrymodifications.xcu over its defaults at startup, the same way
# LibreOffice does, and most of the keys are shared. Java is disabled because
# nothing in the script needs it and its absence otherwise raises a dialog.
#
# TWO KEYS ARE SPREADSHEET-SPECIFIC AND ONLY ONE OF THEM IS KNOWN TO EXIST HERE:
#
#   Calc/Input AutoInput        cell autoinput, present since OpenOffice.org.
#                               Typing into a cell otherwise completes the entry
#                               from the rest of the column and Enter commits the
#                               SUGGESTION rather than what was typed.
#   Calc/Formula/Load           recalculation-on-load. This is a LibreOffice 4.x
#     ODFRecalcMode             addition and AOO 4.1 predates it, so setting it
#                               here is very likely a no-op. MEASURE what AOO
#                               actually does when the workbook opens: if it
#                               recalculates the Summary sheet during block 2,
#                               then block 2 is not measuring the same thing here
#                               as elsewhere and block 11 has less left to do.
#                               Record the answer in MEASUREMENTS.md either way -
#                               an unknown key is silently ignored, so a passing
#                               install proves nothing about it.
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
 <item oor:path="/org.openoffice.Office.Calc/Input"><prop oor:name="AutoInput" oor:op="fuse"><value>false</value></prop></item>
 <item oor:path="/org.openoffice.Office.Calc/Formula/Load"><prop oor:name="ODFRecalcMode" oor:op="fuse"><value>1</value></prop></item>
</oor:items>
XCU

log "staging the workbook"
cp /tmp/repo/applications/spreadsheets/parrot-ledger.ods /tmp/parrot-ledger.ods
chmod 644 /tmp/parrot-ledger.ods

log "installed: openoffice-calc $(dpkg-query -W -f='${Version}' openoffice-calc 2>/dev/null || echo '?')"
