"""Prices carried over from the old shop."""

from __future__ import annotations

LEGACY_SKU = "SKU-0000"

PRICES = {
    LEGACY_SKU: 0.00,
    "SKU-1001": 12.50,
    "SKU-2010": 24.00,
}


def price_of(sku):
    """Look up *sku*, falling back to the placeholder's price."""
    return PRICES.get(sku, PRICES[LEGACY_SKU])


def is_placeholder(sku):
    """True while *sku* has not been migrated to the new scheme."""
    return sku == LEGACY_SKU
