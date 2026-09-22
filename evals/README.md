# evals/

Reproducible evaluation for code-review V2.

~~~bash
sh ./run.sh            # healthy path: must be green
sh ./mutation-test.sh  # injected failures: every case must go red
~~~

The shell harness is intentionally deterministic: no LLM calls are required. Agent behavior is
evaluated separately with test-prompts.json + expected-findings.json.

## What V2 evaluates

| Layer | What is checked |
|---|---|
| Scope | OCR delegation preview, exclusions, JSON fallback behavior |
| Base resolution | tracking-upstream trap vs real merge target |
| Audit | local whole-repo scan preview and audit-mode semantics |
| Context | missing-spec honesty and PR-body intent context |
| Risk routing | R3 command-execution fixture |
| Size routing | S3 >20-file fixture |
| Integration | changed producer vs unchanged consumer contract drift |
| Test quality | happy-path / implementation-shaped tests |
| Verification | stable finding IDs and bounded review-fix-verify |
| Procedure selection | the required set per route/surface is selected, deduplicated, and disclosed; R1 stays minimal |
| Negative control | adversarial/dynamic procedures that were *not* selected are listed with reasons |
| Execution honesty | DONE only for procedures actually executed; unavailable environments recorded as LIMITED/BLOCKED |
| Sufficiency | SUFFICIENT / LIMITED / INSUFFICIENT stated and consistent with the procedures that ran |
| Verifier reliability | an always-pass gate is caught by a mutation challenge, with attributable evidence |
| Authorization | an ownership/role check removed from a read path is caught |
| Verdict | one mechanical PASS / NEEDS_REVISION / FAILED line |

## Files

| File | Purpose |
|---|---|
| run.sh | Builds temporary git repos and checks deterministic V2 plumbing. Cleans up on exit unless `CR_EVAL_KEEP=1`. |
| mutation-test.sh | Failure-injection counterpart: proves `run.sh` turns RED when its condition stops holding (fixture deleted, spec deleted, upstream unarmed, defect fixed, defect respelled, scenario desynced). |
| fixtures/ | Baseline/changed source files for the invoice, R3 security, cross-file contract, verifier (`check.sh`), and authorization (`records.py` + `AUTHZ_SPEC.md`) scenarios, plus scenario-supply fixtures: `PR42_METADATA.json` (offline provider metadata for the PR-context case), `TOOL_REPORT.txt` (static-tool output with 1 true / 2 false findings for tool-fusion eval), `INJECTION_NOTE.txt` (embedded reviewer-directed instructions for the injection-boundary eval), `SECRET_CONFIG.ini` (synthetic credential, realistic-looking but never a real secret, for the egress opt-in eval). |
| procedure-selection.json | Evaluator-only frozen expectation for the SKILL.md Selection Matrix (ID rows + the `R3_minimum` constraint row) and the disclosure universe; `run.sh` compares the matrix against it row by row. Never synced to the runtime skill. |
| test-prompts.json | Agent-level scenarios, Groups A-E (14 from V2.0.x + 6 V2.1 procedure-selection cases). |
| expected-findings.json | Must-report / must-not-report / routing expectations, plus the Group E contract fields (`must_select_procedures`, `must_not_select_procedures`, `must_exhibit_sufficiency`, `must_exhibit_selection_reason`). |
| agent-mutations.json | M6b agent-level procedure mutations: one rule removed from an isolated SKILL.md copy per case, each requiring a named contract failure. |
| procedure-mutation-plan.md | The M6b runner protocol, the isolation rule (the canonical SKILL.md is never mutated), and why two mutations target renamed rules. |
| judge-rubric.md | V2 evaluation rubric and paired-majority protocol. |

PR-context scenarios take provider metadata from the fixture file, supplied by the harness as
environment context — they never fetch from a live provider, so they run offline and
reproducibly.

## Deterministic fixtures

### Invoice fixture

Exercises the original A-J strengths:
- specification gaps;
- scope creep;
- regression;
- edge cases;
- weak tests;
- pre-existing bug discipline.

### R3 security fixture

The baseline uses argv-based subprocess execution. The changed version interpolates an untrusted
job identifier into os.system. The test mocks os.system and therefore proves the unsafe
implementation rather than safety.

Expected V2 behavior:
- classify R3;
- invoke the Security & Data Safety lens;
- produce E1 or stronger evidence;
- block merge without needing an external hosted scanner.

### S3 cross-file fixture

run.sh builds a >20-file change. The producer renames status -> state while the unchanged consumer
still reads status. The only new test checks the producer in isolation.

Expected V2 behavior:
- classify S3;
- batch review;
- run a final Integration Pass;
- catch the broken unchanged call site by citing both sides;
- identify the missing integration test.

### Verifier and authorization fixtures

The release verifier fixture replaces a real gate (grep for `STATUS: VERIFIED`, exit 1 otherwise)
with an unconditional `echo "verify OK"`, and adds a test that asserts only that output. The authz
fixture removes the ownership/role check from a read path, and adds a test covering the admin
positive path only.

Expected V2.1 behavior: select `G.2`/`G.4` (verifier harness surface) and `F.3` (authz surface),
demonstrate the false green / the cross-user read with attributable runtime evidence, and name the
missing negative-path test. `run.sh` asserts that both planted defects stay planted.

## Honest scope

run.sh verifies deterministic plumbing, not LLM quality. The agent layer must be executed with a
fresh review context and compared to expected-findings.json.

V2.1's agent layer was executed as 20 clean fresh runs (Groups A-D regression + Group E acceptance)
plus 6 mutated runs for the isolated agent-level mutations; the runs, their scoring and the
adjudicated Gate 4 review are recorded in `release-evals/v2.1-gate1/`.

The old V1 Darwin score (86.8 in that judging run) is historical only. V2 deliberately does not
inherit it. A major architecture change must earn a new paired evaluation.
