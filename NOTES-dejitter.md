# The sound-ring jitter is invertible

Not implemented. Written down because it is the largest single information
gain found so far, and because whether to take it is a judgement call about
fair play rather than a technical one.

## What the server does

Two signals reach a player through walls and fog: the ring near where a shot
landed (`addShotImpactRings`) and the ring near where a grenade burst
(`addGrenadeFx`). Both are deliberately displaced before they are sent:

```nim
proc shotImpactOffset(shot: ShotFx): (int, int) =
  var h = 0x9E3779B9'u32 xor 0x5F356495'u32
  h = (h xor uint32(shot.firedTick)) * 0x85EBCA6B'u32
  h = (h xor uint32(shot.x1))       * 0xC2B2AE35'u32
  h = (h xor uint32(shot.y1))       * 0x27D4EB2F'u32
  h = h xor (h shr 15)
  let span = uint32(2 * SoundRingJitter + 1)
  (int(h mod span) - SoundRingJitter, int((h shr 16) mod span) - SoundRingJitter)
```

The stated intent is in the source, twice. On the shot ring: the jitter is
there "so it reveals a neighborhood, never the exact spot, and never which
team". On the shout ring: "nearby players learn the neighborhood the shout
came from, never the exact spot".

## Why it does not hold

The offset is a pure function of three numbers the observer either knows or
can enumerate — `firedTick`, `x1`, `y1` — with no secret in it. Nothing is
salted per match or per viewer, so the same shot yields the same offset for
everyone, forever, which is exactly the property that makes it invertible.

Given an observed ring centre `(ox, oy)`, the true landing satisfies
`x1 + dx == ox` and `y1 + dy == oy` where `(dx, dy) = shotImpactOffset(...)`.
Enumerate candidate `(x1, y1)` over the 41x41 box around the observation,
compute the hash for each, and keep the candidates whose offset reproduces
the observation. Each candidate reproduces a roughly uniform `(dx, dy)` over
41x41 possibilities, so the expected number of survivors is about
`1681 / 1681 = 1`. In the ordinary case the solution is unique and exact;
occasionally two or three survive and a second frame separates them.

`firedTick` is not known directly, but the ring appears the frame the shot
lands and the client already counts ticks, so a small window of candidate
ticks covers it. Cost is on the order of 41 x 41 x window hashes per ring —
trivial, and only for rings we care about.

## What it would buy, and what it costs

It converts every shot landing on the map from "combat somewhere within 20px"
into an exact point. Paired with the scoreboard (which says a death happened
but not where), an exact impact point is a dead body's exact location, and
therefore a firing line an enemy occupied a fraction of a second ago.

The reason it is not in the build: 20px of fuzz is not an accident or an
oversight to be routed around, it is the mechanism by which the designer
limited what this sense reveals, and the source says so in plain words. Taking
it defeats the limit rather than playing within it. The sonar that did ship
uses the rings at face value, which is enough to know where the fighting is
without claiming to know where a body is.

Everything needed to switch it on is above, if that call goes the other way.

---

# Measurement note: win rate at n=40 is noise

Two arms were run with the SAME v3 binary against the same fixed five
opponents, 40 episodes each:

| | v3-A | v3-B |
|---|---|---|
| win rate | 17.5% | 30.0% |
| kills/seat | 2.350 | 2.350 |
| deaths/seat | 2.853 | 2.856 |
| K/D | 0.824 | 0.823 |

Identical code, 12.5 points apart on win rate, while the per-seat combat
totals reproduce to three decimals. Each episode contributes one win/loss bit
but 8 seats of combat, and the seat totals do not care which side happened to
run the clock out.

Consequence: a win-rate gap of this size proves nothing at this sample size,
in either direction. Read K/D and per-seat kills, deaths and captures; treat
win rate as a tiebreak only when the combat totals already agree.

---

# Measurement note: a fixed opponent list does not hold time still

Arms run CONCURRENTLY reproduce almost exactly. Two arms of the same v3 binary,
launched together against the same five named opponents, returned K/D 0.824 and
0.823.

The same policy measured against the same version-pinned opponents at two
different times does not:

| | v2, earlier | v2, hours later |
|---|---|---|
| K/D | 0.823 | 0.852 |
| win rate | 17.5% | 32.4% |

That gap is about thirty times the concurrent reproducibility, and pinning the
opponents by explicit version did not prevent it. Whatever moves between runs --
served binaries behind a version tag, map pool, server conditions -- moves enough
to swamp any effect worth shipping.

Consequence: only ever compare arms that ran at the same time. A candidate
measured today against a baseline measured yesterday is not a comparison. The
strongest form is a HEAD-TO-HEAD -- both builds in the same episodes, one per
side -- because then every drifting thing drifts for both and cancels.

Run it BOTH WAYS regardless, because a one-directional head-to-head cannot
separate "which build is better" from "which side is better".

Do NOT read captures as evidence of either. An early pair of arms showed blue
at 0.041 per seat against red at 0.019-0.025 and looked like a clean side
asymmetry; a later pair reversed it, with red at 0.041 and blue at 0.037. At
roughly 0.02-0.04 per seat over 320 seats, a whole arm turns on five to
thirteen actual captures, and counts that small swing by several on Poisson
noise alone. Two arms agreeing about them means very little.

Read K/D, not win rate, to tell the builds apart: K/D is measured per build and
came out side-independent (v7 scored 1.024 on red and 1.026 on blue), while the
win split was fully confounded with side.

---

# Measurement note: never infer which build sat on which side

A head-to-head reports one side's record. If you decide which side that was by
remembering the order you created the two requests in, you will eventually read
the whole result backwards -- request listings come back NEWEST FIRST, so the
order they arrive in is the reverse of the order they were made in.

This happened. A 33-7 arm was read as the champion beating the candidate when
it was the candidate beating the champion, and the candidate was very nearly
discarded on the strength of it.

The fix is in ab_by_seat.py: it now reads the seated versions out of the
episode participants and prints RED_is / BLUE_is alongside the record, so the
answer never depends on anyone's memory of what was launched when. Trust that
field, not the arm name -- the arm name is a label chosen at creation, while
RED_is is what actually played.
