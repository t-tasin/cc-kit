#!/usr/bin/env bash
# security-nudge.sh — PostToolUse (Edit|Write). Part of cc-kit.
# Nudges (never blocks) when an edit touches a security-sensitive path: any of
# Dockerfile*, docker-compose*, a path under .github/workflows/, a path
# containing auth/secret/token/session/login/crypto/password, or a filename
# ending .env.example. Prints one line to stdout so it lands in Claude's
# context, pointing at the `secure` skill. No-ops when unkitted. Fails OPEN:
# ordinary parse problems stay silent (same as secrets-guard/protect-generated);
# only a python3 process failure warns on stderr. This hook is a nudge, not a
# gate — it must never exit nonzero.
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
  echo "cc-kit: security-nudge degraded (python3 failed) — security-sensitive edit detection inactive" >&2
  exit 0
fi

[[ -z "${file_path:-}" ]] && exit 0

reason="$(python3 -c '
import os, sys

try:
    fp = sys.argv[1]
    base = os.path.basename(fp).lower()
    low = fp.lower()

    reason = ""
    if base.startswith("dockerfile"):
        reason = "Dockerfile"
    elif base.startswith("docker-compose"):
        reason = "docker-compose"
    elif ".github/workflows/" in low:
        reason = ".github/workflows"
    elif base.endswith(".env.example"):
        reason = ".env.example"
    else:
        for kw in ("auth", "secret", "token", "session", "login", "crypto", "password"):
            if kw in low:
                reason = kw
                break
    print(reason)
except Exception:
    print("")
' "$file_path" 2>/dev/null)" || reason=""

[[ -z "${reason:-}" ]] && exit 0

echo "cc-kit: security-sensitive edit ($reason) — run /secure before merging."
exit 0
