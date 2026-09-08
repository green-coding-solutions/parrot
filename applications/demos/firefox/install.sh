#!/usr/bin/env bash
# The demo measures the same browser the pdf_viewers group does, so it installs
# it with the same script rather than a copy of it.
#
# The real installer lives under applications/pdf_viewers/firefox/ and not here,
# because this directory is a demo: moving the demos out of the benchmark in
# d9aac1a took the installer with them and broke every pdf_viewers/firefox run
# with "No such file or directory".  A benchmark must not depend on a demo.
set -euo pipefail

exec bash "$(dirname "$(readlink -f "$0")")/../../pdf_viewers/firefox/install.sh" "$@"
