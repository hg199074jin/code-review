# Judge Rubric (darwin-skill protocol, as applied to this skill)

How the evolution score for this skill was produced, and how to reproduce it.
Protocol source: [darwin-skill](https://github.com/alchaincyf/darwin-skill) v2.1.

## The two layers of evaluation

1. **Deterministic plumbing** — `evals/run.sh`. No LLM involved: fixture integrity,
   `ocr delegate preview` scope resolution, `ocr scan --preview` enumeration, the
   base-resolution upstream trap. Binary pass/fail, fully reproducible.
2. **Agent behaviour** — `evals/test-prompts.json` + `evals/expected-findings.json`.
   Run the prompt in a fresh reviewer context with `SKILL.md` loaded, and against a
   baseline without it. Check which planted defects are caught, which discipline
   traps are respected, and whether the coverage line + single verdict line appear.

## The 9-dimension rubric (comparison criteria, not absolute scores)

| # | Dimension | Weight | What is checked |
|---|---|---|---|
| 1 | Frontmatter quality | 7 | name convention; description = what + when + triggers; ≤1024 chars; no filler tail |
| 2 | Workflow clarity | 12 | numbered steps; input/output per step |
| 3 | Failure-mode encoding | 12 | explicit "if X fails → Y"; positive-flow-only loses ≥3 |
| 4 | Checkpoint design | 6 | visual markers (🔴/STOP) before key decisions; prose-only does not count |
| 5 | Actionable specificity | 18 | concrete params/formats/examples; softeners lose points |
| 6 | Resource integration | 4 | referenced paths exist |
| 7 | Overall architecture | 12 | hierarchy, no redundancy, no filler |
| 8 | Observed behaviour | 23 | running the test prompts matches the claimed capability |
| 9 | Counter-examples | 6 | explicit "do NOT" list |

## Scoring rules (the important part)

- **Absolute scores are triage only.** The same unchanged text scored by different
  judges swings ±8. Never use absolute deltas for keep/revert decisions.
- **Keep/revert uses paired comparison:** N=3 (odd) independent judges each read the
  BEFORE and AFTER versions in one session and return `{better|worse|tie}` +
  `margin{clear|slight}` + one-line reason. Majority wins; a tie counts as keep.
- **Stop rule:** two consecutive rounds of slight/tight margins → stop
  (diminishing returns; more edits tend to add filler, not quality).
- **One dimension per round.** Multi-dimension edits cannot be attributed.

## Score record for this skill

| Stage | Dimension | Change | Verdict |
|---|---|---|---|
| baseline | — | — | 74.9 (triage) |
| round 1 | dim 3 failure modes | 7-row fallback table | 3-0 better (clear) |
| round 2 | dim 4 checkpoints | 4 explicit markers | 3-0 better (slight) |
| round 3 | dim 7 architecture | dedupe triple-stated prohibition | 3-0 better (slight) |
| final | — | — | 86.8 (triage) |

The 86.8 is a **triage number produced by the judging model available that day**,
not a stable benchmark. What is stable and reproducible: the protocol, the fixtures,
the planted defects, and the paired-majority verdicts (all 3-0, zero reverts).

## Reproducing

```bash
./evals/run.sh                       # deterministic layer, seconds, no LLM
# agent layer: for each scenario in evals/test-prompts.json, build the repo state
# described in expected-findings.json, dispatch a fresh reviewer with SKILL.md,
# and diff what it catches against must_report / must_not_report_as_finding.
```
