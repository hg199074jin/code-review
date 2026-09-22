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


---

# Cycle 2 — fix cycle results (2026-09-22)

Evaluated AND released artifact: `SKILL.md` sha256
`348946aec2e3b39388920bf862b8755f2323383f045f3ef44a2cfe5ee1a33455` (line count 637/640). The first
cycle's 26 runs belong to the superseded `41e10ff4…` and are kept as history only.

## Commits

`c91085b` F1a normative fix · `180cc19` F1b DM9–DM13 · `e5912cd` F2 Sufficiency criteria ·
`5bb983b` F3 fixture drift probes · `16c2ee3` F4 rubric/README/evidence/erratum · `00571b8` F5
PRC-07 · `ad4e418` F6 freeze · `35b8900` F7 GUARDS_COMPLETE sentinel · `eab62b9` F6 cycle-2 evidence.

## Gate 1 (re-declared green only after the new guards had mutation proofs)

`run.sh` 59/0 with `ocr`, 54/0 without; `mutation-test.sh` **25/25** (DM1–DM16, including DM16 for
the mid-block-crash false-green window that Gate 4 round 2 found); `shellcheck` clean; SKILL.md
637/640; the two previously inert expectation fields are now guard-consumed.

## Gates 2+3 (cycle 2): 12 clean fresh runs — all contracts met

Scoring: `results-v2.tsv`. Highlights:

- **PRC-07 (new)** — an R3 change that triggers none of the four mandatory surfaces still selected
  and executed an adversarial procedure (F.1) **via the new `R3_minimum` row**, stated the
  different-nature corroboration and the critical-path reread, and claimed no surface. This is the
  behavioral proof that the round-1 P1 is fixed.
- The two runs that misread the route minimum in cycle 1 (06, 07) both read **floor ∪ passes** this
  time; no divergence recurred.
- `v2-s3-integration-10`'s severity matched the frozen catalog exactly this cycle (P1 →
  NEEDS_REVISION); the cycle-1 P0 variance did not recur.
- Recorded variances (content present, folded per §6.4 same-root-cause dedup): weak_tests
  (workspace-01) and weak_integration_test (s3-integration-10); severity variance on 07's unrunnable
  suite (P1 here vs P2/P3 in cycle 1).

## M6b (cycle 2): 2 detected, 1 not attributable — recorded, not papered over

- AM2R (remove the disclosure rule): **DETECTED** — the not-selected list became an indiscriminate
  20-item enumeration, `ADVERSARIAL`/`DYNAMIC`/`universe` 0 mentions (clean run: 6 scoped items).
- AM3 (adversarial procedures into the R1 floor): **DETECTED** — a docs-only R1 review selected F.2
  and G.2; G.2 even ran a mutation challenge on a comment change.
- AM1 (delete the `command_execution` row): **NOT ATTRIBUTABLE on this model** — the reviewer
  re-added F.2 and F.5 by discretionary addition and still ran a real injection probe. The security
  *behavior* survived the row's removal; the *row* is therefore not mutation-verifiable on this
  model. Recorded as a negative result next to cycle 1's detected AM1 (different model): row-level
  selection enforcement is model-dependent, which is itself a finding about how much the framework
  should rely on discretionary additions.
- AM4/AM5 were not re-run (Option B scope); cycle 1's detections stand for those rules.

## Gate 4 (cycle 2): round 2 FAIL → fixes → round 3 PASS

- Round 2 (`05dd293..ad4e418`): **NEEDS_REVISION, P0=0, P1=1** — the committed release evidence still
  belonged to the pre-fix candidate (correct: the F6 results were not yet in the repository). Also
  found: a mid-block-crash false-green window in `run.sh`'s guard block (P2, fixed by the
  `GUARDS_COMPLETE` sentinel + DM16), undefined advisory-row semantics (P2 → follow-up MS-V21-12, the
  sentence was deliberately **not** added so the released artifact stays byte-identical to the
  evaluated one), stale README evidence (P3, fixed), a results.tsv cross-reference typo (P3, fixed).
- Round 3 (`05dd293..eab62b9`): **PASS, P0=0, P1=0, P2=2, P3=1.** The reviewer independently
  reproduced every deterministic number (59/0, 54/0, 25/25, shellcheck 0, baseline 34/0/29/0/14/14),
  re-derived all hashes (HEAD SKILL.md = candidate snapshot = evaluated artifact; 21/21 scenario
  worktrees), re-ran three false-green injections (all red), and confirmed the round-1 P1 and the
  round-2 CR-002/003/006 genuinely closed. Residual boundary: the 16 agent runs were verified
  statically (hashes, frozen refs, consistency), not re-executed.

## Findings disposition (cumulative)

| Finding | Disposition |
|---|---|
| MS-V21-01 (P1, route minimum / R3 floor) | **FIXED** (F1a) and behaviorally proven (PRC-07, PRC-06) |
| MS-V21-02 (P3, coverage line vs selection) | **FIXED** (F2 legend rule) |
| MS-V21-03 (P2, hardcoded guard pair) | **FIXED** (F1a universe-bound guard) |
| MS-V21-04 (P2, disclosure rule unguarded) | **FIXED** (F1a `disclosure_rule_stated` + DM12) |
| MS-V21-05 (P2, new fixtures undrifted) | **FIXED** (F3 probes + DM14/DM15) |
| MS-V21-06 (P2, Sufficiency criteria missing) | **FIXED** (F2) |
| MS-V21-07 (P3, rubric dropped fix/verify) | **FIXED** (F4 dimension 13) |
| MS-V21-08 (P3, evals/README stale) | **FIXED** (F4) |
| MS-V21-09 (P3, evidence chain out-of-tree) | **FIXED** (F4 harness copies; generators updated in F6) |
| MS-V21-10 (record, M0 manifest) | **FIXED** (M7 cycle 1) |
| MS-V21-11 (record, s11 expectation) | **OPEN follow-up** — erratum written; fixture decision belongs to the V2.0.2 record owner (`release-evals/v2.1-baseline/erratum-s11.md`) |
| MS-V21-12 (P2, advisory-row semantics) | **OPEN follow-up** — deliberately not added post-evaluation; next patch, with its own targeted re-run |
| Round-2 CR-003 (P2, guard-block crash window) | **FIXED** (F7 sentinel + DM16) |

## Human Merge Gate input (cycle 2)

| Item | Status |
|---|---|
| Gate 1 deterministic | PASS (59/0, 54/0, 25/25, shellcheck 0, 637 lines) |
| Gates 2+3 agent | 12/12 contracts met (4 recorded variances, no missed defects) |
| M6b mutations | 2 detected + 1 honestly non-attributable this cycle |
| Gate 4 merge-safety | **PASS (P0=0, P1=0)** after the round-2 findings were fixed |
| Open follow-ups | MS-V21-11 (s11 erratum, V2.0.2 record), MS-V21-12 (advisory semantics, next patch) |
| Mergeable? | **Yes by the protocol's bar.** Merge + post-merge sync execute only on the user's explicit GO. |


---

# V2.2 cycle — review independence (2026-09-23)

Design: `code-review-meta-review/v22-design-review/code-review-V2.2-设计文档-v2.md` (four external
review rounds). Branch `v2.2-review-independence`.

## Gates

- M1+M2 (`d15d317` + fixes): SKILL.md independence section (author_conflict_status confirmed/
  cleared/unknown, priority, pass ledger, five-condition independent pass, runtime cap) + four
  bundled contract fixes; guards `review_independence_rule_stated` / `brief_contract_stated` /
  marker extension; DM20-DM22. Deterministic: run.sh 61/0 + 56/0, mutation 32/32, shellcheck 0,
  640/640 lines.
- M3 (`13390b6` + `a7172cc`): 24-case frozen set; three single-factor independence scenarios
  (PRC-08 author-conflict / R3-A no-fresh-reviewer / R3-B independent-pass).
- M5 (12 fresh runs, `results-v2.tsv` v22-m5 rows): declared-path acceptance **PASS** —
  PRC-08 author-self-review disclosed + LIMITED; R3-B independent-pass + SUFFICIENT; R3-A
  disclosed sequential-fallback but graded SUFFICIENT (cap miss); Group E all contracts met,
  field-local migration invariant demonstrated (findings unchanged, sufficiency changed).
- **V22-F2 behavioral finding**: the independence cap is applied by model reviewers when author
  conflict is CONFIRMED (1/1) but NOT for absence-based limitations (0/3: prc04 a/b/d across three
  text variants, R3-A). Conclusion: the cap is not model-self-enforceable; enforcement moved to the
  runtime layer (mechanical attestation from facts the runtime owns). Design doc amended (§A).
- M1b fix en route (`d4b7caf`): M5 also surfaced that the cap never propagated to the judgment
  site; first fixed as section-8 criteria, then as a red CHECKPOINT - and finally moved to the
  SUFFICIENT definition + runtime enforcement after samples c/d.

## M6 merge-safety (V2.2 delta)

- Round 1 (`84ae4af..a7172cc`, deployed-V2.1 authority): **NEEDS_REVISION, P0=0, P1=1** - CR-001:
  the M1+M2 commit claimed DM20-DM22 injection proofs that were never committed (the guards
  themselves verified working via the reviewer's own probes). Plus 2 P2 (dangling SHA in
  results-v2; v22 contracts missing F.2), 2 P2 release-docs items (version still 2.1.0, rubric
  dim 5 stale), 2 P3.
- All findings fixed (DM20-22 implemented for real, 32/32; contracts corrected; version 2.2.0;
  READMEs; rubric; identity records). CR-005/CR-006 recorded as follow-ups.
- Final status: awaiting the narrow M6 re-verification + Human Merge Gate.


## M6 narrow closure verification (round 2, `9366dd4`)

An independent narrow review verified: CR-001 **CLOSED** (DM20-22 present, mutation 32/32, each red
attributable); CR-003 **CLOSED** (F.2 in both v22 contracts); CR-004 **CLOSED** (2.2.0 everywhere,
V2.2 sections, rubric semantics); CR-005/CR-006 **CLOSED** as recorded follow-ups. Residual items
found and immediately fixed: the V2.2 candidate-identity record was missing (added to
`candidate-identity.txt`: evaluated `f9547d09` @7dabc6e vs release `d5bc44bb` @9366dd4, delta =
version line only) and two doc numbers corrected (actual 639 wc / 640-line budget). The reviewer's
closing statement: no new P0/P1 from the fix delta; all other five findings closed with strong
empirical evidence.

## Human Merge Gate input (V2.2)

| Item | Status |
|---|---|
| Deterministic | 61/0 + 56/0, mutation 32/32, shellcheck 0, 640-line budget (wc 639/640) |
| M5 targeted acceptance | 12 fresh runs; declared independence paths all behave per contract; the absence-path cap is NOT model-self-enforceable (4 samples) → moved to runtime enforcement, honestly recorded |
| M6 merge-safety | round 1 NEEDS_REVISION (P1 = claimed-but-absent DM proofs, plus 4 P2/P3) → all fixed → narrow closure verification: 6/6 closed, no new P0/P1; residual = one record file, added |
| Mergeable? | **Yes by the protocol's bar** (0 P0 / 0 P1 open; findings dispositioned). Merge + runtime sync (SKILL.md only, to 2.2.0) on the user's explicit GO. |
