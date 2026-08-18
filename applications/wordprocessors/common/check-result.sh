#!/usr/bin/env bash
# Assert what the scenario was supposed to have done, against the files it left
# behind rather than against the screenshots.
#
#   check-result.sh [container] [expected-pdf-pages]
#
# The PDF page count is a per-app number because the apps paginate the shipped
# document differently - LibreOffice and OpenOffice both make it 98 pages,
# AbiWord makes it 97 - and the run adds exactly two (one for the inserted image,
# one for the page break). Each app that differs from the default carries the
# number in <app>/expected-pdf-pages, which verify-app.sh and record-session.sh
# pass in.
#
# Every defect this group has produced so far was invisible in the screenshots:
# a replace-all that reported a count and changed nothing, a page break that the
# window manager swallowed, a typed line that landed inside a table cell. A
# screenshot check answers "does this look like it did when I recorded it"; only
# the saved document answers "did the run do the work".
#
# Counts are compared against the document generate_document.py ships, so this
# fails just as loudly on a document that was never opened as on one that was
# opened and not edited.
set -uo pipefail

CONTAINER="${1:-window-container}"
WANT_PDF_PAGES_ARG="${2:-100}"
ODT=/tmp/parrot-report.odt
PDF=/tmp/parrot-report.pdf

# What the shipped document contains, from generate_document.py.
WANT_ANCHOR=120       # Cormorant -> Shearwater
WANT_IMAGES=13        # 12 figures + the one the scenario inserts
WANT_TABLES=4         # 3 in the document + the one the scenario inserts
# The PDF page count is NOT here: it is per-app, and arrives as $2.

fail=0
ok()   { printf '  ok   %s\n' "$*"; }
bad()  { printf '  FAIL %s\n' "$*"; fail=1; }

docker exec -i "$CONTAINER" python3 - "$ODT" "$PDF" "$WANT_PDF_PAGES_ARG" <<'PY'
import re, sys, zipfile, os, zlib
import xml.etree.ElementTree as ET

odt, pdf = sys.argv[1], sys.argv[2]
want_pdf_pages = int(sys.argv[3])
out = []

def emit(good, msg):
    out.append(("ok  " if good else "FAIL", msg))

if not os.path.exists(odt):
    emit(False, f"{odt} does not exist - the document was never saved")
else:
    with zipfile.ZipFile(odt) as z:
        content = z.read("content.xml").decode("utf-8", "replace")
        pics = [n for n in z.namelist() if n.startswith("Pictures/")]

    # Replace all. 120 is what the generator puts in; any other number means a
    # different document, a different anchor, or a replace that half-ran.
    shear = content.count("Shearwater")
    corm  = content.count("Cormorant")
    emit(shear == 120, f"Shearwater x{shear} (want 120)")
    emit(corm == 0,    f"Cormorant x{corm} (want 0)")

    # The typed block. Checking the text, not a line count: the code editors
    # group shipped a recording whose ten new lines were all empty because the
    # Returns arrived and the characters did not.
    for line in ("The kestrel circled above the reservoir before dawn.",
                 "Three technicians logged the reading and filed the sheet.",
                 "Nothing in the record explained the drop in pressure."):
        emit(line in content, f"typed: {line[:44]}...")

    # The typed block must be a HEADING, which is what block 12 did to it. If
    # the style box silently kept focus, the text is there and the style is not.
    m = re.search(r'text:style-name="([^"]*)"[^>]*>Nothing in the record', content)
    style = m.group(1) if m else "(not found)"
    emit(bool(m) and "Heading" in style or style.startswith("P"),
         f"typed block carries a style ({style})")

    # Insert image and insert table.
    emit(len(pics) == 13, f"pictures x{len(pics)} (want 13)")
    tables = len(re.findall(r"<table:table ", content))
    emit(tables == 4, f"tables x{tables} (want 4)")
    # Alpha / Beta / Gamma must be in THREE SEPARATE CELLS of one row.
    #
    # The substring test this replaced - `">Alpha<" in content` - passes on a
    # document where all three words are in the SAME cell, because Calligra
    # writes that as
    #     <text:p>Alpha<text:tab/>Beta<text:tab/>Gamma</text:p>
    # and ">Alpha<" matches ">Alpha<text:tab/>". Calligra Words does exactly
    # this: Tab inside a table inserts a tab character instead of moving to the
    # next cell, and the old check called it ok on a one-cell table with two
    # empty cells beside it. That is the "counts do not record identity" blind
    # spot AGENTS.md warns about, in the ground truth itself.
    #
    # Searching every row of every table rather than assuming the inserted table
    # is last, so this does not depend on document order.
    TABLE = "{urn:oasis:names:tc:opendocument:xmlns:table:1.0}"
    root_t = ET.fromstring(content)
    def cell_text(cell):
        return "".join(cell.itertext()).strip()
    triple = False
    for tbl in root_t.iter(TABLE + "table"):
        for row in tbl.iter(TABLE + "table-row"):
            cells = [cell_text(c) for c in row.iter(TABLE + "table-cell")]
            if cells[:3] == ["Alpha", "Beta", "Gamma"]:
                triple = True
    emit(triple, "Alpha / Beta / Gamma in three separate cells of one row")

    # The page break, which the window manager ate the first time it was tried
    # (fluxbox binds Ctrl+F12, and Ctrl+Return landed inside a table cell).
    #
    # Counting the fo:break-before attribute does NOT work: the shipped document
    # defines ONE automatic style carrying it and references that style from all
    # twelve chapter headings, so the attribute appears once. Writer then rewrites
    # the automatic styles on save into some other number. The count that means
    # something is how many paragraphs REFERENCE a break-carrying style.
    #
    # PARSED, not pattern-matched. The first version of this anchored
    # style:name immediately after "<style:style ", which is how LibreOffice and
    # OpenOffice happen to write it. AbiWord writes style:family first, so the
    # pattern matched NOTHING and the check reported "x0 from 0 break style(s)"
    # on a document that had five break-carrying styles and seventeen paragraphs
    # using them.
    #
    # A hardened regex is not the answer either: a non-greedy body match stops at
    # the first "/>", so a style whose break sits after some other child element
    # would still be missed. ElementTree is in the standard library, costs
    # nothing, and is immune to both attribute order and child ordering.
    STYLE = "{urn:oasis:names:tc:opendocument:xmlns:style:1.0}"
    FO    = "{urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0}"
    TEXT  = "{urn:oasis:names:tc:opendocument:xmlns:text:1.0}"
    root = ET.fromstring(content)
    breakers = set()
    for st in root.iter(STYLE + "style"):
        name = st.get(STYLE + "name")
        if not name:
            continue
        for pp in st.iter(STYLE + "paragraph-properties"):
            if pp.get(FO + "break-before") == "page":
                breakers.add(name)
    refs = sum(1 for el in root.iter() if el.get(TEXT + "style-name") in breakers)
    emit(refs >= 13,
         f"paragraphs starting a new page x{refs} (12 chapters + 1 inserted), "
         f"from {len(breakers)} break style(s)")

def pdf_page_count(data):
    """Count /Type /Page objects, including ones inside compressed streams.

    A plain regex over the file works for the PDFs LibreOffice and OpenOffice
    write. It reports ZERO for AbiWord's, which comes out of GTK's print backend
    as PDF 1.7 with the page objects packed into ~100 compressed object streams -
    a 9.5 MB file that looked like an export that had produced nothing at all.
    Inflate the object streams and count there when the plain scan finds none.
    """
    pages = len(re.findall(rb"/Type\s*/Page[^s]", data))
    if pages:
        return pages
    for m in re.finditer(rb"/Type\s*/ObjStm", data):
        start = data.find(b"stream", m.end())
        if start < 0:
            continue
        start += len(b"stream")
        while start < len(data) and data[start] in (13, 10):
            start += 1
        end = data.find(b"endstream", start)
        if end < 0:
            continue
        try:
            inflated = zlib.decompress(data[start:end])
        except zlib.error:
            continue
        pages += len(re.findall(rb"/Type\s*/Page[^s]", inflated))
    return pages


if not os.path.exists(pdf):
    emit(False, f"{pdf} does not exist - the export never ran")
else:
    data = open(pdf, "rb").read()
    pages = pdf_page_count(data)
    emit(pages == want_pdf_pages,
         f"pdf {pages} pages, {len(data)//1024} KiB (want {want_pdf_pages})")

for tag, msg in out:
    print(f"  {tag} {msg}")
print("RESULT", "PASS" if all(t == "ok  " for t, _ in out) else "FAIL")
PY

docker exec "$CONTAINER" test -f "$ODT" || exit 1
