"""Tests for the order pricing rules."""

from src.price_calculator import (
    LineItem,
    calculate_total,
    format_total,
    shipping_for,
    subtotal_for,
)

BASKET = [
    LineItem("SKU-1001", "Feather duster", 12.50, quantity=2),
    LineItem("SKU-2010", "Perch, oak", 24.00, weight_grams=3200),
]


def test_subtotal():
    assert subtotal_for(BASKET) == 49.00


def test_shipping_is_waived_above_the_threshold():
    assert shipping_for(BASKET) == 0.0


def test_total_without_a_discount():
    assert round(calculate_total(BASKET), 2) == 58.31


def test_total_with_a_discount():
    assert round(calculate_total(BASKET, "PARROT10"), 2) == 58.31 - 5.83


def test_format():
    assert format_total(58.31) == "58.31 EUR"
