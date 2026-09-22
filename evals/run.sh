#!/bin/sh
# code-review skill — deterministic eval plumbing (no LLM involved).
#
# Builds the fixtures, then checks the deterministic layer the skill depends on:
#   1. fixture integrity    — planted defects still present, proven BEHAVIOURALLY
#   2. ocr delegate preview — workspace scope resolution + exclusion detection
#   3. ocr scan --preview   — whole-repo enumeration without an LLM endpoint
#   4. upstream trap        — proves why base must not be the tracking upstream
#   5. R3 security fixture  — command-injection path + weak implementation-shaped test
#   6. S3 integration fixture — >20-file change + stale unchanged consumer contract
#
# Design rule (audit CR-001): a planted defect that a pure function can demonstrate is
# asserted by RUNNING that function, never by matching source strings. String guards are
# reserved for fixture markers, schema keys, and known static tokens.
#
# Failure-injection counterpart: evals/mutation-test.sh proves the checks below actually
# go red when their condition stops holding. A green run.sh alone is not evidence.
#
# Agent-level behaviour (A–J coverage, verdicts) is covered by evals/test-prompts.json.
# Judge-level scoring is covered by evals/judge-rubric.md.

set -u

HERE=$(cd "$(dirname "$0")" && pwd)
FIX="$HERE/fixtures"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/cr-eval.XXXXXX")
# Keep the workspace for inspection with CR_EVAL_KEEP=1; otherwise remove it on exit so
# repeated runs do not accumulate git repos (audit CR-011).
cleanup() { [ "${CR_EVAL_KEEP:-0}" = "1" ] || rm -rf "${WORK:?}"; }
trap cleanup EXIT INT TERM
PASS=0
FAIL=0

ok()  { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; }
note(){ printf '  --   %s\n' "$1"; }

# assert_grep <pattern> <file> <pass-msg> <fail-msg>  — static markers only
assert_grep() {
  if grep -q -- "$1" "$2"; then ok "$3"; else bad "$4"; fi
}

# behave <dir> <pass-msg> <fail-msg> <python-code>
# Runs <python-code> with the fixture dir on sys.path and as cwd. Exit 0 => the asserted
# condition holds (defect still planted / contract still broken). Non-zero => drift.
behave() {
  _d="$1"; _ok="$2"; _bad="$3"; _code="$4"
  if PROBE_DIR="$_d" PYTHONDONTWRITEBYTECODE=1 python3 -c "$_code" >/dev/null 2>&1; then
    ok "$_ok"
  else
    bad "$_bad"
  fi
}

# require <relpath-under-fixtures> — existence, reported as a failure
require() {
  if [ -f "$FIX/$1" ]; then return 0; fi
  bad "missing fixtures/$1"
  return 1
}

# cp_guard <relpath-under-fixtures> <destination>
cp_guard() {
  if cp "$FIX/$1" "$2" 2>/dev/null; then return 0; fi
  bad "fixture copy failed: $1"
  return 1
}

# ocr_run <outfile> <ocr args...> — runs ocr, preserves stderr for diagnosis.
# Discarding stderr made an OCR tool failure indistinguishable from fixture drift (audit OR-012).
ocr_run() {
  _o="$1"; shift
  if ocr "$@" >"$_o" 2>"$_o.err"; then return 0; fi
  note "ocr $* failed: $(head -1 "$_o.err" 2>/dev/null)"
  return 1
}

have_ocr=0
if command -v ocr >/dev/null 2>&1; then have_ocr=1; else note "ocr not on PATH — ocr checks skipped (skill falls back to git diff)"; fi

G() { git -c user.email=eval@local -c user.name=eval "$@"; }

# Every fixture file the harness copies must exist. Copying a missing file used to fail
# silently (audit CR-002).
ALL_FIXTURES="baseline/invoice.py baseline/legacy.py baseline/test_invoice.py
baseline/consumer.py baseline/producer.py baseline/runner.py
changed/invoice.py changed/test_invoice.py changed/runner.py changed/test_runner.py
changed/producer.py changed/test_service.py
SPEC.md HIGH_RISK_SPEC.md CROSSFILE_SPEC.md
PR42_METADATA.json TOOL_REPORT.txt INJECTION_NOTE.txt SECRET_CONFIG.ini
baseline/check.sh changed/check.sh changed/check_test.sh
baseline/records.py changed/records.py changed/test_records.py AUTHZ_SPEC.md
procedure-selection.json"

# ---------------------------------------------------------------- fixtures --
echo '[1/6] fixture integrity'
# The reassuring summary line is emitted only when nothing was missing: a green line beside
# a FAIL is misleading in a release whose thesis is evidence honesty.
MISSING=0
for f in $ALL_FIXTURES; do require "$f" || MISSING=$((MISSING + 1)); done
if [ "$MISSING" -eq 0 ]; then
  ok "all $(echo "$ALL_FIXTURES" | wc -w | tr -d ' ') fixture files present"
else
  bad "$MISSING fixture file(s) missing"
fi

# --- PRC-04 / PRC-06 fixtures: the planted defects must stay planted (MS-V21-05) ---
# Without these, "fixing" either planted defect leaves every other check green, because the two
# new fixtures are only existence-checked; their acceptance value lives in the Group E runs.
CH="$FIX/changed"

behave "$CH" "authz bypass planted (cross-user read returns another user's record)" \
  "drift: records.py ownership check restored — the planted authz bypass is gone" '
import os, sys
d = os.environ["PROBE_DIR"]; sys.path.insert(0, d); os.chdir(d)
from records import get_record
try:
    got = get_record({"id": "alice"}, {"id": "r2", "owner": "bob"})
except PermissionError:
    sys.exit(1)
sys.exit(0 if got.get("owner") == "bob" else 1)'

behave "$CH" "always-pass verifier planted (check.sh succeeds with no build report)" \
  "drift: check.sh no longer passes unconditionally — the planted false-green gate is gone" '
import os, subprocess, sys, tempfile
d = os.environ["PROBE_DIR"]
with tempfile.TemporaryDirectory() as td:
    r = subprocess.run(["sh", os.path.join(d, "check.sh")], cwd=td,
                       capture_output=True, text=True)
sys.exit(0 if r.returncode == 0 and "verify OK" in r.stdout else 1)'

# ------------------------------------------------- V2.1 registry guards (M1) --
echo '[1b/6] V2.1 procedure registry & disclosure universe'
SKILL_FILE="$HERE/../SKILL.md"
# Both READMEs are checked (EN + zh); a dotted procedure ID in either must be a registry
# member, and legacy bare IDs must be absent (E1/E2/E3 excluded - they are evidence grades).
if python3 - "$SKILL_FILE" "$HERE/../README.md" "$HERE/../README.zh-CN.md" "$FIX/procedure-selection.json" "$HERE/test-prompts.json" "$HERE/expected-findings.json" >"$WORK/v21-registry.txt" 2>&1 <<'PY'
import json, os, re, sys
skill_path, readme_en, readme_zh = sys.argv[1:4]
def ok(n): print("GUARD_OK " + n)
def fail(n, d=""): print("GUARD_FAIL " + n + (" - " + d if d else ""))

try:
    skill = open(skill_path, encoding="utf-8").read()
    readmes = [(os.path.basename(p), open(p, encoding="utf-8").read()) for p in (readme_en, readme_zh)]
except OSError as exc:
    fail("skill_registry_inputs_readable", str(exc)); sys.exit(0)
lines = skill.split("\n")

reg = {}
for i, ln in enumerate(lines):
    m = re.match(r"^\|\s*([A-Z]\.[0-9]+)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*$", ln)
    if m:
        reg.setdefault(m.group(1), []).append([a.strip() for a in m.group(3).split(",")])

if len(reg) == 30: ok("procedure_count_exactly_30")
else: fail("procedure_count_exactly_30", f"found {len(reg)} registry rows, expected 30")

dups = sorted(p for p, v in reg.items() if len(v) > 1)
if dups: fail("procedure_ids_unique", f"duplicate rows for {dups}")
else: ok("procedure_ids_unique")

bad_parent = sorted(p for p in reg if p.split(".")[0] not in "ABCDEFGHIJ" or not p.split(".", 1)[1].isdigit())
if bad_parent: fail("procedure_parents_valid", str(bad_parent))
else: ok("procedure_parents_valid")

bare_defs = re.findall(r"^\|\s*[A-J][0-9]+\s*\|", skill, flags=re.M)
if bare_defs: fail("procedure_id_pattern_canonical", f"legacy bare-ID table rows present: {bare_defs}")
else: ok("procedure_id_pattern_canonical")

VALID = {"CORE", "EXTENDED", "ADVERSARIAL", "DYNAMIC"}
bad_attr = sorted((p, a) for p, v in reg.items() for a in v[0] if a not in VALID)
if bad_attr: fail("procedure_attributes_valid", str(bad_attr))
else: ok("procedure_attributes_valid")

universe = sorted(p for p, v in reg.items() if "ADVERSARIAL" in v[0] or "DYNAMIC" in v[0])
if universe == ["D.3", "F.1", "F.2", "F.3", "F.5", "G.2"]:
    ok("disclosure_universe_matches")
else:
    fail("disclosure_universe_matches", f"derived {universe}")

# the disclosure rule itself is normative text, not only registry data (MS-V21-04)
if ("`NOT_SELECTED`, it must be listed under `Not selected by routing`" in skill
        and "**Negative-control disclosure**" in skill):
    ok("disclosure_rule_stated")
else:
    fail("disclosure_rule_stated", "section 5a negative-control disclosure rule missing or reworded")

i5 = next((i for i, l in enumerate(lines) if l.startswith("## 5. Review lenses")), None)
i5a = next((i for i, l in enumerate(lines) if l.startswith("## 5a.")), None)
if i5 is None or i5a is None or i5a <= i5:
    fail("j_procedures_not_business_lens", "section markers not found")
elif re.search(r"J\.[0-9]", "\n".join(lines[i5:i5a])):
    fail("j_procedures_not_business_lens", "J.x referenced inside the lens section")
else:
    ok("j_procedures_not_business_lens")

n_lines = len(lines)
if n_lines <= 640: ok(f"skill_line_budget ({n_lines} <= 640)")
else: fail(f"skill_line_budget ({n_lines} > 640)")

# independence rule + brief contract must be stated in normative text (V2.2)
prio = "Priority: `author-self-review` > `sequential-fallback` >\n`independent-pass`."
if (prio in skill and "author_conflict_status" in skill
        and "is the safe default" in skill
        and "did not put history in the prompt" in skill):
    ok("review_independence_rule_stated")
else:
    fail("review_independence_rule_stated", "independence rule block missing or reworded")
if ("facts pass, interpretations do not" in skill and "Fact Pack" in skill
        and "may not be hand-edited" in skill and "verbatim" in skill):
    ok("brief_contract_stated")
else:
    fail("brief_contract_stated", "independent review brief contract missing or reworded")

# report-contract markers: only proves the section/enums were not deleted wholesale.
# Does NOT prove LLM behaviour - that is Group E + M6b territory.
# Markers must be specific to the section-8 contract itself: the bare phrase "Not selected by
# routing" also occurs in the 5a prose, and the bare enum words also occur in the Sufficiency
# criteria paragraph, so either loose form leaves the guard unarmed (found by DM13 and DM8).
markers = ["## 审查程序", "\nNot selected by routing:",
           "Review Sufficiency: <SUFFICIENT | LIMITED | INSUFFICIENT>",
           "Review independence: <author-self-review | sequential-fallback | independent-pass>"]
missing_m = [m for m in markers if m not in skill]
if missing_m: fail("report_contract_markers_present", f"missing {missing_m}")
else: ok("report_contract_markers_present")

LEGACY = re.compile(r"\b(?:A[1-3]|B[1-3]|C[1-3]|D[1-3]|F[1-5]|G[1-4]|H1|I[12]|J[1-3])\b")
DOTTED = re.compile(r"[A-J]\.[0-9]+")
dotted_bad, legacy_bad = [], []
for name, text in readmes:
    for tok in sorted(set(DOTTED.findall(text))):
        if tok not in reg: dotted_bad.append(f"{name}:{tok}")
    for tok in LEGACY.findall(text):
        legacy_bad.append(f"{name}:{tok}")
if dotted_bad: fail("readme_dotted_procedure_ids_valid", str(dotted_bad))
else: ok("readme_dotted_procedure_ids_valid")
if legacy_bad: fail("readme_legacy_procedure_ids_absent", str(legacy_bad))
else: ok("readme_legacy_procedure_ids_absent")

# Group E machine-readable contract fields must exist on every v21- scenario
try:
    tp = json.load(open(sys.argv[5], encoding="utf-8")) if len(sys.argv) > 5 else None
    ef = json.load(open(sys.argv[6], encoding="utf-8")) if len(sys.argv) > 5 else None
except Exception as exc:
    tp = ef = None; fail("group_e_contract_fields_present", f"json parse: {exc}")
if tp is not None:
    need = ("must_select_procedures", "must_not_select_procedures", "must_exhibit_sufficiency", "must_exhibit_selection_reason")
    v21 = [c["id"] for c in tp["test_cases"] if c["id"].startswith("v21-")]
    miss = [sid for sid in v21 if sid not in ef.get("scenarios", {})
            or any(f not in ef["scenarios"][sid] for f in need)]
    if miss: fail("group_e_contract_fields_present", f"missing fields/entries: {miss}")
    else: ok("group_e_contract_fields_present")

# --- M2: Selection Matrix vs frozen expectation (evaluator-only JSON) ---
sel_path = sys.argv[4] if len(sys.argv) > 4 else None
if not sel_path or not os.path.isfile(sel_path):
    # a missing frozen expectation file must be red, not a silently skipped block
    # (found by the 2026-09-22 whole-repo review; deletion used to stay green at 49/0)
    fail("selection_expectation_file_present", "evals/fixtures/procedure-selection.json missing")
elif True:
    if "<!-- PROCEDURE_SELECTION_BEGIN -->" not in skill or "<!-- PROCEDURE_SELECTION_END -->" not in skill:
        fail("selection_matrix_parseable", "markers missing")
    else:
        ok("selection_matrix_parseable")
        block = skill.split("<!-- PROCEDURE_SELECTION_BEGIN -->", 1)[1].split("<!-- PROCEDURE_SELECTION_END -->", 1)[0]
        mrows, mrow_dups = {}, []
        for ln in block.split("\n"):
            m = re.match(r"^\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*(route|mandatory|advisory)\s*\|\s*$", ln)
            if m:
                key, field = m.group(1), m.group(2)
                if key in mrows: mrow_dups.append(key)
                ids = sorted(set(DOTTED.findall(field)))
                id_only = re.fullmatch(r"[A-Z]\.[0-9]+(?:, [A-Z]\.[0-9]+)*", field.strip()) is not None
                constraints = [] if id_only else [c.strip() for c in field.split(";") if c.strip()]
                mrows[key] = {"class": m.group(3), "ids": ids, "constraints": constraints}
        if mrow_dups: fail("selection_rows_unique", f"duplicate keys: {mrow_dups}")
        else: ok("selection_rows_unique")
        unknown = sorted({i for v in mrows.values() for i in v["ids"]} - set(reg))
        if unknown: fail("selection_ids_exist", f"matrix ids not in registry: {unknown}")
        else: ok("selection_ids_exist")
        mand = sorted(k for k, v in mrows.items() if v["class"] == "mandatory")
        adv = sorted(k for k, v in mrows.items() if v["class"] == "advisory")
        if len(mand) == 4 and len(adv) == 6: ok("mandatory_advisory_classification_stable")
        else: fail("mandatory_advisory_classification_stable", f"mandatory={len(mand)} advisory={len(adv)}")
        # the floor rule must be stated in normative text, not only implied by a row name
        if "route minimum is the floor for every route" in skill: ok("route_floor_stated")
        else: fail("route_floor_stated", "floor sentence missing from section 4.3")
        r3 = mrows.get("R3_minimum")
        r3txt = " ".join(r3.get("constraints", [])) if r3 else ""
        r1_ids = mrows.get("R1_S1_minimum", {}).get("ids", [])
        if (r3 and r3.get("class") == "route" and "ADVERSARIAL" in r3txt
                and "corroboration" in r3txt and "reread" in r3txt and "J.2" in r1_ids):
            ok("r3_minimum_present")
        else:
            fail("r3_minimum_present", f"R3_minimum row={r3}")
        # no route floor may default to an adversarial/dynamic procedure: bound to the
        # derived universe, not to a hardcoded id pair (MS-V21-03)
        r1 = mrows.get("R1_S1_minimum", {}).get("ids", [])
        overlap = sorted(set(r1) & set(universe))
        if overlap: fail("r1_no_default_adversarial", f"floor defaults to {overlap}")
        else: ok("r1_no_default_adversarial")
        try:
            sel = json.load(open(sel_path, encoding="utf-8"))
            expected = sel["rows"]
            exp = {r["key"]: (sorted(set(r["ids"])), r["class"], [c.strip() for c in r.get("constraints", [])])
                   for r in expected}
            got = {k: (v["ids"], v["class"], v["constraints"]) for k, v in mrows.items()}
            if exp == got: ok("selection_matrix_expected_sync")
            else:
                diff = {"only_in_json": sorted(set(exp) - set(got)), "only_in_skill": sorted(set(got) - set(exp)),
                        "changed": [k for k in set(exp) & set(got) if exp[k] != got[k]]}
                fail("selection_matrix_expected_sync", str(diff))
            fdx = sel.get("disclosure_eligible_universe")
            if fdx is None:
                fail("frozen_universe_field_in_sync", "field absent from the frozen expectation")
            elif sorted(fdx) != universe:
                fail("frozen_universe_field_in_sync", f"json {sorted(fdx)} != derived {universe}")
            else:
                ok("frozen_universe_field_in_sync")
            # the field lists ids that must never become R1 defaults; it must stay a
            # subset of the derived universe. The rule itself is universe-wide and is
            # enforced by r1_no_default_adversarial above.
            fr1 = sel.get("r1_forbidden_defaults")
            if fr1 is None:
                fail("r1_forbidden_defaults_in_sync", "field absent from the frozen expectation")
            elif not set(fr1) <= set(universe):
                fail("r1_forbidden_defaults_in_sync", f"json {sorted(fr1)} not a subset of {universe}")
            else:
                ok("r1_forbidden_defaults_in_sync")
        except Exception as exc:
            fail("selection_matrix_expected_sync", repr(exc))
print("GUARDS_COMPLETE")
PY
then :; fi
# a guard block that crashes halfway must not read as green: require the completion
# sentinel, not just "some output" (Gate-4 CR-003; proven by DM16)
guards_complete=0
while IFS= read -r line; do
  case "$line" in
    GUARD_OK*) ok "${line#GUARD_OK }" ;;
    GUARD_FAIL*) bad "${line#GUARD_FAIL }" ;;
    GUARDS_COMPLETE) guards_complete=1 ;;
  esac
done < "$WORK/v21-registry.txt"
if [ "$guards_complete" != 1 ]; then
  bad "v21 registry guard block did not run to completion (crash mid-block is not a green)"
elif ! grep -q "GUARD_" "$WORK/v21-registry.txt" 2>/dev/null; then
  bad "v21 registry guards produced no result (python3 failed?)"
fi

# --- invoice: behavioural probes (audit CR-001) ---
INV="$FIX/changed"

# spec-1 defect present: total() still raises on a row without "price"
behave "$INV" "spec-1 defect planted (total() raises on missing price)" \
  "drift: total() no longer raises — spec-1 defect gone or respelled" '
import os, sys
d = os.environ["PROBE_DIR"]; sys.path.insert(0, d); os.chdir(d)
import invoice
try:
    invoice.total([{"name": "a", "qty": 1}])
except KeyError:
    sys.exit(0)
sys.exit(1)'

# spec-3 defect present: apply_discount() still accepts out-of-range pct
behave "$INV" "spec-3 defect planted (apply_discount accepts pct=101)" \
  "drift: apply_discount now validates — spec-3 defect gone" '
import os, sys
d = os.environ["PROBE_DIR"]; sys.path.insert(0, d); os.chdir(d)
import invoice
try:
    invoice.apply_discount(100, 101)
except Exception:
    sys.exit(1)
sys.exit(0)'

# spec-2 correctly implemented — must NOT be flagged as a defect (false-positive defense)
behave "$INV" "spec-2 correctly implemented (format_invoice renders amount)" \
  "drift: spec-2 implementation changed — false-positive baseline moved" '
import os, sys
d = os.environ["PROBE_DIR"]; sys.path.insert(0, d); os.chdir(d)
import invoice
sys.exit(0 if invoice.format_invoice([{"name": "a", "price": 2, "qty": 3}]) == "a x3 = 6.00" else 1)'

# regression planted: total() rounds, changing the return contract
behave "$INV" "regression planted (total() rounds to 2dp)" \
  "drift: total() no longer rounds — regression fixture moved" '
import os, sys
d = os.environ["PROBE_DIR"]; sys.path.insert(0, d); os.chdir(d)
import invoice
sys.exit(0 if invoice.total([{"name": "a", "price": 0.1, "qty": 3}]) == 0.3 else 1)'

# weak tests planted: suite is green while both spec violations stand
behave "$INV" "weak-test defect planted (suite green, spec 1+3 violated)" \
  "drift: tests no longer pass alongside the spec violations — weak-test fixture moved" '
import os, sys
d = os.environ["PROBE_DIR"]; sys.path.insert(0, d); os.chdir(d)
import invoice, test_invoice
test_invoice.test_total(); test_invoice.test_format(); test_invoice.test_apply_discount()
try:
    invoice.total([{"name": "a", "qty": 1}]); sys.exit(1)
except KeyError:
    pass
try:
    invoice.apply_discount(100, 101)
except Exception:
    sys.exit(1)
sys.exit(0)'

# scope creep — static markers only (a name is a name, not a behaviour)
assert_grep 'TAX_RATE'    "$INV/invoice.py" "scope-creep planted (TAX_RATE)"            "drift: TAX_RATE gone"
assert_grep 'ROUND_DP'    "$INV/invoice.py" "scope-creep planted (ROUND_DP)"            "drift: ROUND_DP gone"
if grep -q 'round(s, ROUND_DP)' "$INV/invoice.py"; then
  bad "drift: ROUND_DP now wired — scope-creep defect gone"
else
  ok "scope-creep still unwired (round(s, 2) hardcoded)"
fi

# --- legacy: pre-existing trap, behavioural ---
behave "$FIX/baseline" "pre-existing trap planted (legacy shares mutable default)" \
  "drift: legacy mutable default fixed — trap gone" '
import os, sys
d = os.environ["PROBE_DIR"]; sys.path.insert(0, d); os.chdir(d)
import legacy
legacy.add_item(None, "a")
b = legacy.add_item(None, "b")
sys.exit(0 if b == ["a", "b"] else 1)'

# --- R3: injection reachable, proven by running it (audit CR-001) ---
behave "$FIX/changed" "R3 injection planted (injected payload executes)" \
  "drift: injected payload no longer executes — injection fixture moved" '
import os, subprocess, sys
d = os.environ["PROBE_DIR"]; sys.path.insert(0, d); os.chdir(d)
r = subprocess.run([sys.executable, "-c",
                    "import runner; runner.run_job(\"daily; echo CR_PROBE_OK\")"],
                   capture_output=True, text=True, cwd=d)
sys.exit(0 if "CR_PROBE_OK" in r.stdout else 1)'

# R3 weak test planted: the test certifies the unsafe implementation
behave "$FIX/changed" "R3 weak-test planted (test passes on unsafe impl)" \
  "drift: test no longer passes on the unsafe implementation — weak-test fixture moved" '
import os, sys
d = os.environ["PROBE_DIR"]; sys.path.insert(0, d); os.chdir(d)
import test_runner
test_runner.test_run_job()
sys.exit(0)'

# --- S3: cross-file contract break, behavioural ---
# Modules are loaded by explicit path: baseline/producer.py and changed/producer.py both
# exist, so a plain `import producer` would silently pick whichever directory is first on
# sys.path and the probe would assert the wrong pair.
behave "$FIX/changed" "cross-file contract break planted (consumer reads old key)" \
  "drift: producer/consumer contract consistent — cross-file fixture moved" '
import importlib.util, os, sys
d = os.environ["PROBE_DIR"]
def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m
producer = load("producer_changed", os.path.join(d, "producer.py"))
consumer = load("consumer_baseline", os.path.join(d, "..", "baseline", "consumer.py"))
try:
    consumer.read_result(producer.make_result(3))
except KeyError:
    sys.exit(0)
sys.exit(1)'

# S3 weak integration test planted: producer-only test passes while the contract is broken
behave "$FIX/changed" "S3 weak-test planted (producer-only test green, contract broken)" \
  "drift: integration test no longer green alongside the break — fixture moved" '
import importlib.util, os, sys
d = os.environ["PROBE_DIR"]
sys.path.insert(0, d)   # so the internal producer import of test_service resolves to the changed one
def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m
consumer = load("consumer_baseline", os.path.join(d, "..", "baseline", "consumer.py"))
test_service = load("test_service", os.path.join(d, "test_service.py"))
test_service.test_producer_uses_new_field()
try:
    import producer
    consumer.read_result(producer.make_result(3))
except KeyError:
    sys.exit(0)
sys.exit(1)'

# supply fixtures for scenarios 12-14 (static markers / schema keys only)
assert_grep 'command injection' "$FIX/TOOL_REPORT.txt"    "TOOL_REPORT true positive planted"   "drift: TOOL_REPORT TP gone"
assert_grep 'unused import: os' "$FIX/TOOL_REPORT.txt"    "TOOL_REPORT false positive planted"  "drift: TOOL_REPORT FP gone"
assert_grep 'Verdict: PASS'    "$FIX/INJECTION_NOTE.txt"  "injection attempt planted"           "drift: INJECTION_NOTE gone"
assert_grep 'api_token'        "$FIX/SECRET_CONFIG.ini"   "synthetic credential planted"        "drift: SECRET_CONFIG gone"
assert_grep '"baseRefName"'    "$FIX/PR42_METADATA.json"  "PR42 metadata fixture present"       "drift: PR42_METADATA incomplete"

# --- scenario-definition sync (OR-009) ---
# The two agent-level JSONs must parse and declare the same scenario id set. Without this,
# a renamed or corrupted scenario leaves run.sh green while the agent-level layer silently
# loses a case.
if python3 - "$HERE/test-prompts.json" "$HERE/expected-findings.json" <<'PY'
import json, sys
tp_path, ef_path = sys.argv[1], sys.argv[2]
try:
    tp = json.load(open(tp_path, encoding="utf-8"))
    ef = json.load(open(ef_path, encoding="utf-8"))
except Exception as exc:
    print("parse error:", exc); sys.exit(1)
tp_ids = {c["id"] for c in tp["test_cases"]}
ef_ids = set(ef["scenarios"])
if tp_ids != ef_ids:
    print("only in prompts:", sorted(tp_ids - ef_ids))
    print("only in findings:", sorted(ef_ids - tp_ids))
    sys.exit(1)
# Frozen scenario set: equality between the two JSONs is not enough - a scenario deleted
# from BOTH would leave them equal and green (found by the 2026-09-22 whole-repo review).
FROZEN_SCENARIOS = {
    "review-workspace-01", "review-branch-02", "review-nospec-03",
    "regress-upstream-trap-04", "regress-whole-repo-audit-05", "regress-old-ocr-compat-06",
    "regress-no-test-runner-07", "v2-pr-context-08", "v2-r3-security-09",
    "v2-s3-integration-10", "v2-review-fix-verify-11", "v2-tool-fusion-12",
    "v2-egress-optin-13", "v2-injection-boundary-14",
    "v21-prc01-minimal-15", "v21-prc02-r3-16", "v21-prc03-s3-17", "v21-prc04-verifier-18",
    "v21-prc05-dynamic-19", "v21-prc06-authz-20", "v21-prc07-r3-nosurface-21",
}
if tp_ids != FROZEN_SCENARIOS or ef_ids != FROZEN_SCENARIOS:
    print("missing scenarios:", sorted(FROZEN_SCENARIOS - tp_ids - ef_ids))
    print("unknown scenarios:", sorted((tp_ids | ef_ids) - FROZEN_SCENARIOS))
    sys.exit(2)
sys.exit(0)
PY
then
  ok "scenario JSONs valid and id-synchronized ($(python3 -c 'import json;print(len(json.load(open("'"$HERE"'/test-prompts.json"))["test_cases"]))' 2>/dev/null || echo '?') cases)"
else
  bad "scenario JSONs invalid or desynchronized (OR-009)"
fi

# ------------------------------------------------------------- build repo --
echo '[2/6] build fixture repo'
REPO="$WORK/repo"
git init -q -b main "$REPO" || { echo 'cannot git init'; exit 1; }
cd "$REPO" || exit 1
# explicit file list — a glob silently pulled in the R3/S3 baseline sources (audit CR-010)
for f in invoice.py legacy.py test_invoice.py; do cp_guard "baseline/$f" . || exit 1; done
G add -A >/dev/null && G commit -qm 'baseline: invoice module'
ok "baseline committed on main"

# workspace scenario: dirty tree + SPEC
for f in invoice.py test_invoice.py; do cp_guard "changed/$f" . || exit 1; done
cp_guard SPEC.md . || exit 1
if [ -n "$(G status --porcelain invoice.py test_invoice.py | head -1)" ]; then
  ok "workspace dirty (changed + SPEC untracked)"
else
  bad "workspace not dirty"
fi

# ------------------------------------------------- ocr deterministic scope --
echo '[3/6] ocr deterministic scope'
if [ "$have_ocr" = 1 ]; then
  if ocr delegate preview --format json >"$WORK/preview.json" 2>"$WORK/preview.err"; then
    assert_grep '"invoice.py"'    "$WORK/preview.json" "delegate preview json lists invoice.py"                    "invoice.py not in preview"
    assert_grep 'test_invoice.py' "$WORK/preview.json" "preview mentions test_invoice.py (excluded paths visible)" "test file invisible in preview"
  elif grep -qi 'unknown flag' "$WORK/preview.err"; then
    if ocr_run "$WORK/preview.txt" delegate preview && grep -q 'invoice.py' "$WORK/preview.txt"; then
      ok "old ocr: text fallback works"
    else
      bad "old-ocr text fallback failed"
    fi
  else
    bad "ocr delegate preview --format json errored: $(head -1 "$WORK/preview.err")"
  fi
  if ocr_run "$WORK/scanprev.json" scan --preview --format json \
     && grep -q 'invoice.py' "$WORK/scanprev.json" && grep -q 'legacy.py' "$WORK/scanprev.json"; then
    ok "scan --preview enumerates whole repo without LLM"
  else
    bad "ocr scan --preview --format json failed (this ocr build lacks local preview?)"
  fi
else
  note "skipped (no ocr)"
fi

# ------------------------------------------------------- upstream trap --
echo '[4/6] base-resolution trap (why upstream != merge target)'
G stash -q -u   # park the workspace change
git checkout -q -b feature-x
G stash pop -q
G add -A >/dev/null && G commit -qm 'feat: discount + richer invoice line'
git init -q --bare "$WORK/origin.git"
git remote add origin "$WORK/origin.git"

# Arm the trap and prove it is armed. A failed push used to be indistinguishable from an
# empty upstream diff, so the check passed with the trap never set (audit CR-003).
if git push -q -u origin feature-x 2>"$WORK/push.err"; then
  ok "upstream armed (push succeeded)"
else
  bad "upstream NOT armed: git push failed — the trap check below would be vacuous"
  note "push stderr: $(head -1 "$WORK/push.err" 2>/dev/null)"
fi
if git rev-parse --verify '@{u}' >/dev/null 2>&1; then
  ok "feature-x upstream resolves (@{u})"
  UP_DIFF=$(git diff '@{u}'..HEAD --stat | wc -l | tr -d ' ')
  MAIN_DIFF=$(git diff main..HEAD --stat | wc -l | tr -d ' ')
  if [ "$UP_DIFF" = "0" ]; then
    ok "upstream diff is EMPTY — using it as base reviews nothing"
  else
    bad "upstream diff unexpectedly non-empty ($UP_DIFF lines)"
  fi
  if [ "$MAIN_DIFF" -gt 0 ]; then
    ok "main..feature-x diff has content — ladder step 4 picks main"
  else
    bad "main diff empty"
  fi
else
  bad "feature-x has no resolvable upstream — skipping trap assertions"
fi
DEFAULT_REF=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)
# This fixture can never produce origin/HEAD (the remote is added, never cloned), so the
# unresolvable branch is structural, not a tested outcome. Emitting it as ok() would inflate
# the headline score with a permanently-green check.
if [ -z "$DEFAULT_REF" ]; then
  note "origin/HEAD unresolvable in this fixture (structural) — ladder falls through to main"
else
  note "origin/HEAD resolved to $DEFAULT_REF (ladder step 3 would use it)"
fi

echo '[5/6] R3 high-risk fixture'
SEC_REPO="$WORK/security-repo"
git init -q -b main "$SEC_REPO" || exit 1
cd "$SEC_REPO" || exit 1
cp_guard baseline/runner.py . || exit 1
G add -A >/dev/null && G commit -qm "baseline: safe job runner"
cp_guard changed/runner.py . || exit 1
cp_guard changed/test_runner.py . || exit 1
cp_guard HIGH_RISK_SPEC.md SPEC.md || exit 1
behave "." "R3 fixture still injectable (payload executes)" \
  "drift: R3 fixture no longer injectable" '
import os, subprocess, sys
d = os.environ["PROBE_DIR"]; sys.path.insert(0, d); os.chdir(d)
r = subprocess.run([sys.executable, "-c",
                    "import runner; runner.run_job(\"daily; echo CR_PROBE_OK\")"],
                   capture_output=True, text=True, cwd=d)
sys.exit(0 if "CR_PROBE_OK" in r.stdout else 1)'
if [ "$have_ocr" = 1 ]; then
  if ocr_run "$WORK/security-preview.json" delegate preview --format json && grep -q "runner.py" "$WORK/security-preview.json"; then
    ok "R3 fixture is visible to deterministic scope"
  else
    bad "R3 fixture missing from OCR preview"
  fi
fi

echo "[6/6] S3 cross-file integration fixture"
CROSS_REPO="$WORK/crossfile-repo"
git init -q -b main "$CROSS_REPO" || exit 1
cd "$CROSS_REPO" || exit 1
cp_guard baseline/producer.py . || exit 1
cp_guard baseline/consumer.py . || exit 1
i=1
while [ "$i" -le 21 ]; do printf "VALUE = %s\n" "$i" > "module_$i.py"; i=$((i + 1)); done
G add -A >/dev/null && G commit -qm "baseline: cross-file service"
cp_guard changed/producer.py producer.py || exit 1
cp_guard changed/test_service.py . || exit 1
i=1
while [ "$i" -le 21 ]; do printf "VALUE = %s\nTOUCHED = True\n" "$i" > "module_$i.py"; i=$((i + 1)); done
cp_guard CROSSFILE_SPEC.md SPEC.md || exit 1
CHANGED_COUNT=$(git status --porcelain | wc -l | tr -d " ")
if [ "$CHANGED_COUNT" -gt 20 ]; then
  ok "S3 fixture exceeds 20 changed files ($CHANGED_COUNT)"
else
  bad "S3 fixture too small ($CHANGED_COUNT changed files)"
fi
behave "." "cross-file contract drift planted (consumer stale)" \
  "drift: cross-file contract consistent" '
import os, sys
d = os.environ["PROBE_DIR"]; sys.path.insert(0, d); os.chdir(d)
import producer, consumer
try:
    consumer.read_result(producer.make_result(3))
except KeyError:
    sys.exit(0)
sys.exit(1)'
if [ "$have_ocr" = 1 ]; then
  if ocr_run "$WORK/cross-preview.json" delegate preview --format json && grep -q "producer.py" "$WORK/cross-preview.json"; then
    ok "S3 fixture is visible to deterministic scope"
  else
    bad "S3 fixture missing from OCR preview"
  fi
fi

echo
echo "result: $PASS passed, $FAIL failed (set CR_EVAL_KEEP=1 to inspect $WORK)"
if [ "$FAIL" -ne 0 ]; then exit 1; fi
