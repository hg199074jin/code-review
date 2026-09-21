from invoice import total, format_invoice, apply_discount


def test_total():
    assert total([{"name": "a", "price": 2, "qty": 3}]) == 6


def test_format():
    assert format_invoice([{"name": "a", "price": 2, "qty": 3}]) == "a x3 = 6.00"


def test_apply_discount():
    assert apply_discount(100, 10) == 90
