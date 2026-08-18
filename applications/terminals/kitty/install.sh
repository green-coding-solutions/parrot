#!/usr/bin/env bash
# Install kitty and write kitty.conf.
#
# THE ONE ENTRANT WHOSE DEFAULTS CANNOT BE RECORDED. kitty's cursor blinks out
# of the box, so two screenshots of an idle window 1.5 s apart are not
# identical - which means every checkpoint after the first fails on replay, for
# a reason that has nothing to do with the benchmark. Measured, not guessed:
#
#   default                       -> CHANGES
#   cursor_blink_interval 0       -> steady
#
# Every other entrant in the group is steady out of the box. If kitty is ever
# upgraded, re-run the two-screenshot test before trusting a recording.
set -euo pipefail
PROFILE_ONLY=0
[[ "${1:-}" == "--profile-only" ]] && PROFILE_ONLY=1
log() { printf '[install-kitty] %s\n' "$*"; }

COMMON=/tmp/repo/applications/terminals/common/install-common.sh
if [[ $PROFILE_ONLY -eq 0 ]]; then
    source "$COMMON"
    log "installing kitty"
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends kitty >/dev/null
else
    COMMON_PROFILE_ONLY=1; source "$COMMON"
fi

log "writing kitty.conf"
mkdir -p /root/.config/kitty
cat > /root/.config/kitty/kitty.conf <<'CONF'
font_family      DejaVu Sans Mono
bold_font        DejaVu Sans Mono Bold
italic_font      DejaVu Sans Mono Oblique
font_size        11.0

# THE line. See the note at the top of this file.
cursor_blink_interval 0
cursor_shape          block

scrollback_lines      20000
enable_audio_bell     no
visual_bell_duration  0
window_padding_width  2
remember_window_size  no
initial_window_width  1440
initial_window_height 900
confirm_os_window_close 0
update_check_interval 0
# kitty ligates by default; DejaVu Sans Mono has no ligatures, but this pins the
# behaviour so a font substitution cannot quietly change the glyph run.
disable_ligatures     always
CONF

# --- launch wrapper ------------------------------------------------------
# `--single-instance` is deliberately NOT used: it would make a relaunch attach
# to the running process as a new OS window owned by the first, which is not the
# process replay.py supervises.
#
# kitty takes the command to run directly rather than behind `-e`, which is worth
# writing down because assuming `-e` here is what made the truecolour probe
# report nonsense for it during the capability pass.
write_launcher kitty \
    'exec kitty'

log "installed: kitty $(dpkg-query -W -f='${Version}' kitty 2>/dev/null || echo '?')"
