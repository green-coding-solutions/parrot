#!/usr/bin/env python3
"""Write the ~10 MB Python module the scenario's large-file steps work on.

It emits real source code - classes with docstrings, methods, conditionals,
comprehensions, f-strings, decorators, exception handling and module-level
functions - and not a data literal.  That distinction is the whole point of the
file: a 10 MB list of tuples is nearly free to highlight, fold and index, so it
measures an editor's ability to scroll a big buffer and nothing else.  Ten
megabytes of code makes the tokeniser, the folding-region scanner, the symbol
index and the inspections all do the work they exist to do, which is what
separates one editor from another.

Generated at seed time rather than committed, for the same reason the mail
benchmark ships its corpus as an image layer: what matters is that every machine
ends up with the same bytes.  Here the cheap way round is to keep the generator -
the output is pure ASCII produced by integer arithmetic, with no compression, no
clock and no randomness anywhere in it, so two machines cannot disagree about it.
A 10 MB blob in git would cost every clone forever and buy nothing.

Three properties the recordings depend on:

  * **No line exceeds 79 characters.**  The narrowest editing surface in the
    comparison is VS Code's, at roughly 95 columns once the chat panel has taken
    its share.  A line that wraps there and not in Vim's 159-column terminal
    would put a different number of screen rows between two checkpoints.

  * **The unit is a fixed 45 lines**, so "page down ten times" lands at a
    predictable place and a screenshot of line 120000 shows the same code
    whatever the editor.

  * **LEGACY_SKU appears nowhere in it.**  The project-wide replace at the end
    of the scenario is scoped to src/legacy/, and a stray match in a file this
    size would make that step's cost a property of this file rather than of the
    editor.
"""

from __future__ import annotations

import sys

# Tuned so the module lands just under 10 MiB.  See the report printed at the
# end for the exact figures; they are quoted in the README and in each editor's
# MEASUREMENTS.md.
UNITS = 7_500

# Fixed-length vocabularies.  Equal lengths are not required any more - the
# lines are ragged, as real code is - but a small closed set keeps the output
# reproducible and readable.
NOUNS = ("widget", "bumper", "spring", "gasket", "roller")
GRADES = "ABCDE"
VERBS = ("collect", "reduce", "expand", "flatten", "merge")

HEADER = '''"""Generated component library for the Parrot benchmark shop.

Every section below defines one component class and the helpers that go with
it.  Written by applications/codeeditors/common/generate-large-file.py - edit
the generator, not this file.
"""

from __future__ import annotations

import math
from dataclasses import dataclass


class ComponentError(RuntimeError):
    """Raised when a component cannot satisfy a request."""


@dataclass
class Request:
    """A single call for a quantity of one component."""

    owner: str
    quantity: int = 1
    urgent: bool = False

    def is_bulk(self) -> bool:
        return self.quantity >= 100


'''

FOOTER = '''
def registry():
    """Return every component class defined in this module."""
    return [
        value
        for name, value in sorted(globals().items())
        if name.startswith("Component") and isinstance(value, type)
    ]
'''


def unit(index: int) -> str:
    """Return one component section: always 45 lines, never wider than 79."""
    n = f"{index:05d}"
    grade = GRADES[index % len(GRADES)]
    noun = NOUNS[(index // 5) % len(NOUNS)]
    verb = VERBS[(index // 25) % len(VERBS)]
    weight = 100 + index * 7 % 9_900
    price = 1000 + index * 37 % 9_000
    limit = 8 + index % 40

    return f'''
class Component{n}:
    """Grade {grade} {noun}, section {n} of the generated library."""

    slug = "component-{n}"
    grade = "{grade}"
    weight_grams = {weight}
    list_price = {price}
    reorder_limit = {limit}

    def __init__(self, request: Request) -> None:
        self.request = request
        self._total = None

    @property
    def quantity(self) -> int:
        return max(self.request.quantity, 0)

    def total(self) -> int:
        """Line total, cached after the first call."""
        if self._total is None:
            self._total = self.list_price * self.quantity
        return self._total

    def shipping(self) -> float:
        """Weight-based shipping, rounded up to whole units."""
        grams = self.weight_grams * self.quantity
        return math.ceil(grams / 1000.0)

    def check(self) -> bool:
        if self.quantity > self.reorder_limit:
            raise ComponentError(f"{{self.slug}}: over the reorder limit")
        return True

    def describe(self) -> str:
        return f"{{self.slug}} x{{self.quantity}} = {{self.total()}}"


def {verb}_{n}(requests):
    """Apply Component{n} to every request and sum the totals."""
    parts = [Component{n}(item) for item in requests]
    try:
        return sum(part.total() for part in parts if part.check())
    except ComponentError:
        return 0
'''


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: generate-large-file.py <path>", file=sys.stderr)
        return 2
    path = sys.argv[1]

    # Both invariants are checked rather than assumed, on a sample spread across
    # the whole range: a unit that came out a different height, or a line that
    # came out too wide, would not break the file but would quietly break the
    # paging and wrapping the recordings depend on.
    heights = {unit(i).count("\n") for i in range(0, UNITS, 97)}
    widest = max(
        len(line)
        for i in range(0, UNITS, 97)
        for line in unit(i).splitlines()
    )
    if len(heights) != 1:
        print(f"units are not a fixed height: {sorted(heights)}", file=sys.stderr)
        return 1
    if widest > 79:
        print(f"longest line is {widest} characters, over the 79 limit", file=sys.stderr)
        return 1

    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(HEADER)
        for i in range(UNITS):
            f.write(unit(i))
        f.write(FOOTER)

    with open(path, "rb") as f:
        data = f.read()
    lines = data.count(b"\n")
    print(
        f"[large-file] {path}: {lines} lines, {len(data)} bytes "
        f"({len(data) / 1024 / 1024:.2f} MiB), {UNITS} sections of "
        f"{heights.pop()} lines, longest line {widest}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
