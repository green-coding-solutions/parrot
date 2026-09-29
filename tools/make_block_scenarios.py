#!/usr/bin/env python3
"""Write a per-block copy of every time-normalized usage scenario.

usage_scenario_normalized.yml replays its whole recording in one flow step, so
GMT sees the session as one phase. The copy this writes next to it,
usage_scenario_blocks_normalized.yml, replays the same recording one block per
flow step with `replay.py --block N`, so every block of the group's script.md
becomes a phase of its own. Block 1 starts the app; every later block continues
the app the block before it left running.

Each flow step is named after its block's label - the text before the first
colon of the block's `log` line - so phase N has the same name in every app of
a group, which is what makes the phases comparable. GMT only accepts
`[.\\s0-9a-zA-Z_()-]` in a flow name, so markdown links are reduced to their
text, `%` becomes `percent`, `:` becomes `-` and anything else outside that set
is dropped.

Everything above `flow:` is copied from the source scenario, with ", per block"
added to `name:` and a sentence added to `description:`. Rerun the tool after
re-recording or re-normalizing; --check reports out-of-date copies and writes
nothing.

    ./tools/make_block_scenarios.py                       # every group
    ./tools/make_block_scenarios.py applications/videoplayers
    ./tools/make_block_scenarios.py --check
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# helpers.py and timed_xmacro.py live one level up in the repository, and next to
# this script inside the container image, so both locations are on the path.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from helpers import note_label  # noqa: E402  (needs the path set up above)
from timed_xmacro import read_replay_lines, split_blocks  # noqa: E402

REPO = Path(__file__).resolve().parent.parent
SOURCE_NAME = "usage_scenario_normalized.yml"
TARGET_NAME = "usage_scenario_blocks_normalized.yml"
CONTAINER_REPO = "/tmp/repo"

# The flow-name rule in green-metrics-tool's lib/schema_checker.py.
GMT_FLOW_NAME = re.compile(r"^[\.\s0-9a-zA-Z_\(\)-]+$")
YAML_KEYWORDS = {"y", "n", "yes", "no", "true", "false", "on", "off", "null"}

REPLAY_COMMAND = re.compile(
    r"^\s*command:\s*(python3 /usr/local/bin/replay\.py (/tmp/repo/\S+\.parrot))\s*$",
    re.MULTILINE,
)


class ScenarioError(Exception):
    """A source scenario or recording this tool cannot turn into blocks."""


def flow_name(log_text: str) -> str:
    """Return a GMT flow name for a block, from the text after `log `."""
    # The label ends at the first ": ", as script.md writes it ("* Label: detail").
    # note_label ends it at the first bare colon, which turns "Aspect ratio 4:3"
    # into "Aspect ratio 4"; everywhere else the two agree.
    label = log_text.split(": ", 1)[0] if ": " in log_text else note_label(log_text)
    label = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", label)   # [text](url) -> text
    label = label.replace("%", " percent").replace(":", "-")
    label = re.sub(r"[^.\s0-9a-zA-Z_()-]", "", label)
    return " ".join(label.split())


def yaml_scalar(name: str) -> str:
    """Write *name* bare when YAML reads it back as that string, quoted otherwise."""
    if re.fullmatch(r"[A-Za-z][\sA-Za-z0-9._()-]*", name) and name.lower() not in YAML_KEYWORDS:
        return name
    return f'"{name}"'


def block_names(recording: Path) -> list[str]:
    """Return one flow name per block of *recording*, in order."""
    names: list[str] = []
    for index, block in enumerate(split_blocks(read_replay_lines(recording)), start=1):
        logs = [line.split(None, 1) for line in block if line.split(None, 1)[0].lower() == "log"]
        logs = [parts[1] for parts in logs if len(parts) > 1]
        if not logs:
            raise ScenarioError(f"{recording}: block {index} has no `log` line to name it by")
        name = flow_name(logs[-1])
        if not name or not GMT_FLOW_NAME.match(name):
            raise ScenarioError(f"{recording}: block {index} gives no usable flow name ({logs[-1]!r})")
        names.append(name)
    duplicates = sorted({name for name in names if names.count(name) > 1})
    if duplicates:
        raise ScenarioError(f"{recording}: GMT flow names must be unique, repeated: {duplicates}")
    return names


def _rewrite_header_line(head: str, key: str, rewrite) -> str:
    pattern = re.compile(rf"^{key}:[ \t]*(.*)$", re.MULTILINE)
    matches = pattern.findall(head)
    if len(matches) != 1 or matches[0][:1] in ("'", '"', "|", ">"):
        raise ScenarioError(f"expected exactly one plain `{key}:` line, found {matches!r}")
    return pattern.sub(lambda m: f"{key}: {rewrite(m.group(1))}", head, count=1)


def render(source: Path) -> tuple[str, list[str]]:
    """Return (text of the blocks scenario, its flow names) for *source*."""
    text = source.read_text(encoding="utf-8")
    flow_at = re.search(r"^flow:[ \t]*$", text, re.MULTILINE)
    if flow_at is None:
        raise ScenarioError(f"{source}: no top-level `flow:`")
    head, flow = text[:flow_at.start()], text[flow_at.start():]

    # Only the shape every normalized scenario has is understood: one step,
    # one replay command. Anything else would be dropped silently.
    steps = re.findall(r"^  - name:", flow, re.MULTILINE)
    commands = REPLAY_COMMAND.findall(flow)
    containers = re.findall(r"^    container:\s*(\S+)\s*$", flow, re.MULTILINE)
    if len(steps) != 1 or len(commands) != 1 or len(containers) != 1:
        raise ScenarioError(
            f"{source}: expected one flow step with one replay.py command, found "
            f"{len(steps)} steps and {len(commands)} replay commands"
        )
    command, container_path = commands[0]
    container = containers[0]
    read_notes = re.search(r"^\s*read-notes-stdout:\s*true\s*$", flow, re.MULTILINE) is not None
    recording = REPO / Path(container_path).relative_to(CONTAINER_REPO)
    names = block_names(recording)

    try:
        head = _rewrite_header_line(
            head, "name",
            lambda v: f"{v[:-1]}, per block)" if v.endswith(")") else f"{v} (per block)",
        )
        head = _rewrite_header_line(
            head, "description",
            lambda v: f"{v}. Every block is its own flow step",
        )
    except ScenarioError as exc:
        raise ScenarioError(f"{source}: {exc}") from None

    out = [
        f"# GENERATED by tools/make_block_scenarios.py from {SOURCE_NAME}. Do not edit:",
        "# change that file or the recording, then rerun the tool.",
        "#",
        f"# Replays {recording.name} one block per flow step, so every block",
        "# of the group's script.md is a GMT phase of its own. Block 1 starts the app;",
        "# every later block continues it as the block before left it (replay.py --block).",
        "#",
        head.rstrip("\n"),
        "",
        "flow:",
    ]
    for index, name in enumerate(names, start=1):
        out += [
            f"  - name: {yaml_scalar(name)}",
            f"    container: {container}",
            "    commands:",
            "      - type: console",
            f"        command: {command} --block {index}",
        ]
        if read_notes:
            out.append("        read-notes-stdout: true")
    return "\n".join(out) + "\n", names


def find_sources(paths: list[Path]) -> list[Path]:
    sources: list[Path] = []
    for path in paths:
        if path.is_file():
            sources.append(path.resolve())
        else:
            sources.extend(sorted(p.resolve() for p in path.rglob(SOURCE_NAME)))
    return sources


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    parser.add_argument("paths", nargs="*", type=Path, default=[REPO / "applications"],
                        help=f"{SOURCE_NAME} files, or folders to search for them "
                             "(default: applications/)")
    parser.add_argument("--check", action="store_true",
                        help="write nothing; exit 1 if any copy is missing or out of date")
    args = parser.parse_args(argv)

    sources = find_sources(args.paths)
    if not sources:
        print(f"no {SOURCE_NAME} found under {[str(p) for p in args.paths]}", file=sys.stderr)
        return 1

    failed = False
    group_names: dict[Path, tuple[Path, list[str]]] = {}
    for source in sources:
        target = source.with_name(TARGET_NAME)
        try:
            content, names = render(source)
        except (ScenarioError, OSError, ValueError) as exc:
            print(f"ERROR {exc}", file=sys.stderr)
            failed = True
            continue

        # Phases are only comparable across a group if they carry the same names
        # in the same order - tools/check_blocks.py enforces the same thing.
        group = source.parent.parent
        first = group_names.setdefault(group, (source, names))
        if first[1] != names:
            print(f"ERROR {source}: block names differ from {first[0]}", file=sys.stderr)
            failed = True
            continue

        rel = target.relative_to(REPO) if target.is_relative_to(REPO) else target
        current = target.read_text(encoding="utf-8") if target.exists() else None
        if current == content:
            print(f"up to date  {rel} ({len(names)} blocks)")
        elif args.check:
            print(f"{'STALE' if current is not None else 'MISSING'}  {rel}", file=sys.stderr)
            failed = True
        else:
            target.write_text(content, encoding="utf-8")
            print(f"wrote       {rel} ({len(names)} blocks)")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
