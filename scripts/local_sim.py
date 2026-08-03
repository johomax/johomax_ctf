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
    scripts/local_sim.py paint <treatment> <control> -n 20   # Paintbot

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

`paint` is the same discipline on a Paintbot board (analysis/paintbot.md),
where "which side" becomes "which of four colours" and one mirror is not
enough to cancel it. See `rotation_assigns`.
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
PAINT_CONFIG = os.path.join(SIM_DIR, "paintbot_4ffa.json")
DEFAULT_ENGINE = os.environ.get("CTF_ENGINE_DIR", os.path.join(REPO, ".engine"))
# SIM_BINARY/SIM_WORK move a whole run off the default paths. `build.sh`
# refuses to rebuild over a binary that episodes are still executing, which is
# correct and is also the only thing stopping two experiments on one box from
# swapping binaries out from under each other -- so a second run wants its own
# pair of paths, not a queue behind the first.
BINARY = os.environ.get("SIM_BINARY", os.path.join(REPO, ".sim-build", "simulate"))
WORK = os.environ.get("SIM_WORK")   # None: build.sh's own default
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


def build(tree_a, tree_b, out=BINARY, work=WORK, tree_c=None, tree_d=None):
    """Compile one simulator binary. `work` isolates a build from the default
    tree, which matters because build.sh lays the policy trees out there and
    keeps its nimcache there between builds.

    `tree_c`/`tree_d` are the third and fourth policy trees a four-entrant
    Paintbot episode can seat; leaving them out is what keeps the CTF
    head-to-head compiling exactly the two trees it always did."""
    if not os.path.isdir(os.path.join(DEFAULT_ENGINE, "src", "ctf")):
        sys.exit(f"no engine at {DEFAULT_ENGINE} -- {BOOTSTRAP_HINT}")
    command = [BUILD_SH]
    for flag, tree in (("--tree-c", tree_c), ("--tree-d", tree_d)):
        if tree:
            command += [flag, tree]
    command += [tree_a, tree_b, out]
    if work:
        command.append(work)
    subprocess.run(command, check=True)
    return out


# --------------------------------------------------------------------------
# running episodes
# --------------------------------------------------------------------------

#: The largest number of episodes handed to one simulator process.
#:
#: Starting a process costs an engine setup -- the map bake, the art load, and
#: each seat's nav-grid build -- a fixed ~0.6 s against an episode's couple of
#: seconds of ticks. The simulator caches all of it across the episodes of one
#: process (the bake keyed on the resolved map, the nav grid and post scans on
#: the walkability mask), so the second seed in a batch starts in ~0.05 s.
#:
#: The cap exists because the other half of the trade is the tail: episodes
#: range from ~1800 to ~4700 ticks, so a fat batch drawn late strands a core
#: for its whole length. Measured on four cores, 40 episodes: one per process
#: 37.7 s, fixed batches of two 32.8 s, guided (below) 31.2 s. Batches of
#: eight came in at 35.5 s -- worse than batches of two, all of it tail.
BATCH_MAX = 6


def _batch(job):
    """Run one batch of seeds in ONE process, and return a record per seed.

    Records are matched back BY SEED rather than by position: a batch that
    dies partway still yields the episodes that finished, so a crash costs the
    episode it happened in and not the ones already on stdout. The seeds after
    it come back as errors, which `run_many` re-runs one to a process -- so a
    crash is still reported per episode, exactly as it was when every episode
    had its own process (README rule 7: sample loss stays visible).
    """
    binary, engine, config, seeds, assign, tick_cap = job
    proc = subprocess.run(
        [binary, "--engine", engine, "--config", config,
         "--seeds", ",".join(str(s) for s in seeds), "--assign", assign,
         "--tick-cap", str(tick_cap), "--quiet"],
        capture_output=True, text=True)
    done = {}
    for line in proc.stdout.splitlines():
        try:
            record = json.loads(line)          # blank lines land here too
        except json.JSONDecodeError:
            continue
        if "seed" in record:
            done[record["seed"]] = record
    note = proc.stderr.strip()[-400:] or "no output"
    return [done.get(s, {"seed": s, "assign": assign, "error": note})
            for s in seeds]


def _batched(jobs, workers):
    """Group per-episode jobs into per-process batches, keeping their indices.

    Everything but the seed has to match for two episodes to share a process,
    so the grouping is by (binary, engine, config, assign, tick_cap) -- which
    in a head-to-head means the two directions batch separately, as they must.

    Batches SHRINK as the queue drains (guided self-scheduling): each one
    takes a workers'-worth slice of what is left, so the run starts with fat
    batches that amortize setup and finishes with singletons that let the
    workers land together. Sorting the batches large-first makes that hold
    across the direction groups too, since the pool dispatches in order.
    """
    groups = defaultdict(list)
    for index, (binary, engine, config, seed, assign, tick_cap) in enumerate(jobs):
        groups[(binary, engine, config, assign, tick_cap)].append((index, seed))
    batches = []
    for (binary, engine, config, assign, tick_cap), items in groups.items():
        at = 0
        while at < len(items):
            # ceil(left / workers), so the slice is a workers'-worth of what
            # is left: >= 1 by the loop condition, and BATCH_MAX caps it.
            size = min(BATCH_MAX, -(-(len(items) - at) // workers))
            part = items[at:at + size]
            at += size
            batches.append((
                (binary, engine, config, [s for _, s in part], assign, tick_cap),
                [i for i, _ in part]))
    batches.sort(key=lambda b: -len(b[1]))
    return batches


def run_many(jobs, workers, label):
    """Run episodes across processes, streaming progress to stderr."""
    batches = _batched(jobs, workers)
    records = [None] * len(jobs)
    done = 0
    with ProcessPoolExecutor(max_workers=workers) as pool:
        for indices, produced in zip(
                [b[1] for b in batches],
                pool.map(_batch, [b[0] for b in batches])):
            for index, record in zip(indices, produced):
                records[index] = record
                done += 1
                note = record.get("error")
                print(f"\r{label}: {done}/{len(jobs)}"
                      + (f"  FAILED seed {record['seed']}: {note}" if note else ""),
                      end="", file=sys.stderr, flush=True)

    # An episode that failed inside a batch gets one lone-process retry: the
    # batch may have died on an earlier seed and never reached it at all.
    retry = [i for i, r in enumerate(records) if "error" in r]
    if retry:
        print(f"\n{label}: retrying {len(retry)} failed episode(s), "
              "one to a process", file=sys.stderr, flush=True)
        solo = [(binary, engine, config, [seed], assign, tick_cap)
                for binary, engine, config, seed, assign, tick_cap
                in (jobs[i] for i in retry)]
        with ProcessPoolExecutor(max_workers=workers) as pool:
            for index, produced in zip(retry, pool.map(_batch, solo)):
                if "error" not in produced[0]:
                    records[index] = produced[0]
    print("", file=sys.stderr)
    return records


def require_ok(*records):
    """Exit on any episode that did not produce a record. A selfcheck step
    that quietly compared two failures would report a match."""
    for record in records:
        if "error" in record:
            sys.exit(f"episode failed: {record['error']}")


def slug(name):
    return "".join(c if c.isalnum() or c in "-_" else "-" for c in name)


def default_out(stem):
    """A path under episodes/, which .gitignore already keeps out of the repo."""
    directory = os.path.join(REPO, "episodes")
    os.makedirs(directory, exist_ok=True)
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    return os.path.join(directory, f"{stem}-{stamp}.jsonl")


def show_path(path):
    """Repo-relative when it is inside the repo, absolute when it is not.

    A bare relpath turns an --out under /tmp into ../../../tmp/..., which is
    both ugly and wrong to paste back if you are not standing in the repo.
    """
    inside = os.path.commonpath([os.path.abspath(path), REPO]) == REPO
    return os.path.relpath(path, REPO) if inside else os.path.abspath(path)


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
# Paintbot: four entrants, up to four colours
# --------------------------------------------------------------------------

#: How many entrant policies a Paintbot episode seats, and therefore the length
#: of the rotation. The hosted variants all deal seats round-robin, so the
#: entrant holding slot s is `s % ENTRANTS`: on 4ffa/4ffa8 that coincides with
#: the colour (`slot mod 4`), and on 2v2 it splits each colour between two
#: entrants, which is what makes that shape "two policies per team".
ENTRANTS = 4


def roster_size(config_path):
    """How many seats the config declares, which is how long an --assign is.

    Only the count is read here. Every seat's COLOUR comes back off the record
    instead, because the engine is the one that assigns it -- reading it from
    the config would agree with itself no matter what the engine did.
    """
    with open(config_path) as fh:
        slots = json.load(fh).get("slots") or []
    if not slots:
        sys.exit(f"{config_path} declares no slots; a Paintbot run needs the "
                 "variant's own roster")
    return len(slots)


def rotation_assigns(n_slots, lineup):
    """One `--assign` per rotation step, over the SAME seed.

    Colour is to a four-team board what side is to the arena: a confound worth
    more than most of the effects being measured (sim/README.md records the
    arena's red bias at 70-84%). The mirror cancels a side because there are
    only two of them. With four, the equivalent is a ROTATION -- run the seed
    once per entrant position, sliding the lineup round by one each time, so
    every build occupies every position, and therefore every colour, exactly as
    often as every other build does.

    The lineup is read as "entrant 0 is 'a', entrant 1 is 'b', ..." and step r
    hands entrant position k the build that started at position k-r. With the
    default `abbb` that is one candidate against a field of three controls --
    the league's own shape -- and the candidate visits all four colours across
    the four episodes of one seed.
    """
    n = len(lineup)
    return ["".join(lineup[(slot % n - r) % n] for slot in range(n_slots))
            for r in range(n)]


def default_lineup(n_builds):
    if n_builds == 2:
        return "a" + "b" * (ENTRANTS - 1)
    if n_builds == ENTRANTS:
        return "".join(chr(ord("a") + i) for i in range(ENTRANTS))
    sys.exit(f"no default lineup for {n_builds} builds; pass --lineup")


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
# pooling a Paintbot rotation
# --------------------------------------------------------------------------

def paint_episode(record):
    """Per-build totals for one Paintbot episode.

    Score is the mean of the seat rewards a build held, and the mean is the
    right reduction rather than a convenience: the engine pays ONE pot award
    per team (`finishGame`, sim.nim) and writes it to every seat of that team,
    so a build holding one whole team reads its own team's score back exactly,
    and a build holding half of each of two teams -- which is what the 2v2
    shape is -- reads the average of the two, which is what the league pays it
    over those two entries.

    `won` is the same average, so it is the share of a build's entries that
    were on the winning team: a win RATE for a build on one team, and the same
    quantity generalized when it is not.
    """
    per = {}
    for seat in record["seats"]:
        totals = per.setdefault(seat["build"], defaultdict(float))
        totals["seats"] += 1
        for key in ("kills", "deaths", "captures", "shotsFired", "shotsHit",
                    "reward"):
            totals[key] += seat[key]
        totals["onWinner"] += 1.0 if seat["team"] == record["winner"] else 0.0
        totals["colour:" + seat["team"]] += 1
    for totals in per.values():
        totals["score"] = totals["reward"] / totals["seats"]
        totals["won"] = totals["onWinner"] / totals["seats"]
    return per


def paint_groups(records, rotation):
    """Split records into (complete seed groups, skipped-with-reason).

    A group is one seed's whole rotation, and it is kept only if it is
    COMPLETE. That is the price of the rotation being the thing that cancels
    colour: a seed missing one of its four episodes leaves one build on three
    colours and its rivals on a different three, which puts back exactly the
    bias the design exists to remove. Dropping it is sample loss and is
    reported as such -- what is never allowed is keeping it quietly.
    """
    groups = defaultdict(list)
    skipped = []
    for record in records:
        if "error" in record:
            skipped.append((record, record["error"]))
        elif not record.get("finished", True):
            # No `finishGame`, so every reward in it is 0 -- a number that
            # reads exactly like a real pot score and is not one.
            skipped.append((record, f"hit the tick cap at {record['ticks']} "
                                    "ticks, so nothing was ever scored"))
        else:
            groups[record["seed"]].append(record)
    usable = {}
    for seed, group in sorted(groups.items()):
        if len(group) == rotation:
            usable[seed] = group
        else:
            for record in group:
                skipped.append((record, f"only {len(group)} of {rotation} "
                                        "rotation steps survived this seed"))
    return usable, skipped


def teammates(records, build, others):
    """How often each OTHER build shared a team with this one, in episodes.

    Empty when no team ever held two builds, which is the 4ffa/4ffa8 case --
    one entrant per team, so there is nobody to be teamed with. It is the 2v2
    shape that needs this: two entrants split each team, and who your partner
    is moves a score as hard as which colour you drew.

    A cyclic rotation cancels colour and does NOT cancel this. Entrant
    positions k and k+2 always share a team, and a cyclic shift moves both, so
    a lineup of four distinct builds pairs the same two together in every
    rotation step. With the default `abbb` lineup that is harmless -- there is
    only one other build to be teamed with -- which is why this is reported
    rather than refused.
    """
    # Every other build is a key, present or not: a partner a build NEVER drew
    # is exactly the imbalance worth catching, and a dict built only from what
    # was seen cannot show it.
    counts = {other: 0 for other in others}
    for record in records:
        for team in record["teamStats"]:
            if build not in team["builds"]:
                continue
            for other in team["builds"]:
                if other != build:
                    counts[other] += 1
    return counts if any(counts.values()) else {}


def ci(values):
    """The 2.5th and 97.5th percentiles of a bootstrap sample."""
    ordered = sorted(values)
    return ordered[int(0.025 * len(ordered))], ordered[int(0.975 * len(ordered))]


def paint_report(records, names, rotation, source=""):
    """Pool one Paintbot rotation: score, win share, K/D, and the colour audit.

    `names` maps a build character to its label. Build 'a' is the treatment;
    everything else is the field it ran against, and the gap at the end is 'a'
    minus the mean of that field -- the shape of the question the league asks.
    """
    usable, skipped = paint_groups(records, rotation)
    for record, why in skipped:
        print(f"  SKIPPED seed {record.get('seed', '?')} "
              f"({record.get('assign', '?')}): {why}")
    if skipped:
        print()
    if not usable:
        sys.exit("no complete rotations survived; nothing to pool")

    flat = [r for group in usable.values() for r in group]
    episodes = [paint_episode(r) for r in flat]
    teams = flat[0]["teams"]

    endings = defaultdict(int)
    for record in flat:
        endings[record["ending"]] += 1

    print(f"source          : {source}")
    print(f"board           : {teams} teams, {flat[0]['scoring']} scoring, "
          f"{flat[0]['mapPath']} map, {flat[0]['layout']}")
    print(f"episodes pooled : {len(flat)}   "
          f"({len(usable)} seeds x {rotation} rotation steps)")
    print(f"episodes lost   : {len(skipped)}")
    print("endings         : " + "  ".join(
        f"{k} {v}" for k, v in sorted(endings.items())))
    print("median length   : "
          f"{int(statistics.median(r['ticks'] for r in flat))} ticks\n")

    def mean(sample, build, key):
        return sum(ep[build][key] for ep in sample) / len(sample)

    colours = sorted({seat["team"] for r in flat for seat in r["seats"]})
    for build in sorted(names):
        held = [ep[build] for ep in episodes]
        kills = sum(t["kills"] for t in held)
        deaths = sum(t["deaths"] for t in held)
        fired = sum(t["shotsFired"] for t in held)
        print(f"{names[build]}  [{build}]")
        print(f"  seats/episode : {held[0]['seats']:.0f}")
        print(f"  mean score    : {mean(episodes, build, 'score'):+.4f}")
        print(f"  win share     : {mean(episodes, build, 'won'):.4f}"
              f"   (chance {1.0 / teams:.4f})")
        print(f"  kills         : {kills:.0f}")
        print(f"  deaths        : {deaths:.0f}")
        print(f"  captures      : {sum(t['captures'] for t in held):.0f}")
        print(f"  K/D           : {kills / deaths if deaths else 0.0:.4f}")
        print("  accuracy      : "
              f"{sum(t['shotsHit'] for t in held) / fired if fired else 0.0:.3f}")
        # The rotation auditing itself. Every build must have sat on every
        # colour the same number of times; anything else means the design did
        # not survive the sample loss above and the gap below carries colour.
        seen = {c: sum(t["colour:" + c] for t in held) for c in colours}
        balanced = len(set(seen.values())) <= 1
        print("  colour seats  : "
              + "  ".join(f"{c} {n:.0f}" for c, n in seen.items())
              + ("" if balanced else "   <-- UNBALANCED"))
        if not balanced:
            print("     The rotation did not survive this run's sample loss.")
            print("     Colour advantage is still inside this build's score.")
        mates = teammates(flat, build, [o for o in names if o != build])
        if mates:
            even = len(set(mates.values())) <= 1
            print("  teammates     : "
                  + "  ".join(f"{names[o]}[{o}] {n}"
                              for o, n in sorted(mates.items()))
                  + ("" if even else "   <-- UNBALANCED"))
            if not even:
                print("     Who you are teamed WITH is a second confound the")
                print("     rotation has to cancel, and here it did not.")

    # Bootstrap over SEED GROUPS. Never over episodes and never over seats: the
    # rotation steps of one seed share a terrain draw, and the seats inside one
    # episode share an outcome exactly -- under pot scoring every seat of a
    # team is paid the same number, so sixteen seats are at most four numbers.
    units = list(usable.values())
    unit_eps = [[paint_episode(r) for r in unit] for unit in units]
    rng = random.Random(20260803)
    draws = [[ep for unit in (rng.choice(unit_eps) for _ in unit_eps)
              for ep in unit]
             for _ in range(10000)]

    print(f"\nmean pot score per episode, bootstrapped over seeds "
          f"(n={len(units)})")
    for build in sorted(names):
        lo, hi = ci(mean(draw, build, "score") for draw in draws)
        print(f"  {names[build]:<26} {mean(episodes, build, 'score'):+.4f}"
              f"   95% CI [{lo:+.4f}, {hi:+.4f}]")

    field = [b for b in sorted(names) if b != "a"]
    if "a" not in names or not field:
        return

    def gap(sample):
        return (mean(sample, "a", "score")
                - sum(mean(sample, b, "score") for b in field) / len(field))

    observed = gap(episodes)
    lo, hi = ci(gap(draw) for draw in draws)
    label = names["a"] + " - " + (names[field[0]] if len(field) == 1
                                  else "the field")
    print(f"\nscore gap ({label}), same resamples")
    print(f"  observed           : {observed:+.4f}")
    print(f"  95% CI             : [{lo:+.4f}, {hi:+.4f}]")
    crosses = lo <= 0 <= hi
    print(f"  crosses zero       : {'YES' if crosses else 'no'}")
    if lo == hi == observed == 0.0:
        if not any(r["winner"] != "none" for r in flat):
            print("\n  A zero with NO VARIANCE behind it, because nothing on")
            print("  this board ever resolved: every team was paid the same in")
            print("  every episode, so the run could not have found a gap of")
            print("  any size. Read it as 'the board never resolved', not as")
            print("  'the builds are level'.")
        elif len({r["gameHash"] for r in flat}) == len(usable):
            # Every rotation step of a seed hashed the same -> the builds are
            # byte-equal, so the rotation ran ONE episode several ways.
            print("\n  An exact zero, and on identical builds it is the only")
            print("  answer arithmetic allows: the rotation steps of a seed")
            print("  are literally the same episode (one gameHash per seed),")
            print("  and over a COMPLETE rotation every build's mean is the")
            print("  mean over all colours -- the same number for all of them.")
            print("  An error in the rotation or in the score attribution")
            print("  breaks that identity, so this is the null calibrating,")
            print("  not the builds being level.")
    elif crosses:
        print("\n  No result. A CI that crosses zero is not a small effect,")
        print("  it is an absent one (README rule 6). Buy more seeds or")
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
    shown = show_path(out)
    print(f"\nrecords: {shown}")
    print(f"re-pool with: scripts/local_sim.py pool {shown}"
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


def cmd_paint(args):
    """One Paintbot measurement: a colour rotation over a four-entrant board.

    Every seed is run once per entrant position (`rotation_assigns`), so a
    build's score is pooled over all four colours and the colour advantage
    cancels the way side advantage cancels in the two-team mirror. n seeds
    therefore cost 4n episodes -- and all four are needed, which is why an
    incomplete seed is dropped whole rather than pooled short.
    """
    n_slots = roster_size(args.config)
    sides = [args.treatment, args.control, args.build_c, args.build_d]
    sides = [s for s in sides if s]
    lineup = args.lineup or default_lineup(len(sides))
    if set(lineup) != {chr(ord("a") + i) for i in range(len(sides))}:
        sys.exit(f"--lineup {lineup} does not use exactly the "
                 f"{len(sides)} builds given")

    with tempfile.TemporaryDirectory(prefix="ctf-sim-trees-") as keep:
        resolved = [resolve_tree(side, keep) for side in sides]
        names = {chr(ord("a") + i): name
                 for i, (_, name) in enumerate(resolved)}
        binary = build(resolved[0][0], resolved[1][0],
                       tree_c=resolved[2][0] if len(resolved) > 2 else None,
                       tree_d=resolved[3][0] if len(resolved) > 3 else None)

        assigns = rotation_assigns(n_slots, lineup)
        seeds = [args.first_seed + i for i in range(args.episodes)]
        jobs = [(binary, args.engine, args.config, s, a, args.tick_cap)
                for s in seeds for a in assigns]
        records = run_many(jobs, args.workers,
                           " / ".join(names[k] for k in sorted(names)))

    out = args.out or default_out(
        f"paint-{slug(os.path.basename(args.config))}-{slug(names['a'])}")
    write_records(out, records)
    print()
    paint_report(records, names, len(assigns), source=show_path(args.config))
    shown = show_path(out)
    print(f"\nrecords: {shown}")
    print(f"re-pool with: scripts/local_sim.py pool {shown} --paint"
          + "".join(f" --name-{k} '{v}'" for k, v in sorted(names.items())))


def cmd_pool(args):
    records = [json.loads(line) for line in open(args.episodes) if line.strip()]
    if args.paint:
        names = {k: getattr(args, "name_" + k) for k in "abcd"
                 if any(s["build"] == k
                        for r in records if "seats" in r for s in r["seats"])}
        # The rotation length is not in a record, so recover it from the run:
        # the distinct assign strings ARE the rotation steps.
        rotation = len({r["assign"] for r in records if "assign" in r})
        paint_report(records, names, rotation,
                     source=show_path(args.episodes))
        return
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
    require_ok(a, b, x, y)

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

    check_batch_matches_solo(args, binary)
    check_paintbot_record(args, binary)
    check_trees_are_separate(args)

    print("\n== decoder: framing, truncation sweep, walkability isolation")
    subprocess.run([os.path.join(SIM_DIR, "test_decoder.sh")], check=True)

    print("\nselfcheck passed.")


def check_batch_matches_solo(args, binary):
    """Prove a batched worker is the same measurement as one process per seed.

    `run_many` puts several episodes through one process to amortize setup,
    which is only sound because everything that survives between them is a
    cache of a pure function: the engine's map bake (keyed on the resolved
    CtfMap), its memoized sprite rasters, the policy's nav grid and post scans
    (keyed on the walkability mask), the shared walkability decode. A cache
    that is NOT pure -- one that carried a scrap of the previous episode's
    state -- would make an episode's result depend on what a worker happened
    to run before it, which is the kind of wrongness that never announces
    itself: every episode still finishes, every number still looks like a
    number, and the batch size silently becomes an experimental variable.

    So: run three seeds one to a process, then all three through one, and
    require the same gameHash. Deliberately more than one seed and more than
    one process-order -- a leak that only shows on the third episode of a
    batch is exactly the kind this has to catch.
    """
    print("\n== batching: three seeds, one process, must match one-per-process")
    seeds = [7001, 7002, 7003]
    # The three solo runs and the batched run are independent, so fan them
    # out rather than paying four episodes end to end on one core.
    jobs = [(binary, args.engine, args.config, [s], "a" * 16, args.tick_cap)
            for s in seeds]
    jobs.append((binary, args.engine, args.config, seeds, "a" * 16,
                 args.tick_cap))
    with ProcessPoolExecutor(max_workers=args.workers) as pool:
        produced = list(pool.map(_batch, jobs))
    solo = [part[0] for part in produced[:-1]]
    batched = produced[-1]
    ok = True
    for one, many in zip(solo, batched):
        require_ok(one, many)
        match = one["gameHash"] == many["gameHash"]
        ok = ok and match
        print(f"   seed {one['seed']}: solo {one['gameHash']}"
              f"  batched {many['gameHash']}  "
              f"{'MATCH' if match else 'DIVERGED'}")
    if not ok:
        sys.exit("   -> a batched episode is not the episode it would have "
                 "been alone.\n      Something cached across episodes is not "
                 "a pure function of that episode.\n      Set BATCH_MAX = 1 "
                 "and find it before trusting any number from here.")
    print("   -> identical, so batch size is not an experimental variable")


def check_paintbot_record(args, binary):
    """Prove a four-team episode is fully described, and a scored one scored.

    Two things here can be wrong while everything still runs and every number
    still looks like a number, which is the only kind of bug worth a check:

    - a seat's COLOUR. Before this existed the record called green and yellow
      `blue`, and nothing anywhere complained -- a pooler reading it would
      have silently merged two teams' worth of seats into one.
    - a tick-capped episode's SCORE. `finishGame` never ran, so every reward
      is 0, which reads exactly like a real pot score for a team that drew.

    So: one deliberately capped 4ffa episode must report four colours in slot
    order and `finished: false`, and one 2v2 episode run to its end must pay
    the winning team more than the losing one out of the engine's own award.
    """
    print("\n== paintbot: four colours, and a pot score only when scored")
    capped, scored = run_many([
        (binary, args.engine, os.path.join(SIM_DIR, "paintbot_4ffa.json"),
         900001, "a" * 16, 400),
        (binary, args.engine, os.path.join(SIM_DIR, "paintbot_2v2.json"),
         900001, "a" * 16, args.tick_cap),
    ], args.workers, "paintbot")
    require_ok(capped, scored)

    colours = [s["team"] for s in capped["seats"]]
    want = ["red", "blue", "green", "yellow"] * 4
    print(f"   4ffa slot colours : {' '.join(colours[:8])} ...")
    if colours != want or capped["teams"] != 4:
        sys.exit(f"   -> the four-team roster is not being reported: got "
                 f"{colours}\n      on a {capped['teams']}-team board. Every "
                 "per-team number from here is wrong.")
    if capped["finished"] or any(s["reward"] for s in capped["seats"]):
        sys.exit("   -> a tick-capped episode reported itself finished or "
                 "carried a reward.\n      Unscored episodes would pool as "
                 "real draws.")
    print(f"   4ffa tick-capped  : finished {capped['finished']}, "
          "every reward 0")

    scores = {t["team"]: t["score"] for t in scored["teamStats"]}
    print(f"   2v2 seed 900001   : {scored['ending']} / winner "
          f"{scored['winner']} / scores {scores}")
    if not scored["finished"] or scored["winner"] not in scores:
        sys.exit("   -> the 2v2 probe did not resolve; this check needs a "
                 "scored episode.\n      Pick a seed that ends inside the "
                 "tick cap before trusting a pot score.")
    if any(scores[t] >= scores[scored["winner"]]
           for t in scores if t != scored["winner"]):
        sys.exit("   -> a losing team was paid at least as much as the "
                 "winner.\n      The score is not coming off the engine's own "
                 "award.")
    print("   -> colours, the scored/unscored split, and the pot all hold")


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

        # Its own work dir: build.sh replaces the policy trees in whatever
        # dir it is given, and this check has no business destroying the
        # binary the caller just made.
        binary = build(os.path.join(REPO, "bot", "baseline"), tree_b,
                       os.path.join(work, "simulate"),
                       work=os.path.join(work, "build"))
        # A different turret rate diverges within a few ticks, so this needs
        # nowhere near a full episode.
        pure_a, pure_b = run_many([
            (binary, args.engine, args.config, 313, "a" * 16, 400),
            (binary, args.engine, args.config, 313, "b" * 16, 400),
        ], 2, "separation")

        require_ok(pure_a, pure_b)
        print(f"   all-a (AimRate 5): hash {pure_a['gameHash']}")
        print(f"   all-b (AimRate 3): hash {pure_b['gameHash']}")
        if pure_a["gameHash"] == pure_b["gameHash"]:
            sys.exit("   -> IDENTICAL. The two trees are sharing state: side b "
                     "is running side a's code.\n      Every head-to-head this "
                     "simulator reports would be a flat zero. Do not use it.")
        print("   -> diverged, as it must")

        check_warm_build(args, work, pure_a)


def check_warm_build(args, work, cold):
    """Prove a build on a WARM nimcache is the build a cold one would give.

    `sim/build.sh` keeps its nimcache between builds, which is most of what a
    research loop's wall clock used to be -- and is also the one speedup here
    that could be wrong without looking wrong: a cache that handed back a
    stale object file would compile the policy you edited into a binary
    running the policy you didn't, and every number after it would be a
    measurement of the wrong build with nothing out of place to notice.

    So: rebuild the UNPERTURBED pair over the cache the perturbed build just
    left behind, and require the same episode. The previous build in this work
    dir had a different side b, so a cache that leaks anything at all leaks it
    here.

    That premise is the whole test, and it comes from the caller, so it is
    asserted rather than assumed: with no cache to reuse this degenerates into
    "a cold build matches itself", which passes forever while testing nothing.
    """
    print("\n== warm nimcache: rebuild over it and require the same episode")
    work_dir = os.path.join(work, "build")
    if not any(name.startswith("nimcache")
               for name in os.listdir(work_dir)):
        sys.exit(f"   -> no nimcache in {work_dir}: this check would be a "
                 "cold build\n      compared against itself. Fix its premise "
                 "before trusting a warm build.")
    baseline = os.path.join(REPO, "bot", "baseline")
    binary = build(baseline, baseline,
                   os.path.join(work, "simulate-warm"), work=work_dir)
    warm, = run_many(
        [(binary, args.engine, args.config, 313, "a" * 16, 400)], 1, "warm")
    require_ok(warm)
    print(f"   cold (AimRate 5 on side a): hash {cold['gameHash']}")
    print(f"   warm (AimRate 5 both sides): hash {warm['gameHash']}")
    if warm["gameHash"] != cold["gameHash"]:
        sys.exit("   -> DIVERGED. The kept nimcache is not producing the "
                 "binary its sources describe.\n      Build with SIM_CLEAN=1 "
                 "and do not trust anything measured since.")
    print("   -> identical, so a kept nimcache is not an experimental variable")


def main():
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    def common(p, with_episodes=True, config=LEAGUE_CONFIG):
        p.add_argument("--engine", default=DEFAULT_ENGINE,
                       help="coworld-ctf checkout (default: .engine)")
        p.add_argument("--config", default=config,
                       help="game config JSON, a hosted variant's own "
                            "game_config verbatim (default: "
                            f"{os.path.basename(config)})")
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

    p = sub.add_parser(
        "paint", help="Paintbot: four entrants, colour-rotated over each seed")
    p.add_argument("treatment")
    p.add_argument("control")
    p.add_argument("--build-c", help="a third entrant policy (ref or path)")
    p.add_argument("--build-d", help="a fourth entrant policy (ref or path)")
    p.add_argument("--lineup",
                   help="which build takes each entrant position before the "
                        "rotation starts (default: 'abbb' for two builds -- "
                        "one candidate against a field of three -- and 'abcd' "
                        "for four)")
    common(p, config=PAINT_CONFIG)
    p.set_defaults(func=cmd_paint)

    p = sub.add_parser("pool", help="re-pool a saved JSONL run")
    p.add_argument("episodes")
    p.add_argument("--name-a", default="a")
    p.add_argument("--name-b", default="b")
    p.add_argument("--name-c", default="c")
    p.add_argument("--name-d", default="d")
    p.add_argument("--paint", action="store_true",
                   help="pool as a Paintbot colour rotation, not a mirror")
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
