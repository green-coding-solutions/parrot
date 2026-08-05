#!/usr/bin/env bash
# Make window geometry deterministic before the window manager starts.
#
#   pin-windows.sh <main-window-res-name> [width] [height] [res-class] [role]
#   pin-windows.sh Mail                             # Thunderbird / Betterbird
#   pin-windows.sh bluemail 1440 900 BlueMail       # BlueMail: res_name is
#                                                   # ambiguous, see MAIN_CLASS
#   pin-windows.sh claws-mail 1440 900 Claws-mail mainwindow
#                                                   # Claws Mail: see MAIN_ROLE
#
# Must run BEFORE entrypoint.sh, because fluxbox reads ~/.fluxbox/apps once at
# startup and will not overwrite a file that is already there.
#
# WHY THIS EXISTS
#
# fluxbox 1.3.7 leaves session.screen0.windowPlacement unset, so it falls back to
# RowSmartPlacement: each new window is positioned to avoid overlapping the
# windows already on screen.  That makes position a function of whatever else
# happens to be open, which is exactly what you do not want in a recording.
#
# It compounds, because a dialog is centred on its parent:
#
#   main window        placed by the app, then resized by position-window.sh
#   compose window     placed by RowSmartPlacement, relative to the main window
#   SMTP password box  centred on the compose window
#
# So the outgoing-server password prompt inherits two layers of variability, and a
# macro that clicks its OK button at fixed coordinates misses.  That is what broke
# the last three steps of the Thunderbird recording.
#
# Fixing it here rather than in the macro matters: window management done with
# xdotool is NOT an input event, so xmacrorec2 does not record it and replay would
# never repeat it.  The window manager, on the other hand, applies these rules
# identically at record time and at replay time - both runs go through the same
# setup-commands in the same image.
set -euo pipefail

# The main window's res_name - the FIRST field of WM_CLASS, e.g. "Mail" for
# Thunderbird's 3-pane.  Optional: without it every window including the main one
# is merely centred, which is still fully reproducible, just not fullscreen.
#
# To find it for a client, run it and read the property off the window:
#   apt-get install -y x11-utils      # xprop is not in the image
#   DISPLAY=:99 xprop -id "$(xdotool search --onlyvisible --name '<title>' | head -1)" WM_CLASS
# Thunderbird's 3-pane reports "Mail", "thunderbird-esr"; its compose window
# reports "Msgcompose" and its dialogs "Thunderbird", all sharing the res_class.
MAIN_NAME="${1:-}"
WIDTH="${2:-1440}"
HEIGHT="${3:-900}"
# Optional res_class, for clients where the res_name alone is ambiguous.
# BlueMail needs it: it maps a 20x20 tray window that shares the res_name
# "bluemail" with the main window and differs only in res_class ("Bluemail"
# against the main window's "BlueMail").  Without the extra term the tray window
# matches too and fluxbox blows it up to a full-screen, undecorated 1440x900 that
# covers the mailbox.
MAIN_CLASS="${4:-}"
# Optional WM_WINDOW_ROLE, for clients whose dialogs are indistinguishable from
# the main window by WM_CLASS alone - which is most of them.
#
# Claws Mail needs it.  Its password prompt, its progress windows and its
# compose window all report WM_CLASS "claws-mail", "Claws-mail", so without a
# role the main-window rule below matches them too and moves them to 0,0 - where
# fluxbox stacks them UNDER the full-screen main window.  The prompt is then
# invisible and modal: the folder tree stops responding to clicks and the client
# looks like it has hung.  Only the main window carries
# WM_WINDOW_ROLE = "mainwindow", so naming it confines the rule to that window
# and every dialog falls through to the centring rule instead.
#
# Read it off a running client with:
#   DISPLAY=:99 xprop -id "$(xdotool search --onlyvisible --name '<title>' | head -1)" \
#       WM_CLASS WM_WINDOW_ROLE
MAIN_ROLE="${5:-}"

log() { printf '[pin-windows] %s\n' "$*"; }

FB="${HOME}/.fluxbox"
mkdir -p "$FB"

# Deterministic placement for anything the rules below do not cover.
# CascadePlacement depends only on how many windows are already mapped, which is
# reproducible for a fixed sequence of actions; RowSmartPlacement depends on their
# sizes and positions, which is not.
#
# The toolbar is hidden for two reasons.  It reserves a 45 px strut at the bottom
# of the screen, and fluxbox clamps a full-height window to the area left over -
# so a window asked for 1440x900 silently becomes 1440x855, every y coordinate
# below the fold shifts, and clicks aimed at the bottom of the window miss.  It
# also carries a live clock, which is a moving pixel in any full-screen capture.
cat > "${FB}/init" <<INIT
session.menuFile:	~/.fluxbox/menu
session.keyFile:	~/.fluxbox/keys
session.styleFile:	/usr/share/fluxbox/styles//ubuntu-light
session.configVersion:	13
session.screen0.windowPlacement:	CascadePlacement
session.screen0.rowPlacementDirection:	LeftToRight
session.screen0.colPlacementDirection:	TopToBottom
session.screen0.fullMaximization:	true
session.screen0.toolbar.visible:	false
INIT

# The main window fills the screen with no decorations, so the client area starts
# at exactly 0,0 - no title-bar offset to account for in click coordinates.
#
# Everything else is centred on the *screen* rather than on its parent, which
# breaks the inheritance chain described above: a dialog lands in the same place
# whatever its parent is doing.
{
    if [[ -n "$MAIN_NAME" ]]; then
        main_pattern="(name=${MAIN_NAME})"
        [[ -n "$MAIN_CLASS" ]] && main_pattern="${main_pattern} (class=${MAIN_CLASS})"
        [[ -n "$MAIN_ROLE" ]]  && main_pattern="${main_pattern} (role=${MAIN_ROLE})"
        cat <<MAINAPP
[app] ${main_pattern}
  [Deco]	{NONE}
  [Dimensions]	{${WIDTH} ${HEIGHT}}
  [Position]	(TOPLEFT)	{0 0}
[end]

MAINAPP
    fi
    cat <<APPS
[app] (name=fbrun)
  [Position]	(WINCENTER)	{0 0}
  [Layer]	{2}
[end]

[app] (title=.*)
  [Position]	(CENTER)	{0 0}
[end]
APPS
} > "${FB}/apps"

if [[ -n "$MAIN_NAME" ]]; then
    log "main window '${MAIN_NAME}' pinned to ${WIDTH}x${HEIGHT} at 0,0, no decorations"
else
    log "no main-window name given; every window is merely centred"
fi
log "all other windows centred on the screen; placement policy CascadePlacement"
