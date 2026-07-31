"""What does a timeout draw actually cost? Reconcile the round's own score
against the episodes it was computed from."""
import json
from collections import defaultdict

import ctfapi
from index_eps import episodes_cached, recent_rounds

LEAGUE = "league_3243d905-d32d-4ec6-978b-fa94751d4a37"


def tally(rid):
    """Per player: wins / losses / timeout draws / wipe draws, from the episodes."""
    t = defaultdict(lambda: {"w": 0, "l": 0, "dT": 0, "dW": 0, "n": 0, "failed": 0})
    for e in episodes_cached(rid):
        names = {p["policy_version_id"]: p["player_name"]
                 for p in (e.get("participants") or [])}
        if e.get("status") != "completed":
            for n in set(names.values()):
                t[n]["failed"] += 1
            continue
        sc = e.get("scores") or []
        if len(sc) != 2 or len(names) != 2:
            continue
        for s in sc:
            n = names.get(s["policy_version_id"])
            if not n:
                continue
            t[n]["n"] += 1
            other = [x for x in sc if x is not s][0]
            if s["score"] > other["score"]:
                t[n]["w"] += 1
            elif s["score"] < other["score"]:
                t[n]["l"] += 1
            elif s["score"] < 0:
                t[n]["dT"] += 1
            else:
                t[n]["dW"] += 1
    return t


if __name__ == "__main__":
    rs = recent_rounds(3)
    for r in rs[:2]:
        rid, rn = r["id"], r["round_number"]
        detail = ctfapi.round_detail(rid) if hasattr(ctfapi, "round_detail") else ctfapi.get(f"/v2/rounds/{rid}")
        res = detail.get("results") or []
        t = tally(rid)
        print(f"\n=== round r{rn} ===")
        hdr = (f"{'player':17} {'rank':>4} {'round score':>12} {'meta.wins':>10} "
               f"{'| my W':>7} {'L':>4} {'dTimeout':>9} {'dWipe':>6} {'n':>4} "
               f"{'| (W-L-dT)/n':>13} {'(W-L)/n':>9} {'W/n':>7}")
        print(hdr); print("-" * len(hdr))
        for row in res:
            n = (row.get("player") or {}).get("name")
            md = row.get("result_metadata") or {}
            c = t.get(n, {})
            N = md.get("episodes_scored") or c.get("n", 0) or 1
            w, l, dT, dW = c.get("w", 0), c.get("l", 0), c.get("dT", 0), c.get("dW", 0)
            print(f"{str(n)[:17]:17} {row.get('rank'):>4} {row.get('score'):>12.4f} "
                  f"{md.get('wins'):>10} {w:>7} {l:>4} {dT:>9} {dW:>6} {c.get('n',0):>4} "
                  f"{(w-l-dT)/N:>13.4f} {(w-l)/N:>9.4f} {w/N:>7.4f}")
        print(f"  scoring_rule={ (res[0].get('result_metadata') or {}).get('scoring_rule') }, "
              f"episodes_scored={ (res[0].get('result_metadata') or {}).get('episodes_scored') }")
