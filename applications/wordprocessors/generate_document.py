#!/usr/bin/env python3
"""Generate ``parrot-report.odt``, the document every word processor opens.

The output is byte-for-byte identical on every machine: every random choice
comes from a fixed seed, every zip entry carries a frozen timestamp, and
nothing is read from the clock or the network. The file is committed to the
repository anyway - this script exists so the document can be changed and
regenerated, not because it is run at measurement time.

    ./generate_document.py                 # writes parrot-report.odt
    ./generate_document.py --check         # verify anchors in an existing file

Layout targets roughly 100 A4 pages in Liberation Serif 12pt. ``PARAGRAPHS``
below is calibrated against a real render; see ``--pages`` to re-measure.
"""

import argparse
import io
import random
import sys
import zipfile
from pathlib import Path

from PIL import Image, ImageDraw

# --------------------------------------------------------------------------
# Everything that decides what the document contains.
# --------------------------------------------------------------------------

SEED = 20260807
FIXED_TIMESTAMP = (2026, 1, 1, 0, 0, 0)

CHAPTERS = 12
SECTIONS_PER_CHAPTER = 4
PARAGRAPHS = 11  # per section; calibrated so the render lands near 100 pages
WORDS_MIN, WORDS_MAX = 70, 120

IMAGES = 12  # one per chapter, placed after the first section
IMAGE_PX = (1200, 770)  # ~200 dpi at the 15cm the figures are placed at
IMAGE_WIDTH_CM = 15.0
IMAGE_NOISE = 0.022  # blended in so the PNGs compress like photographs, not
                     # like flat vector art; tuned for ~500 KiB per figure

TABLES = 3  # placed in chapters 3, 7 and 11
TABLE_CHAPTERS = (3, 7, 11)
TABLE_ROWS = 6  # including the header row
TABLE_COLS = 4

# The anchors the scenario depends on. ``ANCHOR`` must appear exactly
# ANCHOR_COUNT times and ``ANCHOR_REPLACEMENT`` must appear zero times, so
# "replace all" does an identical, assertable amount of work in every app.
ANCHOR = "Cormorant"
ANCHOR_REPLACEMENT = "Shearwater"
ANCHOR_COUNT = 120

BODY_FONT = "Liberation Serif"
HEAD_FONT = "Liberation Sans"

# --------------------------------------------------------------------------
# Prose. Real words, no punctuation that any autocorrect will touch, and
# neither anchor token anywhere in the vocabulary.
# --------------------------------------------------------------------------

NOUNS = """reservoir turbine catchment sensor gauge conduit substation feeder
pipeline embankment spillway culvert transformer switchgear inverter compressor
manifold reservoirs telemetry cabinet enclosure bearing coupling impeller
diaphragm actuator regulator accumulator condenser evaporator heat exchanger
valve seal flange gasket bracket housing rotor stator winding insulator
busbar breaker relay contactor rectifier capacitor resistor filter membrane
cartridge strainer weir sluice penstock draft tube tailrace forebay intake
screen trash rack anchorage abutment parapet revetment groyne breakwater""".split()

ADJECTIVES = """nominal marginal elevated reduced stable erratic seasonal
persistent intermittent gradual abrupt measured provisional revised secondary
adjacent downstream upstream peripheral internal external mechanical thermal
hydraulic electrical structural operational routine scheduled unplanned
subsequent preceding local regional combined partial complete""".split()

VERBS = """recorded reported indicated confirmed suggested exceeded approached
remained returned declined increased stabilised fluctuated preceded followed
accompanied replaced supplemented required prompted delayed advanced restricted
permitted revealed obscured matched contradicted supported""".split()

TEMPLATES = [
    "The {adj} {noun} {verb} a {adj} reading during the {ord} inspection window.",
    "Field staff {verb} that the {noun} had remained {adj} for the whole period.",
    "A {adj} {noun} was fitted upstream of the {noun} before the survey began.",
    "Neither the {noun} nor the {adj} {noun} {verb} any change worth recording.",
    "Readings taken at the {noun} {verb} values consistent with the {adj} baseline.",
    "The {ord} survey {verb} a {adj} shift in the behaviour of the {noun}.",
    "Maintenance on the {adj} {noun} was deferred until the {ord} quarter.",
    "The {noun} and its {adj} {noun} were inspected and returned to service.",
    "No {adj} fault was found in the {noun} during the {ord} walkdown.",
    "Data from the {noun} {verb} the conclusion reached in the {ord} chapter.",
    "The {adj} {noun} continues to operate within the limits set for it.",
    "Replacement of the {noun} {verb} a {adj} improvement in throughput.",
]

# Sentences carrying the find-and-replace anchor.
ANCHOR_TEMPLATES = [
    f"The {{noun}} feeding {ANCHOR} was isolated for the duration of the test.",
    f"{ANCHOR} returned to its {{adj}} operating point without intervention.",
    f"Output from {ANCHOR} was logged alongside the {{adj}} {{noun}} readings.",
    f"Staff attending {ANCHOR} recorded no {{adj}} deviation that shift.",
    f"The {{adj}} {{noun}} downstream of {ANCHOR} was cleaned and refitted.",
]

ORDINALS = ["first", "second", "third", "fourth", "fifth", "sixth", "seventh",
            "eighth", "ninth", "tenth", "eleventh", "twelfth"]

CHAPTER_TITLES = [
    "Scope and Method", "Catchment Conditions", "Intake Structures",
    "Conveyance and Losses", "Generating Plant", "Electrical Systems",
    "Instrumentation", "Control and Telemetry", "Civil Works",
    "Environmental Monitoring", "Maintenance Record", "Findings and Actions",
]

SECTION_TITLES = [
    "Background", "Observations", "Analysis", "Recommendations",
]

TABLE_HEADERS = ["Reference", "Location", "Reading", "Status"]
TABLE_STATUS = ["Nominal", "Marginal", "Elevated", "Stable", "Reduced", "Pending"]


def sentence(rng, template):
    return template.format(
        noun=rng.choice(NOUNS),
        adj=rng.choice(ADJECTIVES),
        verb=rng.choice(VERBS),
        ord=rng.choice(ORDINALS),
    )


def paragraph(rng):
    """A paragraph nothing in any autocorrect will rewrite.

    Every sentence starts with a capital and ends with a period, there are no
    apostrophes, quotes, dashes, ellipses, ordinals written as digits, URLs or
    digits adjacent to letters, and no line starts with a dash or a number.
    """
    words, parts = 0, []
    target = rng.randint(WORDS_MIN, WORDS_MAX)
    while words < target:
        s = sentence(rng, rng.choice(TEMPLATES))
        parts.append(s)
        words += len(s.split())
    return " ".join(parts)


# --------------------------------------------------------------------------
# Images. Chart-like figures over seeded noise, so they compress like real
# photographs rather than to nothing, and decoding them costs something.
# --------------------------------------------------------------------------

def make_image(rng, index):
    w, h = IMAGE_PX
    base = Image.new("RGB", (w, h), (250, 249, 246))
    draw = ImageDraw.Draw(base)

    hue = [(58, 92, 130), (128, 74, 62), (74, 110, 82), (108, 86, 128)][index % 4]

    # A soft vertical gradient behind everything.
    for y in range(0, h, 4):
        t = y / h
        draw.rectangle(
            [0, y, w, y + 4],
            fill=(int(250 - 40 * t), int(249 - 38 * t), int(246 - 30 * t)),
        )

    # Plot frame.
    left, right, top, bottom = 120, w - 80, 90, h - 110
    draw.rectangle([left, top, right, bottom], outline=(180, 178, 172), width=3)
    for i in range(1, 6):
        y = top + (bottom - top) * i // 6
        draw.line([left, y, right, y], fill=(214, 212, 206), width=2)

    # Bars.
    bars = 18
    span = (right - left) / bars
    for i in range(bars):
        val = rng.uniform(0.15, 0.95)
        x0 = left + i * span + span * 0.18
        x1 = left + (i + 1) * span - span * 0.18
        y0 = bottom - (bottom - top) * val
        shade = tuple(min(255, c + rng.randint(-18, 18)) for c in hue)
        draw.rectangle([x0, y0, x1, bottom], fill=shade)

    # A trend line over the top.
    pts, prev = [], rng.uniform(0.3, 0.7)
    for i in range(bars):
        prev = max(0.1, min(0.95, prev + rng.uniform(-0.12, 0.12)))
        pts.append((left + (i + 0.5) * span, bottom - (bottom - top) * prev))
    draw.line(pts, fill=(196, 82, 54), width=5, joint="curve")
    for px, py in pts:
        draw.ellipse([px - 7, py - 7, px + 7, py + 7], fill=(196, 82, 54))

    # Seeded noise, blended in so the PNG does not compress away to nothing.
    noise = Image.frombytes("L", (w, h), rng.randbytes(w * h)).convert("RGB")
    return Image.blend(base, noise, IMAGE_NOISE)


# --------------------------------------------------------------------------
# ODF
# --------------------------------------------------------------------------

def esc(text):
    return (text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"))


NS = (
    'xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
    'xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0" '
    'xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" '
    'xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" '
    'xmlns:draw="urn:oasis:names:tc:opendocument:xmlns:drawing:1.0" '
    'xmlns:fo="urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0" '
    'xmlns:xlink="http://www.w3.org/1999/xlink" '
    'xmlns:svg="urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0" '
    'xmlns:meta="urn:oasis:names:tc:opendocument:xmlns:meta:1.0" '
    'xmlns:dc="http://purl.org/dc/elements/1.1/"'
)


def styles_xml():
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<office:document-styles {NS} office:version="1.3">
 <office:font-face-decls>
  <style:font-face style:name="{BODY_FONT}" svg:font-family="{BODY_FONT}" style:font-family-generic="roman" style:font-pitch="variable"/>
  <style:font-face style:name="{HEAD_FONT}" svg:font-family="{HEAD_FONT}" style:font-family-generic="swiss" style:font-pitch="variable"/>
 </office:font-face-decls>
 <office:styles>
  <style:default-style style:family="paragraph">
   <style:paragraph-properties fo:hyphenation-ladder-count="no-limit" style:line-break="strict"/>
   <style:text-properties style:font-name="{BODY_FONT}" fo:font-size="12pt" fo:language="en" fo:country="GB"/>
  </style:default-style>
  <style:style style:name="Standard" style:family="paragraph" style:class="text">
   <style:paragraph-properties fo:margin-top="0cm" fo:margin-bottom="0.212cm" fo:text-align="justify"/>
   <style:text-properties style:font-name="{BODY_FONT}" fo:font-size="12pt"/>
  </style:style>
  <style:style style:name="Text_20_body" style:display-name="Text body" style:family="paragraph" style:parent-style-name="Standard" style:class="text">
   <style:paragraph-properties fo:margin-top="0cm" fo:margin-bottom="0.247cm" fo:text-align="justify"/>
  </style:style>
  <style:style style:name="Heading" style:family="paragraph" style:parent-style-name="Standard" style:next-style-name="Text_20_body" style:class="text">
   <style:paragraph-properties fo:margin-top="0.423cm" fo:margin-bottom="0.212cm" fo:keep-with-next="always" fo:text-align="start"/>
   <style:text-properties style:font-name="{HEAD_FONT}" fo:font-size="14pt"/>
  </style:style>
  <style:style style:name="Heading_20_1" style:display-name="Heading 1" style:family="paragraph" style:parent-style-name="Heading" style:next-style-name="Text_20_body" style:default-outline-level="1" style:class="text">
   <style:paragraph-properties fo:margin-top="0.847cm" fo:margin-bottom="0.423cm"/>
   <style:text-properties style:font-name="{HEAD_FONT}" fo:font-size="22pt" fo:font-weight="bold"/>
  </style:style>
  <style:style style:name="Heading_20_2" style:display-name="Heading 2" style:family="paragraph" style:parent-style-name="Heading" style:next-style-name="Text_20_body" style:default-outline-level="2" style:class="text">
   <style:paragraph-properties fo:margin-top="0.635cm" fo:margin-bottom="0.212cm"/>
   <style:text-properties style:font-name="{HEAD_FONT}" fo:font-size="16pt" fo:font-weight="bold"/>
  </style:style>
  <style:style style:name="Title" style:family="paragraph" style:parent-style-name="Heading" style:next-style-name="Subtitle" style:class="chapter">
   <style:paragraph-properties fo:margin-top="0cm" fo:margin-bottom="0.212cm" fo:text-align="center"/>
   <style:text-properties style:font-name="{HEAD_FONT}" fo:font-size="28pt" fo:font-weight="bold"/>
  </style:style>
  <style:style style:name="Subtitle" style:family="paragraph" style:parent-style-name="Heading" style:next-style-name="Text_20_body" style:class="chapter">
   <style:paragraph-properties fo:margin-top="0.212cm" fo:margin-bottom="0.529cm" fo:text-align="center"/>
   <style:text-properties style:font-name="{HEAD_FONT}" fo:font-size="16pt" fo:font-style="italic"/>
  </style:style>
  <style:style style:name="Caption" style:family="paragraph" style:parent-style-name="Standard" style:class="extra">
   <style:paragraph-properties fo:margin-top="0.212cm" fo:margin-bottom="0.423cm" fo:text-align="center"/>
   <style:text-properties style:font-name="{BODY_FONT}" fo:font-size="10pt" fo:font-style="italic"/>
  </style:style>
  <style:style style:name="Figure" style:family="paragraph" style:parent-style-name="Standard" style:class="extra">
   <style:paragraph-properties fo:margin-top="0.423cm" fo:margin-bottom="0cm" fo:text-align="center"/>
  </style:style>
  <style:style style:name="Table_20_Contents" style:display-name="Table Contents" style:family="paragraph" style:parent-style-name="Standard" style:class="extra">
   <style:paragraph-properties fo:text-align="start" text:number-lines="false" text:line-number="0"/>
   <style:text-properties fo:font-size="11pt"/>
  </style:style>
  <style:style style:name="Table_20_Heading" style:display-name="Table Heading" style:family="paragraph" style:parent-style-name="Table_20_Contents" style:class="extra">
   <style:paragraph-properties fo:text-align="start"/>
   <style:text-properties fo:font-size="11pt" fo:font-weight="bold"/>
  </style:style>
 </office:styles>
 <office:automatic-styles>
  <style:page-layout style:name="pm1">
   <style:page-layout-properties fo:page-width="21.001cm" fo:page-height="29.7cm" style:print-orientation="portrait" fo:margin-top="2cm" fo:margin-bottom="2cm" fo:margin-left="2cm" fo:margin-right="2cm" style:writing-mode="lr-tb"/>
  </style:page-layout>
 </office:automatic-styles>
 <office:master-styles>
  <style:master-page style:name="Standard" style:page-layout-name="pm1"/>
 </office:master-styles>
</office:document-styles>
"""


def content_xml(body):
    img_h = IMAGE_WIDTH_CM * IMAGE_PX[1] / IMAGE_PX[0]
    cols = "".join(
        f'<style:style style:name="co{i+1}" style:family="table-column">'
        f'<style:table-column-properties style:column-width="4.25cm"/></style:style>'
        for i in range(TABLE_COLS)
    )
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<office:document-content {NS} office:version="1.3">
 <office:font-face-decls>
  <style:font-face style:name="{BODY_FONT}" svg:font-family="{BODY_FONT}" style:font-family-generic="roman" style:font-pitch="variable"/>
  <style:font-face style:name="{HEAD_FONT}" svg:font-family="{HEAD_FONT}" style:font-family-generic="swiss" style:font-pitch="variable"/>
 </office:font-face-decls>
 <office:automatic-styles>
  <style:style style:name="fr1" style:family="graphic">
   <style:graphic-properties style:vertical-pos="middle" style:vertical-rel="text" style:horizontal-pos="center" style:horizontal-rel="paragraph" fo:padding="0cm" fo:border="none"/>
  </style:style>
  <style:style style:name="ta1" style:family="table">
   <style:table-properties style:width="17cm" table:align="margins"/>
  </style:style>
  {cols}
  <style:style style:name="ce1" style:family="table-cell">
   <style:table-cell-properties fo:padding="0.1cm" fo:border="0.05pt solid #808080"/>
  </style:style>
  <style:style style:name="Pbreak" style:family="paragraph" style:parent-style-name="Heading_20_1">
   <style:paragraph-properties fo:break-before="page"/>
  </style:style>
 </office:automatic-styles>
 <office:body>
  <office:text>
{body}
  </office:text>
 </office:body>
</office:document-content>
""".replace("__IMG_H__", f"{img_h:.3f}")


def manifest_xml(pictures):
    entries = "".join(
        f'  <manifest:file-entry manifest:full-path="Pictures/{name}" '
        f'manifest:media-type="image/png"/>\n' for name in pictures
    )
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0" manifest:version="1.3">
  <manifest:file-entry manifest:full-path="/" manifest:media-type="application/vnd.oasis.opendocument.text"/>
  <manifest:file-entry manifest:full-path="content.xml" manifest:media-type="text/xml"/>
  <manifest:file-entry manifest:full-path="styles.xml" manifest:media-type="text/xml"/>
  <manifest:file-entry manifest:full-path="meta.xml" manifest:media-type="text/xml"/>
{entries}</manifest:manifest>
"""


META_XML = f"""<?xml version="1.0" encoding="UTF-8"?>
<office:document-meta {NS} office:version="1.3">
 <office:meta>
  <dc:title>Parrot Field Report</dc:title>
  <dc:creator>Parrot benchmark</dc:creator>
  <meta:creation-date>2026-01-01T00:00:00</meta:creation-date>
  <dc:date>2026-01-01T00:00:00</dc:date>
 </office:meta>
</office:document-meta>
"""


# --------------------------------------------------------------------------
# Assembly
# --------------------------------------------------------------------------

def build_body(rng, img_h):
    """Return (xml, picture_files, plain_text)."""
    out, pics, plain = [], [], []

    def para(style, text):
        out.append(f'   <text:p text:style-name="{style}">{esc(text)}</text:p>')
        plain.append(text)

    def head(level, text, page_break=False):
        style = "Pbreak" if page_break else f"Heading_20_{level}"
        out.append(
            f'   <text:h text:style-name="{style}" '
            f'text:outline-level="{level}">{esc(text)}</text:h>'
        )
        plain.append(text)

    para("Title", "Parrot Field Report")
    para("Subtitle", "Annual review of the Windvane catchment installations")

    # Decide up front which body paragraphs carry the anchor, so the count is
    # exact rather than probabilistic.
    total_paras = CHAPTERS * SECTIONS_PER_CHAPTER * PARAGRAPHS
    step = total_paras / ANCHOR_COUNT
    anchor_at = {int(i * step) for i in range(ANCHOR_COUNT)}
    assert len(anchor_at) == ANCHOR_COUNT, "anchor slots collided"

    n = 0
    for c in range(CHAPTERS):
        head(1, f"{ORDINALS[c].capitalize()} Chapter. {CHAPTER_TITLES[c]}",
             page_break=True)

        for s in range(SECTIONS_PER_CHAPTER):
            head(2, f"{SECTION_TITLES[s]}")

            for _ in range(PARAGRAPHS):
                text = paragraph(rng)
                if n in anchor_at:
                    text += " " + sentence(rng, rng.choice(ANCHOR_TEMPLATES))
                para("Text_20_body", text)
                n += 1

            # One figure per chapter, after the first section.
            if s == 0:
                idx = len(pics)
                name = f"img{idx+1:02d}.png"
                buf = io.BytesIO()
                make_image(rng, idx).save(buf, format="PNG", optimize=False)
                pics.append((name, buf.getvalue()))
                out.append(
                    f'   <text:p text:style-name="Figure">'
                    f'<draw:frame draw:style-name="fr1" draw:name="Image{idx+1}" '
                    f'text:anchor-type="as-char" svg:width="{IMAGE_WIDTH_CM}cm" '
                    f'svg:height="{img_h:.3f}cm" draw:z-index="{idx}">'
                    f'<draw:image xlink:href="Pictures/{name}" xlink:type="simple" '
                    f'xlink:show="embed" xlink:actuate="onLoad"/>'
                    f'</draw:frame></text:p>'
                )
                cap = (f"Figure {idx+1}. Monthly readings recorded at the "
                       f"{rng.choice(NOUNS)} during the {ORDINALS[c]} period.")
                para("Caption", cap)

            # Three tables, in the chapters named above.
            if s == 1 and (c + 1) in TABLE_CHAPTERS:
                t = TABLE_CHAPTERS.index(c + 1) + 1
                rows = [f'   <table:table table:name="Table{t}" table:style-name="ta1">']
                for i in range(TABLE_COLS):
                    rows.append(f'    <table:table-column table:style-name="co{i+1}"/>')
                for r in range(TABLE_ROWS):
                    rows.append("    <table:table-row>")
                    for col in range(TABLE_COLS):
                        if r == 0:
                            val, sty = TABLE_HEADERS[col], "Table_20_Heading"
                        elif col == 0:
                            val, sty = f"Item {r}", "Table_20_Contents"
                        elif col == 1:
                            val, sty = rng.choice(NOUNS).capitalize(), "Table_20_Contents"
                        elif col == 2:
                            val, sty = f"{rng.randint(10, 99)}", "Table_20_Contents"
                        else:
                            val, sty = rng.choice(TABLE_STATUS), "Table_20_Contents"
                        rows.append(
                            f'     <table:table-cell table:style-name="ce1" '
                            f'office:value-type="string">'
                            f'<text:p text:style-name="{sty}">{esc(val)}</text:p>'
                            f'</table:table-cell>'
                        )
                        plain.append(val)
                    rows.append("    </table:table-row>")
                rows.append("   </table:table>")
                out.extend(rows)
                para("Caption", f"Table {t}. Summary of the readings above.")

    return "\n".join(out), pics, "\n".join(plain)


def write_odt(path, body, pics):
    with zipfile.ZipFile(path, "w") as z:
        # The mimetype entry must come first and be stored, not deflated.
        zi = zipfile.ZipInfo("mimetype", FIXED_TIMESTAMP)
        zi.compress_type = zipfile.ZIP_STORED
        z.writestr(zi, b"application/vnd.oasis.opendocument.text")

        def add(name, data, level=6):
            zi = zipfile.ZipInfo(name, FIXED_TIMESTAMP)
            zi.compress_type = zipfile.ZIP_DEFLATED
            zi.external_attr = 0o644 << 16
            z.writestr(zi, data, compresslevel=level)

        add("styles.xml", styles_xml())
        add("content.xml", content_xml(body))
        add("meta.xml", META_XML)
        add("META-INF/manifest.xml", manifest_xml([n for n, _ in pics]))
        for name, data in pics:
            # PNG is already compressed; storing it keeps the zip honest.
            zi = zipfile.ZipInfo(f"Pictures/{name}", FIXED_TIMESTAMP)
            zi.compress_type = zipfile.ZIP_STORED
            z.writestr(zi, data)


def check(path):
    """Assert the anchors in a built document."""
    with zipfile.ZipFile(path) as z:
        content = z.read("content.xml").decode()
        pics = [n for n in z.namelist() if n.startswith("Pictures/")]
    ok = True
    found = content.count(ANCHOR)
    if found != ANCHOR_COUNT:
        print(f"FAIL {ANCHOR}: {found} occurrences, expected {ANCHOR_COUNT}")
        ok = False
    else:
        print(f"ok   {ANCHOR}: {found} occurrences")
    other = content.count(ANCHOR_REPLACEMENT)
    if other:
        print(f"FAIL {ANCHOR_REPLACEMENT}: {other} occurrences, expected 0")
        ok = False
    else:
        print(f"ok   {ANCHOR_REPLACEMENT}: absent")
    if len(pics) != IMAGES:
        print(f"FAIL images: {len(pics)}, expected {IMAGES}")
        ok = False
    else:
        print(f"ok   images: {len(pics)}")
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-o", "--output", default=None)
    ap.add_argument("--check", action="store_true",
                    help="only verify the anchors of an existing file")
    args = ap.parse_args()

    out = Path(args.output or Path(__file__).parent / "parrot-report.odt")

    if args.check:
        sys.exit(0 if check(out) else 1)

    rng = random.Random(SEED)
    img_h = IMAGE_WIDTH_CM * IMAGE_PX[1] / IMAGE_PX[0]
    body, pics, plain = build_body(rng, img_h)
    write_odt(out, body, pics)

    words = len(plain.split())
    size = out.stat().st_size
    print(f"[doc] {out.name}: {size/1024/1024:.1f} MiB, {words} words, "
          f"{len(pics)} images, {TABLES} tables")

    # The figure the scenario inserts from disk during the run. Same generator,
    # its own seed, so it is visibly not one of the twelve already in the file.
    shot = out.parent / "parrot.png"
    make_image(random.Random(SEED + 1), 3).save(shot, format="PNG")
    print(f"[doc] {shot.name}: {shot.stat().st_size/1024:.0f} KiB")

    check(out)


if __name__ == "__main__":
    main()
