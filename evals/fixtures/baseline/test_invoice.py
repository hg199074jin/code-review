from invoice import total, format_invoice


def test_total():
    assert total([{"name": "a", "price": 2, "qty": 3}]) == 6


def test_format():
    assert format_invoice([{"name": "a", "price": 2, "qty": 3}]) == "a x3"
