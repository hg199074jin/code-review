# AUDIT findings — canonical record (2026-09-21)

Whole-repo AUDIT of `code-review` at `v2.0.1-followups`. This is the deduplicated, canonical
finding set: 15 discrete findings. The working report contained a duplicated CR-001..CR-006
block (a copy artifact, not two reviewer submissions) — removed here so finding statistics
stay clean.

Evidence grades: **E2** = deterministic (file/grep/run), **E3** = runtime reproduction
(controlled mutation on a throwaway copy under /tmp).

## P1 — release harness issues false-green

| ID | Finding | Evidence |
|---|---|---|
| CR-001 | Planted-defect guards are literal-string matchers, so a correctly-fixed defect is still reported "planted" and a differently-spelled real drift escapes | E3 |
| CR-002 | Fixture files can be deleted with zero failure signal (9 of 15 copied files never existence-checked; no `cp` is guarded) | E3 |
| CR-003 | The upstream-trap check passes when the trap was never armed (failed `git push` is indistinguishable from an empty upstream diff) | E3 |

Shared severity rationale: the condition is false, yet `run.sh` exits 0 and prints PASS, so
release evidence is signed incorrectly. This is failure-as-success, not thin coverage.

## P2 — scenarios not cleanly reproducible / docs behind product

| ID | Finding | Evidence |
|---|---|---|
| CR-004 | `PR42_METADATA.json` `headRefName` is `feature`; the harness builds `feature-x` — scenario 08 is still not cleanly scoreable | E2 |
| CR-005 | `test-prompts.json` names three non-existent fixture files (`tool-report.txt`, `config.ini`, `REVIEW_NOTES.txt`) and carries a pre-`f75e632` credential description | E2 |
| CR-006 | `judge-rubric.md` scenario groups cover 11 of 14 cases; the three OR-002 scenarios (12/13/14) are judged by no group | E2 |
| CR-007 | Changelog stops at V2.0.0 while badges and SKILL.md metadata ship 2.0.1 | E2 |

## P3 — hygiene and specification drift

| ID | Finding | Evidence |
|---|---|---|
| CR-008 | `weak_tests` and `weak_integration_test` have no drift assertion of any kind | E2 |
| CR-009 | `release-evals/results.tsv` header declares 11 columns; data rows use 9; newest row uses a third schema | E2 |
| CR-010 | `cp "$FIX"/baseline/*.py` contaminates the invoice repo with the R3/S3 baseline sources | E2 |
| CR-011 | `run.sh` has no cleanup trap; temp repos accumulate | E2 |
| CR-012 | Lens naming drift: "Security & Data Safety" (SKILL.md) vs "Security / Reliability" (both READMEs, architecture doc, evals) | E2 |
| CR-013 | §3.1 scope-resolution matrix omits `DIFF_PR` and `VERIFY` rows; VERIFY's compound scope has no resolution command | E2 |
| CR-014 | EN/zh READMEs are not translations of each other: "Specialist review without voting" is EN-only, "安装" is zh-only | E2 |
| CR-015 | `judge-rubric.md` score-history row still says V2 unscored | E2 |

## Confirmed still open from the acknowledged backlog (not new discoveries)

OR-001 (context cost ~2x, accepted tradeoff), OR-004 (REVIEW_FIX acceptance contract
under-specified), OR-005 (R2/S2 two-pass split leaves the Security lens unassigned),
OR-006 (case 09 dual expected verdict), OR-009 (no JSON sync guard), OR-010 (no explicit
legacy `review-agent` ban), OR-011 (READMEs fold repo instructions into requirement-source
priority), OR-013 (spec2 must-not false-positive defense absent).

## Verified clean

Shell correctness/portability (shellcheck 0 under sh, dash, bash --posix); exit-code
semantics (positive control: renaming `TAX_RATE` correctly yields FAIL + exit 1);
expected-findings ↔ fixtures defect matching (all 10 catalog entries accurate); verdict /
severity / evidence mechanics consistent across five files; egress privacy model and the
2-cycle bound consistent; `results.tsv` **numbers** accurate (independently re-ran the PR #1
tree: 19/19 with ocr, 14/14 without, matching the record) — only its **structure** is
defective (CR-009).
