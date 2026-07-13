#!/usr/bin/env bash
# session-start.sh — SessionStart. Part of cc-kit.
# Injects the kitted project's short protocol into context; silent otherwise.
set -uo pipefail
proj="${CLAUDE_PROJECT_DIR:-.}"
[[ -f "$proj/.claude/cc-kit.json" && -f "$proj/.claude/protocol.md" ]] || exit 0
head -c 4000 "$proj/.claude/protocol.md"
exit 0
