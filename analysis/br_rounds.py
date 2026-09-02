#!/usr/bin/env python3
"""Collect hosted Paintbot ladder rounds and rank the field on them.

    analysis/br_rounds.py fetch [--since ROUND_NUMBER] [--limit N]
    analysis/br_rounds.py report [--variant SUBSTR] [--since ROUND_NUMBER]

`fetch` walks the league's recent rounds, pulls every episode request of each
completed round (participants + scores) and its results artifact (per-seat
kills/deaths/win/glory), and stores them under research/br_rounds/<round>/.
Already-stored episodes are skipped, so re-running is cheap.

`report` pools the stored episodes per policy version: episodes, wins,
league-score mean (glory if the seat's team won, else 0 -- the number the
leaderboard averages), kills/deaths per seat, and seats alive at the end.
Reads nothing off the network.
"""

import argparse
import json
import os
import subprocess
import sys
import urllib.parse
import urllib.request
from collections import defaultdict

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STORE = os.path.join(REPO, "research", "br_rounds")
LEAGUE = "league_b8fa9b35-ac22-48cf-a03f-07b397aff1c7"
API = "https://softmax.com/api/observatory/v2"
US = "ply_bcb80069-fb0c-4ba5-a45c-06b647870aeb"


def token():
    path = os.path.expanduser("~/.softmax/credentials.yaml")
    for line in open(path):
        if "https://softmax.com/api: usr_" in line:
            return line.split()[-1]
    sys.exit("no softmax token in ~/.softmax/credentials.yaml")


def get(path, tok):
    req = urllib.request.Request(
        API + path,
        headers={"Authorization": "Bearer " + tok, "User-Agent": "curl/8.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def rounds(limit):
    """Newest rounds first, straight from the API (cursor-paginated); the
    CLI's `rounds` model broke against the API's entries/next_cursor shape."""
    tok = token()
    out, cursor = [], None
    while len(out) < limit:
        path = f"/rounds?league_id={LEAGUE}&limit={min(100, limit - len(out))}"
        if cursor:
            path += "&cursor=" + urllib.parse.quote(cursor, safe="")
        d = get(path, tok)
        entries = d.get("entries") if isinstance(d, dict) else d
        if not entries:
            break
        out.extend(entries)
        cursor = d.get("next_cursor") if isinstance(d, dict) else None
        if not cursor:
            break
    return out


def round_episodes(rid):
    d = get(f"/rounds/{rid}/episode-requests", token())
    if isinstance(d, list):
        return d
    return d.get("entries") or next(
        (v for v in d.values() if isinstance(v, list)), [])


def fetch(args):
    tok = token()
    os.makedirs(STORE, exist_ok=True)
    for r in rounds(args.limit):
        num = int(r["round_number"])
        if num < args.since or r["status"] != "completed":
            continue
        rdir = os.path.join(STORE, f"{num}_{r['id']}")
        os.makedirs(rdir, exist_ok=True)
        eps = round_episodes(r["id"])
        got = 0
        for e in eps:
            path = os.path.join(rdir, e["id"] + ".json")
            if os.path.exists(path):
                continue
            if e.get("status") != "completed":
                continue
            req = get(f"/episode-requests/{e['id']}", tok)
            try:
                res = get(f"/episode-requests/{e['id']}/artifacts/results", tok)
            except Exception as exc:  # noqa: BLE001
                res = {"error": str(exc)}
            with open(path + ".tmp", "w") as fh:
                json.dump({"round": num, "round_id": r["id"],
                           "request": req, "results": res}, fh)
            os.replace(path + ".tmp", path)
            got += 1
        print(f"round {num}: {len(eps)} episodes, {got} new", file=sys.stderr)


def load(since, variant):
    for rdir in sorted(os.listdir(STORE)) if os.path.isdir(STORE) else []:
        num = int(rdir.split("_", 1)[0])
        if num < since:
            continue
        for fn in os.listdir(os.path.join(STORE, rdir)):
            if not fn.endswith(".json"):
                continue
            d = json.load(open(os.path.join(STORE, rdir, fn)))
            if variant and variant not in (d["request"].get("variant_name") or ""):
                continue
            yield d


def report(args):
    per = defaultdict(lambda: {"player": "", "eps": set(), "seats": 0,
                               "wins": 0, "score": 0.0, "kills": 0,
                               "deaths": 0, "alive": 0, "dmg": 0})
    n_eps = 0
    ticks = []
    for d in load(args.since, args.variant):
        req, res = d["request"], d["results"]
        if "scores" not in res:
            continue
        n_eps += 1
        if res.get("finalTick") is not None:
            ticks.append(res["finalTick"])
        parts = {p["position"]: p for p in req.get("participants", [])}
        for i, score in enumerate(res["scores"]):
            p = parts.get(i)
            if not p:
                continue
            key = f"{p['policy_name']}:v{p['version']}"
            a = per[key]
            a["player"] = p["player_name"]
            a["eps"].add(req["id"])
            a["seats"] += 1
            a["wins"] += int(bool(res["win"][i]))
            a["score"] += score
            a["kills"] += res["kills"][i]
            a["deaths"] += res["deaths"][i]
            a["alive"] += int(res["deaths"][i] == 0)
            a["dmg"] += res.get("hitDamage", [0] * 64)[i]
    rows = []
    for key, a in per.items():
        s = a["seats"]
        rows.append((a["score"] / s, key, a["player"], len(a["eps"]), s,
                     a["wins"] / s, a["kills"] / s, a["deaths"] / s,
                     a["alive"] / s, a["dmg"] / s))
    rows.sort(reverse=True)
    print(f"episodes {n_eps}; finalTick median "
          f"{sorted(ticks)[len(ticks) // 2] if ticks else 'n/a'}")
    print(f"{'policy':44} {'player':18} {'eps':>3} {'seats':>5} {'score':>7} "
          f"{'win%':>5} {'k/seat':>6} {'d/seat':>6} {'alive%':>6} {'dmg':>5}")
    for sc, key, player, eps, s, w, k, dd, al, dmg in rows:
        flag = " <== us" if player == "Jordan" else ""
        print(f"{key[:44]:44} {player[:18]:18} {eps:3d} {s:5d} {sc:7.1f} "
              f"{100 * w:5.1f} {k:6.2f} {dd:6.2f} {100 * al:6.1f} {dmg:5.2f}{flag}")


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    f = sub.add_parser("fetch")
    f.add_argument("--since", type=int, default=3549)
    f.add_argument("--limit", type=int, default=30)
    f.set_defaults(fn=fetch)
    r = sub.add_parser("report")
    r.add_argument("--since", type=int, default=3549)
    r.add_argument("--variant", default="Battle")
    r.set_defaults(fn=report)
    args = ap.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
