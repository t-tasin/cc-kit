#!/usr/bin/env python3
"""Generate tasks.json from TASKS.md (single source of truth). Generic cc-kit board."""
import json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LINE = re.compile(
    r"^- \[[ x]\] \*\*(?P<id>T-\d+)\*\* · (?P<status>NS|IP|IMPL|TEST|MERGED) · "
    r"(?P<owner>@[\w—-]+) · (?P<desc>.+)$"
)

def main() -> int:
    tasks, counts = [], {}
    for raw in (ROOT / "TASKS.md").read_text().splitlines():
        m = LINE.match(raw.strip())
        if not m:
            continue
        d = m.groupdict()
        tasks.append(d)
        counts[d["status"]] = counts.get(d["status"], 0) + 1
    (ROOT / "tasks.json").write_text(json.dumps({"tasks": tasks}, indent=1) + "\n")
    print(f"[gen_tasks_json] wrote tasks.json: {len(tasks)} tasks {counts}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
