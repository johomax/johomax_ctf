#!/usr/bin/env python3
"""Run head-to-heads on the local simulator instead of on the league.

`sim/` links the real engine, the real observation path and two real policy
builds into one binary (see sim/README.md). This is the front door to it: it
resolves each side to a policy tree, builds the binary, runs both directions
of the mirror across cores, and pools the result under the same rules the
hosted analyzer uses.

    scripts/local_sim.py selfcheck
    scripts/local_sim.py h2h <treatment> <control> -n 40
    scripts/local_sim.py run <build> -n 10
    scripts/local_sim.py pool <episodes.jsonl>

A side is a git ref (`HEAD`, `main`, a sha, `HEAD~3`) or a path to a policy
tree. Git refs are materialized read-only into a temp dir, so the working tree
is never disturbed and an uncommitted change is only measured if you point at
`bot/baseline` explicitly.

The seven rules in README.md's "Evaluating a change" hold here too, with one
exception and one addition:

  * Rule 1 (only compare builds that ran at the same time) is the one rule the
    simulator retires. There is no league to drift: the engine is pinned, the
    field is the other build, and a seed reproduces an episode exactly. This is
    the whole reason the local loop is worth having.
  * Rules 2-7 hold unchanged, and rule 2 gets stricter: the simulator runs the
    SAME SEED both ways, so the two directions differ only in which build held
    which side. That is a paired design, and `pool` bootstraps over seed pairs
    rather than over loose episodes to keep the pairing.
"""

import argparse
import datetime
import json
import os
import random
import shutil
import statistics
import subprocess
import sys
import tempfile
from collections import defaultdict
from concurrent.futures import ProcessPoolExecutor

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIM_DIR = os.path.join(REPO, "sim")
BUILD_SH = os.path.join(SIM_DIR, "build.sh")
LEAGUE_CONFIG = os.path.join(SIM_DIR, "league_config.json")
DEFAULT_ENGINE = os.environ.get("CTF_ENGINE_DIR", os.path.join(REPO, ".engine"))
BINARY = os.path.join(REPO, ".sim-build", "simulate")
BOOTSTRAP_HINT = "run sim/bootstrap.sh first"


# --------------------------------------------------------------------------
# resolving a side to a policy tree
# --------------------------------------------------------------------------

def resolve_tree(side, keep):
    """A policy directory for `side`, which is a path or a git ref."""
    candidate = os.path.abspath(side)
    if os.path.isdir(candidate):
        if os.path.isfile(os.path.join(candidate, "decide.nim")):
            return candidate, side
        nested = os.path.join(candidate, "baseline")
        if os.path.isfile(os.path.join(nested, "decide.nim")):
            return nested, side
        sys.exit(f"{side} is a directory but not a policy tree (no decide.nim)")

    try:
        sha = subprocess.run(
            ["git", "-C", REPO, "rev-parse", "--short", side],
            capture_output=True, text=True, check=True).stdout.strip()
    except subprocess.CalledProcessError:
        sys.exit(f"{side} is neither a directory nor a git ref")

    out = os.path.join(keep, sha + "-" + str(abs(hash(side)) % 10000))
    os.makedirs(out, exist_ok=True)
    # `git archive` reads the ref, never the index or the working tree, so a
    # dirty checkout cannot leak into a measurement of a committed ref.
    archive = subprocess.run(
        ["git", "-C", REPO, "archive", side, "bot/baseline"],
        capture_output=True, check=True).stdout
    tar = os.path.join(out, "tree.tar")
    with open(tar, "wb") as fh:
        fh.write(archive)
    subprocess.run(["tar", "-xf", tar, "-C", out], check=True)
    os.remove(tar)
    tree = os.path.join(out, "bot", "baseline")
    if not os.path.isfile(os.path.join(tree, "decide.nim")):
        sys.exit(f"ref {side} has no bot/baseline/decide.nim")
    return tree, f"{side}@{sha}"


def build(tree_a, tree_b, out=BINARY):
    if not os.path.isdir(os.path.join(DEFAULT_ENGINE, "src", "ctf")):
        sys.exit(f"no engine at {DEFAULT_ENGINE} -- {BOOTSTRAP_HINT}")
    subprocess.run([BUILD_SH, tree_a, tree_b, out], check=True)
    return out


# --------------------------------------------------------------------------
# running episodes
# --------------------------------------------------------------------------

def _one(job):
    binary, engine, config, seed, assign, tick_cap = job
    proc = subprocess.run(
        [binary, "--engine", engine, "--config", config,
         "--seeds", str(seed), "--assign", assign,
         "--tick-cap", str(tick_cap), "--quiet"],
        capture_output=True, text=True)
    if proc.returncode != 0:
        return {"seed": seed, "assign": assign, "error": proc.stderr.strip()[-400:]}
    line = proc.stdout.strip().splitlines()
    if not line:
        return {"seed": seed, "assign": assign, "error": "no output"}
    return json.loads(line[-1])


def run_many(jobs, workers, label):
    """Run episodes across processes, streaming progress to stderr."""
    done, records = 0, []
    with ProcessPoolExecutor(max_workers=workers) as pool:
        for record in pool.map(_one, jobs):
            done += 1
            records.append(record)
            note = record.get("error")
            print(f"\r{label}: {done}/{len(jobs)}"
                  + (f"  FAILED seed {record['seed']}: {note}" if note else ""),
                  end="", file=sys.stderr, flush=True)
    print("", file=sys.stderr)
    return records


def slug(name):
    return "".join(c if c.isalnum() or c in "-_" else "-" for c in name)


def default_out(stem):
    """A path under episodes/, which .gitignore already keeps out of the repo."""
    directory = os.path.join(REPO, "episodes")
    os.makedirs(directory, exist_ok=True)
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    return os.path.join(directory, f"{stem}-{stamp}.jsonl")


def write_records(path, records):
    with open(path, "w") as fh:
        for record in records:
            fh.write(json.dumps(record) + "\n")
    return path


def mirrored_assign(n_slots=16):
    """The two directions: A on red seats then B on red seats.

    Seats alternate red/blue by parity, which is the engine's own team
    assignment and the same parity `bot/baseline.nim` derives its team from.
    """
    ab = "".join("a" if i % 2 == 0 else "b" for i in range(n_slots))
    ba = "".join("b" if i % 2 == 0 else "a" for i in range(n_slots))
    return ab, ba


# --------------------------------------------------------------------------
# pooling
# --------------------------------------------------------------------------

def episode_totals(record):
    """Per-build totals for one episode, keyed by the build that held the seat.

    Read off the seats, never off the direction: the record carries the build
    on every seat, so the arm's name cannot enter the verdict (README rule 3).
    """
    per = defaultdict(lambda: defaultdict(float))
    for seat in record["seats"]:
        b = seat["build"]
        per[b]["kills"] += seat["kills"]
        per[b]["deaths"] += seat["deaths"]
        per[b]["captures"] += seat["captures"]
        per[b]["shotsFired"] += seat["shotsFired"]
        per[b]["shotsHit"] += seat["shotsHit"]
    winner = None
    if not record.get("draw", False):
        for seat in record["seats"]:
            if seat["team"] == record.get("winner"):
                winner = seat["build"]
                break
    return per, winner


def pool_records(records):
    ok = [r for r in records if "error" not in r]
    skipped = [r for r in records if "error" in r]
    pairs = defaultdict(list)
    for record in ok:
        pairs[record["seed"]].append(record)
    return ok, skipped, pairs


def kd(totals, build):
    d = totals[build]["deaths"]
    return totals[build]["kills"] / d if d else 0.0


def sum_totals(episodes):
    tot = defaultdict(lambda: defaultdict(float))
    wins = defaultdict(int)
    for per, winner in episodes:
        for b, v in per.items():
            for k, n in v.items():
                tot[b][k] += n
        if winner:
            wins[winner] += 1
    return tot, wins


def report(records, name_a, name_b, seed_paired=True):
    ok, skipped, pairs = pool_records(records)
    if not ok:
        sys.exit("no episodes completed")

    # Every skipped episode is printed, never silently dropped (README rule 7).
    for record in skipped:
        print(f"  SKIPPED seed {record['seed']} "
              f"({record.get('assign','?')}): {record['error']}")
    if skipped:
        print()

    episodes = [episode_totals(r) for r in ok]
    tot, wins = sum_totals(episodes)
    n = len(episodes)

    endings = defaultdict(int)
    for record in ok:
        endings[record["ending"]] += 1
    ticks = [r["ticks"] for r in ok]

    print(f"episodes pooled : {n}   ({name_a} = a, {name_b} = b)")
    print("endings         : " + "  ".join(
        f"{k} {v}" for k, v in sorted(endings.items())))
    print(f"median length   : {int(statistics.median(ticks))} ticks\n")

    for build, label in (("a", name_a), ("b", name_b)):
        acc = 0.0
        if tot[build]["shotsFired"]:
            acc = tot[build]["shotsHit"] / tot[build]["shotsFired"]
        print(f"{label}  [{build}]")
        print(f"  kills    : {tot[build]['kills']:.0f}")
        print(f"  deaths   : {tot[build]['deaths']:.0f}")
        print(f"  captures : {tot[build]['captures']:.0f}")
        print(f"  K/D      : {kd(tot, build):.4f}")
        print(f"  accuracy : {acc:.3f}")
        print(f"  wins     : {wins[build]} / {n}")

    # Bootstrap over SEED PAIRS when the run is paired, so a resample keeps
    # both directions of a seed together -- the two directions of one seed
    # share a map draw and a spawn layout and are not independent. Falls back
    # to episodes when the run is not paired.
    units = list(pairs.values()) if seed_paired else [[r] for r in ok]
    unit_eps = [[episode_totals(r) for r in unit] for unit in units]

    def gap(sample):
        flat = [ep for unit in sample for ep in unit]
        t, _ = sum_totals(flat)
        return kd(t, "a") - kd(t, "b")

    observed = kd(tot, "a") - kd(tot, "b")
    rng = random.Random(20260730)
    draws = sorted(gap([rng.choice(unit_eps) for _ in unit_eps])
                   for _ in range(10000))
    lo, hi = draws[int(0.025 * len(draws))], draws[int(0.975 * len(draws))]

    print(f"\nK/D gap ({name_a} - {name_b}), bootstrapped over "
          f"{'seed pairs' if seed_paired else 'episodes'} (n={len(units)})")
    print(f"  observed           : {observed:+.4f}")
    print(f"  95% CI             : [{lo:+.4f}, {hi:+.4f}]")
    crosses = lo <= 0 <= hi
    print(f"  crosses zero       : {'YES' if crosses else 'no'}")
    if crosses:
        print("\n  No result. A CI that crosses zero is not a small effect,")
        print("  it is an absent one (README rule 6). Buy more episodes or")
        print("  call it level.")
    elif min(abs(lo), abs(hi)) < 0.25 * abs(observed):
        print("\n  Marginal: the interval nearly touches zero. README rule 5 --")
        print("  intervals like this have come back level at twice the n.")


# --------------------------------------------------------------------------
# commands
# --------------------------------------------------------------------------

def cmd_h2h(args):
    with tempfile.TemporaryDirectory(prefix="ctf-sim-trees-") as keep:
        tree_a, name_a = resolve_tree(args.treatment, keep)
        tree_b, name_b = resolve_tree(args.control, keep)
        binary = build(tree_a, tree_b)

        ab, ba = mirrored_assign()
        seeds = [args.first_seed + i for i in range(args.episodes)]
        # Same seed both directions: identical terrain and spawn draws, so the
        # only difference between the pair is which build held which side.
        jobs = [(binary, args.engine, args.config, s, a, args.tick_cap)
                for s in seeds for a in (ab, ba)]
        records = run_many(jobs, args.workers,
                           f"{name_a} vs {name_b}")

    # Always keep the records. A head-to-head is an hour of CPU and `pool` can
    # re-read it for free; losing that to a forgotten flag is a bad trade.
    # `episodes/` is gitignored -- a run is a record, not source.
    out = args.out or default_out(f"h2h-{slug(name_a)}-vs-{slug(name_b)}")
    write_records(out, records)
    print()
    report(records, name_a, name_b, seed_paired=True)
    print(f"\nrecords: {os.path.relpath(out, REPO)}")
    print(f"re-pool with: scripts/local_sim.py pool {os.path.relpath(out, REPO)}"
          f" --name-a '{name_a}' --name-b '{name_b}'")


def cmd_run(args):
    with tempfile.TemporaryDirectory(prefix="ctf-sim-trees-") as keep:
        tree, name = resolve_tree(args.build, keep)
        binary = build(tree, tree)
        seeds = [args.first_seed + i for i in range(args.episodes)]
        jobs = [(binary, args.engine, args.config, s, "a" * 16, args.tick_cap)
                for s in seeds]
        records = run_many(jobs, args.workers, name)

    out = args.out or default_out(f"run-{slug(name)}")
    write_records(out, records)
    ok = [r for r in records if "error" not in r]
    endings = defaultdict(int)
    red = 0
    for record in ok:
        endings[record["ending"]] += 1
        if record.get("winner") == "red":
            red += 1
    print(f"\n{name}: {len(ok)}/{len(records)} episodes")
    print("endings : " + "  ".join(f"{k} {v}" for k, v in sorted(endings.items())))
    print(f"red won : {red}/{len(ok)}"
          + ("" if not ok else f"  ({100.0 * red / len(ok):.1f}%)"))
    print("\nAll sixteen seats are the same build, so this measures the GAME,")
    print("not the build: the red bias here is the number a head-to-head has")
    print("to cancel, and it is why one direction can never settle a change.")


def cmd_pool(args):
    records = [json.loads(line) for line in open(args.episodes) if line.strip()]
    report(records, args.name_a, args.name_b, seed_paired=not args.unpaired)


def cmd_selfcheck(args):
    """Prove the simulator is wired up and deterministic before trusting it."""
    print("== building (same tree on both sides)")
    tree = os.path.join(REPO, "bot", "baseline")
    binary = build(tree, tree)

    ab, ba = mirrored_assign()
    a, b, x, y = run_many([
        (binary, args.engine, args.config, 4242, "a" * 16, args.tick_cap),
        (binary, args.engine, args.config, 4242, "a" * 16, args.tick_cap),
        (binary, args.engine, args.config, 99, ab, args.tick_cap),
        (binary, args.engine, args.config, 99, ba, args.tick_cap),
    ], args.workers, "selfcheck")
    for record in (a, b, x, y):
        if "error" in record:
            sys.exit(f"episode failed: {record['error']}")

    print("\n== determinism: one seed, run twice, must match on gameHash")
    same = a["gameHash"] == b["gameHash"] and a["ticks"] == b["ticks"]
    print(f"   run 1: hash {a['gameHash']} ticks {a['ticks']} {a['ending']}")
    print(f"   run 2: hash {b['gameHash']} ticks {b['ticks']} {b['ending']}")
    print(f"   -> {'MATCH' if same else 'DIVERGED'}")
    if not same:
        sys.exit("the simulator is not deterministic; do not trust its numbers")

    print("\n== seat independence: build 'a' and build 'b' are the same source,")
    print("   so a mirrored pair must be a pure side swap")
    xa = sum(s["kills"] for s in x["seats"] if s["build"] == "a")
    yb = sum(s["kills"] for s in y["seats"] if s["build"] == "b")
    print(f"   seed 99 direction 1: hash {x['gameHash']} a-kills {xa}")
    print(f"   seed 99 direction 2: hash {y['gameHash']} b-kills {yb}")
    identical = x["gameHash"] == y["gameHash"]
    print(f"   -> {'identical episode' if identical else 'different episode'}"
          " (both are fine; identical means the two trees are byte-equal and")
    print("      the swap is exact, which is the strongest null you can get)")

    print("\n== a real episode finished, engine-side")
    print(f"   {a['ending']} / winner {a['winner']} / {a['ticks']} ticks")

    check_trees_are_separate(args)

    print("\nselfcheck passed.")


def check_trees_are_separate(args):
    """Prove side 'b' is really a second policy, not an alias for side 'a'.

    This guards the one failure that would be invisible forever. The whole
    head-to-head rests on Nim resolving imports relative to the importing
    file, so that two copies of the policy tree are two module sets with two
    sets of module-level state. If that ever stopped holding -- one shared
    `tuning`, one shared set of adopted map dimensions -- both sides would run
    identical code, every A/B would report a flat zero, and nothing would look
    wrong: no error, no warning, just a tool that can never find a difference.
    So: perturb a constant in side b and require the episode to change.
    """
    print("\n== tree separation: perturb side b and require it to diverge")
    with tempfile.TemporaryDirectory(prefix="ctf-sim-perturb-") as work:
        tree_b = os.path.join(work, "baseline")
        shutil.copytree(os.path.join(REPO, "bot", "baseline"), tree_b)

        tuning = os.path.join(tree_b, "tuning.nim")
        before = open(tuning).read()
        after = before.replace("AimRate* = 5", "AimRate* = 3", 1)
        if after == before:
            sys.exit("could not perturb AimRate in tuning.nim -- this check "
                     "silently stopped testing anything; fix it before "
                     "trusting a head-to-head")
        open(tuning, "w").write(after)

        binary = build(os.path.join(REPO, "bot", "baseline"), tree_b,
                       os.path.join(work, "simulate"))
        # A different turret rate diverges within a few ticks, so this needs
        # nowhere near a full episode.
        pure_a, pure_b = run_many([
            (binary, args.engine, args.config, 313, "a" * 16, 400),
            (binary, args.engine, args.config, 313, "b" * 16, 400),
        ], 2, "separation")

    for record in (pure_a, pure_b):
        if "error" in record:
            sys.exit(f"episode failed: {record['error']}")
    print(f"   all-a (AimRate 5): hash {pure_a['gameHash']}")
    print(f"   all-b (AimRate 3): hash {pure_b['gameHash']}")
    if pure_a["gameHash"] == pure_b["gameHash"]:
        sys.exit("   -> IDENTICAL. The two trees are sharing state: side b is "
                 "running side a's code.\n      Every head-to-head this "
                 "simulator reports would be a flat zero. Do not use it.")
    print("   -> diverged, as it must")


def main():
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    def common(p, with_episodes=True):
        p.add_argument("--engine", default=DEFAULT_ENGINE,
                       help="coworld-ctf checkout (default: .engine)")
        p.add_argument("--config", default=LEAGUE_CONFIG,
                       help="game config JSON (default: sim/league_config.json,"
                            " the hosted variant's own game_config)")
        p.add_argument("--tick-cap", type=int, default=20000)
        p.add_argument("--workers", type=int,
                       default=max(1, (os.cpu_count() or 2) - 1))
        p.add_argument("--first-seed", type=int, default=1000)
        p.add_argument("--out", help="write episode records as JSONL")
        if with_episodes:
            p.add_argument("-n", "--episodes", type=int, default=20,
                           help="seeds; a h2h runs each one BOTH ways")

    p = sub.add_parser("h2h", help="two builds, both directions, same seeds")
    p.add_argument("treatment")
    p.add_argument("control")
    common(p)
    p.set_defaults(func=cmd_h2h)

    p = sub.add_parser("run", help="one build in all sixteen seats")
    p.add_argument("build")
    common(p)
    p.set_defaults(func=cmd_run)

    p = sub.add_parser("pool", help="re-pool a saved JSONL run")
    p.add_argument("episodes")
    p.add_argument("--name-a", default="a")
    p.add_argument("--name-b", default="b")
    p.add_argument("--unpaired", action="store_true",
                   help="bootstrap over episodes instead of seed pairs")
    p.set_defaults(func=cmd_pool)

    p = sub.add_parser("selfcheck", help="prove the wiring and determinism")
    common(p, with_episodes=False)
    p.set_defaults(func=cmd_selfcheck)

    args = parser.parse_args()
    if not os.path.isfile(BUILD_SH):
        sys.exit(f"missing {BUILD_SH}")
    if not shutil.which("git"):
        sys.exit("git is required to resolve a ref to a policy tree")
    args.func(args)


if __name__ == "__main__":
    main()
