# Shout-Intel

A gossip protocol for sharing timestamped tactical facts over the shout
channel. Implementation is `bot/baseline/shoutintel.nim` (pure, no game
imports) plus a wiring layer in `bot/baseline.nim` behind `-d:shoutIntel`.

    nim r bot/baseline/shoutintel_test.nim     # 54,800 checks, no server needed

## What it carries

Four kinds of observation, each stamped with when it was seen:

| Type | Payload (24 bits) |
|---|---|
| SIGHT | enemy(3) · cell(12) · age(6) · flags(3: heart, shield, arc) |
| DEATH | enemy(3) · cell(12) · age(6) · lives(2) · idKnown(1) |
| PICKUP | spawn(4) · taker(4) · age(6) · takerKnown(1) · spare(9) |
| GONE | spawn(4) · age(6) · spare(14) |

One message is 10 characters: `'~'` then 9 base-94 digits (`'!'`..`'~'`)
encoding a 58-bit integer — a 6-bit header (version 2, sequence 3, count 1)
and one or two 26-bit records (type 2, payload 24).

Space is excluded from the alphabet entirely. That is not tidiness: the server
strips leading and trailing spaces, so any encoding that could emit one at
either end would be silently corrupted in transit.

## Two places this deviates from the spec, and why

**`enemy(3)` names all eight enemies; there is no "unknown" value.** Three bits
is exactly eight, and the spec also asks for a reserved unknown — the two
cannot both hold. Naming all eight was the better trade: SIGHT and DEATH are
*keyed* per enemy, so a record with no name has no slot to merge into and no
way to be reconciled. Sightings of unidentified bodies are therefore not sent
at all (the badge names an enemy whenever the enemy is visible, so this costs
little), and DEATH spends its spare bit on `idKnown` for the genuinely
anonymous case — a corpse nobody can attribute. Such a death still reports
"this ground is safe for ~3s" without deducting a specific enemy's life on a
guess.

**`taker` is the global player index (0..15), with a spare bit for
"nobody seen".** The spec's 4-bit taker has to cover 8 enemies, 8 teammates and
unknown — 17 values in 16 slots. The badge already hands us a global player
index that covers all 16 losslessly, and PICKUP had 10 spare bits, so one of
them carries `takerKnown`. Nothing is dropped.

## Two bugs the invariant tests found

Both were phantom-freshness bugs: a record whose apparent observation time
creeps *forward*, so it wins every merge, gets relayed again, and never dies.
This is the one failure mode the design explicitly must not have, and neither
was visible by reading the code.

**1. Age-field saturation.** The 6-bit age saturates at 63 quanta (252 ticks).
A relayer emitting a record older than that writes an age that understates the
truth, and the receiver reconstructs `sendTick − 253` — a time that advances
with the *relayer's* clock rather than standing still at the original
observation. Each hop made the record fresher. Caught by the three-agent ring
test, which showed the fact still circulating after 60 rounds instead of
expiring. Fixed on both sides: `sendable` refuses to emit at saturation, and
`decodeMessage` refuses to believe a saturated age. A record that old is past
the expiry horizon anyway, so nothing of value is discarded.

**2. Late listeners over-dating a bubble.** This one is in the spec's own
reconstruction formula. `tick_bubble_first_seen − 1 − 4×age` is only correct if
you were watching the sender when the bubble went up. An agent that drifts into
the ~247px radius part-way through a bubble's ~3s life sees it for the first
time long after it was said, and dates every fact inside it up to 72 ticks too
fresh. The inflated copy then beats the honest one in the merge and is relayed
onward, re-inflating at every listener who was also out of range. Caught by the
end-to-end simulation once its invariant was tightened to compare against the
true observation tick rather than merely "not in the future".

The fix is for the receiver to declare what it does not know:
`decodeMessage(text, firstSeenTick, uncertaintyTicks)`, where the caller passes
0 if the sender was under continuous observation and `BubbleLifeTicks` if not.
Erring old is always safe — an over-aged record loses a merge or expires early.
Erring young is unbounded.

The general rule both bugs point at: **every dating path must round toward
older.** Age quantisation rounds up for the same reason.

## Merge

One slot per key per kind — SIGHT and DEATH per enemy, PICKUP and GONE per
spawn — each slot a max over a total order (observation tick, then packed
payload to break ties deterministically). That makes the merge commutative,
associative and idempotent, so any permutation and duplication of the same
record set converges to the same store.

PICKUP and GONE deliberately get *separate* slots rather than one they contend
for. A single contested slot cannot satisfy "a GONE never overwrites a PICKUP
unless it post-dates the respawn that PICKUP implies" and remain
order-insensitive at the same time — I tried, and a three-record sequence
folds to different answers depending on order. With separate slots no overwrite
is possible, and the rule is applied at read time in `spawnState`, where it
cannot depend on arrival order.

## Wiring

Off by default; build with `--build-arg NIM_DEFINES=-d:shoutIntel`.
`-d:shoutIntel` supersedes the older `-d:shoutCoord` scheme (both can be
defined; intel wins the shout slot).

Observation sources are all existing bot machinery: identity badges for enemy
identity and loadout, corpse sprites for deaths, and the pickup tracker for
PICKUP/GONE. A PICKUP requires the *transition* — stocked when we last looked,
empty now — which is what pins the respawn exactly; without that prior sighting
all we can honestly say is GONE.

Consumers are deliberately conservative, because the last session measured
every intel-into-avoidance change as a net loss:

- **Spawn intel feeds routing** (`applySpawnIntel`). Knowing a shield was
  lifted six seconds ago only ever removes a wasted trip. It spends no vision
  and no nerve, which is the property the previously-regressing consumers
  lacked.
- **Heart-carrier sightings steer movement**, but only under `-d:shoutThief`,
  matching the existing precedent — broadcast convergence pulling a whole wave
  onto one fix was measured as an attrition risk, so it stays separately
  switchable.

Taunts are guarded: anything starting with the magic character has it stripped
before sending. That has to be enforced rather than assumed, because taunts
arrive from a language model at runtime. Note the fix must *drop* the
character — padding with a leading space would not survive the server's
stripping.

## Building it from a bare checkout

This archive is the source only; the policy project that held `nimby.lock` is
not in it. Two things are needed and neither is obvious:

- **`bitworld`** — the engine library (`bitworld/[profile, spriteprotocol,
  server]`). It is NOT in the nimble registry and is not in the downloaded
  coworld images. It lives at `Metta-AI/bitworld` on GitHub. Clone the whole
  repo, not just `src/`: `spriteprotocol.nim` does a `staticRead` of
  `../../client/data/pallete.png`, so the build fails on a `src`-only copy.
- **`pixie`, `supersnappy`, `whisky`, `curly`** — all public, `nimble install`.

Then `nim c --path:<bitworld>/src ... players/baseline/baseline.nim`.

For the Docker image, note two environment traps. The session egress proxy
speaks only CONNECT, so `apt-get` inside a build cannot reach the Debian
mirrors (it fails `405 Method Not Allowed`) — use a base image that already
carries a compiler (`gcc:12-bookworm`) and vendor the Nim toolchain, the
nimble package set and bitworld into the build context, so the build stage
needs no network at all. And do not build the binary on the host and copy it
in: the host is Ubuntu 24.04 (glibc 2.39) while the runtime image is bookworm
(glibc 2.36), so a host-built binary will not start.

A mechanism check before spending an A/B, per the rule in `HANDOFF.md`:

    docker build --build-arg NIM_DEFINES="-d:shoutIntel -d:intelDebug" -t x .
    coworld run-episode <manifest> x -o smoke
    grep INTEL smoke/logs/policy_agent_*.log

`-d:intelDebug` prints sent/heard/dropped/held counts on a fixed cadence
rather than per send, so a run of *silence* is visible too — which is the
failure a per-send print would hide. A healthy run shows `dropped=0` on every
agent: the codec is surviving the server's sanitizer intact.

## Measured — it does not pay. Do not ship it.

Both directions, 40 episodes each, run concurrently, 80 scored, zero failures:

| request | RED | RED K/D | BLUE | BLUE K/D | RED wins |
|---|---|---|---|---|---|
| `xreq_d98578ef` | v13 intel | 0.9111 | v12 control | 1.0971 | 13/40 |
| `xreq_ba29dfa2` | v12 control | 0.9906 | v13 intel | 1.0093 | 19/40 |

Pooled by build (`scripts/pool_h2h.py`):

- **K/D: control 1.0426 vs intel 0.9593**, gap **+0.083** to control,
  95% CI [+0.0035, +0.166]
- Win rate: control 57.5% vs intel 42.5%, gap +15.0 pts, CI [−7.5, +37.5]
- Captures: 27 vs 25, gap +2, CI [−12, +16]

Only K/D separates from noise, and it does so *narrowly*: the CI lower bound
sits on top of zero. Re-running the bootstrap under 40 different seeds, the
interval clears zero in 38 of 40, with one-sided P(gap ≤ 0) ≈ 0.021 (range
0.015–0.028). So: real, but marginal.

Two things stop this being a coin flip. K/D and win rate point the **same**
way, where in the v11 arc test they pointed opposite ways — that was the
signature of no effect, and this is not that. And there is a mechanism that
predicts the sign: the position leak. This build shouts at nearly the 1/s
limit from every seat, where the carrier heartbeat it replaces shouted only
from a carrier or a defender whose position was already the least secret thing
on the map. Paying ~0.08 K/D to broadcast where your flankers are is a
coherent story, and it is the risk that was flagged before the run.

Honest caveat: the pooled gap is carried almost entirely by the first
direction. BLUE outperformed RED in *both* requests (RED won only 32/80
overall), so there was a side effect and pooling cancelled it — but the size
of that side effect differed sharply between directions (0.186 vs 0.019), and
the build effect is precisely that asymmetry. A confirming pair would settle
it. It is not worth buying: nothing here suggests shipping, and the cheapest
correct action is to leave the champion alone.

### The missing consumer, added and measured — still does not pay

The first run measured the protocol with almost no readers: `bot.intel.sight[]`
fed **nothing** in the default build, so the richest part of the payload was
wired to a dead end while the build paid the full position leak of shouting.
Grenades are the natural consumer — the lob and the blast both ignore walls,
so a heard position is directly usable with no line of sight and nothing spent
to look. That was added (v14) and measured the same way, against the same v12
control:

- K/D: control 1.0372 vs v14 0.9639, gap +0.073, CI [−0.011, +0.156] (crosses zero)
- Win rate: 53.8% vs 43.8%, gap +10.0 pts, CI [−11.3, +31.2] (crosses zero)
- **Captures: 29 vs 15, gap +14, CI [+1, +27] (excludes zero)**

So wiring the consumer did not rescue it. K/D moved a hair in v14's favour
relative to v13 (0.073 behind instead of 0.083) and captures got markedly
worse. A plausible mechanism for the capture drop: charging a throw sets
`holdStill`, so every extra grenade is up to a second of an attacker standing
still, and captures run on tempo. Treat the capture number with the caution
this repo's own rule demands — it turns on few events, and the interval's
lower bound is +1.

Two experiments in a row now say the same thing from different directions:
the send policy is the expensive part. Both a near-empty consumer set and a
genuinely useful one lost to the same control. What has never been tried is
shouting **rarely** — heart-carrier sightings only, a few times a match —
which would keep the highest-value message and drop almost all of the leak.

This does **not** show that shared perception is worthless. It shows that
broadcasting at nearly the 1/s cap from every seat costs more than anything
yet tried returns.

### The quiet send policy

So the send side was rewritten to say the same things far less often. Four
rules, three of them in `shoutintel.nim` where they are testable:

1. **Nothing redundant, from either source.** One wire slot per key records
   what the TEAM last broadcast — ours and anything we heard. A fact a
   teammate just said is already in every store within earshot, so repeating
   it buys nothing and still costs a full position leak. This is the rule the
   old build lacked entirely: it tracked only its own sends.
2. **Only on material change.** A visible enemy produces a new sighting every
   tick, each one "fresher" than the last, and freshness alone must not buy
   the slot. A sighting is re-broadcast when the body has moved at least
   `ShoutCellDelta` (2 cells, ~32px) or its loadout/heart status changed — a
   step change in what somebody is carrying is news even standing still.
   Spawn events are discrete: the same pickup reported twice is one event.
3. **Not into an empty room.** `mateInEarshot` suppresses the shout when no
   teammate is plausibly within ~247px. Hearing a teammate counts as the
   stronger evidence, because audibility is symmetric and passes through the
   walls and fog that hide a sighting. It is a suspicion, not a proof: a
   silent unseen mate inside the radius costs us one message, where guessing
   the other way costs a leak every second of the match.
4. **Distrust what you hear, in proportion to its age.** Heard sightings feed
   grenade targeting with doubt that grows at `NadeShoutAgeCost` px/tick on
   top of the base 90. A snapshot of a moving body describes a wider area the
   older it gets, and a blast has one fixed radius to cover it.

Measured effect on traffic, same instrumentation, per 480 ticks per agent:

| | shouts sent | records heard |
|---|---|---|
| loud (v13/v14) | 19.4 mean, 26 max | 89.0 |
| quiet | **2.7 mean, 5 max** | 18.6 |

A 7.2x cut in the position leak, with `dropped=0` and the store still holding
2-7 live records per agent. One agent that spent the match away from its
team muted 110 shouts it would otherwise have made into an empty room.

### Measured: quieter is WORSE. The leak was never the problem.

v17 (quiet Shout-Intel) against v16, both built from the same commit and
differing only by `-d:shoutIntel`, so the aim fix is on both arms and only the
shouting is under test. 80 episodes, zero failures:

- **K/D: control 1.0844 vs quiet-intel 0.9224**, gap **+0.162 to control**,
  95% CI [+0.066, +0.259]
- Win rate: 60.0% vs 38.8%, gap +21.2 pts
- Captures: 15 vs 21, crosses zero

This is the most solid result in the whole file: **40 of 40** bootstrap seeds
excluded zero, one-sided P(gap ≤ 0) ≈ 0.0008, and — for the first time in any
of these head-to-heads — **both directions agree in sign** (control led
1.139/0.878 in one and 1.032/0.969 in the other). Nothing here rests on a
side-effect asymmetry.

And it is *worse* than the loud build it was meant to improve: −0.162 against
−0.083 (v13) and −0.073 (v14). Cutting the position leak by 7.2x made the bot
measurably worse, which kills the hypothesis those two earlier runs suggested.
**The leak is not what Shout-Intel was paying.**

The best remaining mechanism fits the whole series. Grenade charging sets
`holdStill`, so every throw costs an attacker up to a second of standing
still. Quieter shouting means heard positions are refreshed far less often,
so the grenade consumer throws at *older* fixes — the same tempo cost, spent
on worse information. That predicts the ordering actually observed: loud with
no consumer (−0.083), loud with the consumer (−0.073), quiet with the
consumer (−0.162).

If that is right, the thing to remove is not the shouting but the *acting*:
paying tempo to act on second-hand positions is the losing trade, and it gets
worse the staler the second hand is. The untested version of this protocol is
one that shares intel and spends nothing to use it — routing only, no throws,
no movement — which is where v13 nearly was, and v13 is still the least-bad
of the three.

Requests: `xreq_d98578ef-a168-47c8-ae44-b743d5249a18` (intelRed),
`xreq_ba29dfa2-dfee-43bc-ae58-87d7ec1595af` (controlRed).

## Four send policies, four losses — and the pattern points somewhere else

`CTF_LEVER_SHOUTSEEN` shouts only while an enemy already has eyes on us, and
then shouts freely: the leak is zero when the position is already known, so
the rationing that made the quiet build stale is dropped. Bursty rather than
thin — 4.3 sends per 480 ticks per agent, but 15 at the peak.

v20 (exposure-gated) against v21 (same commit, no define), 80 episodes:

- **K/D: 0.9334 vs 1.0719**, gap **−0.139**, 95% CI [−0.224, −0.057]
- **Win rate: 35.0% vs 63.7%**, gap −28.7 pts, CI [−48.7, −7.5] — the first
  time win rate itself has separated from noise in this repo
- Captures 17 vs 30, CI [−26, 0]

40/40 seeds exclude zero, one-sided p ≈ 0.0005, and both directions agree in
sign. Another clear loss.

Line the four up by how much they talk:

| build | shouts /480t | K/D gap vs its control |
|---|---|---|
| v13 loud, spawn routing only | 19.4 | −0.083 |
| v14 loud + grenade consumer | 19.4 | −0.073 |
| v20 shout-when-seen (bursty) | 4.3 | −0.139 |
| v17 quiet | 2.7 | −0.162 |

**The relationship is monotonic and backwards: the more it shouts, the less it
loses.** That kills the position leak as an explanation twice over — once
because cutting volume made things worse, and again because making the
remaining shouts *free* (v20) did not help either. Whatever is costing, it
gets worse as the intel gets **staler**, which is the signature of a consumer
acting on out-of-date facts rather than of anything to do with secrecy.

### The prime suspect is a bug in the one consumer every variant shares

`applySpawnIntel` is in all four builds, including v13 which has no grenade
consumer at all. It writes heard spawn state into the routing tables, and it
is systematically pessimistic in a way that grows with staleness:

- A GONE record means "observed empty at T". The item was actually taken at
  some unknown time *before* T, so the true respawn is *earlier* than
  `T + respawn`. `spawnState` returns `T + respawn` anyway.
- `applySpawnIntel` then only ever moves `absentAt` **later**
  (`if st.takenAt > absentAt[i]`). It is a one-way ratchet toward believing
  spawns are empty.

So the bot is told, with increasing confidence as reports age, that med kits
and shields are unavailable when they are in fact stocked — and skips them.
Fewer med kits is directly fewer effective hit points, which is exactly where
a K/D deficit would show up, and the staler the intel the bigger the error.
That predicts the monotonic ordering above, including why the two loud builds
lost least.

It also fits the one thing that never fit the leak story: v13, the build with
almost no consumers, lost anyway.

**Next test, cheap and decisive:** build `-d:shoutIntel` with
`applySpawnIntel` disabled — share and merge everything, act on none of it —
and run it against the same control. If the loss disappears, the protocol was
never the problem and a bug in one consumer was.

## Spawn intel was not the cause, and the "pattern" was not real

Disabling `applySpawnIntel` did not help. v22 (`-d:shoutIntel`, spawn intel
off) against v23 (same commit, no define): K/D **0.9411 vs 1.0622**, gap
**−0.121**, 95% CI [−0.198, −0.045]; captures 14 vs 28, CI [−26, −2]. Still a
clear regression, in the same band as every other variant.

So the hypothesis in the section above is **refuted**, and the reasoning that
produced it was worse than the conclusion. It rested on the five gaps looking
monotonic in shout volume. They are not — the intervals overlap almost
completely:

| build | K/D gap | 95% CI |
|---|---|---|
| v13 loud, spawn routing only | −0.083 | [−0.166, −0.004] |
| v14 loud + grenade consumer | −0.073 | [−0.156, +0.011] |
| v22 spawn intel disabled | −0.121 | [−0.198, −0.045] |
| v20 shout-when-seen | −0.139 | [−0.224, −0.057] |
| v17 quiet | −0.162 | [−0.259, −0.066] |

A single constant effect near **−0.11** is consistent with all five. Reading
an ordering out of that was over-fitting five noisy point estimates, and it
sent one whole experiment down a blind alley.

What survives is simpler and more damning: **Shout-Intel costs about 0.11 K/D
no matter what.** Five variants spanning a 7x range of shout volume, two
different consumer sets, and a build with the suspect consumer switched off
all land in the same place. Neither the send policy nor the consumers move it,
which means the cost is attached to having the machinery in the build at all.

The remaining candidate is per-frame cost. Every variant runs `intelHear`
(which walks every sprite object), `learnOwnName` (again), `noteDeaths`,
`noteSights`, `noteSpawns` and `expire` on every single frame, regardless of
whether anything is sent. If that work pushes the frame budget, the client
drops frames and the bot simply acts less often — which would cost combat
uniformly and would be invisible to every experiment run so far. It is cheap
to test: `ProtocolClient` already tracks `frameAdvance`, `framesDropped` and
`skippedFrames`, so a local run comparing the two builds settles it without
spending a single league episode.

Until that is checked, the honest status is: **do not ship Shout-Intel in any
form.** The protocol is correct — 56,782 invariant checks say so — and it is
still a measured liability.
