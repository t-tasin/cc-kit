#!/usr/bin/env bash
# test-hooks.sh — self-test for cc-kit universal hooks. Exit 0 = all pass.
set -uo pipefail
cd "$(dirname "$0")"
PASS=0; FAIL=0

kitted="$(mktemp -d)"; mkdir -p "$kitted/.claude"
printf '{"tier":"full","generatedFiles":["tasks.json","web/openapi.gen.ts"]}' > "$kitted/.claude/cc-kit.json"
printf '# protocol\nread the board first.\n' > "$kitted/.claude/protocol.md"
unkitted="$(mktemp -d)"
trap 'rm -rf "$kitted" "$unkitted"' EXIT

check() { # name script payload project_dir expected_rc
  local name="$1" script="$2" payload="$3" dir="$4" want="$5"
  printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$dir" bash "$script" >/dev/null 2>&1
  local rc=$?
  if [ "$rc" -eq "$want" ]; then echo "PASS: $name"; PASS=$((PASS+1))
  else echo "FAIL: $name (rc=$rc want=$want)"; FAIL=$((FAIL+1)); fi
}

ev() { printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$1"; }

# secrets-guard
check "unkitted repo ignored"        secrets-guard.sh "$(ev "$unkitted/.env")"              "$unkitted" 0
check ".env blocked"                 secrets-guard.sh "$(ev "$kitted/.env")"                "$kitted"   2
check ".env.local blocked"           secrets-guard.sh "$(ev "$kitted/db/.env.local")"       "$kitted"   2
check ".env.example allowed"         secrets-guard.sh "$(ev "$kitted/.env.example")"        "$kitted"   0
check "normal file allowed"          secrets-guard.sh "$(ev "$kitted/src/main.py")"         "$kitted"   0
check "malformed json fails open"    secrets-guard.sh 'not-json'                            "$kitted"   0

# protect-generated
check "unkitted generated ignored"   protect-generated.sh "$(ev "$unkitted/tasks.json")"    "$unkitted" 0
check "generated file blocked"       protect-generated.sh "$(ev "$kitted/tasks.json")"      "$kitted"   2
check "nested generated blocked"     protect-generated.sh "$(ev "$kitted/web/openapi.gen.ts")" "$kitted" 2
check "same basename elsewhere OK"   protect-generated.sh "$(ev "$kitted/fixtures/tasks.json")" "$kitted" 0
check "non-generated allowed"        protect-generated.sh "$(ev "$kitted/src/app.py")"      "$kitted"   0
check "malformed json fails open"    protect-generated.sh '{broken'                          "$kitted"   0

# session-start
out="$(CLAUDE_PROJECT_DIR="$kitted" bash session-start.sh)"
if [ "$?" -eq 0 ] && printf '%s' "$out" | grep -q "read the board"; then
  echo "PASS: session-start injects protocol"; PASS=$((PASS+1))
else echo "FAIL: session-start injects protocol"; FAIL=$((FAIL+1)); fi
out="$(CLAUDE_PROJECT_DIR="$unkitted" bash session-start.sh)"
if [ "$?" -eq 0 ] && [ -z "$out" ]; then
  echo "PASS: session-start silent when unkitted"; PASS=$((PASS+1))
else echo "FAIL: session-start silent when unkitted"; FAIL=$((FAIL+1)); fi

echo "---"; echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
