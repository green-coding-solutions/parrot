#!/usr/bin/env python3
"""Shared helpers for Parrot recording metadata and format."""

from __future__ import annotations

from pathlib import Path

PARROT_HEADER = "# Parrot recording v2"

APP_FIELDS = ("startcommand", "windowtitle", "windowclass")

DEFAULT_APP_META = {
    "startcommand": "",
    "windowtitle":  "Calculator",
    "windowclass":  "gnome-calculator",
}

# First token of any event line in a .🦜 file.
# Lines whose first token is NOT one of these are treated as metadata.
EVENT_VERBS = frozenset({"wait", "mousemove", "mousedown", "mouseup", "keydown", "keyup", "check", "log", "label", "loop"})


def normalize_app_meta(meta: dict[str, str] | None) -> dict[str, str]:
    """Fill in defaults for metadata keys that were not supplied at all.

    A key that IS supplied but empty stays empty.  That is what lets a recording
    say "match this window by title only, ignore the class" - needed whenever an
    app gives its dialogs the same WM_CLASS as its main window, so that matching
    on class alone would pick an arbitrary one of them.  Without this, an empty
    windowclass silently became the gnome-calculator default and window lookup
    matched nothing.
    """
    merged = dict(DEFAULT_APP_META)
    if meta:
        for key in APP_FIELDS:
            if key in meta and meta[key] is not None:
                merged[key] = str(meta[key]).strip()
    return merged


def load_app_metadata(input_path: Path) -> dict[str, str]:
    """
    Parse the metadata block at the top of a .🦜 file.

    Format:
        # comment
        key = value          ← metadata (everything after '=' is the value)
        <blank line>
        wait 2.5             ← first event line; stops metadata parsing
        mousemove 100 200

    Lines before the first event verb are treated as 'key = value' pairs.
    '=' is optional; 'key value' (space-separated) is also accepted.
    """
    raw: dict[str, str] = {}
    with input_path.open("r", encoding="utf-8") as f:
        for raw_line in f:
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue
            if line.split()[0].lower() in EVENT_VERBS:
                break   # reached the events section
            if "=" in line:
                key, _, value = line.partition("=")
            else:
                parts = line.split(None, 1)
                key, value = parts[0], (parts[1] if len(parts) > 1 else "")
            key = key.strip().lower()
            if key in APP_FIELDS:
                raw[key] = value.strip()
    return normalize_app_meta(raw)


def format_metadata_lines(meta: dict[str, str]) -> list[str]:
    """Return the metadata block lines for writing to a .🦜 file.

    Every field is written, including empty ones.  An omitted key would be filled
    in from the defaults on load, which would turn a deliberate "ignore the window
    class" into a match against gnome-calculator.
    """
    lines: list[str] = []
    for key in APP_FIELDS:
        lines.append(f"{key} = {meta.get(key, '')}")
    return lines


# ---------------------------------------------------------------------------
# Checkpoint note labels
# ---------------------------------------------------------------------------
# A script line may carry a short label and a detailed instruction, separated by
# the first colon:
#
#     * Reply and send: reply to the second message with the text ...
#
# Recording shows the whole line, so whoever is driving the application knows
# exactly what to do and every client is driven identically.  Replay emits only
# the label, because that is what ends up as a note in the measurement and what
# names the block when recordings are compared - the detail would make both
# unreadable.
#
# The full line stays in the .🦜 file either way, so a recording remains
# self-documenting.

NOTE_LABEL_SEPARATOR = ":"


def note_label(note: str) -> str:
    """Return the part of a checkpoint note before the first colon.

    Falls back to the whole note when there is no colon, so scripts written
    without labels keep working unchanged.  A colon with nothing before it is
    also left alone, rather than producing an empty note.
    """
    label, sep, _detail = note.partition(NOTE_LABEL_SEPARATOR)
    if not sep:
        return note.strip()
    label = label.strip()
    return label if label else note.strip()
