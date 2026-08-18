"""Stock levels for the Parrot benchmark shop."""

from __future__ import annotations

STOCK = {
    "SKU-1001": 42,
    "SKU-1002": 7,
    "SKU-1003": 0,
    "SKU-2010": 115,
}

LOW_STOCK_THRESHOLD = 10


def in_stock(sku):
    """True when *sku* can be ordered at all."""
    return STOCK.get(sku, 0) > 0


def is_low(sku):
    """True when *sku* is running out."""
    level = STOCK.get(sku, 0)
    return 0 < level <= LOW_STOCK_THRESHOLD


def reserve(sku, quantity):
    """Take *quantity* off the shelf, returning what was actually reserved."""
    available = STOCK.get(sku, 0)
    taken = min(available, quantity)
    STOCK[sku] = available - taken
    return taken
