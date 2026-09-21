# Requirement

1. `total()` must skip a line that has no `price` key instead of raising.
2. `format_invoice()` must render each line as `name x qty = amount`.
3. Add `apply_discount(t, pct)` that raises `ValueError` when `pct` is
   outside 0-100.
