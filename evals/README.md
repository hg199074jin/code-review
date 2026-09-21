# evals/

Reproducible evaluation for code-review V2.

~~~bash
./run.sh
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
| Verdict | one mechanical PASS / NEEDS_REVISION / FAILED line |

## Files

| File | Purpose |
|---|---|
| run.sh | Builds temporary git repos and checks deterministic V2 plumbing. |
| fixtures/ | Baseline/changed source files for invoice, R3 security, and cross-file contract scenarios. |
| test-prompts.json | 11 agent-level scenarios. |
| expected-findings.json | Must-report / must-not-report / routing expectations. |
| judge-rubric.md | V2 evaluation rubric and paired-majority protocol. |

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
- invoke the Security/Reliability lens;
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

## Honest scope

run.sh verifies deterministic plumbing, not LLM quality. The agent layer must be executed with a
fresh review context and compared to expected-findings.json.

The old V1 Darwin score (86.8 in that judging run) is historical only. V2 deliberately does not
inherit it. A major architecture change must earn a new paired evaluation.
