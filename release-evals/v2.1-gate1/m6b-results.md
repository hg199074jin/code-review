# M6b — agent-level procedure mutation results (V2.1)

Protocol (frozen plan, M6b): `mutation → isolated copy of the frozen SKILL.md → one fresh agent
review against the paired Group E scenario → named contract failure`. The clean baseline is reused
from the Gate-3 run of the same scenario, so each mutation costs one new run. The canonical
`SKILL.md` is never mutated.

## Isolation proof

- canonical `candidate/SKILL.md` sha256 before and after all runs:
  `41e10ff4fe8fc326b44b6b9d1e38f91d87301a886f4148b06b39f0a2d36d3d6f` — unchanged
  (`candidate-identity.txt`).
- each AM read its own `am-skill/<ID>-mutated-SKILL.md`; mutation diffs are one rule each
  (regenerated deterministically by `harness/gen-am-mutations.py`).
- all 20 scenario repositories re-hashed after the runs: 0 of 20 drifted, no `__pycache__` created
  (manifest comparison, `harness/scenario-manifest.json`).

## Mutation-set refinement (recorded deviation from the frozen AM table)

The frozen table targeted two selection removals. Both are **selection-redundant** against the
frozen Selection Matrix, so no single-rule removal can make them unselectable:

```text
S3_additions           : C.2, E.1, G.3, J.1
base ∪ pass1 ∪ pass2   : C.2, E.1, G.3, J.1     <- all four already required
S3 unique members      : none

command_execution row  : F.1, F.2, G.1
  F.1  also required by the unconditional R2 pass-2 row  -> cannot be removed by one rule
  G.1  also in base and pass-2 rows                      -> cannot be removed by one rule
  F.2  unique to this row                                -> the only attributable target
```

(Set arithmetic over `evals/fixtures/procedure-selection.json`, re-runnable in one command.)

Consequences, both recorded rather than papered over:

1. **AM1** targets F.2 instead of F.1: deleting the `command_execution` row removes F.2 from any
   selection, which the PRC-02 contract requires.
2. **AM2 first attempt** (delete the `verifier_harness` row, expect G.2/G.4 to vanish) was
   **NOT ATTRIBUTABLE**: the reviewer selected G.2 and G.4 on its own judgment and ran a
   three-mutant challenge. Removing a surface row is compensated by the registry plus the
   discretionary-addition clause, so the selection contract cannot detect it. Kept in
   `evals/agent-mutations.json` under `not_attributable` as a negative result.
3. **AM2R** replaces it with the removal of the **negative-control disclosure rule** (universe
   definition in §5a, its R1 note in §4.3, and the `Not selected by routing` block in the §8
   contract) — a rule with no second source, so a compliant reviewer cannot restore it.

## Results

| AM | mutation (one rule) | scenario | expected failure | observed | verdict |
|---|---|---|---|---|---|
| AM1 | delete `command_execution` mandatory surface row | v21-prc02-r3-16 | `SELECTION_GUARD_FAIL:F.2` | selected set omits F.2; F.2 appears under not-selected; F.1 survives via the R2 pass-2 row (as predicted) | **DETECTED** |
| AM2 | delete `verifier_harness` mandatory surface row | v21-prc04-verifier-18 | `SELECTION_GUARD_FAIL:G.2/G.4` | G.2/G.4 still selected; mutation challenge still run | NOT ATTRIBUTABLE |
| AM2R | remove the negative-control disclosure rule | v21-prc01-minimal-15 | `DISCLOSURE_GUARD_FAIL` | report lists all 20 not-selected procedures with no universe scoping; `ADVERSARIAL` 0x, `DYNAMIC` 0x, `universe` 0x (clean run: 6x / 2x / 1x) | **DETECTED** |
| AM3 | add F.2 + G.2 to `R1_S1_minimum` | v21-prc01-minimal-15 | `OVER_REVIEW_GUARD_FAIL` | R1/S1 docs change selects F.2 and G.2; F.2 recorded `NOT_APPLICABLE` | **DETECTED** |
| AM4 | reverse the execution-honesty rule | v21-prc05-dynamic-19 | `EXECUTION_HONESTY_FAIL` | `A.1 Requirement Trace — DONE` although SPEC item 4 (production endpoint) still cannot be executed; clean run recorded `LIMITED`; Sufficiency flips to SUFFICIENT | **DETECTED** |
| AM5 | remove the Review Sufficiency contract | v21-prc05-dynamic-19 | `SUFFICIENCY_CONTRACT_FAIL` | report closes with `Review conclusion: done` — the mutated contract's own placeholder — and never states SUFFICIENT/LIMITED/INSUFFICIENT | **DETECTED** |

Clean baselines used (Gate 3, same fixtures): `runs/clean/v21-prc01-minimal-15.md`,
`v21-prc02-r3-16.md`, `v21-prc04-verifier-18.md`, `v21-prc05-dynamic-19.md`.
Mutated reports: `runs/mutated/AM1.md`, `AM2.md`, `AM2R.md`, `AM3.md`, `AM4.md`, `AM5.md`.

## Attribution discipline applied

- No mutation was accepted because "something turned red": each required a specific contract
  failure read out of the reviewer's own report/JSON, compared against the clean run of the *same*
  fixture.
- Decoys were excluded: AM1's red is the missing F.2, not the missing F.1 (which survives by
  design); AM2R's red is the loss of universe scoping, not a missing ID (all six universe IDs still
  appear among the 20 listed).
- The one mutation that could not be attributed is reported as such instead of being replaced by a
  weaker pass criterion.
- Harness caveat: the reviewer brief names `not_selected_by_routing` among the machine-readable
  keys, which is a mild leak for mutations that remove a *contract field*. AM2R's detection
  therefore rests on the report's own content (no ADVERSARIAL/DYNAMIC framing anywhere), which the
  key name cannot produce; AM5's rests on the value (`done` placeholder), which the key name cannot
  produce either.
