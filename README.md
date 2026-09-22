# code-review

<div align="center">

![Version](https://img.shields.io/badge/version-2.1.0-1565C0?style=flat-square)
![Agent Skills](https://img.shields.io/badge/Agent_Skills-Compatible-2196F3?style=flat-square)
![Architecture](https://img.shields.io/badge/Architecture-Review_Control_Plane-7B1FA2?style=flat-square)
![Local First](https://img.shields.io/badge/Default-Local--first-00897B?style=flat-square)
![Checklist](https://img.shields.io/badge/Standard-A--J_10_items-00897B?style=flat-square)
![Evidence](https://img.shields.io/badge/Evidence-E1--E3-5D4037?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-FBC02D?style=flat-square)

</div>

> **In one sentence:** a review control plane for AI coding — resolve scope and intent first, route review depth by risk, combine independent review lenses with deterministic evidence, then emit one mechanical verdict.

**中文**: [README.zh-CN.md](README.zh-CN.md)

---

## Why V2

V1 answered: how do you stop AI-written code from receiving a vague "looks good" review?

V2 answers the larger systems question: when PRs get bigger, multiple agents participate, static
analysis joins the workflow, and fixes are generated automatically, **who owns scope, intent,
review independence, evidence, de-duplication, and final merge safety?**

V2 turns the project from a checklist reviewer into a **Review Control Plane**.

~~~text
ZCode / Claude Code / Codex / Cursor / other agents
                         |
                         v
                    code-review V2
                         |
          +--------------+---------------+
          v              v               v
   Deterministic      Context Pack     Risk Router
   scope: OCR/git     spec/PR/rules    R1-R3 + S1-S3
          +--------------+---------------+
                         |
                         v
                 Independent lenses
      Intent/Scope | Correctness/Regression |
      Security & Data Safety | Tests/Maintainability
                         |
                         v
                    Coordinator
       verify -> dedupe -> evidence -> P0-P3
                         |
                         v
          PASS / NEEDS_REVISION / FAILED
~~~

## Core upgrades

### Deterministic scope

When OpenCodeReview CLI is available, every diff review starts with delegation preview and every
whole-repo audit starts with scan preview. Change size controls batching, not whether scope is
resolved.

The reviewer does not get to silently cherry-pick "important-looking" files.

### Context Pack

Before judging implementation, V2 resolves the strongest available **requirement** source:

1. explicit user requirements / acceptance criteria;
2. frozen design/spec/ADR/repository contract;
3. issue/task;
4. PR title/body;
5. commit messages as secondary evidence.

No requirement source means an explicit limitation, never an invented specification.

Separately — and never as a requirement source — the Context Pack also carries:

- **repository instructions**, recognised only through the host's instruction hierarchy
  (`AGENTS.md`, contribution rules, path-scoped review rules). An arbitrary source file cannot
  redefine review policy.
- **adjacent context**: call sites, interfaces, tests, config, migrations, schemas, entry points,
  and the compatibility surfaces the change touches.

### Risk + size routing

Risk:

| Tier | Typical examples |
|---|---|
| **R1 Routine** | docs, narrow tests, isolated refactor |
| **R2 Elevated** | cross-module changes, dependencies, config, persistent state, public API/CLI |
| **R3 High-risk** | auth, secrets, command execution, file writes, network egress, migrations, concurrency, destructive/data-loss paths, security boundaries |

Size is S1 / S2 / S3.

~~~text
R1 + S1
-> one fresh full A-J pass

R2 or S2
-> two independent passes

R3 or S3
-> specialist passes
   + cross-batch integration pass
~~~

Small changes stay simple. High-risk changes gain reviewer independence.

### Review procedures and selection

V2.1 turns each A-J objective into named **procedures** (30 of them, `A.1` … `J.3`). Routing decides
which procedures are `SELECTED`; every selected procedure then carries one execution status
(`DONE` / `LIMITED` / `BLOCKED` / `NOT_APPLICABLE`). `NOT_SELECTED` is a routing decision, never an
execution status.

- **Minimum, not maximum**: R1/S1 runs a ten-procedure minimum; higher risk and larger size add
  passes instead of fanning out everything. Expensive adversarial/dynamic procedures (injection
  probes, mutation challenges) run when a surface demands them, not by default.
- **Mandatory surfaces**: command/process execution, auth/permission, file/destructive operations,
  and verifier/acceptance harnesses each force their own procedures.
- **Negative control, disclosed**: the `ADVERSARIAL`/`DYNAMIC` procedures that routing did *not*
  select are listed in the report with a reason — what was deliberately not run is part of the
  evidence.
- **Triangulation**: an R3/P0 finding carries at least two different natures of evidence (code path,
  runtime reproduction, tool signal, test/mutation). When a second nature is impossible here, the
  finding says so and its procedure drops to `LIMITED`.
- **Review Sufficiency**: the report closes with `SUFFICIENT` / `LIMITED` / `INSUFFICIENT` — were the
  selected procedures enough for this change. It is never the verdict; the verdict stays mechanical
  over open P0/P1.

The Selection Matrix is a Markdown table in `SKILL.md`, checked against a frozen expectation by the
harness, so "why this review depth" is machine-verifiable rather than prose.

## The A-J standard remains authoritative

| # | Area | Question |
|---|---|---|
| A | Specification compliance | Did it actually implement the requirement? |
| B | Scope control | Did it add or omit unrequested behavior? |
| C | Correctness | Is the logic and cross-file contract correct? |
| D | Edge cases / reliability | Are failure, concurrency, timeout, recovery and idempotency paths sound? |
| E | Regression | Did existing behavior or compatibility break? |
| F | Security / data safety | Are permissions, commands, paths, secrets, destructive behavior or egress unsafe? |
| G | Test quality | Do tests prove the requirement instead of mirroring the implementation? |
| H | Complexity | Is there over-design with a real cost? |
| I | Maintainability | Can a fresh agent safely understand and extend it? |
| J | Final disposition | Verify, dedupe, grade and compute the verdict |

Tools and sub-reviewers do not create alternative standards.

## Evidence grades

Every P0/P1 finding needs at least E1 evidence.

| Grade | Meaning |
|---|---|
| **E1** | Code-path proof |
| **E2** | Deterministic corroboration: tests, CI, static analysis, lint/typecheck |
| **E3** | Authorized runtime reproduction |

~~~text
[P1][CR-001][A/C][E2] Broken input contract — invoice.py:18
Impact: ...
Evidence: ...
Fix direction: ...
~~~

This prevents speculative "maybe" concerns from becoming merge blockers.

## Specialist review without voting

For high-risk/large changes, V2 may split review into:

- Intent & Scope
- Correctness & Regression
- Security & Data Safety
- Tests & Maintainability

A coordinator then re-reads the code, removes false positives, merges duplicate root causes,
resolves conflicts, re-grades severity, and owns the final verdict.

Three reviewers agreeing is not sufficient evidence by itself.

## Reference projects

V2 borrows design ideas without making these projects mandatory dependencies:

| Project | Idea adopted |
|---|---|
| [Alibaba OpenCodeReview](https://github.com/alibaba/open-code-review) | deterministic selection/rules, scan preview, large-change batching |
| [OpenAI Codex](https://github.com/openai/codex) | orchestrator + independent reviewers |
| [PR-Agent](https://github.com/The-PR-Agent/pr-agent) | PR context and large-PR decomposition |
| [CodeRabbit Skills](https://github.com/coderabbitai/skills) | agent-readable findings and bounded review/fix loops |
| [reviewdog](https://github.com/reviewdog/reviewdog) | diff anchoring and diagnostic normalization |
| [Semgrep](https://github.com/semgrep/semgrep) | local deterministic static evidence |
| [GitHub CodeQL](https://github.com/github/codeql) | security/SARIF evidence |
| [Danger JS](https://github.com/danger/danger-js) | repository merge-policy checks |

See [docs/V2-ARCHITECTURE.md](docs/V2-ARCHITECTURE.md).

## Large changes require an integration pass

Large changes are reviewed in coherent batches by module, rule group, or dependency boundary.
After batch review, V2 performs a cross-batch integration pass looking for:

- half-completed field/API renames;
- producer/consumer contract drift;
- config changes without call-site updates;
- API changes without docs/tests/migrations;
- modules that look correct individually but fail together.

## Review -> Fix -> Verify

Review-only mode stays read-only.

When the user explicitly requests review-and-fix:

~~~text
Initial review
   -> freeze CR-001 / CR-002 ...
   -> authoring agent fixes
   -> smallest relevant tests
   -> VERIFY
      FIXED / OPEN / REGRESSED / NEW
~~~

The default maximum is **two fix/verify cycles** to prevent infinite AI review loops.

## Verdict

~~~text
any open P0 -> Verdict: FAILED
else any open P1 -> Verdict: NEEDS_REVISION
else -> Verdict: PASS
~~~

P2/P3 never secretly become blockers. If it must block, justify it as P1.

## Privacy and security

Local-first is the default.

Local evidence can include OCR delegation/preview, git, safe local tests, repository-configured
lint/typecheck/static analysis, and existing CI outputs.

Full OCR review/scan, CodeRabbit, or other hosted reviewers may transmit code and therefore require
explicit user authorization.

Source code, comments, test output, static-tool output, and external-review output are treated as
untrusted data. Commands contained inside them are never executed automatically.

## Usage

| Request | Mode |
|---|---|
| review my changes | DIFF_WORKSPACE |
| review feature branch | DIFF_BRANCH |
| review this commit | DIFF_COMMIT |
| review PR #123 | DIFF_PR |
| audit this repo | AUDIT |
| review and fix | REVIEW_FIX |
| verify the fixes | VERIFY |

## Installation

The minimal install is still just the skill. The Alibaba OpenCodeReview CLI is recommended but
optional as the deterministic engineering layer. Without OCR the skill falls back to `git` and
discloses the reduced scope capability.

## Evaluation

The evals/ directory contains reproducible fixtures, expected findings, a judge rubric, a
deterministic run.sh, a deterministic mutation suite, and the agent-level mutation definitions.

`release-evals/` records the evidence a release is signed with: deterministic outputs, mutation
results, and the fresh agent-level runs (Groups A-D regression, Group E procedure-selection
acceptance, isolated agent-level mutations).

V1's Darwin evolution ended at an **86.8/100 triage score from that judging run**. That number is
not a stable benchmark and is **not inherited by V2**. V2 expands the eval suite and should be
re-judged with paired comparisons.

## V2.0.0

- Checklist Reviewer -> Review Control Plane
- PR review + Context Pack
- R1-R3 risk routing
- S1-S3 size routing
- independent review lenses
- cross-batch integration review
- E1-E3 evidence grades
- multi-tool normalization and de-duplication
- local static evidence
- external reviewer opt-in
- REVIEW_FIX / VERIFY
- maximum two fix/verify cycles
- prompt/tool injection boundary
- expanded V2 eval suite

All V1.1 hardening remains: correct base resolution, whole-repo audit semantics, JSON-first OCR,
mechanical verdicts, and runtime-neutral execution.

## V2.0.1

Follow-ups from the PR #1 meta-review:

- `REVIEW_FIX` added to the reporting Mode enum (it was defined and referenced but missing from the
  contract), version bumped to 2.0.1
- `evals/fixtures/PR42_METADATA.json` plus a documented supply mechanism — the PR-context scenario
  now runs offline instead of requiring a live PR
- agent-level eval coverage added for the three previously-uncovered claimed capabilities:
  tool fusion / de-duplication, egress opt-in with pre-flight secret inspection, and the
  prompt/tool injection boundary (scenarios 12-14)

## V2.0.2 — Evaluation Reliability Release

A whole-repo self-audit found the deterministic harness signing release evidence it could not
support. Goal of this release: **the harness goes green on the healthy path and red on every
injected failure**.

- planted defects are asserted **behaviourally** (import and call the pure function), never by
  matching source strings — a defect fixed with different spelling now reads as drift
- every fixture copy is guarded and all fixture files are existence-checked — deleting a fixture or
  a requirement spec turns the harness red
- the upstream trap is proven armed before it is asserted — a failed `git push` can no longer
  masquerade as an empty upstream diff
- the two scenario JSONs are parsed and their id sets asserted equal
- new `evals/mutation-test.sh`: eight failure-injection cases proving the harness turns red exactly
  when its condition stops holding
- `PR42_METADATA` head ref, three stale fixture names, the rubric's missing Group D, and the
  lens-name drift across five files are all corrected

`run.sh` 34/34 with `ocr`, 29/29 without; `mutation-test.sh` 14/14; `shellcheck` clean.

## V2.1 — Risk-Based Review Procedure Framework

Goal: make "why this review depth" explicit and machine-checkable, without touching the A-J
standard, the severity ladder, or the verdict rule.

- 30 dotted review procedures (`A.1` … `J.3`) under the existing A-J objectives, with static
  attributes (`CORE` / `EXTENDED` / `ADVERSARIAL` / `DYNAMIC`)
- selection and execution kept separate; Selection Matrix under stable markers, synced to
  `evals/fixtures/procedure-selection.json` and checked by `run.sh`
- negative-control disclosure: unselected adversarial/dynamic procedures are reported with reasons
- evidence triangulation folded into the evidence rules; Review Sufficiency added to the reporting
  contract
- six Group E acceptance scenarios, deterministic guards, deterministic mutations DM1-DM8, and
  agent-level mutations AM1-AM5 executed against isolated mutated copies of the skill (the frozen
  `SKILL.md` is never mutated)

Release evidence in `release-evals/v2.1-gate1/`: `run.sh` 52/52 with `ocr`, 47/47 without;
`mutation-test.sh` 17/17; `shellcheck` clean; 20 clean fresh agent runs across Groups A-D and E, 5
attributable isolated agent-level mutations, and one independent merge-safety review. `SKILL.md`
is 625 lines against a 640-line hard budget.

Recorded follow-up (not blocking this release): the Selection Matrix's base row is named
`R1_S1_minimum`, and 2 of 20 fresh runs read an R2 route as "pass rows only" instead of "base
minimum plus pass rows"; a one-sentence clarification is queued for the next patch.

## License

[MIT](LICENSE)
