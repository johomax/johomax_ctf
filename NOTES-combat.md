# Two combat bugs, measured

Both are in the base bot and predate Shout-Intel — v12 and v13 behave
identically here. Both were found by counting, not by reading:

    docker build --build-arg NIM_DEFINES=-d:combatDebug -t x .
    coworld run-episode <manifest> x -o out -n 3
    grep COMBAT out/episode-*/logs/policy_agent_*.log

Numbers below are 16 agent-episodes (3 local episodes, all 16 slots).

## 1. The turret parks just outside its own firing tolerance

Two thresholds disagree, and nothing reconciles them:

- **When to stop turning** is a constant: `CombatDeadband = 2` brads. The
  traverse holds still once `|err| <= 2` (`AimRate` is 5 brads/tick, so it
  cannot settle tighter than about ±2.5 — hence the 2).
- **When to fire** is range-dependent: the aim error's perpendicular miss at
  the target's range must fit an 11px bullet corridor
  (`perpMiss = range * sin(err)` ≤ `FireSlackPx = 11`).

Those only agree at close range. The largest error that still fires:

| settled error | fires out to |
|---|---|
| 0 brads | any range |
| 1 brad | 448 px |
| 2 brads | **224 px** |

So beyond ~224px the turret can reach `|err| = 2`, declare itself settled, and
stop — while the fire gate still says no. Nothing then changes: the turret has
no reason to turn (it is inside the deadband) and the gun has no reason to fire
(the corridor test fails). The bot holds a perfect-looking aim on a live enemy,
with a clear corridor and a ready gun, and never pulls the trigger. Both sides
do it symmetrically, which is the staring contest.

Measured: of 111 ticks holding a gun target with the gun ready, **79 did not
fire, and 22 of those were stalled in exactly this state — 20% of all engaged
ticks — at a mean range of 441 px.** At 441px the shot needs `|err| <= 1`,
and the deadband happily allows 2.

### Fixed — `CTF_FIX_AIMBAND` (on by default)

`fireDeadband(range)` makes the stop-turning threshold the same quantity as
the start-firing threshold, solved for the angle instead of the miss:
`asin(FireSlackPx / range)` in brads, clamped so it is never looser than the
old constant (inside ~224px nothing changes at all).

That makes the pathological state *unrepresentable* rather than merely rarer:
whenever the traverse halts, `err <= deadband` implies
`perpMiss <= FireSlackPx` by construction, so "settled, in range, gun ready,
still not shooting" cannot occur.

Verified with one binary and the lever toggled, so nothing else differs:

| | `CTF_FIX_AIMBAND=0` | on |
|---|---|---|
| ticks: target + ready gun | 146 | 101 |
| ...traverse stopped, no shot | **31** (21.2%) | **0** (0.0%) |

Two honest caveats. It cannot conjure precision the turret does not have —
`AimRate` is 5 brads/tick, so past ~448px the required deadband is 0 brads,
which only some approach residues can hit; the rest still has to be bought by
closing the range, which the engage branch was already doing. And the local
fire rate did not visibly improve (15.8% vs 11.9% of engaged ticks), but
those are different random episodes at a small sample and a local all-slots
run cannot measure strength anyway. What is established here is that the
stall state is gone, not that it converts to kills.

**Aggravating factor, still unfixed:** see the jink gate below.

### Measured: directionally positive, not established

v15 (plain build plus the fix, no Shout-Intel, so the comparison isolates it)
against the v12 control, both directions, 40 episodes each, 80 scored, zero
failures:

- **K/D: v15 1.0365 vs v12 0.9647**, gap **+0.072 to v15**,
  95% CI [−0.023, +0.169] — crosses zero
- Win rate: 51.2% vs 48.8% — crosses zero
- Captures: 19 vs 22 — crosses zero

Under 40 bootstrap seeds **0 of 40** intervals excluded zero, and the
one-sided P(the fix is *not* ahead) is about 0.072. So this is the first
change measured here that is not a regression, but it is not established
either.

The two directions also disagree in sign — v12 led when v15 held RED
(1.018 vs 0.983), v15 led by a lot when v12 held RED (1.094 vs 0.914). BLUE
outperformed RED in both, so pooling cancelled a side effect, and the build
effect is the difference in its size. That is the same shape as the v11 arc
test, and it is the shape that most often turns out to be nothing.

The case for keeping it anyway is that it is a **defect repair, not a tuning
change**: the old code had a provable dead state (21% of engaged ticks, in
which the bot could not fire no matter what) and the fix removes it by
construction, with no measured harm. The case for not claiming a win is
everything in the paragraph above. A confirming pair would settle it and is
the cheap, correct next step before anyone calls this an improvement.

**Aggravating factor, read from the code but not separately measured:** the
anti-stuck jink is gated `if bot.stuckTicks > 20 and engage < 0`. While a
target is held, the unsticking burst is disabled — so anything that pins the
bot while it is aiming keeps it pinned, and the stall above has nothing to
break it.

## 2. Grenades are held because the enemy is out of throwing range

The bot does throw — 52 grenades across the 16 agent-episodes — but it holds
one for 2594 ticks to do it, and the reason is almost entirely range:

| candidate landing refused because | count | share |
|---|---|---|
| **too far (> `NadeMaxRange` 240px)** | **2056** | **91.7%** |
| fresh target, clear corridor, alone (use the gun) | 136 | 6.1% |
| a mate inside the blast (`nadeSafe`) | 47 | 2.1% |
| too close (< `NadeMinRange` 72px) | 0 | 0% |

`nadeSafe` was the obvious suspect and it is not the problem — it refuses 2%
of candidates. Neither is the deliberate "prefer the gun on a clear shot" rule
(6%). The grenade simply has a 240px reach on a 1235px map, and the gun fights
at 440-500px (see above), so the enemy is nearly always beyond lobbing
distance when a grenade is in hand.

Nothing in the movement layer ever treats "get inside 240px of someone" as a
reason to move. The grenade is a weapon of pure opportunity: it is used when
the game happens to deliver a target into range, and otherwise carried.

That makes the grenade-farming lever a net accumulator — pickups run 4-16 per
match against roughly 3 throws per agent per episode here. Whether closing to
throwing range is worth the exposure is an open question and would need a
head-to-head; the point of this note is only that the binding constraint is
range, not safety and not the gun-preference rule.
