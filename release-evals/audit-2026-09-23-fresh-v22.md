# Fresh whole-repo AUDIT — 2026-09-23 (user-dispatched new session, code-review V2.2)

The user opened a NEW conversation on the same machine and dispatched the code-review V2.2 skill
against this repository at `6b0a9fd` - the first real-world use of V2.2 and the authoritative
audit under the standing plan (fresh reviewer, no authoring history).

Verdict: **PASS** - 0 P0 / 0 P1 / 0 P2 / **7 P3** (all doc/record staleness).
Full report text: preserved verbatim in the user's session; findings + verification + disposition
below (all seven findings empirically re-verified by the coordinator before fixing).

## Findings and disposition (fix commit: this commit)

| ID | Sev | Finding | Disposition |
|---|---|---|---|
| CR-001 | P3 | candidate-identity.txt line-count annotation inverted (wc 640/guard 639/no trailing newline; actual 639/640/has-one) | FIXED - note corrected |
| CR-002 | P3 | V2.1-era metadata stale after v22 additions (test-prompts version 2.1.0, "14+7" count, two "Current:" labels) | FIXED - 2.2.0, 14+7+3, labels refreshed |
| CR-003 | P3 | mutation-test.sh header says CR_EVAL_KEEP, cleanup reads MUTATION_KEEP | FIXED - header aligned to code |
| CR-004 | P3 | judge-rubric scenario groups stop at Group D (14/24) | FIXED - Group E + Group V22 added |
| CR-005 | P3 | follow-up ledger drift: s11 (closed at this row's own base_sha) and MS-V21-12 still listed open in READMEs and results.tsv:18 | FIXED - READMEs updated; results.tsv:18 note corrected in place (b72fa58 precedent); MS-V21-12 text landed in V2.2 M1 and the 12 M5 runs verified against that artifact |
| CR-006 | P3 | docs/V2-ARCHITECTURE.md has zero V2.2 coverage while READMEs link it | FIXED - V2.2 section added |
| CR-007 | P3 | in-tree harness copies predate the v22 scenarios (cannot reproduce the 12 runs from the repo) | FIXED - make-briefs.py / build-scenarios.sh / scenario-manifest.json refreshed; MANIFEST shas updated |

## Process finding (the recurrence pattern, now checklist-ed)

CR-002/CR-006 are the THIRD occurrence of the same class (MS-V21-08 -> audit CR-006 -> this
CR-002/006): rapid release iterations leave doc metadata (counts, version strings, "Current:"
labels, open-item lists) stale. Countermeasure added to `evals/README.md` as a mandatory
pre-merge **documentation sweep** (grep version strings, scenario counts, Current: labels,
open-item lists, line counts).
