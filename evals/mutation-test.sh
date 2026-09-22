#!/bin/sh
# code-review skill — failure-injection (mutation) test for the deterministic harness.
#
# A green run.sh is NOT evidence. This script proves the harness's checks actually go RED
# when their condition stops holding:
#
#   M1  normal                     -> PASS   (baseline: the harness is green when healthy)
#   M2  delete a copied fixture    -> FAIL   (CR-002)
#   M3  delete a requirement SPEC  -> FAIL   (CR-002)
#   M4  break the upstream push    -> FAIL   (CR-003: trap must be proven armed)
#   M5  fix a planted defect       -> FAIL   (CR-001: behavioural drift guard must fire)
#   M6  respell a planted defect   -> FAIL   (CR-001: guard must not be a string matcher)
#   M7  desync the scenario JSONs  -> FAIL   (OR-009: id sets must be guarded)
#   M8  restore everything         -> PASS
#
#   DM1-DM13 (M6a, V2.1): every procedure-framework guard has its own injected failure,
#   and each red must be attributable to the target guard name (MS-001 discipline).
#
# Isolation rule: harness mutations run against throwaway copies under $WORK; the repo is
# never touched. M6b (agent-level SKILL mutations) is documented separately in
# evals/procedure-mutation-plan.md and never touches the canonical SKILL.md.
#
# Attribution rules (MS-001): "red" counts only when the harness output carries the target
# FAIL marker; a non-zero exit without one, or a decoy failure, is not evidence.
#
# Usage: ./evals/mutation-test.sh
# Env:   MUTATION_VERBOSE=1 | CR_EVAL_KEEP=1

set -u

HERE=$(cd "$(dirname "$0")" && pwd)
SKILL_FILE="$HERE/../SKILL.md"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/cr-mutation.XXXXXX")
CAP=$(mktemp "${TMPDIR:-/tmp}/cr-mut-out.XXXXXX")
VERBOSE=${MUTATION_VERBOSE:-0}
CASES=0
GOOD=0

cleanup() { [ "${MUTATION_KEEP:-0}" = "1" ] || rm -rf "${WORK:?}"; rm -f "${CAP:?}"; }
trap cleanup EXIT INT TERM

say()  { printf '%s\n' "$1"; }
ok()   { CASES=$((CASES + 1)); GOOD=$((GOOD + 1)); printf '  ok   %s\n' "$1"; }
bad()  { CASES=$((CASES + 1)); printf '  FAIL %s\n' "$1"; }
note() { printf '  --   %s\n' "$1"; }

fresh() {  # fresh <name> -> isolated copy (evals + SKILL + READMEs) for harness mutations
  _n="$1"
  rm -rf "${WORK:?}/$_n"
  mkdir -p "$WORK/$_n"
  cp -R "${HERE:?}" "$WORK/$_n/evals"
  cp "${SKILL_FILE}" "${HERE:?}/../README.md" "${HERE:?}/../README.zh-CN.md" "$WORK/$_n/"
  printf '%s' "$WORK/$_n/evals"
}

run_quiet() {  # run_quiet <dir> ; harness output lands in $CAP
  ( cd "$1" && sh ./run.sh >"$CAP" 2>&1 )
  return $?
}

harness_ran() {
  grep -q '^result: ' "$CAP" 2>/dev/null || grep -q '^  FAIL ' "$CAP" 2>/dev/null
}

harness_failed_for_reason() { grep -q '^  FAIL ' "$CAP" 2>/dev/null; }

# expect <desc> <want: pass|fail> <rc>
expect() {
  _desc="$1"; _want="$2"; _rc="$3"
  if ! harness_ran; then
    bad "$_desc (harness never ran and reported no FAIL line - not evidence either way)"
    if [ "$VERBOSE" = 1 ]; then sed 's/^/    /' "$CAP"; fi
    return
  fi
  if [ "$_want" = pass ]; then
    if [ "$_rc" -eq 0 ]; then ok "$_desc"; else bad "$_desc (expected green, got red)"; fi
  else
    if [ "$_rc" -ne 0 ] && harness_failed_for_reason; then ok "$_desc"
    elif [ "$_rc" -ne 0 ]; then bad "$_desc (non-zero exit with no FAIL line - red unattributable)"
    else bad "$_desc (expected RED, got green - false confidence)"; fi
  fi
}

show() {
  if [ "$VERBOSE" = 1 ]; then
    printf '    --- harness output ---\n'; sed 's/^/    /' "$CAP"; printf '    --- end ---\n'
  fi
}

# ---- M6a helper: mutate an isolated copy, run the harness, judge by target guard ----
dm_case() {  # dm_case <case> <guard-name> <target-file> <mut.py-path>
  _c="$1"; _guard="$2"; _target="$3"; _mut="$4"
  rm -rf "${WORK:?}/$_c"; mkdir -p "${WORK:?}/$_c"
  cp -R "${HERE:?}" "$WORK/$_c/evals"
  cp "${SKILL_FILE}" "${HERE:?}/../README.md" "${HERE:?}/../README.zh-CN.md" "$WORK/$_c/"
  # the mutation target file is ALWAYS the last argument
  if ! python3 "$_mut" "$WORK/$_c/SKILL.md" "$WORK/$_c/README.md" "$WORK/$_c/README.zh-CN.md" \
      "$WORK/$_c/evals/test-prompts.json" "$WORK/$_c/evals/expected-findings.json" "$WORK/$_c/$_target" \
      >"$WORK/$_c/mut.log" 2>&1; then
    # a mutation whose anchor no longer exists proves nothing: report it as its own failure
    # mode instead of letting it look like "the guard did not fire".
    bad "$_c (mutation did not apply - anchor missing; see $WORK/$_c/mut.log)"
    [ "$VERBOSE" = 1 ] && sed 's/^/    /' "$WORK/$_c/mut.log"
    return
  fi
  rc=0; ( cd "$WORK/$_c/evals" && sh ./run.sh >"$CAP" 2>&1 ) || rc=$?
  if ! harness_ran; then
    bad "$_c (harness never ran - not evidence)"; [ "$VERBOSE" = 1 ] && sed 's/^/    /' "$CAP"; return
  fi
  if [ "$rc" -ne 0 ] && grep -q "FAIL $_guard" "$CAP"; then ok "$_c"
  else bad "$_c (expected red via $_guard; rc=$rc)"; fi
}

say '[M1] baseline: unmutated harness must be green'
E=$(fresh m1); rc=0; run_quiet "$E" || rc=$?; show
expect "M1 normal harness is green" pass "$rc"

say '[M2] mutation: delete a copied fixture (changed/test_service.py)'
E=$(fresh m2); rm -f "$E/fixtures/changed/test_service.py"
rc=0; run_quiet "$E" || rc=$?; show
expect "M2 deleting a fixture turns the harness RED" fail "$rc"

say '[M3] mutation: delete a requirement SPEC (HIGH_RISK_SPEC.md)'
E=$(fresh m3); rm -f "$E/fixtures/HIGH_RISK_SPEC.md"
rc=0; run_quiet "$E" || rc=$?; show
expect "M3 deleting a requirement spec turns the harness RED" fail "$rc"

say '[M4] mutation: break the upstream push (trap never armed)'
E=$(fresh m4)
sed -i.bak 's|git push -q -u origin feature-x|git remote set-url origin /nonexistent-cr-mutation-remote.git; git push -q -u origin feature-x|' "$E/run.sh"
rm -f "$E/run.sh.bak"
rc=0; run_quiet "$E" || rc=$?; show
expect "M4 an unarmed upstream trap turns the harness RED" fail "$rc"
if harness_ran && grep -q 'upstream NOT armed' "$CAP"; then
  ok "M4b the red came from the arming guard, not an unrelated crash"
fi

say '[M5] mutation: fix a planted defect (spec-1 skip branch, respelled)'
E=$(fresh m5)
python3 - "$E/fixtures/changed/invoice.py" <<'PY'
import sys
p = sys.argv[-1]
s = open(p).read()
s = s.replace('        s += ln["price"] * ln["qty"]',
              '        p = ln.get("price")\n        if p is None:\n            continue\n        s += p * ln["qty"]')
open(p, 'w').write(s)
PY
rc=0; run_quiet "$E" || rc=$?; show
expect "M5 fixing spec-1 turns the harness RED" fail "$rc"

say '[M6] mutation: respell a planted defect (assert instead of raise ValueError)'
E=$(fresh m6)
python3 - "$E/fixtures/changed/invoice.py" <<'PY'
import sys
p = sys.argv[-1]
s = open(p).read()
s = s.replace('    return t * (1 - pct / 100)',
              '    assert 0 <= pct <= 100\n    return t * (1 - pct / 100)')
open(p, 'w').write(s)
PY
rc=0; run_quiet "$E" || rc=$?; show
expect "M6 respelling spec-3 still turns the harness RED" fail "$rc"

say '[M7] mutation: desync the two scenario JSONs (rename one id)'
E=$(fresh m7)
python3 - "$E/test-prompts.json" <<'PY'
import sys
p = sys.argv[-1]
s = open(p).read().replace('v2-tool-fusion-12', 'v2-tool-fusion-12-renamed', 1)
open(p, 'w').write(s)
PY
rc=0; run_quiet "$E" || rc=$?; show
expect "M7 a desynced scenario id turns the harness RED" fail "$rc"

say '[M8] restore: a fresh copy must be green again (no residue)'
E=$(fresh m8); rc=0; run_quiet "$E" || rc=$?; show
expect "M8 restored harness is green" pass "$rc"

# ---- M6a: deterministic mutations (DM1-DM13) ----

say '[DM1] duplicate a procedure ID in the registry'
M="$WORK/dm1.py"
printf '%s\n' \
  "import sys" \
  "p = sys.argv[-1]" \
  "s = open(p).read()" \
  "s = s.replace('| A.1 | Requirement Trace | CORE |', '| A.1 | Requirement Trace | CORE |' + chr(10) + '| A.1 | Duplicate Row | CORE |', 1)" \
  "open(p, 'w').write(s)" > "$M"
dm_case dm1 procedure_ids_unique SKILL.md "$M"

say '[DM2] invalid parent letter (A.1 -> Z.1)'
M="$WORK/dm2.py"
printf '%s\n' \
  "import sys" \
  "p = sys.argv[-1]" \
  "s = open(p).read().replace('| A.1 |', '| Z.1 |', 1)" \
  "open(p, 'w').write(s)" > "$M"
dm_case dm2 procedure_parents_valid SKILL.md "$M"

say '[DM3] Selection Matrix changed without touching the frozen JSON'
M="$WORK/dm3.py"
printf '%s\n' \
  "import sys" \
  "p = sys.argv[-1]" \
  "s = open(p).read()" \
  "s = s.replace('| R1_S1_minimum | A.1, A.2, B.1, C.2, E.1, G.1, I.1, J.1, J.2, J.3 |', '| R1_S1_minimum | A.1, A.2, B.1, C.2, E.1, F.2, G.2, I.1, J.1, J.2, J.3 |', 1)" \
  "open(p, 'w').write(s)" > "$M"
dm_case dm3 selection_matrix_expected_sync SKILL.md "$M"

say '[DM4] README references a non-registry dotted ID (A.999)'
M="$WORK/dm4.py"
printf '%s\n' \
  "import sys" \
  "p = sys.argv[-1]" \
  "s = open(p).read() + '\nA.999 fake procedure reference\n'" \
  "open(p, 'w').write(s)" > "$M"
dm_case dm4 readme_dotted_procedure_ids_valid README.md "$M"

say '[DM5] README retains a legacy bare procedure ID (G2)'
M="$WORK/dm5.py"
printf '%s\n' \
  "import sys" \
  "p = sys.argv[-1]" \
  "s = open(p).read() + '\nG2 Mutation Challenge was here (legacy spelling)\n'" \
  "open(p, 'w').write(s)" > "$M"
dm_case dm5 readme_legacy_procedure_ids_absent README.md "$M"

say '[DM6] SKILL.md grows past the 640-line budget'
M="$WORK/dm6.py"
printf '%s\n' \
  "import sys" \
  "p = sys.argv[-1]" \
  "s = open(p).read() + ('# budget pad' + chr(10)) * 80" \
  "open(p, 'w').write(s)" > "$M"
dm_case dm6 skill_line_budget SKILL.md "$M"

say '[DM7] Group E contract field deleted from expected-findings'
M="$WORK/dm7.py"
printf '%s\n' \
  "import json, sys" \
  "p = sys.argv[-1]" \
  "d = json.load(open(p, encoding='utf-8'))" \
  "d['scenarios']['v21-prc02-r3-16'].pop('must_select_procedures', None)" \
  "json.dump(d, open(p, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)" > "$M"
dm_case dm7 group_e_contract_fields_present evals/expected-findings.json "$M"

say '[DM8] Review Sufficiency enum deleted from SKILL.md'
M="$WORK/dm8.py"
printf '%s\n' \
  "import sys" \
  "p = sys.argv[-1]" \
  "s = open(p).read().replace('Review Sufficiency: <SUFFICIENT | LIMITED | INSUFFICIENT>', 'Review Sufficiency: <result>')" \
  "open(p, 'w').write(s)" > "$M"
dm_case dm8 report_contract_markers_present SKILL.md "$M"

# ---- M6a (F1b): mutations for the guards added with the 4.3 fix (DM9-DM13) ----

say '[DM9] the route-floor sentence deleted from 4.3'
M="$WORK/dm9.py"
cat > "$M" <<'DMEOF'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
old = ("The **route minimum is the floor for every route**: `R1_S1_minimum` is required in all cases, and\n"
       "R2/S2, R3 and S3 add their rows on top of it. A route never replaces the floor.")
assert old in s, "anchor missing"
open(p, "w", encoding="utf-8").write(s.replace(old, "The route minimums are the tables below.", 1))
DMEOF
dm_case dm9 route_floor_stated SKILL.md "$M"

say '[DM10] the R3_minimum constraint row deleted from SKILL.md and the frozen JSON'
M="$WORK/dm10.py"
cat > "$M" <<'DMEOF'
import json, os, sys
skill = sys.argv[1]
fx = os.path.join(os.path.dirname(skill), "evals", "fixtures", "procedure-selection.json")
s = open(skill, encoding="utf-8").read()
row = "| R3_minimum | >= 1 ADVERSARIAL; >= 1 corroboration; critical-path reread | route |\n"
assert row in s, "anchor missing"
open(skill, "w", encoding="utf-8").write(s.replace(row, "", 1))
d = json.load(open(fx, encoding="utf-8"))
d["rows"] = [r for r in d["rows"] if r["key"] != "R3_minimum"]
json.dump(d, open(fx, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
DMEOF
dm_case dm10 r3_minimum_present evals/fixtures/procedure-selection.json "$M"

say '[DM11] an adversarial procedure added to the route floor in SKILL.md AND the JSON'
M="$WORK/dm11.py"
cat > "$M" <<'DMEOF'
import json, os, sys
skill = sys.argv[1]
fx = os.path.join(os.path.dirname(skill), "evals", "fixtures", "procedure-selection.json")
old = "| R1_S1_minimum | A.1, A.2, B.1, C.2, E.1, G.1, I.1, J.1, J.2, J.3 | route |"
new = "| R1_S1_minimum | A.1, A.2, B.1, C.2, E.1, F.1, G.1, I.1, J.1, J.2, J.3 | route |"
s = open(skill, encoding="utf-8").read()
assert old in s, "anchor missing"
open(skill, "w", encoding="utf-8").write(s.replace(old, new, 1))
d = json.load(open(fx, encoding="utf-8"))
for r in d["rows"]:
    if r["key"] == "R1_S1_minimum":
        r["ids"] = sorted(set(r["ids"]) | {"F.1"})
json.dump(d, open(fx, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
DMEOF
dm_case dm11 r1_no_default_adversarial evals/fixtures/procedure-selection.json "$M"

say '[DM12] the negative-control disclosure rule deleted from 5a'
M="$WORK/dm12.py"
cat > "$M" <<'DMEOF'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
old = ("**Negative-control disclosure**: procedures with the `ADVERSARIAL` or `DYNAMIC` attribute form the\n"
       "disclosure-eligible universe = {D.3, F.1, F.2, F.3, F.5, G.2}. Whenever such a procedure is\n"
       "`NOT_SELECTED`, it must be listed under `Not selected by routing` with a reason (intersection with\n"
       "this universe, deduplicated, sorted by ID). R1 may use the compressed one-line form.")
assert old in s, "anchor missing"
open(p, "w", encoding="utf-8").write(s.replace(old, "Procedure attributes are informational.", 1))
DMEOF
dm_case dm12 disclosure_rule_stated SKILL.md "$M"

say '[DM13] the Not-selected disclosure block deleted from the section 8 reporting contract'
M="$WORK/dm13.py"
cat > "$M" <<'DMEOF'
import re, sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
m = re.search(r"Not selected by routing:\n<every NOT_SELECTED procedure[^>]*>\n\n", s)
assert m, "anchor missing"
open(p, "w", encoding="utf-8").write(s[:m.start()] + s[m.end():])
DMEOF
dm_case dm13 report_contract_markers_present SKILL.md "$M"

say ""
say "mutation test: $GOOD/$CASES cases behaved as required"
if [ "$GOOD" -ne "$CASES" ]; then
  say "The harness has a false-confidence path: a mutation that should fail silently passed,"
  say "or the harness could not run at all (which is not evidence either way)."
  exit 1
fi
say "All failure paths are armed: the harness goes red exactly when its condition stops holding."
