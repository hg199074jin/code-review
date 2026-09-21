TAX_RATE = 0.07
ROUND_DP = 2


def total(lines):
    s = 0
    for ln in lines:
        s += ln["price"] * ln["qty"]
    return round(s, 2)


def format_invoice(lines):
    out = []
    for ln in lines:
        out.append("%s x%d = %.2f" % (ln["name"], ln["qty"], ln["price"] * ln["qty"]))
    return "\n".join(out)


def apply_discount(t, pct):
    return t * (1 - pct / 100)
