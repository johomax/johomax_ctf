# v153 hosted replay analysis: rounds 4480–4485

## Verdict

`jordan-ctf-candidate:v153` is already the highest-kill policy in this six-round field: **83 kills in 72 episodes (1.153/episode)**, versus 0.724 for `apex:v38`, 0.595 for `Monet:v42`, and 0.877 for `daveey paintbot-huddle:v159`. Its remaining problem is not finding ordinary fights. It is converting survival into the late, multiplied kills that make a jackpot.

The best next one-variable test is to change both recalled `edge_ride.margin` values to **240**. Zone deaths were 21/52 archived deaths, 20 happened while the seat was moving, and the three dud episodes that survived into phase 5 ran at a median geometric zone clearance of only 3 px, versus 71 px for jackpot survivors and 83 px for middling survivors. This is a late-rescue problem, not a general inactivity problem.

The reported jackal freeze is real under the verified cached-ladder semantics, but it was small in this cohort: four episodes, four bouts, 180 ticks total (7.5 s), and no kill or death during a bout. It is worth retaining as a diagnosis and regression check, but changing jackal is not one of the top three tests from these data.

Ranked one-variable tests:

1. Recalled `edge_ride.margin`: `140/120 -> 240/240`.
2. `target_law.prefer`: `isolated -> bounty`, retaining `weakened` first.
3. Replace the bottom `edge_ride` rung with `lane_warden(240,866,1250,260,2)` as one categorical treatment.

These are experiment priors, not measured uplifts. The plausible effects are respectively **+0.03 to +0.10**, **0.00 to +0.05**, and **-0.03 to +0.08 kills/episode**; each tail-oriented test could add roughly **0–3 percentage points** to the observed 9.7% jackpot rate. Test them separately.

## Data and method

The evaluated policy is the exact call schedule in [v177-solo-hpfrac-fixed.env](s2_patches/recipes/v177-solo-hpfrac-fixed.env), hosted as `jordan-ctf-candidate:v153`:

- opening: `target_law(hold zonePhase 1) > supply_run(hp_frac < 0.3) > loot(guarded) > edge_ride(420,320,1.0)`;
- tick 900: the same target/supply/loot rungs, then guarded `jackal(earshot=700, afterKill, hpFloor=2)`, then `edge_ride(140,80,0.5)`;
- tick 1500: no loot, the same guarded jackal, then `edge_ride(120,80,0.9)`.

Hosted result JSON covers **72 v153 seat-episodes**, 12 in each of rounds 4480–4485. Raw replay coverage is **61/72**: all v153 episodes except 11 from round 4482. The archive contains 66 total episode replays because each round also has one non-v153 episode replay, except round 4482, where only one replay is present. The missing v153 rows comprise one jackpot, one middling result, and nine duds; therefore hosted score and opponent comparisons use all 72 rows, while tick-, position-, HP-, intent-, and distance-level claims use the 61 archived v153 replays.

I parsed annotations with the semantics of [s2_replays.py](../analysis/s2_replays.py) and deterministically re-simulated positions and HP following [s2_replay_positions.py](../analysis/s2_replay_positions.py), against the pinned GV59 engine. Every available replay passed its manifest/hash validation. Kill totals in the 61 replays are 73, exactly matching the hosted result rows for those same seats. Cover distance uses an exact dump of the engine's immutable body-map cover atlas. Combat and scoring interpretations follow [s2_combat_model.md](s2_combat_model.md).

The effective movement intent at a tick is the newest accepted annotation whose cached intent still owns the seat. This matters: the first live controller whose guard passes owns movement; an empty emission retains its cached intent; and guarded `jackal` emits `jackal:hold` until it sees a fresh public kill-feed row.

For descriptive score slices, this report defines:

- **jackpot/near-cap:** score >= 100,000;
- **middling:** 1,000 <= score < 100,000;
- **dud:** score < 1,000.

These are outcome-defined slices, useful for finding signatures but not for causal attribution.

## Hosted outcomes and score tiers

Across all 72 v153 episodes, the policy recorded 83 kills, 365 hit damage, 10 wins, and seven jackpots. Kill count was zero in 30 episodes, one in 16, two in 14, three in nine, and four in three. Thus 58.3% of episodes had at least one kill and 36.1% had at least two.

| Score tier | Episodes | Score median | Kills | K/episode | Kill histogram | Hit damage/episode | Wins |
|---|---:|---:|---:|---:|---|---:|---:|
| Jackpot/near-cap | 7 | 331,776 | 22 | 3.143 | 3K: 6; 4K: 1 | 11.00 | 6 |
| Middling | 14 | 4,320 | 29 | 2.071 | 0K: 1; 1K: 3; 2K: 6; 3K: 2; 4K: 2 | 7.93 | 4 |
| Dud | 51 | 12 | 32 | 0.627 | 0K: 29; 1K: 13; 2K: 8; 3K: 1 | 3.47 | 0 |

Every jackpot had three or four kills. That is the most useful tail fact: the next change should preserve the present kill engine and increase the chance that an already-dangerous seat lives long enough to land its third kill under heat, closing-time, placement, and win multipliers.

## Where and when v153 kills

The 61 archived v153 episodes contain 73 kills: 69 by gun, three by grenade, and one by spray. The typical kill is still ordinary-range combat—median distance 302 px, IQR 174–544—but the jackpot slice has a materially heavier longshot tail.

| Score tier in archived sample | Episodes covered | Kills | <300 px | 300–865 px | >=866 px | Median distance | Actual Longshot / Closing Time / Last Light deeds |
|---|---:|---:|---:|---:|---:|---:|---:|
| Jackpot/near-cap | 6/7 | 19 | 10 | 5 | 4 | 291 px | 4 / 10 / 2 |
| Middling | 13/14 | 28 | 14 | 13 | 1 | 301 px | 1 / 20 / 1 |
| Dud | 42/51 | 26 | 12 | 13 | 1 | 326 px | 1 / 9 / 0 |
| **All archived** | **61/72** | **73** | **36** | **31** | **6** | **302 px** | **6 / 39 / 3** |

Four of 19 archived jackpot kills were longshots (21.1%), versus two of 54 non-jackpot kills (3.7%). The exploratory odds ratio is about 6.9; a two-sided Fisher exact test gives `p=0.036`. This is a promising tail signature, not proof that forcing long range will improve the policy: there are only six longshots, and three occurred during the closing-time window but retained a different deed because the scoring selection tied or preferred that deed.

The absolute replay-tick distribution requested is:

| Score tier | <900 | 900–1499 | 1500–2475 | >=2476 | Median kill tick |
|---|---:|---:|---:|---:|---:|
| Jackpot/near-cap | 2 | 6 | 8 | 3 | 1,710 |
| Middling | 0 | 13 | 14 | 1 | 1,565 |
| Dud | 2 | 20 | 4 | 0 | 1,019 |
| **All archived** | **4** | **39** | **26** | **4** | **1,410** |

The stronger slices keep killing after tick 1500; duds almost stop. Absolute tick 2476 is not the Last Light boundary. Replay play begins around ticks 800–850, while zone scoring phases use elapsed game time. On that clock, 45 kills met the closing-time predicate and three met Last Light; the awarded deeds were 39 and three respectively.

The six actual longshots were at 906, 907, 995, 1,003, 1,069, and 1,282 px. Four belonged to jackpot episodes. One particularly informative near-cap loss in round 4485 scored 995,328 from three kills, including consecutive 906 px and 907 px longshots, before a 226 px combat death at tick 1693. The tail value is real, but spacing alone did not finish the episode.

## Intent ownership and the jackal freeze

Across 58,490 live replay ticks, effective intent ownership was:

| Effective mode | Live ticks | Share |
|---|---:|---:|
| Zone reflex | 47,406 | 81.05% |
| `edge_ride` | 3,942 | 6.74% |
| `jackal:join` | 3,178 | 5.43% |
| `jackal:hold` | 180 | 0.31% |
| Loot, supply, and other | 3,784 | 6.47% |

Zone reflex dominates because it takes over during dangerous shrink geometry. Any recipe-only change to the base ladder therefore has a limited direct time budget; its value must come from reaching better positions before reflex intervention or from better choices between interventions.

`jackal:hold` occurred in only **4/61 episodes (6.6%)**. All four bouts happened while an actual live enemy was within 700 px. They lasted 9, 17, 57, and 97 ticks: 180 ticks total, median 37 ticks (1.54 s), range 0.38–4.04 s. No own kill or death occurred during a hold. Each bout ended when a fresh kill-feed row caused `jackal:join`; the next decisive own event was a kill in two episodes and a death in two, 88–538 ticks later.

The mechanism is therefore exactly as described, but its observed ceiling is low. Even deleting every frozen tick would free only 0.31% of live time. By contrast, `jackal:join` ran in 43/61 episodes for 132.4 seconds total; its pooled live-time share was 8.28% in duds, 2.78% in middling episodes, and 3.15% in jackpots. That association may reflect field state and early death rather than harm, so it is a reason to instrument jackal—not enough evidence to retune it first.

## Deaths, motion, zone edge, and cover

The 61 archived episodes contain nine wins and 52 deaths. Of those deaths, **21 (40.4%) were to zone** and 31 to combat. Motion over the prior 24 ticks separates them:

| Death cause | Moving | Holding (<1 px displacement) | Total |
|---|---:|---:|---:|
| Zone | 20 | 1 | 21 |
| Combat | 19 | 12 | 31 |

All 52 deaths occurred while the effective annotation was a zone/reflex or emergency-support intent: 45 under zone reflex and seven under medkit or grenade-clear behavior. None occurred during effective jackal, edge-cover, or jackal-hold ownership. This does not absolve the base controller—its prior positioning determines how hard reflex must work—but it rules out “the seat freezes and immediately dies” as the main failure mode.

For combat deaths, killer distance was a median 397 px (IQR 220–636). The lone archived jackpot death was at 226 px. Middling combat deaths were closer (median 203 px, five deaths); dud combat deaths were farther (median 521 px, 25 deaths), including four incoming kills from >=866 px. Duds are not merely overcommitting into point-blank fights; many are being caught in weak positions at ordinary or long range.

Zone-edge clearance below is the signed geometric distance from cog centre to the board-clamped current safe rectangle: positive is inside, negative outside. Actual paint arrival is the damage authority, so the two zone deaths at +1 px are consistent with the moving paint front rather than an error in the replay.

| Elapsed zone interval | Jackpot median [IQR], outside | Middling median [IQR], outside | Dud median [IQR], outside |
|---|---|---|---|
| Phase 1 wait, 0–258 | 472 [275,663], 0% | 415 [263,560], 0% | 387 [277,533], 0% |
| Phase 1 shrink, 259–418 | 341 [236,632], 0% | 380 [228,524], 0% | 308 [170,434], 0% |
| Phase 2, 419–601 | 216 [59,422], 10.7% | 170 [73,331], 0.7% | 106 [25,225], 17.4% |
| Phase 3, 602–862 | 71 [12,316], 21.1% | 76 [36,151], 3.4% | 83 [42,124], 4.5% |
| Phase 4, 863–1312 | 92 [39,145], 4.6% | 77 [38,125], 0.9% | 56 [24,83], 5.6% |
| Phase 5, 1313–2475 | 71 [35,105], 1.0% | 83 [43,112], 1.6% | 3 [-3,8], 33.6% |
| Phase 6, 2476–3750 | 59 [39,60], 3.7% | 11 [0,41], 24.2% | no survivors |

The late split is the actionable one. Only three dud episodes reached phase 5, so this is a small, survivor-conditioned sample, but those seats were effectively riding the paint boundary. Nineteen of 21 zone deaths were geometrically outside at death; their clearances ranged to -227 px. A larger recalled margin gives reflex a shorter rescue path and creates more time for a third kill.

Cover does **not** distinguish jackpots in the expected direction. On stationary ticks, distance to the nearest engine cover post was a median 35 px for jackpots, 16 px for middling episodes, and 24 px for duds; the share within 16 px was 17%, 50%, and 43%. At death, 56% of middling and 57% of dud seats were within 16 px of a cover post. A cover post is a navigation hint, not armor and not proof of occlusion from the killer. Therefore the lane-warden recommendation rests on controlled range plus margin, not on a claim that more cover-post hugging itself wins.

## Same-round kill comparison

The unpaired distribution uses every hosted seat for each policy in rounds 4480–4485.

| Policy | Episodes | Kills | K/episode | 0K | 1K | 2K | 3K | 4K | Any kill | 2+ kills |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| **v153** | **72** | **83** | **1.153** | 30 | 16 | 14 | 9 | 3 | 58.3% | 36.1% |
| `apex:v38` | 76 | 55 | 0.724 | 43 | 17 | 12 | 2 | 2 | 43.4% | 21.1% |
| `Monet:v42` | 74 | 44 | 0.595 | 41 | 24 | 7 | 2 | 0 | 44.6% | 12.2% |
| `daveey paintbot-huddle:v159` | 73 | 64 | 0.877 | 32 | 25 | 9 | 7 | 0 | 56.2% | 21.9% |
| `daveey-1:v160` | 74 | 64 | 0.865 | 38 | 19 | 7 | 9 | 1 | 48.6% | 23.0% |

For the stricter common-episode comparison, I paired policies only where both appeared in the same episode and bootstrapped episode-level kill differences 100,000 times:

| Opponent | Common episodes | v153 K/ep | Opponent K/ep | Paired difference, 95% bootstrap interval | v153 higher / tied / lower |
|---|---:|---:|---:|---:|---:|
| `apex:v38` | 70 | 1.171 | 0.729 | **+0.443 [0.043, 0.829]** | 35 / 18 / 17 |
| `Monet:v42` | 68 | 1.162 | 0.588 | **+0.574 [0.221, 0.941]** | 31 / 21 / 16 |
| `daveey:v159` | 67 | 1.179 | 0.881 | +0.299 [-0.045, 0.642] | 31 / 15 / 21 |
| `daveey-1:v160` | 68 | 1.103 | 0.779 | +0.324 [-0.044, 0.691] | 28 / 23 / 17 |

Under the repository's measurement rule, v153 beat apex and Monet on kills in this batch, while both daveey comparisons are **level** because their intervals cross zero. This supports protecting v153's baseline combat rate. The opportunity is tail conversion, not copying a lower-kill leader wholesale.

## Three one-variable recipe changes

### 1. Increase only recalled `edge_ride.margin` to 240

Change the tick-900 margin from 140 to 240 and the tick-1500 margin from 120 to 240. Keep `enterLead`, `coverBias`, every guard, and the opening margin unchanged.

Why first:

- 21/52 archived deaths were zone deaths, and 20 were moving rather than frozen;
- 19/21 were already geometrically outside at death;
- phase-5 dud survivors had 3 px median clearance and spent 33.6% of their live ticks outside, versus 71–83 px and 1.0–1.6% for the better slices;
- the current recalled values explicitly ask the base controller to run much closer to the edge just as zone DPS and kill multipliers rise.

Expected direction: slightly fewer early/ordinary engagements, fewer irrecoverable late shrink paths, and more opportunities for kill three. Screening prior: **+0.03 to +0.10 kills/episode** and **+1 to +3 percentage points jackpot frequency** (about one or two extra jackpots per 72 episodes). The ceiling is modest because zone reflex already owns 81% of live ticks. The previous `v182` local batch combined margin 240 with jackal earshot 900 and did not win; it does not isolate this change.

### 2. Change only `target_law.prefer` from `isolated` to `bounty`

Use `prefer:["weakened","bounty"]` in opening and both recalls; change nothing else.

Why second:

- `isolated` has no useful teammate-separation meaning in this solo variant, so the current second preference contributes little;
- v153 already creates the field's best kill rate, while all archived jackpots require three or four kills;
- bounty should alter **which** viable target is selected rather than add an indiscriminate movement controller, aiming existing combat capacity at the highest heat/score conversion.

Expected direction: nearly neutral raw kills with a small upside from better target ordering, but a fatter score tail when a second or third kill lands on a valuable target. Screening prior: **0.00 to +0.05 kills/episode** and **0 to +2 percentage points jackpot frequency**. Treat the score effect as the main hypothesis. The regressed `v179` local bundle also changed scatter, margins, and loot-medkit behavior, so it is not evidence against bounty in isolation.

### 3. Replace only the bottom `edge_ride` rung with `lane_warden`

Make one categorical controller substitution at the opening and both recalls, leaving every higher rung and guard untouched:

```json
{"play":"lane_warden","params":{"margin":240,"standoffMin":866,"standoffMax":1250,"coverRadius":260,"hpFloor":2}}
```

Why third:

- longshots were 4/19 jackpot kills but only 2/54 non-jackpot kills;
- the play combines the safe late margin from recommendation 1 with a gun-range lane rather than adding a new high-priority controller;
- the 906/907 px double-longshot episode demonstrates that the current policy can convert that band into a near-cap result.

Expected direction: a tail-oriented trade—possibly fewer easy close finishes, but more longshot multipliers and less edge exposure. Screening prior: **-0.03 to +0.08 kills/episode** and **+1 to +3 percentage points jackpot frequency**. The downside must be accepted explicitly: current jackpot seats did not hug cover posts more than duds, and the six-longshot association is small and observational. The prior seven-episode `v180f` local screen was level on kills (0.88 versus 0.88 for v177) and produced one 3.54M leg, which is enough to keep the hypothesis alive but not to claim a win.

## What not to test first

- **Jackal `afterKill -> bothWeakened`:** this removes the no-feed hold mode, but only 180 archived live ticks are directly exposed. A realistic prior is roughly -0.03 to +0.03 K/episode and 0–1 jackpot percentage point. Keep it as the fourth test or add a freshness guard only if a separate code change is allowed.
- **Scatter:** the isolated `v181` local screen was 0.69 K/seat over 16 episodes versus roughly 0.90 for pooled v177 and did not justify hosted spend.
- **More loot or supply appetite:** five deaths already happened under medkit movement, and the successful score tail is defined by late kills, not a visible item shortfall. Changing resource behavior before positioning risks masking the cleaner hypothesis.
- **Pact:** solo semantics provide no teammate to coordinate with; it does not address the observed failure.

## Experiment order and success criteria

Run the three recipes separately in rank order, one variable per experiment, with the same opponents and both directions/full colour rotation required by the repository rules. First verify from replay annotations that the intended bottom rung actually owns movement when higher guards do not; cached-intent semantics make recipe appearance insufficient.

Primary metrics should be kills/episode and jackpot rate (`score >= 100,000`), with phase-5 zone clearance, zone-death rate, longshots/episode, and 3+ kill frequency as mechanism checks. Do not promote a change merely for a higher mean score from one capped leg. A kill-rate 95% interval crossing zero is level; for a deliberately tail-oriented candidate, require either a credible jackpot increase without a material kill loss or enough additional episodes to resolve the tail.

The immediate decision is therefore: **test recalled margin 240 alone; keep v153 otherwise intact.**
