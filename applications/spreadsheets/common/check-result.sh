#!/usr/bin/env bash
# Assert what the scenario was supposed to have done, against the files it left
# behind rather than against the screenshots.
#
#   check-result.sh [container] [expected-pdf-pages]
#
# Every defect the word processor group produced was invisible in the
# screenshots: a replace-all that reported a count and changed nothing, a page
# break the window manager swallowed, a typed line that landed in a table cell.
# A spreadsheet has more ways to look right and be wrong than a document does -
# a fill-down that stopped at row 1000 looks identical on screen to one that
# reached row 20001, because you cannot see row 1000 from the top of the sheet.
#
# NOTHING HERE NEEDS THE GENERATOR'S SEED.  The Reading column is an arithmetic
# progression by construction, so the set of values that must survive the run is
# a closed form, and column I is checked against E and F of the SAME saved row -
# which is what makes the check independent of how the sort happened to land.
set -uo pipefail

CONTAINER="${1:-window-container}"
WANT_PDF_PAGES_ARG="${2:-9}"
ODS=/tmp/parrot-ledger.ods
PDF=/tmp/parrot-ledger.pdf

docker exec -i "$CONTAINER" python3 - "$ODS" "$PDF" "$WANT_PDF_PAGES_ARG" <<'PY'
import os
import re
import sys
import zipfile
import zlib
import xml.etree.ElementTree as ET
from decimal import Decimal, ROUND_HALF_UP, ROUND_HALF_DOWN

ods, pdf = sys.argv[1], sys.argv[2]
want_pdf_pages = int(sys.argv[3])

# Must match generate_workbook.py.  Duplicated rather than imported because this
# runs inside the container, where the generator is not installed.
ROWS = 20_000
LAST_ROW = ROWS + 1
READING_BASE = Decimal("10.00")
READING_STEP = Decimal("0.37")
FACTORS = {Decimal(f) for f in
           ("0.80", "0.85", "0.90", "0.95", "1.00", "1.05", "1.10", "1.15", "1.25")}
ANCHOR = "Cormorant"
ANCHOR_REPLACEMENT = "Shearwater"
ANCHOR_COUNT = 500
FILTER_CATEGORY = "Turbine"
FILTER_ROWS = 3_400

TABLE = "{urn:oasis:names:tc:opendocument:xmlns:table:1.0}"
OFFICE = "{urn:oasis:names:tc:opendocument:xmlns:office:1.0}"
STYLE = "{urn:oasis:names:tc:opendocument:xmlns:style:1.0}"
NUMBER = "{urn:oasis:names:tc:opendocument:xmlns:datastyle:1.0}"
CONFIG = "{urn:oasis:names:tc:opendocument:xmlns:config:1.0}"
CHART = "{urn:oasis:names:tc:opendocument:xmlns:chart:1.0}"

out = []


def emit(good, msg):
    out.append(("ok  " if good else "FAIL", msg))


CENT = Decimal("0.01")


def money(value, rounding=ROUND_HALF_UP):
    """ROUND(x, 2) as a spreadsheet does it: half away from zero.

    Python's round() is half-to-even and would disagree with these applications
    on every value ending in a half cent - failing them for being correct.
    """
    return value.quantize(CENT, rounding=rounding)


def cents(value):
    """A stored value, snapped back to the two decimals it is supposed to have.

    NOT cosmetic. The applications do not agree on how to SERIALISE a number:

        LibreOffice   office:value="8.59"
        Gnumeric      office:value="8.5899999999999999"

    Gnumeric writes the full double, so a comparison of exact Decimals fails on
    essentially every cell of a sheet that is entirely correct - and it fails on
    the shipped Reading and Factor columns too, which the run never touched.
    The first version of this checker did exactly that. Snapping to two decimals
    first is what makes the assertions about arithmetic rather than about
    serialisation.
    """
    return None if value is None else value.quantize(CENT, rounding=ROUND_HALF_UP)


def expand_row(row, want_cols):
    """The cells of one row, with table:number-columns-repeated expanded.

    Every application writes repeated and trailing cells in compressed form, and
    a naive list(row.iter(cell)) therefore returns a DIFFERENT number of cells
    per application for the same sheet - so column E is at index 4 in one file
    and index 2 in another, and every value read after that is the wrong one.
    """
    cells = []
    for cell in row:
        if cell.tag not in (TABLE + "table-cell", TABLE + "covered-table-cell"):
            continue
        repeat = int(cell.get(TABLE + "number-columns-repeated", 1))
        # A trailing cell can claim to repeat to the end of the sheet.
        repeat = min(repeat, want_cols + 1)
        cells.extend([cell] * repeat)
        if len(cells) > want_cols:
            break
    while len(cells) < want_cols:
        cells.append(None)
    return cells[:want_cols]


def expand_rows(table, want_rows, want_cols):
    """Rows with table:number-rows-repeated expanded, stopping at want_rows.

    Uncapped this runs to the sheet's last row, which is a million-odd empty
    rows in most of these applications and sixteen million in Gnumeric.
    """
    rows = []
    for row in table.iter(TABLE + "table-row"):
        repeat = int(row.get(TABLE + "number-rows-repeated", 1))
        repeat = min(repeat, want_rows - len(rows) + 1)
        for _ in range(repeat):
            rows.append(expand_row(row, want_cols))
            if len(rows) >= want_rows:
                return rows
    return rows


def value_of(cell):
    if cell is None:
        return None
    v = cell.get(OFFICE + "value")
    return Decimal(v) if v is not None else None


def text_of(cell):
    return "" if cell is None else "".join(cell.itertext())


if not os.path.exists(ods):
    emit(False, f"{ods} does not exist - the workbook was never saved")
else:
    with zipfile.ZipFile(ods) as z:
        names = z.namelist()
        content = z.read("content.xml").decode("utf-8", "replace")
        # styles.xml matters: it is where the applications put the number style
        # that block 14's format resolves through.
        styles = (z.read("styles.xml").decode("utf-8", "replace")
                  if "styles.xml" in names else "")
        settings = (z.read("settings.xml").decode("utf-8", "replace")
                    if "settings.xml" in names else "")
        # The chart block 16 inserted is an embedded document of its own.
        charts = []
        for n in names:
            if n.endswith("content.xml") and n != "content.xml":
                try:
                    charts.append((n, ET.fromstring(z.read(n))))
                except ET.ParseError:
                    pass

    root = ET.fromstring(content)
    try:
        styles_root = ET.fromstring(styles) if styles else None
    except ET.ParseError:
        styles_root = None
    tables = {t.get(TABLE + "name"): t for t in root.iter(TABLE + "table")}
    emit(set(tables) >= {"Readings", "Sites", "Summary"},
         f"sheets {sorted(tables)}")

    if "Readings" in tables:
        # A..K: eight data columns, the filled formula in I, the total in K.
        rows = expand_rows(tables["Readings"], LAST_ROW, 11)
        emit(len(rows) == LAST_ROW,
             f"Readings rows {len(rows)} (want {LAST_ROW})")

        readings = [cents(value_of(r[4])) for r in rows[1:]]
        factors = [cents(value_of(r[5])) for r in rows[1:]]
        computed = [cents(value_of(r[8])) for r in rows[1:]]
        formulas = [r[8] is not None and r[8].get(TABLE + "formula")
                    for r in rows[1:]]

        # BLOCK 7, the sort.  Two assertions, because either alone passes on a
        # sheet the other would fail: non-decreasing says it is in order, and the
        # set says nothing was lost or overwritten getting there.  A sort of
        # column E alone - the classic spreadsheet mistake, and what happens if
        # the selection is one column instead of A1:H20001 - passes the first
        # and would pass the second too, which is what the I == E*F check below
        # is for: it is the only one that sees the columns come apart.
        present = [r for r in readings if r is not None]
        emit(len(present) == ROWS, f"Reading values present x{len(present)}")
        emit(present == sorted(present),
             "Reading non-decreasing over rows 2..%d - the sort ran" % LAST_ROW)
        want = {(READING_BASE + READING_STEP * i).quantize(CENT)
                for i in range(ROWS)}
        emit(set(present) == want,
             f"Reading is exactly the shipped set ({len(set(present) ^ want)} differ)")
        emit(all(f in FACTORS for f in factors if f is not None),
             "every Factor is one of the shipped factors")

        # BLOCKS 8 and 9, the formula and the fill-down.  Checked against E and F
        # of the same SAVED row, so it holds whatever order the sort produced.
        # A fill-down that stopped early is invisible on screen: you cannot see
        # row 1000 from the top of the sheet, and the last checkpoint before the
        # save is not looking at row 20001 either.
        filled = sum(1 for f in formulas if f)
        emit(filled == ROWS, f"column I holds x{filled} formulas (want {ROWS})")
        # ROUND on an exact half-cent is genuinely ambiguous and the applications
        # do not agree, because none of them is rounding a decimal - they are
        # rounding a double. 13.70 * 0.85 is 11.6450 exactly and
        # 11.644999999999999 in IEEE 754, so Gnumeric answers 11.65 on about 700
        # of these 20,000 rows where an exact-decimal HALF_UP says 11.64.
        # Neither is wrong.
        #
        # So a tie is allowed to fall either way and NOTHING else is. For a
        # product that is not an exact half-cent the two bounds are the same
        # number and this stays a strict equality, which is the point: it still
        # catches a fill-down that stopped early, filled a constant, or drifted
        # off its row.
        wrong = []
        for i, (r, f, c) in enumerate(zip(readings, factors, computed)):
            if None in (r, f, c):
                wrong.append(i + 2)
                continue
            p = r * f
            if c not in (money(p), money(p, ROUND_HALF_DOWN)):
                wrong.append(i + 2)
        ties = sum(1 for r, f in zip(readings, factors)
                   if None not in (r, f) and money(r * f) != money(r * f, ROUND_HALF_DOWN))
        emit(not wrong,
             f"column I == ROUND(E*F,2) on every row ({ties} half-cent ties allowed "
             f"either way)"
             + (f" - first wrong at row {wrong[0]}, {len(wrong)} rows" if wrong else ""))

        # BLOCK 10, the total.  Compared with a tolerance: the applications sum
        # 20,000 doubles in whatever order they please, and the last bit of a
        # 74-million total is not something to fail an application over.
        total = value_of(rows[0][10]) if rows else None
        want_total = sum((c for c in computed if c is not None), Decimal("0"))
        emit(total is not None and abs(total - want_total) < Decimal("0.05"),
             f"K1 = {total} (want {want_total})")

        # BLOCK 15, the replace-all.
        notes = [text_of(r[7]) for r in rows[1:]]
        shear = sum(1 for n in notes if ANCHOR_REPLACEMENT in n)
        corm = sum(1 for n in notes if ANCHOR in n)
        emit(shear == ANCHOR_COUNT,
             f"{ANCHOR_REPLACEMENT} x{shear} (want {ANCHOR_COUNT})")
        emit(corm == 0, f"{ANCHOR} x{corm} (want 0)")

        # BLOCK 12 only has to have SELECTED the right rows; block 13 has to have
        # put them all back.  A filter that is still applied leaves the hidden
        # rows in the file, and the saved sheet then has 3,400 visible rows and
        # 16,600 that only exist for anyone who looks - including the PDF.
        cats = [text_of(r[3]) for r in rows[1:]]
        emit(cats.count(FILTER_CATEGORY) == FILTER_ROWS,
             f"{FILTER_CATEGORY} rows x{cats.count(FILTER_CATEGORY)} "
             f"(want {FILTER_ROWS}) - what block 12 filtered to")
        hidden = sum(1 for r in tables["Readings"].iter(TABLE + "table-row")
                     if r.get(TABLE + "visibility") in ("collapse", "filter"))
        emit(hidden == 0, f"hidden rows x{hidden} (want 0) - the filter was cleared")

        # BLOCK 14, the number format.  Resolved through the whole style chain,
        # because every link in it is somewhere an application is free to put it:
        #
        #   the number style       may live in styles.xml, NOT content.xml
        #   the cell style         names the number style through data-style-name
        #   the cell               may name the cell style itself, OR inherit it
        #                          from the COLUMN's default-cell-style-name
        #
        # LibreOffice applying a format to E2:E20001 writes neither of the two
        # obvious things: it puts the number style in styles.xml and hangs the
        # cell style off the column, leaving all 20,000 cells with no style
        # attribute at all.  A checker that reads only per-cell styles in
        # content.xml reports zero formatted cells on a sheet that is entirely
        # correctly formatted.
        decimals = {}
        for tree in (root, styles_root):
            if tree is None:
                continue
            for st in tree.iter(NUMBER + "number-style"):
                for n in st.iter(NUMBER + "number"):
                    decimals[st.get(STYLE + "name")] = n.get(NUMBER + "decimal-places")
        two_dp = set()
        for tree in (root, styles_root):
            if tree is None:
                continue
            for st in tree.iter(STYLE + "style"):
                name = st.get(STYLE + "name")
                if name and decimals.get(st.get(STYLE + "data-style-name")) == "2":
                    two_dp.add(name)

        # The default cell style of column E, if the format was applied there.
        col_styles = []
        for col in tables["Readings"].iter(TABLE + "table-column"):
            repeat = min(int(col.get(TABLE + "number-columns-repeated", 1)), 16)
            col_styles.extend([col.get(TABLE + "default-cell-style-name")] * repeat)
        col_e = col_styles[4] if len(col_styles) > 4 else None

        formatted = sum(1 for r in rows[1:]
                        if r[4] is not None
                        and (r[4].get(TABLE + "style-name") or col_e) in two_dp)
        emit(formatted == ROWS,
             f"E2:E{LAST_ROW} carry a two-decimal format x{formatted} (want {ROWS}) "
             f"[column style {col_e}]")

    # BLOCK 4, the freeze.  ODF records it in settings.xml as a split MODE of 2
    # (frozen) as against 1 (a draggable split), per sheet.
    # Confirmed against a workbook LibreOffice really wrote: freezing row 1 and
    # saving gives HorizontalSplitMode=0, VerticalSplitMode=2,
    # VerticalSplitPosition=1.  Mode 2 is frozen where 1 is a draggable split,
    # so the mode is the assertion and the position is only diagnostic.
    #
    # One trap on the way there: a document opened with Hidden=True writes a
    # settings.xml with NO Views block at all, so the freeze vanishes from the
    # file while remaining set in the running application.  That is an artefact
    # of loading hidden and not something a recorded run can hit - but it is
    # exactly what a "the app does not persist this" conclusion would look like.
    split = re.findall(r'config:name="([^"]*Split[^"]*)"[^>]*>([^<]*)<', settings)
    frozen = ("VerticalSplitMode", "2") in split
    emit(frozen, "Readings carries a frozen split "
                 f"(settings.xml VerticalSplitMode=2); found {split or 'no split keys'}")

    # BLOCK 16, the chart.  Parsed, not substring-matched: "chart" appears in
    # the namespace declarations of every embedded object whether or not one was
    # ever inserted.
    found = [(n, c.iter(CHART + "chart")) for n, c in charts]
    kinds = [ch.get(CHART + "class") for n, c in charts
             for ch in c.iter(CHART + "chart")]
    emit(bool(kinds), f"embedded chart x{len(kinds)} {kinds}")


def pdf_page_count(data):
    """Count /Type /Page objects, including ones inside compressed streams.

    A plain regex works for the PDFs LibreOffice and OpenOffice write and reports
    ZERO for a GTK print backend's, which packs the page objects into compressed
    object streams - a file that looks like an export that produced nothing.
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
    # The workbook carries print ranges, so this is bounded and comparable. If
    # it comes back in the hundreds, that application ignored them and its
    # figure for block 18 is not like anybody else's.
    emit(pages == want_pdf_pages,
         f"pdf {pages} pages, {len(data) // 1024} KiB (want {want_pdf_pages})")

for tag, msg in out:
    print(f"  {tag} {msg}")
print("RESULT", "PASS" if all(t == "ok  " for t, _ in out) else "FAIL")
PY

docker exec "$CONTAINER" test -f "$ODS" || exit 1
