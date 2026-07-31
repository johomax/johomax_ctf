"""Index recent completed CTF rounds -> episodes (cached JSON)."""
import json
import os
import sys

import ctfapi

LEAGUE = "league_3243d905-d32d-4ec6-978b-fa94751d4a37"
CACHE = os.path.expanduser("~/.ctf/scout")
ROUNDS_DIR = f"{CACHE}/rounds"
os.makedirs(ROUNDS_DIR, exist_ok=True)


def recent_rounds(count=6, since=None):
    """Completed rounds, newest first."""
    out, offset = [], 0
    while len(out) < count and offset < 600:
        r = ctfapi.get(f"/v2/rounds?league_id={LEAGUE}&limit=100&offset={offset}")
        batch = r if isinstance(r, list) else (r.get("entries") or r.get("data") or r.get("items") or [])
        if not batch:
            break
        for x in batch:
            if x.get("status") != "completed":
                continue
            if since is not None and (x.get("round_number") or 0) < since:
                return out
            out.append(x)
            if len(out) >= count:
                break
        offset += 100
    return out


def episodes_cached(rid):
    p = f"{ROUNDS_DIR}/{rid}.json"
    if os.path.exists(p):
        with open(p) as f:
            return json.load(f)
    eps = ctfapi.episodes(rid, limit=1000)
    with open(p, "w") as f:
        json.dump(eps, f)
    return eps


if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 6
    rs = recent_rounds(n)
    print(f"{len(rs)} completed rounds: r{rs[-1]['round_number']}..r{rs[0]['round_number']}",
          file=sys.stderr)
    allrows = []
    for r in rs:
        eps = episodes_cached(r["id"])
        print(f"  r{r['round_number']} {r['id']} -> {len(eps)} episodes", file=sys.stderr)
        for e in eps:
            e["_round_number"] = r["round_number"]
        allrows.extend(eps)
    with open(f"{CACHE}/episodes.json", "w") as f:
        json.dump(allrows, f)
    print(f"total {len(allrows)} episodes -> {CACHE}/episodes.json", file=sys.stderr)
    if allrows:
        print(json.dumps(allrows[0], indent=1)[:2000])
