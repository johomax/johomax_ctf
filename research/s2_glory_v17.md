# Paintbot solo BR: Glory v17 scoring economy

Source snapshot: `/private/tmp/engine-main-v44` at
`e68074652e63c5651a1c2aa2148edc2bba5ddcc1`. This is `GloryVersion = 17`
and `GameVersion = 62` (`src/ctf/glory.nim:300-327`;
`src/ctf/sim_types.nim:141-157`). The `battle-royale-s2` manifest is the
16-player, 16-team, one-life, 4-HP, 1300-range variant
(`coworld_manifest_paintbot.json:1214-1218`;
`coworld_manifest_paintbot.json:1268-1338`;
`coworld_manifest_paintbot.json:1340-1361`). It arms all five S6 switches:
`brAssistRescueUngated`, `pactScopedWipeDown`, `placementRampV3`,
`gloryFixedPointScale`, and `catalogV3Reprice`, in addition to the existing
multiplier, win-factor, and mint-cap switches
(`coworld_manifest_paintbot.json:1404-1423`).

## Conclusions

- v17 moves direct value **away from placement and toward combat and formal
  alliances**. Final 8 and Final 4 become score-neutral; Final 2 is only x1.30
  and is skipped from a low product. The nominal x1.02 survival ticks are also
  skipped from a no-deed product. A zero-deed loser therefore scores **1 at
  every survival time**, and a zero-deed winner scores **8**, not a continuously
  rising amount.
- A plain tag is now x2.20 instead of x1, and heat is repriced from x1/x2/x4/x8
  to **x1/x5/x14/x36**. Losing seats bank their products, so cheap tags and
  short kill chains are worth pursuing instead of pure hiding.
- In solo BR, `brAssistRescueUngated` does **not** make an ordinary cross-team
  assist pay: the setup damager must still be on the killer's literal team.
  A pact ally is not a teammate for that predicate. Formal pact co-damage pays
  through `JOINT ACT` and the ally stack instead.
- There is a material implementation issue at this exact commit: the armed
  raw-product cap remains `2^24` even though the accumulator is scaled by 1024,
  and the percent-fold cap precheck is also missing the percent denominator.
  Consequently the maximum reported unhalved score is **16,384**, and v3
  factors can hit it far earlier than their actual product would. This is the
  executable behavior to plan around until the engine changes, not the stated
  fixed-point design intent.

## 1. Deed prices and factor composition

The frozen v15/v16 integer bases are at `src/ctf/glory.nim:2550-2606`; v17
starts by copying that table and overrides the following entries
(`src/ctf/glory.nim:3106-3137`). “Enemy” below is the v17 territory-adjusted
class before heat or ally stack.

| Deed | v15/v16 base | v17 non-enemy base | v17 enemy-ground base |
|---|---:|---:|---:|
| ordinary `TAG` | x1 | **x2.20** | **x2.20** |
| `FIRST!` | x2 | **x4.00** | **x4.24** |
| `LONGSHOT` | x3 | **x6.00** | **x6.24** |
| `BOUNTY` / ace | x4 | **x9.00** | **x9.27** |
| `CLOSING TIME` | x3 with `winAsMultiplier` | **x1.20** | **x1.27** |
| `LAST LIGHT` | x4 | **x8.00** | **x8.24** |
| `MULTI!` / splash | x3 | **x6.00** | **x6.24** |
| `POINT-BLANK` | x1 | **x2.50** | **x2.50** |
| `CHASE` / rundown | x2 | **x4.00** | **x4.24** |
| `PAYBACK` / revenge | x2 | **x4.00** | **x4.24** |
| shield soak | x1 | **x1.60** | **x1.60** |
| clutch heal | x1 | **x1.80** | **x1.80** |

`CLOSING TIME` deserves care: the function chooses 120% whenever the
**configuration flag** `winAsMultiplier` is true, and `awardDeed` passes that
flag at mint time. It does not know whether the earning seat will eventually
win. Thus x1.20 is the active base for both winners and losers in this manifest
(`src/ctf/glory.nim:3189-3200`; `src/ctf/sim.nim:510-521`).

Unchanged v3 bases inherit the old table: sprayed/bombed/rank-up x1;
assist/rescue/duo-down/tag-back/joint-act x2; steal/peel x4; denial x6; and
capture/wipe x8. Flag deeds are structurally unavailable on this flagless
variant. Placement has its own table, below. One kill still resolves to one
kill deed by precedence, so a longshot replaces rather than stacks with a
plain tag; `FIRST!` is the deliberate extra deed on the first hostile kill
(`src/ctf/glory.nim:3362-3385`; `src/ctf/sim.nim:3290-3293`).

### Territory, heat, and allies

The old enemy-ground `+1` integer rung is replaced by 15% of its logarithmic
magnitude. The exact lookup, keyed to the deed's **old** base, is:

| Old base | v17 territory multiplier |
|---:|---:|
| x1 or other | x1.00 |
| x2 | x1.06 |
| x3 | x1.04 |
| x4 | x1.03 |
| x6 | x1.02 |
| x8 | x1.02 |

The engine multiplies the v3 class percentage by this percentage and truncates
to an integer percentage. Because an ordinary tag's old base is x1, its new
x2.20 class still receives **no** territory bump
(`src/ctf/glory.nim:3155-3176`; `src/ctf/glory.nim:3189-3200`).

Heat is now **x1, x5, x14, x36** at the existing ember thresholds 0, 1, 2,
and 4 (`src/ctf/glory.nim:3147-3148`;
`src/ctf/glory.nim:1033-1046`). The cadence was not repriced: a positive-drama
deed adds one ember **after** pricing itself, embers cap at 11, and each 270-tick
quiet window removes two (`src/ctf/sim.nim:556-558`;
`src/ctf/sim.nim:249-259`; `src/ctf/glory.nim:1046-1064`). `CLOSING TIME` and
`LAST LIGHT` have zero drama, so they neither use nor add heat; ordinary tags,
First Blood, longshots, ace tags, splash, point-blank, and rundown do
(`src/ctf/glory.nim:919-978`).

The ally-stack ladder for `k = 1..6+` becomes **x1, x5, x7.5, x12.5, x20,
x32.5**, clamped at the ends (`src/ctf/glory.nim:3150-3153`;
`src/ctf/glory.nim:3183-3187`). In BR, another team counts only when it has an
active mutual pact with the killer's team and has a qualifying damage mark on
the same victim; unallied third-party damage does not create a stack
(`src/ctf/sim.nim:2840-2858`). An unpacted solo seat therefore always has
`k=1`.

### Fixed point, rounding, and the small-factor gate

The accumulator starts at `P = 1024`, representing score 1.0, instead of at
one (`src/ctf/glory.nim:2515-2544`;
`src/ctf/sim.nim:1057-1084`). For one v3 deed, the engine multiplies the
applicable class, heat, carry, and stack percentages as one rational and
truncates **once** to an integer event percentage `q`; it then folds

```text
P' = floor(P * q / 100)
score = floor((P / 2^friendly_fire_halvings) / 1024)
```

(`src/ctf/glory.nim:3202-3220`; `src/ctf/glory.nim:2993-3010`;
`src/ctf/sim.nim:330-339`). This preserves sub-integer score state across
events, but not exact rational state across events: every event percentage and
every product fold has an integer truncation.

There is an additional gate. `q <= 100` is identity; `100 < q < 200` is
**skipped**, not accumulated, while the unscaled product is below 64. Only
`q >= 200` can fold from the seed. At exactly `P = 64 * 1024`, a small factor
starts applying (`src/ctf/glory.nim:2938-2991`;
`tests/test_glory_s5_rig.nim:343-360`). Thus standalone x1.02 survival,
x1.30 Final 2, x1.60 shield, x1.80 heal, and x1.20 Closing Time are no-ops for
a low-scoring seat. Small class factors can still become effective if an
ally-stack lifts the combined event percentage to x2 or more.

### Shipping-code cap caveat

With `deedMintCaps` armed, `recutProductCap()` returns the raw value `2^24`
(`src/ctf/glory.nim:2642-2654`; `src/ctf/glory.nim:2801-2805`). The production
fold compares the **1024-scaled** `P` directly with that raw cap, then the score
reader divides by 1024. Therefore the maximum unhalved reported score in this
snapshot is:

```text
floor(2^24 / 1024) = 2^14 = 16,384
```

The percent-fold guard also tests `P >= floor(cap / q)` before computing
`floor(P*q/100)` (`src/ctf/glory.nim:2985-2991`). The equivalent cap condition
would include the factor 100, so this guard can clamp about 100 times too early.
This conflicts with the fixed-point headroom tests' own stated cap accumulator,
`RecutProductCapArmed * scale`
(`tests/test_glory_percent_scale_headroom.nim:296-308`).

A home-ground trace makes the impact concrete:

- First ordinary tag when it is not global First Blood: `1024 -> 2252`, reported
  score 2, ember 1. A second tag inside the heat window uses
  `220% * 500% = 1100%`: `2252 -> 24772`, score 24, ember 2. On the third tag,
  `q=3080`; `24772 >= floor(2^24/3080)=5447`, so it jumps to the cap and reports
  16,384.
- If the first tag is global First Blood, the tag first gives `P=2252` and
  ember 1. `FIRST!` then sees x5 heat, so its event factor is x20 and produces
  `P=45040`, reported score 43, ember 2. The next ordinary tag has `q=3080` and
  immediately trips the same premature cap.

The cap is observable through `GLORY_CAP_HIT` events
(`src/ctf/sim.nim:341-380`). These traces should be checked against the first
live v17 replays before treating intended, uncapped catalog calculations as
ladder forecasts.

The supplied forum fit, `2^a * 3^b` with constant per-tag x4/x8 effects, is
therefore a v15/v16 description and cannot be extrapolated into v17. Decimal
class percentages already break that factorization, and the value of an
ordinary v17 tag depends on its pre-deed heat, territory, pact context, and
whether the product-cap guard fires. Winning adds the same flat x8 only at
finalize; it does not change a tag's mint-time factor.

## 2. Placement ramp and continuous survival credit

| Finish event | v15/v16 | v17 |
|---|---:|---:|
| Final 8 | x2 | **x1.00** |
| Final 4 | x3 | **x1.00** |
| Final 2, both finalists | x4 | **x1.30** |
| Solo win, applied at finalize | x8 | **x8** |

The new placement percentages are literal 100/100/130
(`src/ctf/glory.nim:3013-3033`). The thresholds still fire once for every
surviving team when living-team count crosses 8, 4, and 2, including skipped
counts (`src/ctf/glory.nim:2781-2792`;
`src/ctf/sim.nim:6871-6914`). The winner then receives a composition-neutral
x8 after the conclusion sweep, with no heat, territory, carry, or stack
(`src/ctf/glory.nim:3241-3277`; `src/ctf/sim.nim:6124-6152`).

Survival credit is **per living-seat tick, not per zone phase**. During
`Playing`, each living seat increments `aliveTicks`; whenever the new value is
a positive multiple of 720, the engine attempts a 102% fold
(`src/ctf/sim.nim:8098-8146`). At 24 ticks/s this is every 30 seconds
(`src/ctf/sim_types.nim:849`; `src/ctf/glory.nim:3035-3046`). There is no
separate survival-mint cap. The seat stops receiving checkpoints on death and
the episode's `maxTicks=10000` bounds a continuously living seat to at most
`floor(10000/720) = 13` checkpoints
(`coworld_manifest_paintbot.json:1347-1351`).

For `T` elapsed **Playing** ticks, let

```text
n(T) = min(floor(T / 720), 13)
C = 2^24
S = 1024
```

At each of those `n` checkpoints the exact committed recurrence is:

```text
Pj = Pj-1                         if Pj-1 < 64*S
   = C                            if Pj-1 >= floor(C/102)
   = floor(Pj-1 * 102 / 100)      otherwise
```

For a zero-tag seat with no other factor-producing deeds, `P0=S`, so every
checkpoint takes the first branch. Final 8/4 are identities, and Final 2's
130% is also skipped below `64*S`. Its score is therefore exactly:

```text
non-winner: 1, for every T from 0 through 10000
winner:     8, for every T, after the finalize win factor
```

The test suite explicitly pins Final 2 as skipped from the scaled seed
(`tests/test_glory_s5_rig.nim:227-270`). If the product has already reached
64 before a checkpoint, the credit begins then; missed earlier checkpoints
are never replayed. Ignoring the separate premature-cap branch, 13 credits
have a nominal multiplier `1.02^13 = 1.2936066`; starting at exactly 64, the
13 integer folds produce raw `P=84770`, 1.29349 times the start, and report
82. This is a small post-combat tail, not a reward for hiding from the seed.

## 3. `brAssistRescueUngated` in solo BR

An `ASSIST` is not “any damage by anyone within 120 ticks.” The victim stores
only the **last enemy hit that left it alive**; a finishing hit is never stored
(`src/ctf/sim_types.nim:3449-3459`;
`src/ctf/sim.nim:4265-4281`). At death, that stored damager receives an assist
only if all of these hold:

1. it is a valid seat other than the killer;
2. its stored hit is at most 120 ticks old; and
3. its literal team equals the killer's team.

The switch removes only the former “not BR” mint gate
(`src/ctf/glory.nim:1706-1713`; `src/ctf/sim.nim:3238-3262`). The payment is
the unchanged assist base **x2**—x2.12 on enemy ground—and it takes the team's
current heat because assist has positive drama (`src/ctf/glory.nim:2573-2576`;
`src/ctf/glory.nim:919-946`). It does **not** require a pact, and an active pact
does not satisfy the same-team test.

Accordingly, `ASSIST` is structurally impossible in this 16-one-seat-team
variant. Damage a pact ally contributes to somebody else's kill may instead
qualify as `JOINT ACT`: at least two teams must hit the same victim in the
120-tick incident, and each paid contributor must have an active pact with
another contributing team. `JOINT ACT` pays x2 and is not a heat deed
(`src/ctf/sim.nim:2860-2897`; `src/ctf/sim.nim:2915-2946`;
`src/ctf/glory.nim:963-970`).

`RESCUE` is ungated by the same switch, but it likewise retains a literal
same-team teammate predicate and requires that teammate to remain alive. It is
also impossible for a one-seat team; a pact ally does not substitute
(`src/ctf/sim.nim:3263-3285`).

## 4. `pactScopedWipeDown`

An active pact group is the victim's team plus every team with which it holds
a mutual pact (`src/ctf/sim_state.nim:219-248`). On a hostile kill, if the
victim belonged to a group of at least two teams, the killer is outside that
group, and the kill empties the victim's own one-seat team:

- if at least one other member of the victim's pact group remains alive, the
  killer receives `DUO DOWN`, base **x2** (x2.12 on enemy ground);
- if the kill leaves the whole victim pact group with no living member, the
  killer receives `WIPEOUT`, base **x8** (x8.16 on enemy ground).

This is scope over the **target's opposing pact**, not a requirement that the
killer have allies. Once selected, `pactForced` makes the pact deed beat the
ordinary resolved kill deed; a stronger already-selected zone marquee can
still prevent a lower-base `DUO DOWN` from being selected
(`src/ctf/sim.nim:3133-3179`). In particular, a pact `DUO DOWN` can replace a
longshot even though v17 prices longshot at x6; the regression test pins that
exact shadowing result (`tests/test_glory_s5_rig.nim:362-375`). An unpacted
victim has a group of one, so ordinary solo-vs-solo kills are unchanged.

This target-side rule is separate from the attacker's ally stack. If the
killer and its own pact ally co-damaged the victim inside the incident window,
the resulting kill deed can also receive the attacker-side `k=2`, x5 stack.
Any actual damage between pact partners immediately dissolves their pact
(`src/ctf/sim.nim:3515-3539`).

## 5. Ladder standing: clamp and EMA

The checked-in ladder audit records the live served configuration fetched on
2026-09-08 as `sum_top_k=12`, `rated_k=0.05`, and
`rated_clamp_multiple=150.0` (`docs/designs/STANDING_SWEEP.md:17-33`;
`tools/ladder/standing_replay.py:8-27`;
`tools/ladder/standing_replay.py:74-84`). For an entrant with previous
standing `s`:

```text
round_score = sum(the entrant's top 12 episode scores in the round)
input       = clip(round_score, s/150, 150*s)   # after the first round
new_s       = s + 0.05 * (input - s)
```

The first observed round initializes the standing from its score; subsequent
rounds retain 95% of the old standing and take 5% of the clamped input. The
replay implementation is at `tools/ladder/standing_replay.py:303-340`. Thus
150 is a multiplicative clamp on the **round input relative to the prior
standing**, not a maximum standing. `k=0.05` has a round half-life of
`ln(0.5)/ln(0.95) = 13.51` rounds
(`docs/designs/STANDING_SWEEP.md:54-63`).

This is confirmed from the served settings and exact replay, not from a
checked-in production backend. The audit explicitly says the accessible
backend source implements a different wall-clock EWMA and contains none of
these fields (`docs/designs/STANDING_SWEEP.md:35-50`;
`tools/ladder/standing_replay.py:29-42`).

Losing seats do feed this ladder: the engine now banks each concluded seat's
own team ledger without a `playerWon` gate
(`src/ctf/roster.nim:1018-1050`). Under the v17 cap behavior above, one episode
can report at most 16,384 before friendly-fire halvings, so even twelve capped
legs sum to at most 196,608. That is a consequence of the e6807465 arithmetic,
not of `rated_clamp_multiple`.

## 6. Design implications for the solo recipe

### Answers to the policy questions

**Does v17 reward survival more? No, not directly.** The old finish line gave
a survivor cumulative x2*x3*x4 = x24 before the solo x8 win factor. v17 gives
x1*x1*x1.3, and the x1.3 plus every x1.02 survival checkpoint are skipped for
a no-deed seat. Against the supplied v15/v16 field rungs, a zero-tag winner
could carry the placement/win multiple; the controlled v17 zero-deed winner is
only 8. A safer late posture remains useful to preserve a good leg and chase
the x8 win when below cap, but elapsed survival and middle placement do not
pay a hider. Once already capped, even the win fold cannot increase score.

**Do tags in losses justify fighting rather than hiding? Yes, for selective
fights.** Every loser banks its product, a hider stays at 1, a standalone
ordinary tag reports 2, a two-tag heat chain reports 24, and a three-tag chain
hits the committed 16,384 cap. Global First Blood makes the first ordinary
kill report about 43 and the next heat-chained tag cap. The new top-12 round
sum also discards weak legs, favoring a chance at a strong combat leg over
reliably banking 1. This does not make every fight good: a lone tag is a small
return for dying, and a low-product `CLOSING TIME` kill can be entirely skipped
because its x1.20 base is below the small-factor gate.

**Is heat chaining repriced? Its timing is unchanged, but its magnitude is
radically higher.** Thresholds remain 1/2/4 embers and cooling remains two
embers after each 270 quiet ticks; the rungs move from x1/x2/x4/x8 to
x1/x5/x14/x36. The current deed sees the old ember count and increments heat
afterward. This makes `jackal` conversion inside a streak much more valuable,
although the cap bug makes additional score after two or three chained tags
zero.

**Longshot versus ordinary tag.** At the 1300-pixel live gun, longshot remains
`floor(700*1300/1050) = 866` pixels or farther
(`src/ctf/glory.nim:1538`; `src/ctf/glory.nim:1614-1622`;
`src/ctf/glory.nim:3345-3357`). On home ground it is x6 versus x2.2, or
**2.727x** an ordinary tag. On enemy ground it is x6.24 versus x2.2, or
**2.836x**. The same heat and ally-stack multipliers cancel in that ratio.
This is a smaller relative premium than v15/v16's x3 versus x1 at home and x4
versus x1 on enemy ground, even though the longshot's absolute base doubled.

### Ranked recipe changes

Each should be measured as a one-variable experiment against the current
`target_law > supply_run(guarded) > loot(guarded) > edge_ride` ladder and its
jackal recalls (`research/s2_patches/recipes/v186-solo-supply-clearance.env:1-3`).

1. **Delete the opening `target_law.holdTrigger:{"zonePhase":1}`; keep
   `prefer:["weakened","isolated"]`.** The hold currently permits only return
   fire until it releases (`docs/designs/BR_PLAYS.md:96-104`). Competing for
   First Blood now has an unusually large payoff because the normal deed adds
   ember 1 before the separate x4 First Blood deed, which therefore sees x5
   heat. This is the cleanest one-variable way to expose that opportunity.

2. **Advance the existing guarded jackal recall from tick 900 to about tick
   420; keep `earshot:700`, `joinWhen:"afterKill"`, `exitAfter:{"hpFloor":2}`,
   and the current distance/HP guard.** This preserves the tested safety shape
   while making cheap third-party conversions available from the first shrink
   instead of waiting another 480 ticks. `jackal` is explicitly the
   loiter/join-cheap/leave-with-profit controller
   (`docs/designs/BR_PLAYS.md:89-94`). Its value now comes from converting two
   kills inside heat windows, not from accruing survival ticks.

3. **Run a conditional one-partner `pact` experiment only with a known
   reciprocal declarer.** Add `pact{partners:["$PARTNER"], protect:true,
   onBetrayal:"returnFire"}` above `target_law` and exclude that partner from
   targeting. A single co-damaging ally changes the kill stack from x1 to x5
   and can mint a separate x2 `JOINT ACT`; it also creates a real revive window
   for one-seat teams (`research/s2_combat_model.md:124-128`). With no
   reciprocal declaration it provides none of those scoring effects, so a
   blind pact slot is not justified.

Keep the guarded `supply_run` and `loot`: healing and equipment now buy more
combat opportunity, while their enemy-clearance guards keep them from
interrupting contact. Keep `edge_ride` as the default controller rather than
shipping strict longshot `lane_warden{margin:240, standoffMin:866,
standoffMax:1250, coverRadius:260, hpFloor:2}`. The latter deliberately holds
866-1250 range (`bot/plays/lane_warden.nim:7`;
`bot/plays/lane_warden.nim:267-318`), but its prior pooled test traded kill and
win rate for a fatter tail (`research/LEDGER.md:6299`), and v17 reduces the
longshot's relative premium. Likewise, do not revive bounty-first solely for
the x9 headline: the non-enemy ace/tag ratio moved from 4.0 to only 4.09, while
the earlier bounty test materially reduced kills and wins
(`research/LEDGER.md:6315`).
