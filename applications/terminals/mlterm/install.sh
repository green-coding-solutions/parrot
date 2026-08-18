#!/usr/bin/env bash
# Install mlterm and configure it to match the rest of the group.
#
#   install.sh                 full install
#   install.sh --profile-only  re-seed the config only, for measuring
#
# mlterm is in the group because it is an entirely independent implementation -
# not VTE, not a fork of xterm, not a Rust/GPU newcomer - with its own renderer
# and a reputation built on multilingual text. The Unicode block of this corpus
# is exactly where that should show.
set -euo pipefail

PROFILE_ONLY=0
[[ "${1:-}" == "--profile-only" ]] && PROFILE_ONLY=1
log() { printf '[install-mlterm] %s\n' "$*"; }

COMMON=/tmp/repo/applications/terminals/common/install-common.sh
if [[ $PROFILE_ONLY -eq 0 ]]; then
    # shellcheck source=/dev/null
    source "$COMMON"
    log "installing mlterm"
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends mlterm >/dev/null
else
    COMMON_PROFILE_ONLY=1
    # shellcheck source=/dev/null
    source "$COMMON"
fi

# mlterm reads ~/.mlterm/main for its settings. The keys are its own; none of the
# other six spell them this way.
log "seeding /root/.mlterm"
mkdir -p /root/.mlterm
# fontsize IS IN PIXELS, not points - this is the one setting that does not mean
# what the same number means everywhere else in the group. At 11 mlterm came up
# with a 205x68 grid against xterm's 159x47, because DejaVu Sans Mono at 11
# POINTS is about 14.7 pixels. 15 puts it on the same cell size as the rest.
cat > /root/.mlterm/main <<'CONF'
fontsize = 15
type_engine = xft
use_anti_alias = true
logsize = 20000
scrollbar_view_name = none
use_scrollbar = false
bel_mode = none
blink_cursor = false
static_backscroll_mode = true
line_space = 0
inner_border = 2
termtype = xterm-256color
CONF
cat > /root/.mlterm/font <<'CONF'
ISO10646_UCS4_1 = DejaVu Sans Mono
CONF

# --- launch wrapper ------------------------------------------------------
# NOTE THE PIN STRING. mlterm's WM_CLASS is `"xterm", "mlterm"` - its res_name is
# literally `xterm`, which is what fluxbox matches on, so usage_scenario.yml pins
# `xterm` and NOT `mlterm`. Measured; assuming `mlterm` here would leave the
# window unpinned and every reference screenshot the wrong size.
write_launcher mlterm \
    'exec mlterm'

log "installed: mlterm $(dpkg-query -W -f='${Version}' mlterm 2>/dev/null || echo '?')"
