#!/usr/bin/env bash
# Install SMPlayer and write its configuration.
#
# The odd one of the three mpv front ends: it does not link libmpv, it SPAWNS
# mpv as a child process and talks to it over its IPC socket. So this entrant
# measures a Qt GUI plus a second process, against Celluloid's Qt-free GUI plus
# an embedded library - which is exactly the comparison the group exists for.
set -euo pipefail
PROFILE_ONLY=0
[[ "${1:-}" == "--profile-only" ]] && PROFILE_ONLY=1
log() { printf '[install-smplayer] %s\n' "$*"; }

COMMON="$(dirname "$(readlink -f "$0")")/../common/install-common.sh"
if [[ $PROFILE_ONLY -eq 0 ]]; then
    source "$COMMON"
    log "installing smplayer"
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends smplayer >/dev/null
else
    COMMON_PROFILE_ONLY=1; source "$COMMON"
fi

# remember_time_pos=false is load-bearing, not a preference. SMPlayer's default
# is to store a resume position per file, so the second run of a recording would
# start clip 01 somewhere other than its first frame and every checkpoint after
# block 1 would be against a different part of the film.
#
# The rest pins things that would otherwise vary between runs: the single
# instance server (a second launch would hand its files to the first and exit),
# the config dialog on first start, and the update check.
log "writing smplayer.ini"
mkdir -p /root/.config/smplayer
cat > /root/.config/smplayer/smplayer.ini <<'CONF'
[instances]
use_single_instance=false

[smplayer]
gui=DefaultGUI
config_version=6

[%General]
remember_media_settings=false
remember_time_pos=false
osd=1
screenshot_directory=/tmp

[update_checker]
enabled=false
CONF

cat > /usr/local/bin/parrot-smplayer <<LAUNCH
#!/usr/bin/env bash
exec smplayer ${CLIPS}
LAUNCH
chmod +x /usr/local/bin/parrot-smplayer
log "launcher written"
