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
  python scripts/pool_h2h.py <xreq_a> <xreq_b> [...] [--resamples=N]
                             [--treatment=LABEL] [--json]

Note the `=`: the options are parsed as one token each, and a space-separated
`--resamples N` would leave N looking like a third request id.

More than two request ids are accepted and pooled together, which is how a
confirmation run is read: rule 5 says a marginal call at 80 episodes is not
settled, so the follow-up mirror is pooled WITH the first one rather than
read on its own.

`--treatment=LABEL` orients every gap as (treatment - control) instead of
alphabetically. Without it the sign follows `sorted()`, which puts v9 after
v45 and quietly reverses the reading -- the same class of mistake as trusting
the arm name. Any unique suffix of the label works, so `--treatment=:v46` is
enough. `--json` prints the whole verdict as one object for a driver to read;
the human-readable report is unchanged and still goes to stdout without it.

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


def orient(builds: list[str], treatment: str | None) -> tuple[str, str]:
    """Return (x, y) so that gaps read (x - y), positive favouring x.

    Without a named treatment the order is alphabetical, which is arbitrary:
    `sorted()` puts ":v45" before ":v9", so the sign of every gap depends on
    how the version numbers happen to sort. Naming the treatment removes the
    question the same way naming the opponents does.
    """
    if treatment is None:
        return builds[0], builds[1]
    hits = [b for b in builds if b == treatment or b.endswith(treatment)]
    if len(hits) != 1:
        # ValueError, not sys.exit: this runs inside the auto-research driver
        # as well as from a shell, and a SystemExit raised in a library
        # function walks straight past `except Exception` and takes the whole
        # unattended loop down with it.
        raise ValueError(f"--treatment={treatment!r} matched {hits} of "
                         f"{builds}; give a label or a suffix that names "
                         "exactly one build")
    x = hits[0]
    return x, next(b for b in builds if b != x)


def verdict(xreqs: list[str], n_boot: int = 10000,
            treatment: str | None = None) -> dict:
    """Pool every request given into one both-directions verdict.

    The returned object is what `main` prints and what a driver reads: the
    per-build totals, the observed gaps, and a bootstrap interval for each.
    """
    eps, skipped = collect(xreqs)
    if not eps:
        raise RuntimeError("no scored episodes")
    builds = sorted({e["red"] for e in eps} | {e["blue"] for e in eps})
    if len(builds) != 2:
        raise RuntimeError(
            f"expected exactly 2 builds across the mirror, saw: {builds}")
    x, y = orient(builds, treatment)

    obs = pool(eps)
    random.seed(20260728)
    kd_s, wr_s, cap_s = [], [], []
    for _ in range(n_boot):
        p = pool([random.choice(eps) for _ in eps])
        kd_s.append(kd(p, x) - kd(p, y))
        wr_s.append((p["wins"][x] - p["wins"][y]) / p["n"])
        cap_s.append(p["totals"][x]["captures"] - p["totals"][y]["captures"])

    def interval(observed: float, draws: list[float]) -> dict:
        s = sorted(draws)
        lo, hi = s[int(0.025 * len(s))], s[int(0.975 * len(s))]
        return {"observed": observed, "ci_lo": lo, "ci_hi": hi,
                "crosses_zero": lo <= 0 <= hi}

    return {
        "n": obs["n"],
        "xreqs": list(xreqs),
        "resamples": n_boot,
        "skipped": skipped,
        "x": x,
        "y": y,
        "builds": {
            b: {"seats": obs["seats"][b], "wins": obs["wins"][b],
                "kd": kd(obs, b),
                **{k: obs["totals"][b][k] for k in
                   ("kills", "deaths", "captures")}}
            for b in builds
        },
        "red_win_rate": sum(1 for e in eps if e["red_win"]) / len(eps),
        "gaps": {
            "kd": interval(kd(obs, x) - kd(obs, y), kd_s),
            "win_rate": interval((obs["wins"][x] - obs["wins"][y]) / obs["n"],
                                 wr_s),
            "captures": interval(
                obs["totals"][x]["captures"] - obs["totals"][y]["captures"],
                cap_s),
        },
    }


def main() -> None:
    argv = [a for a in sys.argv[1:] if not a.startswith("--")]
    n_boot = 10000
    treatment = None
    as_json = False
    for a in sys.argv[1:]:
        if a.startswith("--resamples"):
            n_boot = int(a.split("=", 1)[1])
        elif a.startswith("--treatment"):
            treatment = a.split("=", 1)[1]
        elif a == "--json":
            as_json = True
    if len(argv) < 2:
        sys.exit(__doc__)

    if as_json:
        try:
            v = verdict(argv, n_boot, treatment)
        except (RuntimeError, ValueError) as exc:
            sys.exit(str(exc))
        print(json.dumps(v, indent=2, default=float))
        return

    eps, skipped = collect(argv)
    if not eps:
        sys.exit("no scored episodes")
    builds = sorted({e["red"] for e in eps} | {e["blue"] for e in eps})
    if len(builds) != 2:
        sys.exit(f"expected exactly 2 builds across the mirror, saw: {builds}")
    try:
        x, y = orient(builds, treatment)
    except ValueError as exc:
        sys.exit(str(exc))

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
        # Not `verdict`: that is the module-level function this same
        # function calls a few lines up, and binding the name here makes it a
        # local for the whole of main() -- so `--json` died with an
        # UnboundLocalError on a line that had not run yet.
        reading = "YES - not separable from noise" if lo <= 0 <= hi else "no"
        print(f"  crosses zero       : {reading}")


if __name__ == "__main__":
    main()
