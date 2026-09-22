DB = {
    "r1": {"id": "r1", "owner": "alice", "value": "salary-90000"},
    "r2": {"id": "r2", "owner": "bob", "value": "salary-60000"},
}


def get_record(user, record):
    if record["owner"] != user["id"] and user.get("role") != "admin":
        raise PermissionError("forbidden")
    return DB[record["id"]]
