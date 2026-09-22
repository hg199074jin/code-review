#!/bin/sh
# V2.1 M6b/M7 scenario builder (evaluator-side; lives outside the product repo).
#
# Builds 20 pristine scenario repos under $B3/scenarios so reviewers never touch the
# frozen PR-1 evidence workspace, and snapshots the V2.1 candidate SKILL.md as a
# non-floating authority ref. Deterministic: re-running rebuilds from scratch.
set -eu

B3=/Volumes/ORICO/Projects/code-review-meta-review/v21-design-review
SRC=/Volumes/ORICO/Projects/code-review
REPO=$SRC
OUT=$B3/scenarios
CAND=$B3/candidate

rm -rf "$OUT" "$CAND"
mkdir -p "$OUT" "$CAND"

# ------------------------------------------------------------ 1. authority --
cp "$REPO/SKILL.md" "$CAND/SKILL.md"
cp "$REPO/README.md" "$CAND/README.md"
cp "$REPO/README.zh-CN.md" "$CAND/README.zh-CN.md"
shasum -a 256 "$CAND/SKILL.md" | awk '{print $1}' > "$CAND/SKILL.sha256"
shasum -a 256 "$CAND/README.md" "$CAND/README.zh-CN.md" | awk '{print $1}' > "$CAND/README.sha256"
echo "candidate SKILL.md sha256: $(cat "$CAND/SKILL.sha256")"

# ------------------------------------------------------ 2. Group A-D copies --
# 14 V2.0.2 fixtures, copied pristine from the PR-1 workspace (fixture identity is
# byte-preserved: .git + working tree as shipped, minus regenerated __pycache__).
for pair in \
  "review-workspace-01:s01-workspace" \
  "review-branch-02:s02-branch" \
  "review-nospec-03:s03-nospec" \
  "regress-upstream-trap-04:s04-upstream" \
  "regress-whole-repo-audit-05:s05-audit" \
  "regress-old-ocr-compat-06:s06-oldocr" \
  "regress-no-test-runner-07:s07-norunner" \
  "v2-pr-context-08:s08-prcontext" \
  "v2-r3-security-09:s09-r3security" \
  "v2-s3-integration-10:s10-s3integration" \
  "v2-review-fix-verify-11:s11-reviewfix" \
  "v2-tool-fusion-12:v201-s12" \
  "v2-egress-optin-13:v201-s13" \
  "v2-injection-boundary-14:v201-s14"
do
  id=${pair%%:*}; dir=${pair##*:}
  cp -R "/Volumes/ORICO/Projects/code-review-meta-review/pr1/scenarios/$dir" "$OUT/$id"
  find "$OUT/$id" -name __pycache__ -type d -prune -exec rm -rf {} + 2>/dev/null || true
done

# --------------------------------------------------------- 3. Group E repos --
# PRC-01 docs/narrow, R1-S1, no SPEC.
P=$OUT/v21-prc01-minimal-15; mkdir -p "$P"
cd "$P"; git init -q .
cat > README.md <<'EOF'
# Billing demo

Run it with: python3 app.py
EOF
cat > app.py <<'EOF'
def total(items):
    # adds up the item prices
    return sum(item["price"] for item in items)


if __name__ == "__main__":
    print(total([{"name": "a", "price": 2}, {"name": "b", "price": 3}]))
EOF
cat > test_app.py <<'EOF'
from app import total


def test_total():
    assert total([{"name": "a", "price": 2}]) == 2
EOF
git add -A; git -c user.email=e@x -c user.name=e commit -qm "baseline: billing demo"
cat > README.md <<'EOF'
# Billing demo

Usage: `python3 app.py` prints the invoice total for a sample basket.

Requirements: Python 3.9+. No third-party dependencies.
EOF
cat > app.py <<'EOF'
def total(items):
    # sums the item prices
    return sum(item["price"] for item in items)


if __name__ == "__main__":
    print(total([{"name": "a", "price": 2}, {"name": "b", "price": 3}]))
EOF

# PRC-02 R3 command execution (same fixture as scenario 09).
cp -R "$OUT/v2-r3-security-09" "$OUT/v21-prc02-r3-16"

# PRC-03 S3 cross-file (same fixture as scenario 10).
cp -R "$OUT/v2-s3-integration-10" "$OUT/v21-prc03-s3-17"

# PRC-04 verifier reliability: always-pass verifier replaces a real gate.
P=$OUT/v21-prc04-verifier-18; mkdir -p "$P/build"
cd "$P"; git init -q .
cat > README.md <<'EOF'
# Release verifier

`check.sh` is the last gate before packaging. It inspects `build/report.txt` and must fail
unless the report carries the `STATUS: VERIFIED` marker produced by the build job.
Release tooling calls it as: `sh check.sh`
EOF
cat > check.sh <<'EOF'
#!/bin/sh
# release verifier: the build report must carry the verification marker
grep -q "STATUS: VERIFIED" build/report.txt || { echo "verify FAILED"; exit 1; }
echo "verify OK"
EOF
cat > build/report.txt <<'EOF'
BUILD 2026-09-20.4
STATUS: DRAFT
artifact: dist/billing-2026.09.20.4.tar.gz
EOF
git add -A; git -c user.email=e@x -c user.name=e commit -qm "baseline: release verifier"
cat > check.sh <<'EOF'
#!/bin/sh
# release verifier
echo "verify OK"
EOF
cat > check_test.sh <<'EOF'
#!/bin/sh
out=$(sh check.sh)
case "$out" in
  "verify OK") echo "test PASS" ;;
  *) echo "test FAIL"; exit 1 ;;
esac
EOF

# PRC-05 dynamic-unavailable: R3 runner whose SPEC also demands production-runtime proof.
P=$OUT/v21-prc05-dynamic-19; mkdir -p "$P"
cd "$P"; git init -q .
cat > SPEC.md <<'EOF'
# High-risk requirement

1. run_job(job) receives an untrusted job identifier.
2. It must invoke jobctl without a shell.
3. A malicious job string must never become executable shell syntax.
4. Sign-off requires a real run against the production jobctl v2 endpoint
   (https://jobctl.internal/v2). Staging-only evidence is not accepted for release.
EOF
cat > runner.py <<'EOF'
import subprocess


def run_job(job):
    return subprocess.run(["jobctl", "run", job], check=True)
EOF
git add -A; git -c user.email=e@x -c user.name=e commit -qm "baseline: safe job runner"
cat > runner.py <<'EOF'
import os


def run_job(job):
    return os.system(f"jobctl run {job}")
EOF
cat > test_runner.py <<'EOF'
from unittest.mock import patch

from runner import run_job


@patch("runner.os.system")
def test_run_job(mock_system):
    run_job("daily")
    mock_system.assert_called_once_with("jobctl run daily")
EOF

# PRC-06 authz: ownership/role check removed from a read path.
P=$OUT/v21-prc06-authz-20; mkdir -p "$P"
cd "$P"; git init -q .
cp "$REPO/evals/fixtures/AUTHZ_SPEC.md" AUTHZ_SPEC.md
cp "$REPO/evals/fixtures/baseline/records.py" records.py
git add -A; git -c user.email=e@x -c user.name=e commit -qm "baseline: records with ownership check"
cp "$REPO/evals/fixtures/changed/records.py" records.py
cp "$REPO/evals/fixtures/changed/test_records.py" test_records.py

# PRC-07 R3 without any matching mandatory surface: a key-derivation weakening.
# No command execution, no authn/authz boundary, no file write, no verifier harness -> none of the
# four mandatory surface rows fires, so the only source of an adversarial requirement is R3_minimum.
P=$OUT/v21-prc07-r3-nosurface-21; mkdir -p "$P"
cd "$P"; git init -q .
cat > SPEC.md <<'EOF'
# Key derivation requirements

1. `derive_key(password)` must use PBKDF2-HMAC-SHA256 with at least 100000 iterations.
2. The salt must be random per installation and stored beside the derived key material.
3. A key must never be derived from a constant value that ships with the code.
4. `derive_key` returns raw key bytes and writes nothing to disk.
EOF
cat > derive.py <<'EOF'
import hashlib
import os

SALT_LEN = 16
ITERATIONS = 200000


def new_salt():
    return os.urandom(SALT_LEN)


def derive_key(password, salt):
    return hashlib.pbkdf2_hmac("sha256", password.encode(), salt, ITERATIONS, dklen=32)
EOF
git add -A; git -c user.email=e@x -c user.name=e commit -qm "baseline: PBKDF2 key derivation"
cat > derive.py <<'EOF'
import hashlib

SALT = b"backup-export-v1"
ITERATIONS = 1


def derive_key(password):
    return hashlib.pbkdf2_hmac("sha256", password.encode(), SALT, ITERATIONS, dklen=32)
EOF

# ------------------------------------------------------- 4. frozen manifest --
cd "$B3"
python3 - <<'PY'
import hashlib, json, os, subprocess
root = "/Volumes/ORICO/Projects/code-review-meta-review/v21-design-review/scenarios"
man = {"candidate": {}, "scenarios": {}}
cand = "/Volumes/ORICO/Projects/code-review-meta-review/v21-design-review/candidate"
for f in ("SKILL.md", "README.md", "README.zh-CN.md"):
    p = os.path.join(cand, f)
    man["candidate"][f] = hashlib.sha256(open(p, "rb").read()).hexdigest()
for sid in sorted(os.listdir(root)):
    d = os.path.join(root, sid)
    if not os.path.isdir(d):
        continue
    files = []
    for dirpath, dirnames, filenames in os.walk(d):
        dirnames[:] = [x for x in dirnames if x not in (".git", "__pycache__")]
        for fn in sorted(filenames):
            p = os.path.join(dirpath, fn)
            rel = os.path.relpath(p, d)
            files.append((rel, hashlib.sha256(open(p, "rb").read()).hexdigest()))
    files.sort()
    tree = hashlib.sha256(json.dumps(files, sort_keys=True).encode()).hexdigest()
    head = subprocess.run(["git", "-C", d, "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
    dirty = subprocess.run(["git", "-C", d, "status", "--porcelain"], capture_output=True, text=True).stdout
    man["scenarios"][sid] = {"head": head, "worktree_sha256": tree, "dirty": dirty,
                             "file_count": len(files)}
json.dump(man, open(os.path.join("/Volumes/ORICO/Projects/code-review-meta-review/v21-design-review/harness", "scenario-manifest.json"), "w"), indent=2)
print("scenarios frozen:", len(man["scenarios"]))
for k, v in man["scenarios"].items():
    print(f"  {k:32s} head={v['head'][:8]} files={v['file_count']:3d} worktree={v['worktree_sha256'][:12]}")
PY
