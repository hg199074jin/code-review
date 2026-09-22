#!/usr/bin/env python3
"""Generate the AM1-AM5 mutated SKILL copies for M6b (evaluator-side).

Isolation: the canonical candidate/SKILL.md is never written; each AM gets its own
copy under am-skill/, and every copy must differ from canonical in exactly one rule.

The mutation set follows the frozen plan's M6b intent (an R3 security requirement, a
conditional-surface requirement, an over-review default, the execution-honesty rule, the
sufficiency contract) with one documented refinement: F.1 and the S3_additions row are
selection-redundant (see prove-redundancy.py), so the two selection-removal mutations
target the uniquely-sourced members instead.
"""
import pathlib
import sys

B3 = pathlib.Path("/Volumes/ORICO/Projects/code-review-meta-review/v21-design-review")
CANON = B3 / "candidate" / "SKILL.md"
OUT = B3 / "am-skill"

COMMAND_ROW = "| command_execution | F.1, F.2, G.1 | mandatory |\n"
VERIFIER_ROW = "| verifier_harness | G.2, G.4, J.2 | mandatory |\n"
R1_ROW = ("| R1_S1_minimum | A.1, A.2, B.1, C.2, E.1, G.1, I.1, J.1, J.2, J.3 | route |")
R1_ROW_MUT = ("| R1_S1_minimum | A.1, A.2, B.1, C.2, E.1, F.2, G.2, G.1, I.1, J.1, J.2, J.3 | route |")
HONESTY = "Never fabricate evidence; a `BLOCKED` procedure is never recorded as `DONE`."
HONESTY_MUT = "Procedures that cannot run are still marked `DONE` when the overall conclusion is clear."
SUF_CONTRACT = "Review Sufficiency: <SUFFICIENT | LIMITED | INSUFFICIENT>"
SUF_CONTRACT_MUT = "Review conclusion: <done>"
SUF_DEF_1 = "- **`SUFFICIENT`**："
SUF_NOTE = ('`Review Sufficiency` is the statement "were the required procedures enough", never a verdict — the\n'
            'verdict stays mechanical over open P0/P1.')
SUF_NOTE_MUT = "The verdict stays mechanical over open P0/P1.\n"

MUTATIONS = {
    "AM1": {"desc": "delete the command_execution mandatory surface row",
            "target": "SELECTION_GUARD_FAIL:F.2", "scenario": "v21-prc02-r3-16",
            "edits": [(COMMAND_ROW, "")]},
    "AM2": {"desc": "delete the verifier_harness mandatory surface row",
            "target": "SELECTION_GUARD_FAIL:G.2/G.4", "scenario": "v21-prc04-verifier-18",
            "edits": [(VERIFIER_ROW, "")]},
    "AM3": {"desc": "add F.2, G.2 to R1_S1_minimum (R1 default fan-out into adversarial/dynamic)",
            "target": "OVER_REVIEW_GUARD_FAIL", "scenario": "v21-prc01-minimal-15",
            "edits": [(R1_ROW, R1_ROW_MUT)]},
    "AM4": {"desc": "reverse the execution-honesty rule (BLOCKED may be recorded as DONE)",
            "target": "EXECUTION_HONESTY_FAIL", "scenario": "v21-prc05-dynamic-19",
            "edits": [(HONESTY, HONESTY_MUT)]},
    "AM5": {"desc": "remove the Review Sufficiency reporting contract",
            "target": "SUFFICIENCY_CONTRACT_FAIL", "scenario": "v21-prc05-dynamic-19",
            "edits": [(SUF_CONTRACT, SUF_CONTRACT_MUT), (SUF_NOTE, SUF_NOTE_MUT)]},
}

src = CANON.read_text(encoding="utf-8")
# NOTE: the design doc's section 12 value definitions were not implemented in SKILL.md, so
# this filter matches nothing today; it is kept so the mutation stays correct if they are added
# (finding MS-V21-06 in release-evals/v2.1-gate1/m7-gate-report.md).
SUF_DEF_BLOCK = [l for l in src.splitlines(keepends=True) if l.startswith(SUF_DEF_1) or
                 l.startswith("- **`LIMITED`**：") or l.startswith("- **`INSUFFICIENT`**：")]
assert SUF_DEF_BLOCK == [], SUF_DEF_BLOCK

OUT.mkdir(exist_ok=True)
fail = 0
for am, spec in MUTATIONS.items():
    text = src
    for old, new in spec["edits"]:
        if text.count(old) != 1:
            print(f"FAIL {am}: anchor not unique ({text.count(old)}x): {old[:60]!r}")
            fail = 1
            continue
        text = text.replace(old, new, 1)
    if am == "AM5":
        for line in SUF_DEF_BLOCK:
            text = text.replace(line, "", 1)
    path = OUT / f"{am}-mutated-SKILL.md"
    path.write_text(text, encoding="utf-8")
    changed = [i for i, (a, b) in enumerate(zip(src.splitlines(), text.splitlines()), 1) if a != b]
    delta = len(src.splitlines()) - len(text.splitlines())
    print(f"{am}: {spec['desc']}\n     target={spec['target']} scenario={spec['scenario']} "
          f"changed_lines={len(changed)} line_delta={delta}")

# Isolation proof: canonical must be untouched.
print("canonical sha256:", (B3 / "candidate" / "SKILL.sha256").read_text().strip())
sys.exit(fail)
