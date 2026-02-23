#!/usr/bin/env python3
"""Shared helpers for xmacro #APP metadata."""

from __future__ import annotations

import shlex
from pathlib import Path

APP_DIRECTIVE = "#APP"
APP_FIELDS = ("startcommand", "windowtitle", "windowclass")
DEFAULT_APP_META = {
    "startcommand": "",
    "windowtitle": "Calculator",
    "windowclass": "gnome-calculator",
}


def parse_app_directive(line: str) -> dict[str, str] | None:
    if line != APP_DIRECTIVE and not line.startswith(f"{APP_DIRECTIVE} "):
        return None

    rest = line[len(APP_DIRECTIVE) :].strip()
    if not rest:
        return {}

    try:
        tokens = shlex.split(rest)
    except ValueError:
        return {}

    result: dict[str, str] = {}
    i = 0
    while i < len(tokens):
        token = tokens[i]
        if "=" in token:
            key, value = token.split("=", 1)
            i += 1
        elif i + 1 < len(tokens):
            key, value = token, tokens[i + 1]
            i += 2
        else:
            i += 1
            continue

        key = key.strip().lower()
        if key in APP_FIELDS:
            result[key] = value.strip()

    return result


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
    raw: dict[str, str] = {}
    with input_path.open("r", encoding="utf-8") as f:
        for line in f:
            parsed = parse_app_directive(line.rstrip("\n"))
            if parsed is not None:
                raw.update(parsed)
    return normalize_app_meta(raw)


def format_app_directive_lines(meta: dict[str, str]) -> list[str]:
    lines: list[str] = []
    for key in APP_FIELDS:
        value = meta.get(key, "")
        if value == "":
            continue
        lines.append(f"{APP_DIRECTIVE} {key}={shlex.quote(value)}")
    return lines

def derive_run_name(compose_file: Path) -> str:
    parts = [p for p in compose_file.stem.split("-") if p]
    return parts[-1] if parts else compose_file.stem
