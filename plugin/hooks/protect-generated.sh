#!/usr/bin/env bash
# protect-generated.sh — PreToolUse (Edit|Write). Part of cc-kit.
# Blocks edits to files listed under "generatedFiles" in .claude/cc-kit.json.
# Match rule: realpath(file_path) == realpath(<project>/<entry>) — exact path,
# never bare basename — copies elsewhere in the tree stay editable. realpath
# (not abspath) on both sides so a symlinked CLAUDE_PROJECT_DIR or a symlinked
# file_path (e.g. macOS /tmp -> /private/tmp) can't be used to bypass the match.
# No-ops when unkitted. Fails OPEN on any parse problem — but if the manifest
# itself is unreadable/malformed or python3 fails, warns on stderr instead of
# staying silently degraded.
set -euo pipefail

proj="${CLAUDE_PROJECT_DIR:-.}"
manifest="$proj/.claude/cc-kit.json"
[[ -f "$manifest" ]] || exit 0

input="$(cat 2>/dev/null)" || true
file_path="$(printf '%s' "${input:-}" | python3 -c '
import json, sys
try:
    print(json.load(sys.stdin).get("tool_input", {}).get("file_path", "") or "")
except Exception:
    print("")
' 2>/dev/null)" || true

# Short-circuit before any path math: abspath("")/realpath("") resolving to CWD
# is a footgun that must never be allowed to match a manifest entry.
[[ -z "${file_path:-}" ]] && exit 0

degraded_msg='cc-kit: protect-generated degraded (manifest unreadable or python3 failed) — generated-file protection inactive'

if result="$(python3 -c '
import json, os, sys

manifest_path, proj_dir, fp = sys.argv[1], sys.argv[2], sys.argv[3]

try:
    data = json.load(open(manifest_path))
except Exception:
    print("DEGRADED")
    sys.exit(0)

entries = data.get("generatedFiles", [])
if not isinstance(entries, list):
    # Wrong shape (e.g. a bare string) — never iterate it char-by-char.
    print("DEGRADED")
    sys.exit(0)

try:
    proj_real = os.path.realpath(proj_dir)
    fp_real = os.path.realpath(fp)
    for e in entries:
        if isinstance(e, str) and fp_real == os.path.realpath(os.path.join(proj_real, e)):
            print("HIT:" + e)
            sys.exit(0)
except Exception:
    print("DEGRADED")
    sys.exit(0)

print("OK")
' "$manifest" "$proj" "$file_path" 2>/dev/null)"; then
  py_rc=0
else
  py_rc=$?
fi

if [[ "$py_rc" -ne 0 ]]; then
  echo "$degraded_msg" >&2
  exit 0
fi

case "$result" in
  HIT:*)
    entry="${result#HIT:}"
    echo "cc-kit: $entry is generated — edit its source of truth and re-run its generator instead" >&2
    exit 2
    ;;
  DEGRADED)
    echo "$degraded_msg" >&2
    exit 0
    ;;
esac

exit 0
