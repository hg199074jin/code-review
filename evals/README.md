# evals/

Reproducible evaluation for the code-review skill.

```bash
./run.sh    # seconds, no LLM, no network — deterministic layer only
```

## What's here

| File | Purpose |
|---|---|
| `run.sh` | Rebuilds the fixture repos and checks the deterministic plumbing: planted defects intact, `ocr delegate preview --format json` scope, `ocr scan --preview --format json` whole-repo enumeration, and the base-resolution upstream trap (proves `git diff @{u}..HEAD` is empty while `main..HEAD` has the real delta). |
| `fixtures/` | Plain source files for baseline / changed states + `SPEC.md`. The repos themselves are built by `run.sh` — no nested git metadata is committed. |
| `test-prompts.json` | 7 scenarios: 3 original behaviour cases + 4 V1.1 regression cases (upstream trap, whole-repo audit, old-ocr `--format` fallback, no-test-runner). |
| `expected-findings.json` | Per scenario: which planted defects **must** be reported, which discipline traps **must not** become findings, and the expected verdict. |
| `judge-rubric.md` | The 9-dimension rubric and the paired-majority judging protocol behind the evolution record. |

## Honest scope

`run.sh` covers the deterministic layer only. The agent layer (does a fresh reviewer
with `SKILL.md` actually catch the planted defects and respect the traps) requires an
LLM and therefore is a protocol, not a script: follow `test-prompts.json` +
`expected-findings.json` with any reviewing model. The judge layer is documented in
`judge-rubric.md` — its score is a triage number from that day's judging model, not a
stable benchmark.
