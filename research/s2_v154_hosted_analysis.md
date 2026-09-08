# v154 hosted replay analysis: rounds 4489–4494

## Verdict

`jordan-ctf-candidate:v154` preserved and slightly improved the field-leading combat engine: **99 kills in 76 episodes (1.303/episode)**, 15 three-plus-kill episodes, and seven jackpots. No named rival exceeded 0.919 K/episode in the same rounds. In common episodes, v154 beat daveey-1, apex, docxology, bruce, and Aaron on paired kills; the Monet comparison is level because its bootstrap interval touches zero.

The margin-240 treatment achieved its intended mechanism **directionally, not causally proved**. Relative to the non-concurrent v153 cohort, zone deaths fell from 21/52 deaths (40.4%) to 16/63 (25.4%). More specifically, phase-5 dud survivors moved from a median 3 px geometric clearance and 33.6% of live ticks outside to 63 px and 0.5% outside. The late boundary-riding signature that motivated v154 is gone.

The remaining weaknesses are different:

- v154 still had 16 zone deaths, all while moving and all already outside. Twelve occurred in phases 2–3; dud outside time there rose to 21.2% and 11.8%. The residual zone problem is earlier routing, not phase-5 margin.
- Tail conversion did not improve in six-round frequency: seven jackpots in both cohorts (9.2% of v154 episodes versus 9.7% for v153), and v154 had no capped leg versus one for v153. Nine of 15 three-plus-kill episodes and nine of 13 wins still finished below 100,000.
- `supply_run` was the effective cached intent at 13 of 47 combat deaths but produced only six medkit pickups while it owned movement. This is the strongest new controller-level loss cluster.
- `jackal:hold` expanded from 0.31% to 1.04% of live ticks: 21 episodes, 21 bouts, and 30.6 seconds total. It caused no observed death, so it remains a lower-ceiling cleanup.
- Longshots remain valuable but are no longer a strong separator: four of 26 jackpot kills versus four of 73 other kills, odds ratio 3.14, Fisher `p=0.201`. The overall longshot rate was essentially unchanged from v153.

The next test should still be queued **v184**, changing `target_law.prefer` from `isolated` to `bounty` while retaining `weakened` first. It is the smallest way to attack the now-dominant tail-conversion problem without replacing the movement controller that produces 1.303 K/episode.

Ranked against three new one-variable proposals:

1. **v184:** `target_law` second preference `isolated -> bounty`.
2. **New:** add a 650 px enemy-clearance clause to every `supply_run` guard.
3. **New:** recalled `edge_ride.enterLead` `80 -> 160`, leaving margin 240.
4. **New:** recalled `jackal.joinWhen` `afterKill -> bothWeakened`.
5. **v185:** replace only the bottom `edge_ride` rung with longshot `lane_warden`.

These are screening priors, not measured uplifts. The detailed expected effects and stopping rules are at the end of the report.

## Data and method

The evaluated recipe is [v183-solo-margin240.env](s2_patches/recipes/v183-solo-margin240.env), hosted as `jordan-ctf-candidate:v154`. I verified it against [v177-solo-hpfrac-fixed.env](s2_patches/recipes/v177-solo-hpfrac-fixed.env): the only change is both recalled `edge_ride.margin` values, from 140/120 to 240/240.

Its effective call schedule is:

- opening: `target_law(weakened, isolated; hold through zone phase 1) > supply_run(hp_frac < 0.3) > guarded loot > edge_ride(420,320,1.0)`;
- tick 900 recall: the same target/supply/loot rungs, guarded `jackal(earshot=700, afterKill, hpFloor=2)`, then `edge_ride(240,80,0.5)`;
- tick 1500 recall: no loot, the same guarded jackal, then `edge_ride(240,80,0.9)`.

Hosted result JSON contains **76 v154 seat-episodes** across rounds 4489–4494. The archive contains 78 episode replays in total; 76 contain v154 and two do not. Thus v154 replay coverage is **76/76**, with no tier-dependent hole. All 76 replays passed manifest/hash validation, and their 99 extracted kill events exactly match the corresponding hosted result rows.

I used the annotation semantics in [s2_replays.py](../analysis/s2_replays.py), re-simulated exact per-tick positions and HP following [s2_replay_positions.py](../analysis/s2_replay_positions.py), and extracted native engine events from the pinned GV59 replay stream. Cover distance uses the engine's immutable cover-post atlas for the 11 generated maps in this cohort. Zone clearance is signed distance from cog centre to the board-clamped current safe rectangle: positive is inside and negative outside. Combat and scoring interpretations follow [s2_combat_model.md](s2_combat_model.md).

Effective intent means the newest accepted annotation whose cached intent still owns the seat. That qualification matters: the first live guarded controller owns movement, and an empty emission retains its cached intent.

As in the v153 report, the descriptive score tiers are:

- **jackpot/near-cap:** score >= 100,000;
- **middling:** 1,000 <= score < 100,000;
- **dud:** score < 1,000.

These are outcome-defined slices. They expose signatures but do not make those signatures causal. The v153 comparison is also non-concurrent, so apparent before/after changes are mechanism evidence rather than a controlled A/B result.

## Hosted outcomes and score tiers

Across all 76 episodes, v154 recorded 99 kills, 405 hit damage, 13 wins, seven jackpots, and no capped leg. Kill count was zero in 29 episodes, one in 19, two in 13, three in nine, four in four, five in one, and six in one. Thus 61.8% of episodes had a kill, 36.8% had two or more, and 19.7% had three or more.

| Score tier | Episodes | Score median | Kills | K/episode | Kill histogram | Hit damage/episode | Wins | Caps |
|---|---:|---:|---:|---:|---|---:|---:|---:|
| Jackpot/near-cap | 7 | 663,552 | 26 | 3.714 | 2K: 1; 3K: 2; 4K: 3; 6K: 1 | 10.00 | 4 | 0 |
| Middling | 18 | 6,144 | 41 | 2.278 | 1K: 5; 2K: 6; 3K: 5; 4K: 1; 5K: 1 | 9.67 | 9 | 0 |
| Dud | 51 | 6 | 32 | 0.627 | 0K: 29; 1K: 14; 2K: 6; 3K: 2 | 3.16 | 0 | 0 |

The tail is still kill-driven, but less cleanly than v153. Six of seven jackpots had at least three kills, yet **nine other three-plus-kill episodes did not jackpot**; one five-kill and one four-kill episode remained middling. Similarly, only four of 13 wins were jackpots. The next gain is more likely to come from the value and timing of an existing kill than from indiscriminately seeking more fights.

The direct descriptive comparison is:

| Metric | v153, rounds 4480–4485 | v154, rounds 4489–4494 | Raw change |
|---|---:|---:|---:|
| Episodes | 72 | 76 | +4 |
| Kills/episode | 1.153 | **1.303** | +0.150 (+13.0%) |
| Hit damage/episode | 5.069 | **5.329** | +0.260 (+5.1%) |
| Any-kill episodes | 58.3% | **61.8%** | +3.5 pp |
| 3+ kill episodes | 16.7% | **19.7%** | +3.1 pp |
| Wins | 13.9% | **17.1%** | +3.2 pp |
| Jackpots | **9.7%** | 9.2% | -0.5 pp |
| Capped legs | **1** | 0 | -1 |

The combat movement is encouraging, but it is not an isolated margin estimate: the rounds and opposing field differ, and ordinary kill-count variance easily covers a 0.15 K/episode shift at this sample size. Jackpot frequency is flat, which is the more important reason not to call v154 a solved tail policy.

## Where and when v154 kills

All 99 kills are replay-covered: 97 by gun, one by grenade, and one by spray. The typical kill remained ordinary range—median 312 px, IQR 182–525. Longshots were only eight of 99 kills.

| Score tier | Episodes | Kills | <300 px | 300–865 px | >=866 px | Median distance [IQR] | Longshot / Closing Time / Last Light deeds |
|---|---:|---:|---:|---:|---:|---:|---|---|
| Jackpot/near-cap | 7 | 26 | 12 | 10 | 4 | 345 [232,690] px | 4 / 16 / 2 |
| Middling | 18 | 41 | 23 | 16 | 2 | 268 [114,349] px | 2 / 31 / 2 |
| Dud | 51 | 32 | 11 | 19 | 2 | 356 [198,591] px | 2 / 14 / 0 |
| **All** | **76** | **99** | **46** | **45** | **8** | **312 [182,525] px** | **8 / 61 / 4** |

The eight physical longshots were at 892, 903, 985, 1,028, 1,100, 1,102, 1,207, and 1,232 px, and all eight received `dLongshotKill`. Four of 26 jackpot kills were longshots (15.4%) versus four of 73 non-jackpot kills (5.5%). The odds ratio is 3.14, but the two-sided Fisher exact result is `p=0.201`; this is weak tail evidence, not a controller mandate. For comparison, v153 had almost the same overall longshot share—six of 73—but a more concentrated 4/19 versus 2/54 jackpot split (`p=0.036`).

Sixty-seven kills met the physical Closing Time predicate, while 61 received that deed. All four physical Last Light kills received `dLastLight`. The six missing Closing Time awards overlap another eligible kill deed; that selector retains one of the overlapping distance/time deeds rather than every satisfied predicate.

Absolute replay tick shows that v154 did more work after its second recall:

| Score tier | <900 | 900–1499 | 1500–2475 | >=2476 | Median kill tick |
|---|---:|---:|---:|---:|---:|
| Jackpot/near-cap | 0 | 12 | 12 | 2 | 1,549 |
| Middling | 2 | 10 | 24 | 5 | 1,767 |
| Dud | 6 | 15 | 11 | 0 | 1,219 |
| **All** | **8** | **37** | **47** | **7** | **1,541** |

Fifty-four of 99 v154 kills (54.5%) occurred at absolute tick 1500 or later, versus 30 of 73 archived v153 kills (41.1%). Middling episodes account for most of that gain. As before, absolute tick 2476 is not the Last Light boundary because replay play starts hundreds of ticks after the replay clock starts.

On elapsed zone time, kills distribute as follows:

| Score tier | P1 wait | P1 shrink | P2 | P3 | P4 | P5 | P6+ |
|---|---:|---:|---:|---:|---:|---:|---:|
| Jackpot/near-cap | 7 | 1 | 3 | 5 | 4 | 4 | 2 |
| Middling | 6 | 3 | 3 | 6 | 10 | 11 | 2 |
| Dud | 15 | 5 | 4 | 6 | 2 | 0 | 0 |
| **All** | **28** | **9** | **10** | **17** | **16** | **15** | **4** |

Only two dud kills occurred from phase 4 onward, versus ten jackpot and 23 middling kills. V154 is still a survival-to-late-kills policy: phase-4/5 positioning is valuable because the stronger seats continue converting there, not because the late field automatically pays out.

## Intent ownership and the larger jackal hold

Across 70,942 live replay ticks, effective intent ownership was:

| Effective mode | Live ticks | Share |
|---|---:|---:|
| Zone reflex | 58,331 | 82.23% |
| `edge_ride` | 5,361 | 7.56% |
| `jackal:join` | 2,761 | 3.89% |
| `jackal:hold` | 735 | 1.04% |
| Loot | 1,998 | 2.82% |
| `supply_run` | 1,569 | 2.21% |
| Other | 187 | 0.26% |

Zone reflex is still the overwhelming movement owner. Recipe changes matter chiefly by improving the position from which reflex begins its rescue or by changing the short windows between reflex interventions.

`jackal:hold` occurred in **21/76 episodes**, one bout per episode. Bout duration was 1–106 ticks, median 32 ticks (1.33 s); total exposure was 735 ticks (30.6 s). No death happened during a hold. Two own kills did, because holding movement does not disable native gunfire. This is a real cached-ladder inefficiency and substantially larger than v153's four bouts/180 ticks, but it is not the observed cause of a loss. That keeps the `bothWeakened` cleanup below supply safety and early zone entry.

## Deaths, zone edge, killer distance, supply runs, and cover

The 76 episodes contain 13 wins and 63 deaths. Sixteen deaths (25.4%) were to zone and 47 to combat:

| Death cause | Moving over prior 24 ticks | Holding | Total |
|---|---:|---:|---:|
| Zone | 16 | 0 | 16 |
| Combat | 31 | 16 | 47 |
| **All** | **47** | **16** | **63** |

All 16 zone deaths were already geometrically outside at death, with clearance from -6 to -236 px. Seven were in phase 2, five in phase 3, one in phase 4, one in phase 5, and two in phase 6+. This is no longer a stationary seat waiting for paint: it is a seat whose route started too late or could not cover the required distance.

The per-tick clearance table is survivor-conditioned. A cell is `median [IQR], percent outside`:

| Elapsed zone interval | Jackpot/near-cap | Middling | Dud |
|---|---|---|---|
| Phase 1 wait, 0–258 | 605 [197,660], 0% | 381 [254,490], 0% | 377 [250,527], 0% |
| Phase 1 shrink, 259–418 | 502 [125,612], 0% | 304 [184,407], 0.0% | 272 [178,399], 0.0% |
| Phase 2, 419–601 | 310 [70,431], 0% | 113 [31,192], 11.0% | 94 [18,202], 21.2% |
| Phase 3, 602–862 | 109 [64,212], 1.2% | 77 [38,127], 3.4% | 80 [26,141], 11.8% |
| Phase 4, 863–1312 | 80 [39,121], 0.9% | 70 [37,101], 1.1% | 69 [28,107], 9.1% |
| Phase 5, 1313–2475 | 64 [33,99], 1.5% | 83 [44,114], 1.6% | 63 [36,94], 0.5% |
| Phase 6+, >=2476 | 12 [1,33], 14.5% | 39 [14,44], 7.7% | 18 [7,29], 5.1% |

Four dud episodes reached phase 5 and two reached phase 6+, versus only three reaching phase 5 and none phase 6 in the archived v153 sample. The phase-5 dud improvement—3 px to 63 px median, 33.6% to 0.5% outside—is therefore not just a single unusually safe survivor. It is still a small outcome-selected subset, so it should be treated as a mechanism check rather than an effect estimate.

The margin treatment did not solve the earlier transition. V153 dud outside shares were 17.4% in phase 2 and 4.5% in phase 3; v154's are 21.2% and 11.8%. Those are exactly the intervals containing 12/16 current zone deaths. Increasing margin again would attack a late signature that has already improved. Increasing recalled `enterLead` is the more targeted follow-up because it asks `edge_ride` to enter the announced next rectangle sooner while preserving the 240 px destination margin.

For combat deaths, killer distance was a median 352 px (IQR 218–543):

| Score tier | Combat deaths | Median killer distance [IQR] | >=866 px |
|---|---:|---:|---:|
| Jackpot/near-cap | 3 | 250 [186,279] px | 0 |
| Middling | 7 | 163 [157,252] px | 0 |
| Dud | 37 | 396 [271,645] px | 6 |
| **All** | **47** | **352 [218,543] px** | **6** |

Dud deaths remain mostly ordinary-range positional losses, not point-blank overcommitment. Their median improved from v153's 521 px, but six were still incoming longshots.

The effective intent at death exposes a new support-run cluster:

| Effective intent at death | Combat deaths | Zone deaths | Total |
|---|---:|---:|---:|
| Zone reflex | 28 | 16 | 44 |
| `supply_run` | 13 | 0 | 13 |
| `edge_ride` | 3 | 0 | 3 |
| Loot | 1 | 0 | 1 |
| Other | 2 | 0 | 2 |

The 13 `supply_run` combat deaths had median killer distance 542 px (IQR 388–747); five killers were within 500 px and eight within 650 px. Across the whole cohort, v154 picked up 13 medkits: six while `supply_run` owned movement, four under a cached loot intent, and three under zone reflex. Last-intent attribution is observational—the seat is already at one HP when the guard normally fires—but 13 combat losses for six successful pickups is enough to justify a clean enemy-distance screen.

Cover-post proximity again fails to identify winners:

| Score tier | Stationary ticks | Median cover distance | Stationary ticks <=16 px | Deaths | Median at death | Deaths <=16 px |
|---|---:|---:|---:|---:|---:|---:|
| Jackpot/near-cap | 11,177 | 40 px | 22.9% | 3 | 9 px | 66.7% |
| Middling | 22,062 | 48 px | 25.3% | 9 | 27 px | 33.3% |
| Dud | 16,394 | 30 px | 40.0% | 51 | 34 px | 43.1% |

Duds spent the largest share of stationary time close to a post. A cover post is a navigation hint, not armor or proof that the killer's ray was occluded. More post hugging is therefore not supported as a standalone improvement, and v185 must be judged on controlled range and tail deeds rather than “more cover.”

## Same-round comparison with the top entrants

The unpaired distribution uses every completed hosted row for the named policy in rounds 4489–4494. A capped leg means score >= 16,777,216.

| Entrant / policy | Episodes | Score sum | Kills | K/episode | 3+ kill episodes | Wins | Jackpots | Capped legs |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| **Jordan / v154** | **76** | **12,114,612** | **99** | **1.303** | **15 (19.7%)** | **13** | **7** | **0** |
| softmaxwell / `Monet:v41` | 74 | 2,678,800 | 68 | 0.919 | 4 (5.4%) | 5 | 3 | 0 |
| softmaxclaudius-t2 / `apex:v38` | 74 | 2,939,164 | 58 | 0.784 | 5 (6.8%) | 8 | 2 | 0 |
| bruce (pawchuck) / `bruce:v3` | 73 | 4,305,914 | 54 | 0.740 | 4 (5.5%) | 4 | 2 | 0 |
| Aaron / `aaron-paintbot:v7` | 75 | 351,168 | 55 | 0.733 | 2 (2.7%) | 2 | 1 | 0 |
| docxology / `daf-paintbot-s2-v4:v1` | 73 | 9,726,992 | 50 | 0.685 | 4 (5.5%) | 6 | 3 | 0 |
| daveey-1 / `paintbot-huddle:v160` | 74 | 1,159,744 | 47 | 0.635 | 3 (4.1%) | 3 | 2 | 0 |

No named entrant capped a leg. Docxology is the immediate **score** threat: its 9.73M sum includes an 8.86M round despite only 0.685 K/episode. That is evidence that its bounty-first/deed-oriented ladder can convert a rare leg, not that its ordinary combat engine is stronger than v154's.

For the stricter common-episode comparison, I paired only episodes containing both policies and bootstrapped episode-level kill differences 100,000 times:

| Opponent | Common episodes | v154 K/ep | Opponent K/ep | Paired difference, 95% bootstrap interval | v154 higher / tied / lower | Verdict |
|---|---:|---:|---:|---:|---:|---|
| daveey-1 `v160` | 72 | 1.333 | 0.639 | **+0.694 [0.278,1.111]** | 38 / 22 / 12 | v154 higher |
| `apex:v38` | 72 | 1.333 | 0.792 | **+0.542 [0.125,0.958]** | 35 / 18 / 19 | v154 higher |
| `Monet:v41` | 72 | 1.333 | 0.917 | +0.417 [0.000,0.833] | 30 / 21 / 21 | **level** |
| docxology | 71 | 1.282 | 0.704 | **+0.577 [0.169,0.986]** | 32 / 22 / 17 | v154 higher |
| `bruce:v3` | 71 | 1.324 | 0.718 | **+0.606 [0.197,1.028]** | 32 / 21 / 18 | v154 higher |
| `aaron-paintbot:v7` | 73 | 1.301 | 0.726 | **+0.575 [0.260,0.904]** | 29 / 32 / 12 | v154 higher |

The Monet interval lands exactly on zero, so it does not clear the repository's conservative “level” rule. The other five paired comparisons do. This is strong evidence to preserve v154's basic combat behavior while testing target value or narrow safety guards.

### What their live ladders do differently

These are accepted calls parsed from the same replay reports, not inferred policy source:

| Entrant | Calls/episode; median (range) | Observed ladder shape and important parameters | Custom plays / diplomacy |
|---|---|---|---|
| **v154** | 3.00; 3 (3–3) | Fixed opening and recalls: `target_law > supply_run > loot > edge_ride`; recalls add `jackal`, then remove loot. Edge is 420/320 initially and 240/80 later. | No custom play, pact, or `never` target. |
| daveey-1 | 4.89; 5 (3–8) | Usually `loot > scatter > edge > jackal > crossfire`, variably adding supply/target. Loot commonly races within 400 and prefers grenades; scatter 320 px/300 ticks; edge 140/80/0.5; jackal `afterKill`, 600 px, hpFloor 2; target often `weakened,bounty`. | Public reference plays; rare `bodyguard`; no pacts/never list. Frequent recalls re-trigger scatter under cached semantics. |
| apex | 0.96; 1 (0–1) | Static `warden > loot`, with no recall in called episodes. Warden uses `holdTeams=0`, `lanePx=90`, `preferMode=3`, `protectOwn=true`; loot avoids contests with detour 2500, medkits false. | Custom `warden`; no diplomacy. Three episodes had no accepted call. |
| Monet | 8.54; 8 (4–17) | Opens `target_law > scatter`, then mixes target, scatter, jackal (`bothWeakened`, 550 px, exit after two kills), supply, loot, and custom combat/ring controllers. Target usually includes `weakened,revenge,bounty,isolated`. | Custom `fire_superiority`, `ring_walker`, and `hold_vs_gun`; 72 pact entries across its calls and many no-shoot targets. It proposed Jordan in two episodes and never-listed Jordan in 11, but Jordan never reciprocated, so no mutual pact existed. |
| docxology | 6.74; 7 (0–12) | Usually `target_law(bounty,revenge,weakened,isolated) > scatter > edge`; recalls add jackal (`bothWeakened`, 900 px, hpFloor 0), loot (900, medkits true), and supply (700, hpBelow 3). Edge is 240/260/0.8. | Reference plays only; no pacts/never list. Three episodes had no accepted call. |
| bruce | 1.92; 2 (0–2) | `target_law > farm_hold > edge_ride > anchor12`; edge 180/140/0.75. | Custom `farm_hold` and `anchor12`; target law uses rotating `never` lists, including Jordan in 13 episodes; no pact calls. |
| Aaron | 6.73; 7 (4–10) | `target_law(weakened,isolated) > scatter > edge`, with some recalls omitting scatter. Edge 240/260/0.8. | No known custom play, pact, or never list. |

The contrast is useful:

- v154 calls far less often than Monet, docxology, Aaron, or daveey, yet kills more. More recalls are not an improvement by themselves.
- The two strongest score-tail comparators, docxology and Monet, both include `bounty` and use `bothWeakened` jackal. Docxology puts bounty first; Monet adds custom deed/ring logic and diplomacy.
- Apex and bruce rely on custom stationary/holding controllers, but neither approaches v154's kill rate in these rounds.
- No listed policy changed version during rounds 4489–4494. Docxology's rapid score gain and bruce's 4.31M batch are tail realizations of stable policies, not evidence of a newly deployed upward trend. Monet is `v41` here rather than the `v42` seen in the earlier v153 window.

## Explicit v153 weakness audit

| v153 finding | v154 evidence | Status |
|---|---|---|
| Phase-5 dud seats rode the paint boundary: 3 px median clearance, 33.6% outside. | 63 px median clearance, 0.5% outside; four dud survivors reached P5 and two reached P6+. | **Improved; intended margin mechanism landed.** |
| Zone caused 21/52 deaths (40.4%). | Zone caused 16/63 (25.4%). | **Directionally improved**, but non-concurrent and interval-sized uncertainty remains. |
| Most zone deaths were moving and already outside. | All 16 were moving and outside. | **Remains.** Rescue-path failure, not freeze. |
| Duds stopped killing late. | Dud kills at absolute tick >=1500 rose from 4 to 11; total late-kill share rose from 41.1% to 54.5%. | **Improved**, mainly into the middling tier. |
| Every jackpot had 3–4 kills; tail conversion required survival to kill three. | Six of seven jackpots had 3+ kills, but nine other 3+ episodes and nine wins stayed below jackpot. | **Remains; conversion is now clearer than kill acquisition.** |
| Longshots were concentrated in jackpots (OR 6.9, `p=0.036`). | OR 3.14, `p=0.201`; overall longshot frequency stayed near 8%. | **Weaker signal.** Do not prioritize range forcing. |
| Jackal hold was real but tiny: 180 ticks, four episodes, no deaths. | 735 ticks, 21 episodes, no deaths, two kills while holding. | **Larger inefficiency, still not a demonstrated killer.** |
| Cover proximity did not distinguish jackpots. | Duds again spent more stationary time within 16 px of posts than jackpots. | **Remains; more cover-post hugging is unsupported.** |
| Ordinary combat was already field-leading. | 1.303 K/episode; paired higher than five named rivals and level with Monet. | **Preserved.** |

## Three new one-variable proposals and full queue order

### Overall ranking

| Rank | Test | One variable | Expected K/episode effect | Expected jackpot-frequency effect |
|---:|---|---|---:|---:|
| 1 | **Queued v184** | `target_law.prefer[1]: isolated -> bounty` at all calls | 0.00 to +0.05 | 0 to +2 pp |
| 2 | **New supply safety** | Require no tracked enemy or nearest enemy >650 px in every `supply_run` guard | -0.02 to +0.06 | 0 to +1 pp |
| 3 | **New earlier entry** | Recalled `edge_ride.enterLead: 80 -> 160` | -0.02 to +0.05 | 0 to +2 pp |
| 4 | **New jackal trigger** | Recalled `jackal.joinWhen: afterKill -> bothWeakened` | -0.03 to +0.04 | 0 to +1 pp |
| 5 | **Queued v185** | Bottom controller `edge_ride -> lane_warden(240,866,1250,260,2)` | -0.12 to 0.00 | 0 to +2 pp |

The ranges are priors for experiment sizing, not confidence intervals. Jackpot changes of one or two percentage points are difficult to resolve in a single six-round batch; mechanism metrics are needed alongside the binary tail outcome.

### 1. Run v184 next: prefer bounty instead of isolated

Use [v184-solo-margin240-bounty.env](s2_patches/recipes/v184-solo-margin240-bounty.env) exactly as queued. It changes `prefer:["weakened","isolated"]` to `prefer:["weakened","bounty"]` in the opening and both recalls, with no movement, guard, timing, or margin change.

Why it remains first:

- `isolated` is neutral in this solo field, while `bounty` distinguishes a veteran target;
- nine three-plus-kill episodes and nine wins failed to jackpot, so target value/timing is now more deficient than raw fight count;
- v154 already has ample ordinary combat volume, and `target_law` changes target ordering rather than installing a new movement controller;
- docxology's bounty-first ladder generated the nearest same-round score threat despite a much lower kill rate, while Monet also carries bounty in its target list.

The expected raw-kill effect is near neutral; the hypothesis is a fatter tail from directing an otherwise available second/third kill toward a higher-value tracked target. Instrument selected target level/bounty eligibility if the replay exposes it. Promote only if jackpot/three-plus conversion improves without a material kill-rate loss.

### 2. New proposal: gate supply runs on 650 px enemy clearance

Append this clause to the existing `supply_run` guard in the opening and both recalls, leaving `hp_frac`, medkit distance, `detourMax`, and `contested` unchanged:

```json
["or",
  ["==",["get","world.nearest_enemy_dist"],-1],
  [">",["get","world.nearest_enemy_dist"],650]]
```

Why second:

- `supply_run` owned the cached intent at 13 combat deaths but only six medkit pickups;
- eight of those killers were within 650 px, where the combat model gives a native gun about 99% hit probability at the outer bound;
- loot already uses the same form of enemy-clearance guard, so this changes one predicate rather than introducing a new controller;
- it directly attacks the largest non-reflex death cluster.

The risk is real: at the current `hp_frac < 0.3` threshold, the seat is already desperate, and declining a nearby medkit may also lose. That is why the expected K/episode range includes a small downside. The mechanism gate is fewer combat deaths with effective `supply_run`, with medkit pickups and healing retained as much as possible.

### 3. New proposal: increase only recalled enter lead to 160

Change both recalled `edge_ride.enterLead` values from 80 to 160. Keep opening `enterLead=320`, all margins, both cover biases, recall ticks, and every higher rung unchanged.

Why third:

- phase-5 clearance—the problem margin controls—improved sharply;
- all 16 remaining zone deaths were moving and outside, and 12 occurred in phases 2–3;
- `edge_ride` switches from the current rectangle to the announced next rectangle when `ticksToShrink <= enterLead`, so 160 buys up to 80 additional ticks (3.33 seconds at 24 Hz) for the transition without asking the seat to sit deeper throughout the entire phase;
- this uses an existing parameter and attacks route start time rather than retesting a larger margin.

The tradeoff is earlier disengagement from a viable fight. Expect a small possible kill loss against fewer irrecoverable transition paths. The mechanism gate is lower P2/P3 outside share and fewer P2/P3 zone deaths; do not accept merely prettier phase-5 clearance, which v154 already has.

### 4. New proposal: `afterKill -> bothWeakened` for recalled jackal

Change only `joinWhen` in both recalled jackal entries. Keep `earshot=700`, `hpFloor=2`, the outer HP/enemy-distance guard, ladder position, and recalls fixed.

Why fourth:

- it removes reliance on a fresh public kill-feed row, the condition that creates `jackal:hold` under cached semantics;
- hold exposure grew to 735 ticks in 21 episodes;
- Monet and docxology both use `bothWeakened`, so the parameter is current-field-tested behavior rather than a new custom play.

Why not higher: no seat died during a hold, native combat continued, and only 1.04% of live time is directly exposed. The mechanism gate is a large fall in `jackal:hold` ticks without an increase in close combat deaths.

### 5. Keep v185 behind the other four

[v185-solo-lane-warden-bottom.env](s2_patches/recipes/v185-solo-lane-warden-bottom.env) is a valid one-variable categorical test: it replaces the bottom `edge_ride` rung at all three calls with `lane_warden(margin=240, standoffMin=866, standoffMax=1250, coverRadius=260, hpFloor=2)` and leaves higher rungs unchanged.

It is now fifth because the evidence for forcing its range band weakened:

- longshots were only 8/99 kills and their jackpot association no longer clears an exploratory significance check;
- jackpot seats did not use cover posts more than duds;
- the pooled local v180f screen was about 0.76 K/episode versus 0.88 for v177, a roughly -0.12 point trade, even though it showed a fatter score tail; v180f differed elsewhere, so this is a downside prior rather than an isolated estimate of v185;
- v154's present advantage over the field is kill volume, which v185 is the most likely test to sacrifice.

V185 remains worth a tail screen after the narrower changes, especially if bounty does not improve jackpot conversion. It should not displace v184 or a direct test of the observed supply/zone-transition clusters.

## Experiment order and decision rules

Run one treatment at a time against the same opponent set, with full seat/color rotation and comparable episode counts. First confirm from replay annotations that the intended controller or guard actually changed effective ownership; recipe presence is not enough under cached-ladder semantics.

Use kills/episode and jackpot frequency (`score >= 100,000`) as joint primary outcomes. Mechanism checks should be treatment-specific:

- v184: bounty-eligible target selections and jackpot rate among 3+ kill episodes/wins;
- supply guard: medkit pickups/heals and combat deaths under `supply_run`;
- enterLead: P2/P3 outside share, transition clearance, and zone deaths by phase;
- bothWeakened: `jackal:hold` ticks/bouts and combat deaths while jackal owns movement;
- v185: longshots/episode, 3+ kills, ordinary-kill loss, and jackpot rate.

Do not promote on mean score from one giant leg. A 95% kill-rate interval that reaches/crosses zero is level. For a tail-oriented candidate, require a credible jackpot or 3+-kill-to-jackpot conversion gain without a material kill-rate loss, or extend the batch until the tail estimate is informative.

The immediate decision is: **run v184 next; retain v154 as champion unless bounty clears those gates.**
