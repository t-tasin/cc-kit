#!/usr/bin/env bash
# validate.sh — static gate: manifests parse, frontmatter parses, hooks compile.
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0

for j in .claude-plugin/marketplace.json plugin/.claude-plugin/plugin.json plugin/hooks/hooks.json; do
  if python3 -c "import json;json.load(open('$j'))" 2>/dev/null; then echo "OK   $j"
  else echo "FAIL $j (missing or invalid JSON)"; fail=1; fi
done

python3 - <<'PY' || fail=1
import glob, sys
try:
    import yaml
except ImportError:
    sys.exit("FAIL: pyyaml required (pip install pyyaml)")
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
        print(f"FAIL {f}: {e}"); bad = 1
sys.exit(bad)
PY

for s in plugin/hooks/*.sh; do
  [ -e "$s" ] || continue
  if bash -n "$s"; then echo "OK   $s"; else echo "FAIL $s"; fail=1; fi
done

[ "$fail" -eq 0 ] && echo "ALL VALID" || echo "VALIDATION FAILED"
exit "$fail"
