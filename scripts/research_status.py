#!/usr/bin/env python3
"""Where the auto-research loop has got to, in one screen.

Reads `research/state.json` for what has been decided and asks the server what
is still in flight, so a glance answers both "what did it find" and "is it
still working". Nothing here writes anything.

Usage:
  python scripts/research_status.py
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import experiments as cat  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
STATE = ROOT / "research" / "state.json"
BIN = os.environ.get("COWORLD_BIN", "coworld")


def xreq_progress(xreq: str) -> str:
    try:
        out = subprocess.run([BIN, "xp-request", "get", xreq, "--json"],
                             capture_output=True, text=True, check=True).stdout
        d = json.loads(out)
        return (f"{d.get('status')} "
                f"{d.get('completed_count')}/{d.get('episode_count')}"
                + (f" ({d['failed_count']} failed)" if d.get("failed_count") else ""))
    except Exception as exc:                      # noqa: BLE001
        return f"unreadable ({exc})"


def main() -> None:
    if not STATE.exists():
        sys.exit(f"no {STATE}: the loop has not run yet")
    st = json.loads(STATE.read_text())

    print(f"generation : {st['generation']}")
    print(f"baseline   : {st['baseline']}   (control for every open experiment)")
    print(f"champion   : {st['champion']}")

    done = st.get("done", {})
    print(f"\n=========== DECIDED ({len(done)}) ===========")
    for name, r in done.items():
        gap = r.get("kd_gap") or {}
        detail = (f"K/D {gap['observed']:+.4f} "
                  f"[{gap['ci_lo']:+.4f}, {gap['ci_hi']:+.4f}]" if gap else "")
        print(f"  {r['outcome']:<9} {name:<20} {detail}")
        if r.get("outcome") == "ABANDONED":
            print(f"            {r.get('why', '')[:150]}")

    pending = [q["name"] for q in st.get("queue", [])]
    pending += [e.name for e in cat.SEED
                if e.name not in done and e.name not in pending]
    print(f"\n=========== QUEUED ({len(pending)}) ===========")
    print("  " + (", ".join(pending) if pending else "(nothing left)"))

    # Anything created by the most recent experiment that has not been pooled
    # yet is the one thing state.json cannot tell you about, so ask the server.
    last = next(iter(reversed(list(done.values()))), None)
    if last and last.get("xreqs"):
        print("\n=========== LAST MIRROR ===========")
        for x in last["xreqs"]:
            print(f"  {x}  {xreq_progress(x)}")


if __name__ == "__main__":
    main()
