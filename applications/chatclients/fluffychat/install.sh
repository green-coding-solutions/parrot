#!/usr/bin/env bash
# Install FluffyChat from Flathub, pinned to an OSTree commit.
#
# WHY THIS ONE IS IN THE GROUP
#
# FluffyChat is Flutter, which nothing else in Parrot measures. Flutter does not
# use the platform's widgets at all - it ships its own renderer and paints every
# control itself, onto a single surface. That is a genuinely different drawing
# path from GTK, from Qt and from Electron's Chromium, and the scenario's
# scroll-back and thumbnail blocks are where it should show.
#
# Flathub is the only Linux channel the project publishes for desktop.
#
# The commits below were read from Flathub's OSTree refs on 2026-08-08:
#   https://dl.flathub.org/repo/refs/heads/app/im.fluffychat.Fluffychat/x86_64/stable
# The branch they sit on (`stable`) moves; the commits do not.
set -euo pipefail

FLUFFYCHAT_REF=im.fluffychat.Fluffychat
FLUFFYCHAT_COMMIT=104c4950b04a4e91cc26e55b7b06b01022aa954c9b482da49eb9851324719dc7

# NOT the freedesktop runtime, which is what a Flutter application would be
# expected to build against - FluffyChat's Flathub manifest names
# org.gnome.Platform 50, the same runtime and the same commit as Fractal.
#
# That is worth knowing before reading the results: the GNOME runtime is shared
# between the two, so whatever it costs to pull in and start is a constant
# across them, and a gap between Fractal and FluffyChat is the application and
# its toolkit rather than the runtime.
RUNTIME_REF=org.gnome.Platform//50
RUNTIME_COMMIT=a8da766dd0273a67539d2b98358ed6809d8e729280baf63428108837135229d3

bash /tmp/repo/applications/chatclients/common/install-flatpak.sh \
    "$FLUFFYCHAT_REF" "$FLUFFYCHAT_COMMIT" "$RUNTIME_REF" "$RUNTIME_COMMIT"
