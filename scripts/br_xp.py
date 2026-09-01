#!/usr/bin/env python3
"""Hosted battle-royale Experience Requests: create them and pool them.

    scripts/br_xp.py create <candidate_ref> --opps A B C -n N [--group G|--rotate]
                            [--notes TEXT] [--dry-run]
    scripts/br_xp.py pool <xreq_id> [<xreq_id> ...] [--focus <policy substring>]

The league seats four entrant policies per 32-seat episode, each holding one
slot group: policy g holds slots g, g+4, ..., g+28, i.e. colours g, g+4, g+8,
g+12 and both seats of each of those duos. `create` reproduces that shape
with the candidate in group G and the three opponents in the others, targets
the league with `variant_id: battle-royale`, and asks for N episodes.
`--rotate` creates four requests, one per group, so the fixed spawn points
of the map cancel over the block (README rule 2, in colour form).

`pool` re-keys every seat to the policy that held it and reports, per
policy: episodes, seats, wins, mean league score (glory if the seat's team
won, else 0 -- what the leaderboard averages), kills and deaths per seat,
and the share of seats alive at the end. For the focus policy (default: the
first candidate seen) it bootstraps a 95% interval on the mean league score
over EPISODES, since the eight seats of one game are not independent.

Costs 0.5 credits per episode (2026-09-01). Read the episodes back with
`coworld xp-request episodes <xreq>`; replays are linked there.
"""

import argparse
import json
import os
import random
import subprocess
import sys
import urllib.request
from collections import defaultdict

LEAGUE = "league_b8fa9b35-ac22-48cf-a03f-07b397aff1c7"
API = "https://softmax.com/api/observatory/v2"
SEATS = 32
GROUPS = 4


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
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.load(r)


def coworld(*args):
    out = subprocess.run(["uvx", "coworld@latest", *args],
                         capture_output=True, text=True)
    if out.returncode != 0:
        sys.exit(out.stderr[-2000:] or out.stdout[-2000:])
    return out.stdout


def body(candidate, opps, group, n, notes):
    if len(opps) != GROUPS - 1:
        sys.exit(f"need exactly {GROUPS - 1} opponents")
    refs = list(opps)
    refs.insert(group, candidate)
    roster = [{"player": {"policy_ref": refs[s % GROUPS]}, "slot": s}
              for s in range(SEATS)]
    return {"target": {"league_id": LEAGUE, "variant_id": "battle-royale"},
            "roster": roster, "num_episodes": n,
            "notes": f"{notes} [candidate={candidate} group={group}]"}


def create_piped(args):
    groups = list(range(GROUPS)) if args.rotate else [args.group]
    for g in groups:
        b = body(args.candidate, args.opps, g, args.n, args.notes)
        if args.dry_run:
            print(f"group {g}: {json.dumps(b)[:300]} ...")
            continue
        out = subprocess.run(
            ["uvx", "coworld@latest", "xp-request", "create", "-", "--json"],
            input=json.dumps(b), capture_output=True, text=True)
        if out.returncode != 0:
            sys.exit(out.stderr[-1500:])
        d = json.loads(out.stdout)
        cost = (d.get("cost_preview") or {}).get("estimated_cost_credits")
        print(f"group {g}: {d['id']} cost {cost}")


def pool(args):
    tok = token()
    per = defaultdict(lambda: {"eps": set(), "seats": 0, "wins": 0,
                               "score": 0.0, "kills": 0, "deaths": 0,
                               "alive": 0, "dmg": 0, "tk": 0})
    focus_scores = []
    focus = args.focus
    n_eps = 0
    for x in args.xreqs:
        d = json.loads(coworld("xp-request", "episodes", x, "--json"))
        rows = d if isinstance(d, list) else next(
            v for v in d.values() if isinstance(v, list))
        for e in rows:
            if e.get("status") != "completed":
                print(f"skip {e['id']}: {e.get('status')} {e.get('error')}",
                      file=sys.stderr)
                continue
            req = get(f"/episode-requests/{e['id']}", tok)
            res = get(f"/episode-requests/{e['id']}/artifacts/results", tok)
            if "scores" not in res:
                print(f"skip {e['id']}: no results artifact", file=sys.stderr)
                continue
            n_eps += 1
            parts = {p["position"]: p for p in req.get("participants", [])}
            ep_focus = []
            for i, score in enumerate(res["scores"]):
                p = parts.get(i)
                if not p:
                    continue
                key = f"{p['policy_name']}:v{p['version']}"
                if focus is None and i == 0:
                    focus = key
                a = per[key]
                a["eps"].add(e["id"])
                a["seats"] += 1
                a["wins"] += int(bool(res["win"][i]))
                a["score"] += score
                a["kills"] += res["kills"][i]
                a["deaths"] += res["deaths"][i]
                a["alive"] += int(res["deaths"][i] == 0)
                a["dmg"] += res.get("hitDamage", [0] * SEATS)[i]
                a["tk"] += res.get("teamKills", [0] * SEATS)[i]
                if focus and focus in key:
                    ep_focus.append(score)
            if ep_focus:
                focus_scores.append(sum(ep_focus) / len(ep_focus))
    print(f"episodes pooled: {n_eps}")
    print(f"{'policy':40} {'eps':>3} {'seats':>5} {'score':>7} {'win%':>5} "
          f"{'k/seat':>6} {'d/seat':>6} {'alive%':>6} {'dmg':>5} {'tk':>3}")
    rows = sorted(per.items(), key=lambda kv: -kv[1]["score"] / kv[1]["seats"])
    for key, a in rows:
        s = a["seats"]
        print(f"{key[:40]:40} {len(a['eps']):3d} {s:5d} {a['score'] / s:7.1f} "
              f"{100 * a['wins'] / s:5.1f} {a['kills'] / s:6.2f} "
              f"{a['deaths'] / s:6.2f} {100 * a['alive'] / s:6.1f} "
              f"{a['dmg'] / s:5.2f} {a['tk']:3d}")
    if focus_scores:
        rng = random.Random(1)
        means = []
        for _ in range(2000):
            sample = [rng.choice(focus_scores) for _ in focus_scores]
            means.append(sum(sample) / len(sample))
        means.sort()
        lo, hi = means[int(0.025 * len(means))], means[int(0.975 * len(means))]
        print(f"focus {focus}: mean league score per episode "
              f"{sum(focus_scores) / len(focus_scores):.1f} "
              f"[{lo:.1f}, {hi:.1f}] over {len(focus_scores)} episodes")


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("create")
    c.add_argument("candidate")
    c.add_argument("--opps", nargs=3, required=True)
    c.add_argument("-n", type=int, default=4)
    c.add_argument("--group", type=int, default=0)
    c.add_argument("--rotate", action="store_true")
    c.add_argument("--notes", default="br a/b")
    c.add_argument("--dry-run", action="store_true")
    c.set_defaults(fn=create_piped)
    p = sub.add_parser("pool")
    p.add_argument("xreqs", nargs="+")
    p.add_argument("--focus")
    p.set_defaults(fn=pool)
    args = ap.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
