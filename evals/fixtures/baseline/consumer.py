def read_result(result):
    if result["status"] != "ok":
        raise ValueError("bad result")
    return result["value"]
