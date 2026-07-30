#!/usr/bin/env python3
"""Run ONE experiment as a both-directions hosted head-to-head, and wait.

Creates the two mirrored requests back to back so both directions are in
flight at the same moment -- that is rule 1 (only compare builds measured at
the same time) and rule 2 (both directions, so the side advantage cancels)
from HANDOFF.md. Then it blocks until both are finished, so a caller can run
experiments strictly one after another.

Usage:
  python scripts/run_experiment.py <name> <treatment_ref> <control_ref> [eps]

Prints the two request ids on stdout as `XREQ_A=... XREQ_B=...` and exits
non-zero if either request ends in a state other than completed.
"""

import json
import os
import subprocess
import sys
import time

LEAGUE = "league_3243d905-d32d-4ec6-978b-fa94751d4a37"
DIVISION = "div_37361341-2970-4dac-9528-55398bab0d1a"
BIN = os.environ.get("COWORLD_BIN", "coworld")
POLL_SECONDS = 60


def cli(*args: str, attempts: int = 4) -> str:
    last = None
    for i in range(attempts):
        try:
            return subprocess.run([BIN, *args], capture_output=True, text=True,
                                  check=True).stdout
        except subprocess.CalledProcessError as exc:
            last = exc
            time.sleep(2 ** i)
    raise last


def body(red: str, blue: str, arm: str, n: int) -> dict:
    roster = [{"player": {"policy_ref": red}, "slot": s} for s in range(0, 16, 2)]
    roster += [{"player": {"policy_ref": blue}, "slot": s} for s in range(1, 16, 2)]
    return {
        "target": {"league_id": LEAGUE, "division_id": DIVISION},
        "roster": roster,
        "num_episodes": n,
        "notes": f"ctf-h2h | arm={arm} | red={red} | blue={blue} | eps={n}",
    }


def create(red: str, blue: str, arm: str, n: int, path: str) -> str:
    with open(path, "w") as fh:
        json.dump(body(red, blue, arm, n), fh, indent=2)
    out = cli("xp-request", "create", path, "--json")
    d = json.loads(out)
    return d.get("id") or d["experience_request"]["id"]


EP_TERMINAL = {"completed", "failed", "cancelled", "canceled", "error", "skipped"}


def status(xreq: str) -> str:
    """Report a request as finished once its EPISODES are all finished.

    The request-level `status` field is not reliable as a completion signal:
    the spawnintel pair sat at "pending" with `started_at` still null for over
    an hour after all 40 of each one's episodes had reached "completed". A
    driver polling only that field waits forever on work that is already done.
    Trust the episode roll-up, and fall back to the request field only when the
    episode list has not been populated yet.
    """
    d = json.loads(cli("xp-request", "get", xreq, "--json"))
    eps = d.get("episodes") or []
    if eps and all(e.get("status") in EP_TERMINAL for e in eps):
        return "completed" if any(e.get("status") == "completed" for e in eps) \
            else "failed"
    return d.get("status", "?")


def main() -> None:
    name, treat, ctrl = sys.argv[1], sys.argv[2], sys.argv[3]
    n = int(sys.argv[4]) if len(sys.argv) > 4 else 40

    a = create(treat, ctrl, f"{name}TreatRed", n, f"xp-requests/h2h-{name}-a.json")
    b = create(ctrl, treat, f"{name}CtrlRed", n, f"xp-requests/h2h-{name}-b.json")
    print(f"XREQ_A={a}\nXREQ_B={b}", flush=True)

    terminal = {"completed", "failed", "cancelled", "canceled", "error"}
    while True:
        sa, sb = status(a), status(b)
        print(f"  [{time.strftime('%H:%M:%S')}] {name}: A={sa} B={sb}", flush=True)
        if sa in terminal and sb in terminal:
            break
        time.sleep(POLL_SECONDS)

    print(f"DONE {name}: A={sa} B={sb}", flush=True)
    sys.exit(0 if sa == "completed" and sb == "completed" else 1)


if __name__ == "__main__":
    main()
