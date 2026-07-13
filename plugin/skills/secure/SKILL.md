---
name: secure
description: "Use after implementation work lands or before merging — runs the kit's security review loop on the current diff."
---

Post-implementation security gate. A change is never "clean" on vibes — it's clean when `security-reviewer` and `silent-failure-hunter` have actually looked at the diff and you can show what they found (or found clean).

## Steps

1. **Determine the diff scope:**
   - Default: everything this branch/session has touched — unstaged + staged working-tree changes, plus committed work not yet on the default branch (`git diff <default-branch>...HEAD` unioned with the working-tree diff).
   - If the user names an explicit ref/range ("review against `main`", "just the last commit", "PR #42"), use that instead.
   - State the scope in one line before dispatching, so a wrong guess gets corrected before the review runs on the wrong slice.

2. **Dispatch both review agents in parallel, read-only:**
   - `security-reviewer` — secrets, injection, authn/authz, per-user/session data isolation, unbounded allocations, rate limiting, unsafe deserialization, container/CI privilege widening.
   - `silent-failure-hunter` — swallowed exceptions, bare excepts, silent fallbacks, ignored return codes.
   - Both receive the same diff scope from step 1. Neither has edit tools — they report, they don't fix.

3. **Consolidate into one ranked list** (Critical > High > Medium > Low), each finding carrying:
   - `file:line` (or range).
   - A concrete failure/attack scenario — "an attacker with X does Y, causing Z," not "this could be a problem." A finding with no concrete scenario gets dropped or downgraded, not padded in to look thorough.
   - Which agent raised it.
   - A fix direction (one line — this skill doesn't implement; that's a dispatch to `implementer`).

4. **List what was checked and found clean, explicitly.** Pull each agent's "checked and clean" section forward into the consolidated report — silence on a category must never be mistaken for "reviewed, no issue."

5. **Gate the merge:**
   - Any Critical/High finding **blocks** the merge recommendation until fixed.
   - After a fix lands, re-run step 2 on the updated diff before clearing the gate — don't take the fix's correctness on the fixer's word.
   - Medium/Low: report but don't block; note as a follow-up if left unfixed.

## Output

One consolidated report: scope reviewed → findings by severity → checked-and-clean list → merge verdict (**blocked** / **clear**).

## Banned as "clean"

- Dispatching only one of the two agents because the diff "looks like" it's only a correctness change or only a security change — most diffs implicate both classes.
- Treating "no findings returned" from an agent that was never actually dispatched as a clean bill.
- Clearing the gate on a re-review that covers a smaller diff than the one the original findings were raised against.
