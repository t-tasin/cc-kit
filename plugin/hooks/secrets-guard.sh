#!/usr/bin/env bash
# secrets-guard.sh — PreToolUse (Edit|Write). Part of cc-kit.
# Blocks edits to .env / .env.* (except .env.example) in kitted projects.
# No-ops instantly when the project has no .claude/cc-kit.json.
# Fails OPEN: any parse problem lets the edit proceed. Ordinary empty/malformed
# hook payloads stay silent (python3 catches those itself and exits 0); only a
# python3 process failure (nonzero exit) warns on stderr — distinguished from
# empty output by checking python3's own exit status, not just its stdout.
set -euo pipefail

[[ -f "${CLAUDE_PROJECT_DIR:-.}/.claude/cc-kit.json" ]] || exit 0

input="$(cat 2>/dev/null)" || true

if file_path="$(printf '%s' "${input:-}" | python3 -c '
import json, sys
try:
    print(json.load(sys.stdin).get("tool_input", {}).get("file_path", "") or "")
except Exception:
    print("")
' 2>/dev/null)"; then
  py_rc=0
else
  py_rc=$?
fi

if [[ "$py_rc" -ne 0 ]]; then
  echo "cc-kit: secrets-guard degraded (python3 failed) — .env protection inactive" >&2
  exit 0
fi

[[ -z "${file_path:-}" ]] && exit 0

IFS='/' read -ra parts <<< "$file_path" || true
for part in "${parts[@]}"; do
  if [[ "$part" == ".env" ]] || { [[ "$part" == .env.* ]] && [[ "$part" != ".env.example" ]]; }; then
    echo "cc-kit: secrets file — never edit or commit it; document its shape in .env.example instead" >&2
    exit 2
  fi
done
exit 0
