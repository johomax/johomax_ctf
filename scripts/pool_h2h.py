#!/usr/bin/env python3
"""Pool BOTH directions of a head-to-head into one verdict per build.

`ab_by_seat.py` answers "how did RED do in this one request". That is the right
unit for reading a single arm, but it cannot settle a head-to-head on its own,
because RED is not a neutral seat. In a measured 79-episode mirror of two
builds, whoever held RED won 70.9% of episodes regardless of which build it
was. Reading either direction alone therefore measures the side, not the
build, and will report a ~20-point build effect that does not exist.

This pools the mirror. Every seat is re-keyed to the build that actually held
it (read from the episode participants, never from the arm name), totals are
summed across both requests so the side advantage cancels, and the remaining
gap is bootstrapped over episodes to say whether it is separable from noise.

Episodes are the resampling unit. The eight seats inside one episode share a
single game and are not independent; treating them as independent is what makes
a per-seat standard error look reassuringly tiny when it is not.

Usage:
  python scripts/pool_h2h.py <xreq_a> <xreq_b> [--resamples=N]

Note the `=`: the option is parsed as one token, and a space-separated
`--resamples N` would leave N looking like a third request id.

Set COWORLD_BIN to the CLI path when it is not on PATH.
"""

import json
import os
import random
import subprocess
import sys
import time
from collections import defaultdict

# How to reach the CLI, in order: $COWORLD_BIN, then `uv run coworld` inside a
# coworld player project if one is checked out here, then plain `coworld` off
# PATH.
COWORLD_BIN = os.environ.get("COWORLD_BIN")
PROJECT = os.environ.get("COWORLD_PROJECT", "/home/user/coworld-ctf-player")
USE_UV = not COWORLD_BIN and os.path.isdir(PROJECT)


def _cli(*args, attempts: int = 4) -> str:
    """Run the CLI, retrying transient failures.

    A per-episode fetch that fails once and is then swallowed costs a whole
    episode from the pool without saying so. That silent sample loss is the
    same class of bug as the object-id sonar dedupe: the number still prints,
    it is just quietly computed on less data than you think. Retry, and let a
    genuine failure surface to the caller.
    """
    if COWORLD_BIN:
        cmd, kwargs = [COWORLD_BIN, *args], {}
    elif USE_UV:
        cmd, kwargs = ["uv", "run", "coworld", *args], {"cwd": PROJECT}
    else:
        cmd, kwargs = ["coworld", *args], {}
    last = None
    for i in range(attempts):
        try:
            return subprocess.run(cmd, capture_output=True, text=True, check=True,
                                  **kwargs).stdout
        except subprocess.CalledProcessError as exc:
            last = exc
            time.sleep(2 ** i)
    raise last


def collect(xreqs: list[str]) -> tuple[list[dict], list[dict]]:
    """Return (scored episodes, skipped episodes) across every request given."""
    eps, skipped = [], []
    for xreq in xreqs:
        d = json.loads(_cli("xp-request", "episodes", xreq, "--json"))
        rows = d if isinstance(d, list) else d.get("entries", [])
        for r in rows:
            scores, parts = r.get("scores") or [], r.get("participants") or []
            if not scores or not parts:
                skipped.append({"xreq": xreq[:18], "id": r.get("id"),
                                "status": r.get("status"), "error": r.get("error")})
                continue
            even = [p for p in parts if p["position"] % 2 == 0]
            odd = [p for p in parts if p["position"] % 2 == 1]
            if not even or not odd:
                skipped.append({"xreq": xreq[:18], "id": r.get("id"),
                                "status": r.get("status"), "error": "one-sided roster"})
                continue

            # Who actually played, read from the episode participants. Never
            # from the arm name -- that is a label chosen at creation time.
            red, blue = even[0].get("label"), odd[0].get("label")
            by_pv = {s["policy_version_id"]: s["score"] for s in scores}
            red_pvs = {p["policy_version_id"] for p in even}
            blue_pvs = {p["policy_version_id"] for p in odd}
            if red_pvs & blue_pvs:
                skipped.append({"xreq": xreq[:18], "id": r.get("id"),
                                "status": "mirror", "error": "same version both sides"})
                continue
            red_score = next((by_pv[pv] for pv in red_pvs if pv in by_pv), None)
            blue_score = next((by_pv[pv] for pv in blue_pvs if pv in by_pv), None)
            if red_score is None:
                skipped.append({"xreq": xreq[:18], "id": r.get("id"),
                                "status": r.get("status"), "error": "no score for red"})
                continue

            try:
                res = json.loads(_cli("episode-results", r["id"]))
            except Exception:
                skipped.append({"xreq": xreq[:18], "id": r.get("id"),
                                "status": r.get("status"), "error": "results unreadable"})
                continue

            ep = {"xreq": xreq[:18], "red": red, "blue": blue,
                  "red_win": red_score > 0,
                  "blue_win": bool(blue_score is not None and blue_score > 0)}
            for key in ("kills", "deaths", "captures"):
                vals = res.get(key) or []
                ep[f"red_{key}"] = sum(v for i, v in enumerate(vals) if i % 2 == 0)
                ep[f"blue_{key}"] = sum(v for i, v in enumerate(vals) if i % 2 == 1)
            n_seats = len(res.get("kills") or [])
            ep["red_seats"] = sum(1 for i in range(n_seats) if i % 2 == 0)
            ep["blue_seats"] = sum(1 for i in range(n_seats) if i % 2 == 1)
            eps.append(ep)
    return eps, skipped


def pool(sample: list[dict]) -> dict:
    tot = defaultdict(lambda: defaultdict(float))
    seats, wins = defaultdict(int), defaultdict(int)
    for e in sample:
        for side in ("red", "blue"):
            build = e[side]
            for key in ("kills", "deaths", "captures"):
                tot[build][key] += e[f"{side}_{key}"]
            seats[build] += e[f"{side}_seats"]
        if e["red_win"]:
            wins[e["red"]] += 1
        elif e["blue_win"]:
            wins[e["blue"]] += 1
    return {"totals": tot, "seats": seats, "wins": wins, "n": len(sample)}


def kd(p: dict, build: str) -> float:
    t = p["totals"][build]
    return t["kills"] / t["deaths"] if t["deaths"] else 0.0


def main() -> None:
    argv = [a for a in sys.argv[1:] if not a.startswith("--")]
    n_boot = 10000
    for a in sys.argv[1:]:
        if a.startswith("--resamples"):
            n_boot = int(a.split("=", 1)[1])
    if len(argv) < 2:
        sys.exit(__doc__)

    eps, skipped = collect(argv)
    if not eps:
        sys.exit("no scored episodes")
    builds = sorted({e["red"] for e in eps} | {e["blue"] for e in eps})
    if len(builds) != 2:
        sys.exit(f"expected exactly 2 builds across the mirror, saw: {builds}")
    x, y = builds

    obs = pool(eps)
    print(f"scored episodes pooled : {obs['n']}")
    print(f"skipped                : {len(skipped)}")
    for s in skipped:
        print(f"  - {s['xreq']} {s['id']} status={s['status']} error={s['error']}")

    print("\n================ POOLED BY BUILD ================")
    for b in builds:
        t, s = obs["totals"][b], obs["seats"][b]
        print(f"\n{b}")
        print(f"  seats    : {s}")
        for key in ("kills", "deaths", "captures"):
            print(f"  {key:<9}: {t[key]:.0f}  ({t[key]/s:.3f}/seat)")
        print(f"  K/D      : {kd(obs, b):.4f}")
        print(f"  wins     : {obs['wins'][b]} / {obs['n']} "
              f"({obs['wins'][b]/obs['n']:.1%})")

    # Side advantage: the reason one direction cannot settle anything.
    print("\n================ SIDE EFFECT ================")
    red_w = sum(1 for e in eps if e["red_win"])
    print(f"  RED wins overall : {red_w}/{len(eps)} ({red_w/len(eps):.1%})")
    for xq in dict.fromkeys(e["xreq"] for e in eps):
        sub = [e for e in eps if e["xreq"] == xq]
        rw = sum(1 for e in sub if e["red_win"])
        print(f"  {xq}: RED={sub[0]['red']} wins {rw}/{len(sub)} ({rw/len(sub):.1%})")

    random.seed(20260728)
    kd_s, wr_s, cap_s = [], [], []
    for _ in range(n_boot):
        p = pool([random.choice(eps) for _ in eps])
        kd_s.append(kd(p, x) - kd(p, y))
        wr_s.append((p["wins"][x] - p["wins"][y]) / p["n"])
        cap_s.append(p["totals"][x]["captures"] - p["totals"][y]["captures"])

    print(f"\n========= BOOTSTRAP ({n_boot} resamples over episodes) =========")
    print(f"gaps are ({x} - {y}); positive favours {x}")
    obs_p = pool(eps)
    for name, o, s, f in (
        ("K/D gap", kd(obs_p, x) - kd(obs_p, y), sorted(kd_s), "+.4f"),
        ("Win-rate gap", (obs_p["wins"][x] - obs_p["wins"][y]) / obs_p["n"],
         sorted(wr_s), "+.3f"),
        ("Capture gap", obs_p["totals"][x]["captures"] - obs_p["totals"][y]["captures"],
         sorted(cap_s), "+.0f"),
    ):
        lo, hi = s[int(0.025 * len(s))], s[int(0.975 * len(s))]
        print(f"\n{name}")
        print(f"  observed           : {o:{f}}")
        print(f"  95% CI (bootstrap) : [{lo:{f}}, {hi:{f}}]")
        verdict = "YES - not separable from noise" if lo <= 0 <= hi else "no"
        print(f"  crosses zero       : {verdict}")


if __name__ == "__main__":
    main()
