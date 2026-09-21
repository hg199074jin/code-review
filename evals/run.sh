#!/bin/sh
# code-review skill — deterministic eval plumbing (no LLM involved).
#
# Builds the fixtures, then checks the deterministic layer the skill depends on:
#   1. fixture integrity    — planted defects still present (guards drift)
#   2. ocr delegate preview — workspace scope resolution + exclusion detection
#   3. ocr scan --preview   — whole-repo enumeration without an LLM endpoint
#   4. upstream trap        — proves why base must not be the tracking upstream
#
# Agent-level behaviour (A–J coverage, verdicts) is covered by evals/test-prompts.json.
# Judge-level scoring is covered by evals/judge-rubric.md.

set -u

HERE=$(cd "$(dirname "$0")" && pwd)
FIX="$HERE/fixtures"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/cr-eval.XXXXXX")
PASS=0
FAIL=0

ok()  { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; }
note(){ printf '  --   %s\n' "$1"; }

# assert_grep <pattern> <file> <pass-msg> <fail-msg>
assert_grep() {
  if grep -q -- "$1" "$2"; then ok "$3"; else bad "$4"; fi
}

have_ocr=0
if command -v ocr >/dev/null 2>&1; then have_ocr=1; else note "ocr not on PATH — ocr checks skipped (skill falls back to git diff)"; fi

G() { git -c user.email=eval@local -c user.name=eval "$@"; }

# ---------------------------------------------------------------- fixtures --
echo '[1/4] fixture integrity'
for f in invoice.py legacy.py test_invoice.py; do
  [ -f "$FIX/baseline/$f" ] || bad "missing baseline/$f"
done
for f in invoice.py test_invoice.py; do
  [ -f "$FIX/changed/$f" ] || bad "missing changed/$f"
done
[ -f "$FIX/SPEC.md" ] || bad "missing SPEC.md"

if grep -q '"price" not in ln' "$FIX/changed/invoice.py"; then
  bad "drift: spec-1 skip branch now implemented (expected missing)"
else
  ok "spec-1 defect planted (total lacks skip branch)"
fi
if grep -q 'raise ValueError' "$FIX/changed/invoice.py"; then
  bad "drift: spec-3 validation now implemented (expected missing)"
else
  ok "spec-3 defect planted (apply_discount lacks validation)"
fi
assert_grep 'TAX_RATE'      "$FIX/changed/invoice.py" "scope-creep planted (TAX_RATE/ROUND_DP)"      "drift: TAX_RATE gone"
assert_grep 'round(s, 2)'   "$FIX/changed/invoice.py" "regression planted (total now rounds)"        "drift: round() gone"
assert_grep 'into=\[\]'     "$FIX/baseline/legacy.py" "pre-existing trap planted (legacy mutable default)" "drift: legacy trap gone"

# ------------------------------------------------------------- build repo --
echo '[2/4] build fixture repo'
REPO="$WORK/repo"
git init -q -b main "$REPO" || { echo 'cannot git init'; exit 1; }
cd "$REPO" || exit 1
cp "$FIX"/baseline/*.py .
G add -A >/dev/null && G commit -qm 'baseline: invoice module'
ok "baseline committed on main"

cp "$FIX/changed/invoice.py" "$FIX/changed/test_invoice.py" .
cp "$FIX/SPEC.md" .
if [ -n "$(G status --porcelain invoice.py test_invoice.py | head -1)" ]; then
  ok "workspace dirty (changed + SPEC untracked)"
else
  bad "workspace not dirty"
fi

# ------------------------------------------------- ocr deterministic scope --
echo '[3/4] ocr deterministic scope'
if [ "$have_ocr" = 1 ]; then
  if ocr delegate preview --format json >"$WORK/preview.json" 2>"$WORK/preview.err"; then
    assert_grep '"invoice.py"'     "$WORK/preview.json" "delegate preview json lists invoice.py"                      "invoice.py not in preview"
    assert_grep 'test_invoice.py'  "$WORK/preview.json" "preview mentions test_invoice.py (excluded paths visible)"   "test file invisible in preview"
  elif grep -qi 'unknown flag' "$WORK/preview.err"; then
    if ocr delegate preview >"$WORK/preview.txt" 2>/dev/null && grep -q 'invoice.py' "$WORK/preview.txt"; then
      ok "old ocr: text fallback works"
    else
      bad "text fallback failed"
    fi
  else
    bad "ocr delegate preview --format json errored: $(head -1 "$WORK/preview.err")"
  fi
  if ocr scan --preview --format json >"$WORK/scanprev.json" 2>/dev/null \
     && grep -q 'invoice.py' "$WORK/scanprev.json" && grep -q 'legacy.py' "$WORK/scanprev.json"; then
    ok "scan --preview enumerates whole repo without LLM"
  else
    bad "ocr scan --preview --format json failed (this ocr build lacks local preview?)"
  fi
else
  note "skipped (no ocr)"
fi

# ------------------------------------------------------- upstream trap --
echo '[4/4] base-resolution trap (why upstream != merge target)'
G stash -q -u   # park the workspace change
git checkout -q -b feature-x
G stash pop -q
G add -A >/dev/null && G commit -qm 'feat: discount + richer invoice line'
git init -q --bare "$WORK/origin.git"
git remote add origin "$WORK/origin.git"
git push -q -u origin feature-x 2>/dev/null

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
DEFAULT_REF=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)
if [ -z "$DEFAULT_REF" ]; then
  ok "origin/HEAD unresolvable here — ladder falls through to main (step 4)"
else
  note "origin/HEAD resolved to $DEFAULT_REF (ladder step 3 would use it)"
fi

echo
echo "result: $PASS passed, $FAIL failed (workdir $WORK)"
if [ "$FAIL" -ne 0 ]; then exit 1; fi
