#!/usr/bin/env python3
"""Re-open decided experiments so the loop measures them again.

For when the RULE changes rather than the result. A verdict reached under a
screen that has since been retuned is not a verdict about the change, it is a
verdict about the old threshold, and leaving it in `done` means the loop never
revisits it.

This edits `research/state.json` in place, so the loop must be stopped first --
it holds its state in memory and would write over this on its next save.

Usage:
  python scripts/requeue.py <name> [<name> ...]
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

STATE = Path(__file__).resolve().parent.parent / "research" / "state.json"


def main() -> None:
    names = sys.argv[1:]
    if not names:
        sys.exit(__doc__)
    st = json.loads(STATE.read_text())
    queued = [q["name"] for q in st.get("queue", [])]
    for name in names:
        was = st["done"].pop(name, None)
        if was is None:
            print(f"  {name}: not in done — nothing to re-open")
            continue
        print(f"  {name}: re-opened (was {was.get('outcome')}: "
              f"{was.get('why', '')[:90]})")
        if name not in queued:
            # The catalogue is consulted for anything not in `done`, so a seed
            # experiment needs no queue entry -- only a derived one would, and
            # derived ones carry their definition in the queue already.
            pass
    STATE.write_text(json.dumps(st, indent=2) + "\n")
    print(f"\ndone now holds {len(st['done'])} verdicts; "
          f"queue holds {[q['name'] for q in st['queue']]}")


if __name__ == "__main__":
    main()
