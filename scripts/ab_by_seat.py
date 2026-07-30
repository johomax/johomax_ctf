#!/usr/bin/env python3
"""Score an A/B arm by SEAT, not by policy name.

The arm requests pin our roster to the even slots and fill the odd slots from
the league's top_n pool. Reading a name was a safe way to tell those apart
only up until our own policy was submitted; from that point the pool can deal
us back to ourselves, those seats answer to our own name, and a name-keyed
reader counts them as ours. That inflates the sample and mixes opponent play
into our own combat totals.

Slot parity is what the request actually fixed, so it stays true no matter who
the pool serves up. An opponent seat holding our own policy is then simply a
strong opponent, which is what it is.

Win and loss need one more guard. A score is reported per policy VERSION, not
per seat, so in a mirror episode -- our version on both sides -- the single
entry for that version cannot say which side it refers to. Those episodes are
counted and excluded rather than guessed at; per-seat combat totals are still
sound there, because those come from the per-seat results payload.
"""

import json
import os
import subprocess
import sys
from collections import Counter

PROJECT = "/home/user/coworld-ctf-player"

# Set COWORLD_BIN when the CLI is not reachable as `uv run coworld` inside
# PROJECT -- e.g. a fresh container holding only this archive, where the
# original player project does not exist at all. Same switch pool_h2h.py uses.
COWORLD_BIN = os.environ.get("COWORLD_BIN")


def _cli(*args) -> str:
    cmd = [COWORLD_BIN, *args] if COWORLD_BIN else ["uv", "run", "coworld", *args]
    kwargs = {} if COWORLD_BIN else {"cwd": PROJECT}
    return subprocess.run(
        cmd, capture_output=True, text=True, check=True, **kwargs,
    ).stdout


def summarize(xreq: str, label: str) -> dict:
    d = json.loads(_cli("xp-request", "episodes", xreq, "--json"))
    rows = d if isinstance(d, list) else d.get("entries", [])

    wins = losses = draws = mirrors = 0
    red_labels, blue_labels = Counter(), Counter()
    ours, theirs = Counter(), Counter()
    our_seats_n = their_seats_n = 0
    opp_names = Counter()

    for r in rows:
        scores, parts = r.get("scores") or [], r.get("participants") or []
        if not scores or not parts:
            continue
        mine = [p for p in parts if p["position"] % 2 == 0]
        opp = [p for p in parts if p["position"] % 2 == 1]
        if not mine or not opp:
            continue
        for p in opp:
            opp_names[p.get("label")] += 1
        # Read who is actually seated where, from the episode itself. Naming
        # an arm at creation time and trusting the name later is how the two
        # sides get swapped: request listings come back newest-first, so the
        # order they arrive in is not the order they were made in.
        for p in mine:
            red_labels[p.get("label")] += 1
        for p in opp:
            blue_labels[p.get("label")] += 1

        our_pvs = {p["policy_version_id"] for p in mine}
        opp_pvs = {p["policy_version_id"] for p in opp}
        by_pv = {s["policy_version_id"]: s["score"] for s in scores}

        # Per-seat combat totals, straight from the per-seat payload.
        try:
            res = json.loads(_cli("episode-results", r["id"]))
        except Exception:
            res = None
        if res:
            n = len(res.get("kills") or [])
            for key in ("kills", "deaths", "captures"):
                vals = res.get(key) or []
                for i in range(len(vals)):
                    if i % 2 == 0:
                        ours[key] += vals[i]
                    else:
                        theirs[key] += vals[i]
            our_seats_n += sum(1 for i in range(n) if i % 2 == 0)
            their_seats_n += sum(1 for i in range(n) if i % 2 == 1)

        if our_pvs & opp_pvs:
            mirrors += 1          # same version both sides: score is ambiguous
            continue
        our_score = next((by_pv[pv] for pv in our_pvs if pv in by_pv), None)
        if our_score is None:
            continue
        if our_score > 0:
            wins += 1
        elif any(v > 0 for pv, v in by_pv.items() if pv not in our_pvs):
            losses += 1
        else:
            draws += 1

    scored = wins + losses + draws

    def per(c, n):
        return {k: round(c[k] / n, 3) for k in ("kills", "deaths", "captures")} if n else {}

    return {
        "arm": label,
        "RED_is": red_labels.most_common(1)[0][0] if red_labels else "?",
        "BLUE_is": blue_labels.most_common(1)[0][0] if blue_labels else "?",
        "note": "wins/ours_per_seat/kd all describe RED_is",
        "xreq": xreq[:18],
        "scored": scored,
        "wins": wins, "losses": losses, "draws": draws,
        "win_rate": round(wins / scored, 3) if scored else None,
        "mirror_episodes_excluded": mirrors,
        "our_seats": our_seats_n,
        "ours_per_seat": per(ours, our_seats_n),
        "opp_per_seat": per(theirs, their_seats_n),
        "kd": round(ours["kills"] / ours["deaths"], 3) if ours["deaths"] else None,
        "opponents": dict(opp_names.most_common(6)),
    }


if __name__ == "__main__":
    for pair in sys.argv[1:]:
        label, _, xreq = pair.partition("=")
        print(json.dumps(summarize(xreq, label), indent=2))
