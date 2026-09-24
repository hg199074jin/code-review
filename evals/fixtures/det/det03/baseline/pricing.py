COUPONS = {"SAVE10": 0.9}

def apply_discount(total, coupon):
    """Apply a coupon code to the pre-discount total."""
    factor = COUPONS.get(coupon)
    if factor is None:
        return total
    return round(total * factor, 2)

def checkout(cart_total, coupon):
    return apply_discount(cart_total, coupon)
