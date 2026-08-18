#!/usr/bin/env bash
# Install Calligra Words from Flathub, pinned to an OSTree commit.
#
# Calligra comes from Flathub rather than apt on purpose. Ubuntu 24.04 packages
# 3.2.1, the Qt5 series; Flathub carries 26.04.3, which is Qt6 and has the
# reworked interface. Measuring the Flatpak means measuring current Calligra, at
# the cost of the Flatpak runtime being in the figure - which is a real part of
# what a Flatpak costs a user. See the group README.
#
# The commit below is the one `flatpak remote-info flathub org.kde.calligra`
# resolved to for version 26.04.3, dated 2026-07-02. The branch it sits on
# (`stable`) moves; the commit does not.
set -euo pipefail

CALLIGRA_REF=org.kde.calligra
CALLIGRA_COMMIT=3aed03805b3c9377c000e2363cc5fe9b28ef637da78b733d241d9506e087bebc

# Pinned as well, and for the same reason: a runtime update changes the Qt, the
# theme and the fonts the application draws with, so it changes the reference
# screenshots.
RUNTIME_REF=org.kde.Platform//6.10
RUNTIME_COMMIT=d0d8f7888350e93c0e6d009d79c5b143f6f6dde09de28ff93a7dc8a14a848c16

bash /tmp/repo/applications/wordprocessors/common/install-flatpak.sh \
    "$CALLIGRA_REF" "$CALLIGRA_COMMIT" "$RUNTIME_REF" "$RUNTIME_COMMIT"
