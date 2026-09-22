# Erratum — the `v2-review-fix-verify-11` acceptance line (MS-V21-11)

Status: **recorded, not silently repaired.** Written during the V2.1 M7 cycle on 2026-09-22.
Scope: a V2.0.2-era evaluation record. It does not affect V2.1's behaviour, and nothing here has been
merged or published.

## What the record says

`evals/expected-findings.json` (frozen since V2.0.1, unchanged through V2.0.2) requires for that
scenario:

```json
"initial_must_report": ["command_injection", "weak_security_test"]
```

and `release-evals/results.tsv` records, for the V2.0.2 cycle:

> meta-review 2026-09-21 … GateB2 acceptance x4 — PASS 4/4 - R3 injection graded P0 with runtime
> proof; S3 contract drift captured; REVIEW_FIX converged in 1 of 2 cycles

with the per-scenario table in the meta-review workspace
(`pr1/evaluator/reports/gate-b2-verdict.md`) reading:

> s11 REVIEW_FIX … command_injection✓ weak_security_test✓ + CR-002 失败语义回归 P1 … 三项 FIXED✓ …
> 无 open P0/P1→PASS

## What the fixture actually contains

The scenario repository is `scenarios/v2-review-fix-verify-11` (a copy of the meta-review workspace's
`pr1/scenarios/s11-reviewfix`):

| File | State |
|---|---|
| `runner.py` | **safe baseline**, byte-identical to `HEAD:runner.py` (`git hash-object` = `HEAD:runner.py`); `subprocess.run(["jobctl", "run", job], check=True)` |
| `test_runner.py` | the **post-fix** test: `@patch("runner.subprocess.run")`, asserts `["jobctl","run","daily"]` with `check=True` |
| `SPEC.md` | 3 requirements (untrusted id, no shell, no shell syntax) |
| git | **one** commit, `8e440bb baseline: safe job runner`; file mtimes 2026-09-21 10:23–10:28 |

There is no `os.system` anywhere in the change set, and no weak test: the change set is `SPEC.md` +
`test_runner.py`, and both describe the *safe* contract. An injected `runner.py` side by side with
the weak `os.system`-mocking test exists only in the evaluator's own fixture bundle
(`pr1/evaluator/snapshots/b2-assets/evals/fixtures/`).

So the expectation `initial_must_report: ["command_injection", …]` **cannot be satisfied by the
artifact it names** — a correct reviewer must not report a command-injection finding that the diff
does not contain.

## Evidence that this is a record defect, not a V2.1 regression

- The fixture has been in this state since before the B2 run: single commit, mtimes predate
  `gate-b2-verdict.md` (~11:16 the same day), and the file hashes match the copies made today.
- The V2.1 run (2026-09-22, `runs/clean/v2-review-fix-verify-11.md`) verified `runner.py` against
  `HEAD` by hash, reported the two real defects of the actual change set — the new safety test is not
  collectable by any available runner (P1) and asserts only a benign identifier (P2) — fixed both in
  a `/tmp` copy, re-ran the smallest relevant checks, and closed with `PASS`, one cycle, no open
  P0/P1. That is textbook REVIEW_FIX behaviour against this fixture.
- Two readings remain open, and this note does not pick one silently:
  1. the B2 s11 run reviewed the `b2-assets` bundle rather than the scenario repository, so the tick
     is mis-attributed; or
  2. the tick is simply wrong.
  Either way the s11 line in the V2.0.2 record is not evidence for "REVIEW_FIX with an injected P0".

## Options (a fixture decision, not an evaluator edit)

1. **Keep the fixture, fix the expectation.** Rewrite `initial_must_report` to the fixture-derived
   contract (test-quality findings + bounded fix/verify mechanics, no injection claim). Cheapest;
   loses the "fix a P0 from the initial findings" coverage.
2. **Restore the injected initial state.** Put `os.system(f"jobctl run {job}")` + the
   `os.system`-mocking test in the change set so the scenario tests REVIEW_FIX from a genuine P0, and
   keep the current expectation. Costs a fixture rebuild and a fresh acceptance run.

Option 2 preserves the capability that Gate B2 claimed to have verified; option 1 is honest about
what the fixture now is. The decision belongs with the V2.0.2 record owner (issue #2 on the upstream
repository), because it changes a V2.0.x expectation.

Nothing in `evals/expected-findings.json` was edited while writing this erratum: the V2.1 Gate 2
scoring for this scenario was adjudicated against the fixture instead (see
`release-evals/v2.1-gate1/m7-gate-report.md`, MS-V21-11).
