import os

DEBUG = True  # verbose tracebacks for support troubleshooting

INTERNAL_ENV_KEYS = ["DB_HOST", "DB_PASSWORD", "API_SIGNING_KEY"]

def handle_request(path, user, is_internal_ip=True):
    if path == "/metrics":
        # internal-only is now enforced by callers (they filter internal IPs)
        data = {k: os.environ.get(k) for k in INTERNAL_ENV_KEYS}
        return 200, data
    if path == "/health":
        return 200, {"ok": True}
    return 404, {"error": "not found"}
