# Why RED keeps winning mirrors — investigation record

The question: the league where every head-to-head runs shows RED winning
51%–75% of mirror episodes regardless of build (19 of 19 pooled mirrors in
`LEDGER.md`, plus the 70.9% hosted self-mirror in `../README.md`). This
file records what that advantage is, what it is not, and the experiments
behind both. All local runs: pinned engine `beae1614` + `perf.patch`,
`sim/league_config.json`, seeds 5000–5031/5047, via `sim/` and two patched
variants described below.

## The engine is fair where it is easy to be fair

- **Walls mirror exactly**: `isWall(x,y) == isWall(width-1-x,y)` for every
  pixel of the baked arena (0 mismatches).
- **Bullets mirror exactly**: `lineOfSightClear` uses truncating division,
  which is odd-symmetric; gun shots resolve simultaneously against a
  post-movement snapshot, so mutual duels kill both.

## Where it is not fair

- **The fog-of-war grid cannot mirror.** 8 px cells anchored at x = 0 on a
  1235 px map (154 cells + a 3 px east column). Measured on the baked
  arena: 157 of 1854 opaque fog cells (8.5%) have a transparent mirror
  twin; over 102,752 mirrored (viewer, aim, target) pairs on walkable
  ground, 2.30% of sightlines disagree with their mirror shadow-only,
  0.72% under the league 45° cone. Balanced in aggregate, structured
  locally — specific posts and lanes see (or are seen) where their mirror
  is not. **This bot's nav grid uses the same west-anchored 8 px scheme**
  (`grid.nim`), so the policy's cover/cost model inherits the same seams.
- **Per-player engine loops run in slot order** (movement, body-blocking,
  every pickup scan). League slots alternate red-even/blue-odd, so each
  red player acts just before its blue counterpart; the two med kits sit
  exactly on the mirror axis (x = 617) and a same-tick contested grab
  always goes to red.
- **The spawn stagger is un-mirrored** (±6 px in absolute x for both
  teams) — already known here: `roleForSeat` swaps seats 2/3 per team to
  win the opening pickup race despite it.
- **1 px anchor offset** (blue pedestal/zone 1 px deeper than red's
  mirror), same-tick double captures award blue (enum order), blocked
  slides prefer west/north for both teams. All micro.
- **Jitter streams are a constant lottery**: `bot.rng = initRand(slot *
  7919 + 1)` — the same streams every episode, and red always holds the
  even slots.

## The amplifier: local episodes share a scripted opening

`config.seed` feeds only the sim RNG, and on `arena` (no trenches) its
first draw is the first respawn placement. So every local episode of a
given build pair plays an **identical deterministic opening** until 72
ticks after first blood; "n episodes" are one scripted opening plus
post-first-blood divergence. That is why local mirror numbers are huge and
unstable: the recorded 84.4%-red mirror (this tree at `bb9874e`) and a
61.4%-blue mirror (HEAD, seeds 5000–5047, measured this session) are the
same engine and near-identical policies. Hosted episodes decohere from
tick 1 through wall-clock pacing instead, which is why hosted averages sit
stably at ~65%.

## Experiments (2026-07-31)

**Scripted parity swap.** League config with slot teams swapped
(red-odd/blue-even) + `host.nim`'s team parity patched to match, `bb9874e`
tree, seeds 5000–5031: red 13 / blue 19 (40.6% [25.5%, 57.7%]) vs 87%
(27/31) in normal seating. A scripted mirror's outcome does not survive
*any* re-seating — it re-rolls the opening.

**Decohered ensembles.** `world.nim` patched to mix a per-episode epoch
into the jitter seed (`slot*7919 + 1 + 104729*epoch`, epoch = seed via
env); verified same-epoch reproduces the gameHash and different epochs
diverge. 32 seeds each:

| run | tree | seating | red share of decisive |
|---|---|---|---|
| E1 | bb9874e | normal | 56.7% [39.2%, 72.6%] |
| E2 | bb9874e | parity-swapped | 74.2% [56.8%, 86.3%] |
| E3 | HEAD (v71-era) | normal | 40.6% [25.5%, 57.7%] |

- E1+E2: the west team wins 65.6% pooled **whichever slots it holds** —
  the hosted band (51–75%) reproduced locally with no pacing and no build
  pairing. The red advantage is anchored to the **map side**, not to slot
  processing order and not to the jitter-stream lottery (E2 swapped both).
- E1 vs E2 do not separate at n=32; there is no evidence seating matters
  at all once episodes decohere.
- E3: the current tree's blue lean is real under decoherence too. The red
  edge is a property of the (policy population × map-side seams) product,
  and the latest grenade changes moved it — consistent with the ledger's
  two weakest red shares being its two most recent entries (nadefarm420
  56.2%, nadecarrier 51.2%).

## What this means for measurement here

- Rule 2 (both directions, always) is confirmed load-bearing and stays.
- Local mirrors at fixed build pairs are **one scripted opening**, not n
  independent games. For game-level questions (not build A-vs-B), decohere
  first (the epoch-jitter patch) or the number is an artifact.
- The engine-side fix list lives in the engine repo
  (`docs/FAIRNESS_AUDIT.md` on the same branch): symmetrize the fog grid,
  simultaneous pickup resolution, mirrored spawn stagger, 1 px anchor.
  Policy-side here: seed jitter from (team-relative seat, episode) rather
  than raw slot, and the strongest cure for any residual handedness is to
  mirror the coordinate frame — decide as if always attacking east and
  flip the output buttons for the east team.

## Reproducing

- Fog probe (wall mirror check + fovBlocked pairing + sightline pairs):
  `sim/fovprobe.nim` — build like the simulator (engine nim.cfg +
  `--path:.engine/src`), run `fovprobe .engine sim/league_config.json`.
- Scripted mirrors: `scripts/local_sim.py run <tree> -n 48 --first-seed 5000`.
- Parity swap: copy `sim/`, invert the parity in `host.nim:41`, swap the
  `slots` teams in a copy of `league_config.json`.
- Decoherence: patch `seedRng` as above; drive one seed per process with
  `CTF_JITTER_EPOCH=<seed>`.
