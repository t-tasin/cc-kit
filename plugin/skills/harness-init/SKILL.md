---
name: harness-init
description: "Use when the user asks to set up / initialize the Claude Code harness in a project (new or existing) — analyzes the repo, asks the tier, generates the committed project layer."
---

# harness-init

This is the bridge between cc-kit's two layers. The **universal layer** — the
`implementer`, `architect`, `security-reviewer`, `silent-failure-hunter`, and
`pr-test-analyzer` agents, plus the `harness-init` (this skill), `subagent-briefs`,
`verify-task`, and `resume` skills, plus the gated hooks in `plugin/hooks/` — ships
inside the cc-kit plugin and reaches every project the instant the plugin is enabled.
None of that is committed to the project's own repo. The **project layer** — a
tailored `CLAUDE.md`, `.claude/settings.json`, stack rules, and (tier `full`) a task
board — has to live in the project's own git history so every collaborator gets it on
`git clone`, with no manual setup. `/harness-init` is what writes that project layer,
by reading the repo and the templates shipped in `templates/` next to this file, never
by filling in a generic boilerplate blind to what's actually in the repo.

Work through the five steps below, in order, every time this skill runs — whether
this is the project's first init or its fifth re-run.

## Step 1 — Analyze the repo

Before asking anything or writing anything, read enough of the repo to describe it
accurately:

- **Detect stack(s)** by presence of manifest/build files at the repo root (and one
  level into common subdirs for monorepos): `package.json` → Node/JS/TS (open it —
  `scripts` becomes candidate commands, `devDependencies`/`dependencies` hint at the
  framework and test runner); `pyproject.toml` or `setup.cfg` → Python (open
  `pyproject.toml`'s `[project]`/`[tool.*]` tables for the package name, linter, and
  test runner); `go.mod` → Go; `Cargo.toml` → Rust; `Dockerfile`/`Dockerfile.*` or a
  `docker-compose*.yml` → containerized; a CI config (`.github/workflows/*.yml`,
  `.gitlab-ci.yml`, `.circleci/config.yml`) → note it, both as a stack signal and as a
  maturity signal (below). A repo can have more than one stack (e.g. a Python backend
  and a Node frontend in the same tree) — detect all of them, generate rules for each.
- **Detect maturity**, to inform (not decide) the tier recommendation in Step 2:
  commit count (`git rev-list --count HEAD`, if it's a git repo at all), presence of a
  tests directory or test files (`tests/`, `test/`, `__tests__/`, `*_test.go`,
  `*.spec.ts`, …), and CI config presence. Roughly: an empty or near-empty repo with no
  tests and no CI reads as an experiment; a repo with a real commit history, tests, and
  CI reads as long-lived and serious. This is a heuristic for the recommendation in
  Step 2, never a silent decision — the user always gets the final call.
- **Read any existing harness**: check for `CLAUDE.md` and `.claude/` (especially
  `.claude/cc-kit.json`) before writing anything. Their presence or absence determines
  whether this run is a fresh init (Step 3) or a re-run that must respect Step 4's
  idempotency contract. Do this read now, not as an afterthought in Step 3 — it changes
  what Step 2's recommendation and Step 3's file list should be (e.g. a re-run never
  re-asks for a project name it can already read back out of the existing CLAUDE.md).

## Step 2 — Ask the tier

Ask exactly one question, with the `AskUserQuestion` tool, exactly two options — never
default silently, even when Step 1's signals point clearly one way:

- **Question**: "Which tier fits this project?"
- **Option `full`** — "Long-lived / serious project: everything in lite, plus a
  `TASKS.md` board, a generated `tasks.json` mirror with a CI sync check, tests-first
  hard-gate language in `CLAUDE.md`, and a `tasks/lessons.md` self-improvement loop."
- **Option `lite`** — "Experiment, script, or prototype: a tailored `CLAUDE.md` + stack
  rules + hooks wiring only — no board bureaucracy."

State the recommendation implied by Step 1's maturity signals in the question's
context (e.g. "this looks like a fresh scratch repo — lite is probably the fit, but
your call"), but let the user pick either option regardless of what was detected. If
this is a re-run (Step 1 found an existing `.claude/cc-kit.json`), show its current
`tier` value in the question context so the user knows what they're changing, if
anything — re-selecting the same tier is the common case and is exactly as valid an
answer as switching.

## Step 3 — Generate the project layer

Read every file under this skill's own `templates/` directory and instantiate it —
literal placeholders get substituted, authored placeholders get written from Step 1's
analysis. Never invent a fixed value for an authored placeholder; if analysis found
nothing for it, say so explicitly in the output rather than leaving a generic
filler sentence.

**Placeholders:**

| Placeholder | Kind | Source |
|---|---|---|
| `{{PROJECT_NAME}}` | literal | repo directory name, or the `name` field in `package.json` / `pyproject.toml` if one exists and disagrees with the directory — prefer the manifest name |
| `{{DATE}}` | literal | today's date, `YYYY-MM-DD` |
| `{{TIER}}` | literal | the Step 2 answer, `full` or `lite` |
| `{{STACKS}}` | authored | a bullet list of what Step 1 detected, one line per stack, naming the manifest and the key tooling found in it (e.g. `- Python (pyproject.toml) — pytest, ruff`). If nothing was detected, write a single line saying so instead of an empty section. |
| `{{COMMANDS}}` | authored | a bullet list of the commands a contributor actually runs here — `package.json` `scripts` entries, common Python invocations (`pytest`, `ruff check .`) if their tools were detected, `make` targets if a `Makefile` exists, `docker compose up` if a compose file exists. Only list commands the repo can actually run; never guess a command that doesn't correspond to something detected. |
| `{{RULES_IMPORTS}}` | authored | a bullet list of the `.claude/rules/<stack>.md` files written this run (relative paths), or the literal line `(no stack-specific rules — no recognized manifests detected)` when Step 1 found nothing |

**Files written every run (both tiers):**

- `CLAUDE.md` — instantiate `templates/CLAUDE.md.tmpl` verbatim except for the
  placeholder substitutions above. If Step 2's tier is `full`, additionally insert a
  `## Task board` section *inside* the same managed region, immediately before
  `<!-- cc-kit:managed:end -->` — pointing at `TASKS.md`, stating the status flow
  (`NS → IP → IMPL → TEST → MERGED`), the claim-is-status+owner-in-one-edit rule, and
  the rule that `tasks.json` is a generated mirror (`python3 scripts/gen_tasks_json.py`
  after every board edit — never hand-edit `tasks.json`). Omit this section entirely
  for tier `lite` — a lite-tier `CLAUDE.md` never mentions `TASKS.md`.
- `.claude/settings.json` — instantiate `templates/settings.json.tmpl`. It has no
  placeholders; write it as-is (see Step 4 for what changes on a re-run).
- `.claude/cc-kit.json` — instantiate `templates/cc-kit.json.tmpl` with `{{TIER}}` and
  `{{DATE}}`. Start `generatedFiles` empty on a fresh init; tier `full` immediately adds
  `tasks.json` to it (below).
- `.claude/protocol.md` — instantiate `templates/protocol-full.md` for tier `full` or
  `templates/protocol-lite.md` for tier `lite`, copied as-is (neither has
  placeholders) into `.claude/protocol.md`. This is the file `session-start.sh`
  injects at the top of every session — it's what makes the `resume` skill's
  board-aware pickup ritual (or, for `lite`, the plain read-CLAUDE.md reminder) visible
  to the agent before it does anything else.
- `.claude/rules/<stack>.md` — one file per stack Step 1 actually detected, never one
  for a stack that wasn't found. There is no fixed template for these — author each as
  a terse, comment-style bullet list in the spirit of the hook script headers in
  `plugin/hooks/` (a title line, then plain rules, no filler prose): formatter/linter
  to run, test framework and where tests live, language-specific footguns worth naming
  (e.g. for Python: no bare `except:` — the `silent-failure-hunter` agent flags
  swallowed errors on review; for any stack with user input: never trust it unvalidated
  — the `security-reviewer` agent's invariant list covers injection and authz). Keep
  each file short enough to be read in one glance.
- `.gitignore` — append `CLAUDE.local.md`, `.claude/settings.local.json`, and
  `.claude/worktrees/`, but only the lines not already present (check before
  appending; don't duplicate on a re-run).

**Additional files, tier `full` only:**

- `TASKS.md` — instantiate `templates/board/TASKS.md.tmpl` with `{{PROJECT_NAME}}`.
  Written once; see Step 4 for why it is never regenerated on a re-run.
- `scripts/gen_tasks_json.py` — copy `templates/board/gen_tasks_json.py` verbatim
  (`chmod +x`). Then add `"tasks.json"` to `generatedFiles` in the
  `.claude/cc-kit.json` just written, since that's the file this script produces and
  the file `protect-generated.sh` must block direct edits to.
  Also seed `tasks/todo.md` and `tasks/lessons.md` — each is one short paragraph
  explaining what the file is for (an active plan; a running list of corrections
  turned into rules), not a populated example.

Everything in this step is written fresh only if it doesn't already exist, **except**
`CLAUDE.md`, `.claude/protocol.md`, `.claude/settings.json`, and `.claude/cc-kit.json`,
which are always (re)written on every run, subject to Step 4's rules about what part of
each is allowed to change.

## Step 4 — Idempotent re-run

If Step 1 found an existing `.claude/cc-kit.json`, this is a re-run, and three
different contracts apply depending on the file:

1. **Fenced-managed files** (`CLAUDE.md`, `.claude/protocol.md`): only the text
   between `<!-- cc-kit:managed:start -->` and `<!-- cc-kit:managed:end -->` is
   regenerated from the templates and this run's fresh analysis. Everything before the
   start marker and after the end marker is the project's own content and must come
   back byte-for-byte unchanged. If either marker is missing from a file that should
   have it, that's drift — stop, tell the user exactly what's missing, and ask how to
   proceed before writing anything to that file; never silently reinsert fences around
   content you can't be sure hasn't been hand-edited.
2. **Fully-managed JSON files** (`.claude/settings.json`, `.claude/cc-kit.json`,
   marked by `"_ccKitManaged": true`): refresh the kit-owned keys, but never blindly
   overwrite the whole file — merge. Preserve any key the user or another tool added
   that isn't part of the shipped template (e.g. extra `enabledPlugins` entries, extra
   hook wiring in `settings.json`). For `cc-kit.json` specifically, union
   `generatedFiles` rather than replacing it — a fresh run only ever adds entries
   (e.g. a `lite`→`full` upgrade adds `tasks.json`), it never drops one a prior run or
   the user added. If the tier actually changed this run, apply the consequences: a
   `lite`→`full` upgrade adds the tier-`full`-only files from Step 3 if they're not
   already there; a `full`→`lite` downgrade does **not** delete `TASKS.md` or any board
   file that may already hold real task data — instead tell the user the board files
   still exist and ask whether to remove them or leave them in place.
3. **One-time scaffolds** (`.claude/rules/<stack>.md`, `TASKS.md`,
   `scripts/gen_tasks_json.py`, `tasks/todo.md`, `tasks/lessons.md`): write only if
   missing. If one already exists, leave it completely untouched — these accumulate
   real content (actual tasks, actual lessons, a hand-tuned rule) that regeneration
   would destroy. Do not silently skip reporting them, though: if analysis now detects
   a stack with no corresponding rules file yet, or a tier-`full` project is missing a
   scaffold it should have, name the gap in the finish summary (Step 5) and ask before
   creating anything new into a space the user may have deliberately emptied.

In all three cases the rule is the same shape: regenerate what's contractually kit-
owned, touch nothing else, and when something doesn't fit neatly into "regenerate" or
"leave alone," ask instead of guessing.

## Step 5 — Finish

Print a one-screen summary, not a transcript of every file read:

- Every file written or updated this run, grouped as "created" vs. "updated" vs.
  "left untouched (already present)".
- The tier the project ended up on, and whether that changed from before.
- Any drift or open question surfaced in Step 4 that still needs the user's answer.
- Next steps: commit the new/changed files; nothing further to do locally — because
  `.claude/settings.json` pins the cc-kit marketplace and plugin, any collaborator who
  clones the repo and opens Claude Code gets prompted to install the identical
  harness automatically, with no manual setup on their end. Mention that ongoing work
  in this project should now lean on the rest of the kit: dispatch implementation
  through the `implementer` agent (escalating to `architect` for schema/contract or
  security-sensitive design), write dispatch briefs with the `subagent-briefs` skill,
  close tasks out through the `verify-task` skill, and pick up future sessions with
  the `resume` skill.
