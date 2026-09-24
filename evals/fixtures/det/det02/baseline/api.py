USERS = {
    "alice": {"id": "alice", "role": "user"},
    "bob": {"id": "bob", "role": "user"},
    "viewer1": {"id": "viewer1", "role": "viewer"},
}
RECORDS = {"r1": {"id": "r1", "owner": "alice", "body": "payload"}}

def get_record(user, record_id):
    record = RECORDS[record_id]
    if record["owner"] != user["id"]:
        raise PermissionError("forbidden")
    return record
