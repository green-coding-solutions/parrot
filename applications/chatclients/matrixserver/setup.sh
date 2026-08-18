#!/usr/bin/env bash
# Bring up the benchmark homeserver from a bare ubuntu:24.04 container.
#
# This is the from-scratch path: it installs the packages and seeds the corpus,
# which takes several minutes.  It is what the Dockerfile runs at build time,
# and it stays useful for iterating on the corpus without rebuilding an image -
# lower PARROT_MATRIX_HISTORY while doing that.
#
# For benchmarking, prefer the prebuilt image - see matrixserver/README.md.
# There the work is already baked in and only start.sh runs.
set -euo pipefail

HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

bash "${HERE}/build.sh"
bash "${HERE}/start.sh"
