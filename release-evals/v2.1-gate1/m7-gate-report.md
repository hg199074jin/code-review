# M7 — Full regression + independent review (V2.1)

Frozen plan: 《Code Review V2.1 实施方案 V3》 M7. Evaluated artifact:
`SKILL.md` sha256 `41e10ff4fe8fc326b44b6b9d1e38f91d87301a886f4148b06b39f0a2d36d3d6f`
(see `candidate-identity.txt` for the evaluated-vs-released delta).

**Gate result: Gate 1 PASS · Gate 2 PASS · Gate 3 PASS · Gate 4 FAIL (P0 = 0, P1 = 1) → release BLOCKED.**
Per the plan's escalation clause ("fresh review 出现 V2.1 核心设计 P1"), the release escalates to a
full Major Release Protocol v4 cycle before any merge. Nothing has been merged; `main` is untouched.

## Gate 1 — deterministic (PASS)

| Check | Result | Evidence |
|---|---|---|
| `sh evals/run.sh` (ocr present) | 52 passed / 0 failed | `run-with-ocr.txt` |
| `sh evals/run.sh` (no ocr on PATH) | 47 passed / 0 failed | `run-without-ocr.txt` |
| `sh evals/mutation-test.sh` | 17/17 cases behaved as required | `mutation.txt` |
| `shellcheck evals/run.sh evals/mutation-test.sh` | 0 findings | `shellcheck.txt` |
| JSON fixtures parse | 5/5 valid | `json-validation.txt` |
| fixture references | none missing | `fixture-refs.txt` |
| scenario JSON id sets | 20 = 20, identical | `fixture-refs.txt` |
| `SKILL.md` line budget | 625 ≤ 640 | `line-counts.txt` |
| recorded line counts | baseline 510 / M1 578 / M2 604 / M3+M4 625 (unchanged through M5/M6a/docs) | `line-counts.txt` |
| V2.0.2 baseline SHAs | `BASE_SHA` and all six blob shas recomputed and completed in the M0 manifest (they were empty placeholders in the M0 commit) | `release-evals/v2.1-baseline/manifest.json` |

## Gate 2 — Groups A–D regression (PASS, 14/14)

14 V2.0.2 scenarios, one fresh reviewer each, scored against `evals/expected-findings.json`.
Per-scenario detail: `results.tsv`; reports: the evaluator workspace `runs/clean/<scenario>.md`.

All 14 met their contract fields (must_report, must_not_report, must_exhibit, routing). One
severity/verdict variance is recorded and adjudicated rather than waived:

- `v2-s3-integration-10`: the producer/consumer drift was graded **P0** (runtime `KeyError` on the
  only contract path) where the frozen catalog says P1, flipping the verdict from NEEDS_REVISION to
  FAILED. Same defect, no missed finding, stronger severity → within the §6.3 ladder
  ("core function fundamentally broken"). Adjudicated as a **recorded variance**, not a failure.

One expectation line is adjudicated as unsatisfiable (finding MS-V21-11 below).

## Gate 3 — Group E acceptance (PASS, 6/6)

Six V2.1 scenarios covering selection minimality, R3 security selection, S3 integration, verifier
false-green, execution honesty under an unavailable environment, and authz:

| Scenario | Contract demands | Observed |
|---|---|---|
| `v21-prc01-minimal-15` | exact R1/S1 minimum; F.2/G.2 absent; disclosure = the 6-ID universe; SUFFICIENT | exactly the 10-ID minimum, F.2/G.2 not selected, all six universe IDs disclosed with reasons, no R3 fan-out, PASS |
| `v21-prc02-r3-16` | F.1/F.2/G.1/J.2; triangulation; independent reread; injection found | all four selected, injection P0 with E1+E3, 25 procedures, SUFFICIENT |
| `v21-prc03-s3-17` | C.2/E.1/G.3/J.1; integration pass; 100% accounting; drift with both sides | all four, 24/24 files accounted, drift cites producer.py:2 + consumer.py:2 |
| `v21-prc04-verifier-18` | G.2/G.4; false-green demonstrated; attributable mutation challenge | G.2/G.4 selected, gate proven to pass on a DRAFT report while the baseline exits 1, three mutations run |
| `v21-prc05-dynamic-19` | F.1/G.1; unavailable runtime never DONE; residual disclosed; Sufficiency LIMITED | production endpoint recorded as unproven (A.1 LIMITED), Sufficiency LIMITED, no fabricated runtime claim |
| `v21-prc06-authz-20` | F.3/E.1/G.1; independent corroboration; ownership bypass | bypass reproduced at runtime, cross-user read succeeds, 8-mutant challenge on the new test |

Two routing-tier variances (`prc04` reviewed as R3 vs the declared R2) are recorded; both readings
are defensible under §4.1 and no contract field depends on them.

## M6b — agent-level mutations (4 attributable, 1 negative result)

Full protocol, isolation proof and per-AM evidence: `m6b-results.md`.

| AM | target | result |
|---|---|---|
| AM1 delete `command_execution` row | `SELECTION_GUARD_FAIL:F.2` | DETECTED |
| AM2 delete `verifier_harness` row | `SELECTION_GUARD_FAIL:G.2/G.4` | NOT ATTRIBUTABLE (reviewer selected them anyway) → recorded |
| AM2R remove the negative-control disclosure rule | `DISCLOSURE_GUARD_FAIL` | DETECTED |
| AM3 add F.2/G.2 to `R1_S1_minimum` | `OVER_REVIEW_GUARD_FAIL` | DETECTED |
| AM4 reverse the execution-honesty rule | `EXECUTION_HONESTY_FAIL` | DETECTED |
| AM5 remove the Sufficiency contract | `SUFFICIENCY_CONTRACT_FAIL` | DETECTED |

Isolation: canonical `SKILL.md` sha256 identical before and after (verified after the runs), and
0 of 20 scenario repositories drifted (manifest re-hash), no `__pycache__` created.

Cost: 20 clean runs (Gate 2 + Gate 3) + 6 mutated runs (5 planned + 1 replacement for the
non-attributable AM2). Reviewer runtime: fresh `general-purpose` subagents on the session model,
one scenario per run, 17-56 tool calls per run.

## Gate 4 — fresh independent merge-safety review: FAIL

- Authority: `main` `SKILL.md` (deployed stable V2.0.2, sha256 `4ebbbb15…`) — a fresh reviewer
  applied the **stable** standard to `05dd293..c886324`, independently re-ran the deterministic
  suite (reproduced 52/52, 47/47, 17/17, shellcheck 0), re-derived the manifest hashes, re-computed
  the 20 clean runs' selected sets, and ran five reverse-injection experiments.
- Verdict: **NEEDS_REVISION — P0 = 0, P1 = 1, P2 = 6, P3 = 2.** Bar per the plan is P0 = 0, P1 = 0,
  PASS → **gate fails**. Report: evaluator workspace `runs/merge-safety/V21-gate4.md`.
- The reviewer explicitly confirmed that the release's own factual claims held: baseline 34/29 and
  14/14 reproduce, the manifest hashes match, and the "release delta is one version line" claim is
  true.

## Adjudication of Gate 4 findings

Each finding was re-checked against the artifact. Two were adjusted after adjudication.

### MS-V21-01 (P1, CONFIRMED — blocks the release)

The Selection Matrix does not define what a **route minimum** is, and it does not carry the R3
minimum the frozen design requires.

1. **Ambiguous base row.** The row is named `R1_S1_minimum`. §4.3's formula says
   `required = dedupe(route minimum ∪ mandatory surface ∪ explicit requirement)` but never says
   which rows make up the "route minimum" for R2/R3. Observed consequence across the 20 runs:
   18 read it as *base ∪ passes* (22 procedures for R2/S1), 2 read it as *pass rows only*
   (16–18 procedures, dropping A.1/A.2/B.1/C.2/E.1/I.1/J.1 — including requirement tracing and
   finding de-duplication). The design doc §8.2 does say "默认增加" (adds to the base), but that
   sentence is in the design document, not in the runtime artifact.
2. **No R3 minimum.** The matrix has 14 rows and **no R3 row**; the frozen design §8.3 requires R3
   to include "route minimum; matched mandatory surface; ≥1 adversarial procedure; ≥1
   deterministic/dynamic corroboration; critical-path independent reread; J.2". SKILL.md's
   normative text for R3 is only §4.3's "R3/S3 = specialist passes + final integration pass; any R3
   security/data-loss path gets an independent re-read". Consequence: an R3 change with no matching
   mandatory surface (for example crypto, a frozen contract, or a data-loss path with no file I/O
   surface) can legitimately select **zero adversarial procedures** while still being an R3 review.
   The fixture JSON does contain an `R3` descriptor entry, but it is not mirrored in the matrix and
   is read by nothing.
3. **`S3_additions` is selection-redundant.** All four members (C.2, E.1, G.3, J.1) are already
   required by base ∪ pass rows, so the row cannot change any selection (set arithmetic in
   `m6b-results.md`). It documents S3's requirements but has no routing effect — which is exactly
   why the plan's AM2 design could not produce an attributable mutation.
4. **No guard and no acceptance scenario distinguishes the readings.** `selection_matrix_parseable`
   / `selection_matrix_expected_sync` compare SKILL.md to the fixture, and the fixture omits R3; the
   Group E scenarios all pass under either reading. This is why 26 agent runs and a green
   deterministic suite did not surface it.

Fix direction (smallest safe): one edit block in §4.3 — state that the R1/S1 minimum is the floor
for every route and that R2/S2, R3 and S3 add their rows on top; add an explicit R3 minimum row
(`>=1 ADVERSARIAL`, `>=1 DETERMINISTIC/DYNAMIC corroboration`, critical-path reread, `J.2`);
mirror both into `evals/fixtures/procedure-selection.json`; add a Group E scenario for the
R3-without-surface path; add a guard that binds the disclosure/R3 rules to the SKILL.md prose.
Any SKILL.md edit invalidates the current agent-level evidence, so this needs a re-run cycle.

### MS-V21-04 (P2, CONFIRMED) — the disclosure rule itself has no deterministic guard

`disclosure_universe_matches` derives the universe from the registry table (so the attribute data
is guarded), but nothing guards the §5a rule sentence or the §8 `Not selected by routing` block:
deleting that block leaves `run.sh` at 52/52. The M4 plan anticipated partial coverage ("此 guard 只
防整段被删"), and the agent-level AM2R proves the behaviour *is* observable — but the deterministic
layer is blind to the rule that V2.1 was built around.

### MS-V21-05 (P2, CONFIRMED) — the two new fixtures have no drift assertion

`run.sh` lists `changed/check.sh`, `changed/check_test.sh`, `changed/records.py`,
`changed/test_records.py`, `AUTHZ_SPEC.md` only in the existence check (lines 91-92). The invoice
fixtures carry 13 behavioural probes; the new ones carry none, so "fixing" the planted authz
bypass or the always-pass verifier leaves `run.sh` green. The agent-level contract would eventually
catch it, but the deterministic layer signs evidence it cannot support for these two fixtures.

### MS-V21-03 (P2, CONFIRMED) — `r1_no_default_adversarial` hardcodes two IDs

`run.sh:228` tests `if "F.2" in r1 or "G.2" in r1`, while the universe has six members, and the
fixture's `r1_forbidden_defaults` / `disclosure_eligible_universe` fields are read by no guard at
all. Adding F.1 (or D.3) to `R1_S1_minimum` **and** to the fixture keeps the suite green. AM3's
detection rested on the hardcoded pair, not on the frozen expectation.

### MS-V21-06 (P2, CONFIRMED — design fidelity) — Sufficiency values have no criteria

Design §12 defines the three values with criteria and forbids "the review is complete" phrasing
under `INSUFFICIENT`. The runtime artifact has only the contract line and the "never a verdict"
note; `INSUFFICIENT` has no defined trigger, and the six Group E runs produced 5×SUFFICIENT /
1×LIMITED with no derivable rule. (This also explains why the M6b AM5 mutation had to target the
contract line rather than definitions that do not exist.)

### MS-V21-02 (P3, partially confirmed) — coverage line vs selection

CR-002's claim that the retained "no risk tier may skip the A–J standard" text contradicts an R1
minimum with no F/D/H procedures is **textually** true but **behaviourally** handled: the clean
PRC-01 run reported `D ➖`, `H ➖`, `F ➖` with reasons instead of claiming ✅, and A.1 as LIMITED.
The text should state that rule ("a route that selects no procedure for an objective reports ➖,
never ✅"), but no misreporting was observed and R1 is by definition low-surface.

### MS-V21-07 (P3, CONFIRMED) — eval rubric dropped the fix/verify dimension

The V2.0.2 rubric scored "Fix/verify control" (dim 11, 7 points: stable IDs, targeted verification,
bounded loops). The V2.1 redistribution replaced dim 11 with "Execution honesty" and the doc claims
the four changed dimensions were only "renamed/sharpened", so REVIEW_FIX/VERIFY is no longer scored
in the paired rubric even though the capability still ships.

### MS-V21-08 (P3, CONFIRMED) — `evals/README.md` is stale

It still describes "11 original + 3 added in 2.0.1" cases and lists neither `AUTHZ_SPEC.md`,
`CROSSFILE_SPEC.md`, the check/records fixtures, nor `agent-mutations.json` /
`procedure-mutation-plan.md` / `procedure-selection.json`. 20 cases exist now.

### MS-V21-09 (P3, partially confirmed) — evidence chain is partly out-of-tree

`release-evals/v2.1-gate1/*` references `scenarios/`, `harness/scenario-manifest.json`,
`runs/clean|mutated`, `harness/gen-am-mutations.py` and briefs, which live in the evaluator
workspace outside the repository, so the 26 agent runs are not reproducible from the repo alone.
`candidate-identity.txt`'s "Machine check" line was also not executable as written (it quoted a
content sha256 as a git ref); corrected and committed at M7. Fix direction: keep the generator and
scenario builder in the repo (or record their shas in the manifest) so the evidence chain is
self-contained.

### MS-V21-10 (record, fixed) — M0 manifest had empty SHAs

`release-evals/v2.1-baseline/manifest.json` recorded `BASE_SHA` and the six blob shas as empty
strings. Completed at Gate 1 from `git show 05dd293:<path>`; the recomputed runtime SKILL.md sha
(`4ebbbb15…`) confirms baseline == runtime == the recorded prefix.

### MS-V21-11 (record, no V2.1 impact) — a V2.0.2 acceptance line is not reproducible

`evals/expected-findings.json` requires `v2-review-fix-verify-11` to report `command_injection` in
its initial findings, but that fixture's change set is `SPEC.md` + `test_runner.py` only —
`runner.py` is the **safe baseline** (unchanged, verified by `git hash-object` = `HEAD:runner.py`)
and its test already patches `subprocess.run` with `["jobctl","run","daily"], check=True`. So the
expectation is unsatisfiable against the fixture, and the V2.0.2 Gate B2 record
("s11: command_injection ✓ … 三项 FIXED") cannot be reproduced from the artifact it names: the
fixture repo has a single commit and file mtimes (10:23-10:28 on 2026-09-21) that predate the B2
run, and the only place an injected `runner.py` coexists with the weak test is
`pr1/evaluator/snapshots/b2-assets/`. Two readings remain (the B2 s11 run reviewed the asset bundle
rather than the scenario repo, or the record's tick is wrong); either way the s11 line is not
evidence for the REVIEW_FIX-with-injection claim. Today's V2.1 run exercised the REVIEW_FIX
mechanics correctly (IDs frozen, fix applied by the authoring role in a copy, minimal re-run, one
cycle, FIXED statuses, PASS with no open P0/P1). Recommend an erratum in issue #2 and a fixture
decision (either restore an injected initial state or rewrite the expectation).

### Validity caveat — reviewer model changed between baselines

The V2.0.2-era severity expectations in `defect_catalog` were recorded from runs on the then-session
model (GLM); this cycle ran on a different session model. Cross-version severity comparisons
(today's P0-vs-catalog-P1 on `v2-s3-integration-10`, and `weak_security_test` graded P1 instead of
P2 in the R3 scenarios) are therefore confounded by the model change and are not attributable to
V2.1. Within this cycle the comparisons *are* like-for-like: every clean/mutated pair ran on the same
model, which is what the M6b attributions rest on.

## Escalation determination

The plan: "满足任一条件则升级为完整 Major Release Protocol v4: … fresh review 出现 V2.1 核心设计
P1 …"。Gate 4 produced exactly one P1, and it is a core-design defect (selection semantics and the
missing R3 minimum). Therefore:

- **Do not merge.** `main` stays at `05dd293`; the branch is preserved as-is for the fix cycle.
- The next cycle must (a) fix MS-V21-01 in `SKILL.md` plus the fixture/matrix sync, (b) close
  MS-V21-03/04/05/06 in the harness and normative text, (c) add the R3-without-surface acceptance
  scenario, and (d) re-establish agent-level evidence for the changed artifact.
- Because any `SKILL.md` edit invalidates the current authority snapshot, the re-run scope is a
  user decision:
  - **Option A (full rigor)**: repeat all 20 clean scenarios + the 5 AM runs + Gate 4 (≈26 runs).
  - **Option B (targeted)**: re-run the 6 Group E scenarios, the 2 A–D scenarios whose selection
    reading varied (06, 07), 3 selection-sensitive regression scenarios, the 3 selection-targeted
    AMs (AM1/AM2R/AM3) and one new R3-without-surface scenario, then Gate 4 again (≈15 runs), with
    the reduced scope disclosed in the release evidence.
  Recommendation: **Option B**, because the fix is confined to §4.3 semantics plus harness guards —
  but the decision is the user's, as it changes both cost and the evidence scope.
- M8 (Human Merge Gate, merge, post-merge sync) is **not reached** in this cycle.

## Human Merge Gate input

| Item | Status |
|---|---|
| Gate 1 deterministic | PASS (52/52, 47/47, 17/17, shellcheck 0, 625 lines) |
| Gate 2 Groups A–D | PASS 14/14 (1 recorded severity variance) |
| Gate 3 Group E | PASS 6/6 (2 recorded routing-tier variances) |
| M6b agent mutations | 4 detected, 1 non-attributable (recorded) |
| Gate 4 merge-safety | **FAIL — P0 = 0, P1 = 1** |
| Mergeable now? | **No.** Fix MS-V21-01 and the P2s, then re-run and re-review |
