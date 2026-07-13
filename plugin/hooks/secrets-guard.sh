#!/usr/bin/env bash
# secrets-guard.sh — PreToolUse (Edit|Write). Part of cc-kit.
# Blocks edits to .env / .env.* (except .env.example) in kitted projects.
# No-ops instantly when the project has no .claude/cc-kit.json.
# Fails OPEN: any parse problem lets the edit proceed.
set -euo pipefail

[[ -f "${CLAUDE_PROJECT_DIR:-.}/.claude/cc-kit.json" ]] || exit 0

input="$(cat 2>/dev/null)" || true
file_path="$(printf '%s' "${input:-}" | python3 -c '
import json, sys
try:
    print(json.load(sys.stdin).get("tool_input", {}).get("file_path", "") or "")
except Exception:
    print("")
' 2>/dev/null)" || true
[[ -z "${file_path:-}" ]] && exit 0

IFS='/' read -ra parts <<< "$file_path" || true
for part in "${parts[@]}"; do
  if [[ "$part" == ".env" ]] || { [[ "$part" == .env.* ]] && [[ "$part" != ".env.example" ]]; }; then
    echo "cc-kit: secrets file — never edit or commit it; document its shape in .env.example instead" >&2
    exit 2
  fi
done
exit 0
