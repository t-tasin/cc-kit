# cc-kit — Live Acceptance Runbook

> **This is a manual runbook, not an automated test.** It requires an interactive
> Claude Code session with the cc-kit plugin enabled — `/plugin marketplace add`,
> the `AskUserQuestion` tier prompt in `/harness-init`, and a live PreToolUse hook
> block cannot run headless in CI. Nothing in this file executes on its own; a
> human (or an agent with an attached interactive Claude Code session) must run
> each scenario below, in order, and record the actual output.
>
> **Do not perform the live run from this document alone.** When it is run, paste
> the captured output/evidence for all four scenarios into the `v0.1.0` tagging
> commit (Task 8) so the acceptance evidence ships with the tag.

Every command block below is copy-pasteable as-is into a terminal. Every
assertion names the exact file and the exact string/value to check, and prints
`PASS: ...` or `FAIL: ...` so results can be pasted verbatim as evidence.

## Prerequisites

- Claude Code CLI installed and logged in (`claude --version` runs).
- `python3` on `PATH`.
- macOS (this repo's dev machine) — the checksum commands below use `md5 -q`;
  on Linux substitute `md5sum` and compare the first field.
- The `cc-kit` repo pushed to `github.com/t-tasin/cc-kit` (confirm with
  `git -C /Users/tasin/Desktop/Codebase.nosync/cc-kit log --oneline -1` and
  `git -C /Users/tasin/Desktop/Codebase.nosync/cc-kit remote -v`). If testing
  before a push, use the local-path marketplace variant noted in Scenario 1.

---

## Scenario 1 — Install the kit

1. Start a Claude Code session anywhere (a scratch dir is fine):

   ```bash
   claude
   ```

2. Inside the session, add the marketplace and enable the plugin:

   ```
   /plugin marketplace add t-tasin/cc-kit
   ```

   Local-path variant (use this instead if the repo isn't pushed yet — point it
   at the working tree):

   ```
   /plugin marketplace add /Users/tasin/Desktop/Codebase.nosync/cc-kit
   ```

   When prompted, enable the **`cc-kit`** plugin from the **`cc-kit`**
   marketplace.

3. **Assert:** the plugin shows as enabled. Either:
   - run `/plugin` inside the session and confirm `cc-kit@cc-kit` is listed as
     enabled, **or**
   - check the CLI's own settings file on disk:

     ```bash
     python3 -c "
     import json
     d = json.load(open('$HOME/.claude/settings.json'))
     assert d.get('enabledPlugins', {}).get('cc-kit@cc-kit') is True, d
     print('PASS: cc-kit@cc-kit enabled in ~/.claude/settings.json')
     "
     ```

   Expected output: `PASS: cc-kit@cc-kit enabled in ~/.claude/settings.json`.

---

## Scenario 2 — Fixture A: lite tier

1. Seed the fixture (plain shell, no Claude needed yet):

   ```bash
   mkdir -p /tmp/fixture-py/src && cd /tmp/fixture-py

   cat > pyproject.toml <<'EOF'
   [project]
   name = "fixture-py"
   version = "0.1.0"
   requires-python = ">=3.11"

   [tool.pytest.ini_options]
   testpaths = ["tests"]
   EOF

   cat > src/app.py <<'EOF'
   def main():
       print("hello from fixture-py")


   if __name__ == "__main__":
       main()
   EOF

   git init -q
   ```

2. Launch Claude Code in the fixture and run the generator:

   ```bash
   claude
   ```

   ```
   /harness-init
   ```

   When asked "Which tier fits this project?", answer **`lite`**.

3. **Assert — managed fences in `CLAUDE.md`:**

   ```bash
   grep -q '<!-- cc-kit:managed:start -->' /tmp/fixture-py/CLAUDE.md \
     && grep -q '<!-- cc-kit:managed:end -->' /tmp/fixture-py/CLAUDE.md \
     && echo "PASS: CLAUDE.md has managed fences" \
     || echo "FAIL: CLAUDE.md missing managed fences"
   ```

4. **Assert — `.claude/cc-kit.json` parses with `"tier": "lite"`:**

   ```bash
   python3 -c "
   import json
   d = json.load(open('/tmp/fixture-py/.claude/cc-kit.json'))
   assert d.get('tier') == 'lite', d
   assert d.get('_ccKitManaged') is True, d
   print('PASS: .claude/cc-kit.json parses, tier=lite')
   "
   ```

5. **Assert — a Python stack rules file exists:**

   ```bash
   ls /tmp/fixture-py/.claude/rules/python*.md \
     && echo "PASS: .claude/rules/python*.md exists" \
     || echo "FAIL: no .claude/rules/python*.md"
   ```

6. **Assert — NO task board on lite tier:**

   ```bash
   test -f /tmp/fixture-py/TASKS.md \
     && echo "FAIL: TASKS.md exists on lite tier" \
     || echo "PASS: no TASKS.md on lite tier"
   ```

Expected overall: 4x `PASS`, 0x `FAIL`.

---

## Scenario 3 — Fixture B: full tier (+ hook-block check)

1. Seed an empty fixture:

   ```bash
   mkdir -p /tmp/fixture-full && cd /tmp/fixture-full && git init -q
   ```

2. Launch Claude Code and run the generator:

   ```bash
   claude
   ```

   ```
   /harness-init
   ```

   When asked "Which tier fits this project?", answer **`full`**.

3. **Assert — board files exist:**

   ```bash
   test -f /tmp/fixture-full/TASKS.md \
     && test -f /tmp/fixture-full/scripts/gen_tasks_json.py \
     && test -f /tmp/fixture-full/tasks/todo.md \
     && test -f /tmp/fixture-full/tasks/lessons.md \
     && echo "PASS: TASKS.md, scripts/gen_tasks_json.py, tasks/todo.md, tasks/lessons.md all exist" \
     || echo "FAIL: one or more full-tier board files missing"
   ```

4. **Assert — `gen_tasks_json.py` runs and produces `tasks.json`:**

   ```bash
   cd /tmp/fixture-full && python3 scripts/gen_tasks_json.py
   ```

   Expected output (counts may vary, but it must not error):
   `[gen_tasks_json] wrote tasks.json: 1 tasks {'NS': 1}`

   ```bash
   test -f /tmp/fixture-full/tasks.json \
     && echo "PASS: tasks.json written" \
     || echo "FAIL: tasks.json not written"
   ```

5. **Assert — `tasks.json` is listed in `generatedFiles`:**

   ```bash
   python3 -c "
   import json
   d = json.load(open('/tmp/fixture-full/.claude/cc-kit.json'))
   assert 'tasks.json' in d.get('generatedFiles', []), d
   print('PASS: tasks.json listed in .claude/cc-kit.json generatedFiles')
   "
   ```

6. **Assert — an Edit attempt on `tasks.json` inside the Claude session is
   blocked by the hook.**

   First, snapshot the file so we can prove it was untouched:

   ```bash
   md5 -q /tmp/fixture-full/tasks.json
   # (Linux: md5sum /tmp/fixture-full/tasks.json)
   ```
   Record this checksum as `BEFORE`.

   In the **same** Claude Code session (still running with cwd
   `/tmp/fixture-full`, cc-kit enabled from Scenario 1), type:

   ```
   Directly edit tasks.json and reformat it to use 4-space indentation.
   ```

   **Expected behavior:** Claude's `Edit`/`Write` tool call on `tasks.json` is
   denied before it runs. The transcript must show a PreToolUse hook block
   whose stderr reason is exactly:

   ```
   cc-kit: tasks.json is generated — edit its source of truth and re-run its generator instead
   ```

   Then re-checksum the file:

   ```bash
   md5 -q /tmp/fixture-full/tasks.json
   # (Linux: md5sum /tmp/fixture-full/tasks.json)
   ```

   ```bash
   [ "$BEFORE" = "$AFTER" ] \
     && echo "PASS: tasks.json unchanged after blocked Edit attempt" \
     || echo "FAIL: tasks.json was modified despite hook"
   ```

   (Set `BEFORE`/`AFTER` shell variables to the two checksums above before
   running this comparison, or diff the two recorded values by eye.)

Expected overall: the reason string above appears verbatim in the transcript,
and the two checksums match.

---

## Scenario 4 — Re-run survival check (Fixture A)

1. Hand-add a custom section to Fixture A's `CLAUDE.md`, below the
   `<!-- cc-kit:managed:end -->` marker:

   ```bash
   cat >> /tmp/fixture-py/CLAUDE.md <<'EOF'

   ## Fixture A custom section (acceptance test)
   This line must survive a /harness-init re-run untouched — do not delete
   when regenerating managed content.
   EOF
   ```

2. In a Claude Code session with cwd `/tmp/fixture-py` (reuse the Scenario 2
   session or start a fresh `claude` there), re-run:

   ```
   /harness-init
   ```

   Answer the tier question again (re-selecting **`lite`** is the expected,
   valid answer — this is the common re-run case, not a tier change).

3. **Assert — the custom section survives verbatim:**

   ```bash
   grep -qF '## Fixture A custom section (acceptance test)' /tmp/fixture-py/CLAUDE.md \
     && grep -qF 'This line must survive a /harness-init re-run untouched — do not delete' /tmp/fixture-py/CLAUDE.md \
     && echo "PASS: custom CLAUDE.md section survived /harness-init re-run" \
     || echo "FAIL: custom CLAUDE.md section lost or altered by re-run"
   ```

4. **Assert — managed fences still present and still parse (sanity that the
   re-run actually regenerated the managed region, not just left the whole
   file alone):**

   ```bash
   grep -q '<!-- cc-kit:managed:start -->' /tmp/fixture-py/CLAUDE.md \
     && grep -q '<!-- cc-kit:managed:end -->' /tmp/fixture-py/CLAUDE.md \
     && echo "PASS: managed fences still present after re-run" \
     || echo "FAIL: managed fences missing after re-run"
   ```

Expected overall: 2x `PASS`, 0x `FAIL`.

---

## Results (paste into the v0.1.0 tagging commit)

When the live run (Task 7 Step 2) is executed, capture the actual `PASS`/`FAIL`
lines and the exact hook-block transcript excerpt from Scenario 3 Step 6 here,
then carry this section into the tagging commit message or PR description:

```
Run: 2026-07-13, claude CLI 2.1.207, macOS. Headless adaptation: /harness-init
driven via `claude -p` sessions (plugin loaded); tier answers pre-authorized in
the prompt (AskUserQuestion unavailable headless); --add-dir granted template
reads and bypassPermissions granted .claude/ writes — both are one-time
interactive approval prompts in a normal session, not kit defects.

Scenario 1 (install):
  First attempt FAILED — plugin.json declared "skills"/"agents"/"hooks" keys;
  plugin schema rejected ("Validation errors: agents: Invalid input").
  Fixed in 7774a5f (dirs are auto-discovered by convention). After fix:
  ✔ Successfully added marketplace: cc-kit
  ✔ Successfully installed plugin: cc-kit@cc-kit (scope: user)
  PASS: cc-kit@cc-kit enabled in ~/.claude/settings.json

Scenario 2 (fixture A, lite): 4/4
  PASS: CLAUDE.md has managed fences
  PASS: .claude/cc-kit.json parses, tier=lite
  PASS: .claude/rules/python*.md exists
  PASS: no TASKS.md on lite tier

Scenario 3 (fixture B, full): all green
  PASS: TASKS.md, scripts/gen_tasks_json.py, tasks/todo.md, tasks/lessons.md all exist
  [gen_tasks_json] wrote tasks.json: 1 tasks {'NS': 1}
  PASS: tasks.json written
  PASS: tasks.json listed in .claude/cc-kit.json generatedFiles
  Live hook block (verbatim transcript):
    PreToolUse:Edit hook error: ["${CLAUDE_PLUGIN_ROOT}/hooks/protect-generated.sh"]:
    cc-kit: tasks.json is generated — edit its source of truth and re-run its generator instead
  BEFORE=f38976d4f28875ddc5ab878a3d8303f2  AFTER=f38976d4f28875ddc5ab878a3d8303f2
  PASS: tasks.json unchanged after blocked Edit attempt

Scenario 4 (re-run survival): 2/2
  PASS: custom CLAUDE.md section survived /harness-init re-run
  PASS: managed fences still present after re-run
```

If any scenario fails, fix the underlying issue per Task 7 Step 3, re-run the
full runbook from Scenario 1, and only paste a run where all four scenarios
are green.
