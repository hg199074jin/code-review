# Code Review V2 Architecture

## Goal

V2 upgrades `code-review` from a checklist-driven reviewer into a **Review Control Plane**.

It keeps the original strengths — specification compliance, test-quality scrutiny, explicit coverage,
P0–P3 severity, one mechanical verdict — and adds deterministic scope resolution, intent context,
risk-adaptive multi-pass review, evidence fusion, and bounded verification.

## Reference projects and what V2 borrows

These projects are design references, not mandatory dependencies.

| Project | Idea adopted | What V2 deliberately does not copy |
|---|---|---|
| [Alibaba OpenCodeReview](https://github.com/alibaba/open-code-review) | deterministic file selection, path rules, whole-repo preview, large-change batching | provider-backed LLM review is not required; delegation/local-first remains default |
| [OpenAI Codex](https://github.com/openai/codex) | orchestrator + independent specialist review passes | V2 does not require Codex-specific subagent names or runtime APIs |
| [PR-Agent](https://github.com/The-PR-Agent/pr-agent) | PR intent/context, provider metadata, large-PR decomposition | no PR-comment command surface or hosted service dependency |
| [CodeRabbit Skills](https://github.com/coderabbitai/skills) | agent-readable findings, bounded review/fix workflow, preserve provenance | external CodeRabbit review is opt-in because it can transmit code |
| [reviewdog](https://github.com/reviewdog/reviewdog) | normalize diagnostics and anchor them to reviewed diffs | V2 is not a comment-posting transport |
| [Semgrep](https://github.com/semgrep/semgrep) | deterministic static evidence as a second signal | Semgrep is optional; V2 does not auto-install or fetch remote rules |
| [GitHub CodeQL](https://github.com/github/codeql) | security/static-analysis evidence and SARIF consumption | normal reviews do not require a CodeQL database or setup |
| [Danger JS](https://github.com/danger/danger-js) | repository policy checks: changelog, generated files, migrations, required artifacts | policy checks do not replace defect review |

## Architecture

```text
User / ZCode / Claude Code / Codex / Cursor / other Agent
                         |
                         v
                 code-review V2
                 Review Control Plane
                         |
          +--------------+---------------+
          |              |               |
          v              v               v
   Scope Resolver   Context Pack     Risk Router
   OCR / git        spec / PR /      R1-R3 + S1-S3
   provider diff    issue / rules
          |              |               |
          +--------------+---------------+
                         |
                         v
                  Review Execution
          +--------------+---------------+
          |              |               |
          v              v               v
   Intent & Scope   Correctness &    Security & Data
   A-B              Regression C-E   Safety F
                         |
                         v
                 Tests / Maintainability
                       G-H-I
                         |
                         v
                Optional Evidence Layer
      tests / lint / typecheck / Semgrep / SARIF /
      existing CI / explicitly-authorized external review
                         |
                         v
                   Coordinator
       verify -> dedupe -> evidence grade -> severity
                         |
                         v
             P0/P1/P2/P3 + one verdict
                         |
              if REVIEW_FIX requested
                         v
               bounded fix -> VERIFY
                   max 2 cycles
```

## Four design boundaries

### 1. Deterministic engineering before LLM judgment

The reviewer should not decide which files "look important". OCR/git enumerates scope first.
Every file is accounted for as reviewed or skipped with a reason.

### 2. Intent is a first-class input

The best available requirement source is resolved before judging implementation. Priority:

1. explicit user requirement / acceptance criteria;
2. frozen design/spec/ADR;
3. issue/task;
4. PR title/body;
5. commit message as secondary context.

No requirement source means a disclosed limitation, not an invented specification.

### 3. Multi-reviewer only when it buys independence

V2 does not fan out every tiny change.

- R1 + S1: one fresh A–J pass.
- R2 or S2: two independent passes.
- R3 or S3: specialist passes + cross-batch integration pass.

This preserves simplicity while using independent reviewers where false negatives are expensive.

### 4. Tools provide evidence, not verdicts

Static analyzers and external reviewers can be wrong. Their output is normalized, verified against
the code and scope, deduplicated, and then re-graded under the V2 severity rubric.

## Finding model

A high-value finding answers four questions:

```text
[P1][CR-001][A/C][E2] Broken contract title — path:line
Impact: what concrete scenario breaks?
Evidence: how do we know?
Fix direction: what is the smallest safe direction?
```

Evidence grades:

- E1 — code-path proof
- E2 — deterministic test/static/CI corroboration
- E3 — authorized runtime reproduction

## Verdict model

The verdict is intentionally simple and mechanical:

```text
open P0 -> FAILED
else open P1 -> NEEDS_REVISION
else -> PASS
```

P2/P3 do not secretly become blockers. If a finding must block merge, it must be justified as P1.

## Privacy model

Local deterministic operations are the default.

Allowed without external LLM egress:
- `ocr delegate preview`
- `ocr delegate rule`
- `ocr scan --preview`
- git inspection
- safe local tests/checks
- repository-local static rules

External reviewer/LLM modes require explicit authorization and a secret/sensitive-scope check.

## V2 success criteria

V2 should be considered successful only when evals show that it can:

1. keep deterministic scope coverage;
2. use the correct merge base;
3. distinguish diff review from whole-repo audit;
4. use PR/requirement context without treating it as infallible;
5. route high-risk changes into independent security review;
6. catch cross-file contract regressions after batching;
7. verify tool findings instead of blindly copying them;
8. run review/fix/verify without entering an infinite loop;
9. preserve one mechanical verdict;
10. disclose incomplete coverage instead of pretending a full audit.

## V2.1 addition — the Review Procedure Framework

V2.1 layers a risk-based procedure framework under the unchanged V2 control plane. Nothing above
changes: the A-J objectives, the P0-P3 ladder, the evidence grades and the single mechanical verdict
are exactly as before.

- Each A-J objective is served by named **procedures** (30, `A.1` … `J.3`) with static attributes
  (`CORE` / `EXTENDED` / `ADVERSARIAL` / `DYNAMIC`). Procedures are the *how*; objectives remain the
  *what*.
- **Selection and execution are separate.** Routing decides `SELECTED` / `NOT_SELECTED`; a selected
  procedure then carries exactly one execution status (`DONE` / `LIMITED` / `BLOCKED` /
  `NOT_APPLICABLE`). `NOT_SELECTED` is never an execution status.
- The **route minimum is the floor for every route** (`R1_S1_minimum`); higher risk and larger size
  add rows (two R2/S2 passes, `S3_additions`, and the `R3_minimum` constraint row: at least one
  ADVERSARIAL procedure, a different-nature corroboration, and an independent critical-path re-read).
  Four mandatory surfaces (command execution, auth/permission, file destructive, verifier harness)
  force their own procedures regardless of route.
- **Negative control is disclosed**: the six ADVERSARIAL/DYNAMIC procedures that routing did *not*
  select are listed in the report with reasons.
- **Evidence triangulation** (two different natures on R3 critical paths and qualifying findings) and
  **Review Sufficiency** (`SUFFICIENT` / `LIMITED` / `INSUFFICIENT`, never a verdict) round out the
  reporting contract.

The Selection Matrix is a Markdown table in `SKILL.md` kept in sync

## V2.2 addition — Review Independence

V2.2 answers a question the procedure framework does not: **who reviewed this, and how independent
was the review?**

- The report carries a **Pass ledger** (one line per pass: context, brief mode, authority sha,
  isolation basis) and a report-level **`Review independence`** state:
  `author-self-review` / `sequential-fallback` / `independent-pass`, with a fixed priority when
  several apply (author conflict wins).
- **`independent-pass` is provable, not declared**: the author conflict must be affirmatively
  cleared (`unknown` is the safe default and blocks the claim), the reviewer must run in a
  runtime-confirmed isolated context receiving only the fact-sanitized Independent Review Brief
  (fixed Fact Pack schema, deterministic resolvers, the user's task verbatim), and the authority
  identity must be fixed.
- **Independence caps Review Sufficiency at `LIMITED`** regardless of how many procedures are
  `DONE` - findings and the mechanical verdict stand, but the report cannot claim an independent
  review was completed. Enforcement lives in the runtime layer, which owns authorship and dispatch
  facts; the reviewer's self-assessment is advisory.
The Selection Matrix is a Markdown table in `SKILL.md` kept in sync with a frozen evaluator-only
expectation (`evals/fixtures/procedure-selection.json`), and the harness verifies the registry, the
matrix, the disclosure universe and the reporting markers on every run, with failure-injection
proofs (DM1-DM16) that each check actually goes red when its condition stops holding.
