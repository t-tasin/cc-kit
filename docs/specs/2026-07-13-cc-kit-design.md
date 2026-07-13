# cc-kit — reusable Claude Code harness · design spec

**Date:** 2026-07-13 · **Status:** approved design, pre-implementation
**Repo:** `github.com/t-tasin/cc-kit` (public, MIT) · **Author:** @t-tasin + Claude

## 1. Problem

Every new project starts Claude Code from zero: no workflow doctrine, no subagent
policy, no mechanical gates, no stack rules. The basanos project proved the fix — a
committed harness (CLAUDE.md + `.claude/` hooks/agents/skills/rules) makes agent
behavior consistent across contributors and model generations — but that harness was
hand-built for one repo. Rebuilding it per project doesn't scale; copying it drifts.

## 2. Solution shape (approach A — hybrid)

Split the harness into two layers:

| Layer | Lives in | Travels by | Contains |
|---|---|---|---|
| **Universal** | cc-kit plugin | plugin enable in `~/.claude/settings.json` — present in every project automatically, auto-updates | agents, generic skills, generic hooks |
| **Project** | each project's repo (committed) | git clone — reaches every collaborator | tailored CLAUDE.md, settings.json pinning the kit, stack rules, optional board scaffold |

The bridge is **`/harness-init`**: a skill in the plugin that *generates* the project
layer by analyzing the repo.

Rejected alternatives: template repo (copy = drift; improvements never reach existing
projects), pure-global config (collaborators get nothing; no per-project tiering).

## 3. Repo structure

```
cc-kit/
├── .claude-plugin/marketplace.json    # repo doubles as a plugin marketplace
├── plugin/
│   ├── .claude-plugin/plugin.json     # "cc-kit" plugin manifest
│   ├── agents/
│   │   ├── implementer.md             # sonnet default; tests-first gate; escalation stop-clause
│   │   ├── architect.md               # opus; design-only; no Edit/Write tools
│   │   ├── security-reviewer.md       # opus; read-only; generic invariants
│   │   ├── silent-failure-hunter.md   # opus; read-only; swallowed-error hunter
│   │   └── pr-test-analyzer.md        # opus; read-only; rubber-stamp-test hunter
│   ├── skills/
│   │   ├── harness-init/SKILL.md      # ⭐ the generator (§4)
│   │   ├── subagent-briefs/SKILL.md   # brief-writing + dispatch→evaluate→refine loop
│   │   ├── verify-task/SKILL.md       # evidence-before-assertion discipline
│   │   └── resume/SKILL.md            # generic session pickup (board-aware if present)
│   ├── hooks/
│   │   ├── hooks.json                 # plugin hook registration
│   │   ├── protect-generated.sh       # blocks edits to files listed in .claude/generated-files
│   │   ├── secrets-guard.sh           # blocks .env* edits (.env.example allowed)
│   │   └── session-start.sh           # injects project protocol if .claude/protocol.md exists
├── docs/specs/                        # this spec + future ones
├── README.md                          # public-facing: what/why/demo (§7)
└── LICENSE                            # MIT
```

## 4. `/harness-init` — the generator

Run inside any project (new or existing). Behavior:

1. **Analyze** — detect stack (package.json, pyproject.toml, go.mod, Cargo.toml,
   Dockerfiles, CI configs), repo size/maturity, existing conventions, existing
   CLAUDE.md/.claude (idempotency, step 4).
2. **Ask tier** — one question:
   - **full** — serious/long-lived project: everything in lite, plus TASKS.md board +
     `scripts/gen_tasks_json.py`-style generated mirror + CI sync check, test-first
     hard-gate language, `tasks/lessons.md` self-improvement loop, PR-evidence
     discipline.
   - **lite** — experiments, scripts, prototypes: tailored CLAUDE.md + stack rules +
     hooks wiring + settings pinning. No board bureaucracy.
3. **Generate the project layer** (committed files):
   - `CLAUDE.md` — written from the analysis, not a fill-in-the-blank template:
     detected stack + commands, tier-appropriate workflow rules, orchestrator/subagent
     policy referencing the kit's agents, escalation criteria table.
   - `.claude/settings.json` — pins the cc-kit marketplace + plugin (collaborators who
     clone get prompted to install the identical setup), plus a curated
     `enabledPlugins` baseline; `effortLevel`; hooks wiring for project-local hooks if
     any.
   - `.claude/rules/<stack>.md` — one per *detected* stack only.
   - `.claude/generated-files` — manifest consumed by `protect-generated.sh`
     (e.g. basanos would list `tasks.json`).
   - `.claude/protocol.md` — the short session-start protocol `session-start.sh`
     injects (tier-appropriate: full = board ritual, lite = read-CLAUDE.md reminder).
   - tier-full only: `TASKS.md` scaffold, gen script, `tasks/lessons.md` +
     `tasks/todo.md` seeds, CI sync-check snippet.
   - `.gitignore` additions: `CLAUDE.local.md`, `.claude/settings.local.json`,
     `.claude/worktrees/` (keeps shared files tracked).
4. **Idempotent re-run** — if a harness exists: diff, reconcile, upgrade in place;
   never clobber user customizations (marked sections / ask on conflict).

## 5. Design principles (inherited from basanos, baked into everything generated)

- **Mechanical gates beat prose** — hooks enforce; CLAUDE.md explains.
- **Model = default, not lock** — agent frontmatter model is overridden per dispatch;
  escalation criteria live in the generated CLAUDE.md.
- **Review agents are structurally read-only** — no Edit/Write in frontmatter, not
  just instructions.
- **Fail open** — a hook that can't parse its payload exits 0; a broken gate must
  never wedge a session.
- **Personal ≠ shared** — personal config goes to gitignored local files; the kit and
  generated layers contain zero secrets and zero machine-specific paths.

## 6. Update & consumption flows

- **Kit improvement:** edit cc-kit → push → plugin auto-update → every project (past
  and future) gets it next session. Project layers only change on `/harness-init`
  re-run.
- **New project (you):** `claude` → `/harness-init` → answer tier → commit.
- **Collaborator:** `git clone` → open Claude Code → prompted to install pinned
  marketplace/plugin → identical harness, zero instruction.
- **basanos migration (later, separate task):** enable kit, re-run init, shrink its
  `.claude/` to project-specific residue (deploy-z2 skill, basanos rules, board).
  basanos becomes the kit's first consumer + living demo.

## 7. Public/showcase requirements

- **MIT license.** No personal data anywhere: no server names, no tailnet details, no
  employer/project internals. (Verified: universal layer is pure doctrine.)
- **README is recruiter-grade:** the problem, the two-layer architecture (diagram),
  a 60-second quickstart, a "what it generates" example, credits/lineage note (ideas
  cherry-picked from the ecc ecosystem at a pinned commit, with the
  quarry-not-framework rationale).
- Clean conventional-commit history from the first commit.

## 8. Testing

- `bats`-or-plain-bash self-test for each hook (mirrors basanos `test-hooks.sh`
  pattern: crafted stdin payloads → expected exit codes; fail-open case included).
- Frontmatter validation script (yaml-parse every agent/skill) wired as a CI check
  (GitHub Actions, free tier).
- `/harness-init` acceptance: run against two fixture repos (a Python service, a
  bare-new dir) in CI or scripted local check; assert generated files parse and tier
  differences hold.

## 9. Out of scope (v1)

- npm/npx installer, Codex/Cursor/other-harness adapters, paid/marketplace listing.
- Auto-migration of basanos (separate follow-up task on the basanos board).
- Windows support for hook scripts (bash assumed; document it).

## 10. Success criteria

1. Fresh empty dir → `/harness-init` → working tiered harness in under 2 minutes.
2. Existing real repo (basanos) adopts the kit with its project layer shrunk, no
   behavior regression.
3. A collaborator cloning a kitted project reaches identical agent/hook/skill
   behavior with zero manual setup beyond accepting the install prompt.
4. A kit improvement lands in all kitted projects without touching their repos.
