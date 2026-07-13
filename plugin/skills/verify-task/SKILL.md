---
name: verify-task
description: "Use before marking any task TEST or MERGED — run its verify: and capture evidence. No green-by-skip, no reduced scope, evidence before assertion."
---

Verification gate for project tasks. A task is never "done" on vibes — it's done when its verify criteria actually ran and passed, and you can show the output.

## Steps

1. **Locate the acceptance/verify criteria** for the task — from the project's board (e.g. a `verify:` line attached to the task entry) if one exists, else the criteria stated when the work was requested. If the task also serves a requirement or spec document named in the project's `CLAUDE.md`, re-check the verify criteria cover that document's acceptance criterion, not just a narrower proxy for it.

2. **Run the FULL scope, not a subset:**
   - No green-by-skip (don't quietly skip a sub-check that's inconvenient right now).
   - No `xfail`/`skip` markers on a case the verify criteria require.
   - No reduced scope ("it passes for the happy path" when the criteria also name an edge/negative case) — the full criteria or it doesn't count.
   - If the criteria imply both a local check and a CI-run check, both must actually pass — CI green is required before flipping to an in-review state (see the project's `CLAUDE.md`); a task counts as done only when the FULL criteria pass, never a reduced scope.

3. **Capture real evidence:**
   - Actual command output (test runner output, curl/response bodies, screenshot description, log excerpt) — not a paraphrase like "tests pass."
   - This evidence goes in the PR description so a reviewer (human or CI) can see it without re-running everything themselves.

4. **If the full verify criteria cannot be met:**
   - Do **not** mark the task done (or its board-equivalent "in review"/"merged" state) anyway. This is a hard rule where the project's `CLAUDE.md` declares one — no silent scope reduction.
   - Instead: re-scope the task on the board — note exactly what was cut and why, open a follow-up task (new ID, never renumber/reuse an existing one) to cover the gap, and tell the user directly what's missing and why.

5. **Bar check:** before calling it done, ask "would a staff engineer approve this?" If the honest answer is "only if they didn't look closely," it's not verified yet.

## Banned as "verification" (these are not evidence)
- "Looks right" / "should work" without a run.
- A test that can't fail (tautological assert, `assert True`, import-only smoke test) counted as coverage.
- Mocking away the exact code under test and calling the mock's success a pass.
- Citing a test written *after* the implementation, whose only job is to match what the code already does.

These overlap with the test-first hard gate the `implementer` subagent follows — if you're verifying someone else's (or a subagent's) work and see one of these, the task isn't verified, regardless of what the test suite reports as green.
