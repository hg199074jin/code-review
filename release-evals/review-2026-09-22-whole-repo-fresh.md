# Fresh whole-repository review — 2026-09-22 (requesting-code-review dispatch)

Reviewer: independent general-purpose subagent (fresh context, no authoring history), dispatched
via the requesting-code-review template at the user's request, with an explicit mandate to review
ALL generations (V1 → V2.1) because earlier code had never had a fresh reviewer.
Range: full history `9df16f0..3357d32`; every tracked file at HEAD read; suites re-run by the
reviewer (59/59 + 54/54, 25/25, shellcheck 0 — all release numbers reproduced) plus three
controlled false-green deletion probes on throwaway copies.

## Verdict

"With fixes — main is healthy for the skill itself, but the deterministic verifier has three
deletion-blind-spot windows that contradict its own release thesis." **0 Critical, 4 Important,
8 Minor.** Full report text preserved in the session transcript; findings and disposition:

| # | Sev | Finding | Origin | Disposition |
|---|---|---|---|---|
| 1 | Important | deleting `procedure-selection.json` silently skipped ~10 guards and stayed green (49/0); file absent from ALL_FIXTURES; no DM case | V2.1 (9f7d096) | **FIXED**: named guard `selection_expectation_file_present` + ALL_FIXTURES entry + DM17 |
| 2 | Important | `frozen_universe_field_in_sync` / `r1_forbidden_defaults_in_sync` passed on field absence | V2.1 (c91085b) | **FIXED**: absence now fails + DM18/DM18b |
| 3 | Important | scenario sync detected desync but not joint deletion — PRC-07 could vanish from both JSONs and stay green | V2.0.x (OR-009 design) | **FIXED**: frozen scenario-id set asserted + DM19 |
| 4 | Important | s11 `initial_must_report` unsatisfiable against its fixture | V2.0.x | **OPEN** — fixture decision belongs to the record owner (erratum-s11.md); any fresh agent-suite run must adjudicate it |
| 5-8, 12 | Minor | stale counts/labels (7 not 6 Group E cases; stale AM1 F.1 line; unlabeled cycle-1 artifacts; README adversarial-procedure caveat) | mixed | **FIXED** in the same commit (docs/labels only) |
| 9, 10, 12a | Minor | SKILL.md wording items (R1-disclosure absoluteness; "no tier skips A–J" vs the R1 floor; H1 still says "V2") | V1/V2/V2.1 | **DEFERRED** — any SKILL.md edit invalidates the cycle-2 evidence; batched with MS-V21-12 in the next patch |
| 7 | Minor | M2/M3/M5–M7 accept any FAIL line (attribution only implemented for M4/DM) | V2.0.x | **DEFERRED** — refactor the legacy M-cases next time mutation-test.sh opens |
| 11 | Minor | injection probes execute `jobctl run` if a jobctl binary exists on PATH | V2 | **DEFERRED** — harmless on stock machines |

Fix commit: harness + docs only. `SKILL.md` untouched — the released artifact remains
`348946ae…` and the cycle-2 agent evidence stays valid. After the fixes: run.sh 59/59 (ocr) and
54/54 (no ocr), mutation-test **29/29** (DM1–DM19b), shellcheck clean.
