# Whole-repo AUDIT — 2026-09-22, by code-review V2.1 (first real-world use)

Authority: `code-review` V2.1 (runtime sha256 `348946ae…`, merged at `84ae4af`).
Target: `/Volumes/ORICO/Projects/code-review` @ `bc5f56a` (main, clean tree, 68 tracked files).
Mode: AUDIT — pre-existing defects reportable at file:line, no diff-overlap requirement.
Full report: the session's final message (this file records the findings table and the verdict).

## Findings (5)

| ID | Sev | Finding | Location |
|---|---|---|---|
| CR-001 | P2 | `expected-findings.json`'s `v2-review-fix-verify-11.initial_must_report` (`command_injection`, `weak_security_test`) cannot be satisfied by its fixture — the fixture's `runner.py` is the safe baseline and its test is already the fixed version (erratum: `release-evals/v2.1-baseline/erratum-s11.md`; fixture decision pending with the record owner) | `evals/expected-findings.json` |
| CR-002 | P2 | the six advisory surface rows carry no trigger semantics in the runtime artifact (select-or-skip judgment is unconstrained); fix deliberately deferred past the release so the evaluated artifact stayed byte-identical (MS-V21-12) | `SKILL.md` §4.3 |
| CR-003 | P3 | post-merge doc staleness: both READMEs still say the release is "awaiting the Human Merge Gate" (it was granted and executed at `84ae4af`); `evals/README.md` cites only the cycle-1 agent-run counts (20 + 6) with no cycle-2 pointer (12 + 3 + Gate 4 ×2) | `README.md:359`, `README.zh-CN.md:366`, `evals/README.md:104-105` |
| CR-004 | P3 | `docs/V2-ARCHITECTURE.md` is linked from both READMEs as the design reference but predates V2.1 — zero mentions of the procedure framework a reader would go there for | `docs/V2-ARCHITECTURE.md` |
| CR-005 | P3 | the captured deterministic outputs in `release-evals/v2.1-gate1/` are cycle-1 artifacts (52/47/17) with no cycle label, while the current numbers (59/54/25) live in other files — a reader opening those files first gets a stale picture | `release-evals/v2.1-gate1/run-with-ocr.txt`, `run-without-ocr.txt`, `mutation.txt` |

## Verified green at audit time (E2/E3)

`run.sh` 59/59 (ocr) and 54/54 (no ocr); `mutation-test.sh` 25/25 (DM1–DM16); `shellcheck` 0;
`SKILL.md` 636/640; the four evidence-dir generator copies hash-identical to the evaluator
workspace; no home-directory paths and no real-shaped credentials anywhere in the tree
(`SECRET_CONFIG.ini` is the documented synthetic fixture); badge 2.1.0 in both READMEs; runtime
skill = repo skill = evaluated artifact (`348946ae`).

## Verdict

**PASS** — mechanically: no open P0, no open P1 (2 × P2, 3 × P3 recorded as follow-ups).
Independence caveat: this audit was run by the session that authored most of V2.1; the standing
route (a fresh reviewer, ideally a different model, once 5–10 real reviews have accumulated)
remains the authoritative next audit.
