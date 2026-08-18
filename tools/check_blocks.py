#!/usr/bin/env python3
"""Cross-check the per-block structure of every .parrot file under a folder.

A "block" is a sequence of action lines that ends with a `log <message>` line
(and the `check <ref>` line that follows it). The log message is the block's
identity, and every parrot file in the folder is expected to define the same
ordered set of blocks (because they implement the same script).

The script always prints a table of total `wait` time per block per file. It
can additionally:

  --split           write each block to <parrot-folder>/blocks/NN-slug.parrot
  --normalize-time  write a sibling <name>-normalized.parrot in which every
                    block is padded (with a single extra `wait`) to the
                    longest duration that block has across all files
"""

from __future__ import annotations

import argparse
import sys
from collections import OrderedDict
from pathlib import Path

# helpers.py lives one level up in the repository, and next to this script inside
# the container image, so both locations are on the path.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from helpers import note_label  # noqa: E402  (needs the path set up above)

EVENT_VERBS = {
    "wait", "mousemove", "mousedown", "mouseup",
    "keydown", "keyup", "check", "log",
}


def find_parrot_files(root: Path) -> list[Path]:
    return sorted(p for p in root.rglob("*.parrot") if p.is_file())


def _first_word(line: str) -> str:
    stripped = line.strip()
    if not stripped:
        return ""
    return stripped.split(None, 1)[0].lower()


def _sum_waits(lines: list[str]) -> float:
    total = 0.0
    for line in lines:
        stripped = line.strip()
        if not stripped:
            continue
        parts = stripped.split()
        if parts[0].lower() == "wait" and len(parts) > 1:
            try:
                total += float(parts[1])
            except ValueError:
                pass
    return total


def parse_blocks(path: Path) -> tuple[list[str], list[dict]]:
    """Return (header_lines, blocks) for the given parrot file.

    Each block dict has:
        name        log message (text after `log `), or a placeholder
        lines       list of raw lines belonging to the block
        wait_total  sum of `wait X` values within the block
    """
    raw_lines = path.read_text(encoding="utf-8").splitlines()

    header: list[str] = []
    blocks: list[dict] = []
    cur_lines: list[str] = []
    cur_name: str | None = None
    in_header = True

    for line in raw_lines:
        verb = _first_word(line)

        if in_header:
            if verb in EVENT_VERBS:
                in_header = False
            else:
                header.append(line)
                continue

        cur_lines.append(line)

        if verb == "log":
            stripped = line.strip()
            parts = stripped.split(None, 1)
            cur_name = parts[1] if len(parts) > 1 else ""

        if verb == "check":
            if cur_name is None:
                cur_name = f"<unnamed block #{len(blocks) + 1}>"
            blocks.append({
                "name": cur_name,
                "lines": cur_lines,
                "wait_total": _sum_waits(cur_lines),
            })
            cur_lines = []
            cur_name = None

    if cur_lines:
        blocks.append({
            "name": cur_name or "<unnamed trailing block>",
            "lines": cur_lines,
            "wait_total": _sum_waits(cur_lines),
        })

    return header, blocks


def verify_same_blocks(parsed: "OrderedDict[Path, tuple[list[str], list[dict]]]") -> bool:
    """Print a report of block-name mismatches. Returns True if all match."""
    if not parsed:
        return True

    paths = list(parsed.keys())
    reference_path = paths[0]
    reference_names = [b["name"] for b in parsed[reference_path][1]]

    all_ok = True
    for path in paths[1:]:
        names = [b["name"] for b in parsed[path][1]]
        if names == reference_names:
            continue
        all_ok = False
        print(f"\n[mismatch] {path} differs from {reference_path}", file=sys.stderr)
        ref_set = set(reference_names)
        cur_set = set(names)
        for missing in [n for n in reference_names if n not in cur_set]:
            print(f"    missing: {missing}", file=sys.stderr)
        for extra in [n for n in names if n not in ref_set]:
            print(f"    extra:   {extra}", file=sys.stderr)
        if ref_set == cur_set and names != reference_names:
            print(f"    same blocks but different order", file=sys.stderr)

    return all_ok


def print_wait_table(parsed: "OrderedDict[Path, tuple[list[str], list[dict]]]", root: Path) -> None:
    if not parsed:
        print("No parrot files found.")
        return

    paths = list(parsed.keys())
    reference_blocks = parsed[paths[0]][1]
    block_names = [b["name"] for b in reference_blocks]

    file_labels = [p.relative_to(root).as_posix() if p.is_relative_to(root) else p.name
                   for p in paths]
    file_labels = [Path(label).stem for label in file_labels]

    name_col = max(5, min(60, max((len(n) for n in block_names), default=5)))
    col_widths = [max(8, len(label)) for label in file_labels]

    header_cells = [f"{label:>{w}}" for label, w in zip(file_labels, col_widths)]
    print(f"{'Block':<{name_col}}  " + "  ".join(header_cells))
    rule_len = name_col + 2 + sum(col_widths) + 2 * max(0, len(col_widths) - 1)
    print("-" * rule_len)

    for i, name in enumerate(block_names):
        cells = []
        for j, path in enumerate(paths):
            blocks = parsed[path][1]
            if i < len(blocks):
                cells.append(f"{blocks[i]['wait_total']:>{col_widths[j]}.3f}")
            else:
                cells.append(f"{'-':>{col_widths[j]}}")
        # Show the label, not the whole instruction: a script line may carry a
        # detailed instruction after a colon, which would make the table
        # unreadable.  Block identity above still compares the full message.
        short = note_label(name)
        display_name = short if len(short) <= name_col else short[: name_col - 1] + "…"
        print(f"{display_name:<{name_col}}  " + "  ".join(cells))

    print("-" * rule_len)
    total_cells = []
    for j, path in enumerate(paths):
        total = sum(b["wait_total"] for b in parsed[path][1])
        total_cells.append(f"{total:>{col_widths[j]}.3f}")
    print(f"{'Total':<{name_col}}  " + "  ".join(total_cells))


# A filename component may be at most 255 bytes on ext4, xfs and every other
# filesystem this is likely to meet.  Leave room for the "NN-" prefix and the
# ".parrot" suffix.
_SLUG_MAX = 200


def _slugify(name: str) -> str:
    """Build a filename component from a block name.

    Uses only the label - the part before the first colon - because a block name
    is a whole script line, and a script line is an instruction written for a
    human driving the application.  The code-editor scenario's longest is 300
    characters, which produced

        OSError: [Errno 36] File name too long

    from --split, after it had already written the seventeen shorter blocks.  A
    partial blocks/ directory that looks complete is worse than a clean failure,
    so the length is also capped rather than merely being unlikely to matter.
    """
    label, sep, _detail = name.partition(":")
    if sep and label.strip():
        name = label

    out: list[str] = []
    for ch in name:
        if ch.isalnum():
            out.append(ch.lower())
        elif ch in ("-", "_"):
            out.append(ch)
        elif ch.isspace():
            out.append("-")
    slug = "".join(out).strip("-_")
    while "--" in slug:
        slug = slug.replace("--", "-")
    return (slug[:_SLUG_MAX].rstrip("-_") or "block")


def split_blocks(path: Path, header: list[str], blocks: list[dict]) -> Path:
    """Write each block to <parrot-folder>/blocks/NN-slug.parrot.

    Each split file is a self-contained parrot file with the original header
    so it can be replayed on its own.
    """
    blocks_dir = path.parent / "blocks"
    blocks_dir.mkdir(exist_ok=True)
    for index, block in enumerate(blocks, start=1):
        slug = _slugify(block["name"])
        out_path = blocks_dir / f"{index:02d}-{slug}.parrot"
        body: list[str] = []
        body.extend(header)
        if header and header[-1].strip() != "":
            body.append("")
        body.extend(block["lines"])
        out_path.write_text("\n".join(body) + "\n", encoding="utf-8")
    return blocks_dir


def write_normalized(
    parsed: "OrderedDict[Path, tuple[list[str], list[dict]]]",
) -> list[Path]:
    """Write a -normalized.parrot next to each parrot file.

    For every block index, the target duration is the maximum wait_total seen
    across all files. The extra wait is inserted as a single `wait <padding>`
    line immediately before the block's `log` line so the action timing is not
    disturbed.
    """
    paths = list(parsed.keys())
    if not paths:
        return []

    block_counts = {len(parsed[p][1]) for p in paths}
    if len(block_counts) != 1:
        raise SystemExit(
            "Cannot normalize: parrot files have different numbers of blocks. "
            "Resolve the structural mismatch first."
        )
    n_blocks = block_counts.pop()

    max_per_block: list[float] = []
    for i in range(n_blocks):
        max_per_block.append(max(parsed[p][1][i]["wait_total"] for p in paths))

    written: list[Path] = []
    for path in paths:
        header, blocks = parsed[path]
        out_lines: list[str] = list(header)
        for i, block in enumerate(blocks):
            padding = max_per_block[i] - block["wait_total"]
            inserted = False
            for line in block["lines"]:
                if (
                    not inserted
                    and padding > 1e-6
                    and _first_word(line) == "log"
                ):
                    out_lines.append(f"wait {padding:.6f}")
                    inserted = True
                out_lines.append(line)
        out_path = path.with_name(f"{path.stem}-normalized.parrot")
        out_path.write_text("\n".join(out_lines) + "\n", encoding="utf-8")
        written.append(out_path)
    return written


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Verify that every .parrot file in a folder defines the same "
            "blocks (identified by their `log` message), print a wait-time "
            "table, and optionally split blocks or write time-normalized copies."
        )
    )
    parser.add_argument(
        "folder",
        type=Path,
        help="Folder to search recursively for .parrot files.",
    )
    parser.add_argument(
        "--split",
        action="store_true",
        help=(
            "Write each block as its own .parrot file under "
            "<parrot-folder>/blocks/."
        ),
    )
    parser.add_argument(
        "--normalize-time",
        action="store_true",
        help=(
            "Write <name>-normalized.parrot next to each input file in which "
            "every block is padded to the longest duration of that block "
            "across all files."
        ),
    )
    parser.add_argument(
        "--exclude-normalized",
        action="store_true",
        default=True,
        help="Skip files whose name ends with '-normalized.parrot' (on by default).",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)

    if not args.folder.is_dir():
        print(f"Not a directory: {args.folder}", file=sys.stderr)
        return 2

    files = find_parrot_files(args.folder)
    if args.exclude_normalized:
        files = [p for p in files if not p.name.endswith("-normalized.parrot")]
        files = [p for p in files if p.parent.name != "blocks"]

    if not files:
        print(f"No .parrot files found under {args.folder}", file=sys.stderr)
        return 1

    parsed: "OrderedDict[Path, tuple[list[str], list[dict]]]" = OrderedDict()
    for path in files:
        parsed[path] = parse_blocks(path)

    print(f"Found {len(files)} parrot file(s) under {args.folder}:")
    for p in files:
        header, blocks = parsed[p]
        print(f"  {p.relative_to(args.folder)}  ({len(blocks)} blocks)")
    print()

    all_match = verify_same_blocks(parsed)
    if all_match:
        print("All files define the same blocks in the same order.\n")
    else:
        print("\nBlock-structure mismatches detected (see above).\n", file=sys.stderr)

    print_wait_table(parsed, args.folder)

    if args.split:
        print("\nSplitting blocks into per-block parrot files...")
        for path in parsed:
            header, blocks = parsed[path]
            blocks_dir = split_blocks(path, header, blocks)
            print(f"  {path.name} -> {blocks_dir} ({len(blocks)} files)")

    if args.normalize_time:
        print("\nWriting time-normalized copies...")
        written = write_normalized(parsed)
        for out in written:
            print(f"  {out}")

    return 0 if all_match else 1


if __name__ == "__main__":
    raise SystemExit(main())
