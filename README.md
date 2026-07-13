# cc-kit

A reusable Claude Code harness: orchestrator-grade agents, workflow skills, and
gated safety hooks, shipped as a plugin — plus `/harness-init`, a generator that
writes each project's own tailored, committed harness layer.

[![CI](https://github.com/t-tasin/cc-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/t-tasin/cc-kit/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

## The problem

Every new project starts Claude Code from zero: no workflow doctrine, no
subagent policy, no mechanical gates, no stack-specific rules. Hand-building
that harness once and reusing it by copy-paste doesn't scale past a couple of
repos, and every copy immediately starts drifting from the one you actually
improve. cc-kit fixes both: a plugin layer that upgrades every project at once,
and a generator that writes the parts that have to live in the project itself.

## Architecture

The harness splits into two layers:

| Layer | Lives in | Travels by | Contains |
|---|---|---|---|
| **Universal** | the cc-kit plugin | plugin enable in `~/.claude/settings.json` — present in every project automatically, auto-updates | agents, generic skills, generic hooks |
| **Project** | each project's own repo (committed) | `git clone` — reaches every collaborator | tailored `CLAUDE.md`, `.claude/settings.json` pinning the kit, stack rules, optional task-board scaffold |

The bridge between them is `/harness-init`, a skill in the plugin that
*generates* the project layer by analyzing the repo it's run in.

```
              ┌─────────────────────────────────────────┐
              │            cc-kit (this repo)            │
              │  agents · skills · hooks · /harness-init │
              └────────────────────┬──────────────────────┘
                                   │ plugin enable
                                   │ (~/.claude/settings.json)
                                   ▼
              ┌─────────────────────────────────────────┐
              │        every Claude Code session          │
              │   universal agents/skills/hooks present    │
              └────────────────────┬──────────────────────┘
                                   │ run /harness-init
                                   │ inside a project
                                   ▼
       ┌───────────────┐   ┌───────────────┐   ┌───────────────┐
       │  project A     │   │  project B     │   │  project C     │
       │  CLAUDE.md     │   │  CLAUDE.md     │   │  CLAUDE.md     │
       │  .claude/      │   │  .claude/      │   │  .claude/      │
       │  cc-kit.json   │   │  cc-kit.json   │   │  cc-kit.json   │
       │  (committed,   │   │  (committed,   │   │  (committed,   │
       │   per-repo)    │   │   per-repo)    │   │   per-repo)    │
       └───────────────┘   └───────────────┘   └───────────────┘
```

A kit improvement lands once, here, and reaches every project's next session
automatically. A project's own layer only changes when that project re-runs
`/harness-init`.

## Quickstart (60 seconds)

```
claude
> /plugin marketplace add t-tasin/cc-kit
> # enable the "cc-kit" plugin when prompted
cd any-project/
claude
> /harness-init
> # answer one question: full or lite
> # review the generated files, then commit
```

That's it — the project now has a tailored `CLAUDE.md`, stack rules, pinned
plugin settings, and (if you picked `full`) a task board.

## What gets generated

Every tier writes:

- `CLAUDE.md` — stack summary, commands, workflow rules, subagent/model policy
- `.claude/settings.json` — pins the cc-kit marketplace + plugin so collaborators
  who clone the repo get prompted to install the identical setup
- `.claude/cc-kit.json` — the kit manifest and hook-activation marker
  (`{"tier": "full"|"lite", "generatedFiles": [...]}`)
- `.claude/protocol.md` — the short session-start protocol injected by the
  `session-start` hook
- `.claude/rules/<stack>.md` — one file per stack actually detected in the repo

`full` tier (long-lived / serious projects) additionally writes:

- `TASKS.md` — the task board, plus `scripts/gen_tasks_json.py` to generate its
  machine-readable mirror
- `tasks/todo.md` and `tasks/lessons.md` — active plan and self-improvement log
- CI wiring to keep the generated task mirror in sync

`lite` tier (experiments, scripts, prototypes) stops at rules + hooks + a
tailored `CLAUDE.md` — no board bureaucracy.

Re-running `/harness-init` on an already-kitted project is idempotent: it only
rewrites the managed regions (fenced with `<!-- cc-kit:managed:start/end -->`
in Markdown, or `"_ccKitManaged": true` in JSON) and asks before touching
anything else.

## Design principles

- **Mechanical gates beat prose.** Hooks enforce; `CLAUDE.md` explains. A rule
  that only lives in a prompt is a rule that gets forgotten under context
  pressure.
- **Model is a default, not a lock.** Agent frontmatter sets a sensible model,
  but every dispatch can override it — architecture and security-sensitive work
  escalate regardless of what the frontmatter says.
- **Review agents are structurally read-only.** `architect`, `security-reviewer`,
  `silent-failure-hunter`, and `pr-test-analyzer` carry no `Edit`/`Write` tools
  in their frontmatter — they cannot make changes, only report them.
- **Fail open.** Every hook that can't parse its input exits 0. A broken gate
  must never wedge a session.
- **Hooks are gated on an explicit per-project marker.** All universal hooks
  check for `.claude/cc-kit.json` first and no-op instantly if it's absent —
  enabling the plugin globally is safe even in repos that haven't opted in.

## What's in the plugin

- **Agents:** `implementer` (default engine for briefed implementation work),
  `architect` (design-only, no edit tools), `security-reviewer`,
  `silent-failure-hunter`, `pr-test-analyzer` (the last three are read-only
  review specialists).
- **Skills:** `harness-init` (the generator described above),
  `subagent-briefs` (how to write and iterate on a dispatch brief),
  `verify-task` (evidence-before-assertion discipline before calling anything
  done), `resume` (generic session pickup — board-aware if the project has
  one).
- **Hooks:** `secrets-guard` (blocks edits to `.env*`, `.env.example`
  excepted), `protect-generated` (blocks edits to files a project has declared
  generated), `session-start` (injects the project's `.claude/protocol.md` if
  present). All three gate on `.claude/cc-kit.json` and fail open.

## Trust note

Enabling this plugin means tracking this repo's `HEAD` — the same trust
surface as any other Claude Code plugin, and the same one this project's
lineage note (below) critiques in a larger ecosystem. The difference is size
and auditability: cc-kit is a handful of reviewable files (five agent
definitions, four skills, three hooks), it has no wildcard, always-on hooks,
and every hook is gated on an explicit per-project marker rather than firing
unconditionally. Version pinning for consumers — so a project can track a
specific kit release instead of `HEAD` — is not yet implemented; it's the
natural next step and is tracked as future work.

## Lineage

cc-kit's agents, skills, and hooks are distilled from a production Claude Code
harness built and run on a real multi-week engineering project, then
generalized so nothing project-specific survived the port. A handful of
structural patterns — the shape of a gated hook, the review-agent/read-only
split — were also informed by the [ecc ecosystem](https://github.com/affaan-m/ecc)
at pinned commit
[`4092795`](https://github.com/affaan-m/ecc/tree/40927950c49f6e742d341e20ff7b9b7e1e7bfff5).
cc-kit cherry-picks specific patterns rather than installing that ecosystem
wholesale: a smaller, auditable set of files beats a larger always-on
installation that expands prompt bloat, runs wildcard hooks unconditionally,
and widens the surface through which injected instructions can reach the
agent.

## License

MIT — see [LICENSE](./LICENSE).
