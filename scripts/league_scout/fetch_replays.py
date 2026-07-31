"""Download replays for a chosen set of players. Public S3, no auth."""
import json
import os
import sys
from concurrent.futures import ThreadPoolExecutor

import urllib.request

CACHE = os.path.expanduser("~/.ctf/scout/replays")
os.makedirs(CACHE, exist_ok=True)

TOP = {"RowDaBoat", "James Boggs", "daveey", "Andre von Houck", "NanosaurusX"}
US = "Jordan"


def players_of(e):
    return {p.get("player_name") for p in (e.get("participants") or [])}


def pick(eps):
    """Episodes among top-5, or top-5 vs us. Both are what we want to learn from."""
    out = []
    for e in eps:
        if e.get("status") != "completed" or not e.get("replay_url"):
            continue
        ps = players_of(e)
        if len(ps) != 2:
            continue
        if ps <= TOP or (ps & TOP and US in ps):
            out.append(e)
    return out


def fetch(e):
    url = e["replay_url"]
    name = url.rsplit("/", 1)[-1]
    path = f"{CACHE}/{name}"
    if os.path.exists(path) and os.path.getsize(path) > 0:
        return path, True
    try:
        urllib.request.urlretrieve(url, path)
        return path, False
    except Exception as ex:  # noqa: BLE001
        print(f"  FAIL {name}: {ex}", file=sys.stderr)
        return None, False


if __name__ == "__main__":
    eps = json.load(open(f"{CACHE}/episodes.json"))
    sel = pick(eps)
    print(f"selected {len(sel)} of {len(eps)} episodes", file=sys.stderr)
    from collections import Counter
    c = Counter(" vs ".join(sorted(players_of(e))) for e in sel)
    for k, v in sorted(c.items(), key=lambda kv: -kv[1]):
        print(f"  {k}: {v}", file=sys.stderr)
    with ThreadPoolExecutor(max_workers=12) as ex:
        res = list(ex.map(fetch, sel))
    ok = [r for r, _ in res if r]
    cached = sum(1 for _, c2 in res if c2)
    print(f"{len(ok)} replays on disk ({cached} already cached)", file=sys.stderr)
    # manifest: replay filename -> episode metadata we need for attribution
    man = {}
    for e, (p, _) in zip(sel, res):
        if not p:
            continue
        man[os.path.basename(p)] = {
            "ereq": e["id"],
            "round": e["_round_number"],
            "coworld_version": e.get("coworld_version"),
            "scores": e.get("scores"),
            "participants": [
                {"position": p2.get("position"), "player_name": p2.get("player_name"),
                 "policy_name": p2.get("policy_name"), "version": p2.get("version"),
                 "policy_version_id": p2.get("policy_version_id")}
                for p2 in (e.get("participants") or [])
            ],
        }
    with open(f"{CACHE}/manifest.json", "w") as f:
        json.dump(man, f)
    print(f"manifest -> {CACHE}/manifest.json", file=sys.stderr)
