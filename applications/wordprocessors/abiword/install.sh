#!/usr/bin/env bash
# Install AbiWord from Ubuntu 24.04, pinned.
#
# AbiWord is the lightest thing in this group by a wide margin and the one most
# likely to fall out of it. It can do every block in script.md, which was
# checked against the plugins it ships rather than assumed:
#
#   opendocument.so   reads and writes ODT, so the open/save blocks work
#   openxml.so        DOCX, if the group is ever run a second time in that format
#   pdf.so            PDF export - present, but see below
#
# ON pdf.so, corrected after measuring block 18.  It is installed and it is what
# would back `File > Save Copy...` with the file type set to PDF - but that route
# turned out to be undrivable: AbiWord refuses to infer the format from a .pdf
# extension ("The given file extension does not match the chosen file type!",
# and answering Yes writes an AbiWord document under a .pdf name), and its
# `Save file as type` combo does not open under a synthetic click at all.
#
# Block 18 therefore goes through `File > Print... > Print to File`, where the
# output format is already PDF.  That is GTK's own print backend rather than
# pdf.so, and it needs no configured printer - so the earlier note here, that
# without pdf.so the only way out would be a printer, was wrong on both counts.
# script.md allows print-to-file explicitly.  The check below is kept as an
# install sanity test, not because block 18 depends on it.
set -euo pipefail

AB_VERSION='3.0.5~dfsg-3.2build4'

log() { printf '[install-abiword] %s\n' "$*"; }

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

# fonts-liberation is not optional: the document is written in Liberation Serif
# and Liberation Sans, and a substituted font repaginates it, so the fixed Page
# Down counts in the driver land on different content than they did when the
# reference screenshots were taken.
log "installing abiword ${AB_VERSION}"
apt-get install -y -qq --no-install-recommends \
    "abiword=${AB_VERSION}" \
    fonts-liberation \
    >/dev/null

fc-cache -f >/dev/null 2>&1 || true

log "plugins present:"
for p in opendocument pdf openxml; do
    if ls /usr/lib/*/abiword-*/plugins/${p}.so >/dev/null 2>&1; then
        log "  ${p}.so ok"
    else
        echo "[install-abiword] ${p}.so MISSING - script.md cannot be driven" >&2
        exit 1
    fi
done

log "staging the document"
cp /tmp/repo/applications/wordprocessors/parrot-report.odt /tmp/parrot-report.odt
cp /tmp/repo/applications/wordprocessors/parrot.png        /tmp/parrot.png
chmod 644 /tmp/parrot-report.odt /tmp/parrot.png

log "installed: $(dpkg-query -W -f='${Version}' abiword)"
