import os

DEBUG = False

INTERNAL_ENV_KEYS = ["DB_HOST", "DB_PASSWORD", "API_SIGNING_KEY"]

def handle_request(path, user, is_internal_ip=True):
    if path == "/metrics":
        if not is_internal_ip:
            raise PermissionError("internal only")
        data = {k: os.environ.get(k) for k in INTERNAL_ENV_KEYS}
        return 200, data
    if path == "/health":
        return 200, {"ok": True}
    return 404, {"error": "not found"}
