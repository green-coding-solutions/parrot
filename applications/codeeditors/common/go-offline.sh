#!/usr/bin/env bash
# Cut the container off the network, as the last setup-command before
# entrypoint.sh.
#
# WHY
#
# Everything these benchmarks need is installed by then.  What is left is the
# editors reaching out on their own account - update checks, telemetry, licence
# pings, marketplace queries - and every one of those is a measurement that
# depends on someone else's server being up and on how fast it answers.
#
# It is not a theoretical concern.  IntelliJ IDEA queries the JetBrains
# marketplace the first time it sees a .py file and, when the query succeeds,
# draws a "Plugins supporting *.py files found" banner across the top of the
# editor.  That banner is one row tall, so it pushes the whole editing surface
# down 32 px - and it appears only on a machine that can reach the marketplace.
# A recording made on a connected machine then fails every screenshot check on
# a disconnected one, and vice versa, with a diff that looks like the editor
# scrolled.
#
# Emptying resolv.conf rather than filtering with iptables is deliberate: the
# container has no NET_ADMIN capability under GMT, and nothing here connects to
# a bare IP address.  It is also trivially reversible for debugging - the file
# is a tmpfs mount, so a container restart brings it back.
set -euo pipefail

log() { printf '[go-offline] %s\n' "$*"; }

# /etc/resolv.conf is bind-mounted by Docker, so it cannot be replaced - only
# truncated in place.
: > /etc/resolv.conf

log "DNS resolution disabled; the container can no longer reach a name"
if getent hosts deb.debian.org >/dev/null 2>&1; then
    log "WARNING: a hostname still resolves - something else is serving DNS"
else
    log "confirmed: hostname lookups fail"
fi
