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

Measured end to end, on four cores, `h2h ... -n 8` — eight seeds run both ways,
so sixteen episodes and 40,311 sim ticks, compile included:

```
3.2 min wall   12 s per episode   ~300 episodes/hour   19 ms per tick
```

which puts a real head-to-head at roughly:

| seeds | episodes | wall clock, 4 workers |
|---|---|---|
| 20 | 40 | ~8 min |
| 40 | 80 | ~16 min |
| 80 | 160 | ~32 min |

So the n=80 `../README.md` calls the floor for a marginal call is a quarter of
an hour, and the n=160 it wants when an interval nearly touches zero is about
half an hour. Episode length moves that more than anything else — the run
above ranged 1785 to 4230 ticks — and a wipe gets cheaper as it goes, because
dead players cost neither a decision nor much of an observation.

Roughly seven tenths of a tick is the policy thinking, three tenths is the
engine building sixteen observations, and `sim.step` itself is under half a
percent. That ratio is the useful part: **this simulator measures your
policy's CPU cost as much as its strength**, and the fastest way to speed it
up is to make the policy cheaper. That is not theoretical — the first thing
this tool was pointed at was its own throughput, and it found that
`protocols.nim` was sweeping a 22k-slot object table 28 times per decision to
find 180 objects. Fixing that was worth 1.99x end to end, and the simulator
verified the fix changed nothing: ten seeds, identical `gameHash`, and the
same sixteen-episode A/B down to the last digit of the interval.

`SIM_NIM_FLAGS` overrides the build flags — `--stackTrace:on` when you are
chasing a crash inside the policy, `-d:danger` for about another 18% if you
want it. Bounds checks stay on by default on purpose: `-d:danger` turns an
out-of-range index from a crash into silence, which is the wrong trade for a
tool whose job is finding behaviour bugs.

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

Move the two pins together, then re-run `selfcheck`.

## Layout

```
bootstrap.sh        toolchain, dependencies, engine checkout
engine.pin          the coworld-ctf commit, and why it is that one
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
