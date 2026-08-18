#!/usr/bin/env bash
# Install Gnumeric from Ubuntu 24.04, pinned, and seed its settings.
#
# The only entrant in this group that is a spreadsheet rather than an office
# suite, and the only one that is not descended from StarOffice or drawn with a
# web view. That is why it is here.
set -euo pipefail

GNM_VERSION='1.12.56-2build5'

log() { printf '[install-gnumeric] %s\n' "$*"; }

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

# fonts-liberation is not optional. The workbook is written in Liberation Sans;
# without it fontconfig substitutes something else, the rendered row heights and
# column widths move, and every absolute click coordinate in drive-scenario.sh
# lands on a different cell than it did when the reference screenshots were
# taken.
#
# gnumeric-common carries the schemas and must be pinned to the same version.
# dconf-cli is for `dconf update` below - see the settings note.
log "installing gnumeric ${GNM_VERSION}"
apt-get install -y -qq --no-install-recommends \
    "gnumeric=${GNM_VERSION}" \
    "gnumeric-common=${GNM_VERSION}" \
    fonts-liberation \
    dconf-cli \
    >/dev/null

fc-cache -f >/dev/null 2>&1 || true

# --- settings ------------------------------------------------------------
#
# Gnumeric keeps its preferences in GSettings, not in a config file, so there is
# no equivalent of the LibreOffice family's registrymodifications.xcu to drop in
# place. And GSettings cannot simply be WRITTEN here: the dconf backend needs a
# session bus to write, and this container has neither a bus nor an init.
# `gsettings set` fails, and running the application under `dbus-run-session`
# would change the startcommand that every recording stores verbatim.
#
# The way in is a dconf SYSTEM database. Writing dconf needs a bus; READING it
# does not - the backend maps the compiled database straight off disk. So the
# value is compiled into /etc/dconf/db/local and the profile points at it, and
# the application picks it up with no bus anywhere. Confirmed rather than
# assumed:
#
#   gsettings get org.gnome.gnumeric.core.gui.editing autocomplete   ->  false
#   dconf read /org/gnome/gnumeric/core/gui/editing/autocomplete     ->  false
#
# WHAT IS TURNED OFF, AND WHY
#
#   autocomplete   CELL AUTOINPUT. Typing into a cell otherwise completes the
#                  entry from the rest of the column, and the Enter that ends
#                  the entry commits the SUGGESTION rather than what was typed.
#                  This is the code editors' autocomplete problem in a
#                  spreadsheet, and it is off in every other app in this group
#                  for the same reason.
#
# There is NO recalculation-on-load setting to match the LibreOffice family's
# ODFRecalcMode. Whether Gnumeric evaluates the Summary sheet's SUMIFs while
# opening the workbook - which would put part of block 11's work inside block 2 -
# has to be MEASURED and written into MEASUREMENTS.md. A missing setting is not
# the same as a setting that is off.
log "seeding dconf system database"
mkdir -p /etc/dconf/db/local.d /etc/dconf/profile
printf 'user-db:user\nsystem-db:local\n' > /etc/dconf/profile/user
cat > /etc/dconf/db/local.d/00-parrot <<'CONF'
[org/gnome/gnumeric/core/gui/editing]
autocomplete=false
CONF
dconf update

# The workbook the scenario opens is copied, not symlinked: the scenario saves
# over it, and a symlink would write straight back into the repository checkout.
log "staging the workbook"
cp /tmp/repo/applications/spreadsheets/parrot-ledger.ods /tmp/parrot-ledger.ods
chmod 644 /tmp/parrot-ledger.ods

log "installed: $(dpkg-query -W -f='${Version}' gnumeric)"
