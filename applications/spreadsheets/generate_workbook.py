#!/usr/bin/env python3
"""Generate ``parrot-ledger.ods``, the workbook every spreadsheet opens.

The output is byte-for-byte identical on every machine: every random choice
comes from a fixed seed, every zip entry carries a frozen timestamp, and
nothing is read from the clock or the network. The file is committed to the
repository anyway - this script exists so the workbook can be changed and
regenerated, not because it is run at measurement time.

    ./generate_workbook.py                 # writes parrot-ledger.ods
    ./generate_workbook.py --check         # verify the anchors in an existing file
    ./generate_workbook.py --expected      # print what check-result.sh must assert

WHAT THE SCRIPT DEPENDS ON, AND WHY IT IS HERE RATHER THAN IN THE APPS

  Reading (column E) is UNIQUE across all 20,000 rows.  Block 7 sorts on it.
  With ties, a stable sort and an unstable sort put different rows in the same
  place, the reference screenshots stop being comparable between applications,
  and the ground truth can only assert that the column is non-decreasing rather
  than that it is exactly right.

  Category (column D) carries CATEGORY_COUNTS exactly.  Block 12 filters to
  Turbine, so how many rows survive is an assertable number rather than
  whatever the data happened to contain.

  Note (column H) carries ANCHOR exactly ANCHOR_COUNT times and
  ANCHOR_REPLACEMENT zero times.  Block 15 replaces one with the other.  It is
  in Note and not in Category because the Summary sheet's SUMIF formulas key on
  Category: renaming a category mid-run would silently change the chart drawn
  three blocks later.

  Cross-sheet formulas exist only on Summary, written here in ODF form.
  Nothing the script TYPES crosses a sheet - the ODF suites write Sites.A2 and
  Gnumeric writes Sites!A2, so a typed cross-sheet reference is a different
  formula in different applications.

  Every formula carries a CACHED VALUE as well as its text.  Recalculation on
  load is turned off in every profile so that block 2 measures a load and block
  11 measures a recalculation; an application that does not recalculate on load
  displays the cached value, and without one it would display zero.

  office:version is 1.2, not 1.3.  Apache OpenOffice implements 1.2 and puts a
  modal "ODF Version Conflict" in front of anything newer.

  Print ranges are set on all three sheets, so block 18 exports a bounded PDF
  instead of four hundred pages of grid.
"""

import argparse
import datetime as dt
import random
import re
import sys
import zipfile
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path
from xml.sax.saxutils import escape

# --------------------------------------------------------------------------
# Everything that decides what the workbook contains.
# --------------------------------------------------------------------------

SEED = 20260811
FIXED_TIMESTAMP = (2026, 1, 1, 0, 0, 0)

ROWS = 20_000  # data rows on Readings; the heading row is row 1

# The one number that has to be settled before the first recording.  The script
# names ranges by address - A1:H20001, I2:I20001, =SUM(I2:I20001) - so changing
# it invalidates every recording, every reference screenshot and the ground
# truth.  See the group README.
LAST_ROW = ROWS + 1

SITES = 40
FIRST_DAY = dt.date(2026, 1, 1)
DAYS = 365

# Counts, not probabilities.  A probability gives a different number of Turbine
# rows every time the seed changes, and block 12 filters to exactly this many.
CATEGORY_COUNTS = {
    "Intake": 3_000,
    "Conduit": 3_200,
    "Turbine": 3_400,
    "Spillway": 3_600,
    "Telemetry": 3_800,
    "Switchgear": 3_000,
}
FILTER_CATEGORY = "Turbine"

ANCHOR = "Cormorant"
ANCHOR_REPLACEMENT = "Shearwater"
ANCHOR_COUNT = 500

# Reading values.  An arithmetic progression shuffled into place: every value is
# distinct by construction, which no amount of random generation guarantees, and
# they still look like instrument readings.
READING_BASE = Decimal("10.00")
READING_STEP = Decimal("0.37")

FACTORS = [Decimal(f) for f in
           ("0.80", "0.85", "0.90", "0.95", "1.00", "1.05", "1.10", "1.15", "1.25")]

STATUSES = ["ok", "ok", "ok", "ok", "check"]

REGIONS = ["North", "Coast", "Highland", "Estuary"]

SITE_NAMES = """Harlow Weir, Kelsey Bank, Ardmore Cut, Penhale Race, Tarn Foot,
Bracken Sluice, Marrow Bay, Ivelet Head, Slaidburn Mill, Cadgwith Point,
Rushmere Lock, Glenholm Rise, Fenwick Drain, Oldbury Reach, Camlough Fall,
Trenance Pool, Bewcastle Ford, Sallow Marsh, Dunmail Gate, Wraysholme Bar,
Netherby Spur, Corrieburn, Alderford Cut, Meldon Basin, Stannage Edge,
Thrushgill, Broughton Ley, Halkyn Vale, Ennerdale Neb, Kirkoswald,
Portloe Steps, Whinlatter, Grizedale Beck, Ravenglass, Lanercost Mill,
Sedgwick Fold, Threlkeld Bank, Warcop Holme, Yealand Green, Zennor Cove"""
SITE_NAMES = [n.strip() for n in SITE_NAMES.replace("\n", " ").split(",")]

SENSOR_PREFIXES = ["FT", "PT", "TT", "LT", "VT", "AT"]

# Note text.  Real words, no punctuation any autocorrect will touch, and neither
# anchor token anywhere in the vocabulary.
NOTE_TEMPLATES = [
    "routine check",
    "no action taken",
    "logged by field staff",
    "within nominal band",
    "second pass confirmed",
    "instrument reseated",
    "reading held steady",
    "scheduled walkdown",
    "cleaned and refitted",
    "deferred to next quarter",
]
ANCHOR_TEMPLATES = [
    f"{ANCHOR} line isolated",
    f"compared against {ANCHOR}",
    f"{ANCHOR} feed reseated",
    f"routed through {ANCHOR}",
    f"{ANCHOR} logged separately",
]

HEADINGS = ["Date", "Site", "Sensor", "Category", "Reading", "Factor",
            "Status", "Note"]

# What gets printed, and therefore what ends up in the PDF block 18 exports.
# Without these the export is the used range - four hundred-odd pages of grid in
# whichever apps do not give up first - and the page count stops being a useful
# assertion.
PRINT_ROWS = 200

OUT = Path(__file__).resolve().parent / "parrot-ledger.ods"

NS = """xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" \
xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0" \
xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" \
xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" \
xmlns:number="urn:oasis:names:tc:opendocument:xmlns:datastyle:1.0" \
xmlns:fo="urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0" \
xmlns:of="urn:oasis:names:tc:opendocument:xmlns:of:1.2" \
xmlns:svg="urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0" \
xmlns:calcext="urn:org:documentfoundation:names:experimental:calc:xmlns:calcext:1.0\""""


# --------------------------------------------------------------------------
# The data.  Generated once and shared by the writer and by --check, so the
# ground truth and the file can never disagree about what should be in it.
# --------------------------------------------------------------------------

def money(value: Decimal) -> Decimal:
    """Round half away from zero, the way every spreadsheet's ROUND does.

    Python's round() is round-half-to-even, so round(2.675, 2) is 2.67 where
    every application in this group gives 2.68.  check-result.sh compares 20,000
    computed products against what the run left in column I; getting this wrong
    would fail an application for being correct.
    """
    return value.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def build_data():
    rng = random.Random(SEED)

    sites = [{"code": f"SITE-{i + 1:02d}",
              "name": SITE_NAMES[i],
              "region": REGIONS[i % len(REGIONS)]}
             for i in range(SITES)]

    # Unique by construction, then shuffled so the sheet does not arrive sorted.
    readings = [READING_BASE + READING_STEP * i for i in range(ROWS)]
    rng.shuffle(readings)

    categories = [c for c, n in CATEGORY_COUNTS.items() for _ in range(n)]
    assert len(categories) == ROWS, "CATEGORY_COUNTS must sum to ROWS"
    rng.shuffle(categories)

    anchor_rows = set(rng.sample(range(ROWS), ANCHOR_COUNT))

    rows = []
    for i in range(ROWS):
        site = sites[rng.randrange(SITES)]
        note = (rng.choice(ANCHOR_TEMPLATES) if i in anchor_rows
                else rng.choice(NOTE_TEMPLATES))
        rows.append({
            "date": FIRST_DAY + dt.timedelta(days=rng.randrange(DAYS)),
            "site": site["code"],
            "sensor": f"{rng.choice(SENSOR_PREFIXES)}-{rng.randrange(1000, 9999)}",
            "category": categories[i],
            "reading": readings[i],
            "factor": rng.choice(FACTORS),
            "status": rng.choice(STATUSES),
            "note": note,
        })

    # The per-category totals Summary caches, computed here rather than left to
    # the application: with recalculation-on-load off, the cached value is what
    # is on screen from block 2 until block 11.
    totals = {c: sum((r["reading"] for r in rows if r["category"] == c),
                     Decimal("0")) for c in CATEGORY_COUNTS}

    return sites, rows, totals


# --------------------------------------------------------------------------
# ODF.
# --------------------------------------------------------------------------

def cols_xml(style: str, count: int) -> str:
    return (f'<table:table-column table:style-name="{style}" '
            f'table:number-columns-repeated="{count}"/>')


def cell_text(value: str, style: str = "") -> str:
    st = f' table:style-name="{style}"' if style else ""
    return (f'<table:table-cell{st} office:value-type="string">'
            f'<text:p>{escape(value)}</text:p></table:table-cell>')


def cell_float(value, style: str = "") -> str:
    st = f' table:style-name="{style}"' if style else ""
    return (f'<table:table-cell{st} office:value-type="float" '
            f'office:value="{value}"><text:p>{value}</text:p></table:table-cell>')


def cell_date(value: dt.date) -> str:
    iso = value.isoformat()
    return (f'<table:table-cell table:style-name="ce-date" '
            f'office:value-type="date" office:date-value="{iso}">'
            f'<text:p>{iso}</text:p></table:table-cell>')


def cell_formula(formula: str, value) -> str:
    """A formula cell with its result cached beside it.

    ODF stores the formula in table:formula and the last computed result in
    office:value.  Both are needed: the formula so a recalculation has something
    to do, the value so the sheet is not full of zeros before one happens.
    """
    return (f'<table:table-cell table:formula="{escape(formula, {chr(34): "&quot;"})}" '
            f'office:value-type="float" office:value="{value}">'
            f'<text:p>{value}</text:p></table:table-cell>')


def row(cells: str) -> str:
    return f"<table:table-row>{cells}</table:table-row>"


def sheet(name: str, body: str, cols_xml: str, print_range: str) -> str:
    """One sheet, with its print range and its page setup.

    table:style-name="ta1" is what ties the sheet to the master page, and so to
    the LANDSCAPE page layout below.  Without it each application falls back to
    its own default page setup: portrait A4 in LibreOffice, where the eight
    columns are 20.8cm against 17cm of printable width, so G and H break onto
    pages of their own.  Where an application puts that break is a per-app
    decision, and the PDF page count - which is the only thing the ground truth
    can check about block 18 - would then differ for a reason that has nothing
    to do with the application's work.  Landscape fits all eight columns in one
    width and removes the question.

    table:print-ranges takes a cell-range-address-LIST - Readings.A1:Readings.H201,
    with the sheet named on both ends - and NOT the bracketed [Readings.$A$1:...]
    form that formulas use.  Given the bracketed form LibreOffice does not
    complain, does not warn, and prints the whole used range instead: the first
    version of this generator exported a 718-page, 44 MiB PDF and the only sign
    was the page count.
    """
    return (f'<table:table table:name="{name}" table:style-name="ta1" '
            f'table:print-ranges="{print_range}">{cols_xml}{body}</table:table>')


def readings_sheet(rows_data) -> str:
    out = [row("".join(cell_text(h, "ce-head") for h in HEADINGS))]
    for r in rows_data:
        out.append(row(
            cell_date(r["date"])
            + cell_text(r["site"])
            + cell_text(r["sensor"])
            + cell_text(r["category"])
            + cell_float(r["reading"])
            + cell_float(r["factor"])
            + cell_text(r["status"])
            + cell_text(r["note"])))
    # Seven narrow columns and a wide one.  Note holds the longest strings in
    # the workbook, and a column too narrow for them puts the decision about
    # what to do with the overflow - clip it, spill it, print it - in each
    # application's hands, inside the range block 18 exports.
    cols = (cols_xml("co1", 7) + cols_xml("co2", 1))
    return sheet("Readings", "".join(out), cols,
                 f"Readings.A1:Readings.H{PRINT_ROWS + 1}")


def sites_sheet(sites) -> str:
    out = [row("".join(cell_text(h, "ce-head")
                       for h in ("Site", "Name", "Region")))]
    for s in sites:
        out.append(row(cell_text(s["code"]) + cell_text(s["name"])
                       + cell_text(s["region"])))
    return sheet("Sites", "".join(out), cols_xml("co1", 3),
                 f"Sites.A1:Sites.C{SITES + 1}")


def summary_sheet(totals) -> str:
    """Six SUMIFs over the 20,000 rows of Readings, and a grand total.

    This is the only cross-sheet formula anywhere in the workbook, and the whole
    reason block 11 has anything to recalculate: each SUMIF walks the full
    Readings column.  Block 16 charts A1:B7.
    """
    # THE SECOND HALF OF A RANGE CARRIES ITS OWN LEADING DOT.
    #
    # OpenFormula writes a range as [Sheet.A1:.B2] - the end reference is `.B2`,
    # not `B2`, even when the sheet is named at the start. The first version of
    # this generator wrote [Readings.$D$2:$D$20001] and:
    #
    #   LibreOffice, and everything else descended from StarOffice, accepted it
    #   silently and computed the right answers, so nothing about the workbook
    #   looked wrong for the whole of the first application's measuring pass;
    #
    #   Gnumeric refused it outright - "Unable to parse
    #   'SUMIF([Readings.$D$2:$D$20001];[.A7];[Readings.$E$2:$E$20001])'
    #   ('Invalid expression')" - one modal per formula, before the window even
    #   appeared.
    #
    # The lenient majority is the danger here, not the strict one. Had the group
    # been all-LibreOffice-lineage, a malformed corpus would have shipped.
    out = [row(cell_text("Category", "ce-head") + cell_text("Total", "ce-head"))]
    for cat in CATEGORY_COUNTS:
        f = (f"of:=SUMIF([Readings.$D$2:.$D${LAST_ROW}];[.A{len(out) + 1}];"
             f"[Readings.$E$2:.$E${LAST_ROW}])")
        out.append(row(cell_text(cat) + cell_formula(f, totals[cat])))
    out.append(row(""))
    grand = sum(totals.values(), Decimal("0"))
    out.append(row(cell_text("All sites") + cell_formula("of:=SUM([.B2:.B7])", grand)))
    return sheet("Summary", "".join(out), cols_xml("co1", 2),
                 "Summary.A1:Summary.B9")


def content_xml(sites, rows_data, totals) -> str:
    styles = """<office:automatic-styles>
<style:style style:name="ta1" style:family="table" style:master-page-name="Default">\
<style:table-properties table:display="true" style:writing-mode="lr-tb"/></style:style>
<style:style style:name="co1" style:family="table-column">\
<style:table-column-properties style:column-width="2.6cm"/></style:style>
<style:style style:name="co2" style:family="table-column">\
<style:table-column-properties style:column-width="5.0cm"/></style:style>
<number:date-style style:name="N-date">\
<number:year number:style="long"/><number:text>-</number:text>\
<number:month number:style="long"/><number:text>-</number:text>\
<number:day number:style="long"/></number:date-style>
<style:style style:name="ce-date" style:family="table-cell" \
style:parent-style-name="Default" style:data-style-name="N-date"/>
<style:style style:name="ce-head" style:family="table-cell" \
style:parent-style-name="Default">\
<style:text-properties fo:font-weight="bold"/></style:style>
</office:automatic-styles>"""
    body = (readings_sheet(rows_data) + sites_sheet(sites)
            + summary_sheet(totals))
    return (f'<?xml version="1.0" encoding="UTF-8"?>\n'
            f'<office:document-content {NS} office:version="1.2">'
            f'{styles}'
            f'<office:body><office:spreadsheet>{body}'
            f'</office:spreadsheet></office:body></office:document-content>')


STYLES_XML = f"""<?xml version="1.0" encoding="UTF-8"?>
<office:document-styles {NS} office:version="1.2">
<office:styles>
<style:style style:name="Default" style:family="table-cell">\
<style:text-properties style:font-name="Liberation Sans" fo:font-size="10pt"/>\
</style:style>
</office:styles>
<office:automatic-styles>
<style:page-layout style:name="pm1"><style:page-layout-properties \
fo:page-width="29.7cm" fo:page-height="21.0cm" style:print-orientation="landscape" \
fo:margin-top="2cm" fo:margin-bottom="2cm" fo:margin-left="2cm" \
fo:margin-right="2cm"/></style:page-layout>
</office:automatic-styles>
<office:master-styles>
<style:master-page style:name="Default" style:page-layout-name="pm1"/>
</office:master-styles>
</office:document-styles>"""

META_XML = f"""<?xml version="1.0" encoding="UTF-8"?>
<office:document-meta {NS} \
xmlns:meta="urn:oasis:names:tc:opendocument:xmlns:meta:1.0" \
xmlns:dc="http://purl.org/dc/elements/1.1/" office:version="1.2">
<office:meta>
<meta:generator>parrot generate_workbook.py</meta:generator>
<dc:title>Parrot Field Ledger</dc:title>
<meta:creation-date>2026-01-01T00:00:00</meta:creation-date>
</office:meta></office:document-meta>"""

MANIFEST_XML = """<?xml version="1.0" encoding="UTF-8"?>
<manifest:manifest \
xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0" \
manifest:version="1.2">
<manifest:file-entry manifest:full-path="/" manifest:version="1.2" \
manifest:media-type="application/vnd.oasis.opendocument.spreadsheet"/>
<manifest:file-entry manifest:full-path="content.xml" \
manifest:media-type="text/xml"/>
<manifest:file-entry manifest:full-path="styles.xml" \
manifest:media-type="text/xml"/>
<manifest:file-entry manifest:full-path="meta.xml" \
manifest:media-type="text/xml"/>
</manifest:manifest>"""

MIMETYPE = "application/vnd.oasis.opendocument.spreadsheet"


def write_ods(path: Path) -> None:
    sites, rows_data, totals = build_data()

    def entry(zf, name, data, compress=zipfile.ZIP_DEFLATED):
        info = zipfile.ZipInfo(name, date_time=FIXED_TIMESTAMP)
        info.compress_type = compress
        info.external_attr = 0o644 << 16
        zf.writestr(info, data)

    with zipfile.ZipFile(path, "w") as zf:
        # mimetype first and stored, per the ODF packaging rules.
        entry(zf, "mimetype", MIMETYPE, zipfile.ZIP_STORED)
        entry(zf, "META-INF/manifest.xml", MANIFEST_XML)
        entry(zf, "meta.xml", META_XML)
        entry(zf, "styles.xml", STYLES_XML)
        entry(zf, "content.xml", content_xml(sites, rows_data, totals))


# --------------------------------------------------------------------------
# Checking.
# --------------------------------------------------------------------------

def check(path: Path) -> int:
    import xml.etree.ElementTree as ET

    T = "{urn:oasis:names:tc:opendocument:xmlns:table:1.0}"
    O = "{urn:oasis:names:tc:opendocument:xmlns:office:1.0}"

    fail = 0

    def report(good, msg):
        nonlocal fail
        print(f"  {'ok  ' if good else 'FAIL'} {msg}")
        if not good:
            fail = 1

    if not path.exists():
        print(f"  FAIL {path} does not exist")
        return 1

    with zipfile.ZipFile(path) as zf:
        content = zf.read("content.xml").decode()

    root = ET.fromstring(content)
    tables = {t.get(T + "name"): t for t in root.iter(T + "table")}
    report(set(tables) == {"Readings", "Sites", "Summary"},
           f"sheets {sorted(tables)}")

    rows = list(tables["Readings"].iter(T + "table-row"))
    report(len(rows) == LAST_ROW, f"Readings rows {len(rows)} (want {LAST_ROW})")

    readings, cats, notes = [], [], []
    for r in rows[1:]:
        cells = list(r.iter(T + "table-cell"))
        cats.append("".join(cells[3].itertext()))
        readings.append(cells[4].get(O + "value"))
        notes.append("".join(cells[7].itertext()))

    report(len(set(readings)) == ROWS,
           f"Reading unique x{len(set(readings))} of {ROWS} - the sort key")
    for cat, want in CATEGORY_COUNTS.items():
        got = cats.count(cat)
        report(got == want, f"Category {cat} x{got} (want {want})")

    anchors = sum(1 for n in notes if ANCHOR in n)
    replacements = sum(1 for n in notes if ANCHOR_REPLACEMENT in n)
    report(anchors == ANCHOR_COUNT,
           f"{ANCHOR} x{anchors} (want {ANCHOR_COUNT})")
    report(replacements == 0,
           f"{ANCHOR_REPLACEMENT} x{replacements} (want 0) - before the run")

    # Nothing outside Summary may reference another sheet: a typed cross-sheet
    # formula is not portable between the ODF suites and Gnumeric, and this is
    # the check that the workbook does not quietly acquire one.
    for name in ("Readings", "Sites"):
        formulas = [c.get(T + "formula") for c in tables[name].iter(T + "table-cell")
                    if c.get(T + "formula")]
        report(not formulas, f"{name} carries no formulas ({len(formulas)})")

    report('office:version="1.2"' in content,
           "ODF 1.2 - Apache OpenOffice rejects 1.3")

    # Every range in every formula must have a dot on BOTH endpoints. Gnumeric
    # rejects the dotless form outright and the StarOffice lineage accepts it
    # silently, so this is the check that stops a corpus only half the group can
    # read from shipping again.
    bad = [f for f in re.findall(r'table:formula="([^"]*)"', content)
           if re.search(r':(?!\.)[A-Za-z$]', f)]
    report(not bad, f"every formula range is dotted on both ends ({len(bad)} bad)"
                    + (f" e.g. {bad[0]}" if bad else ""))
    report(all(t.get(T + "print-ranges") for t in tables.values()),
           "every sheet has a print range")

    print("RESULT", "PASS" if not fail else "FAIL")
    return fail


def expected() -> None:
    """What check-result.sh has to assert after a run, computed from the data."""
    _, rows_data, _ = build_data()
    products = [money(r["reading"] * r["factor"]) for r in rows_data]
    srt = sorted(rows_data, key=lambda r: r["reading"])
    print(f"rows                 {ROWS}")
    print(f"sorted E2            {srt[0]['reading']}")
    print(f"sorted E{LAST_ROW}   {srt[-1]['reading']}")
    print(f"K1 = SUM(I2:I{LAST_ROW})  {sum(products, Decimal('0'))}")
    print(f"{ANCHOR_REPLACEMENT} after the run   {ANCHOR_COUNT}")
    print(f"{FILTER_CATEGORY} rows        {CATEGORY_COUNTS[FILTER_CATEGORY]}")
    print("NOTE: column I is computed AFTER the sort, so the expected value of")
    print("      I(n) is money(E(n) * F(n)) of the SORTED row n, not the")
    print("      generated one. check-result.sh must sort before comparing.")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--check", action="store_true",
                    help="verify the anchors in the existing file")
    ap.add_argument("--expected", action="store_true",
                    help="print what a finished run should leave behind")
    args = ap.parse_args()

    if args.expected:
        expected()
        return 0
    if args.check:
        return check(OUT)

    write_ods(OUT)
    size = OUT.stat().st_size
    print(f"wrote {OUT} ({size / 1024 / 1024:.1f} MiB)")
    return check(OUT)


if __name__ == "__main__":
    sys.exit(main())
