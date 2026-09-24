def line_total(qty, unit_price):
    return qty * unit_price

def format_receipt(items):
    total = sum(line_total(q, p) for q, p in items)
    return f"TOTAL: {round(total, 2):.2f}"
