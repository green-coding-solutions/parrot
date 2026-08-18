"""Shipping weights carried over from the old shop."""

from __future__ import annotations

LEGACY_SKU = "SKU-0000"

WEIGHTS = {
    LEGACY_SKU: 0,
    "SKU-1001": 180,
    "SKU-2010": 3200,
}


def weight_of(sku):
    """Grams for *sku*, or the placeholder's weight when it is unknown."""
    return WEIGHTS.get(sku, WEIGHTS[LEGACY_SKU])


def needs_weighing(sku):
    """The placeholder has no real weight, so it always has to be weighed."""
    return sku == LEGACY_SKU
