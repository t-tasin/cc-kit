#!/usr/bin/env bash
# protect-generated.sh — PreToolUse (Edit|Write). Part of cc-kit.
# Blocks edits to files listed under "generatedFiles" in .claude/cc-kit.json.
# Match rule: exact project-relative path (file_path == <project>/<entry>),
# never bare basename — copies elsewhere in the tree stay editable.
# No-ops when unkitted; fails OPEN on any parse problem.
set -euo pipefail

proj="${CLAUDE_PROJECT_DIR:-.}"
manifest="$proj/.claude/cc-kit.json"
[[ -f "$manifest" ]] || exit 0

input="$(cat 2>/dev/null)" || true
hit="$(printf '%s' "${input:-}" | python3 -c '
import json, sys, os
try:
    fp = json.load(sys.stdin).get("tool_input", {}).get("file_path", "") or ""
    entries = json.load(open(sys.argv[1])).get("generatedFiles", []) or []
    proj = os.path.abspath(sys.argv[2])
    fp = os.path.abspath(fp)
    for e in entries:
        if fp == os.path.abspath(os.path.join(proj, e)):
            print(e)
            break
except Exception:
    pass
' "$manifest" "$proj" 2>/dev/null)" || true

if [[ -n "${hit:-}" ]]; then
  echo "cc-kit: $hit is generated — edit its source of truth and re-run its generator instead" >&2
  exit 2
fi
exit 0
