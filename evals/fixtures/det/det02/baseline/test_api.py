from api import get_record, USERS, RECORDS

def test_owner_can_read():
    assert get_record(USERS["alice"], "r1")["body"] == "payload"

def test_other_user_denied():
    try:
        get_record(USERS["bob"], "r1")
        assert False
    except PermissionError:
        pass
