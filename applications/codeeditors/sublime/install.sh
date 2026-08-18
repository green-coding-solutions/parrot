#!/usr/bin/env bash
# Install Sublime Text build 4200 from the official .deb.
#
# Not from Sublime's apt repository, which only ever carries the current build:
# download.sublimetext.com keeps every past build at a stable, build-numbered
# URL, which is the property a recording needs.
#
# NOTHING IS CONFIGURED.  No Packages/User/Preferences.sublime-settings is
# written; Sublime runs on its defaults, including whatever it puts up on first
# launch.
set -euo pipefail

ST_BUILD='4200'
ST_SHA256='79a687ffd749004eb4360243dc2133a68bbc8243f890ff3f8f5b00835870c7ea'
ST_URL="https://download.sublimetext.com/sublime-text_build-${ST_BUILD}_amd64.deb"

log() { printf '[install-sublime] %s\n' "$*"; }

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

log "downloading Sublime Text build ${ST_BUILD}"
wget -q -O /tmp/sublime.deb "$ST_URL"

log "verifying checksum"
echo "${ST_SHA256}  /tmp/sublime.deb" | sha256sum -c -

log "installing"
apt-get install -y -qq --no-install-recommends \
    /tmp/sublime.deb fonts-dejavu-core fonts-liberation >/dev/null
rm -f /tmp/sublime.deb
fc-cache -f >/dev/null 2>&1 || true

# A profile from scratch on every setup pass, so run N starts where run 1 did.
rm -rf /root/.config/sublime-text /root/.cache/sublime-text

log "installed: $(subl --version 2>/dev/null || echo 'Sublime Text')"
