#!/usr/bin/env bash
# Install Fractal from Flathub, pinned to an OSTree commit.
#
# Flathub rather than apt, and not by preference: Fractal 5 is a GTK4/libadwaita
# rewrite that shares no code with the Fractal in Ubuntu's archive, and Flathub
# is where the GNOME project publishes it. Measuring the Flatpak means measuring
# current Fractal, at the cost of the GNOME runtime being in the figure - which
# is a real part of what a Flatpak costs a user.
#
# The commits below were read from Flathub's OSTree refs on 2026-08-08:
#   https://dl.flathub.org/repo/refs/heads/app/org.gnome.Fractal/x86_64/stable
# The branch they sit on (`stable`) moves; the commits do not.
set -euo pipefail

FRACTAL_REF=org.gnome.Fractal
FRACTAL_COMMIT=be6bc4ab095c275998efad5b3538907f957b2b3833e6c3735d7351f69b010bf2

# Pinned as well, and for the same reason as the application: a runtime update
# changes the GTK, the theme and the fonts Fractal draws with, so it changes
# every reference screenshot in the recording.
#
# Branch 50, taken from Fractal's own Flathub manifest (`runtime-version`)
# rather than guessed - the app will not start against a runtime it was not
# built for, and the failure is a bwrap error that says nothing about versions.
RUNTIME_REF=org.gnome.Platform//50
RUNTIME_COMMIT=a8da766dd0273a67539d2b98358ed6809d8e729280baf63428108837135229d3

bash /tmp/repo/applications/chatclients/common/install-flatpak.sh \
    "$FRACTAL_REF" "$FRACTAL_COMMIT" "$RUNTIME_REF" "$RUNTIME_COMMIT"
