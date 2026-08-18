#!/usr/bin/env bash
# Install SoftMaker FreeOffice 2024 (TextMaker), pinned.
#
#   install.sh                  install and seed the profile
#   install.sh --profile-only   re-seed the profile, install nothing
#
# Closed source, and one of two closed entrants in the group. It does NOT ask
# for a product key on first launch. The trial nag only starts after about ten
# days and every benchmark run starts from a fresh container, so the clock never
# reaches day one.
#
# NOT installed through SoftMaker's install-softmaker-freeoffice-2024.sh, which
# is what this file used to do. That script adds shop.softmaker.com as an APT
# source and then installs "whatever is current" from it, which means
#   * the benchmark measures a different application every few weeks, and no
#     recording survives it, and
#   * a third-party repository stays wired into the image for every later
#     apt-get in the container.
# The .deb is fetched directly from the same repository's pool instead, pinned
# by version and by the SHA-256 SoftMaker themselves publish in
#   https://shop.softmaker.com/repo/apt/dists/stable/non-free/binary-amd64/Packages
# so the digest below is the vendor's, not one observed from a download.
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

# fonts-liberation is not optional: parrot-report.odt is written in Liberation
# Serif and Liberation Sans, and a substituted font repaginates the document, so
# the fixed Page Down counts in the driver land on different content than they
# did when the reference screenshots were taken.
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

# textmaker24free, not textmaker24. Both names exist; the unsuffixed one belongs
# to the paid SoftMaker Office build and is not what this benchmark is about.
test -x /usr/bin/textmaker24free || { echo "textmaker24free missing" >&2; exit 1; }

fi   # end of the install half; --profile-only resumes here

# --- profile -------------------------------------------------------------
#
# TextMaker keeps settings in TWO ini files under a directory the installer has
# already created, and the first run needs keys from both:
#
#   offo24config.ini   suite-wide (FreeOffice as a whole)
#   tmfo24config.ini   TextMaker's own
#
# Each key below was found by diffing the file across the click that sets it,
# and NOT by capturing the file. A captured copy would carry
#   guid=350D6914-...        a runtime identifier, regenerated per install
#   FirstDayTime / FirstDayHash   the trial clock and its checksum
#   AdsLastDate / SidebarAdDate   today's date
# and AGENTS.md is explicit that such values must not go into a committed
# profile: they are valid but wrong, silently. All five are left to be
# generated. Verified: with only the keys below, a clean container regenerates
# FirstDayTime and FirstDayHash fresh and writes no guid at all.
PROFILE="/root/SoftMaker/Settings"
log "seeding profile at ${PROFILE}"
mkdir -p "$PROFILE"

# UIThemeNewPro    the [User interface] dialog, 1028x648, which asks whether to
#                  use the Ribbon or classic menus before the app will start.
#                  0 is its own default: the first Ribbon design.
# [UserData]       the [User info] dialog, 891x553 - name, company, address.
#                  The section merely has to exist; Cancel writes exactly
#                  "Title=" and never asks again.
# UpdateCheckEnabled  FreeOffice checks softmaker.com for updates on startup.
#                  Turning it off also stops the guid being written, so the
#                  benchmark neither phones home nor mints an identifier.
# FirstLaunch      the counter both dialogs are gated on.
cat > "${PROFILE}/offo24config.ini" <<'CONF'
[ofw]
UIThemeNewPro=0
UpdateCheckEnabled=0
FirstLaunch=2

[UserData]
Title=
CONF

# ShowWelcomeDocument  TextMaker otherwise opens "Welcome to TextMaker.tmdx"
#                  instead of a blank document, so block 1 would not end on an
#                  editable empty page the way every other app in the group does.
# SidebarDocking   the tips sidebar, ~300 px down the right-hand side. It is off
#                  here for a reason beyond width: the sidebar carries a rotating
#                  ADVERTISEMENT, keyed to the date -
#                    AdsLastDate=7.8.2026  SidebarAdPic=1  SidebarAdDate=07.08.2026
#                  in this same file, against 136 banner images the deb unpacks
#                  into the profile. A reference screenshot with a date-keyed ad
#                  in it fails on replay the moment the date moves. Turning the
#                  sidebar off is one click in View > Sidebars and removes the
#                  whole class of failure.
# FirstLaunch      TextMaker's own copy of the counter.
cat > "${PROFILE}/tmfo24config.ini" <<'CONF'
[tm]
FirstLaunch=3
ShowWelcomeDocument=0
SidebarDocking=0
CONF

log "staging the document"
cp /tmp/repo/applications/wordprocessors/parrot-report.odt /tmp/parrot-report.odt
cp /tmp/repo/applications/wordprocessors/parrot.png        /tmp/parrot.png
chmod 644 /tmp/parrot-report.odt /tmp/parrot.png

log "installed: $(dpkg-query -W -f='${Version}' softmaker-freeoffice-2024 2>/dev/null || echo '?')"
