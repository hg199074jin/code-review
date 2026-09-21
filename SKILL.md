---
name: code-review
description: The single entry point for code review — decides when to review, what to review, and how. Use whenever the user asks to review code ("审查这次修改", "review my changes", "审查 xxx 分支", "审查这个 commit", "扫描/审计这个仓库", "code review"), or proactively when a task finishes, a major feature lands, or before a merge. Ships the A–J checklist, P0–P3 severity, and a single PASS / NEEDS_REVISION / FAILED verdict. Uses the `ocr` CLI as its deterministic file-selection engine.
---

# Code Review

This is the **only** skill needed for code review. It covers **when** to review, **what** to
review, **how** to review, and **how to report**. The `ocr` CLI is a tool, not a skill. The
former `review-agent` skill has been merged into this file and now only holds a compatibility
pointer — do not load it.

Write the report in the user's language (Chinese for this user); keep code identifiers, paths,
commands, and verdict lines verbatim.

## 1. When to review

**Mandatory:**
- After each task in subagent-driven development.
- After a major feature is completed.
- Before merging to `main`.

**Optional but valuable:**
- When stuck (a fresh pair of eyes).
- Before refactoring (record a baseline first).
- After fixing a complex bug.

**Red lines:** never skip a review because "it is simple"; never ignore a Critical finding; never
proceed with an unfixed Important finding.

## 2. What to review — resolve the target

Run every git/ocr command from the repository root the user is working in.

| User says | Target |
|---|---|
| "审查这次修改" (no qualifier) | workspace changes: `ocr delegate preview` |
| "审查 xxx 分支" | `ocr delegate preview --from <base> --to <branch>`; base = the merge target the user names, else the branch's upstream, else `main` |
| "审查这个 commit/SHA" | `ocr delegate preview --commit <sha>` |
| "扫描/审计整个仓库" | whole-repo audit, not a diff review — see §3.1 |

If the request is ambiguous, default to the workspace changes, state that assumption in one line,
and continue. Never silently review a range other than the one asked for.

Before reporting findings, state the resolved target and the ocr file checklist, **including what
the pipeline excluded** (for example test paths).

🔴 **CHECKPOINT** — before reviewing, confirm you have read every excluded file the change actually
touches (tests under a default-excluded path are the common case). Skipping this is exactly how a
whole test-file change goes unreviewed.

## 3. How to review

### 3.1 Size the target and route

Determine changed-file count and diff size before reading anything.

- **Small change** (≤5 files or a compact diff): review natively per §3.3.
- **Medium/large change** (many files, refactor, cross-module change, pre-merge or release gate):
  run `ocr delegate preview` for the deterministic reviewable-file list, then
  `ocr delegate rule <files>` for the resolved per-path rules. Treat the OCR list as the file
  checklist and review every file it selects; if it excludes a file the change actually touches
  (for example tests under a default-excluded path), inspect it manually anyway. Use
  `ocr rules check <path>` when a single path's rule is in question.
- **Whole-repository audit or unfamiliar legacy code:** 🛑 **STOP** — `ocr scan` is not available in
  the default local setup (§5). Audit natively instead: read `AGENTS.md`, entry points,
  configuration, and tests, then apply §3.3 to what you read.
- **High-risk change** (security-sensitive code, data-loss paths, frozen contracts): double pass —
  the OCR pipeline output plus an independent full re-read of the critical paths.

If the repository defines `.opencodereview/rule.json`, honor those path-scoped rules in addition
to the applicable `AGENTS.md` instructions.

### 3.2 Execution mode

Prefer dispatching a `general-purpose` subagent as the reviewer so it works from a fresh context
rather than the session history. Hand it:

- `{DESCRIPTION}` — what was built, in one or two sentences.
- `{PLAN_OR_REQUIREMENTS}` — the plan file path, task text, or requirement the work must satisfy.
- `{BASE_SHA}` / `{HEAD_SHA}` (or "workspace changes").
- This file's §3.3–§4 as its review standard.

The review is **read-only**: `git show`, `git diff`, `git log`, and reading files only. Never move
HEAD, stage, or mutate the working tree; use `git worktree add /tmp/review-<sha> <sha>` if another
revision must be materialized. The reviewer never dispatches its own subagents — it reviews in
passes itself and says so. The main agent may review a small, clearly-scoped change in context.

### 3.3 The A–J checklist — check every item, every time

Work through all ten items in order. Do not skip an item because the change "looks simple"; mark it
➖ only when it genuinely does not apply, and say why.

**A. Specification compliance — does it actually implement the requirement?**
- Find the design basis first: task brief, plan document, requirement text, or a `FROZEN`
  convention in `AGENTS.md`. If none exists, say so explicitly in the report instead of pretending
  to have compared against one.
- Walk each requirement and confirm it is genuinely implemented: complete functionality, the
  agreed interface / CLI / output shape, and every acceptance criterion.
- Hunt the classic AI failure: "looks implemented but is not" — only the happy path is handled, a
  field is returned unpopulated, an error branch silently swallows the failure.
- Judge the implementation, not the design. If the design itself is wrong, say so separately.

**B. Scope control — was anything added that was not asked for?**
- List every part of the change with no basis in the requirement: new config keys, parameters,
  files, dependencies, "just in case" abstraction layers.
- For each, decide whether it is necessary or self-added; report the self-added ones as
  Minor/Suggestion. Also check the reverse direction — anything the requirement asked for that is
  missing belongs under A.

**C. Correctness — is the logic right?**
- Main-path logic, boundary arithmetic, conditionals, state transitions, error propagation.
- Call sites versus implementation: signature, return-value semantics, exception types.
- Consistency with how existing code and the docs describe the behaviour.

**D. Edge cases — exceptions, nulls, concurrency, timeouts, recovery**
- Empty / `None` / empty collection / empty string; zero, negative, and extreme values; Unicode and
  path separators.
- Concurrency and races; timeouts and retries; failure recovery and partial failure; idempotency.
- Untrusted input: user input, file contents, network responses, missing environment variables.

**E. Regression — did anything that used to work break?**
- Who calls the changed function, module, or config key, and does the old behaviour still hold?
- Run the existing tests; do not infer their result by reading code.
- Backward compatibility of output formats, file names, CLI flags, and config keys; migration paths.

**F. Security — paths, commands, secrets, permissions**
- Paths: concatenation, traversal (`../`), symlinks, whether the write location is controllable.
- Commands: shell invocation and injection surface; are arguments fixed and controlled?
- Secrets: hard-coded tokens, passwords, or keys; sensitive values printed to logs; `.env` committed.
- Permissions: file modes, unnecessary privilege, anything bound to `0.0.0.0`.
- Egress: does the change send content to an external service?

**G. Test quality — do the tests prove the feature, or merely pass?**
- Do the tests assert the behaviour the requirement demands, or the behaviour the code happens to
  have? The latter is a test written to fit the implementation.
- Are there tests that assert nothing (run-only), or that mock the very object under test?
- Are failure paths covered — errors, boundaries, exceptions?
- Does every new or changed behaviour have a corresponding test; are tests reproducible and
  order-independent?
- Name the specific gap, e.g. "no test covers the empty-input branch of `parse()`".

**H. Complexity — over-engineering**
- Report only over-design with a real cost: an unused abstraction, a config key nobody reads, an
  unnecessary dependency, generalisation beyond the requirement, extra failure surface or
  maintenance burden.
- Never report taste disagreements (naming, formatting, preference). When in doubt, either omit it
  or mark it a Suggestion.

**I. Maintainability — can a future agent take this over?**
- Could an agent in a brand-new session read only the code and docs, understand the intent, and
  safely continue?
- Do names and comments explain *why* rather than restate the code; are README, help text, and
  docs in sync with the implementation?
- Dead code, duplicated logic, magic numbers without explanation.

**J. Final disposition — severity and verdict**
- `P0` Critical — release blocker, data loss, security hole, core functionality broken.
- `P1` Major — urgent defect to fix next (correctness, edge case, regression, faked tests).
- `P2` Minor — ordinary defect to fix, or over-design with a real cost.
- `P3` Suggestion — low-impact improvement.
- Exactly one verdict line: `PASS` (no P0/P1), `NEEDS_REVISION` (any P1, or clustered P2),
  `FAILED` (any P0 — must not merge or ship).

### 3.4 What counts as a defect

🔴 **CHECKPOINT** — before recording any P0 or P1, confirm you can demonstrate the failing scenario
from code you actually read. If you cannot demonstrate it, downgrade it or drop it.

Flag an issue only when **all** of these hold:

- It affects correctness, security, performance, or maintainability in a meaningful way.
- It is discrete and actionable.
- It was introduced by the reviewed change.
- The affected scenario or call path can be demonstrated from the code.
- The author would probably fix it if they knew about it.

Do not flag speculative concerns, pre-existing problems, intentional behaviour changes, or style
nits that do not obscure the code.

### 3.5 Failure modes and fallbacks

Each row is a real failure the review can hit. Work the columns left to right; never stop at the
first column and never fall back to silence.

| Trigger | First repair | Still failing |
|---|---|---|
| `ocr` not on PATH or `ocr delegate preview` errors | Confirm with `which ocr`; if absent, review with plain `git diff` and record "no ocr" in the report | Continue the native review; state in the report that file selection was not deterministic |
| Not a git repository, or no commit yet (no `HEAD`) | `ocr delegate preview` cannot resolve a diff — switch to reading the working-tree files directly | Review the files as they are; state that there is no history to compare against |
| The named branch, commit, or SHA does not resolve | Try the branch's configured upstream explicitly: `git rev-parse --abbrev-ref --symbolic-full-name @{u}`, then `git merge-base HEAD <ref>` | Report "target unavailable" and stop. **Never silently substitute a different range** |
| Tests cannot be run (no pytest, no runner, missing deps) | Invoke the test functions directly by importing the module, one by one | Mark E and G as ⚠️ "tests not executed, static review only". **Never write "tests pass" without having run them** |
| The diff is too large for one pass | Split by directory or module and review in passes; say in the report how many passes you made | Do not truncate silently — report which parts were reviewed and which were not |
| A deviation may be intentional or may be a mistake | Report it as an **unconfirmed deviation** and ask the author to confirm | Do not decide intent on the author's behalf in either direction |
| The repository holds confidential material and an external mode is requested | 🛑 **STOP** — refuse and review locally instead (§5) | Escalate to the user; do not proceed on assumption |

## 4. How to report

```
## 目标与范围
<resolved target, base..head or workspace, and the ocr file checklist including exclusions>

## 检查覆盖
A 规格符合性 ✅ | B 范围控制 ✅ | C 正确性 ✅ | D 边界情况 ✅ | E 回归 ✅ |
F 安全 ✅ | G 测试质量 ✅ | H 复杂度 ✅ | I 可维护性 ✅ | J 分级 ✅
（✅ 已查 ｜ ⚠️ 查了但受限（说明原因）｜ ➖ 不适用（说明原因））
```

Then findings first, ordered by severity, one entry per issue:

`[P1] Imperative finding title — path/to/file.ext:line`

Follow the title with one short paragraph explaining the affected scenario and why the behaviour is
wrong. Keep the cited range as small as possible and make sure it overlaps the reviewed diff. If
there are no qualifying findings, say `No findings.` — never invent one to fill the report.

Close with a brief overall assessment that names any material test gaps and residual risks, then
exactly one verdict line: `Verdict: PASS` / `Verdict: NEEDS_REVISION` / `Verdict: FAILED`.

🔴 **CHECKPOINT** — the verdict is exactly one line and must match the findings you listed: no
P0/P1 → PASS; any P1, or clustered P2 → NEEDS_REVISION; any P0 → FAILED. Do not soften a verdict to
avoid an awkward conversation, and do not upgrade one to look thorough.

## 5. Boundaries

- Read-only: never modify files, commit, push, or post review comments.
- Delegation mode only: `ocr delegate preview` / `delegate rule` run locally and need no key.
  Provider-based `ocr review`, `ocr scan`, and any ocr LLM endpoint or key configuration transmit
  content off the machine — 🛑 never run or configure them without explicit user authorization
  (AGENTS.md §21).
- This skill is the only entry to the review stack: do not install or invoke ocr's official
  companion skills, and do not load the legacy `review-agent` skill.
- `superpowers:requesting-code-review` remains the trigger used by automated development flows and
  ships its own reviewer template; it is complementary, not a competing standard. If the two
  disagree, this skill's A–J checklist is the standard for user-requested reviews.
