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
#
# Self-guard (added after the merge-safety review found a false-green here): a mutation can
# never count as "red as required" unless the harness provably RAN. `expect` requires the
# harness's own `result:` summary line in the captured output, and the harness is invoked via
# `sh` so a lost executable bit cannot silently substitute for a real failure.
#
# Usage: ./evals/mutation-test.sh
# Env:   MUTATION_VERBOSE=1 to see the failing output of each mutation.

set -u

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/cr-mutation.XXXXXX")
CAP=$(mktemp "${TMPDIR:-/tmp}/cr-mut-out.XXXXXX")
VERBOSE=${MUTATION_VERBOSE:-0}
CASES=0
GOOD=0

cleanup() { rm -rf "${WORK:?}" "${CAP:?}"; }
trap cleanup EXIT INT TERM

say()  { printf '%s\n' "$1"; }
ok()   { CASES=$((CASES + 1)); GOOD=$((GOOD + 1)); printf '  ok   %s\n' "$1"; }
bad()  { CASES=$((CASES + 1)); printf '  FAIL %s\n' "$1"; }

fresh() {  # fresh <name> -> copies evals/ into $WORK/<name>/evals, echoes the path
  _n="$1"
  rm -rf "${WORK:?}/$_n"
  mkdir -p "$WORK/$_n"
  cp -R "${HERE:?}" "$WORK/$_n/evals"
  # the registry/matrix guards read SKILL.md relative to the evals copy's parent
  cp "${HERE:?}/../SKILL.md" "$WORK/$_n/SKILL.md"
  # registry/matrix/README guards read these too; M6a README mutations (DM4/DM5) need them
  cp "${HERE:?}/../README.md" "${HERE:?}/../README.zh-CN.md" "$WORK/$_n/"
  printf '%s' "$WORK/$_n/evals"
}

run_quiet() {  # run_quiet <evals-dir> ; captures output to $CAP, returns the harness exit code
  ( cd "$1" && sh ./run.sh >"$CAP" 2>&1 )
  return $?
}

harness_ran() {
  # The harness either ran to completion (its own summary line) or failed fast for an
  # identified reason (a FAIL line). Neither present => it never really ran.
  grep -q '^result: ' "$CAP" 2>/dev/null || grep -q '  FAIL ' "$CAP" 2>/dev/null
}

harness_failed_for_reason() { grep -q '  FAIL ' "$CAP" 2>/dev/null; }

# expect_marker <desc> <expected FAIL substring>
# A red is only evidence if it came from the intended guard. Without this, an unrelated
# FAIL line would let a case pass with the wrong root cause (merge-safety MS-004).
expect_marker() {
  _d="$1"; _m="$2"
  if grep -q -- "$_m" "$CAP"; then ok "$_d"; else bad "$_d (expected FAIL marker not found: $_m)"; fi
}

# expect <desc> <want: pass|fail> <actual-exit-code>
expect() {
  _desc="$1"; _want="$2"; _rc="$3"
  if ! harness_ran; then
    bad "$_desc (harness never ran to completion and reported no FAIL line - this is NOT evidence of either green or red)"
    if [ "$VERBOSE" = 1 ]; then sed 's/^/    /' "$CAP"; fi
    return
  fi
  if [ "$_want" = pass ]; then
    if [ "$_rc" -eq 0 ]; then ok "$_desc"; else bad "$_desc (expected green, got red)"; fi
  else
    # A red is only evidence if the harness diagnosed WHY it went red.
    if [ "$_rc" -ne 0 ] && harness_failed_for_reason; then
      ok "$_desc"
    elif [ "$_rc" -ne 0 ]; then
      bad "$_desc (exit non-zero but no FAIL line - red is unattributable)"
    else
      bad "$_desc (expected RED, got green - false confidence)"
    fi
  fi
}

show() {  # show captured harness output when verbose
  if [ "$VERBOSE" = 1 ]; then
    printf '    --- harness output ---\n'
    sed 's/^/    /' "$CAP"
    printf '    --- end ---\n'
  fi
}

say '[M1] baseline: unmutated harness must be green'
E=$(fresh m1); rc=0; run_quiet "$E" || rc=$?; show
expect "M1 normal harness is green" pass "$rc"

say '[M2] mutation: delete a copied fixture (changed/test_service.py)'
E=$(fresh m2); rm -f "$E/fixtures/changed/test_service.py"
rc=0; run_quiet "$E" || rc=$?; show
expect "M2 deleting a fixture turns the harness RED" fail "$rc"
expect_marker "M2b the red came from the missing-fixture guard" "missing fixtures/changed/test_service.py"

say '[M3] mutation: delete a requirement SPEC (HIGH_RISK_SPEC.md)'
E=$(fresh m3); rm -f "$E/fixtures/HIGH_RISK_SPEC.md"
rc=0; run_quiet "$E" || rc=$?; show
expect "M3 deleting a requirement spec turns the harness RED" fail "$rc"
expect_marker "M3b the red came from the missing-spec guard" "missing fixtures/HIGH_RISK_SPEC.md"

say '[M4] mutation: break the upstream push (trap never armed)'
E=$(fresh m4)
# Edit in place, keeping the mode. A sed>new+mv would drop the executable bit, and a harness
# that cannot execute is not a harness that failed.
sed -i.bak 's|git push -q -u origin feature-x|git remote set-url origin /nonexistent-cr-mutation-remote.git; git push -q -u origin feature-x|' "$E/run.sh"
rm -f "$E/run.sh.bak"
rc=0; run_quiet "$E" || rc=$?; show
expect "M4 an unarmed upstream trap turns the harness RED" fail "$rc"
if harness_ran; then
  if grep -q 'upstream NOT armed' "$CAP"; then
    ok "M4b the red came from the arming guard, not an unrelated crash"
  elif [ "$rc" -ne 0 ]; then
    bad "M4b harness went red but not via the arming guard - root cause unclear"
  else
    bad "M4b harness stayed green - the mutation had no effect"
  fi
fi

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
rc=0; run_quiet "$E" || rc=$?; show
expect "M5 fixing spec-1 turns the harness RED" fail "$rc"
expect_marker "M5b the red came from the spec-1 drift guard" "total() no longer raises"

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
rc=0; run_quiet "$E" || rc=$?; show
expect "M6 respelling spec-3 still turns the harness RED" fail "$rc"
expect_marker "M6b the red came from the spec-3 drift guard" "apply_discount now validates"

say '[M7] mutation: desync the two scenario JSONs (rename one id)'
E=$(fresh m7)
python3 - "$E/test-prompts.json" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read().replace('v2-tool-fusion-12', 'v2-tool-fusion-12-renamed', 1)
open(p, 'w').write(s)
PY
rc=0; run_quiet "$E" || rc=$?; show
expect "M7 a desynced scenario id turns the harness RED" fail "$rc"
expect_marker "M7b the red came from the JSON-sync guard" "desynchronized (OR-009)"

say '[M8] restore: a fresh copy must be green again (no residue)'
E=$(fresh m8); rc=0; run_quiet "$E" || rc=$?; show
expect "M8 restored harness is green" pass "$rc"

say ""
say "mutation test: $GOOD/$CASES cases behaved as required"
if [ "$GOOD" -ne "$CASES" ]; then
  say "The harness has a false-confidence path: a mutation that should fail silently passed,"
  say "or the harness could not run at all (which is not evidence either way)."
  exit 1
fi
say "All failure paths are armed: the harness goes red exactly when its condition stops holding."
