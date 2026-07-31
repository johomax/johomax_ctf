#!/usr/bin/env python3
"""Per-role bleed instrumentation: RED vs BLUE over the banked local-sim runs.

Backlog item 9. Reads the episode records `scripts/local_sim.py` writes
(`episodes/*.jsonl`) and aggregates every seat by (side, seat, role) into
kills, deaths, K/D and accuracy, then reports the RED-minus-BLUE gap per seat
and per role with intervals around it.

    nix shell nixpkgs#python3 -c python3 analysis/role_bleed.py > out.md

Read-only. It never touches bot/, sim/, scripts/ or research/.

WHY THE SIDE CONTRAST IS CLEAN, AND WHAT IT IS NOT
--------------------------------------------------
Every banked head-to-head file holds both directions of the same seeds in
equal number (`mirrored_assign` in scripts/local_sim.py: "abab..." then
"baba..."), so across a whole file each SIDE is held by the treatment build in
half its episodes and by the control build in the other half. The build effect
therefore cancels out of a red-minus-blue contrast by construction -- the
mirror image of the trick `pool_h2h.py` uses to cancel the side out of a build
contrast. `direction_balance` below checks that property rather than assuming
it.

What does NOT cancel is the engine pin. The corpus straddles the GV27 ->
1047232f re-pin of 2026-07-31T08:10Z (research/LEDGER.md, "The league moved:
GV27 -> current"), and the ledger's own words are that a stale pin "can
silently measure a game the league no longer plays". So the era split is not
cosmetic: only the gv-current rows describe the game an experiment queued
today would be measured in.

UNITS OF RESAMPLING
-------------------
Three intervals, deliberately, because they answer three different questions:

  seed-pair bootstrap  the two directions of one seed share a terrain draw and
                       a spawn layout, so they resample together (the pairing
                       `local_sim.py`'s own `report` keeps). This is the
                       sampling noise inside this corpus.
  file bootstrap       whole experiment files resample together. A file is one
                       treatment build, one seed block, one moment in the
                       tree's history; this asks whether the gap would survive
                       a different set of experiments.
  side permutation     relabel which side is "red", per seed block, 50/50.
                       The spread of that null is what a gap of exactly zero
                       looks like through the same clustering, and it is the
                       direct answer to "how much of this is noise".
"""

import argparse
import calendar
import datetime
import glob
import json
import os
import random
import sys
import time
from collections import defaultdict

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_EPISODES = os.path.join(REPO, "episodes")
SIDES = ("red", "blue")


# ---------------------------------------------------------------------------
# seat -> role, copied out of the policy rather than guessed
# ---------------------------------------------------------------------------

#: `bot/baseline/world.nim:131 roleForSeat(seat, team)`, transcribed.
#:
#: The per-team seat is `slot div 2` and the team is `slot mod 2` (Red even,
#: Blue odd) -- `bot/baseline.nim:135-136` derives that from the websocket URL
#: in the tournament build and `sim/host.nim:41-42` derives it identically in
#: the simulator, so the two agree. The mapping is FIXED for the episode:
#: `newSeat` computes the role once at construction and nothing anywhere in
#: bot/ assigns `bot.role` again (`grep -rn 'role =' bot/`).
#:
#: Seats 2 and 3 are the only asymmetry. Both spawn at flag height, and the
#: lead rusher (MidTop) is whichever of the two spawns closest to the flag --
#: the sim's un-mirrored +-6px spawn offset makes that seat 3 for Red and
#: seat 2 for Blue (world.nim:132-135). So a role comparison is NOT a seat
#: comparison, and this file reports both.
ROLE_BY_SEAT = {
    0: {"red": "FlankBottom", "blue": "FlankBottom"},
    1: {"red": "MidGuard", "blue": "MidGuard"},
    2: {"red": "MidBottom", "blue": "MidTop"},
    3: {"red": "MidTop", "blue": "MidBottom"},
    4: {"red": "MidBottom", "blue": "MidBottom"},
    5: {"red": "Overwatch", "blue": "Overwatch"},
    6: {"red": "FlankTop", "blue": "FlankTop"},
    7: {"red": "HomeDefender", "blue": "HomeDefender"},
}

ROLES = ["FlankBottom", "MidGuard", "MidTop", "MidBottom",
         "Overwatch", "FlankTop", "HomeDefender"]

#: The moment the simulator's engine pin moved from GV27 (beae1614, ctf
#: v0.7.124) to the league's current 1047232f (ctf 0.7.136) -- live mid
#: diamonds, compact endzones, paint stains. research/LEDGER.md's "The league
#: moved: GV27 -> current" section dates the write-up 2026-07-31T08:10:00Z and
#: names the two `verify-gv29-*` files as the re-verification run ALREADY made
#: under the new pin; those two files' mtimes are 08:02 and 08:05, and the
#: last GV27 experiment (`nade-farm-not-during-thief-chase`, 07:50:07Z per its
#: ledger section) is 07:50. This cutoff sits in the gap between them.
#:
#: An episode file is classified by its mtime, not by a name whitelist,
#: because `episodes/` is a live directory: a concurrent auto-research session
#: adds files while this runs, and a whitelist would silently file them under
#: the wrong engine. `LEDGER_GV_CURRENT` below is the whitelist the ledger
#: does support, kept only as a cross-check the run prints if it disagrees.
PIN_MOVE = 1785484560          # 2026-07-31T07:56:00Z

LEDGER_GV_CURRENT = {
    "verify-gv29-scanarc28-vs-36.jsonl",
    "verify-gv29-medkit120-vs-80.jsonl",
    "exp-medkitdetour-gv29-revert.jsonl",
    "exp-cooldown-sweep.jsonl",
    "exp-duck-standoff.jsonl",
    "exp-clock-phased-wave.jsonl",
    "exp-corpse-track-cleanup.jsonl",
    "exp-onewaybonus40.jsonl",
    "exp-onewaybonus40-further.jsonl",
    "exp-corpseclear160.jsonl",
}

ERAS = ("gv-current", "gv27")


def era_of(path):
    return "gv-current" if os.path.getmtime(path) >= PIN_MOVE else "gv27"


# ---------------------------------------------------------------------------
# loading
# ---------------------------------------------------------------------------

class Episode:
    """One record, reduced to what a side/seat contrast needs."""

    __slots__ = ("file", "era", "mtime", "seed", "assign", "winner", "draw",
                 "seats")

    def __init__(self, record, path, era, mtime):
        self.file = os.path.basename(path)
        self.era = era
        self.mtime = mtime
        self.seed = record["seed"]
        self.assign = record.get("assign", "")
        self.winner = record.get("winner")
        self.draw = record.get("draw", False)
        self.seats = [dict() for _ in range(8)]
        for entry in record["seats"]:
            slot = entry["slot"]
            side = entry["team"]
            # The parity derivation the policy itself uses. A record that
            # violated it would make the seat->role mapping silently wrong,
            # so this is a hard stop rather than a comment.
            expected = "red" if slot % 2 == 0 else "blue"
            if side != expected:
                sys.exit(f"{self.file} seed {self.seed}: slot {slot} is team "
                         f"{side}, but bot/baseline.nim:135 derives "
                         f"{expected} from the slot parity. The seat->role "
                         "mapping cannot be trusted against this record.")
            self.seats[slot // 2][side] = entry


def load(patterns, until=None):
    paths = []
    for pattern in patterns:
        if os.path.isdir(pattern):
            paths.extend(sorted(glob.glob(os.path.join(pattern, "*.jsonl"))))
        else:
            paths.extend(sorted(glob.glob(pattern)))
    if until is not None:
        # `episodes/` is written into by a running research loop. A cutoff is
        # what lets a report state a corpus a re-run can reproduce exactly.
        paths = [p for p in paths if os.path.getmtime(p) <= until]
    if not paths:
        sys.exit(f"no episode files matched {patterns}")

    episodes, skipped = [], []
    for path in paths:
        # Read the era and mtime ONCE per file: `episodes/` is a live
        # directory and a file appended to mid-run must not change era
        # halfway through its own records.
        mtime, era = os.path.getmtime(path), era_of(path)
        name = os.path.basename(path)
        with open(path) as fh:
            for number, line in enumerate(fh, 1):
                line = line.strip()
                if not line:
                    continue
                try:
                    record = json.loads(line)
                except json.JSONDecodeError as problem:
                    # A file being written right now can end mid-line.
                    skipped.append((name, {"seed": f"line {number}",
                                           "error": f"unparseable: {problem}"}))
                    continue
                if "error" in record:        # README rule 7: visibly excluded
                    skipped.append((name, record))
                    continue
                episodes.append(Episode(record, path, era, mtime))
    return paths, episodes, skipped


def clusters(episodes, unit):
    """Group episodes into resampling units, largest key first for stability.

    `seed` keeps the two directions of one seed together (they share a terrain
    and spawn draw). `file` keeps a whole experiment together.
    """
    groups = defaultdict(list)
    for episode in episodes:
        key = episode.file if unit == "file" else (episode.file, episode.seed)
        groups[key].append(episode)
    return [groups[key] for key in sorted(groups, key=str)]


# ---------------------------------------------------------------------------
# the resampled statistic
#
# Everything the intervals need is a linear function of per-(seat, side) sums
# of kills and deaths, so a cluster reduces once to a fixed 33-slot vector and
# a resample is a sum of vectors. That is what makes 2000 draws over ~4000
# clusters finish in seconds instead of an hour.
#
#   index 4*seat + 0 : red kills      index 4*seat + 2 : blue kills
#   index 4*seat + 1 : red deaths     index 4*seat + 3 : blue deaths
#   index 32         : episodes
# ---------------------------------------------------------------------------

VLEN = 33
NIDX = 32


def episode_vector(episode):
    vector = [0] * VLEN
    for seat in range(8):
        base = 4 * seat
        red, blue = episode.seats[seat]["red"], episode.seats[seat]["blue"]
        vector[base] = red["kills"]
        vector[base + 1] = red["deaths"]
        vector[base + 2] = blue["kills"]
        vector[base + 3] = blue["deaths"]
    vector[NIDX] = 1
    return vector


def add(into, other):
    for i in range(VLEN):
        into[i] += other[i]
    return into


def cluster_vector(unit):
    total = [0] * VLEN
    for episode in unit:
        add(total, episode_vector(episode))
    return tuple(total)


def _role_partner():
    """red seat -> the blue seat holding the SAME role, and the inverse.

    Every role has the same number of seats on each side, so this is a
    bijection. MidBottom owns two seats a side (red 2,4 and blue 3,4) and the
    pairing inside it is arbitrary -- the role statistic pools them.
    """
    forward, backward = {}, {}
    for role in ROLES:
        red = [s for s in range(8) if ROLE_BY_SEAT[s]["red"] == role]
        blue = [s for s in range(8) if ROLE_BY_SEAT[s]["blue"] == role]
        if len(red) != len(blue):
            sys.exit(f"role {role} has {len(red)} red seats and {len(blue)} "
                     "blue seats: the sides are not role-symmetric and a role "
                     "contrast is not defined.")
        for r, b in zip(red, blue):
            forward[r], backward[b] = b, r
    return forward, backward


ROLE_PARTNER, ROLE_PARTNER_INV = _role_partner()


def swap_sides(vector):
    """The same vector with the two sides exchanged, SEAT for seat.

    Under the null "the side label carries nothing" this is a relabelling the
    data cannot notice. Swapping (rather than flipping a difference's sign) is
    what keeps the null exact for a ratio statistic like K/D.

    Correct for the per-seat and team contrasts. NOT correct for the per-role
    contrasts: seats 2 and 3 hold different roles on the two sides, so a
    seat-for-seat swap would smuggle the (large) MidTop-vs-MidBottom role
    difference into a null that is supposed to contain only side.
    """
    out = list(vector)
    for seat in range(8):
        base = 4 * seat
        out[base], out[base + 2] = vector[base + 2], vector[base]
        out[base + 1], out[base + 3] = vector[base + 3], vector[base + 1]
    return tuple(out)


def swap_sides_by_role(vector):
    """The same vector with the two sides exchanged, ROLE for role.

    The relabelling the per-role contrasts need: red's MidTop (seat 3) trades
    with blue's MidTop (seat 2), not with blue's seat 3.
    """
    out = list(vector)
    for seat in range(8):
        partner = ROLE_PARTNER[seat]
        out[4 * seat] = vector[4 * partner + 2]
        out[4 * seat + 1] = vector[4 * partner + 3]
    for seat in range(8):
        partner = ROLE_PARTNER_INV[seat]
        out[4 * seat + 2] = vector[4 * partner]
        out[4 * seat + 3] = vector[4 * partner + 1]
    return tuple(out)


def ratio(num, den):
    return num / den if den else 0.0


def stats_from(vector):
    """Every reported gap, from one totals vector. RED minus BLUE throughout."""
    n = vector[NIDX]
    out = {}

    def gap(seats, tag):
        rk = sum(vector[4 * s] for s in seats)
        rd = sum(vector[4 * s + 1] for s in seats)
        bk = sum(vector[4 * s + 2] for s in seats)
        bd = sum(vector[4 * s + 3] for s in seats)
        out[tag + ".kd"] = ratio(rk, rd) - ratio(bk, bd)
        out[tag + ".kills_ep"] = ratio(rk - bk, n)
        out[tag + ".deaths_ep"] = ratio(rd - bd, n)

    for seat in range(8):
        gap([seat], f"seat{seat}")
    for role in ROLES:
        # A role is a different seat set on each side, so it cannot go through
        # `gap`: seats 2 and 3 swap between MidTop and MidBottom.
        red_seats = [s for s in range(8) if ROLE_BY_SEAT[s]["red"] == role]
        blue_seats = [s for s in range(8) if ROLE_BY_SEAT[s]["blue"] == role]
        rk = sum(vector[4 * s] for s in red_seats)
        rd = sum(vector[4 * s + 1] for s in red_seats)
        bk = sum(vector[4 * s + 2] for s in blue_seats)
        bd = sum(vector[4 * s + 3] for s in blue_seats)
        out[f"role:{role}.kd"] = ratio(rk, rd) - ratio(bk, bd)
        out[f"role:{role}.kills_ep"] = ratio(rk - bk, n)
        out[f"role:{role}.deaths_ep"] = ratio(rd - bd, n)
    gap(range(8), "team")
    return out


#: `mode` -> how one draw is built. "boot" resamples clusters with
#: replacement; the two "perm" modes flip each cluster's side label with
#: p = 0.5 under the relabelling appropriate to the contrast being read.
SWAPPERS = {"perm-seat": swap_sides, "perm-role": swap_sides_by_role}


def resample(vectors, draws, seed, mode):
    """Bootstrap (`mode='boot'`) or a side-relabelling null."""
    rng = random.Random(seed)
    count = len(vectors)
    collected = defaultdict(list)
    if mode != "boot":
        swapper = SWAPPERS[mode]
        pairs = [(vector, swapper(vector)) for vector in vectors]
    for _ in range(draws):
        if mode == "boot":
            sample = rng.choices(vectors, k=count)
        else:
            sample = [pair[rng.getrandbits(1)] for pair in pairs]
        totals = [sum(column) for column in zip(*sample)]
        for key, value in stats_from(totals).items():
            collected[key].append(value)
    return {key: sorted(values) for key, values in collected.items()}


def interval(sorted_values, level):
    lo = sorted_values[int((0.5 - level / 2) * len(sorted_values))]
    hi = sorted_values[min(len(sorted_values) - 1,
                           int((0.5 + level / 2) * len(sorted_values)))]
    return lo, hi


def two_sided_p(null_values, observed):
    """Share of the null at least as extreme as |observed|, +1 smoothed."""
    extreme = sum(1 for value in null_values if abs(value) >= abs(observed))
    return (extreme + 1) / (len(null_values) + 1)


# ---------------------------------------------------------------------------
# level tables (no resampling: these are the raw per-seat numbers)
# ---------------------------------------------------------------------------

def tally(episodes):
    out = {s: {side: defaultdict(float) for side in SIDES} for s in range(8)}
    for episode in episodes:
        for seat in range(8):
            for side in SIDES:
                entry = episode.seats[seat][side]
                acc = out[seat][side]
                acc["kills"] += entry["kills"]
                acc["deaths"] += entry["deaths"]
                acc["captures"] += entry["captures"]
                acc["fired"] += entry["shotsFired"]
                acc["hit"] += entry["shotsHit"]
                # `lives: 3` in sim/league_config.json, so deaths saturate at
                # 3 and "spent every life" is the uncensored bleed signal.
                acc["spent"] += 1.0 if entry["deaths"] >= 3 else 0.0
                acc["n"] += 1
    return out


def seat_stats(acc):
    n = acc["n"]
    return {"n": n,
            "kills_ep": ratio(acc["kills"], n),
            "deaths_ep": ratio(acc["deaths"], n),
            "kd": ratio(acc["kills"], acc["deaths"]),
            "acc": ratio(acc["hit"], acc["fired"]),
            "spent": ratio(acc["spent"], n),
            "caps_ep": ratio(acc["captures"], n)}


def merge(accs):
    out = defaultdict(float)
    for acc in accs:
        for key, value in acc.items():
            out[key] += value
    return out


# ---------------------------------------------------------------------------
# reporting
# ---------------------------------------------------------------------------

def fmt(value, places=3, sign=False):
    return f"{value:+.{places}f}" if sign else f"{value:.{places}f}"


def corpus_table(paths, episodes, skipped):
    print("## Corpus\n")
    print("| era | files | episodes | seed blocks | RED win % | draws |")
    print("|---|---|---|---|---|---|")
    rows = [(era, [e for e in episodes if e.era == era]) for era in ERAS]
    rows.append(("**all**", episodes))
    for label, subset in rows:
        if not subset:
            continue
        files = len({e.file for e in subset})
        blocks = len({(e.file, e.seed) for e in subset})
        red = sum(1 for e in subset if not e.draw and e.winner == "red")
        draw = sum(1 for e in subset if e.draw)
        print(f"| {label} | {files} | {len(subset)} | {blocks} | "
              f"{100.0 * red / len(subset):.1f} | {draw} |")
    print(f"\nFiles read: {len(paths)}. Records carrying an `error` "
          f"(excluded, README rule 7): {len(skipped)}.")
    for name, record in skipped:
        print(f"  - {name} seed {record.get('seed')}: {record.get('error')}")
    print()


def era_files_table(episodes):
    """The corpus snapshot, file by file. `episodes/` is a live directory, so
    this table IS the record of what was analysed."""
    per = defaultdict(list)
    for episode in episodes:
        per[episode.file].append(episode)

    # One-directional check: every file the ledger says was run under the new
    # pin must land in gv-current. The converse is not a contradiction -- a
    # file written after the ledger's last entry is post-pin and simply not
    # written up yet.
    disagree = [name for name in per
                if name in LEDGER_GV_CURRENT and per[name][0].era != "gv-current"]
    if disagree:
        print("**MTIME/LEDGER CONTRADICTION for: " + ", ".join(sorted(disagree))
              + " -- research/LEDGER.md says these ran under the re-pinned "
              "engine but their mtime\nputs them before the cutoff. Resolve "
              "before reading anything below.**\n")

    print("<details><summary>per-file snapshot (episodes/ is a live "
          "directory; this is what was read)</summary>\n")
    print("| file | mtime (UTC) | era | in ledger | episodes | RED win % |")
    print("|---|---|---|---|---|---|")
    for name in sorted(per, key=lambda k: per[k][0].mtime):
        subset = per[name]
        red = sum(1 for e in subset if not e.draw and e.winner == "red")
        stamp = time.strftime("%Y-%m-%d %H:%M", time.gmtime(subset[0].mtime))
        cited = "yes" if name in LEDGER_GV_CURRENT else "-"
        print(f"| {name} | {stamp} | {subset[0].era} | {cited} | "
              f"{len(subset)} | {100.0 * red / len(subset):.1f} |")
    print("\n</details>\n")


def direction_balance(episodes):
    """Check the property that makes the side contrast build-neutral."""
    per_file = defaultdict(lambda: defaultdict(int))
    for episode in episodes:
        per_file[episode.file][episode.assign] += 1
    bad = []
    for name, counts in per_file.items():
        values = sorted(counts.values())
        if len(counts) == 2 and values[0] == values[1]:
            continue
        if len(counts) == 1 and set(counts) <= {"a" * 16, "b" * 16}:
            continue                  # one build in all sixteen seats
        bad.append((name, dict(counts)))
    print("## Build balance across sides\n")
    print("A red-minus-blue contrast is build-neutral only if each file ran "
          "both directions\nin equal number. Checked, per file:\n")
    if bad:
        print("**UNBALANCED -- the numbers below are contaminated by the "
              "build:**\n")
        for name, counts in bad:
            print(f"  - {name}: {counts}")
    else:
        print(f"All {len(per_file)} files balanced (equal `abab...` and "
              "`baba...` counts, or a single\nall-one-build assign). The "
              "build cancels out of every red-minus-blue number below.")
    print()


def levels_table(sums):
    print("### Levels, per side and seat\n")
    print("| side | seat | role | kills/ep | deaths/ep | K/D | accuracy | "
          "spent all 3 lives | caps/ep |")
    print("|---|---|---|---|---|---|---|---|---|")
    for side in SIDES:
        for seat in range(8):
            row = seat_stats(sums[seat][side])
            print(f"| {side} | {seat} | {ROLE_BY_SEAT[seat][side]} | "
                  f"{fmt(row['kills_ep'])} | {fmt(row['deaths_ep'])} | "
                  f"{fmt(row['kd'])} | {fmt(row['acc'])} | "
                  f"{100 * row['spent']:.1f}% | {fmt(row['caps_ep'])} |")
    print()


def roles_table(sums):
    print("### Levels, per side and role\n")
    print("(MidBottom pools two seats a side; every other role is one seat. "
          "The role split is\nsymmetric between the sides, so this is an "
          "apples-to-apples pairing.)\n")
    print("| role | seats (red/blue) | red kills/ep | blue kills/ep | "
          "red K/D | blue K/D | red acc | blue acc |")
    print("|---|---|---|---|---|---|---|---|")
    for role in ROLES:
        red_seats = [s for s in range(8) if ROLE_BY_SEAT[s]["red"] == role]
        blue_seats = [s for s in range(8) if ROLE_BY_SEAT[s]["blue"] == role]
        red = seat_stats(merge(sums[s]["red"] for s in red_seats))
        blue = seat_stats(merge(sums[s]["blue"] for s in blue_seats))
        seats = (",".join(map(str, red_seats)) + "/"
                 + ",".join(map(str, blue_seats)))
        print(f"| {role} | {seats} | {fmt(red['kills_ep'])} | "
              f"{fmt(blue['kills_ep'])} | {fmt(red['kd'])} | "
              f"{fmt(blue['kd'])} | {fmt(red['acc'])} | {fmt(blue['acc'])} |")
    print()


def gap_table(rows, observed, boot_seed, boot_file, null, family, title, note):
    """`family` is the number of comparisons the Bonferroni column covers."""
    level = 1 - 0.05 / family
    print(f"### {title}\n")
    print(note + "\n")
    print("| contrast | ΔK/D | 95% CI (seed pairs) | "
          f"{100 * level:.2f}% CI (Bonferroni /{family}) | 95% CI (files) | "
          "Δkills/ep | Δdeaths/ep | perm p |")
    print("|---|---|---|---|---|---|---|---|")
    for key, label in rows:
        kd = observed[f"{key}.kd"]
        lo, hi = interval(boot_seed[f"{key}.kd"], 0.95)
        blo, bhi = interval(boot_seed[f"{key}.kd"], level)
        flo, fhi = interval(boot_file[f"{key}.kd"], 0.95)
        p = two_sided_p(null[f"{key}.kd"], kd)
        strong = (lo > 0 or hi < 0) and (blo > 0 or bhi < 0)
        mark = "**" if strong else ""
        print(f"| {mark}{label}{mark} | {fmt(kd, 4, True)} "
              f"| [{fmt(lo, 4, True)}, {fmt(hi, 4, True)}] "
              f"| [{fmt(blo, 4, True)}, {fmt(bhi, 4, True)}] "
              f"| [{fmt(flo, 4, True)}, {fmt(fhi, 4, True)}] "
              f"| {fmt(observed[f'{key}.kills_ep'], 3, True)} "
              f"| {fmt(observed[f'{key}.deaths_ep'], 3, True)} "
              f"| {p:.4f} |")
    print("\nBold = the seed-pair interval excludes zero at 95% **and** after "
          "the Bonferroni\ncorrection for this whole family. `perm p` is the "
          "two-sided share of the\nside-relabelling null at least this "
          "extreme. The file interval is the one that\nasks whether the gap "
          "survives a different set of experiments -- read it before\nacting "
          "on any row.\n")


def null_table(null, rows):
    print("### What zero looks like\n")
    print("The side-relabelling null through exactly the same clustering and "
          "statistic.\nA gap inside this band is indistinguishable from no "
          "side effect at all.\n")
    print("| contrast | null 95% band, ΔK/D | null 95% band, Δkills/ep |")
    print("|---|---|---|")
    for key, label in rows:
        klo, khi = interval(null[f"{key}.kd"], 0.95)
        nlo, nhi = interval(null[f"{key}.kills_ep"], 0.95)
        print(f"| {label} | [{fmt(klo, 4, True)}, {fmt(khi, 4, True)}] "
              f"| [{fmt(nlo, 3, True)}, {fmt(nhi, 3, True)}] |")
    print()


def per_file_consistency(episodes):
    """The same gap recomputed inside each experiment file, one at a time.

    The file bootstrap gives an interval; this gives the thing the interval
    is summarising. An effect present in 14 of 15 independent experiments is
    a different animal from one carried by a single 400-episode file, and no
    single number distinguishes them.
    """
    units = clusters(episodes, "file")
    rows = []
    for unit in units:
        vector = cluster_vector(unit)
        rows.append((unit[0].file, vector[NIDX], stats_from(list(vector))))
    print("### Does each experiment file agree?\n")
    print(f"The same contrast recomputed inside each of the {len(rows)} "
          "files on its own. Every\nfile is a different treatment build and a "
          "different seed block, so agreement here\nis the closest thing to "
          "replication this corpus has.\n")
    print("| contrast | median ΔK/D | min | max | files with the pooled sign |")
    print("|---|---|---|---|---|")
    pooled = [0] * VLEN
    for unit in units:
        add(pooled, list(cluster_vector(unit)))
    overall = stats_from(pooled)
    keys = ([(f"seat{s}", f"seat {s} "
              f"({ROLE_BY_SEAT[s]['red']}/{ROLE_BY_SEAT[s]['blue']})")
             for s in range(8)] + [("team", "all eight seats")])
    for key, label in keys:
        values = sorted(row[2][f"{key}.kd"] for row in rows)
        middle = values[len(values) // 2]
        agree = sum(1 for value in values
                    if value * overall[f"{key}.kd"] > 0)
        print(f"| {label} | {fmt(middle, 4, True)} | {fmt(values[0], 4, True)} "
              f"| {fmt(values[-1], 4, True)} | {agree}/{len(values)} |")
    print()


def split_half(episodes):
    """Does the per-seat gap reproduce on a disjoint half of the corpus?

    The repository's own hardest lesson (research/LEDGER.md, "Same change, two
    seed batches, two different answers"): a number that does not survive
    being cut in half was never a finding.
    """
    units = clusters(episodes, "seed")
    halves = []
    for parity in (0, 1):
        total = [0] * VLEN
        for index, unit in enumerate(units):
            if index % 2 == parity:
                add(total, list(cluster_vector(unit)))
        halves.append((total[NIDX], stats_from(total)))
    (na, a), (nb, b) = halves
    print("### Split-half reproducibility\n")
    print(f"Alternate seed blocks into two disjoint halves ({na} and {nb} "
          "episodes) and\nrecompute. A gap that flips sign between halves is "
          "noise however tight its CI.\n")
    print("| contrast | role (red/blue) | ΔK/D half A | ΔK/D half B | "
          "same sign |")
    print("|---|---|---|---|---|")
    for seat in range(8):
        ka, kb = a[f"seat{seat}.kd"], b[f"seat{seat}.kd"]
        roles = ROLE_BY_SEAT[seat]
        print(f"| seat {seat} | {roles['red']}/{roles['blue']} | "
              f"{fmt(ka, 4, True)} | {fmt(kb, 4, True)} | "
              f"{'yes' if ka * kb > 0 else '**NO**'} |")
    ta, tb = a["team.kd"], b["team.kd"]
    print(f"| **all eight** | -- | {fmt(ta, 4, True)} | {fmt(tb, 4, True)} | "
          f"{'yes' if ta * tb > 0 else '**NO**'} |")
    print()


def report(episodes, label, draws, seed):
    print(f"## {label}\n")
    sums = tally(episodes)
    seed_units = [cluster_vector(u) for u in clusters(episodes, "seed")]
    file_units = [cluster_vector(u) for u in clusters(episodes, "file")]
    total = [0] * VLEN
    for vector in seed_units:
        add(total, list(vector))
    observed = stats_from(total)

    episode_count = total[NIDX]
    print(f"{episode_count} episodes, {len(seed_units)} seed blocks, "
          f"{len(file_units)} files.\n")
    print("| side | kills | deaths | K/D | kills/ep | accuracy | "
          "spent all 3 lives |")
    print("|---|---|---|---|---|---|---|")
    for side in SIDES:
        acc = merge(sums[s][side] for s in range(8))
        row = seat_stats(acc)
        print(f"| {side} | {acc['kills']:.0f} | {acc['deaths']:.0f} "
              f"| {fmt(row['kd'], 4)} "
              f"| {fmt(acc['kills'] / episode_count)} | {fmt(row['acc'])} "
              f"| {100 * row['spent']:.1f}% |")
    print("\nA seat holds `lives: 3` (sim/league_config.json), so deaths "
          "saturate at 3 and the\nlast column is the uncensored read on how "
          "hard a seat is dying.\n")

    levels_table(sums)
    roles_table(sums)

    boot_seed = resample(seed_units, draws, seed, "boot")
    boot_file = resample(file_units, draws, seed + 1, "boot")
    null = resample(seed_units, draws, seed + 2, "perm-seat")
    null_role = resample(seed_units, draws, seed + 3, "perm-role")

    gap_table([(f"seat{s}", f"seat {s} "
                f"({ROLE_BY_SEAT[s]['red']}/{ROLE_BY_SEAT[s]['blue']})")
               for s in range(8)],
              observed, boot_seed, boot_file, null, 8,
              "RED minus BLUE, by seat",
              "Seat `s` is engine slots `2s` (red) and `2s+1` (blue) -- the "
              "mirrored spawn\nposition. Positive = red ahead, negative = "
              "red bleeding there.")

    gap_table([(f"role:{r}", r) for r in ROLES],
              observed, boot_seed, boot_file, null_role, 7,
              "RED minus BLUE, by role",
              "Re-paired by ROLE, which swaps seats 2 and 3 relative to the "
              "table above\n(world.nim:143-144). This is the pairing backlog "
              "item 4 would act on. The\npermutation null here relabels the "
              "sides ROLE for role, so the MidTop-vs-\nMidBottom difference "
              "cannot leak into it.")

    print("### The team gap, and which seats carry it\n")
    kd_lo, kd_hi = interval(boot_seed["team.kd"], 0.95)
    fk_lo, fk_hi = interval(boot_file["team.kd"], 0.95)
    nk_lo, nk_hi = interval(null["team.kd"], 0.95)
    p = two_sided_p(null["team.kd"], observed["team.kd"])
    print(f"- team ΔK/D (red - blue): **{fmt(observed['team.kd'], 4, True)}**")
    print(f"  - 95% CI over seed pairs: [{fmt(kd_lo, 4, True)}, "
          f"{fmt(kd_hi, 4, True)}]")
    print(f"  - 95% CI over files: [{fmt(fk_lo, 4, True)}, "
          f"{fmt(fk_hi, 4, True)}]")
    print(f"  - null band: [{fmt(nk_lo, 4, True)}, {fmt(nk_hi, 4, True)}], "
          f"permutation p = {p:.4f}")
    kills_gap = observed["team.kills_ep"]
    print(f"- team Δkills/ep: {fmt(kills_gap, 3, True)} "
          "(the sum of the eight per-seat Δkills/ep)\n")
    print("| seat | role (red/blue) | Δkills/ep | share of the team gap |")
    print("|---|---|---|---|")
    for seat in range(8):
        share = observed[f"seat{seat}.kills_ep"]
        pct = 100.0 * share / kills_gap if kills_gap else float("nan")
        roles = ROLE_BY_SEAT[seat]
        print(f"| {seat} | {roles['red']}/{roles['blue']} | "
              f"{fmt(share, 3, True)} | {pct:+.0f}% |")
    print("\nA share over 100% means other seats pull the other way. When the "
          "team gap is\nnear zero the percentages are meaningless -- read the "
          "signs.\n")

    null_table(null, [(f"seat{s}", f"seat {s}") for s in range(8)]
               + [("team", "all eight seats")])
    per_file_consistency(episodes)
    split_half(episodes)


def main():
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("episodes", nargs="*", default=[DEFAULT_EPISODES],
                        help="episode files, globs or directories "
                             "(default: the repo's episodes/)")
    parser.add_argument("--draws", type=int, default=2000,
                        help="bootstrap / permutation draws (default 2000)")
    parser.add_argument("--seed", type=int, default=20260731,
                        help="resampling seed, so a run reproduces")
    parser.add_argument("--era", choices=list(ERAS) + ["all", "each"],
                        default="each",
                        help="which engine pin to report (default: each, "
                             "then the pooled corpus)")
    parser.add_argument("--until", metavar="ISO8601",
                        help="ignore files modified after this UTC time, e.g. "
                             "2026-07-31T18:40:00 -- `episodes/` is written "
                             "into by the research loop, and this is what "
                             "makes a report reproducible")
    args = parser.parse_args()

    until = None
    if args.until:
        stamp = args.until.rstrip("Z")
        try:
            until = calendar.timegm(
                datetime.datetime.fromisoformat(stamp).timetuple())
        except ValueError as problem:
            sys.exit(f"--until: {problem}")

    paths, episodes, skipped = load(args.episodes, until)

    print("# Per-role bleed: RED vs BLUE over the banked local-sim episodes\n")
    print("Generated by `analysis/role_bleed.py` (backlog item 9). "
          f"{args.draws} bootstrap /\npermutation draws, resampling seed "
          f"{args.seed}."
          + (f" Corpus frozen at files modified <= {args.until} UTC."
             if until else " No corpus cutoff: `episodes/` is a live "
                           "directory, so a later re-run reads more files.")
          + "\n")
    corpus_table(paths, episodes, skipped)
    era_files_table(episodes)
    direction_balance(episodes)

    if args.era == "each":
        wanted = [(era, f"Era: {era}") for era in ERAS]
        wanted.append((None, "Era: pooled (BOTH pins -- see the caveat above)"))
    elif args.era == "all":
        wanted = [(None, "Era: pooled (BOTH pins)")]
    else:
        wanted = [(args.era, f"Era: {args.era}")]

    for era, label in wanted:
        subset = (episodes if era is None
                  else [e for e in episodes if e.era == era])
        if subset:
            report(subset, label, args.draws, args.seed)


if __name__ == "__main__":
    main()
