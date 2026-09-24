#!/bin/sh
# code-review skill — failure-injection (mutation) test for the deterministic harness.
#
# A green run.sh is NOT evidence. This script proves the harness's checks actually go RED
# when their condition stops holding:
#
#   M1  normal                     -> PASS   (baseline: the harness is green when healthy)
#   M2  delete a copied fixture    -> RED attributable to the missing-fixture guard  (CR-002)
#   M3  delete a requirement SPEC  -> RED attributable to the missing-fixture guard  (CR-002)
#   M4  break the upstream push    -> RED attributable to the arming guard           (CR-003)
#   M5  fix a planted defect       -> RED attributable to the spec-1 drift guard     (CR-001)
#   M6  respell a planted defect   -> RED attributable to the spec-3 drift guard     (CR-001)
#   M7  desync the scenario JSONs  -> RED attributable to the id-sync guard          (OR-009)
#   M8  restore everything         -> PASS
#
#   DM1-DM22 (M6a, V2.1): every procedure-framework guard has its own injected failure,
#   and each red must be attributable to the target guard name (MS-001 discipline).
#
# Isolation rule: harness mutations run against throwaway copies under $WORK; the repo is
# never touched. M6b (agent-level SKILL mutations) is documented separately in
# evals/procedure-mutation-plan.md and never touches the canonical SKILL.md.
#
# Attribution rules (MS-001, tightened by the PRE-0 maintenance patch): "red" counts only
# when the harness output carries the TARGET guard's FAIL marker; a non-zero exit without
# one, a crash, or a decoy failure is not evidence. Every harness mutation must also prove
# it was actually applied (mut_applied) before the harness runs, and the judge itself is
# refutable: the ST cases at the end feed synthetic output to expect_red_for/mut_applied
# and require the verdict to flip in both directions.
#
# Usage: ./evals/mutation-test.sh
# Env:   MUTATION_VERBOSE=1 | MUTATION_KEEP=1

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

fresh() {  # fresh <name> -> isolated copy (evals + SKILL + READMEs + release-evals)
  _n="$1"
  rm -rf "${WORK:?}/$_n"
  mkdir -p "$WORK/$_n"
  cp -R "${HERE:?}" "$WORK/$_n/evals"
  cp "${SKILL_FILE}" "${HERE:?}/../README.md" "${HERE:?}/../README.zh-CN.md" "$WORK/$_n/"
  cp -R "${HERE:?}/../release-evals" "$WORK/$_n/release-evals"
  printf '%s' "$WORK/$_n/evals"
}

run_quiet() {  # run_quiet <dir> ; harness output lands in $CAP
  ( cd "$1" && sh ./run.sh >"$CAP" 2>&1 )
  return $?
}

harness_ran() {
  grep -q '^result: ' "$CAP" 2>/dev/null || grep -q '^  FAIL ' "$CAP" 2>/dev/null
}

# expect <desc> pass <rc>  — green-path judgement only (M1/M8). Red paths must use
# expect_red_for: a bare "any FAIL line" judge cannot tell the target guard from a decoy
# (the disease the legacy M2/M3/M5-M7 suffered from, closed by the PRE-0 patch).
expect() {
  _desc="$1"; _want="$2"; _rc="$3"
  if [ "$_want" != pass ]; then
    bad "$_desc (expect() only judges green paths; use expect_red_for)"
    return
  fi
  if ! harness_ran; then
    bad "$_desc (harness never ran and reported no FAIL line - not evidence either way)"
    if [ "$VERBOSE" = 1 ]; then sed 's/^/    /' "$CAP"; fi
    return
  fi
  if [ "$_rc" -eq 0 ]; then ok "$_desc"; else bad "$_desc (expected green, got red)"; fi
}

# expect_red_for <desc> <rc> <target-fail-marker>
# Attributed red (MS-001): the case counts only when the harness exited non-zero AND its
# output carries the TARGET guard's FAIL line. A non-zero exit, a crash, or a decoy FAIL
# without the target marker is not evidence for this case.
expect_red_for() {
  _desc="$1"; _rc="$2"; _target="$3"
  if ! harness_ran; then
    bad "$_desc (harness never ran and reported no FAIL line - not evidence either way)"
    if [ "$VERBOSE" = 1 ]; then sed 's/^/    /' "$CAP"; fi
    return
  fi
  if [ "$_rc" -eq 0 ]; then
    bad "$_desc (expected RED via '$_target', got green - false confidence)"
    return
  fi
  if grep -qF -- "  FAIL $_target" "$CAP"; then
    ok "$_desc"
  else
    bad "$_desc (red not attributable: target marker '$_target' absent from harness output)"
    if [ "$VERBOSE" = 1 ]; then sed 's/^/    /' "$CAP"; fi
  fi
}

# mut_applied <desc> <test-args...> — the mutation itself must be proven applied before the
# harness runs; a mutation that silently did not happen proves nothing about the guard.
mut_applied() {
  _desc="$1"; shift
  if "$@"; then return 0; fi
  bad "$_desc"
  return 1
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
  cp -R "${HERE:?}/../release-evals" "$WORK/$_c/release-evals"
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
rc=0
if mut_applied "M2 mutation did not apply (fixture still present)" test ! -f "$E/fixtures/changed/test_service.py"; then
  run_quiet "$E" || rc=$?; show
  expect_red_for "M2 deleting a fixture turns the harness RED (missing-fixture guard)" "$rc" \
    "missing fixtures/changed/test_service.py"
fi

say '[M3] mutation: delete a requirement SPEC (HIGH_RISK_SPEC.md)'
E=$(fresh m3); rm -f "$E/fixtures/HIGH_RISK_SPEC.md"
rc=0
if mut_applied "M3 mutation did not apply (spec still present)" test ! -f "$E/fixtures/HIGH_RISK_SPEC.md"; then
  run_quiet "$E" || rc=$?; show
  expect_red_for "M3 deleting a requirement spec turns the harness RED (missing-fixture guard)" "$rc" \
    "missing fixtures/HIGH_RISK_SPEC.md"
fi

say '[M4] mutation: break the upstream push (trap never armed)'
E=$(fresh m4)
sed -i.bak 's|git push -q -u origin feature-x|git remote set-url origin /nonexistent-cr-mutation-remote.git; git push -q -u origin feature-x|' "$E/run.sh"
rm -f "$E/run.sh.bak"
rc=0
if mut_applied "M4 mutation did not apply (run.sh unchanged)" grep -q 'nonexistent-cr-mutation-remote' "$E/run.sh"; then
  run_quiet "$E" || rc=$?; show
  expect_red_for "M4 an unarmed upstream trap turns the harness RED (arming guard)" "$rc" \
    "upstream NOT armed"
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
rc=0
if mut_applied "M5 mutation did not apply (skip branch absent)" grep -q 'if p is None:' "$E/fixtures/changed/invoice.py"; then
  run_quiet "$E" || rc=$?; show
  expect_red_for "M5 fixing spec-1 turns the harness RED (spec-1 drift guard)" "$rc" \
    "drift: total() no longer raises"
fi

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
rc=0
if mut_applied "M6 mutation did not apply (assert absent)" grep -q 'assert 0 <= pct <= 100' "$E/fixtures/changed/invoice.py"; then
  run_quiet "$E" || rc=$?; show
  expect_red_for "M6 respelling spec-3 still turns the harness RED (spec-3 drift guard)" "$rc" \
    "drift: apply_discount now validates"
fi

say '[M7] mutation: desync the two scenario JSONs (rename one id)'
E=$(fresh m7)
python3 - "$E/test-prompts.json" <<'PY'
import sys
p = sys.argv[-1]
s = open(p).read().replace('v2-tool-fusion-12', 'v2-tool-fusion-12-renamed', 1)
open(p, 'w').write(s)
PY
rc=0
if mut_applied "M7 mutation did not apply (id unchanged)" grep -q 'v2-tool-fusion-12-renamed' "$E/test-prompts.json"; then
  run_quiet "$E" || rc=$?; show
  expect_red_for "M7 a desynced scenario id turns the harness RED (id-sync guard)" "$rc" \
    "scenario JSONs invalid or desynchronized"
fi

say '[M8] restore: a fresh copy must be green again (no residue)'
E=$(fresh m8); rc=0; run_quiet "$E" || rc=$?; show
expect "M8 restored harness is green" pass "$rc"

# ---- M6a: deterministic mutations (DM1-DM22) ----

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
old = ("The **route minimum is the floor for every route**: `R1_S1_minimum` is always required, and R2/S2,\n"
       "R3 and S3 add their rows on top of it. The floor plus `R3_minimum` is what \"route minimum\" means.")
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

say '[DM14] the planted authz bypass restored (fixture drift probe must fire)'
M="$WORK/dm14.py"
cat > "$M" <<'DMEOF'
import sys
p = sys.argv[-1]
s = open(p, encoding="utf-8").read()
old = "def get_record(user, record):\n    return DB[record[\"id\"]]"
new = ("def get_record(user, record):\n"
       "    if record[\"owner\"] != user[\"id\"] and user.get(\"role\") != \"admin\":\n"
       "        raise PermissionError(\"forbidden\")\n"
       "    return DB[record[\"id\"]]")
assert old in s, "anchor missing"
open(p, "w", encoding="utf-8").write(s.replace(old, new, 1))
DMEOF
dm_case dm14 "drift: records.py ownership check restored" evals/fixtures/changed/records.py "$M"

say '[DM15] the real release gate restored in check.sh (fixture drift probe must fire)'
M="$WORK/dm15.py"
cat > "$M" <<'DMEOF'
import sys
p = sys.argv[-1]
s = open(p, encoding="utf-8").read()
old = '#!/bin/sh\n# release verifier\necho "verify OK"\n'
new = ('#!/bin/sh\n# release verifier: the build report must carry the verification marker\n'
       'grep -q "STATUS: VERIFIED" build/report.txt || { echo "verify FAILED"; exit 1; }\n'
       'echo "verify OK"\n')
assert old in s, "anchor missing"
open(p, "w", encoding="utf-8").write(s.replace(old, new, 1))
DMEOF
dm_case dm15 "drift: check.sh no longer passes unconditionally" evals/fixtures/changed/check.sh "$M"

say '[DM16] the guard block crashes halfway (partial green must read as red)'
M="$WORK/dm16.py"
cat > "$M" <<'DMEOF'
import sys
p = sys.argv[-1]
s = open(p, encoding="utf-8").read()
anchor = 'ok("procedure_count_exactly_30")'
assert anchor in s, "anchor missing"
open(p, "w", encoding="utf-8").write(
    s.replace(anchor, anchor + '\nimport sys as _s; _s.stdout.flush(); import os as _o; _o._exit(3)', 1))
DMEOF
dm_case dm16 "v21 registry guard block did not run to completion" evals/run.sh "$M"

say '[DM17] the frozen Selection-Matrix expectation deleted (skip must read as red)'
M="$WORK/dm17.py"
cat > "$M" <<'DMEOF'
import os, sys
os.remove(sys.argv[-1])
DMEOF
dm_case dm17 selection_expectation_file_present evals/fixtures/procedure-selection.json "$M"

say '[DM18] disclosure_eligible_universe removed from the frozen expectation'
M="$WORK/dm18.py"
cat > "$M" <<'DMEOF'
import json, sys
p = sys.argv[-1]
d = json.load(open(p, encoding="utf-8"))
del d["disclosure_eligible_universe"]
json.dump(d, open(p, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
DMEOF
dm_case dm18 frozen_universe_field_in_sync evals/fixtures/procedure-selection.json "$M"

say '[DM18b] r1_forbidden_defaults removed from the frozen expectation'
M="$WORK/dm18b.py"
cat > "$M" <<'DMEOF'
import json, sys
p = sys.argv[-1]
d = json.load(open(p, encoding="utf-8"))
del d["r1_forbidden_defaults"]
json.dump(d, open(p, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
DMEOF
dm_case dm18b r1_forbidden_defaults_in_sync evals/fixtures/procedure-selection.json "$M"

say '[DM19] a scenario deleted jointly from BOTH JSONs (the frozen set must fire)'
M="$WORK/dm19.py"
cat > "$M" <<'DMEOF'
import json, os, sys
root = os.path.dirname(sys.argv[-1])          # .../evals
sid = "v21-prc07-r3-nosurface-21"
tp = json.load(open(os.path.join(root, "test-prompts.json"), encoding="utf-8"))
tp["test_cases"] = [c for c in tp["test_cases"] if c["id"] != sid]
json.dump(tp, open(os.path.join(root, "test-prompts.json"), "w", encoding="utf-8"), indent=2, ensure_ascii=False)
ef = json.load(open(os.path.join(root, "expected-findings.json"), encoding="utf-8"))
ef["scenarios"].pop(sid, None)
json.dump(ef, open(os.path.join(root, "expected-findings.json"), "w", encoding="utf-8"), indent=2, ensure_ascii=False)
DMEOF
dm_case dm19 "scenario JSONs invalid or desynchronized" evals/test-prompts.json "$M"

say '[DM20] the independence priority sentence deleted'
M="$WORK/dm20.py"
cat > "$M" <<'DMEOF'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
old = "Priority: `author-self-review` > `sequential-fallback` >\n`independent-pass`."
assert old in s, "anchor missing"
open(p, "w", encoding="utf-8").write(s.replace(old, "Priority: the three independence states.", 1))
DMEOF
dm_case dm20 review_independence_rule_stated SKILL.md "$M"

say '[DM21] the brief-contract sentence deleted (facts/interpretations + Fact Pack provenance)'
M="$WORK/dm21.py"
cat > "$M" <<'DMEOF'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
old = ("facts pass,\n"
       "interpretations do not; Fact Pack fields come from their declared resolvers and are never\n"
       "hand-edited); and zero coordinator findings, suspicions, or reasoning reaching the reviewer.")
assert old in s, "anchor missing"
open(p, "w", encoding="utf-8").write(s.replace(old, "the task verbatim); and no coordinator findings or suspicions reaching the reviewer.", 1))
DMEOF
dm_case dm21 brief_contract_stated SKILL.md "$M"

say '[DM22] the Review independence marker line deleted from the report contract'
M="$WORK/dm22.py"
cat > "$M" <<'DMEOF'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
old = "Review independence: <author-self-review | sequential-fallback | independent-pass> — <reason>\n"
assert old in s, "anchor missing"
open(p, "w", encoding="utf-8").write(s.replace(old, "", 1))
DMEOF
dm_case dm22 report_contract_markers_present SKILL.md "$M"

# ---- M7 (V2.3): Detection Profile contract guards (DM23-DM30) ----

say '[DM23] the Detection Profiles identity invariant reworded'
M="$WORK/dm23.py"
cat > "$M" <<'DMEOF'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
old = "no selection state, no status of their own"
assert old in s, "anchor missing"
open(p, "w", encoding="utf-8").write(s.replace(old, "a selection state and their own status", 1))
DMEOF
dm_case dm23 detection_contracts_stated SKILL.md "$M"

say '[DM24] a detection evidence token renamed (enum incomplete)'
M="$WORK/dm24.py"
cat > "$M" <<'DMEOF'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
old = "chain_edge"
assert old in s, "anchor missing"
open(p, "w", encoding="utf-8").write(s.replace(old, "chain-link", 1))
DMEOF
dm_case dm24 detection_evidence_contract_stated SKILL.md "$M"

say '[DM25] the S3 impact-map global cap unbounded'
M="$WORK/dm25.py"
cat > "$M" <<'DMEOF'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
old = "S3≤90"
assert old in s, "anchor missing"
open(p, "w", encoding="utf-8").write(s.replace(old, "S3≤unbounded", 1))
DMEOF
dm_case dm25 impact_map_contract_stated SKILL.md "$M"

say '[DM26] guard-weakening triage downgraded from 100% to sampled'
M="$WORK/dm26.py"
cat > "$M" <<'DMEOF'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
old = "100% of deleted"
assert old in s, "anchor missing"
open(p, "w", encoding="utf-8").write(s.replace(old, "sampled deleted", 1))
DMEOF
dm_case dm26 guard_weakening_contract_stated SKILL.md "$M"

say '[DM27] the bounded-shrink marker renamed'
M="$WORK/dm27.py"
cat > "$M" <<'DMEOF'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
old = "minimization_exhausted"
assert old in s, "anchor missing"
open(p, "w", encoding="utf-8").write(s.replace(old, "shrink_exhausted", 1))
DMEOF
dm_case dm27 adversarial_synthesis_contract_stated SKILL.md "$M"

say '[DM28] the differential comparability gate assumed'
M="$WORK/dm28.py"
cat > "$M" <<'DMEOF'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
old = "comparable=YES"
assert old in s, "anchor missing"
open(p, "w", encoding="utf-8").write(s.replace(old, "comparable=assumed", 1))
DMEOF
dm_case dm28 differential_contract_stated SKILL.md "$M"

say '[DM29] the co-occurrence prohibition reworded away'
M="$WORK/dm29.py"
cat > "$M" <<'DMEOF'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
old = "co-occurrence"
assert old in s, "anchor missing"
open(p, "w", encoding="utf-8").write(s.replace(old, "co-location", 1))
DMEOF
dm_case dm29 exploit_chain_contract_stated SKILL.md "$M"

say '[DM30] the benchmark manifest deleted'
M="$WORK/dm30.py"
cat > "$M" <<'DMEOF'
import os, sys
os.remove(sys.argv[-1])
DMEOF
dm_case dm30 benchmark_manifest_valid release-evals/v23/benchmark-manifest.json "$M"

# ---- ST: the attribution judge itself must be refutable (MS-001 applied to the referee) ----
# A judge that accepts any FAIL line cannot tell a target red from a decoy. These cases feed
# synthetic harness output to expect_red_for/mut_applied and require the verdict to flip in
# BOTH directions; a self-test that could only ever pass would prove nothing.
_scap=$CAP
CAP="$WORK/st-cap.txt"

say '[ST-A] attributed red with the target marker present counts as evidence'
printf '  ok   some guard\n  FAIL drift: total() no longer raises - spec-1 defect gone\nresult: 9 passed, 1 failed\n' > "$CAP"
case "$(expect_red_for "ST-A target-attributed red" 1 "drift: total() no longer raises")" in
  '  ok '*) ok "ST-A attributed red with the target marker present judges OK" ;;
  *) bad "ST-A attributed red with the target marker present judges OK" ;;
esac

say '[ST-B] a decoy FAIL without the target marker must be rejected'
printf '  FAIL drift: some unrelated guard fired\nresult: 9 passed, 1 failed\n' > "$CAP"
case "$(expect_red_for "ST-B decoy-only red" 1 "drift: total() no longer raises")" in
  '  FAIL '*) ok "ST-B decoy-only red is rejected as unattributable" ;;
  *) bad "ST-B decoy-only red is rejected as unattributable" ;;
esac

say '[ST-C] a green run must not count as the expected red'
printf '  ok   all guards\nresult: 10 passed, 0 failed\n' > "$CAP"
case "$(expect_red_for "ST-C green is not red" 0 "drift: total() no longer raises")" in
  '  FAIL '*) ok "ST-C green output is rejected where red was required" ;;
  *) bad "ST-C green output is rejected where red was required" ;;
esac

say '[ST-D] a harness that never ran is not evidence'
: > "$CAP"
case "$(expect_red_for "ST-D never ran" 1 "drift: total() no longer raises")" in
  '  FAIL '*) ok "ST-D harness-never-ran is rejected as evidence" ;;
  *) bad "ST-D harness-never-ran is rejected as evidence" ;;
esac

say '[ST-E] an unapplied mutation is reported as its own failure'
case "$(mut_applied "ST-E mutation did not apply" false)" in
  '  FAIL '*) ok "ST-E unapplied mutation is its own failure mode" ;;
  *) bad "ST-E unapplied mutation is its own failure mode" ;;
esac

say '[ST-F] an applied mutation stays silent on success'
if _st_out=$(mut_applied "ST-F should not fire" test -f "$HERE/run.sh") && [ -z "$_st_out" ]; then
  ok "ST-F applied mutation is silent on success"
else
  bad "ST-F applied mutation is silent on success"
fi

CAP=$_scap

say ""
say "mutation test: $GOOD/$CASES cases behaved as required"
if [ "$GOOD" -ne "$CASES" ]; then
  say "The harness has a false-confidence path: a mutation that should fail silently passed,"
  say "or the harness could not run at all (which is not evidence either way)."
  exit 1
fi
say "All failure paths are armed: the harness goes red exactly when its condition stops holding."
