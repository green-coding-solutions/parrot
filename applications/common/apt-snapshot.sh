#!/usr/bin/env bash
# Point apt at Ubuntu's archive as it was when the sweep was defined.
#
# Runs as the first setup-command of every window-container, before any script
# calls apt.
#
# WHY
#
# The install scripts pin the application packages, but Ubuntu keeps only the
# newest version of a package in noble-updates. A pinned version vanishes with
# the next update, and the install then fails with "Version ... was not found":
# vim 2:9.1.0016-1ubuntu7.18 on 2026-09-29, LibreOffice 4:24.2.7-0ubuntu0.24.04.6
# between 2026-10-01 and 2026-10-06. Worse, everything that is not pinned moves
# with the archive without any error: all terminals, all video players and
# every dependency of every app. Two machines, or two days, would measure
# different software.
#
# Reading one fixed snapshot of the archive freezes all of it, so every machine
# and every repetition installs the same packages, and the dataset can be
# rebuilt later.
#
# HOW
#
# The image's Release files carry no "Snapshots:" field, so `apt-get --snapshot`
# is silently ignored there and apt keeps reading the live archive (checked
# 2026-10-12: the candidate stayed at the current version). The sources are
# therefore pointed at snapshot.ubuntu.com explicitly. A snapshot's Release
# files are past their Valid-Until date by design, hence Check-Valid-Until off.
# HTTPS needs ca-certificates, which the image has.
#
# 20260929T150000Z is the hour of commit cdbdd06, which defined the sweep. Every
# pinned version resolves there, including LibreOffice 0ubuntu0.24.04.6
# (checked 2026-10-12).
#
# Vendor repositories that install scripts add later (their own .sources or
# .list files) are left alone. Their packages are pinned by version and
# sha256 in the install scripts.
set -euo pipefail

SNAPSHOT="${PARROT_APT_SNAPSHOT:-20260929T150000Z}"
SOURCES_DIR=/etc/apt/sources.list.d
PARKED="$SOURCES_DIR/parked-by-parrot"

log() { printf '[apt-snapshot] %s\n' "$*"; }

mkdir -p "$PARKED"
# The image's own Ubuntu sources. Parked, not deleted, so they can be looked at.
if [[ -f $SOURCES_DIR/ubuntu.sources ]]; then
    mv "$SOURCES_DIR/ubuntu.sources" "$PARKED/ubuntu.sources"
fi
if [[ -f /etc/apt/sources.list ]] && grep -qE '^[[:space:]]*deb' /etc/apt/sources.list; then
    mv /etc/apt/sources.list "$PARKED/sources.list"
fi

cat > "$SOURCES_DIR/parrot-snapshot.sources" <<EOF
Types: deb
URIs: https://snapshot.ubuntu.com/ubuntu/${SNAPSHOT}/
Suites: noble noble-updates noble-backports noble-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF

cat > /etc/apt/apt.conf.d/99parrot-snapshot <<'EOF'
// Snapshot Release files are past Valid-Until by design.
Acquire::Check-Valid-Until "false";
// snapshot.ubuntu.com answers 503 now and then (seen on machine 13,
// 2026-10-12). apt retries transient failures, with growing delays, in every
// later apt call of the install scripts too.
Acquire::Retries "10";
EOF

# Prove it took, rather than trusting it: the lists must come from the snapshot.
# --error-on=any: a plain `apt-get update` exits 0 even when every index fetch
# failed (measured 2026-10-12), and the install would then fail far from the cause.
#
# HTTPS also matters behind GMT's proxy provider. Over plain HTTP apt opened about
# 800 proxy connections per install, and rootless Docker's gvisor-tap-vsock
# network driver (machine 7) loses a few connects per thousand, so installs failed
# with "Unable to connect to <host>:8889". Through the proxy's CONNECT tunnels the
# same install needs 2 connections (measured 2026-10-12).
#
# A 503 from the snapshot service stopped one run in BOOT (machine 13,
# 2026-10-12), so the update is tried up to six times, about 12 minutes in all.
ok=0
for wait_s in 30 60 120 240 300 0; do
    rm -rf /var/lib/apt/lists/*
    if apt-get update -qq --error-on=any; then ok=1; break; fi
    (( wait_s > 0 )) || break
    log "apt-get update failed, trying again in ${wait_s} s"
    sleep "$wait_s"
done
if (( ok == 0 )); then
    log "FAILED: the snapshot archive did not answer after six attempts" >&2
    exit 1
fi
if ! ls /var/lib/apt/lists | grep -q '^snapshot.ubuntu.com_'; then
    log "FAILED: apt did not fetch its lists from snapshot.ubuntu.com" >&2
    exit 1
fi
if ls /var/lib/apt/lists | grep -qE '^(archive|security)\.ubuntu\.com_'; then
    log "FAILED: apt still reads the live archive" >&2
    exit 1
fi
log "apt reads the Ubuntu archive as of ${SNAPSHOT}"
