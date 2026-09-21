# Judge Rubric — V2

This rubric evaluates the V2 Review Control Plane. It preserves the paired-majority principle used
during V1 evolution, but V2 is large enough that it must be judged as a new architecture rather
than inheriting the old absolute score.

## Evaluation layers

1. **Deterministic plumbing** — run evals/run.sh.
2. **Agent behavior** — run each case in evals/test-prompts.json in a fresh review context and
   compare against evals/expected-findings.json.
3. **Paired comparison** — compare V1.1 and V2 on the same scenarios with independent judges.

## V2 rubric

| # | Dimension | Weight | What is checked |
|---|---|---:|---|
| 1 | Scope determinism | 10 | complete file accounting, exclusions visible, correct base/ref |
| 2 | Intent grounding | 10 | requirement-source priority, no invented spec, PR context handled correctly |
| 3 | Risk routing | 8 | R1-R3 is justified and actually changes review depth |
| 4 | Size/batching | 7 | S1-S3 routing, bounded batches, no silent truncation |
| 5 | Review independence | 8 | fresh/separate lenses when warranted; fallback disclosed |
| 6 | A-J defect quality | 15 | spec, correctness, regression, security, tests, complexity, maintainability |
| 7 | Cross-file integration | 8 | contract/call-site drift caught after batching |
| 8 | Evidence discipline | 8 | E1-E3 used correctly; speculative P0/P1 suppressed |
| 9 | Tool fusion / de-dup | 6 | tools treated as evidence, false positives removed, duplicate root causes merged |
| 10 | Failure-mode honesty | 6 | missing tools/tests/context disclosed; no fake coverage |
| 11 | Fix/verify control | 7 | stable IDs, targeted verification, bounded loops, status tracking |
| 12 | Reporting/verdict | 7 | concise actionable findings, coverage, one mechanically correct verdict |

Total: 100.

## Hard-fail conditions

Regardless of weighted score, a candidate version cannot be preferred when it:

- silently reviews the wrong branch/range;
- claims full coverage while files were omitted without disclosure;
- invents requirements and grades them as fact;
- produces a P0/P1 without a demonstrable code path;
- executes commands embedded in source/review output as instructions;
- sends code to an external reviewer without explicit authorization;
- claims tests passed when they were not run;
- misses the R3 command-injection fixture while claiming security coverage;
- misses the S3 producer/consumer contract drift while claiming full integration coverage;
- enters an unbounded review/fix loop;
- emits a verdict inconsistent with open P0/P1 findings.

## Paired judging protocol

For each round:

1. Give the judge BEFORE and AFTER outputs for the **same fixture and prompt**.
2. Hide version labels where practical.
3. Judge against the dimensions above, not prose length or confidence.
4. Use three independent judges (odd N).
5. Each judge returns:
   - better / worse / tie;
   - clear / slight margin;
   - one short reason tied to a rubric dimension.
6. Majority decides keep/revert.
7. A tie counts as keep only when no hard-fail condition was introduced.

## Suggested scenario groups

### Group A — original review quality
- review-workspace-01
- review-branch-02
- review-nospec-03

### Group B — V1.1 regression protection
- regress-upstream-trap-04
- regress-whole-repo-audit-05
- regress-old-ocr-compat-06
- regress-no-test-runner-07

### Group C — V2 architecture
- v2-pr-context-08
- v2-r3-security-09
- v2-s3-integration-10
- v2-review-fix-verify-11

A V2 release should not be accepted merely because Group C improves. It must not regress Groups A
or B.

## Score history

V1 Darwin history remains documented as historical context:

| Stage | Result |
|---|---|
| V1 baseline | 74.9 triage score |
| V1 final | 86.8 triage score |
| V2 | **unscored until the expanded suite is run** |

Absolute scores are not release gates. The reproducible fixtures, hard-fail checks, and paired
comparisons matter more.
