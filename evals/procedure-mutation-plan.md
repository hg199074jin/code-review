# Procedure Mutation Plan (M6b)

Agent-level procedure mutations prove that **the evals detect a broken skill** — the
deterministic guards (M6a) cannot do this, because the mutation target is the review standard
itself, and the observable effect is a change in LLM review behavior.

## Rules

1. The canonical `SKILL.md` is **never mutated**. Each AM applies exactly one mutation to an
   isolated temporary copy.
2. Observation is the fresh reviewer's output scored against the machine-readable contract in
   `evals/expected-findings.json` (`must_select_procedures`, `must_not_select_procedures`,
   `must_exhibit_sufficiency`) — never the final verdict alone.
3. Cost per AM: one mutated fresh run (the clean baseline PASS is reused from the paired Gate-3
   run; isolation is proven by the canonical SKILL.md SHA being unchanged).
4. Reverse check: restoring the unmutated SKILL.md makes the scenario PASS again.

## Case table

| ID | Mutation (applied to a temp SKILL.md copy) | Scenario | Expected evaluator failure |
|---|---|---|---|
| AM1 | delete F.1 from the command_execution row of the Selection Matrix | PRC-02 | `SELECTION_GUARD_FAIL:F.1` |
| AM2 | delete the S3_additions row | PRC-03 | `SELECTION_GUARD_FAIL:C.2/E.1/G.3` |
| AM3 | add F.2 and G.2 to the R1_S1_minimum row | PRC-01 | `OVER_REVIEW_GUARD_FAIL` |
| AM4 | delete the "never record BLOCKED as DONE" rule | PRC-05 | `EXECUTION_HONESTY_FAIL` |
| AM5 | delete the Review Sufficiency contract block | PRC-05 | `SUFFICIENCY_CONTRACT_FAIL` |

## Runner protocol (per AM)

```text
1. cp SKILL.md work/AMx-mutated-SKILL.md; apply the AM mutation
2. dispatch one fresh reviewer: authority = mutated copy, fixture = paired scenario repo
3. evaluator scores the report against the scenario contract:
   - AM1: F.1 missing from selected procedures -> SELECTION_GUARD_FAIL:F.1
   - AM3: F.2/G.2 present in an R1 report -> OVER_REVIEW_GUARD_FAIL
   - AM4: DONE recorded for an unavailable runtime procedure -> EXECUTION_HONESTY_FAIL
   - AM5: no Review Sufficiency line -> SUFFICIENCY_CONTRACT_FAIL
4. record: mutated-run verdict + contract result; canonical SKILL SHA before/after
```
