"""Order pricing for the Parrot benchmark shop.

Turns a basket of line items into a gross total: discount first, then shipping,
then tax on the sum of both.
"""

from __future__ import annotations

from dataclasses import dataclass, field

DEFAULT_RATE = 0.19
DEFAULT_CURRENCY = "EUR"
MINIMUM_ORDER = 5.00
FREE_SHIPPING_THRESHOLD = 49.00
SHIPPING_FLAT = 4.90
HEAVY_ITEM_GRAMS = 2000
ROUNDING_PLACES = 2


@dataclass
class LineItem:
    """A single position on an order."""

    sku: str
    description: str
    unit_price: float
    quantity: int = 1
    weight_grams: int = 0
    metadata: dict = field(default_factory=dict)

    @property
    def line_price(self) -> float:
        return round(self.unit_price * self.quantity, ROUNDING_PLACES)

    def is_heavy(self) -> bool:
        return self.weight_grams > HEAVY_ITEM_GRAMS

    def label(self) -> str:
        return f"{self.sku} x{self.quantity} - {self.description}"


@dataclass
class Discount:
    """A percentage discount, optionally limited to a set of SKUs."""

    code: str
    percent: float
    applies_to: tuple = ()

    def matches(self, item: LineItem) -> bool:
        if not self.applies_to:
            return True
        return item.sku in self.applies_to

    def describe(self) -> str:
        if self.applies_to:
            return f"{self.code}: {self.percent:g}% on {len(self.applies_to)} SKUs"
        return f"{self.code}: {self.percent:g}% on everything"


DISCOUNTS = {
    "PARROT10": Discount("PARROT10", 10.0),
    "PARROT25": Discount("PARROT25", 25.0),
    "BULK5": Discount("BULK5", 5.0, applies_to=("SKU-1001", "SKU-1002")),
}


def lookup_discount(code):
    """Return the Discount for *code*, or None when it is unknown."""
    if not code:
        return None
    return DISCOUNTS.get(code.strip().upper())


def subtotal_for(items):
    """Sum the line prices of *items*."""
    total = 0.0
    for item in items:
        total += item.line_price
    return round(total, ROUNDING_PLACES)


def discount_for(items, discount):
    """Return the absolute amount *discount* takes off *items*."""
    if discount is None:
        return 0.0
    reduced = 0.0
    for item in items:
        if discount.matches(item):
            reduced += item.line_price * discount.percent / 100.0
    return round(reduced, ROUNDING_PLACES)


def shipping_for(items):
    """Flat shipping, waived above the free-shipping threshold."""
    if subtotal_for(items) >= FREE_SHIPPING_THRESHOLD:
        return 0.0
    return SHIPPING_FLAT


def validate(items):
    """Raise when the basket is too small to be ordered."""
    if not items:
        raise ValueError("empty basket")
    if subtotal_for(items) < MINIMUM_ORDER:
        raise ValueError(f"order below the {MINIMUM_ORDER:.2f} minimum")
    return True


def calculate_total(items, discount_code=None, tax_rate=DEFAULT_RATE):
    """Return the gross total for *items*."""
    subtotal = subtotal_for(items)
    discount = lookup_discount(discount_code)
    subtotal -= discount_for(items, discount)
    subtotal += shipping_for(items)
    subtotal = round(subtotal, ROUNDING_PLACES)
    tax = subtotal * tax_rate
    return subtotal + tax


def apply_tax(amount, tax_rate):
    """Gross up a single *amount* by the given rate."""
    return round(amount * (1 + tax_rate), ROUNDING_PLACES)


def format_total(amount, currency=DEFAULT_CURRENCY):
    """Render *amount* the way the invoice template wants it."""
    return f"{amount:.2f} {currency}"
