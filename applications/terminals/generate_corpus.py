#!/usr/bin/env python3
"""Generate the terminal-emulator benchmark corpus, deterministically.

    ./generate_corpus.py            write corpus/ (default)
    ./generate_corpus.py --check    re-read what is on disk and assert its shape
    ./generate_corpus.py --expected print the values check-result.sh should see

Everything here is fixed by a seed and nothing is read from the clock, the
network or the environment, so two runs on two machines produce byte-identical
files. The whole point of the group is that every emulator is handed exactly the
same stream of bytes.

WHAT IS DELIBERATELY ABSENT
---------------------------
* SGR 5 (blink). A blinking cell is not identical to itself between the capture
  and the replay, so it would fail every checkpoint after it.
* Colour emoji. The one Unicode class the entrants genuinely disagree on - some
  have no colour glyphs at all and the rest disagree about the cell width.
* Anything derived from the clock, the hostname, the working directory or the
  terminal size. All four vary between a recording and a replay.
* Progress driven by elapsed time. `redraw.sh` counts iterations instead.
"""

import argparse
import hashlib
import os
import random
import stat
import sys
from pathlib import Path

SEED = 20260813
ROOT = Path(__file__).resolve().parent
CORPUS = ROOT / "corpus"

PLAIN_LINES = 5000
LONG_LINES = 200
LONG_WIDTH = 620          # several times any plausible window width
REDRAW_ROWS = 20
TREE_DIRS = 40
TREE_FILES_PER_DIR = 25

# How many times each block replays its content, and the single most important
# set of numbers in this file.
#
# THE MEASUREMENT THAT FORCED THIS. Every block was timed inside xterm at one
# pass, from the shell, on a 159x47 window:
#
#     plain (5,000 lines)      13 ms      longlines               6 ms
#     attributes                3 ms      seq (200,000 lines)   151 ms
#     colours-256             183 ms      ls-tree (1,000 files)   7 ms
#     colours-true            172 ms      redraw (200x20)      4,596 ms
#     unicode                   3 ms      boxes                   3 ms
#
# Nine of the ten together came to about half a second and ONE block was 90% of
# the session. A corpus like that cannot tell seven emulators apart: the run is
# almost entirely idle, and the differences vanish into the measurement noise.
#
# The reason `cat`-ing 5,000 lines costs 13 ms is worth understanding, because it
# is the whole design constraint here: an emulator does not have to paint a frame
# it can prove is about to be overwritten, so a fast scroll is optimised away
# almost entirely. Only `redraw.sh`, which addresses the cursor and repaints in
# place, forces the emulator to actually draw every frame - which is exactly why
# it was three orders of magnitude more expensive than everything else.
#
# So the counts below bring each block to roughly 1.5 s of writer time, from the
# measured cost of one pass. That leaves no block dominating, and it keeps the
# thing that DOES differ between emulators - how much of a fast scroll each one
# manages to skip - as a measurable quantity rather than a rounding error.
#
# Repetition rather than bigger files, deliberately: the committed corpus stays
# at half a megabyte instead of growing to forty, the bytes are identical on
# every pass, and the count is one number to re-tune when the hardware changes.
# These are the second pass. The first set was derived from the one-pass costs
# above and came back 235 ms - 1,452 ms; `attributes` was six times light because
# bash's printf BUILTIN is far cheaper than the 20 us/line the first measurement
# implied once the emulator is no longer the bottleneck. Re-tuned from the
# measured scaled numbers, which is the only way to get this right - the cost per
# repetition is not linear in what the block writes.
REPEATS = {
    "plain": 135,           # 135 x 5,000   =  675,000 lines
    "attributes": 30000,    # 30,000 x 12   =  360,000 lines
    "colours-256": 100,     # 100 x 16 rows of 16 background blocks
    "colours-true": 9,      # 9 x 48 bands of 240 distinct colours
    "unicode": 1000,
    "boxes": 1050,
    "redraw": 65,           # 65 x 20 rows repainted IN PLACE - the expensive one
    "longlines": 375,
    "ls-tree": 325,
}
SEQ_TO = 2_000_000          # was 200,000, which cost 151 ms

# The pager search in block 13 looks for this. It has to appear often enough to
# have somewhere to jump to and be absent from every other corpus file, so that
# a search that silently matched something else is visible as a wrong screen.
ANCHOR = "beacon"
ANCHOR_COUNT = 120

LOG = "/tmp/parrot-term.log"

# The block numbers, defined once. Line N of script.md is `BLOCK N` in the
# session log, and verify.sh asserts exactly these, so every generated script
# and every assertion reads them from this one table rather than repeating a
# literal that can drift out of step with the script.
#
# THE SCROLLBACK BLOCKS ARE GONE, and that is why these numbers are not the
# obvious ones. The script used to open with "print a file / scroll back / scroll
# to the end", and it could not survive contact with the entrants:
#
#   Shift+Page Up scrolls in 2 of the 7   (xterm, GNOME Terminal)
#   the mouse wheel scrolls in 4 of the 7 (xterm, GNOME Terminal, alacritty, kitty)
#
# There is no scrollback gesture the seven share. In st, Shift+Page Up is not a
# binding at all - the key is passed to the application as `ESC[5;2~`, readline
# swallows the `ESC[`, and `2~` is left sitting on the command line; twenty
# presses left `2~2~2~...` on the prompt and the NEXT block's command was
# appended to that junk and never ran. Konsole scrolls but does not come back to
# the same screen. So the two blocks were removed rather than given a per-app
# keybinding, because a block driven by a different gesture in each application
# compares the gestures rather than the emulators.
BLOCK = {
    "plain":         2,
    "attributes":    3,
    "colours-256":   4,
    "colours-true":  5,
    "unicode":       6,
    "boxes":         7,
    "redraw":        8,
    "longlines":     9,
    "seq":          10,
    "ls-tree":      11,
}
# Block 14 leaves the mouse selection. It has no command behind it, so it is
# checked through the X PRIMARY selection instead of through the log.
SELECTION_BLOCK = 14

WORDS = (
    "relay station cavern lantern harbour thicket meridian quarry bramble "
    "furlong cistern tundra galley pylon marsh cobble fathom heather ridge "
    "kestrel alder yarrow bracken conduit spindle warren cove tarn"
).split()


def log_line(block, name):
    """Every block ends by appending one line to the session log.

    This is the whole of the ground truth for this group: a terminal emulator
    writes no document, so without a log the only evidence a block ran is a
    screenshot - and a screenshot of a terminal whose output has scrolled past
    looks exactly like a screenshot of a terminal that printed nothing.
    """
    return f'printf "BLOCK %s %s\\n" {block:02d} {name} >> {LOG}\n'


def sh(body):
    return "#!/bin/bash\n# Generated by generate_corpus.py - do not edit.\nset -u\n" + body


def write(path, text, executable=False):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    if executable:
        path.chmod(path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


# --------------------------------------------------------------------------
# the content files
# --------------------------------------------------------------------------

def make_plain(rng):
    """5,000 lines of plain ASCII: the throughput case, and what the pager pages.

    ANCHOR appears exactly ANCHOR_COUNT times, spread evenly, so block 15's
    search has a known number of matches at known distances.
    """
    anchor_rows = {int(i * PLAIN_LINES / ANCHOR_COUNT) + 3 for i in range(ANCHOR_COUNT)}
    lines = []
    for i in range(1, PLAIN_LINES + 1):
        words = " ".join(rng.choice(WORDS) for _ in range(9))
        if i in anchor_rows:
            words = f"{words} {ANCHOR}"
        lines.append(f"{i:05d}  {words}")
    return "\n".join(lines) + "\n"


def make_longlines(rng):
    """Lines several times wider than the window - the wrapping case."""
    out = []
    for i in range(1, LONG_LINES + 1):
        body = " ".join(rng.choice(WORDS) for _ in range(120))
        out.append(f"{i:04d} " + body[:LONG_WIDTH])
    return "\n".join(out) + "\n"


def make_unicode():
    """Scripts every entrant can draw. No colour emoji - see the module note.

    Includes double-width CJK and combining marks on purpose: the cell-width
    rules are where emulators disagree even when the glyphs are all present.
    """
    rows = [
        "Latin      Ærøskøbing naïve façade jalapeño Straße ǅevojka ﬁnesse",
        "Diacritics a\u0301 e\u0308 i\u0302 o\u0303 u\u0304 n\u0303 c\u0327 z\u030c  (combining marks)",
        "Greek      Ζεύς ἀνήρ φιλοσοφία ὕδωρ πνεῦμα Ωμέγα",
        "Cyrillic   Здравствуйте, мир. Ёжик в тумане. Щёлкать",
        "Hebrew     שלום עולם  (right-to-left)",
        "CJK        日本語のテキスト 中文文本 한국어 텍스트  (double width)",
        "Kana       あいうえお カキクケコ ｱｲｳｴｵ  (full and half width)",
        "Symbols    † ‡ § ¶ ‰ № ℮ ⅓ ½ ¾ × ÷ ± ∞ ≠ ≤ ≥ √ ∑ ∏ ∫",
        "Arrows     ← ↑ → ↓ ↔ ↕ ⇐ ⇒ ⇔ ↰ ↱ ⟵ ⟶",
        "Blocks     ░ ▒ ▓ █ ▁ ▂ ▃ ▄ ▅ ▆ ▇ ▉ ▊ ▋ ▌ ▍ ▎ ▏",
        "Braille    ⠁⠃⠉⠙⠑⠋⠛⠓⠊⠚⠅⠇⠍⠝⠕⠏⠟⠗⠎⠞⠥⠧⠺⠭⠽⠵",
    ]
    return "\n".join(rows * 12) + "\n"


def make_boxes():
    """A drawn table - box-drawing glyphs, the other classic width trap."""
    head = "┌" + "┬".join("─" * 14 for _ in range(5)) + "┐"
    mid = "├" + "┼".join("─" * 14 for _ in range(5)) + "┤"
    foot = "└" + "┴".join("─" * 14 for _ in range(5)) + "┘"
    rows = [head]
    for i in range(1, 31):
        cells = "│".join(f" {('cell %d.%d' % (i, c)):<13}" for c in range(1, 6))
        rows.append("│" + cells + "│")
        rows.append(mid if i < 30 else foot)
    double = "╔" + "╦".join("═" * 14 for _ in range(5)) + "╗"
    rows.append(double)
    rows.append("╚" + "╩".join("═" * 14 for _ in range(5)) + "╝")
    return "\n".join(rows) + "\n"


def make_tree(rng):
    """A directory tree for `ls --color=always -R`.

    The extensions are the point: LS_COLORS gives each a different SGR sequence,
    so this is colour interleaved with a real program's output rather than a
    synthetic block of escapes. Names are zero-padded so the sort order is the
    same on every machine regardless of locale collation.
    """
    files = {}
    exts = [".txt", ".sh", ".tar.gz", ".png", ".log", ".py", ".zip", ".md"]
    for d in range(TREE_DIRS):
        for f in range(TREE_FILES_PER_DIR):
            ext = exts[(d * TREE_FILES_PER_DIR + f) % len(exts)]
            name = f"dir{d:03d}/file{f:03d}{ext}"
            files[name] = f"{rng.choice(WORDS)}\n"
    return files


def make_attributes():
    """SGR attribute samples. NOTE: no SGR 5 (blink) - see the module note."""
    body = 'printf "\\n  Text attributes\\n\\n"\n'
    samples = [
        ("1", "bold"), ("2", "dim"), ("3", "italic"), ("4", "underline"),
        ("7", "reverse"), ("9", "strikethrough"), ("21", "double underline"),
        ("53", "overline"), ("1;4", "bold underline"), ("1;7", "bold reverse"),
        ("4;3", "italic underline"), ("2;3", "dim italic"),
    ]
    # The samples are emitted once and repeated by the shell, rather than
    # unrolled REPEATS times into the file: the script stays readable at a
    # glance, and the repeat count is one number to change.
    body += f'for _ in $(seq 1 {REPEATS["attributes"]}); do\n'
    for code, label in samples:
        body += f'  printf "  \\033[{code}m%-22s\\033[0m  {code}\\n" "{label}"\n'
    body += "done\n"
    body += log_line(BLOCK["attributes"], "attributes")
    return sh(body)


def make_colours_256():
    """The 16x16 indexed palette, drawn as background blocks."""
    body = 'printf "\\n  256 colours\\n\\n"\n'
    body += (
        f"for _ in $(seq 1 {REPEATS['colours-256']}); do\n"
        "  for row in $(seq 0 15); do\n"
        "    for col in $(seq 0 15); do\n"
        "      n=$((row * 16 + col))\n"
        '      printf "\\033[48;5;%dm  \\033[0m" "$n"\n'
        "    done\n"
        '    printf "\\n"\n'
        "  done\n"
        '  printf "\\n"\n'
        "done\n"
    )
    body += log_line(BLOCK["colours-256"], "colours-256")
    return sh(body)


def make_colours_true():
    """A 24-bit gradient. 240 columns of distinct colour per row, 48 rows."""
    body = 'printf "\\n  True colour\\n\\n"\n'
    body += (
        f"for _ in $(seq 1 {REPEATS['colours-true']}); do\n"
        "  for band in $(seq 0 47); do\n"
        "    for x in $(seq 0 239); do\n"
        "      r=$(( (x * 255) / 239 ))\n"
        "      g=$(( (band * 255) / 47 ))\n"
        "      b=$(( 255 - r ))\n"
        '      printf "\\033[48;2;%d;%d;%dm \\033[0m" "$r" "$g" "$b"\n'
        "    done\n"
        '    printf "\\n"\n'
        "  done\n"
        "done\n"
    )
    body += log_line(BLOCK["colours-true"], "colours-true")
    return sh(body)


def make_redraw():
    """Repaint REDRAW_ROWS lines in place, REPEATS['redraw'] times.

    This is the one block that does NOT scroll: it uses absolute cursor
    addressing, which is the path a TUI takes and a completely different code
    path in the emulator from appending lines at the bottom. It counts
    iterations rather than seconds so the work is identical on a fast machine
    and a slow one.

    It is also, by a wide margin, the most expensive thing per byte in the
    corpus - 23 ms per iteration against 2.6 microseconds per line of plain
    scrolling - because an in-place repaint is the one case the emulator cannot
    skip a frame of. Its iteration count went DOWN when the others went up: at
    200 iterations it was 90% of the whole session.
    """
    body = (
        'printf "\\033[2J"\n'
        f"for i in $(seq 1 {REPEATS['redraw']}); do\n"
        f"  for row in $(seq 1 {REDRAW_ROWS}); do\n"
        '    bar=$(printf "%0.s#" $(seq 1 $(( (i % 40) + 1 ))))\n'
        '    printf "\\033[%d;1H\\033[K  row %02d   iteration %03d   %s" '
        '"$row" "$row" "$i" "$bar"\n'
        "  done\n"
        "done\n"
        f'printf "\\033[{REDRAW_ROWS + 2};1H\\n"\n'
    )
    body += log_line(BLOCK["redraw"], "redraw")
    return sh(body)


def repeated(command, times):
    """Wrap a command in a shell repeat loop, or return it bare for one pass."""
    if times <= 1:
        return f"{command}\n"
    return f"for _ in $(seq 1 {times}); do\n  {command}\ndone\n"


def make_verify():
    """The ground truth. Re-reads the session log and the artefacts.

    Prints one `ok`/`FAIL` line per assertion and a final RESULT line, in the
    same shape as the spreadsheet group's check-result.sh, so the same habits
    apply: judge a run by RESULT, not by how the screen looked.
    """
    wanted = sorted(((n, name) for name, n in BLOCK.items()))
    body = f'LOG={LOG}\nfail=0\n'
    body += 'if [ ! -f "$LOG" ]; then echo "  FAIL no session log at $LOG"; echo "RESULT FAIL"; exit 1; fi\n'
    for num, name in wanted:
        body += (
            f'if grep -qx "BLOCK {num:02d} {name}" "$LOG"; then echo "  ok   block {num:02d} {name} ran";'
            f' else echo "  FAIL block {num:02d} {name} left no log line"; fail=1; fi\n'
        )
    # The mouse selection is the one block with no command behind it. X keeps it.
    body += (
        f'sel="$(xclip -o -selection primary 2>/dev/null | tr -d "\\n" | head -c 200)"\n'
        f'if [ -n "$sel" ]; then echo "  ok   block {SELECTION_BLOCK:02d} left a PRIMARY selection (${{#sel}} chars)";'
        f' else echo "  FAIL block {SELECTION_BLOCK:02d} left no PRIMARY selection"; fail=1; fi\n'
    )
    body += (
        f'n=$(grep -c "^BLOCK " "$LOG")\n'
        f'if [ "$n" -eq {len(wanted)} ]; then echo "  ok   {len(wanted)} command blocks logged";'
        f' else echo "  FAIL $n command blocks logged (want {len(wanted)})"; fail=1; fi\n'
    )
    body += 'if [ "$fail" -eq 0 ]; then echo "RESULT PASS"; else echo "RESULT FAIL"; fi\n'
    return sh(body)


def make_runner(block, name, command):
    """A thin wrapper: do the thing REPEATS[name] times, then log that it happened.

    The log line is written once, after the whole loop, not once per pass - the
    ground truth asserts an exact count of BLOCK lines and one per repetition
    would turn a working run into `600001 command blocks logged (want 10)`.
    """
    return sh(repeated(command, REPEATS.get(name, 1)) + log_line(block, name))


# --------------------------------------------------------------------------

def build():
    rng = random.Random(SEED)
    if CORPUS.exists():
        for p in sorted(CORPUS.rglob("*"), reverse=True):
            if p.is_file():
                p.unlink()
            else:
                p.rmdir()
    CORPUS.mkdir(parents=True, exist_ok=True)

    write(CORPUS / "plain.txt", make_plain(rng))
    write(CORPUS / "longlines.txt", make_longlines(rng))
    write(CORPUS / "unicode.txt", make_unicode())
    write(CORPUS / "boxes.txt", make_boxes())
    for name, text in make_tree(rng).items():
        write(CORPUS / "tree" / name, text)

    write(CORPUS / "attributes.sh", make_attributes(), executable=True)
    write(CORPUS / "colours-256.sh", make_colours_256(), executable=True)
    write(CORPUS / "colours-true.sh", make_colours_true(), executable=True)
    write(CORPUS / "redraw.sh", make_redraw(), executable=True)
    write(CORPUS / "verify.sh", make_verify(), executable=True)

    here = "$(dirname \"$0\")"
    write(CORPUS / "plain.sh", make_runner(BLOCK["plain"], "plain", f'cat {here}/plain.txt'), True)
    write(CORPUS / "unicode.sh", make_runner(BLOCK["unicode"], "unicode", f'cat {here}/unicode.txt'), True)
    write(CORPUS / "boxes.sh", make_runner(BLOCK["boxes"], "boxes", f'cat {here}/boxes.txt'), True)
    write(CORPUS / "longlines.sh", make_runner(BLOCK["longlines"], "longlines", f'cat {here}/longlines.txt'), True)
    write(CORPUS / "seq.sh", make_runner(BLOCK["seq"], "seq", f"seq 1 {SEQ_TO}"), True)
    write(CORPUS / "ls-tree.sh",
          make_runner(BLOCK["ls-tree"], "ls-tree", f'ls --color=always -R {here}/tree'), True)

    files = sorted(p for p in CORPUS.rglob("*") if p.is_file())
    total = sum(p.stat().st_size for p in files)
    digest = hashlib.sha256()
    for p in files:
        digest.update(p.relative_to(CORPUS).as_posix().encode())
        digest.update(p.read_bytes())
    print(f"wrote {len(files)} files, {total / 1024:.1f} KiB")
    print(f"corpus sha256 {digest.hexdigest()}")


def report(ok, text):
    print(("  ok   " if ok else "  FAIL ") + text)
    return ok


def check():
    good = True
    plain = (CORPUS / "plain.txt").read_text(encoding="utf-8")
    good &= report(plain.count("\n") == PLAIN_LINES, f"plain.txt has {PLAIN_LINES} lines")
    good &= report(plain.count(ANCHOR) == ANCHOR_COUNT,
                   f"'{ANCHOR}' appears {ANCHOR_COUNT} times - what block 15 searches for")

    others = [p for p in CORPUS.rglob("*") if p.is_file() and p.name != "plain.txt"]
    stray = [p.name for p in others
             if ANCHOR in p.read_text(encoding="utf-8", errors="replace")]
    good &= report(not stray, f"'{ANCHOR}' appears in no other corpus file ({len(stray)} do)")

    # SGR 5 anywhere in the corpus would make the screen change by itself.
    blink = []
    for p in CORPUS.rglob("*"):
        if not p.is_file():
            continue
        t = p.read_text(encoding="utf-8", errors="replace")
        if "[5m" in t or ";5m" in t:
            blink.append(p.name)
    good &= report(not blink, f"no SGR 5 (blink) anywhere in the corpus ({len(blink)} files have it)")

    uni = (CORPUS / "unicode.txt").read_text(encoding="utf-8")
    emoji = [c for c in uni if ord(c) >= 0x1F000]
    good &= report(not emoji, f"no colour emoji in unicode.txt ({len(emoji)} found)")
    good &= report("日本語" in uni, "unicode.txt carries double-width CJK")
    good &= report("\u0301" in uni, "unicode.txt carries combining marks")

    tree = list((CORPUS / "tree").rglob("*"))
    good &= report(len([p for p in tree if p.is_file()]) == TREE_DIRS * TREE_FILES_PER_DIR,
                   f"tree has {TREE_DIRS * TREE_FILES_PER_DIR} files")

    for name in ("attributes.sh", "colours-256.sh", "colours-true.sh", "redraw.sh",
                 "verify.sh", "plain.sh", "unicode.sh", "boxes.sh", "longlines.sh",
                 "seq.sh", "ls-tree.sh"):
        p = CORPUS / name
        good &= report(p.exists() and os.access(p, os.X_OK), f"{name} exists and is executable")

    # Every block has to carry its repeat count into the script it generates. A
    # block that quietly reverted to one pass is the failure this whole section
    # exists to prevent: it costs milliseconds, so it contributes nothing to the
    # comparison, and NOTHING else about the run looks wrong - the screenshots
    # match, the log line is there, the ground truth passes.
    for name, times in REPEATS.items():
        if name == "redraw":
            script, needle = "redraw.sh", f"seq 1 {times}"
        else:
            script, needle = f"{name}.sh", f"seq 1 {times}"
        text = (CORPUS / script).read_text(encoding="utf-8")
        good &= report(needle in text, f"{script} repeats its content {times}x")

    good &= report(f"seq 1 {SEQ_TO}" in (CORPUS / "seq.sh").read_text(encoding="utf-8"),
                   f"seq.sh counts to {SEQ_TO}")

    # One log line per block, not one per repetition - the ground truth asserts
    # an exact count and a log line inside the loop would break it.
    for script in ("plain.sh", "unicode.sh", "boxes.sh", "longlines.sh",
                   "ls-tree.sh", "attributes.sh"):
        text = (CORPUS / script).read_text(encoding="utf-8")
        good &= report(text.count(LOG) == 1, f"{script} logs exactly once, outside its loop")

    print("RESULT PASS" if good else "RESULT FAIL")
    return 0 if good else 1


def expected():
    print(f"plain.txt lines        {PLAIN_LINES}")
    print(f"'{ANCHOR}' occurrences   {ANCHOR_COUNT}   (block 15 searches for this)")
    print(f"tree files             {TREE_DIRS * TREE_FILES_PER_DIR}")
    print(f"redraw repaints        {REPEATS['redraw']} x {REDRAW_ROWS} rows, in place")
    print(f"seq counts to          {SEQ_TO}")
    print(f"session log            {LOG}")
    print("command blocks logged  10   (blocks 2, 5, 6, 7, 8, 9, 10, 11, 12, 13)")
    print()
    print("repeat counts, tuned so no single block dominates the session:")
    for name, n in REPEATS.items():
        print(f"  {name:<14} x{n}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true", help="verify what is on disk")
    ap.add_argument("--expected", action="store_true", help="print the expected values")
    args = ap.parse_args()
    if args.check:
        sys.exit(check())
    if args.expected:
        expected()
    else:
        build()
