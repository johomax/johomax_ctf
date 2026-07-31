# Opponents that are not this repository

Everything else in `sim/` measures one of our builds against another of our
builds. This directory adds one outside opponent: **coworld-ctf's default
player**, the `baseline` bot the league ships and the ancestor this whole
repository is a fork of.

It answers a question a self-mirror cannot — *how far has the fork actually
come* — and it is the only opponent available without buying hosted episodes,
because it is the only CTF policy whose source we have. There is exactly one:
the coworld manifest declares a single player (`baseline`), so "the default
policies" is a set of size one.

```bash
sim/opponents/h2h.sh              # 40 seeds, both directions, 80 episodes
sim/opponents/h2h.sh 80 HEAD~5    # more seeds, an older build of ours
```

## Why it needs an adapter at all

`sim/build.sh` links two policy trees into one binary and drops `sim/host.nim`
into each. That host is `bot/baseline.nim`'s `runBot` with the socket removed,
so a tree it can drive has to expose what `runBot` used: a `Bot`, `roleForSeat`,
`seedRng`, `resetTransient`, `buildNavGrid`, `decide`, `AimRate`/`AimBrads`,
and a `ProtocolClient` that can be handed packet bytes instead of a websocket.

The default player has all of that logic and none of that shape. It is one
2850-line module, so nothing in it is exported — a single module needs no
export markers — and its `protocols.nim` only ever receives through `whisky`.

`make_tree.py` rewrites it into the shape and does nothing else:

| what it does | why |
|---|---|
| flattens `baseline/{protocols,artlog,taunts}.nim` to the tree root | `build.sh` copies one directory's `*.nim` |
| exports 9 declarations and 7 `Bot` fields | the host names them |
| cuts the file at `proc runBot` | that loop is what the host replaces |
| adds `seedRng` | upstream spells it inline in `runBot` as `randomize(slot * 7919 + 1)` |
| adds `deliverPacket` / `takeFrame` to its protocol client | the socket-free seam `bot/baseline/protocols.nim` already has |
| writes `world.nim` / `tuning.nim` / `navgrid.nim` as `export decide` shims | the host imports the five modules a layered tree has; this tree is one module |

No constant, no branch, no role, and no line of judgement is touched. Run it
with `--diff` to read every change: nineteen lines gain a `*` or lose a
`baseline/` import prefix, and the rest of the diff is the cut and the two
added procs.

Every edit is an exact string that must match **exactly once**, and a miss is
fatal rather than skipped. An adapter that quietly stopped applying an edit
would measure something other than the policy it names — the same failure the
auto-research loop's `--dry-run` exists to prevent, for the same reason.

## Which default player

The engine checkout's, so the policy and the rules it plays under come from
one commit — `sim/engine.pin`. Upstream's `players/baseline` moves on its own
schedule (29 changed lines of `baseline.nim` between the pin and coworld-ctf
`main`, the day this was written), and pairing a newer bot with older rules
measures the pairing. `--player` points somewhere else if you want that on
purpose.

## A fifth way a local number can disagree with a hosted one

[`../README.md`](../README.md) lists four. Hosting the default player adds one
more, and it applies **only to this opponent**:

5. **The default player draws from the process-wide RNG.** Upstream calls
   `randomize(slot * 7919 + 1)` once in `runBot` and then uses the global
   generator (`rand` at the jink and steer-jitter sites, `sample` at the shout
   sites). In a container that process holds one seat. Here it holds sixteen,
   so the eight seats of this build share one stream instead of owning one
   each. The run stays deterministic — seats are stepped in a fixed order and
   a seed reproduces the episode to the hash, which `selfcheck` and every
   repeat run confirm — but the draws are not the ones a container would have
   made. Our own tree is unaffected: `bot/baseline` gives every `Bot` its own
   `initRand`, which is what makes seat noise a property of the seat.

Nothing about this favours either side. It is a fidelity note, not a bias.

## `-d:artlogNoCurl` is not optional

Upstream's telemetry module links libcurl unless that define is set, and it is
a `dynlib` load: the build succeeds, the first episode dies. `h2h.sh` sets it.
The flag is upstream's own (`players/baseline/README.md` documents it for test
builds); it drops the HTTP delivery path and keeps the rest of the module
compiled in. No artifact is uploaded from a simulator run either way — there
is no runner to inject an upload URL.

## What the number means

[`../../README.md`](../../README.md)'s seven rules and
[`../README.md`](../README.md)'s four differences all still hold. One more,
which is really the simulator's fourth difference with the knife turned
around:

**Beating the default player is not beating the league.** The default is one
entry in the standing field and the weakest lineage in it — every other
competitor is somebody's fork of it, tuned. A margin here says how far this
fork has travelled from where it started. It says nothing about the current
standings, and it cannot be substituted for the hosted mirror that settles a
change.

Its use is as a **regression floor with no drift in it**: this is the one
opponent that will still be the same opponent in a month, so a margin measured
today is comparable to a margin measured whenever the engine pin next moves.
Our own champion mirror cannot do that, because the champion keeps improving
underneath the comparison.

The one difference that does have a direction here is the simulator's first,
and it runs **against** us: in process nobody misses a frame, and the default
player is several times more expensive per tick than this tree is (it is the
policy the three optimization passes were run on — labels as strings, presence
in a sparse table, searches recomputing settled answers). Hosted, it would drop
frames this run hands back to it for free. Whatever margin appears below is
therefore a floor, not a ceiling.

## Measured

`bot/baseline` at `41b07be`, mirrored against the default player at the pinned
engine commit `1047232`. Two mirrors of 40 seeds both ways — seeds 1000-1039
and 2000-2039 — pooled to **160 episodes, 0 skipped**, about 18 minutes each on
four cores. Gaps are `ours - default`, bootstrapped over seed pairs by
`autoresearch_local.verdict_from_records`, the same code that writes every
local verdict in [`../../research/LEDGER.md`](../../research/LEDGER.md).

| | ours (`bot/baseline`) | default (`players/baseline`) |
|---|---|---|
| K/D | 1.2492 | 0.7999 |
| kills / deaths | 3629 / 2905 | 2894 / 3618 |
| captures | 32 | 46 |
| accuracy | 0.687 | 0.639 |
| wins | 112 / 160 (70.0%) | 48 / 160 (30.0%) |

- K/D gap **+0.4493**, 95% CI [+0.3901, +0.5058] — separates positive
- Win-rate gap **+0.400**, 95% CI [+0.250, +0.550] — separates positive
- Capture gap **−14**, 95% CI [−32, +5] — crosses zero

It holds on both sides: ours won 65/80 on blue and 47/80 on red, so the verdict
is not the side bias wearing a number. Episodes ended `capture 78  wipe 82`,
median 2294-2376 ticks.

**The second mirror is why there are two.** At n=80 the capture gap was −14
with a 95% CI of [−27, −1] — captures separating *negative*, which is a veto
under the loop's own local rules, and would have read as "the fork kills better
but converts worse than the bot it came from". The confirmation mirror came
back 20-20 on captures, and the pooled interval crosses zero. That is
[`../../README.md`](../../README.md) rule 5 doing exactly what it is written to
do, for the fifth time in this repository's record, and it is worth noting that
the metric that evaporated was the one with the interesting story attached
to it.

Two things this does not say. It is not a league number — see above. And it is
not a *comparable* number until it is re-run: it is one machine's, one pin's,
and one tree's, so the way to use it is to run it again after the pin moves and
read the change.

### One side observation, unexplained

RED won **38.8%** of these 160 episodes. Under the current pin, local
seed-paired mirrors of two *equal* builds run RED at 51-65%
([`../../research/BACKLOG.md`](../../research/BACKLOG.md) item 21), and both
builds here did better on blue — ours 65/80 vs 47/80, the default 33/80 vs
15/80. So the side advantage does not merely shrink when the builds are
unequal, it points the other way. Nothing in this run explains that, and
nothing here depends on it, since both directions are balanced by
construction. It is recorded because item 21 is open and this is a data point
for it.

## Verified before the episodes were bought

The same list [`../../README.md`](../../README.md) requires before a hosted
mirror, adapted:

- every edit matched exactly once (`make_tree.py` exits otherwise);
- the two-tree binary built, with the `ButtonC` tripwire in
  `bot/baseline/protocols.nim` passing against the engine's pin;
- the default player **plays**, rather than connecting and idling: all sixteen
  seats of it, seed 4242, produced 41 kills over 212 shots at 0.62 accuracy and
  ended in a wipe. A build that does nothing is otherwise indistinguishable
  from a build that is merely much worse, which is exactly the verdict at
  stake here;
- the two trees are genuinely two policies: all-a and all-b on one seed
  produce different episodes (`11538856401437229952` vs `6309108757364360970`);
- our tree plays the *same* episode whether its partner is itself or the
  default player — all-a on seed 4242 hashes identically under both binaries,
  so adding this opponent to the build does not perturb the build it measures;
- the mixed binary is deterministic: one seed, one assignment, run twice,
  identical hash;
- `scripts/local_sim.py selfcheck` passes on this machine.

And after the episodes, the check that the script in this directory is the one
that produced them: the tree was deleted, regenerated from scratch, rebuilt,
and reproduced seed 99's episode to the hash (`7094057229520898237`). A
generator whose output drifts from the tree that was measured would make every
number above unfalsifiable.
