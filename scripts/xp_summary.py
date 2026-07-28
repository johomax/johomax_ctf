#!/usr/bin/env python3
"""Summarize a hosted Experience Request into the numbers an A/B comparison needs.

Usage: python scripts/xp_summary.py <policy_name> xreq_... [xreq_... ...]

Scoring is win-only: +1 to every player on the winning team, -1 to every loser,
-1 to BOTH sides on a time-limit draw, and 0 to both on a mutual wipe. A -1 for us
therefore means "lost or ran out the clock"; the two are told apart by whether any
other policy scored +1 that episode. Draws are never counted as half a win -- the
game punishes a timeout exactly like a loss.

Win rate alone is a blunt instrument here. At a 20% base rate, 20 episodes carry a
standard error near 9 points, so only a swing of roughly 25 points is
distinguishable from opponent-draw luck. The per-seat combat totals are far more
sensitive: each episode contributes 8 seats, so a 20-episode batch is 160 seat
samples of kills, deaths and captures. Read those before concluding a change did
nothing.
"""

import json
import subprocess
import sys
from collections import Counter

PROJECT = "/home/user/coworld-ctf-player"


def _cli(*args) -> str:
    return subprocess.run(
        ["uv", "run", "coworld", *args],
        capture_output=True, text=True, check=True, cwd=PROJECT,
    ).stdout


def summarize(xreq: str, policy_name: str) -> dict:
    d = json.loads(_cli("xp-request", "episodes", xreq, "--json"))
    rows = d if isinstance(d, list) else d.get("entries", [])

    status = Counter(r.get("status") for r in rows)
    wins = losses = draws = 0
    opponents = Counter()
    bad_replays = []
    ours = {"kills": 0, "deaths": 0, "captures": 0}
    theirs = {"kills": 0, "deaths": 0, "captures": 0}
    seats_counted = 0

    for r in rows:
        scores, parts = r.get("scores") or [], r.get("participants") or []
        if not scores or not parts:
            continue

        our_pvs = {p["policy_version_id"] for p in parts
                   if p.get("policy_name") == policy_name}
        if not our_pvs:
            continue
        our_seats = [p["position"] for p in parts
                     if p.get("policy_name") == policy_name]
        for p in parts:
            if p.get("policy_name") != policy_name:
                opponents[p.get("label")] += 1

        by_pv = {s["policy_version_id"]: s["score"] for s in scores}
        our_score = next((by_pv[pv] for pv in our_pvs if pv in by_pv), None)
        if our_score is None:
            continue

        if our_score > 0:
            wins += 1
        elif any(v > 0 for pv, v in by_pv.items() if pv not in our_pvs):
            losses += 1
            bad_replays.append(r.get("replay_url"))
        else:
            draws += 1
            bad_replays.append(r.get("replay_url"))

        # Per-seat combat totals: the sensitive signal. The episode results
        # payload is only reachable per episode request, so fetch it here.
        try:
            res = json.loads(_cli("episode-results", r["id"]))
        except Exception:
            continue
        opp_seats = [i for i in range(len(res.get("team", []))) if i not in our_seats]
        for key in ours:
            vals = res.get(key) or []
            ours[key] += sum(vals[i] for i in our_seats if i < len(vals))
            theirs[key] += sum(vals[i] for i in opp_seats if i < len(vals))
        seats_counted += len(our_seats)

    n = wins + losses + draws
    per_seat = {k: round(v / seats_counted, 3) for k, v in ours.items()} if seats_counted else {}
    per_seat_opp = {k: round(v / seats_counted, 3) for k, v in theirs.items()} if seats_counted else {}

    return {
        "xreq": xreq,
        "policy": policy_name,
        "episode_status": dict(status),
        "scored": n,
        "wins": wins, "losses": losses, "draws": draws,
        "win_rate": round(wins / n, 4) if n else None,
        "our_seat_samples": seats_counted,
        "ours_per_seat": per_seat,
        "opponents_per_seat": per_seat_opp,
        "kill_death_ratio": (round(ours["kills"] / ours["deaths"], 3)
                             if ours["deaths"] else None),
        "opponent_seats": dict(opponents.most_common()),
        "lost_or_drew_replays": [u for u in bad_replays if u][:8],
    }


if __name__ == "__main__":
    name = sys.argv[1]
    for x in sys.argv[2:]:
        print(json.dumps(summarize(x, name), indent=2))
