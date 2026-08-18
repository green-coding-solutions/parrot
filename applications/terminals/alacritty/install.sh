#!/usr/bin/env bash
# Install Alacritty and write its TOML configuration.
#
# The first of the two GPU entrants: OpenGL, Rust, and a deliberately small
# feature set - no tabs, no splits, no scrollback search. That minimalism is why
# it is in the group and it is also why the script avoids all three.
set -euo pipefail
PROFILE_ONLY=0
[[ "${1:-}" == "--profile-only" ]] && PROFILE_ONLY=1
log() { printf '[install-alacritty] %s\n' "$*"; }

COMMON=/tmp/repo/applications/terminals/common/install-common.sh
if [[ $PROFILE_ONLY -eq 0 ]]; then
    source "$COMMON"
    log "installing alacritty"
    # libxkbcommon-x11-0 is NOT optional, and --no-install-recommends is what
    # loses it. Without it alacritty does not start at all:
    #
    #   thread 'main' panicked at xkbcommon-dl-0.4.2/src/x11.rs:59:28:
    #   Library libxkbcommon-x11.so could not be loaded.
    #
    # It exits before any window is mapped, so the symptom is simply that no
    # window ever appears - which looks identical to a slow start.
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
        alacritty libxkbcommon-x11-0 >/dev/null
else
    COMMON_PROFILE_ONLY=1; source "$COMMON"
fi

# 0.13 reads TOML at ~/.config/alacritty/alacritty.toml. The 0.12-and-earlier
# YAML file at the same path is ignored silently, which is the kind of thing
# that looks like "the setting had no effect".
#
# style.blinking = "Off" rather than a blink interval: Alacritty's cursor does
# not blink by default, and this pins it so a future default cannot break every
# recording in the group.
log "writing alacritty.toml"
mkdir -p /root/.config/alacritty
cat > /root/.config/alacritty/alacritty.toml <<'TOML'
[font]
size = 11.0
normal = { family = "DejaVu Sans Mono", style = "Regular" }
bold   = { family = "DejaVu Sans Mono", style = "Bold" }
italic = { family = "DejaVu Sans Mono", style = "Oblique" }

[cursor]
style = { shape = "Block", blinking = "Off" }
unfocused_hollow = false

[scrolling]
history = 20000
multiplier = 3

[bell]
duration = 0

[window]
padding = { x = 2, y = 2 }
dynamic_padding = false
decorations = "none"

[terminal]
osc52 = "CopyPaste"
TOML

# --- launch wrapper ------------------------------------------------------
# No pre-exec step needed; the launcher exists for the locale and so that every
# driver starts its app as `parrot-<app>`.
write_launcher alacritty \
    'exec alacritty'

log "installed: alacritty $(dpkg-query -W -f='${Version}' alacritty 2>/dev/null || echo '?')"
