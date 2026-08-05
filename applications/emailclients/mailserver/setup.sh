#!/usr/bin/env bash
# Bring up the benchmark mail server from a bare ubuntu:24.04 container.
#
# This is the from-scratch path: it installs the packages and generates the
# ~500 MB corpus, which takes a few minutes. It is what the Dockerfile runs at
# build time, and it stays useful for iterating on the corpus without rebuilding
# an image.
#
# For benchmarking, prefer the prebuilt image - see mailserver/README.md. There
# the work is already baked in and only start.sh runs, in about a second.
set -euo pipefail

# readlink -f, so this still resolves when the script is reached through a
# symlink: BASH_SOURCE is then the link's path and ../account.env would not
# exist next to it.  The prebuilt image relies on this - it puts start.sh on
# PATH as /usr/local/bin/parrot-mailserver-start.
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

bash "${HERE}/build.sh"
bash "${HERE}/start.sh"
