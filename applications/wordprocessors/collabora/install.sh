#!/usr/bin/env bash
# Install Collabora Office from Flathub, pinned to an OSTree commit.
#
# Collabora Office is not simply a rebadged LibreOffice any more. The current
# desktop suite is Collabora Online's web-technology UI running offline, which
# makes it the one entrant in the group rendering its interface with web
# technology - exactly the architectural spread that makes the comparison worth
# running. See the group README.
#
# The commit below is what `flatpak remote-info flathub com.collaboraoffice.Office`
# resolved to. `flatpak info` in the container reports its version as
# 26.04.2.4-2; the host's Fedora-filtered flathub mirror reports 26.04.1.4-1 for
# the same commit, because its appstream data is stale. The commit is the
# authority, not either version string. The branch it sits on (`stable`) moves;
# the commit does not. install-flatpak.sh reads the commit back after installing
# and fails loudly if it does not match, so a commit that has been pruned from
# the remote is a hard error rather than a silent unpinned install.
#
# This is the largest install in the group by a distance: about 450 MB of
# application on top of a 387 MB runtime, 1.2 GB and 1 GB respectively once
# unpacked.
set -euo pipefail

COLLABORA_REF=com.collaboraoffice.Office
COLLABORA_COMMIT=54dc072b35c27bc822d711d00b62d3da8cdd564dd4ebefb6db27c0b81d19c177

# Same runtime as Calligra, and pinned for the same reason: a runtime update
# changes the Qt, the theme and the fonts the application draws with.
RUNTIME_REF=org.kde.Platform//6.10
RUNTIME_COMMIT=d0d8f7888350e93c0e6d009d79c5b143f6f6dde09de28ff93a7dc8a14a848c16

bash /tmp/repo/applications/wordprocessors/common/install-flatpak.sh \
    "$COLLABORA_REF" "$COLLABORA_COMMIT" "$RUNTIME_REF" "$RUNTIME_COMMIT"

# Collabora's UI is QtWebEngine, i.e. Chromium, and Chromium refuses to start as
# root without --no-sandbox:
#
#   ERROR:zygote_host_impl_linux.cc(115)] Running as root without --no-sandbox
#   is not supported. See https://crbug.com/638180.
#
# and the window never appears. Everything in this container runs as root. The
# flag is set as a permanent override rather than passed on the command line so
# that usage_scenario.yml's startcommand - and replay.py's relaunch of it - stay
# a plain `flatpak run`.
#
# Note what this does and does not give up: Chromium's own sandbox, INSIDE a
# Flatpak sandbox, in a throwaway container that already needs SYS_ADMIN and
# NET_ADMIN to run a Flatpak at all. It is a real reduction and it is worth
# knowing about.
flatpak override --env=QTWEBENGINE_CHROMIUM_FLAGS=--no-sandbox "$COLLABORA_REF"
echo "[install-collabora] QtWebEngine sandbox disabled (running as root)"
