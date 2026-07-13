#!/usr/bin/env bash
# validate.sh — static gate: manifests parse, frontmatter parses, hooks compile
# + are executable, read-only agents carry no Edit/Write.
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0

for j in .claude-plugin/marketplace.json plugin/.claude-plugin/plugin.json plugin/hooks/hooks.json; do
  if err="$(python3 -c "import json;json.load(open('$j'))" 2>&1)"; then
    echo "OK   $j"
  else
    echo "FAIL $j (missing or invalid JSON):"
    echo "$err" | sed 's/^/       /'
    fail=1
  fi
done

python3 - <<'PY' || fail=1
import glob, sys
try:
    import yaml
except ImportError:
    sys.exit("FAIL: pyyaml required (pip install pyyaml)")

# Review agents must be structurally unable to edit — no Edit/Write in frontmatter
# `tools`. implementer.md is the one agent exempt from this (it's the builder).
READONLY_AGENTS = {
    "plugin/agents/architect.md",
    "plugin/agents/security-reviewer.md",
    "plugin/agents/silent-failure-hunter.md",
    "plugin/agents/pr-test-analyzer.md",
}

bad = 0
files = sorted(glob.glob('plugin/agents/*.md') + glob.glob('plugin/skills/*/SKILL.md'))
if not files:
    print("FAIL no agents/skills found"); bad = 1
for f in files:
    text = open(f).read()
    if not text.startswith('---'):
        print(f"FAIL {f}: no frontmatter"); bad = 1; continue
    try:
        d = yaml.safe_load(text.split('---')[1])
        assert d.get('name') and d.get('description')
        print(f"OK   {f}")
    except Exception as e:
        print(f"FAIL {f}: {e}"); bad = 1; continue

    if f in READONLY_AGENTS:
        tools_raw = d.get('tools')
        if isinstance(tools_raw, str):
            tools = [t.strip() for t in tools_raw.split(',')]
        elif isinstance(tools_raw, list):
            tools = [str(t).strip() for t in tools_raw]
        else:
            tools = []
        if 'Edit' in tools or 'Write' in tools:
            print(f"FAIL {f}: read-only agent must not carry Edit/Write tools (found: {tools_raw!r})")
            bad = 1

sys.exit(bad)
PY

found_hook=0
for s in plugin/hooks/*.sh; do
  [ -e "$s" ] || continue
  found_hook=1
  if bash -n "$s"; then echo "OK   $s (syntax)"; else echo "FAIL $s (syntax)"; fail=1; fi
  if [ -x "$s" ]; then echo "OK   $s (executable)"; else echo "FAIL $s (not executable)"; fail=1; fi
done
if [ "$found_hook" -eq 0 ]; then
  echo "FAIL no plugin/hooks/*.sh files found"
  fail=1
fi

[ "$fail" -eq 0 ] && echo "ALL VALID" || echo "VALIDATION FAILED"
exit "$fail"
