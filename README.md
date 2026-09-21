# code-review

<div align="center">

![Agent Skills](https://img.shields.io/badge/Agent_Skills-Standard-2196F3?style=flat-square)
![Runtime](https://img.shields.io/badge/Runtime-Agnostic-9C27B0?style=flat-square)
![Darwin Optimized](https://img.shields.io/badge/Darwin-Optimized-FF6B35?style=flat-square)
![Score](https://img.shields.io/badge/9--Dim_Score-86.8%2F100-4CAF50?style=flat-square&labelColor=2E7D32)
![Score Improved](https://img.shields.io/badge/Score-%2B11.9-8E24AA?style=flat-square)
![Checklist](https://img.shields.io/badge/Checklist-A--J_10_items-00897B?style=flat-square)
![Tested](https://img.shields.io/badge/Tested-3_Prompts-43A047?style=flat-square)
![Read Only](https://img.shields.io/badge/Mode-Read--Only-00897B?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-FBC02D?style=flat-square)

</div>

> **One line:** a single, self-contained code-review skill that decides *when* to review, *what* to review, and *how* — driven by a ten-item A–J checklist, P0–P3 severity, and exactly one verdict line.

**中文说明**：[README.zh-CN.md](README.zh-CN.md)

---

## Why this exists

When an AI writes the code and an AI reviews it, the human reviewer is missing from the loop. What replaces them is not "read the diff carefully" — it is a **mechanical, itemised quality gate** that runs the same way every time.

This skill is that gate. It is not a linter and not a style guide. It answers ten questions in order, every time, and refuses to let any of them be skipped silently:

| # | Item | The question it answers |
|---|---|---|
| **A** | Specification compliance | Does it actually implement the requirement — or only look like it does? |
| **B** | Scope control | Was anything added that nobody asked for? |
| **C** | Correctness | Is the logic right? |
| **D** | Edge cases | Nulls, exceptions, concurrency, timeouts, failure recovery — considered? |
| **E** | Regression | Did something that used to work break? |
| **F** | Security | Paths, commands, secrets, permissions — any problems? |
| **G** | Test quality | Do the tests prove the feature, or merely pass? |
| **H** | Complexity | Is this over-engineered, at a real cost? |
| **I** | Maintainability | Can a future agent read this and safely continue? |
| **J** | Final disposition | Critical / Major / Minor / Suggestion, plus one verdict |

The two items that catch AI-written code most often are **A** and **G**. The classic AI failure is not a wrong line — it is a function that looks implemented while its required branch is missing, paired with a test that only asserts the happy path. Green tests then certify work that was never done. Item G's test is exactly this: *does the test assert the behaviour the requirement demands, or the behaviour the code happens to have?*

## Install

The skill is a single `SKILL.md`. Drop it into any Agent-Skills-compatible runtime.

```bash
# Claude Code / Codex / Cursor / OpenClaw / Hermes / Gemini CLI — clone into the skills directory
git clone https://github.com/hg199074jin/code-review.git
cp -r code-review ~/.claude/skills/code-review        # or the equivalent path for your runtime
```

Manual: download this repository and copy the folder so that `<skills-dir>/code-review/SKILL.md` exists. Restart the session so the skill description is picked up.

## Usage

Say it in plain language. No skill name to remember, no flags:

| You say | What gets reviewed |
|---|---|
| `审查这次修改` / `review my changes` | the uncommitted workspace changes |
| `审查 xxx 分支` / `review the xxx branch` | that branch against its merge target |
| `审查这个 commit` / `review this commit` | a single commit against its parent |
| `扫描这个仓库` / `audit this repo` | the whole repository, not a diff |

The review is **read-only**: it never edits files, commits, pushes, or posts comments. By default it runs in a fresh reviewer subagent so the judgment is independent of the session that wrote the code.

## How it works

1. **Resolve the target** — workspace, branch, or commit. Ambiguity defaults to the workspace and says so in one line; it never silently reviews a different range than asked for. For a branch, the merge base is resolved by a fixed ladder (user-named target → PR base → repository default branch → `main` → `master` → report and stop). A branch's own tracking upstream is never used as the base — `origin/feature-x` is the *same* branch on the remote, and diffing against it reviews almost nothing.
2. **Resolve the deterministic scope** — whenever `ocr` is available, `ocr delegate preview --format json` runs for every diff review regardless of size (it costs no LLM call); size then decides batching, not whether scope is resolved. Whole-repo audits use `ocr scan --preview --format json` — local enumeration, no LLM. High-risk changes (security, data loss, frozen contracts) get a double pass.
3. **Walk A–J** — all ten items, in order. An item may be marked `➖ not applicable` only with a stated reason. Defect criteria differ by mode: diff reviews flag only what the change introduced (cited range overlapping the diff); whole-repo audits exist precisely to surface pre-existing problems, cited as file:line.
4. **Report** — a coverage line showing which items were checked, findings ordered by severity as `[P1] title — path/to/file.ext:line`, then exactly one verdict line, computed mechanically: any P0 → `FAILED`; else any P1 → `NEEDS_REVISION`; else `PASS`. P2/P3 never change the verdict — if a P2 deserves to block, it is graded P1.

The coverage line is the anti-rubber-stamp device: it forces the review to show, item by item, what was actually checked. `⚠️` means "checked but limited — here is why"; `➖` means "not applicable — here is why".

### Failure modes are part of the spec

A skill that only describes the happy path fails the moment reality disagrees. This one encodes its fallbacks explicitly:

| Trigger | First repair | Still failing |
|---|---|---|
| `ocr` missing or erroring | confirm with `which ocr`, else plain `git diff` | continue natively, state that selection was not deterministic |
| `ocr` rejects `--format json` (older CLI) | retry without `--format`, parse the text output | continue; record which output mode was used |
| Not a git repo / no commits yet | switch to reading the working tree | review the files, state there is no history to compare |
| Branch / SHA does not resolve | try the configured upstream, then `git merge-base` | report "target unavailable" and stop — never substitute a different range |
| Tests cannot be run | detect the project-native runner and run the minimal relevant subset | direct-call only when confirmed safe (no fixtures/parametrize/async/import side effects); else mark E and G `⚠️ static review only` — **never write "tests pass" without running them** |
| Diff too large for one pass | split by directory or module | report which parts were reviewed and which were not |
| Deviation may be intentional | report as an *unconfirmed deviation* | do not decide intent on the author's behalf |
| Confidential repo + external mode requested | 🛑 refuse and review locally | escalate to the user |

## Optional dependency

The skill works standalone. It optionally uses [`ocr`](https://github.com/alibaba/open-code-review) (OpenCodeReview) in **delegation mode**, which runs locally and needs no API key, for deterministic file selection and per-path rule resolution.

```bash
npm install -g @alibaba-group/open-code-review
ocr delegate preview          # reviewable file list for workspace changes
ocr delegate rule <files>     # resolved rules per path
```

Without `ocr`, the skill falls back to `git diff` and says so in the report. Two `ocr` modes are deliberately **not** used by default: `ocr review` and full `ocr scan` require a configured LLM endpoint and transmit content off the machine — the skill refuses them without explicit authorization. `ocr scan --preview` is used: it enumerates files locally with no LLM call, which is exactly what a whole-repo audit needs.

## Project layout

```
code-review/
├── SKILL.md                  # the skill — the whole standard, self-contained
├── evals/                    # reproducible evaluation
│   ├── run.sh                # one command: rebuild fixtures + deterministic checks
│   ├── fixtures/             # baseline / changed sources + SPEC.md
│   ├── test-prompts.json     # 7 scenarios (3 behaviour + 4 regression)
│   ├── expected-findings.json# per-scenario must-report / must-not-report
│   └── judge-rubric.md       # 9-dim rubric + paired-majority protocol
├── docs/
│   └── darwin-result-card.png
├── README.md
├── README.zh-CN.md
└── LICENSE
```

## V1.1 changelog (external review round, 2026-09-21)

All nine findings from an external review were verified and adopted:

- **[P1] base resolution**: the branch's tracking upstream is no longer accepted as a merge target — fixed ladder (user-named → PR base → default branch → `main` → `master` → report). The upstream trap is regression-tested in `evals/run.sh`: `git diff @{u}..HEAD` is empty while `main..HEAD` carries the real delta.
- **[P1] whole-repo vs diff criteria**: §3.4 now defines two modes — diff reviews flag only change-introduced findings overlapping the diff; whole-repo audits surface pre-existing problems as file:line findings.
- **[P2] `ocr scan --preview`** (verified locally, v1.12.7): whole-repo audits now get deterministic local file enumeration instead of giving up on `ocr` entirely.
- **[P2] JSON-first**: all `delegate` calls prefer `--format json`, with a documented text fallback for older CLIs.
- **[P2] routing simplified**: `delegate preview` runs for every diff review regardless of size; size decides batching only.
- **[P2] test fallback tightened**: native-runner detection first; blind import of test modules is forbidden unless confirmed side-effect-free.
- **[P2] verdict made mechanical**: `clustered P2` removed — any P0 → FAILED, else any P1 → NEEDS_REVISION, else PASS.
- **[P3] terminology**: leftover "Critical/Important" wording unified to P0/P1; "read-only" redefined as *source-tree read-only* with explicit test-execution side-effect rules.
- **[P3] runtime neutrality**: the reviewer-subagent instruction no longer names a runtime-specific agent type.
- **reproducibility**: `evals/` added — fixtures, expected findings, judge rubric, and a one-command deterministic check.

## Evolution record

This skill was evolved under the [darwin-skill](https://github.com/alchaincyf/darwin-skill) protocol — design test prompts, baseline evaluation, then rounds of change each decided by three independent judges doing a *paired* comparison of before/after (absolute scores are noise; the paired majority is the ratchet).

| Round | Dimension | Change | Verdict |
|---|---|---|---|
| baseline | — | — | **74.9** / 100 |
| 1 | Failure-mode encoding | added the 7-row fallback table | 3-0 better (clear) |
| 2 | Checkpoint design | 4 explicit 🔴/🛑 markers at decision points | 3-0 better |
| 3 | Overall architecture | merged a triple-stated prohibition into one authoritative section | 3-0 better |
| final | — | — | **86.8** / 100 |

Three rounds, three keeps, zero reverts. The closing regression test is the evidence that matters: the reviewer explicitly invoked the excluded-files checkpoint and the no-pytest fallback — the content added in rounds 1 and 2 was *executed*, not merely written down.

See `docs/darwin-result-card.png` for the scorecard.

## License

[MIT](LICENSE)
