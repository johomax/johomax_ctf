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

Note also this measured the protocol with its conservative consumer set
(spawn intel into routing only). It does **not** show that shared perception
is worthless — it shows this send policy costs more than this consumer set
returns. Shouting less, or only for heart-carrier sightings, is a different
experiment and is still open.

Requests: `xreq_d98578ef-a168-47c8-ae44-b743d5249a18` (intelRed),
`xreq_ba29dfa2-dfee-43bc-ae58-87d7ec1595af` (controlRed).
