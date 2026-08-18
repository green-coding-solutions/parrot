#!/usr/bin/env bash
# Install LibreOffice Calc from Ubuntu 24.04, pinned, and seed a profile.
#
# apt rather than upstream: 24.2.7 is what a Ubuntu user actually gets, and it is
# the version the README's popcon figures are about.  The Document Foundation's
# own deb bundles a second, newer LibreOffice under /opt and would measure
# something the Debian installs do not have.
set -euo pipefail

LO_VERSION='4:24.2.7-0ubuntu0.24.04.6'

log() { printf '[install-libreoffice] %s\n' "$*"; }

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

# fonts-liberation is not optional.  The workbook is written in Liberation Sans;
# without it fontconfig substitutes something else, the rendered row heights and
# column widths move, and every absolute click coordinate in drive-scenario.sh
# lands on a different cell than it did when the reference screenshots were
# taken.
log "installing libreoffice-calc ${LO_VERSION}"
apt-get install -y -qq --no-install-recommends \
    "libreoffice-calc=${LO_VERSION}" \
    fonts-liberation \
    libreoffice-core \
    >/dev/null

fc-cache -f >/dev/null 2>&1 || true

# --- profile -------------------------------------------------------------
#
# LibreOffice merges registrymodifications.xcu over its defaults at startup, so
# the file only has to carry the settings that differ.  Everything below is here
# because leaving it alone breaks a measurement, not because it is untidy.
#
# Shared with the word processor group:
#
#   FirstStartWizardCompleted  otherwise a modal wizard covers the document and
#                              the first checkpoint photographs it
#   ShowTipOfTheDay            a 535x215 modal opens centred on every start
#   ooSetupLastVersion         without it Calc decides it is running 24.2 for the
#                              first time and draws a blue infobar under the
#                              toolbar, pushing the grid down about 30 px - which
#                              moves every row coordinate in the driver
#   AutoSave / AutoSaveTime    a background save landing mid-run puts a write into
#                              whichever block happens to be running
#   Recovery / CrashReport     a killed Calc - which is what happens between
#                              measuring passes and after a timed-out replay -
#                              otherwise opens a Document Recovery window INSTEAD
#                              of the workbook on the next start
#   LastTimeDonateShown        these infobars appear on a schedule derived from
#   LastTimeGetInvolvedShown   the wall clock, so they turn up in some replays and
#                              not others: a moving region in a deterministic
#                              screenshot
#
# And two that are specific to a spreadsheet, both of which would quietly change
# what the benchmark measures:
#
#   Input/AutoInput            CELL AUTOINPUT.  Typing into a cell completes the
#                              entry from other cells in the same column, and the
#                              Enter that ends the entry commits the SUGGESTION.
#                              This is the code editors' autocomplete problem in
#                              a spreadsheet: the same keystrokes produce
#                              different cell contents depending on what is
#                              already in the column.  Blocks 8 and 10 type
#                              formulas, where it also completes function names.
#   Formula/Load/ODFRecalcMode 1 = never recalculate on load.  Left at the
#                              default, an unknown amount of the Summary formula
#                              graph is evaluated inside block 2 - so "open a
#                              workbook" means something different here than in
#                              an application that does not, and block 11 has
#                              less left to do.  Off, block 2 measures a load and
#                              block 11 measures a recalculation.  The workbook
#                              ships cached values for exactly this reason.
#
# Autocorrect is deliberately NOT disabled.  Nothing the script types is text
# that any autocorrect rule fires on - the two typed strings are formulas - and
# leaving it on measures what a user actually runs.
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
 <item oor:path="/org.openoffice.Office.Calc/Input"><prop oor:name="AutoInput" oor:op="fuse"><value>false</value></prop></item>
 <item oor:path="/org.openoffice.Office.Calc/Formula/Load"><prop oor:name="ODFRecalcMode" oor:op="fuse"><value>1</value></prop></item>
</oor:items>
XCU

# The workbook the scenario opens is copied, not symlinked: the scenario saves
# over it, and a symlink would write straight back into the repository checkout.
log "staging the workbook"
cp /tmp/repo/applications/spreadsheets/parrot-ledger.ods /tmp/parrot-ledger.ods
chmod 644 /tmp/parrot-ledger.ods

log "installed: $(dpkg-query -W -f='${Version}' libreoffice-calc)"
