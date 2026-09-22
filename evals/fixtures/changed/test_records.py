from records import get_record


def test_admin_reads_any():
    admin = {"id": "root", "role": "admin"}
    assert get_record(admin, {"id": "r1", "owner": "alice"})["value"] == "salary-90000"
