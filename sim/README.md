# The local simulator

A CTF episode that runs in one process on one machine: no Docker daemon, no
seventeen containers, no websockets, no wall clock, no league. A seed
reproduces an episode exactly, and two policy builds can hold opposite sides
of the same episode, so a head-to-head that used to cost an Experience Request
costs a lunch break instead.

It is not a model of the game. It is the game, with the transport removed.

## What is real, and what is not

Three things carry the fidelity, and all three are the upstream code itself
rather than a copy of it:

| piece | where it comes from |
|---|---|
| the rules | `ctf/sim` from the pinned coworld-ctf checkout, stepped through `step(inputs, prevInputs)` — the same entry the hosted server and the replay player both call |
| what a player sees | the server's own `buildSpriteProtocolPlayerUpdates`, threaded through the same per-viewer state `server.nim` threads, producing the same sprite-protocol bytes a socket would have carried — fog, aim fuzz and all |
| the policy | the tree under test, decoding those bytes through its own `bot/baseline/protocols.nim` |

Nothing on that list is reimplemented here. The only code this directory adds
to the loop is `host.nim`, which is `baseline.nim`'s `runBot` with the socket
taken out, and `simulate.nim`, which ties the three together.

One qualifier on the middle row, because it is the one place this stopped
being byte-for-byte the hosted wire. The observation is still built by the
server's own emitters, from the server's own per-viewer state — but the
sprite definitions a policy would have **dropped on arrival** are no longer
sent, so the packet is shorter than the socket's. That is a claim about the
reader, not a guess about it: `simulate.nim` hands the engine the policy's
own `labelkind.classify`, and a definition it suppresses is one
`refreshFrame` already discards for the kind being `lkOther`. The frame index
the policy actually decides from is identical, which is what the six-seed
`gameHash` comparison tests and what the flat-zero A/B across the change
showed. `engine-patches/perf.patch` carries the argument in full, and the
recipe for re-checking the vocabulary after a pin move.

**Four differences from a hosted episode.** Each one is a reason a local number
can disagree with a league number, and none of them is fixable from here:

1. **The policy never misses a frame.** The hosted server paces by readiness or
   by timeout and steps on without you; here every seat is asked for a mask and
   the game waits. A change that costs CPU shows up as slower wall clock
   locally and as *dropped frames* hosted, and only the second one costs games.
   This is the difference most likely to flatter a change that is expensive to
   compute, and the simulator cannot see it at all.
2. **`frameAdvance` is therefore always 1.** Hosted it exceeds 1 when the
   policy falls behind and `receiveLatestFrame` drains a backlog, or when a
   frame is big enough that the server chunks it across websocket messages and
   the client counts the chunks. Neither can happen in process. (The league
   runs `speed: 1`, one sim step per frame, so that is not a third cause — a
   fast-mode server at speed 16 would be.)
3. **No grader, no commissioner, no Elo.** The simulator reports what the
   engine reports — kills, deaths, captures, the win, the ending. League score
   is a different function of those, computed somewhere else.
4. **The field is the other build.** A local head-to-head says which of two
   builds beats the other. "Is this stronger against the league" is a different
   question with a different opponent set, and only the hosted run in
   `../README.md` asks it. Nothing here is evidence about the standing field,
   however many episodes you buy.

## One calibration point against a hosted number

`../README.md` records a hosted mirror — the same policy on both sides — in
which **RED won 70.9% of 79 episodes**. That is the only local-versus-hosted
comparison currently available, so it is worth having run it:

| | red win rate | 95% CI |
|---|---|---|
| hosted, 79 episodes | 70.9% | — |
| this simulator, 32 episodes (seeds 5000-5031) | 84.4% | [68.2%, 93.1%] |

The side advantage reproduces, at the same order of magnitude, which is the
part that matters — it is the bias every head-to-head here has to cancel, and
it is why one direction can never settle a change. The point estimate is
higher, and n=32 cannot say whether that is real: the interval contains the
hosted figure, but only just, and on decisive episodes alone (27 of 31, 87.1%)
it stops containing it. Do not read this as the simulator being calibrated to
the league. The two runs are not the same experiment — different engine
version, different seeds, two builds hosted against one build here, and
hosted episodes drop frames where these never do.

Treat it as: **the red bias is at least as strong here as it is hosted.** Same
run, for reference:

```
endings : capture 14  timeout 1  wipe 17
median length 2223 ticks, accuracy 0.649, 1354 kills over 32 episodes
```

## The other league: Paintbot

The same policy is entered in a second league on the same engine commit, and
`analysis/paintbot.md` has the record. Four things about it are structural
rather than cosmetic, and each one broke something this directory used to
assume:

| Paintbot | what it broke here |
|---|---|
| four teams — red, blue, green, yellow | the record called every non-red seat `blue` |
| four ENTRANT policies per episode | `--assign` held two builds |
| pot scoring | no per-team score in the record at all |
| generated terrain, and 32 seats on `4ffa8` | nothing, but it is a much bigger board than the arena, and paid for it — see "What a Paintbot board costs" |

A note on the pot, because it is easy to assume otherwise: it is **not
zero-sum on four teams**. `finishGame` pays the winner the whole pot
(`teamCount`) and each loser `-(teamCount div loserTeams)`, which on four
teams is `+4 / -1 / -1 / -1` and leaves `+1` on the table; on two it is
`+2 / -2` and does balance. A clock draw pays `-1` to everybody, which
balances on neither.

`sim/paintbot_{2v2,4ffa,4ffa8,default}.json` are the four hosted variants'
own `game_config`s, extracted the same way `league_config.json` was.

**The score comes from the engine, never from arithmetic here.**
`finishGame` (`src/ctf/sim.nim`) pays the whole pot to the winning team and
`-(teams div loserTeams)` to each loser, or `TimeoutReward` to everybody on a
clock draw, and writes the result to every seat's reward account. The record
reports that number per seat and per team. A config that changed `scoring`
would be followed automatically, because nothing here knows what the rule is.

**One episode can now end three ways rather than two.** A capture on a
four-team board eliminates ONE team and play continues, so an episode can
carry captures and still end by wipe or on the clock. The record's `ending`
is derived from the finishing tick, not from a capture count.

### The rotation, and why one mirror is not enough

`sim/README.md` records the arena's red bias at 70-84%. Colour advantage on a
four-team board is the same class of confound, and the two-team answer — run
the seed both ways — does not generalize, because there are four ways round
and not two. `paint` runs every seed once per entrant position, sliding the
lineup by one each step, so every build sits on every colour exactly as often
as every other build. The report prints that as a `colour seats` line per
build and flags it if it ever fails to hold.

A seed whose rotation is incomplete is dropped WHOLE, and loudly. Pooling
three of four steps is exactly the imbalance the rotation exists to remove.

Two builds is the default lineup (`abbb`: one candidate against a field of
three controls, which is the league's own shape). `--build-c`/`--build-d`
seat two more distinct policies; `build.sh` compiles up to four trees, at
+17% cold and +11% warm, and a two-tree build is byte-identical to what it
always was.

### Two things it cannot do yet, and one it cannot do at all

- **A cyclic rotation cancels colour, not PARTNERS.** On the 2v2 shape two
  entrants split each team, and entrant positions `k` and `k+2` always share
  one — a cyclic shift moves both, so four distinct builds pair the same two
  together in every step. Harmless on the default `abbb` lineup, where there
  is only one other build to be teamed with; with four distinct builds the
  report prints a `teammates` line and marks it `UNBALANCED`, which is
  reporting the confound rather than removing it.
- **On `4ffa`/`4ffa8` the score channel used to carry no signal whatsoever.**
  Green and yellow seats were statues (`analysis/paintbot.md`), so no
  four-team episode resolved: 100 of 100 local episodes timed out and paid
  every team `-1`. An A/A gap of exactly zero there is the board never
  resolving, not the builds being level, and the report says so in those
  words. **The four-team port retired that**, and this paragraph is kept
  because the report's warning still is: four-team boards now do resolve
  (seed 900001 on `4ffa` ends `wipe yellow` at 4300 ticks), but plenty still
  time out, so a zero with no variance behind it means the same thing it
  always did. Nobody has re-run the 100 to replace the figure above.
- **Nothing here is evidence about the standing Paintbot field**, for the
  same reason as difference 4 above: the opponent is the other build.

### What a Paintbot board costs

A Paintbot episode is not an arena episode with different rules on it; it is
a much bigger board, and almost everything here scales with board area. The
variants draw a FIXED size each — the size class is a roll of the generator,
but it is rolled once for a config and not once per seed (see below), so it
is a property of the `--config` and worth knowing:

| config | board | fov cells | seats | tick cap |
|---|---|--:|--:|--:|
| `league_config` / `paintbot_default` | 1235x659 arena | 12,865 | 16 | 5000 |
| `paintbot_2v2` | 1606x857 generated | 21,708 | 16 | 5000 |
| `paintbot_4ffa` | 1248x1248 generated | 24,336 | 16 | 5000 |
| `paintbot_4ffa8` | 2496x2496 generated | 97,344 | **32** | **7500** |

**The terrain is drawn from the CONFIG, not from the seed.** `config.update`
resolves the generated map and pins it into `config.mapSpec`, and
`runEpisode` sets the episode's seed afterwards precisely so a config seed
cannot clobber it — so every seed of one `--config` plays the same ground,
and the seed varies the spawns and every other roll on top of it. That is
upstream's design (it is what makes a replay carry exact geometry) rather
than this tool's, and it is not a performance decision, but read a Paintbot
number knowing it: **seeds vary the game on one board, and `--config` is what
varies the board.**

It is also where the setup cost was hiding. `update` is not the cheap JSON
read its name suggests — it runs the generator and the validator — and
`runEpisode` called it per episode, regenerating identical terrain every
time. It is parsed once per process now (`parseConfig`), and nothing about
what runs changed. That is invisible to a fluffy profile, because `update`
carries no `{.measure.}` mark and the engine's own `MapBake` cache starts one
call later; callgrind found it, which is the lesson under "Profiling"
happening again.

Marginal setup for the second and later episode of one worker, measured at
`--tick-cap 1`:

| | before | after |
|---|--:|--:|
| `4ffa` | ~0.34 s | ~0.15 s |
| `4ffa8` | ~3.4 s | ~0.8 s |
| `2v2` | ~0.21 s | ~0.16 s |

## Setup

```bash
sim/bootstrap.sh                       # nim, deps, engine checkout at engine.pin
python3 scripts/local_sim.py selfcheck # prove the wiring before trusting it
```

`bootstrap.sh` writes only `~/.nimby` and `.engine/`, both gitignored and both
re-fetchable. Point `CTF_ENGINE_DIR` at a checkout you already have and it will
use that one instead, and will say so loudly if that checkout is not at the
pinned commit.

## Running it

```bash
# two builds, both directions, same seeds
python3 scripts/local_sim.py h2h HEAD HEAD~1 -n 40

# one build in all sixteen seats: measures the GAME, not the build
python3 scripts/local_sim.py run bot/baseline -n 20

# re-pool a saved run without re-running it
python3 scripts/local_sim.py pool episodes.jsonl --name-a cand --name-b base

# a Paintbot board: four entrants, every build on every colour
python3 scripts/local_sim.py paint HEAD HEAD~1 \
  --config sim/paintbot_4ffa.json -n 20
```

A side is a git ref or a path. Refs are materialized with `git archive`, which
reads the ref and never the index, so a dirty working tree cannot leak into a
measurement of a committed ref — and an uncommitted change is measured only if
you point at `bot/baseline` on purpose.

## Reading the output

`../README.md`'s seven rules for whether a number means anything hold here,
with one retired and one strengthened:

- **Rule 1 — only compare builds that ran at the same time — is retired.**
  It exists because the league drifts. Nothing here drifts: the engine is
  pinned in `engine.pin`, the opponent is the other build, and a seed
  reproduces an episode to the hash. This is the entire reason the local loop
  is worth having.
- **Rule 2 — both directions, always — gets stricter.** The two directions run
  the *same seed*, so a pair differs only in which build held which side.
  `local_sim.py` bootstraps over seed pairs rather than over loose episodes,
  because the two halves of a pair share a terrain draw and a spawn layout and
  are not independent samples.
- **Rules 3 through 7 are unchanged.** In particular rule 6: a 95% CI that
  crosses zero is not a small effect, it is an absent one. Cheap episodes make
  it tempting to keep looking until an interval clears; that is how you find
  effects that are not there.

Every skipped episode is printed with its error. Sample loss stays visible.

## What it costs

Measured end to end on four cores — `scripts/local_sim.py h2h`, 40 episodes
(20 seeds run both ways), **compile included**, which is how a research loop
actually experiences it:

| | wall clock | episodes/hour |
|---|---|---|
| the previous revision of this tree | 1 m 44 s | ~1,380 |
| this one, cold build | 1 m 15 s | ~1,920 |
| this one, warm build (the loop's steady state) | 57 s | ~2,540 |

**1.84x end to end**, and the two runs produced all 40 episodes with
identical `gameHash`es — the same measurement, faster. A warm build is the
normal case: `build.sh` keeps its nimcache, so only what you edited
recompiles.

Which puts a real head-to-head at roughly:

| seeds | episodes | wall clock, default workers, warm build |
|---|---|---|
| 20 | 40 | ~1 min |
| 40 | 80 | ~1.6 min |
| 80 | 160 | ~2.9 min |

So the n=80 `../README.md` calls the floor for a marginal call is a minute
and a half, and the n=160 it wants when an interval nearly touches zero is
under three — which is the point of the exercise: at these prices the thing
that limits an auto-research loop is deciding what to try, not waiting for
it. Episode length moves that more than anything else — the run above ranged
2088 to 5000 ticks over its 132,114 — and a wipe gets cheaper as it goes,
because dead players cost neither a decision nor much of an observation.

### What a `paint` run costs

The seventh pass measured the same way on Paintbot boards, which are the
expensive ones. Four cores, `paint`'s own rotation and job list, episodes
only (the compile is unchanged by that pass), 20 episodes for `4ffa`/`2v2`
and 8 for `4ffa8`:

| | before | after | |
|---|--:|--:|--:|
| `4ffa`, full episodes | 1,354 ep/h | 1,906 ep/h | **1.41x** |
| `2v2`, full episodes | 1,472 ep/h | 1,898 ep/h | **1.29x** |
| `4ffa8`, 1200 ticks an episode | 186 ep/h | 314 ep/h | **1.69x** |

Note the shape of that: `4ffa8` gains the most because most of what came off
it was per-EPISODE rather than per-tick, which is the fifth pass's lesson
again. And read the absolute numbers as what they are — a `4ffa8` episode is
a 2496x2496 board with 32 seats and a 7500-tick cap, so it costs roughly an
order of magnitude more than an arena episode and no pass is going to change
that.

The eighth pass is per-TICK, so it shows up in both places and by different
amounts. Three seeds run to their natural end, one process, no compile, arms
alternated and the minimum of four rounds taken:

| full episodes, ONE process | before | after | |
|---|--:|--:|--:|
| `paintbot_2v2` | 1.6277 ms/tick | 1.1427 | **1.424x** |
| `paintbot_4ffa8` (600 ticks) | 14.1580 ms/tick | 10.8520 | **1.305x** |
| `paintbot_4ffa` | 0.8932 ms/tick | 0.6901 | **1.294x** |
| `league_config` | 0.8250 ms/tick | 0.6880 | **1.199x** |

`2v2` gains most because the shadowcast's reach (197 cells) badly outruns its
short axis (108), so bounding the row walk to the board saves most of a row
there; `4ffa` is 156 square and saves less.

End to end through the driver, which is what a research loop feels —
`paint -n 12` on `4ffa` (48 episodes over the four-way rotation), four
workers, **warm build included**, both arms run twice and the minimum taken:

| | wall clock | episodes/hour |
|---|---|---|
| the previous revision of this tree | 63.0 s | ~2,740 |
| this one | 54.0 s | ~3,200 |

**1.17x end to end**, with all 48 episodes producing identical `gameHash`es
across the two stacks — the same measurement, faster. It is below what the
same episodes give one at a time for two reasons worth knowing before quoting
either: the warm build is ~6.4 s of both numbers and the pass does not touch
it, and four workers on a four-core box contend for what is left. Episodes
only, it is 1.19x. (That run predates the last round of the pass, so it
understates it; the per-process table above is the current one.)

Three things paid for it, in the order they paid: the driver runs one worker
per CORE rather than per core-minus-one (1.35-1.40x on its own — the reserved
core was doing nothing, since a driver waits on the pool; measured over the
same job list and the same batch shape, so the worker count is the only
variable), the config is parsed once per process instead of once per episode
(see "What a Paintbot board costs"), and the engine stopped rasterizing a
shout bubble for a send it then deduped away
(`engine-patches/perf.patch`, seventh pass).

A fourth thing is not speed but is what lets the first one be safe: the
engine's shadowcast cache is now bounded. Unbounded it grew ~0.19 MB a tick
on `4ffa8` — 707 MB by tick 2000 and ~1.6 GB by that variant's 7500-tick cap,
**per worker**, which is per core the moment the default above went up. It is
capped in bytes now: 707 → 454 MB at tick 2000, wall clock unchanged
(29.74 → 29.53 s). `FovShadowCacheBytes` in the patch is the whole argument,
including why full drops the table rather than evicting.

Two things to hold in mind when reading that. The budget is **per process**,
so a driver's total is it times the worker count — half a gigabyte a worker
on `4ffa8` is the number to budget before raising `CTF_SIM_WORKERS` on a
many-core box, and `local_sim.py`'s `default_workers` says so where somebody
raising it will look. And the cap is set well clear of what a match needs
rather than at the floor (~3,900 entries on the arena's 12,865-cell grid,
~517 on `4ffa8`); whether the arena ever reaches it over a long episode has
not been measured, and does not need to be, because reaching it costs a burst
of recomputation and never an episode.

Three things paid for most of that and none of them is per-tick, so none
shows up in a `ms per tick` reading. **Setup was a fifth of an episode**: the
engine's map bake and each seat's nav-grid build ran per episode and per
seat, for answers that do not vary. **The driver spent it every time**, one
process per episode; `local_sim.py` now hands each worker a batch of seeds
and the simulator caches the map-shaped work across them (`BATCH_MAX`, and
the batches shrink as the queue drains so a long episode cannot strand a core
at the end). **And every run recompiled the engine**, which had not changed —
26 s of a 75 s head-to-head, for a loop that edits one policy file at a time.
`selfcheck` pins the only thing that could go wrong with either cache: a
batched episode must hash the same as the same episode run alone, and a warm
build must be the binary a cold one would have given.

**Quote these against each other, not against the table above.** Every figure
here is one machine's, and the previous revision of this file recorded 19 ms
per tick for the same command on a faster one. What travels between machines
is the ratio, so a claim about throughput needs the before and the after
measured on the same box, minutes apart, with nothing else running — the
readings on a loaded four-core box came in 25% slow and would have hidden a
change worth having.

**And ALTERNATE the arms, round by round.** "Minutes apart" is not enough on
a box this noisy: the eighth pass measured one hunk at 3% SLOWER and then, in
a second run of the same two binaries, at 6% faster. Running a whole arm and
then the whole other arm reads the box's drift as a result. Run one round of
each, repeat, take the minimum per arm — and have the harness refuse to print
a ratio unless every arm produced the same `gameHash` on every seed, because
the cheapest way to look fast is to stop playing the same episode. For an
effect smaller than that swing, do not use the stopwatch at all: callgrind is
deterministic, and an instruction count says whether a change helped before
the stopwatch says how much. (It is not the last word — the same pass found a
hunk callgrind preferred and the stopwatch rejected. See the open-square index
under "Where a tick goes now".)

### Where a tick goes now

Two profilers, and **the second one is where the last pass came from.**
`fluffy` reads the `{.measure.}` marks (see "Profiling" below) and so shows
only what somebody thought to mark; `callgrind` counts every instruction and
does not care. Read them together, and re-read the second one after any pass
— what it found is that the biggest single block in the engine's share of a
tick was a proc with no mark on it at all.

Under callgrind, over a whole episode (seed 5000, 4000 ticks, setup measured
separately and subtracted — it is 7.5 of the 27.0 billion instructions, and
batching amortizes most of that across a worker's seeds, leaving 19.5 billion
of per-tick work):

| share of a tick | what |
|---|---|
| 16% | `castFovOctant` — the shadowcast, recursive, so it lands in two entries |
| 16% | the policy's raycasts (`pixelRayClear` 10%, `rayClearCoarse` 6%) |
| 5% | the cost field (`driveField`) |
| 5% | `setLen` — growing the packet, charged to the module it was instantiated in |
| 4% | `canOccupy` — the movement rules' collision probe |
| 3% | the diamond restamp — **20% before the sixth pass** |
| 2% | the policy's packet decode (`refreshFrame`) |
| the rest | `step`'s own rules, the wire encode, `hypot` |

**The shadowcast and the raycasts ARE the decisions**, so the number of
SAMPLES they take is at its floor: the exact-arithmetic transformations that
were free elsewhere run out right there — `sqrt(d2) <= R` and `d2 <= R*R` can
disagree at an ulp boundary, and one flipped cell is a different episode.
That was read for several passes as the COST being at its floor too, and the
eighth pass is where that stopped being true: **the count of samples is
fixed, what one costs is not.** It took each of the two dearest loops
to roughly a third of its instructions, which was worth more than any single
mechanism since the fifth pass. Its section below says how, and none of it
restates a comparison in a cheaper form.

That table is the ARENA. The seventh pass profiled a **Paintbot** board the
same way — `4ffa`, seed 900001, callgrind over a steady window (ticks 800 to
1200, so the one-time rasters that fill a viewer's def cache are already
paid, which a window at tick 0 is not: read one there and the self marker
looks like 6% of a tick when over an episode it is under 1%):

| share of a tick | what |
|---|---|
| 20% | `castFovOctant` — the shadowcast, in two entries |
| 23% | the policy's raycasts (`pixelRayClear` 12%, `rayClearCoarse` 9%, `gridRayClear` 1%) |
| 14% | the cost field (`driveField`) |
| **15%** | **the shout bubble** — the raster, its per-pixel writes and its glyph blitting. Now zero on this path; see the seventh pass in `engine-patches/perf.patch` |
| 2% | `canOccupy` |
| 2% | `hypot` |
| the rest | `step`'s own rules, the packet decode, the wire encode |

Two things to take from reading it next to the arena's. The decisions
(shadowcast, raycasts, cost field) are a LARGER share here and are the same
code — a bigger board makes rays longer and the grid wider, and none of THAT
is recoverable. And the one big non-decision item was a cosmetic raster that
the arena profile had never made big enough to notice, which is the fifth
pass's lesson arriving on a board that shouts more.

The eighth pass re-read that window on the same board and the same seed, on
one box (`4ffa`, seed 900001, callgrind at `--tick-cap 1200` minus
`--tick-cap 800`, so setup subtracts out). Its "before" is the tree AFTER the
seventh pass, so the shout bubble is already gone and the shares do not line
up with the table above — read the two tables as separate measurements, which
is the same rule the pass table further down states. A steady tick went
**16.4 M instructions to 10.3 M**:

| share of a tick | before | after | G Ir over the window |
|---|--:|--:|---|
| `pixelRayClear` | 29.6% | 16.1% | 1.94 → 0.67 |
| `castFovOctant` (two entries) | 19.3% | 16.4% | 1.27 → 0.68 |
| `driveField` | 9.9% | 12.0% | 0.65 → 0.49 |
| `rayClearCoarse` | 7.9% | 8.3% | 0.52 → 0.34 |
| `setLen` | 4.1% | 6.6% | 0.27, unchanged |
| `canOccupy` | 2.1% | 3.3% | 0.14, unchanged |
| `hypot` | 2.2% | 2.1% | 0.14 → 0.09 |
| `gridRayClear` | 2.1% | 3.0% | 0.14 → 0.12 |

Read the SHARES as what they are: everything that did not move gained share
because the tick shrank. The G Ir column is the one that says what happened.
Every row that moved is the same mechanism found again — an index or a bounds
test recomputed per sample that the caller already knew the answer to. The
pass is written up hunk by hunk in `engine-patches/perf.patch` (the engine's
share) and in the procs themselves in `bot/baseline/grid.nim`,
`navgrid.nim` and `geometry.nim` (the policy's).

One idea from it that did NOT pay, written down so it is not tried twice: an
index of the 8x8 squares of the walkability mask whose every pixel is
walkable, so a pixel ray inside one could skip every sample that provably
stays in it. It is correct, it cuts instructions, and it is SLOWER on the
stopwatch — a square is worth three or four samples against a per-square
lookup plus either two integer divisions to restate the recurrence or the
same steps run without the load. Alternated five times a side at `--tick-cap
1500`: 8.99 s restated / 9.04 s run / **8.67 s with no index at all** on
`4ffa`, and 10.60 / 10.69 / **9.72** on `2v2`. Callgrind preferred the
divisions. This is the caution under "Profiling" arriving in the other
direction: take the ranking from callgrind and the verdict from the
stopwatch, never both from the same tool.

The **ninth pass** took the profile the eighth left — three loops taking
exactly the samples the decisions need — and went after what sat AROUND
them: allocation, zeroing, and per-frame strings. Its finder was the same
pair of tools in the same order. The fluffy trace showed
`buildSpriteProtocolPlayerUpdates` holding ~8% of a `4ffa` tick in SELF time
with nothing marked inside it to blame, and callgrind then named what fluffy
cannot see: `setLen` at 6.5% of the steady window, allocator traffic at
3.3%, `memset` at 2.0%, and ~290k `$int` calls per 1200 ticks building HUD
label strings — five shapes of one defect, per-frame work whose answer was
already known.

- **The shadowcast's cache misses paid `setLen`'s grow loop.** A fresh
  cache entry's shadow seq went 0 → 24 kB through element-by-element
  initialization — ~124k instructions a cast, and a diamond board recasts
  several times a tick. `newSeq` takes the allocator's zeroed payload
  instead; `setLen` was 6.5% of the window and no longer appears in it.
- **`canOccupy` range-checked every pixel of a box one test proves.** The
  movement probe asked `isWalkable` per pixel — four comparisons and a seq
  check, 169 times a call. With the box proved in-bounds up front (which is
  everywhere a soldier can actually stand), each row is two overlapping
  8-byte word compares — a bool is exactly 0 or 1, the fact
  `refreshFovCells` already counts wall pixels with. 3.3% → 0.2%.
- **Labels that are pure functions of small keys were built per viewer per
  frame.** The scoreboard's chips rebuild only when a team's kill or death
  total moves; the hp-bar, identity-badge and own-aim labels are built once
  per key per process, and the own-aim marker's constant 1×1 pixel argument
  is shared. The shot-impact ring — one constant def rebuilt with a sqrt
  per pixel, per shot per viewer per frame — took the eighth pass's
  argument gate, and the self-outline, spray-puff and blast rasters joined
  the third pass's process-wide raster memos. All of these are engine
  hunks (`engine-patches/perf.patch`), and unlike the fifth pass's hook
  they change no wire byte even on a hosted server.
- **The packet regrew from empty every frame,** re-copying itself through
  the doubling-realloc chain per viewer; it now starts at last frame's byte
  count (one field on the viewer state), and `addBoardObject` stops
  zero-filling the 12 bytes it immediately stores (`setLenUninit`).
- **The policy's share is the same shape in three places** (this tree, not
  the patch): `seedField`'s −1 fill and `rebuildExposure`'s copy of the
  static field run through proved pointers — a fill the compiler widens and
  a plain memcpy where each cell paid range checks — `markExposedFrom`'s
  ~9k-cell box scan reads its two grids unchecked under the clamps that
  prove the index, and `NavBuckets` is 32: any count above `NavMaxStep`
  leaves each bucket holding at most one live level, so the count is not a
  tuning knob and the per-push `mod` becomes a mask.

Stopwatch, the eighth pass's own protocol — arms alternated round by round,
the minimum of four rounds, the harness refusing a ratio unless every seed
hashes identically across arms; three seeds per config through ONE process,
no compile, `4ffa8` capped at 600 ticks:

| full episodes, ONE process | before | after | |
|---|--:|--:|--:|
| `paintbot_4ffa` | 0.7288 ms/tick | 0.6097 | **1.195x** |
| `league_config` | 0.7451 ms/tick | 0.6310 | **1.181x** |
| `paintbot_2v2` | 1.1356 ms/tick | 1.0120 | **1.122x** |
| `paintbot_4ffa8` (600 ticks) | 11.6796 ms/tick | 10.7839 | **1.083x** |

Under callgrind the same steady `4ffa` window went **4.13 G to 3.47 G**
instructions (10.3 M to 8.7 M a tick) with the decision loops untouched:
their shares rose, their G Ir did not move, and what shrank is everything
that was not one.

One idea from this pass that did not pay, same ledger as the eighth's:
folding walkability + exposure into one byte per cell for `driveField`'s
inner loop. It is exact, and it is a wash — the load it saves per neighbour
comes back as a widening per relaxation (callgrind: `driveField` +16 M,
`rebuildExposure` −20 M over the window), and the alternated stopwatch
cannot see it either way — so the extra grid and its freshness invariant
were dropped rather than carried for nothing.

Verified the way every pass is, plus the policy-half check the eighth
introduced: every config's episodes hash identically before and after (the
six league seeds, the Paintbot seeds, a mixed lineup, and a full-length
7500-tick `4ffa8` episode); a binary holding the pre-change tree as side a
and the post-change tree as side b produced identical hashes all-a, all-b
and alternating; `selfcheck` passes; the three audits (`-d:navFieldAudit`,
`-d:rayAudit`, `-d:fovSpanAudit`) hash the same as a plain build;
`stock_compare.sh` is identical on every config; and the engine's own
suite still passes on the patched engine.

Five of the nine passes have a row here, each measured back to back on one
idle machine over the same six seeds (5000-5005), one worker and no compile —
the rows are from different machines (and the tree the seeds run has changed
between passes), so read each ratio and never the columns across rows. The
fourth and seventh are missing because neither moved this number (see below),
the eighth because the arena stopped being where the work was, and the ninth
because its numbers are the per-config table above:

| ms per tick, ONE worker, no compile | before | after |
|---|---|---|
| first pass (policy: labels, presence, searches) | 20.1 | 9.1 |
| second pass (engine patches + the nav field) | 14.4 | 4.3 |
| third pass (shared per-connection work + wire encode) | 2.39 | 1.07 |
| fifth pass (headless observation + per-episode setup) | 1.27 | 0.78 |
| sixth pass (lazy fog grid, field horizon, diamond stamps) | 1.596 | 0.954 |

The **eighth**'s numbers are in "What a `paint` run costs" above, measured on
every config the repo carries. Two things about HOW they were measured belong
here, because the rows above predate both. The arms are ALTERNATED round
by round rather than run back to back, and the minimum of four rounds taken —
a whole run of one arm followed by a whole run of the other reads this box's
drift as a result. And the harness refuses to print a ratio unless every arm
produced the same `gameHash` on every seed, because a faster run that is not
the same episode is not a measurement.

(The fourth pass was the GV30 rebase, which held the ratio rather than
improving it; `engine-patches/perf.patch` has its story, and so does the
GV35 rebase after it, which likewise bought nothing and only kept what was
there. The seventh was aimed at the Paintbot boards, so the arena seeds do
not show it either — "What a `paint` run costs" is where it landed. The
sixth pass's row is from a slower box than the fifth's, which is why its
"before" is above the fifth's "after" — the rows are ratios, never a
column.) Against the pinned engine with **no patch at all** — which is also
the check that the simulator still builds and runs on a stock
`CTF_ENGINE_DIR` checkout — the whole stack is **4.748 → 0.463 ms/tick**
on those six seeds at the GV35 pin (23233 game ticks, one worker, no
compile, runs alternated on an idle 3-core box), with all six `gameHash`es
identical. Re-run that one after any change here: it is the statement that
this reproduces the unmodified upstream engine exactly, which is the only
reason it is allowed to be fast. The patched engine also passes
coworld-ctf's own suite (`nim c -r -d:release tests/tests.nim` from the
`.engine` root, 401 checks at this pin) — worth running when a change
touches a path the headless hook switches off, because a six-seed
`gameHash` run never takes those.

The fifth pass was
the first to move the number a research loop actually feels, because most of
what it removed was NOT per-tick: end to end through
`scripts/local_sim.py`, four cores, 40 episodes both directions, **2770 →
4460 episodes/hour** on its box. (The sixth did it again, and for the same
reason — see "What it costs" above, where the compile finally counts.)

Three mechanisms, in the order they paid:

- **The engine drew a game nobody was watching.** The policy reads a closed
  vocabulary of sprite labels and drops the rest of a frame before looking at
  it (`labelkind.nim`), and it never decodes sprite pixels at all except the
  walkability map — while `addSpriteChanged` has always deduped on metadata
  and never on pixel content, so nothing downstream of a raster depended on
  what was in it. The fog overlay, the spinning stone, the arena raster
  itself and every cosmetic sprite were being rasterized, upscaled,
  compressed and shipped for a reader that discarded them on arrival.
  `simulate.nim` now hands the engine the policy's own `classify` as a
  predicate. Deriving it from the policy rather than from a list in the patch
  is the whole point: a policy that starts reading a family turns that
  family's emission back on by itself.

  The predicate governs what is SENT and never which objects are PLACED —
  an emitter that dropped whole items would renumber every later item in its
  object pool, which no `gameHash` run can catch while a family is uniformly
  unread and which would strand a static obstacle mid-episode the first time
  one is not. `addFogRuns` is the single exception, and earns it: it emits
  one label, so its skip cannot be partial. The patch header carries the full
  argument.
- **Each episode baked the same map.** `initSimServer` spent ~430 ms on the
  art bake and three per-pixel passes over the board — a pure function of the
  resolved map, paid once per episode for one hand-authored arena. Cached on
  that map by value, marginal setup per episode fell ~1.16 s → ~0.05 s, which
  is what makes batching seeds into one worker worth doing.
- **Sixteen seats built the same nav grid.** `scanPost` is a pure function of
  the walkability mask and its two arguments; an episode asked it 18 times
  (every seat's `findEnemyPosts`, plus the two overwatch seats' `pickPost`)
  and got two distinct answers, at ~35 ms a scan. That alone was half of
  every episode's setup. The eroded grid, the cover cells and the static
  exposure field cache the same way, keyed on a serial that changes exactly
  when the decoded mask does.

The single-worker figure is not the same measurement as the `10 ms per tick`
above — that one is wall clock across the default worker count, compile
included, and predates the second and third passes, so the episode-cost
table it anchors now overstates a run several times over on a comparable
box. Re-measure locally before budgeting a long head-to-head. What the
first pass fixed, in the order it mattered:

- **Labels were strings in the frame loop.** ~28 label queries per decision,
  each sweeping a 22k-slot object table and comparing a string it had just
  built; the iterating half copied every visible object's label string four
  times a frame, which alone was 14% of the simulator. Labels are now resolved
  to an enum once per sprite definition (`baseline/labelkind.nim`) and a
  frame's objects are grouped by kind, so a query reads only what can match.
- **Presence was a flag in a sparse table.** ~180 objects live across ~22k
  ids, so finding them meant reading 22k padded structs; it is a bitmap now.
- **Two searches recomputed settled answers.** The path field's frontier was a
  binary heap where four small integer step costs allow cyclic buckets, the
  exposure field re-derived the enemy post and respawn ground on every repath
  though neither moves, and the sonar clock calibration re-tested all 901
  candidate offsets against every ring when an offset that misses once is out
  for good.
- **Nim does not inline across modules unaided**, so every raycast sample paid
  a call to add two floats.

Each was verified the way this tool is meant to verify: identical `gameHash`
on every seed, and `selfcheck` still passing. A change that is only meant to
be faster and is not bit-identical is a behaviour change you did not intend.

The second pass moved the engine side, where the first one stopped. Profiled
with fluffy, the pattern was one thing five ways: **per-frame work whose
output the packet dedup then discarded** — rasterizing the viewer's own
outlined self marker every frame (~41% of a tick), copying the spinning
diamond's cached pixels out of a cache that already held them (~14%),
linearly scanning the per-viewer sprite-def cache from every emitter, an
object-delete sweep quadratic in the fog-run count, and re-running the fog
shadowcast for a viewer that had only turned. Those are engine fixes, but
they live here, as `engine-patches/perf.patch`: `bootstrap.sh` applies them
to the managed `.engine` checkout, the six-seed gameHash comparison and
`selfcheck` hold with and without them, and a moved pin that no longer takes
the patch fails the bootstrap loudly instead of quietly measuring an engine
the patch does not describe. The policy's share of the second pass went to
the nav cost field, with the same shape of fix: a repath whose threat picture
has not changed reuses the exposure field and the settled Dijkstra instead of
recomputing them (`rebuildExposure` returns whether anything moved), the
sidestep searches score a candidate cell before buying its raycasts, and a
pixel ray now carries its division incrementally instead of paying two `div`s
per sample.

The third pass found the remaining cost hiding in two places fluffy's totals
only implicate indirectly. First, **per-connection work whose output is
identical for every connection**: each of the sixteen viewers re-decoded the
same pickup PNGs from disk (~10 ms per family, surfacing as inexplicable
spikes in whichever emitter first saw the sprite), re-built the same ~58 ms
init snapshot (map raster + compression, flag sprites, the soldier pool),
and re-rasterized the same cosmetic sprites — about a second of every
episode spent computing sixteen copies of one answer. Those are all pure
functions now cached once per process or per episode
(`engine-patches/perf.patch` has the list). Second, **per-object wire
encoding**: `addObject` is six cross-module calls with a `setLen` each, and
the fog overlay alone re-encoded ~150 unchanged run objects per viewer per
frame — the object block is now cached beside the run list and re-appended
as one `memcpy`, `addBoardObject` encodes in place, and the fog cone walks
the shadowcast's lit-cell list instead of sweeping all ~12.9k grid cells.
The policy's share went to the packet decoder (`baseline/protocols.nim`):
`parseSpritePacket` copied the packet twice and materialized every message —
a label string and a pixels seq per sprite — for a loop that read each field
once; it now decodes the wire bytes in place, and the walkability sprite,
byte-identical for all sixteen seats, is decompressed once and copied
fifteen times. `sim/host.nim` hands the policy raw bytes instead of a blob
string (a `when declared` fallback keeps pre-change trees buildable, so
`h2h` across this revision still works). Same verification as ever:
identical `gameHash` on the six seeds, `selfcheck` passing, and a mixed
old-tree/new-tree episode reproducing the same hash. Because the decoder's
bounds checks used to be library code and are now this repository's, they
carry their own test: `sim/test_decoder.sh` (a `selfcheck` step) decodes a
packet of every message kind through both public entries, then sweeps every
truncation point — a cut at any non-boundary byte must fail the packet — and
pins that the shared walkability cache never leaks one client's mask to a
client sent different bytes.

The sixth pass took the advice above and went looking for mechanisms rather
than loops. Four of them, in the order they paid:

- **The fog built a whole grid to answer questions about forty cells.**
  `refreshPlayerFov` materialized a 12.9k-cell visibility grid per viewer per
  frame — a copy of the cached shadowcast, then a cone test on every lit cell
  in it. The only consumer that wants a GRID is the fog overlay, and the
  fifth pass had already switched that off; everything else asks
  `fovVisibleAt` about a POINT, a few dozen times a frame. The cone is now a
  handful of constants on the viewer and one shared expression (`keeps`), the
  grid is built by `ensureFovVisible` for the overlay and by nothing else,
  and the lit-cell list only the grid pass needs is built on demand too. Off
  the observation hook the overlay runs every frame, so a hosted server
  builds the grid exactly when it always did, out of the same expression.
- **The spinning stone was rasterized for angles it had already been at.**
  This one was invisible to fluffy and came out of callgrind: the diamond
  restamp — ~4k pixels of trigonometry per window, then ~640 fog cells
  re-derived from 41k pixel reads, every four ticks — was 20% of a tick's
  instructions and carried no `{.measure.}` mark. A diamond only ever visits
  `DiamondSpinFrames` angles, so the masks a window writes are cached per
  (window, frame vector) and a restamp is now `h` pairs of `memcpy`; the fog
  cell rescan counts its wall pixels eight at a time out of a `uint64`. 4.75
  billion instructions an episode down to 0.50 — though only 5% of wall
  clock, which is the lesson under "Profiling" about what callgrind counts.
- **The cost field settled the whole map to route one seat.** The policy's
  Dijkstra drained its frontier to the map edge; `navSteer` reads it by
  descending downhill from the seat's own cell, so every cell further from
  the goal than the seat is was settled for nobody. It stops when the seat
  comes off the frontier now — and what it leaves is a PAUSED Dijkstra, not a
  truncated one, so a later tick whose seat has walked past the horizon
  resumes instead of restarting. Extending is deliberately separate from
  repathing: a repath also rebuilds exposure off the current threat list, so
  repathing early because the seat outwalked its horizon would be a different
  field on a different tick, and no longer this policy. It is the subtlest
  thing in the pass, so it has a check of its own rather than resting on the
  six hashes: `-d:navFieldAudit` requires, on every drain, that each cell the
  pause called settled holds the distance a field built FROM SCRATCH gives
  it. It is a pure observer — same six hashes with it on — and it is known to
  be able to fail, because it was written twice before it could (a version
  that resumed the frontier compared it against itself, and a version that
  left the rebuilt field behind repaired the damage every drain).
- **The compile was a third of a head-to-head.** `build.sh` wiped its work
  directory, nimcache included, so every run recompiled an engine that had
  not changed. See "the two-builds-in-one-binary trick" below for what keeps
  that honest.

One idea that did not pay, written down so it is not tried twice: keying the
shadowcast cache on the diamond ANGLE as well as the origin cell, so a turn
made an entry inapplicable rather than stale and a cast came back when the
stone came back round. It measured 1.035 → 1.065 ms/tick. The reuse is not
there to collect — viewers keep walking into cells nobody has stood in at
this angle — so the wider key and the memory bound are paid for nothing.
Never invalidating at all is worth ~12%, and is of course wrong; that is the
size of the prize and the reason it stays unclaimed.

The eighth pass is the first aimed at the **cost of a sample** rather than at
a mechanism to delete, because after seven passes the profile is three loops
that each take exactly the samples the decision needs. It is one idea found
in four places: **an index or a bounds test recomputed per sample that the
caller already knew the answer to.** Every one of them is a proof, not a
flag — see the note on `-d:danger` below for why that distinction is the
whole of it.

- **A pixel ray range-checked every sample against a map it could not
  leave.** `pixelRayClear` was 30% of a `4ffa` tick. Its samples are
  `dx * s div steps` truncated toward zero, so x never leaves `[ax, bx]` and
  y never leaves `[ay, by]`: both endpoints inside the mask puts EVERY sample
  inside it, which turns four comparisons and a seq range check per sample
  into one test per ray. And `steps` is the longer of the two spans, so the
  axis it came from moves exactly one pixel per step — its remainder
  bookkeeping was provably a no-op, and with it gone the flat index is a
  constant stride. A ray that can leave the map keeps the old loop.
  1.94 → 0.67 G Ir over a 400-tick window.
- **The shadowcast walked rows off the edge of the board.**
  `castFovOctant` takes its octant transform as a STATIC parameter now, which
  is what lets the index become a running sum and the row's in-grid span
  become an interval — and that interval BOUNDS the walk rather than
  filtering it, so a row leaving the board stops costing two float divisions
  a cell. Its second division is also skipped on the prefix the start bound
  throws away. 1.27 → 0.68 G. Its arithmetic is untouched, operand for
  operand: an ulp there is one flipped cell.
- **The cost field range-checked what its own `interior` test had just
  proved.** `driveField` reads up to twenty grid entries per settled cell,
  each a ref deref, a seq-header load and a range check under a line that had
  already established the index was in-grid. 0.65 → 0.49 G.
- **`hypot` decided distances that squares could decide.** `withinDist`
  answers `dist(a, b) <= r` off the squared distance whenever it is a whole
  pixel clear of the boundary, and calls the real thing in the annulus where
  it is not. That is NOT `sqrt(d2) <= R` rewritten as `d2 <= R*R` — the
  boundary is never decided by the other route, it is handed to `hypot`
  exactly as before. Exposure costing asks it once per nav cell per threat,
  ~9,000 times a rebuild. 0.14 → 0.09 G.

Two things from the engine's emit path came with it, both the seventh pass's
own "NOT DONE" list: the four emitters that still passed a memoized raster as
the eagerly evaluated argument of a send the dedup then dropped (hp bars,
identity badges, splatters, damage pops) now ask `knownTextDefSize` first,
and `addDamagePops` reads the dims its placement needs off the def instead of
rasterizing to measure them. The gate is not AT those emitters: it is inside
`addBoardSpriteGated`, which takes the raster `untyped` so it is built only on
the branch that ships it. That is where it has to live — the invariant is that
the object stream is not a function of what a policy reads, and an
emitter-level `if` is one a later edit can slide `currentIds.add` into, which
is precisely the defect an earlier draft of the fifth pass had in these four.
`engine-patches/perf.patch` has it in full.

Verified the way every pass here is, plus one check the engine-only passes
cannot use. `stock_compare.sh` (every config, patched against a pristine
checkout of the same commit) is identical, `selfcheck` passes, the engine's
own suite is still 401 checks, and every config's full-length episode hashes
the same before and after. The extra one is for the POLICY half: build one
binary holding the PRE-change tree as side a and the post-change tree as side
b, then run each config all-a, all-b, and alternating — two seeds over four
configs, run to their natural end, and all three assigns produce the same
`gameHash` as each other. Two trees that are behaviourally identical cannot
be told apart by an episode that seats them against each other, and that is
a stronger statement than either tree agreeing with itself.

`SIM_NIM_FLAGS` overrides the build flags — `--stackTrace:on` when you are
chasing a crash inside the policy, `-d:navFieldAudit` to check the cost
field's pause invariant on every drain, `-d:rayAudit` to check the raycasts'
bounds proof and `withinDist` against the expressions they claim to equal,
`-d:fovSpanAudit` to check the shadowcast's span bound against an unbounded
walk (all three ~30% slower or worse, and none may change a hash),
`-d:danger` for about another 18% if you want it. Bounds checks stay on by default on purpose: `-d:danger` turns an
out-of-range index from a crash into silence, which is the wrong trade for a
tool whose job is finding behaviour bugs.

The eighth pass removed several of those checks by hand, which is the same
trade taken deliberately in four places rather than blindly everywhere: each
`ptr UncheckedArray` in it sits under a line that has just proved the index
in range, and the proof is written above it. That is what `-d:danger` cannot
do — it does not know which indices were proved. Everywhere else in the
policy and the engine the checks are still on.

A proof written above a line is a comment, and a comment is what a later edit
breaks silently, so the two kinds of proof in this pass are each pinned by
something that runs. Where the claim is about the CALLER's data — that the nav
grids are the size `GridW`/`GridH` index them at — it is a `doAssert` once per
call, against the thousands of reads it guards; that is live in every build,
because it costs nothing at that ratio. Where the claim is about the LINE's
arithmetic, it is a differential audit in the shape `-d:navFieldAudit`
established:

| flag | requires |
|---|---|
| `-d:rayAudit` | every fast-path ray answers what the general loop answers, and `withinDist(a, b, r)` answers what `dist(a, b) <= r` answers |
| `-d:fovSpanAudit` | the span-bounded shadowcast lights exactly the cells the unbounded one lights |

Both are pure observers — an audited build hashes the same as a plain one on
every config, which is the first thing to check about them. And both are
known to be able to FAIL, which is the second and is the one that is easy to
skip: shifting the fast ray's wrap test by one, narrowing the span by one
cell, and widening `withinDist`'s near margin each trip the assertion they
should, with the offending ray, cell and radius in the message. An audit
nobody has watched fail is an audit that might be testing nothing — that
lesson is the sixth pass's, written down there after `-d:navFieldAudit` had
to be written twice before it could fail.

### Profiling

The engine and the policy both carry `{.measure.}` marks (`bitworld/profile`)
that compile to nothing by default. Build with a trace path and every marked
proc records into a Chrome-trace JSON that
[fluffy](https://github.com/treeform/fluffy) displays:

```bash
SIM_NIM_FLAGS="-d:release -d:useMalloc --opt:speed \
  -d:ProfileTracePath=/tmp/trace.json" \
  sim/build.sh bot/baseline bot/baseline /tmp/simulate-prof /tmp/prof-work
SIM_TRACE_FROM=200 SIM_TRACE_TO=800 /tmp/simulate-prof \
  --engine .engine --config sim/league_config.json \
  --seeds 5000 --assign aaaaaaaaaaaaaaaa --quiet > /dev/null
nim r src/fluffy.nim /tmp/trace.json      # in a fluffy checkout
```

`SIM_TRACE_FROM`/`SIM_TRACE_TO` bound the traced tick window — a whole
episode of events is gigabytes — and a traced run still prints the same
`gameHash`, which is the check that the instrumentation observed the episode
rather than changed it. fluffy chats on stdout, so profile by hand: the
`local_sim.py` drivers expect episode records there and nothing else.

**A NEGATIVE `SIM_TRACE_FROM` traces from process start**, which is the only
way to see an episode's setup: `initSimServer`'s map bake and the first
frame's init snapshot both run before tick 0, so no tick window can arm early
enough to cover them. Pair it with a small `--tick-cap`:

```bash
SIM_TRACE_FROM=-1 SIM_TRACE_TO=3 /tmp/simulate-prof \
  --engine .engine --config sim/league_config.json \
  --seeds 5000 --tick-cap 3 --quiet > /dev/null
```

That is the view that found the fifth pass's two biggest wins, and it is
worth running FIRST on any new pin: a per-tick profile cannot see a cost that
is paid once, and at these speeds setup is a fifth of an episode. Note that
the two views need different builds of the same binary and answer different
questions — do not read a share off one and quote it against the other.

fluffy wants a display, and a sandbox usually has `Xvfb`, so it can have one:
`Xvfb :97 -screen 0 1800x1100x24 &`, `DISPLAY=:97 fluffy trace.json`, and
screenshot the result (`python3 -m pip install mss`, then `mss.MSS().shot()`).
Its dependencies — silky, jsony — are already in `~/.nimby/pkgs` from the
engine's own sync, so `nim c src/fluffy.nim` needs nothing but the engine's
`nim.cfg` copied in beside it. **Kill it when you are done.** It is a GUI and
it spins a core (2.5 of them here) for as long as it is open, which is enough
to make every wall-clock reading afterwards useless and to invert a
before/after — this pass lost a measurement round to exactly that.

Failing that, read the same numbers straight off the trace: it is a
Chrome-trace JSON, and fluffy's Trace Table is per-name count, total time,
and self time (a frame's duration minus the merged coverage of its children).
One catch if you write your own reader — `fluffy/measure` emits events in
POST-order, since `measurePop` is what appends, so sort by `(ts, -dur)` into
pre-order before walking the nesting. A reader written that way agrees with
fluffy's own table to four decimals, which is worth checking once before
trusting it.

**Then run callgrind, and believe it over fluffy about what is missing.**
fluffy shows the `{.measure.}` marks and nothing else, so a cost that nobody
thought to mark is invisible — it does not appear small, it appears as part
of whatever marked proc encloses it. The sixth pass's second-biggest win was
exactly that: `stampDiamondPatch` carries no mark, and it and what it calls
were 20% of a tick. The seventh pass's setup win was the same shape and
worse: a fluffy trace of a Paintbot episode's setup shows `initSimServer`
and `bakeMap` and looks like a solved problem, while the map generator and
its validator — `inShape`, `mapWallAt`, `validateGeneratedMap`, most of the
setup — run inside `config.update` BEFORE `initSimServer` is called and land
in no frame at all. If fluffy's frames do not add up to the wall clock, the
missing time is real and callgrind is where it is.

```bash
valgrind --tool=callgrind --callgrind-out-file=/tmp/cg.out --cache-sim=no \
  .sim-build/simulate --engine .engine --config sim/league_config.json \
  --seeds 5000 --tick-cap 4000 --quiet > /dev/null
callgrind_annotate --auto=no /tmp/cg.out | head -40
```

Three cautions. Callgrind counts INSTRUCTIONS, not cycles: a per-pixel loop
that is well predicted and cache-resident costs less wall clock than its
instruction count suggests. The diamond restamp went 20% → 3% of a tick's
instructions and 5% of its wall clock — so take the ranking from callgrind
and the verdict from the stopwatch, never both from the same tool. And a
profile of one episode is a quarter setup on this map, so run the same
command with `--tick-cap 1` and subtract: a function whose count is
IDENTICAL in both runs (`inShape`, `isArenaWall`, the PNG decode) is pure
setup, and a batching worker pays it once for a whole batch of seeds.

The third is about WHICH ticks. Subtracting `--tick-cap 1` from
`--tick-cap 400` leaves ticks 0-400, and those are not a steady tick: they
are the window in which every per-viewer def cache fills, so the one-time
rasters behind those gates are still being paid. Read `soldierOutlined` off
that window and it is 6% of a tick; read it off ticks 800-1200 and it is
0.6%, which is the true figure and the reason it is not worth touching. Cap
at 1200 and 800 and subtract those instead when the question is where a
settled tick goes.

Callgrind is also the right tool for the A/B when the effect is small. This
box's wall clock swings ~25% run to run, which is wider than most single
hunks are worth; instruction counts are deterministic, so a before/after at a
fixed `--tick-cap` says whether a change helped at all, and the stopwatch
then says how much. Mind that Nim's mangled names carry a serial that moves
between builds (`castFovOctant__..._u4277`), so strip it before diffing two
profiles or every function will look like it moved.

## The two pins

**`engine.pin`** is the coworld-ctf commit the engine is built from. It is a
measurement pin: a local number is comparable to a hosted one only if the rules
match, so it should track the source commit of the coworld package the league
is running — the same commit `bot/baseline/labels.nim` records itself verified
against.

**`league_config.json`** is the hosted variant's own `game_config`, lifted from
that commit's `coworld_manifest.json`. Do not substitute the engine repo's
`config.json`: they disagree, and the disagreement matters. At the pinned
commit `config.json` says `visionConeDeg: 60` while the league runs **45**, and
the vision cone is the single most load-bearing number in a fog-of-war policy
built around aiming.

Move the two pins together, then re-run `selfcheck`. A move must also carry
`engine-patches/perf.patch`: bootstrap refuses to continue when the patch
fits the new commit neither forward nor reverse, and the patch's own header
says how to regenerate it.

## Layout

```
bootstrap.sh        toolchain, dependencies, engine checkout
engine.pin          the coworld-ctf commit, and why it is that one
engine-patches/     speed-only engine fixes bootstrap.sh applies to .engine;
                    bit-identical on gameHash (see perf.patch's own header)
league_config.json  the hosted variant's game_config, verbatim
paintbot_*.json     the four Paintbot variants' game_configs, same provenance
build.sh            lays out two policy trees + a host each (four with
                    --tree-c/--tree-d), compiles them over a kept nimcache
                    (SIM_CLEAN=1 for a cold build)
host.nim            one seat: baseline.nim's runBot with the socket removed,
                    plus the label vocabulary that seat can read
simulate.nim        the episode loop, seat assignment, the JSON record, and
                    the headless-observation hook the engine emits behind
test_decoder.sh     compiles + runs tests/decoder_test.nim against a tree;
tests/              a selfcheck step (the policy decoder's framing tests)
stock_compare.sh    builds the simulator twice -- against .engine and against
                    a pristine copy of the same commit with perf.patch
                    reverted -- and requires an identical gameHash on every
                    config. The claim the whole patch rests on, as a command
```

`build.sh` is where the two-builds-in-one-binary trick lives, and it is worth
knowing about because it is what makes a local head-to-head possible at all.
Nim resolves imports relative to the importing file, so two copies of the
policy tree in two directories are two distinct module sets — with their own
module-level state, including `tuning.nim`'s adopted map dimensions. Copying
`host.nim` into each tree is what binds its `import decide, ...` to the tree it
sits in.

`selfcheck` pins that trick down from both sides, because it is the one thing
here that could be wrong without ever looking wrong:

- With the **same** source on both sides, a mirrored pair must produce the
  *identical* episode. Anything else means the seat swap is leaking.
- With a **deliberately perturbed** side b, the episode must *diverge*. If the
  two trees ever started sharing state, both sides would run the same code,
  every head-to-head would report a flat zero, and there would be no error and
  no warning to notice — just a tool that can no longer find a difference.

That second check also fails loudly if its own perturbation stops applying, so
it cannot quietly degrade into testing nothing.

**The nimcache survives a rebuild**, which is most of what a head-to-head's
compile used to be: the engine is the bulk of the code and a research loop
changes only the policy, so Nim regenerates the modules that moved and reuses
the rest. Cold 27 s, warm 8 s on this box. Nim's content hashing covers the
sources; everything else that decides what a build is — the flags, the
compiler version, which engine the generated `nim.cfg` points at — goes in a
stamp beside the cache, and a stamp that does not match throws the cache
away. `SIM_CLEAN=1` forces a cold build. `selfcheck` pins this too, and for
the same reason as
the two above — a cache that handed back a stale object file would compile
the policy you edited into a binary running the policy you did not, and every
number after it would be a measurement of the wrong build with nothing out of
place to notice. The check rebuilds the unperturbed pair over the cache the
perturbed build just left and requires the same episode.
