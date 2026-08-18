#!/usr/bin/env bash
# Install SoftMaker FreeOffice PlanMaker 2024 from the upstream deb, pinned by
# SHA-256, and seed a profile.
#
# The one closed-source entrant in the group. The forums say the trial ends after
# roughly ten days without a free product key, which would mean an email address
# and an online activation in the middle of a benchmark - but every run starts
# from a fresh container, so the clock never reaches day one and FreeOffice never
# asks. This was tested for TextMaker in the word processor group; PlanMaker
# shares the suite-wide configuration, and it has to be confirmed again here
# rather than assumed.
#
#   install.sh                 full install
#   install.sh --profile-only  re-seed the profile only, for measuring
set -euo pipefail

FO_VERSION=3702
FO_DEB="softmaker-freeoffice-2024_${FO_VERSION}_amd64.deb"
FO_URL="https://shop.softmaker.com/repo/apt/pool/non-free/p/proprietary/${FO_DEB}"
FO_SHA256=d518ce8058cfae4314f828b3885236aeb964551f3589f2b83d74ef02d80c1e23

PROFILE_ONLY=0
[[ "${1:-}" == "--profile-only" ]] && PROFILE_ONLY=1

log() { printf '[install-freeoffice] %s\n' "$*"; }

if [[ $PROFILE_ONLY -eq 0 ]]; then
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

log "installing runtime dependencies"
apt-get install -y -qq --no-install-recommends \
    curl ca-certificates \
    libgtk-3-0t64 libglib2.0-0t64 libx11-6 libxext6 libxrender1 libsm6 libice6 \
    libfontconfig1 libfreetype6 fontconfig fonts-liberation \
    libcups2t64 libasound2t64 >/dev/null

fc-cache -f >/dev/null 2>&1 || true

log "downloading ${FO_DEB} (about 135 MiB)"
curl -fsSL "$FO_URL" -o "/tmp/${FO_DEB}"
echo "${FO_SHA256}  /tmp/${FO_DEB}" | sha256sum -c - >/dev/null
log "sha256 ok"

log "installing"
apt-get install -y -qq "/tmp/${FO_DEB}" >/dev/null
rm -f "/tmp/${FO_DEB}"
test -x /usr/bin/planmaker24free || { echo "planmaker24free missing" >&2; exit 1; }
fi   # end of the install half; --profile-only resumes here

# --- profile -------------------------------------------------------------
#
# Dismissing FreeOffice's two first-launch modals once writes settings under
# /root/SoftMaker, and neither reappears afterwards - so they go into a seeded
# profile and the measured recording starts from an editable sheet like
# everybody else's.
#
#   offo24config.ini   suite-wide: the user-interface choice (ribbon against
#                      classic menus), the update check, and the user-info modal
#   pmfo24config.ini   PlanMaker's own. The TextMaker equivalent needed
#                      FirstLaunch and ShowWelcomeDocument; the keys below are
#                      the same shape and MUST BE CONFIRMED against a fresh
#                      container rather than trusted - an unknown key in an INI
#                      is silently ignored, so a modal that still appears will
#                      look like a timing problem in block 1 rather than a
#                      missing setting.
#
# Two things the word processor group could not put in the profile and had to
# handle in the recording: FreeOffice reopens its welcome document alongside the
# new one, and it keeps a "Welcome to FreeOffice!" sidebar open down the
# right-hand side taking about a fifth of the window width. Check for both.
PROFILE="/root/SoftMaker/Settings"
log "seeding profile at ${PROFILE}"
mkdir -p "$PROFILE"
cat > "${PROFILE}/offo24config.ini" <<'CONF'
[ofw]
UIThemeNewPro=0
UpdateCheckEnabled=0
FirstLaunch=2
[UserData]
Title=
CONF
cat > "${PROFILE}/pmfo24config.ini" <<'CONF'
[pm]
FirstLaunch=3
ShowWelcomeDocument=0
SidebarDocking=0
CONF

log "staging the workbook"
cp /tmp/repo/applications/spreadsheets/parrot-ledger.ods /tmp/parrot-ledger.ods
chmod 644 /tmp/parrot-ledger.ods

log "installed: $(dpkg-query -W -f='${Version}' softmaker-freeoffice-2024 2>/dev/null || echo '?')"
