# Paintbot solo BR: where the large Glory legs come from

Source snapshot: coworld-ctf commit
`e68074652e63c5651a1c2aa2148edc2bba5ddcc1`, the `GloryVersion = 17`,
`GameVersion = 62` snapshot analyzed in `research/s2_glory_v17.md`. The active
`battle-royale-s2` manifest arms `catalogV3Reprice`,
`gloryFixedPointScale`, `placementRampV3`, `brAssistRescueUngated`, and
`pactScopedWipeDown` as well as the older multiplier, win-factor, and mint-cap
switches.

## Executive answer

The hosted million-point examples are **not v17 legs**. Rounds 4594, 4596,
4597, and 4603 ran coworld `0.7.374`, GameVersion 61, without the five v17
flags. They use the v15/v16 integer economy. The first supplied replays with
all five flags are rounds 4612 and 4613 on coworld `0.7.377`, GameVersion 62.

That distinction reverses the initial hypothesis:

- In v17 there is **no positive post-cap multiplier**. Deeds, heat, territory,
  ally stack, curriculum achievements, placement, survival, Clean Sheet, and
  the solo win x8 all fold into the same capped `gloryProduct`.
- The only operation outside that cap is the friendly-fire division. With `h`
  charged incidents, the reported score is
  `floor((gloryProduct / 2^h) / 1024)`.
- The raw cap is still `2^24` while the accumulator is scaled by 1024. Thus an
  unhalved v17 seat can report at most **16,384**. Once it is there, winning or
  earning another achievement cannot make it 100k, 1M, or 7M.
- The engine can report Glory for a loser, but the league bank gate still pays
  only the winning team. At cap the win x8 has no marginal arithmetic value,
  yet winning remains mandatory for the 16,384 to count on the ladder.
- The result badges `spotless`, `sniper`, `silent`, `banksy`, `almost`, and so
  on are display/profile achievements. They are evaluated **after** the Glory
  product and win factor are finalized. Their manifest `points` do not enter
  Glory. They merely correlate with the actual scoring acts.
- The score-bearing achievement with the confusingly similar name is Gun V
  **Longshot**: make a kill from at least 866 px. In v17 its curriculum claim
  is x2, or x3.46 when that `(tree, tier)` is first claimed in the lobby. The
  kill also gets the separate Longshot deed, normally x6 before heat and other
  context.

The equality `7,077,888 = 16,384 x 432` is therefore arithmetic coincidence,
not a v17 cap followed by x432. That round used the old unscaled product and
never hit its `2^24 = 16,777,216` cap.

## 1. The exact v17 score pipeline

Let `P` be the fixed-point product and `h` the friendly-fire halving count.
The episode starts at `P = 1024`, representing 1.0 Glory. Every positive fold
updates this same value, subject to the same raw cap `C = 2^24`:

```text
percent factor q: P <- min(C, floor(P*q/100))
whole factor m:   P <- min(C, P*m)
reported score:   floor((P / 2^h) / 1024)
```

The implementation's percent-fold precheck is stronger than that formula: it
tests `P >= floor(C/q)` rather than accounting for the `/100`. It can jump to
the cap roughly 100 times too early. For example, round 4613's daveey-1 winner
had `P = 70,262` before a 346% first Gun-V claim. Honest multiplication would
produce only 243,106 raw, but `70,262 >= floor(2^24/346)`, so the guard emitted
`GLORY_CAP_HIT` and set `P = 16,777,216`. This is why approximately three
chained ordinary tags can already report 16,384.

All locations below refer to the v17 snapshot: the common product is wired in
`src/ctf/sim.nim:329-381,383-528,591-631`; the cap and percent fold are in
`src/ctf/glory.nim:2642-2667,2938-2995`; conclusion achievements and the win
fold are in `src/ctf/sim.nim:6102-6154`.

### Every fold in or outside the cap

| Source | v17 multiplier | How it is earned | Relation to cap |
|---|---:|---|---|
| Kill/deed class | Table below | The single deed selected for a kill, or another deed event | Folded into `P` before the cap |
| Territory | x1.02-x1.06 on eligible enemy-ground deeds | Deed occurs on enemy-painted ground | Combined into that deed's `q`, before cap |
| Heat | x1/x5/x14/x36 | Positive-drama chain at 0/1/2/4+ embers | Combined into that deed's `q`, before cap |
| Carrier | x2 | Positive-drama deed while carrying a heart | Before cap; impossible on this flagless variant |
| Pact ally stack | x1/x5/x7.5/x12.5/x20/x32.5 | `k=1..6+` allied teams in the victim's damage incident | Combined into the kill deed's `q`, before cap |
| Curriculum tier I-V | x1/x1/x2/x1.05/x2 | Satisfy the tier gate listed below | Same `P`, before cap |
| First Tier-V claim | x3.46 total instead of x2 | Be the first team, including same-tick ties, to claim that particular tree's Tier V | Same `P`, before cap |
| Final 8 / Final 4 | x1 / x1 | Be alive at the crossings | Same `P`; score-neutral |
| Final 2 | x1.30 | Be one of the last two teams | Same `P`; skipped while score accumulator is below 64 |
| Survival | x1.02 every 720 living ticks | Remain alive through a 30-second checkpoint | Same `P`; skipped while below 64 |
| Solo win | x8 | Be the one-seat winning team | Same `P`, last positive fold at finalize |
| Friendly incident | divide by 2 each | Same-team or pact-friendly harmful down | **Outside** cap and scale; the sole post-cap operation |
| End-card badge | no Glory factor | Win and meet its badge predicate | Recorded after scoring; not in `P` |

The 100-199% factors have a separate small-factor gate. While
`P < 64*1024`, they are skipped entirely. Consequently Closing Time x1.20,
shield x1.60, clutch heal x1.80, Tier IV x1.05, Final 2 x1.30, and survival
x1.02 do nothing to a low-product seat. Once the seat reaches 64 they can
apply—unless the premature cap precheck clamps them first.

### Deed classes available to a solo BR seat

The v17 base classes are in `src/ctf/glory.nim:3106-3137`. A kill selects one
primary deed by precedence; it does not multiply all matching descriptions.
Global First Blood is a separate deed and can stack with that first kill.

| Deed | Base | Notes |
|---|---:|---|
| Ordinary gun `TAG` | x2.20 | No territory bonus because its old class was x1 |
| Ordinary spray / grenade kill | x1 | Still advances counters and tiers, but no direct factor |
| `FIRST!` | x4 | Separate first-hostile-kill deed; is priced after the kill deed raises heat |
| `POINT-BLANK` | x2.50 | One-kill-one-deed replacement for the ordinary class |
| `LONGSHOT` | x6 | Kill at least 866 px away; also unlocks Gun V |
| `MULTI!` | x6 | Multi-kill splash event |
| `PAYBACK` / revenge | x4 | Revenge condition |
| `CHASE` / run-down | x4 | Run-down condition |
| `BOUNTY` / ace | x9 | Kill an Ace-level target |
| `CLOSING TIME` | x1.20 | Kill while the zone is actively shrinking; small-gated and has no heat |
| `LAST LIGHT` | x8 | Kill in the final authored zone phase; has no heat |
| Shield soak | x1.60 | Small-gated; first three scoreable mints only |
| Clutch heal | x1.80 | Small-gated; the port's normal path is effectively absent/tombstoned |
| `TAG BACK` | x2 | Revive through the tag-back path; a pact can make this reachable; first three scoreable mints |
| `JOINT ACT` | x2 | Formal-pact co-damage incident; first six scoreable mints per team |
| Pact member down | x2 | Kill a member of an opposing live pact group; first four `dDuoDown` mints |
| Pact-group wipe | x8 | Kill the last living member of an opposing pact group |
| Assist / rescue | x2 | The v17 switch removes the BR ban, but the predicates still require a **literal teammate**, not a pact ally; unavailable to a solo team |
| Rank-up | x1 | No score |
| Flag classes | x2-x8 | Structurally unavailable on the flagless BR map |

For eligible old bases, enemy-ground territory adds x1.06 (old x2), x1.04
(x3), x1.03 (x4), or x1.02 (x6/x8), truncated as part of the event percentage.
Heat then contributes x1/x5/x14/x36 on deeds whose drama is positive. The
current ember thresholds are 0/1/2/4+, and quiet periods decay heat. Thus two
ordinary unallied home-ground tags chain as
`1024 -> 2252 -> 24,772`; the third uses `220%*1400%=3080%` and trips the
premature cap guard. First Blood accelerates this because it is a second fold
after the first kill and sees the newly raised heat.

`JOINT ACT` requires at least two distinct attacking teams to damage the same
victim in one 120-tick incident. Each paid contributor must have an active
mutual pact with another contributor. It gives x2 in the same product. On a
qualifying kill, a single pact partner in the incident also changes ally-stack
`k` from 1 to 2, adding x5 to that kill event; taken together, Joint Act plus
the stack can supply about x10 before the shared cap. `pactScopedWipeDown`
also makes the victim's opposing pact group a target: a member down can select
x2 and the group-ending kill can select x8. These remain primary deed choices,
not extra post-kill multipliers.

There is a live pact-friendly-fire edge. `downFriendly` treats a pact ally as
friendly, but the down path calls `awardDeed(victim.team, dTeamKill, ...)` in
`src/ctf/sim.nim:2677-2768`. In a cross-team pact this charges the **victim's**
product, not the attacker's. A pact ally downing this bot can therefore halve
this bot's capped score. Any pact experiment must measure that downside as
well as Joint Act and the stack.

## 2. Score-bearing curriculum achievements

These are not the achievements array in hosted results. They are internal
one-shot `(tree, tier)` claims folded into Glory by `claimAchievement`.
Every tree uses the same v17 tier factors:

```text
Tier I x1; Tier II x1; Tier III x2; Tier IV x1.05;
Tier V x2, or x3.46 total for the first lobby claim of that tree's Tier V.
```

“First” is tracked per `(tree, tier)`, and all teams satisfying it on the same
tick share first credit. The old v15/v16 Tier V was x4, or **x12** for first;
that old x12 is the large factor in the million-point replay legs. In v17 the
sqrt reprice makes the combined first Tier-V claim 346%, not `x2*x3`.

The gates come from `src/ctf/glory.nim:1934-2204` and
`src/ctf/sim.nim:680-785`:

| Tree | I | II | III | IV | V | Solo flagless status |
|---|---|---|---|---|---|---|
| Gun | First Tag: 1 gun kill | Marksman: 3 gun kills | Bounty: kill an Ace-level enemy | Sharpshooter: reach rank L5 | Longshot: kill at >=866 px | All reachable |
| Spray | First Coat: 1 spray kill | Full Coverage: 2 spray kills | Repainted: 2 from one pickup | Muralist: 3 from one pickup | Double Splash: one spray activation kills 2+ | All reachable in principle |
| Grenade | Delivery: 1 grenade kill | Splatterbomb: 2 grenade kills | Blast Radius: 1 multi-kill blast | Double Blast: 2 multi-kill blasts | Bombardier: 3 grenade kills | All reachable in principle |
| Backup/teamwork | Cover Fire: assist | Escort Duty: kill while teammate carries | The Save: rescue teammate | Second Wind: be rescued, then kill in time | Squad Volley: 3 distinct teammates kill in the window | Unreachable for a one-seat literal team; pacts do not substitute |
| Provider/medkit | First Delivery | Clutch Delivery | Regular Route | Emergency Route | Supply Chain | Entire tree omitted on this port because the supply-share field is absent |
| Carrier | Hands On: contested steal | Fighting Carry: carry kill | Double Steal | Hard Carry | Delivered: capture | Unreachable on flagless BR |
| Defender | Peel carrier | Doorstep denial | Double Peel | Turnaround peel-to-steal | Lockdown: 2 denials | Unreachable on flagless BR |
| Squad | Kitted: convert 2 kit legs | Full Loadout: convert 3 | Full Kit | Clean Sheet: zero team kills for the whole game | Victory Lap: all implemented legs plus capture | Kitted is reachable via grenade+spray kills; Full Loadout needs an assist and is not; Full Kit is tombstoned; Clean Sheet is reachable; Victory Lap is flag-gated |

Clean Sheet is specifically **zero `teamKills`**, not “take no damage.” It is
checked for every team in the conclusion sweep before the win factor. In v17
it attempts x1.05 in the capped product and is usually either skipped below 64
or saturated at the cap. It is distinct from the winner-only `spotless` badge.

## 3. Result badges: complete catalog and no Glory value

`finishGame` calculates these only for the winner after the conclusion sweep,
the x8 win fold, and reward bookkeeping (`src/ctf/sim.nim:6250-6383`). They
have no tiers, no first-claim bonus, and no Glory multiplier. The manifest
points are account-achievement points, not factors in `teamGlory`.

| Badge | Manifest points | Exact win-gated predicate | Solo BR status |
|---|---:|---|---|
| `pacifist` | 25 | No attacks | Impossible in BR because the engagement gate then fails |
| `spotless` | 25 | Zero damage taken; shield-absorbed damage counts; must be engaged | Reachable; **x1 Glory** |
| `almost` | 50 | Team life budget below 2 HP at the end | Reachable; **x1 Glory** |
| `grenadier` | 30 | At least 80% of nonzero dealt damage from grenades | Reachable; **x1 Glory** |
| `rambo` | 40 | At least 9 kills in one life | Reachable but extreme in a 15-opponent lobby; **x1 Glory** |
| `medic` | 30 | Pick up at least 4 medkits in one life | Map/supply dependent; **x1 Glory** |
| `sniper` | 30 | Exactly 100% of nonzero dealt damage from the gun | Reachable; says nothing about range; **x1 Glory** |
| `banksy` | 30 | At least 90% of nonzero dealt damage from spray | Reachable; **x1 Glory** |
| `pack` | 40 | Every cog spends at least 90% of alive ticks near at least 2 literal teammates | Impossible for a solo team; pacts do not count |
| `pit-master` | 40 | At least 90% of dealt damage was dealt while standing in a pit/trench | Map dependent; **x1 Glory** |
| `heist` | 50 | Winning terminal capture and zero kills | Impossible on flagless BR |
| `silent` | 30 | No applied shout during the game | Reachable; **x1 Glory** |
| `assassin` | 50 | At least 10 gun/grenade first-touch killshots | Reachable but extreme; **x1 Glory** |
| `lucky` | 40 | Be caught in and survive at least 5 grenade blasts | Reachable; **x1 Glory** |

This explains the misleading hosted correlation. A winner using only gunfire
often has `sniper`; a long-range gun kill can also mint the real Longshot deed
and Gun-V tier. But `sniper` itself contributes nothing. The same is true of
`spotless`, `silent`, `banksy`, and `almost` in the named legs below.

## 4. Exact factorizations of the named legs

For the v15/v16 rows, “combat/deed core” and “lifecycle factors” are a useful
explanatory split, but not an implementation boundary: every factor still
folded into one unscaled product. Multiplication commuted because these legs
did not hit the old 16,777,216 cap. Event traces were reconstructed by
deterministically replaying the supplied files against their matching engine
commit; `report.json` alone does not expose the Glory deed feed.

| Score | Era and evidence | Exact factorization | What actually supplied it |
|---:|---|---|---|
| **7,077,888** | v16, r4597, soft-codexter-t2, 4 kills | `1,536 * (12*2*3*4*2*8)` = `1,536*4,608` | Deeds `FIRST! x6 * LONGSHOT x16 * CLOSING x4 * CLOSING x4 = 1,536`; first Gun-V Longshot x12; Final8/4/2 x2/x3/x4; Clean Sheet x2; win x8. End badges spotless/sniper/silent: x1. |
| **3,538,944** | v16, r4594, Games Bond, 5 kills | `768 * (12*24*2*8)` = `768*4,608` | Four Closing deeds and one Longshot: `4*3*4*4*4=768`; first Gun V x12; placement x24; Clean Sheet x2; win x8. Badges spotless/sniper/silent: x1. |
| **3,145,728** | v16, r4596, Lawrence, 6 kills | `2,048 * (4*24*2*8)` = `2,048*1,536` | Longshot x8 and four Closing deeds x4: `8*4^4=2,048`; non-first Gun V x4; placement x24; Clean Sheet x2; win x8. Badges almost/sniper/silent: x1. |
| **1,474,560** | v16, r4594, Jordan, 4 kills | `320 * (12*24*2*8)` = `320*4,608` | Three Closing deeds x4 and Last Light x5: `4^3*5=320`; first Spray-V Double Splash x12; placement x24; Clean Sheet x2; win x8. Badges banksy/silent: x1. |
| **1,179,648** | v16, r4603, soft-codexter-t2, 4 kills | `3,072 * (24*2*8)` = `3,072*384` | The raw result and exact replay URL exist in `research/br_rounds`, but the replay body is not present locally. The 3,072 pre-lifecycle core is exact. It can be `256 deeds * first Tier-V x12` or `768 deeds * non-first Tier-V x4`; score, kills, and sniper/silent badges do not distinguish them. Claiming one is not evidence-safe without that replay. |
| **491,520** | v15/v16 shape; observed r4475 winner | `1,280 * (24*2*8)` = `1,280*384` | Ordinary identity kill, four Closing x4, Last Light x5: deed core `4^4*5=1,280`; placement x24; Clean Sheet x2; win x8. Other legs with the same total can factor differently. |
| **73,728** | v15/v16 shape; observed r4481 winner | `192 * (24*2*8)` = `192*384` | Joint Act x3 plus three Closing x4: deed core `3*4^3=192`; placement x24; Clean Sheet x2; win x8. The hosted 4-kill median value is a value class, not proof every 73,728 leg has this event sequence. |
| **24,576** | v16, r4596, Games Bond winner | `64 * (24*2*8)` = `64*384` | Three Closing x4 give deed core 64; placement x24; Clean Sheet x2; win x8. |
| **16,384** | v17, r4613, daveey-1 winner, 3 kills | `floor(C/1024) * 1 = 16,384`, `C=2^24` | Honorable tag 220%, heat-5 enemy Longshot 3,120%, then first Gun V 346% triggers `GLORY_CAP_HIT`. Later survival, placement, Clean Sheet, and win x8 all remain inside the saturated product and add **no** marginal score. No friendly halving. |
| **99** | v17, r4618 metadata, Jordan winner, 3 kills; replay body absent locally | `floor((floor(floor(1024*624/100)*200/100)*8)/1024)` = `floor(102,224/1024)` = **99** | A code-consistent exact decomposition is: two early Closing 120/127% folds skipped below 64; enemy-ground Longshot 624% gives `P=6,389`; non-first Gun V 200% gives `12,778`; other sub-200% folds remain skipped; win x8 gives `102,224`. No cap or friendly halving. Badges spotless/sniper/silent: x1. The missing replay prevents event-feed confirmation. |

Round 4618's “17 kills” was the submitted policy's aggregate over the hosted
round's episode batch, not one solo team's kills in the 99-point episode. The
winning Jordan seat had three kills. Its first two were low-accumulator Closing
Time events and therefore score-neutral under the small-factor gate; the third
was the Longshot in the exact arithmetic reconstruction above. That event
assignment is not replay-confirmed because r4618's replay body is also absent
locally.

The r4603 limitation is worth keeping explicit. Its metadata identifies the
exact S3 replay object and confirms the 4-kill win plus sniper/silent, but the
body was not downloaded into either supplied replay tree. Those facts prove
the `3,072*384` boundary, not which of the two Tier-V decompositions produced
3,072. The other four named million-point legs are fully confirmed from local
event traces.

## 5. What makes a v17 seat bank 16k, 100k, 1M, or 7M?

Under the code and realized v17 configuration analyzed here:

- **16k reported:** reach raw `P=C` and suffer no friendly halving. Roughly
  three chained ordinary tags do it because of heat plus the faulty cap
  precheck; two high-context kills or a Longshot plus first Tier V can also do
  it. **16k banked:** do all of that and win, because the league gives losers
  zero even when the engine reports their product.
- **8k / 4k / ... reported:** reach the same cap, then incur one/two/etc.
  friendly halvings. Banking again requires the win. In solo BR the realistic
  cross-team halving route is a pact ally downing this seat, with the
  victim-charging behavior described above.
- **100k, 1M, 7M:** impossible under this v17 scoring path. They are historical
  v15/v16 legs, or evidence of a different realized config/build. A newly
  observed score above 16,384 should trigger a version/config audit, not a
  search for a hidden post-cap achievement.

Before cap, the ranked concrete behaviors are:

1. **Chain hostile tags quickly.** An ordinary tag is x2.20, then heat makes
   the next one x11 and the third nominally x30.8. Global First Blood adds a
   separate base x4 deed that sees the heat raised by its kill, often about
   x20 on the first sequence. This is the simplest cap route.
2. **Create real longshots, not `sniper` badges.** A kill from >=866 px gives a
   base x6 Longshot deed (x6.24 on enemy ground), multiplied by current heat
   and a pact stack, and unlocks Gun V x2 or first x3.46. The end-card sniper
   badge adds x1.
3. **Keep win probability.** Below cap, the solo win fold is x8 and is the
   largest deterministic lifecycle factor. At cap its marginal factor is x1.
4. **Avoid friendly incidents.** Every charged incident divides the eventual
   result by 2 outside the cap. With a pact, specifically avoid being downed
   by the partner until the victim-charging implementation is fixed.
5. **Use a reciprocal pact only if it produces shared fights.** Joint Act is
   x2, and one marked pact partner changes the kill's ally stack to x5. A
   co-damage conversion can therefore cap very fast. Merely holding a pact
   gives no score, and betrayal exposes the outside-cap halving risk.
6. **Prefer enemy pact members when visible.** Their member-down deed is x2;
   wiping the last member of that opposing pact group is x8. These are inside
   cap and compete with other kill deeds by precedence.
7. **Treat placement, survival, and clean play as tie-break support.** Final 2
   is only x1.30, survival is x1.02/checkpoint, and Clean Sheet is x1.05. All
   are skipped below 64 and saturated at 16,384. Do not sacrifice a tag or win
   to farm them, and do not target spotless/silent/banksy/almost for Glory.

## 6. Top three one-variable policy changes

Baseline ladder: `target_law > supply_run(guarded) > loot(guarded) >
edge_ride`; recalls at tick 900 add guarded `jackal`. These proposals each
change one variable and preserve that structure.

1. **Remove only the opening `holdTrigger`.** Expected mechanism: start moving
   and acquiring targets immediately, increasing the chance of global First
   Blood and of being first to the Gun-V claim. First Blood is base x4 and is
   priced after the primary deed raises heat, so the opening combination can
   be about x20; a first Gun-V claim is x3.46. More importantly, early nearby
   kills begin the x2.2/x11/x30.8 tag chain before the field thins. The v188
   eight-episode syntax/smoke screen was safe (`0.62` kills/seat, `9%` wins),
   but is far too small to be a measured win.
2. **Change only the guarded-jackal recall from tick 900 to tick 420.** Expected
   mechanism: join damaged-target incidents while the lobby is dense enough
   to obtain second/third tags, keep heat inside its 270-tick window, and
   convert opponents before zone play dominates. This targets the actual cap
   path rather than result badges. The v189 eight-episode screen was also safe
   (`0.72` kills/seat, `9%` wins), not a verdict.
3. **Add only a reciprocal `pact` overlay to every existing call, targeting a
   known willing declarer such as Lawrence/`lw-pax`.** Expected mechanism:
   shared damage yields Joint Act x2 and changes a qualifying kill's ally
   stack from x1 to x5; it also enables tag-back revives and exposes opposing
   pact-group down/wipe deeds. Round 4612-4613 calls show Lawrence repeatedly
   naming this seat, so reciprocity is plausible rather than hypothetical.
   Measure active-pact duration, co-damage incidents, Joint Acts, stack-kills,
   revives, and pact-friendly downs. The last counter matters because a pact
   ally can halve the victim's capped bank. The v190 smoke proved only that
   the calls and roster-name resolution were accepted.

These should be hosted as separate A/Bs, not bundled. The custom
`lane_warden` is the fourth choice, not a top-three v17 change: the prior
24-episode pooled screen traded lower kills/wins (`0.76` kills/seat, `8%`
wins versus about `0.88`, `10%`) for a fatter old-economy tail. V17 saturates
that tail at 16,384, reducing the value of sacrificing conversion and wins for
extreme standoff. If revisited, test it alone and judge cap-hit rate plus
winning capped legs, not mean score from old-economy outliers.

## Bottom line

The old giant legs were a product of deed heat, a first Tier-V x12, the
x2*x3*x4 placement ladder, Clean Sheet x2, and win x8. Their visible badges
were passengers. V17 removes that million-point ladder: all positive value is
inside a prematurely clamped fixed-point product, and only friendly-fire
division survives outside it. The policy objective is therefore **reach
16,384 early, avoid being halved, then win**—not collect `sniper`, `spotless`,
or `silent` after the fact.
