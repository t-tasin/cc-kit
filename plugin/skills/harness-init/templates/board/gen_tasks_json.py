#!/usr/bin/env python3
"""Generate tasks.json from TASKS.md (single source of truth). Generic cc-kit board.

Fails loudly (exit 1, nothing written) instead of silently dropping bad input:
- a task-shaped line ("- [ ]"/"- [x]" containing "**T-") that fails the full
  line regex is reported, not skipped.
- a non-empty TASKS.md that yields zero parsed tasks is treated as an error,
  not an empty board.
"""
import json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LINE = re.compile(
    r"^- \[[ x]\] \*\*(?P<id>T-\d+)\*\* · (?P<status>NS|IP|IMPL|TEST|MERGED) · "
    r"(?P<owner>@[\w—-]+) · (?P<desc>.+)$"
)

def main() -> int:
    text = (ROOT / "TASKS.md").read_text()
    raw_lines = text.splitlines()

    tasks, counts = [], {}
    unparseable = []
    current = None  # dict of the most recently matched task, for continuation folding

    for raw in raw_lines:
        stripped = raw.strip()

        # An indented, non-empty line immediately following a matched task line
        # is a wrapped continuation of that task's desc — fold it in with a
        # single space, so authors can wrap long verify/desc text across lines.
        if current is not None and stripped and raw[:1].isspace():
            current["desc"] = current["desc"] + " " + stripped
            continue

        current = None
        if not stripped:
            continue

        m = LINE.match(stripped)
        if m:
            d = m.groupdict()
            tasks.append(d)
            counts[d["status"]] = counts.get(d["status"], 0) + 1
            current = d
            continue

        if stripped.startswith("- [") and "**T-" in stripped:
            unparseable.append(stripped)

    if unparseable:
        for line in unparseable:
            print(f"[gen_tasks_json] UNPARSEABLE: {line}", file=sys.stderr)
        return 1

    if text.strip() and not tasks:
        print("[gen_tasks_json] TASKS.md is non-empty but no tasks were parsed from it", file=sys.stderr)
        return 1

    (ROOT / "tasks.json").write_text(json.dumps({"tasks": tasks}, indent=1) + "\n")
    print(f"[gen_tasks_json] wrote tasks.json: {len(tasks)} tasks {counts}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
