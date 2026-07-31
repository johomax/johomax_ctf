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

Measured end to end on four cores — `scripts/local_sim.py h2h ... -n 40`, so
**80 episodes** (`-n` counts seeds and a h2h runs each both ways),
**compile included**, which is how a research loop actually experiences it.
Both rows warm, back to back on one idle box, same command:

| | wall clock | episodes/hour |
|---|---|---|
| the previous revision of this tree | 1 m 56 s | ~2,490 |
| this one | 1 m 45 s | ~2,730 |

**1.10x end to end**, with every episode's `gameHash` unchanged — the same
measurement, faster. The end-to-end ratio is smaller than the 1.14x the
episodes themselves moved (see the pass table below) because a third of that
wall clock is not episodes: two `git archive` extractions, a warm Nim build,
and the driver's own process spawns are a fixed cost that no per-tick work
touches. It is also the honest number to budget from, so it is the one in
the table.

A warm build is the normal case: `build.sh` keeps its nimcache, so only what
you edited recompiles.

Which puts a real head-to-head at roughly:

| seeds | episodes | wall clock, default workers, warm build |
|---|---|---|
| 20 | 40 | ~1 min |
| 40 | 80 | ~1.8 min |
| 80 | 160 | ~3.2 min |

So the n=80 `../README.md` calls the floor for a marginal call is under two
minutes, and the n=160 it wants when an interval nearly touches zero is
around three — which is the point of the exercise: at these prices the thing
that limits an auto-research loop is deciding what to try, not waiting for
it. Episode length moves that more than anything else — a run ranges roughly
2000 to 5000 ticks — and a wipe gets cheaper as it goes, because dead
players cost neither a decision nor much of an observation.

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

### Where a tick goes now

Two profilers, and **the second one is where the last pass came from.**
`fluffy` reads the `{.measure.}` marks (see "Profiling" below) and so shows
only what somebody thought to mark; `callgrind` counts every instruction and
does not care. Read them together, and re-read the second one after any pass
— what it found is that the biggest single block in the engine's share of a
tick was a proc with no mark on it at all.

Under callgrind, over a whole episode (seed 5000, 4000 ticks, setup measured
separately and subtracted — it is 7.3 of the 24.8 billion instructions, and
batching amortizes most of that across a worker's seeds, leaving 17.5 billion
of per-tick work):

| share of a tick | what |
|---|---|
| 18% | `castFovOctant` — the shadowcast, recursive, so it lands in two entries |
| 17% | the policy's raycasts (`pixelRayClear` 11%, `rayClearCoarse` 6%) |
| 6% | the cost field (`driveField`) |
| 5% | `canOccupy` — the movement rules' collision probe |
| 3% | the policy's packet decode (`refreshFrame`) |
| 2% | `hypot`, and 2% `ringExplained` |
| the rest | `step`'s own rules, the wire encode, the allocator |

Two entries that used to be on this list and are not any more: `setLen` was
5%, all of it the fog's shadow buffer being zeroed twice, and the cosmetic
raster copies (`eqcopy`, `soldierOutlined`) were 9%. The seventh pass took
both; `engine-patches/perf.patch` has the argument.

**The shadowcast and the raycasts ARE the decisions**, and they are close to
their floor for that reason rather than for want of effort: the
exact-arithmetic transformations that were free elsewhere run out right
there — `sqrt(d2) <= R` and `d2 <= R*R` can disagree at an ulp boundary, and
one flipped cell is a different episode. A pass that wants a big number
should look for another mechanism to remove rather than another loop to
tighten; that is where every pass here that paid off came from, including
the two that were hiding under an unmarked proc and all three of the
seventh's.

Seven optimization passes stand behind that split, each measured back to back
on one idle machine, over the same six seeds (5000-5005), one worker and no
compile — the rows are from different machines (and the tree the seeds run
has changed between passes), so read each ratio and never the columns across
rows:

| ms per tick, ONE worker, no compile | before | after |
|---|---|---|
| first pass (policy: labels, presence, searches) | 20.1 | 9.1 |
| second pass (engine patches + the nav field) | 14.4 | 4.3 |
| third pass (shared per-connection work + wire encode) | 2.39 | 1.07 |
| fifth pass (headless observation + per-episode setup) | 1.27 | 0.78 |
| sixth pass (lazy fog grid, field horizon, diamond stamps) | 1.596 | 0.954 |
| seventh pass (memoized self marker, fog buffer, lazy rasters) | 0.679 | 0.598 |

(The fourth pass was the GV30 rebase, which held the ratio rather than
improving it; `engine-patches/perf.patch` has its story. The sixth pass's
row is from a slower box than the fifth's, which is why its "before" is
above the fifth's "after" — the rows are ratios, never a column.) The
seventh's row is five alternating pairs, all five the same direction; it
holds at four workers too, which is the shape the driver actually runs
(0.384 → 0.337 ms/tick, three pairs).

Against the pinned engine with **no patch at all** — which is also the check
that the simulator still builds and runs on a stock `CTF_ENGINE_DIR`
checkout — the whole stack is 9.04 → 0.600 ms/tick on those six seeds, with
all six `gameHash`es identical. Re-run that one after any change here: it is the
statement that this reproduces the unmodified upstream engine exactly, which
is the only reason it is allowed to be fast. The patched engine also passes
coworld-ctf's own suite (`nim c -r -d:release tests/tests.nim` from the
`.engine` root, 327 checks) — worth running when a change touches a path the
headless hook switches off, because a six-seed `gameHash` run never takes
those.

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

The single-worker `ms per tick` rows are not the same measurement as the
end-to-end table under "What it costs": those are wall clock across the
default worker count with the compile included, which is a third of them.
Re-measure locally before budgeting a long head-to-head, and never divide
one table by the other. What the first pass fixed, in the order it mattered:

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

The seventh pass is three more of the same shape, all in the engine, all in
`engine-patches/perf.patch` where the full argument lives:

- **Sixteen viewers rasterized the same self marker.** The second pass had
  already stopped it being re-rasterized every FRAME; what was left was once
  per (viewer, skin, rot), and the picture does not depend on the viewer.
  Memoized on (team, skin, rot): 4% of a tick's instructions to nothing.
- **The fog's shadow buffer was zeroed twice.** A cache miss hands
  `computeFovShadow` a fresh seq, and `setLen` fills new slots one at a time
  — a loop gcc does not turn into a memset — after which the proc memset the
  same 12.9k cells again. `newSeq` allocates zeroed storage once. 4.2% → 1.4%.
- **Every cosmetic raster was copied out of its memo for a dedup that dropped
  it.** Arguments are evaluated before the call, so the third pass's memos
  removed the raster but not the copy out of the table — per badge, hp bar,
  splatter, tracer and bloom, per viewer, per frame, in front of a def check
  that returned immediately. `addBoardSpriteLazy` is a template, so the
  pixels are an expression it does not evaluate on the common path.
  `addBoardSpriteChanged` went from 66,370 calls per 600 ticks to 6,402.

**Three ideas the seventh pass measured and threw away.** Each one is written
down with its number so the next reader spends the slot on something else:

- **Bit-packing the policy's walkability mask**, 813 kB of `seq[bool]` per
  seat down to 102 kB — on the theory that a raycast sampling scattered
  pixels was missing cache on most of them. Bit-identical, and **flat**: 0.667
  → 0.665 ms/tick at one worker and 0.2533 → 0.2528 at four, with the pairs
  disagreeing in sign both times. It also *costs* instructions for the shift
  and mask (`pixelRayClear` 1.95 → 2.16 billion), so it is strictly worse
  work for the same wall clock. The mask was not the bottleneck it looked
  like; a first, non-interleaved reading said 6% and was pure warm-up drift.
- **`findPeekCell` casting its rays in score order** instead of grid order
  with a running best, so it could stop at the first cell that clears. That
  IS the same cell — the answer is the cheapest-scoring cell whose rays
  clear — and it does cut rays. Just not enough to pay for the sort:
  `pixelRayClear` fell 2.5% and the program total ROSE 0.3%. The reason is
  in the call pattern: **69% of calls find no cell at all** (2,254 hits in
  7,348 calls over three episodes), and a call that finds nothing pays for
  every candidate either way.
- **Memoizing `markExposedFrom` per threat spot**, which is a pure function
  of (map, spot) and repeats: 41% of spots hit a 32-entry LRU over three
  episodes. It still loses, because a memo has to compute a spot's set
  against an EMPTY field and so gives up the `already marked` skip — which
  today removes ~2,400 of the ~6,570 cells a call scans, roughly doubling
  the cost of a miss. 0.59 × 2.0 is break-even at best. Not implemented; the
  counts are here so nobody re-derives them.

One change kept without a stopwatch result, flagged as such: `rayClearCoarse`
was recomputing the `hypot` its exposure-costing caller had just used for the
range test, so `rayClearCoarseLen` takes the length already in hand. Same
ray, 23% fewer `hypot` instructions, 0.8% off the per-tick total — and inside
the noise on this box's wall clock. It is dead work removed at no
complexity, not a measured win, and should not be quoted as one.

`SIM_NIM_FLAGS` overrides the build flags — `--stackTrace:on` when you are
chasing a crash inside the policy, `-d:navFieldAudit` to check the cost
field's pause invariant on every drain (~30% slower, and it must not change a
hash), `-d:danger` for about another 18% if you want it. Bounds checks stay on by default on purpose: `-d:danger` turns an
out-of-range index from a crash into silence, which is the wrong trade for a
tool whose job is finding behaviour bugs.

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
`nim.cfg` copied in beside it.

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
were 20% of a tick.

```bash
valgrind --tool=callgrind --callgrind-out-file=/tmp/cg.out --cache-sim=no \
  .sim-build/simulate --engine .engine --config sim/league_config.json \
  --seeds 5000 --tick-cap 4000 --quiet > /dev/null
callgrind_annotate --auto=no /tmp/cg.out | head -40
```

Two cautions. Callgrind counts INSTRUCTIONS, not cycles: a per-pixel loop
that is well predicted and cache-resident costs less wall clock than its
instruction count suggests. The diamond restamp went 20% → 3% of a tick's
instructions and 5% of its wall clock — so take the ranking from callgrind
and the verdict from the stopwatch, never both from the same tool. And a
profile of one episode is a quarter setup on this map, so run the same
command with `--tick-cap 1` and subtract: a function whose count is
IDENTICAL in both runs (`inShape`, `isArenaWall`, the PNG decode) is pure
setup, and a batching worker pays it once for a whole batch of seeds.

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
build.sh            lays out two policy trees + a host each, compiles them
                    over a kept nimcache (SIM_CLEAN=1 for a cold build)
host.nim            one seat: baseline.nim's runBot with the socket removed,
                    plus the label vocabulary that seat can read
simulate.nim        the episode loop, seat assignment, the JSON record, and
                    the headless-observation hook the engine emits behind
test_decoder.sh     compiles + runs tests/decoder_test.nim against a tree;
tests/              a selfcheck step (the policy decoder's framing tests)
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
