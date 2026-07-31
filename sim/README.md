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
pinned commit — or does not carry `engine-patches/`, which bootstrap only ever
applies to the managed checkout, so an unpatched `CTF_ENGINE_DIR` build runs
the pinned rules at unpatched speed.

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

Measured end to end, on four cores, `h2h ... -n 8` — eight seeds run both ways,
so sixteen episodes and 39,300 sim ticks, compile included:

```
2.6 min wall   8 s per episode   ~440 episodes/hour   10 ms per tick
```

(Wall clock across the default worker count, compile included — so the last
figure is CPU per tick derived from it, not a single-worker reading. The
before/after table below is measured differently; see there.)

which puts a real head-to-head at roughly:

| seeds | episodes | wall clock, default workers |
|---|---|---|
| 20 | 40 | ~6 min |
| 40 | 80 | ~11 min |
| 80 | 160 | ~22 min |

So the n=80 `../README.md` calls the floor for a marginal call is about ten
minutes, and the n=160 it wants when an interval nearly touches zero is about
twenty. Episode length moves that more than anything else — the run above
ranged 1785 to 4230 ticks — and a wipe gets cheaper as it goes, because dead
players cost neither a decision nor much of an observation.

**Quote these against each other, not against the table above.** Every figure
here is one machine's, and the previous revision of this file recorded 19 ms
per tick for the same command on a faster one. What travels between machines
is the ratio, so a claim about throughput needs the before and the after
measured on the same box, minutes apart, with nothing else running — the
readings on a loaded four-core box came in 25% slow and would have hidden a
change worth having.

### Where a tick goes now

Under `fluffy` (see "Profiling" below), **building the sixteen observations
is still most of a tick — roughly 70% — with the policy under 30%** and
`sim.step` around one percent. Two optimization passes stand behind that
split, each measured back to back on one idle machine, over the same six
seeds (5000-5005, 13,692 ticks), one worker and no compile — the rows are
from different machines, so read each ratio and never the columns across
rows:

| ms per tick, ONE worker, no compile | before | after |
|---|---|---|
| first pass (policy: labels, presence, searches) | 20.1 | 9.1 |
| second pass (engine patches + the nav field) | 14.4 | 4.3 |

The single-worker figure is not the same measurement as the `10 ms per tick`
above — that one is wall clock across the default worker count, compile
included, and predates the second pass, so the episode-cost table it anchors
now overstates a run by about 3x on a comparable box. Re-measure locally
before budgeting a long head-to-head. What the first pass fixed, in the
order it mattered:

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
to the managed `.engine` checkout, and a moved pin that no longer takes the
patch fails the bootstrap loudly instead of quietly measuring an engine the
patch does not describe. The bit-identity claim is re-provable on demand
rather than trusted to the hand check made when the patch was written:
`local_sim.py verify-patches` builds the simulator patched and unpatched,
runs the six reference seeds through both, and requires them to agree on
`gameHash` and on `obsHash` — an FNV-1a over every observation byte the
episode sent, which is what catches a regression in something cosmetic,
like the fog runs, that the policy never reacts to and `gameHash` therefore
never sees. Run it after every patch edit and every pin move. The policy's
share of the second pass went to the nav cost field, with the same shape of
fix: a repath whose threat picture has not changed reuses the exposure field
and the settled Dijkstra instead of recomputing them (`rebuildExposure`
returns whether anything moved), the sidestep searches score a candidate
cell before buying its raycasts, and a pixel ray now carries its division
incrementally instead of paying two `div`s per sample.

`SIM_NIM_FLAGS` overrides the build flags — `--stackTrace:on` when you are
chasing a crash inside the policy, `-d:danger` for about another 18% if you
want it. Bounds checks stay on by default on purpose: `-d:danger` turns an
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

Move the two pins together, then re-run `selfcheck` and `verify-patches`. A
move must also carry `engine-patches/perf.patch`: bootstrap refuses to
continue when the patch fits the new commit neither forward nor reverse, and
the patch's own header says how to regenerate it.

## Layout

```
bootstrap.sh        toolchain, dependencies, engine checkout
engine.pin          the coworld-ctf commit, and why it is that one
engine-patches/     speed-only engine fixes bootstrap.sh applies to .engine;
                    `verify-patches` re-proves them bit-identical
league_config.json  the hosted variant's game_config, verbatim
build.sh            lays out two policy trees + a host each, compiles them
host.nim            one seat: baseline.nim's runBot with the socket removed
simulate.nim        the episode loop, seat assignment, and the JSON record
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
