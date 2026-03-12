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
EVENT_VERBS = frozenset({"wait", "mousemove", "mousedown", "mouseup", "keydown", "keyup", "check"})


def normalize_app_meta(meta: dict[str, str] | None) -> dict[str, str]:
    merged = dict(DEFAULT_APP_META)
    if meta:
        for key in APP_FIELDS:
            if key in meta and meta[key] is not None:
                value = str(meta[key]).strip()
                if value != "" or key == "startcommand":
                    merged[key] = value
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
    """Return the metadata block lines for writing to a .🦜 file."""
    lines: list[str] = []
    for key in APP_FIELDS:
        value = meta.get(key, "")
        if value:
            lines.append(f"{key} = {value}")
    return lines
