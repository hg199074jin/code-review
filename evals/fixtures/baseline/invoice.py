def total(lines):
    s = 0
    for ln in lines:
        s += ln["price"] * ln["qty"]
    return s


def format_invoice(lines):
    out = []
    for ln in lines:
        out.append("%s x%d" % (ln["name"], ln["qty"]))
    return "\n".join(out)
