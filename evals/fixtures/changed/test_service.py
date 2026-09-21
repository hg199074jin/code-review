from producer import make_result


def test_producer_uses_new_field():
    assert make_result(3)["state"] == "ok"
