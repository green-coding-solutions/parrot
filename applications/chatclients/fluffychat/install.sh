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
# The commits below were read from Flathub's OSTree refs on 2026-09-29:
#   https://dl.flathub.org/repo/refs/heads/app/im.fluffychat.Fluffychat/x86_64/stable
# The branch they sit on (`stable`) moves.  The commits do not move, but they
# do not stay either: the recording was made on FluffyChat 2.8.0, commit
# 104c4950 (read 2026-08-08), and by 2026-09-29 Flathub had deleted it - the
# commit object answers 404, and the branch history reaches back only four
# commits.  This is FluffyChat 2.9.5, the head of that day; every other build
# Flathub still had was 2.9.1, so 2.8.0 is no longer installable at all.
# (`flatpak remote-info` said "Version: 2.9.1" for this commit too - read the
# release list in the Flathub manifest repo instead.)
set -euo pipefail

FLUFFYCHAT_REF=im.fluffychat.Fluffychat
FLUFFYCHAT_COMMIT=35790fc601f62b836680c2f442b9cf42b6b4a61b6dc07c1452fbaf2483db7ab8

# NOT the freedesktop runtime, which is what a Flutter application would be
# expected to build against - FluffyChat's Flathub manifest names
# org.gnome.Platform 50, the same runtime and the same commit as Fractal.
#
# That is worth knowing before reading the results: the GNOME runtime is shared
# between the two, so whatever it costs to pull in and start is a constant
# across them, and a gap between Fractal and FluffyChat is the application and
# its toolkit rather than the runtime.  Keep the two runtime commits equal.
RUNTIME_REF=org.gnome.Platform//50
RUNTIME_COMMIT=b1935f7a673108616d4fd84564f15cefc9f637481472a8d4d2f0945375d41f4b

bash /tmp/repo/applications/chatclients/common/install-flatpak.sh \
    "$FLUFFYCHAT_REF" "$FLUFFYCHAT_COMMIT" "$RUNTIME_REF" "$RUNTIME_COMMIT"
