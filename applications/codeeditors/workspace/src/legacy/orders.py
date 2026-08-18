"""Order rows imported from the old shop, before the SKU scheme changed."""

from __future__ import annotations

LEGACY_SKU = "SKU-0000"

ROWS = [
    {"order": 8801, "sku": LEGACY_SKU, "quantity": 2},
    {"order": 8802, "sku": "SKU-1001", "quantity": 1},
    {"order": 8803, "sku": LEGACY_SKU, "quantity": 5},
]


def legacy_rows():
    """Every imported row that still carries the placeholder SKU."""
    return [row for row in ROWS if row["sku"] == LEGACY_SKU]
