#!/bin/sh
# code-review skill — failure-injection (mutation) test for the deterministic harness.
#
# A green run.sh is NOT evidence. This script proves the harness's checks actually go RED
# when their condition stops holding:
#
#   M1 normal                       -> PASS   (baseline: the harness is green when healthy)
#   M2 delete a copied fixture      -> FAIL   (CR-002: copy must be guarded)
#   M3 delete a requirement SPEC    -> FAIL   (CR-002: spec is load-bearing for P1 grading)
#   M4 break the upstream push      -> FAIL   (CR-003: trap must be proven armed)
#   M5 fix a planted defect         -> FAIL   (CR-001: behavioural drift guard must fire)
#   M6 respell a planted defect     -> FAIL   (CR-001: guard must not be a string matcher)
#   M7 desync the scenario JSONs    -> FAIL   (OR-009: id sets must be guarded)
#   M8 restore everything           -> PASS   (no residue; harness returns to green)
#
# Each mutation runs against a throwaway copy under $WORK; the repository is never touched.
# Usage: ./evals/mutation-test.sh
# Env:   MUTATION_VERBOSE=1 to see the failing output of each mutation.

set -u

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/cr-mutation.XXXXXX")
VERBOSE=${MUTATION_VERBOSE:-0}
CASES=0
GOOD=0

say()  { printf '%s\n' "$1"; }
ok()   { CASES=$((CASES + 1)); GOOD=$((GOOD + 1)); printf '  ok   %s\n' "$1"; }
bad()  { CASES=$((CASES + 1)); printf '  FAIL %s\n' "$1"; }

# expect <desc> <want: pass|fail> <actual-exit-code>
expect() {
  _desc="$1"; _want="$2"; _rc="$3"
  if [ "$_want" = pass ]; then
    if [ "$_rc" -eq 0 ]; then ok "$_desc"; else bad "$_desc (expected green, got red)"; fi
  else
    if [ "$_rc" -ne 0 ]; then ok "$_desc"; else bad "$_desc (expected RED, got green — false confidence)"; fi
  fi
}

fresh() {  # fresh <name> -> copies evals/ into $WORK/<name>/evals, echoes the path
  _n="$1"
  rm -rf "${WORK:?}/$_n"
  mkdir -p "$WORK/$_n"
  cp -R "$HERE" "$WORK/$_n/evals"
  printf '%s' "$WORK/$_n/evals"
}

run_quiet() {  # run_quiet <evals-dir> ; echoes exit code
  ( cd "$1" && ./run.sh >/tmp/.cr-mut-out.$$ 2>&1 )
  _rc=$?
  if [ "$VERBOSE" = 1 ]; then
    printf '    --- harness output ---\n'
    sed 's/^/    /' /tmp/.cr-mut-out.$$
    printf '    --- end ---\n'
  fi
  rm -f /tmp/.cr-mut-out.$$
  return $_rc
}

say '[M1] baseline: unmutated harness must be green'
E=$(fresh m1); rc=0; run_quiet "$E" || rc=$?
expect "M1 normal harness is green" pass "$rc"

say '[M2] mutation: delete a copied fixture (changed/test_service.py)'
E=$(fresh m2); rm -f "$E/fixtures/changed/test_service.py"
rc=0; run_quiet "$E" || rc=$?
expect "M2 deleting a fixture turns the harness RED" fail "$rc"

say '[M3] mutation: delete a requirement SPEC (HIGH_RISK_SPEC.md)'
E=$(fresh m3); rm -f "$E/fixtures/HIGH_RISK_SPEC.md"
rc=0; run_quiet "$E" || rc=$?
expect "M3 deleting a requirement spec turns the harness RED" fail "$rc"

say '[M4] mutation: break the upstream push (trap never armed)'
E=$(fresh m4)
sed 's|git push -q -u origin feature-x|git remote set-url origin /nonexistent-cr-mutation-remote.git; git push -q -u origin feature-x|' \
  "$E/run.sh" > "$E/run.sh.new" && mv "$E/run.sh.new" "$E/run.sh"
rc=0; run_quiet "$E" || rc=$?
expect "M4 an unarmed upstream trap turns the harness RED" fail "$rc"

say '[M5] mutation: fix a planted defect (spec-1 skip branch, respelled)'
E=$(fresh m5)
python3 - "$E/fixtures/changed/invoice.py" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
s = s.replace('        s += ln["price"] * ln["qty"]',
              '        p = ln.get("price")\n        if p is None:\n            continue\n        s += p * ln["qty"]')
open(p, 'w').write(s)
PY
rc=0; run_quiet "$E" || rc=$?
expect "M5 fixing spec-1 turns the harness RED" fail "$rc"

say '[M6] mutation: respell a planted defect (assert instead of raise ValueError)'
E=$(fresh m6)
python3 - "$E/fixtures/changed/invoice.py" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
s = s.replace('    return t * (1 - pct / 100)',
              '    assert 0 <= pct <= 100\n    return t * (1 - pct / 100)')
open(p, 'w').write(s)
PY
rc=0; run_quiet "$E" || rc=$?
expect "M6 respelling spec-3 still turns the harness RED" fail "$rc"

say '[M7] mutation: desync the two scenario JSONs (rename one id)'
E=$(fresh m7)
python3 - "$E/test-prompts.json" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read().replace('v2-tool-fusion-12', 'v2-tool-fusion-12-renamed', 1)
open(p, 'w').write(s)
PY
rc=0; run_quiet "$E" || rc=$?
expect "M7 a desynced scenario id turns the harness RED" fail "$rc"

say '[M8] restore: a fresh copy must be green again (no residue)'
E=$(fresh m8); rc=0; run_quiet "$E" || rc=$?
expect "M8 restored harness is green" pass "$rc"

rm -rf "$WORK"
say ""
say "mutation test: $GOOD/$CASES cases behaved as required"
if [ "$GOOD" -ne "$CASES" ]; then
  say "The harness has a false-confidence path: a mutation that should fail silently passed."
  exit 1
fi
say "All failure paths are armed: the harness goes red exactly when its condition stops holding."
