# GLORYVERSION 17 cap routes, rounds 4611–4621

Date: 2026-09-09

## Bottom line

- The hosted census contains **74 capped seat-episodes out of 2,464 valid seats (3.00%)** in 154 episodes. There were 66 episodes with a cap; eight had two cappers.
- A cap is not a win reward. **61/74 cappers lost (82.4%)** and still banked 16,384. Only friendly-fire halving is applied after the clamp.
- The locally available GameVersion 62 replay bodies cover rounds 4612–4613 only: 26 episodes, 18 capped seats. All 18 routes were re-simulated with the matching engine and checked against the Glory deed feed and `GLORY_CAP_HIT`.
- In those 18 verified routes, **12 used First Blood**, **11 used at least one longshot**, and **all 18 reached the cap on their first or second kill**. The most common family was First Blood followed by one more heated deed inside 270 ticks (8/18). Four caps occurred on a first-kill longshot plus heated First Blood plus the first Gun-V claim.
- Across the full hosted census, the cap-seat kill distribution was 0K: 1, 1K: 8, 2K: 37, 3K: 16, 4K: 9, 5K: 1, 6K: 2. Thus total kills alone cannot reconstruct a route; the zero-kill cap is direct evidence of a non-kill/pact route somewhere in the unavailable traces.
- Jordan produced **4/134 caps (2.99%)**, 128 kills (**0.955/episode**), and 14 wins. The local 24-seat trace subset shows the conversion problem: only 1/18 kills was a longshot, only 2/24 episodes earned First Blood, and 14/24 seats died before a first kill.
- The most useful next one-variable test on top of v191 is to put guarded `jackal` above guarded `loot` at tick 760. The next two tests are a tightly guarded longshot `lane_warden` rung and the already-staged reciprocal pact overlay. Expected effects below are screening priors, not measured results.

## Scope, scoring notation, and evidence boundary

This analysis uses:

- the economy in [`s2_glory_v17_legs.md`](s2_glory_v17_legs.md) and combat constants in [`s2_combat_model.md`](s2_combat_model.md);
- hosted results in `research/br_rounds/4611_round_*` through `4621_round_*`;
- policy calls and ladders in the two available `report.json` files under `research/s2_replays/4612_round_*` and `4613_round_*`;
- deterministic position/HP/event re-simulation via [`analysis/s2_replay_positions.py`](../analysis/s2_replay_positions.py), using `/private/tmp/engine-main-v44`; and
- the matching engine event extractor for `glory_deed`, Gun-tier achievements, and `GLORY_CAP_HIT`.

There are 155 hosted JSON artifacts. One round-4619 artifact is a platform SSL-timeout result with no valid episode, leaving **154 episodes × 16 seats = 2,464 seat-episodes**.

The repository snapshot does **not** contain replay bodies for round 4611 or rounds 4614–4621; the round-4614 replay directory is empty. Hosted results expose score, kills, damage, outcome, and result achievements, but not the per-deed Glory stream, kill ticks, or kill distances. Consequently:

- all 74 capped seats can be enumerated exactly;
- routes, ticks, distances, and the cap-triggering deed are exact for 18/74 caps (24.3%), covering every cap in the available round-4612/4613 replays; and
- the other 56 routes are deliberately marked **unresolved**, rather than guessed from kill totals.

In the route tables, a factor such as `Tag ×2.20` is the multiplier emitted by the deed feed. It is not a point award. The v17 fixed-point product performs its clamp precheck before normalizing the percentage factor, so apparently modest sequences can emit `GLORY_CAP_HIT` and report 16,384 much earlier than ordinary multiplication suggests. `d` is the floored Euclidean shooter-to-victim distance at the kill; longshot is `d >= 866`, point-blank is `d <= 136`; `Δ` is the gap from the preceding kill. `D@1558/p7` means the seat died at tick 1558 in placement 7. Eight-character episode suffixes uniquely identify files in this corpus.

## Hosted cap frequency

There were 74 capped seats, for a field cap rate of **3.00%** (95% Wilson interval 2.40%–3.75%). The leading point estimates are noisy: Andre von Auto's 7/98 interval is 3.50%–14.02%, while Jordan's 4/134 interval is 1.17%–7.42%. Those overlap; this census ranks observed production, not settled policy quality.

| Entrant | Valid seats | Caps | Cap rate | Capped wins |
|---|---:|---:|---:|---:|
| Andre von Auto | 98 | 7 | 7.14% | 1 |
| Ari Sklar | 137 | 7 | 5.11% | 1 |
| docxology | 138 | 6 | 4.35% | 3 |
| softmaxclaudius-t2 | 138 | 6 | 4.35% | 0 |
| daveey | 138 | 5 | 3.62% | 1 |
| Jordan | 134 | 4 | 2.99% | 1 |
| macromackie | 136 | 4 | 2.94% | 0 |
| relh | 136 | 4 | 2.94% | 1 |
| richard | 136 | 4 | 2.94% | 1 |
| Aaron | 137 | 4 | 2.92% | 1 |
| soft-codexter-t2 | 137 | 4 | 2.92% | 1 |
| @lessandro-forum-power-user | 135 | 3 | 2.22% | 0 |
| Lawrence | 136 | 3 | 2.21% | 0 |
| softmaxwell | 136 | 3 | 2.21% | 1 |
| pawchuck | 137 | 3 | 2.19% | 0 |
| daveey-1 | 138 | 3 | 2.17% | 1 |
| Andre von Houck | 50 | 1 | 2.00% | 0 |
| Games Bond | 131 | 2 | 1.53% | 0 |
| NanosaurusX | 136 | 1 | 0.74% | 0 |

Andre von Auto and Andre von Houck are separate entrants. Auto first appears in this window in round 4614; the locally replayable rounds contain only Houck.

## Verified routes to the cap

### Route-family frequency

These shares describe the **18 trace-covered caps**, not all 74 caps. The two available rounds are a contiguous convenience sample, not a random sample.

| Verified route family | Seats | Share |
|---|---:|---:|
| First hostile deed + heated First Blood, then a second deed within 270 ticks | 8 | 44.4% |
| First-kill longshot + heated First Blood + first Gun-V claim | 4 | 22.2% |
| Ordinary first kill, then heated longshot, then first Gun-V claim | 3 | 16.7% |
| First longshot + Gun-V claim, then another heated longshot | 2 | 11.1% |
| First longshot + Gun-V claim, then heated Ace | 1 | 5.6% |

The exact cap-triggering event was first Gun-V claim in 7 cases, heated ordinary tag in 5, heated longshot in 2, and one each of heated pact-member-down, Ace, point-blank, and enemy-ground longshot. No `Joint Act` deed and no ally-stack factor above one appeared in these 26 local episodes. The deed feed contained pact activity, and pact member down directly capped one seat.

### Every trace-covered capped seat

| Round / episode / seat | Entrant | Verified factor route to `GLORY_CAP_HIT` | Outcome |
|---|---|---|---|
| 4612 / `b3ad7d44` / s11 | softmaxclaudius-t2 | K1 t1052 d844: Tag ×2.20 + First Blood ×21.20; K2 t1223, Δ171, d275: Tag ×30.80 → cap | D@1558 / p7, 2K |
| 4612 / `79f72256` / s3 | pawchuck | K1 t837 d439: Tag ×2.20 + First Blood ×21.20; K2 t922, Δ85, d510: Tag ×30.80 → cap | D@1359 / p8, 2K |
| 4612 / `45c8aa9f` / s1 | richard | K1 t1059 d402: Tag ×2.20; K2 t1185, Δ126, d988: Longshot ×31.20; t1186 first Gun-V ×3.46 → cap | D@1440 / p9, 2K |
| 4612 / `025aec25` / s1 | richard | K1 t877 d216: Tag ×2.20 + First Blood ×21.20; second target down at t1003, Δ126, d311; pact finalization t1021: Pact Member Down ×29.68 → cap | D@1316 / p11, 2K |
| 4612 / `e43e45ce` / s0 | daveey | K1 t927 d210: Tag ×2.20 + First Blood ×21.20; K2 t967, Δ40, d452: Tag ×30.80 → cap | D@1744 / p5, 2K |
| 4612 / `b7d9f910` / s2 | macromackie | K1 t835 d909: Longshot ×6.24 + First Blood ×21.20; t836 first Gun-V ×3.46 → cap | D@1343 / p7, 1K |
| 4612 / `abc46e33` / s13 | soft-codexter-t2 | K1 t1604 d868: Longshot ×6.24; t1605 first Gun-V ×3.46; K2 t1825, Δ221, d546: Ace ×46.35 → cap | D@2047 / p4, 2K |
| 4613 / `9daffd6c` / s11 | macromackie | K1 t974 d1129: Longshot ×6.24; t975 Gun-V ×2.00; K2 t1023, Δ49, d926: Longshot ×31.20 → cap | D@3329 / p3, 3K total |
| 4613 / `88cfd920` / s6 | Ari Sklar | K1 t876 d867: Longshot ×6.24 + First Blood ×21.20; t877 first Gun-V ×3.46 → cap | D@2294 / p2, 4K total |
| 4613 / `531f6dbd` / s11 | Andre von Houck | K1 t860 d299: Tag ×2.20 + First Blood ×21.20; K2 t1017, Δ157, d535: Tag ×30.80 → cap | D@1080 / p13, 2K |
| 4613 / `297faa11` / s13 | **Jordan** | K1 t849 d596: Tag ×2.20 + First Blood ×21.20; K2 t1056, Δ207, d110: Point-blank ×35.00 → cap | D@1537 / p7, 2K |
| 4613 / `273446ee` / s13 | soft-codexter-t2 | K1 t963 d879: Longshot ×6.24; t964 first Gun-V ×3.46; K2 t1014, Δ51, d967: Longshot ×31.20 → cap | D@1567 / p7, 2K |
| 4613 / `df14e744` / s14 | Ari Sklar | K1 t996 d1142: Longshot ×6.24 + First Blood ×21.20; t997 first Gun-V ×3.46 → cap | D@1891 / p4, 2K total |
| 4613 / `ce169c0d` / s9 | NanosaurusX | K1 t928 d890: Longshot ×6.24 + First Blood ×21.20; t929 first Gun-V ×3.46 → cap | D@1529 / p5, 1K |
| 4613 / `90c9da1c` / s12 | Lawrence | K1 t851 d338: Tag ×2.20 + First Blood ×21.20; K2 t998, Δ147, d993: enemy-ground Longshot ×87.36 → cap | D@1000 / p12, 2K |
| 4613 / `de0d3e16` / s4 | daveey-1 | K1 t1280 d197: Tag ×2.20; K2 t1325, Δ45, d950: Longshot ×31.20; t1326 first Gun-V ×3.46 → cap | **Win / p1**, 3K total |
| 4613 / `de0d3e16` / s7 | daveey | K1 t1219 d44: Point-blank ×2.50 + First Blood ×21.20; K2 t1238, Δ19, d560: Tag ×30.80 → cap | D@1950 / p4, 2K |
| 4613 / `cbc39779` / s13 | softmaxclaudius-t2 | K1 t961 d297: Tag ×2.20; K2 t1057, Δ96, d1116: Longshot ×31.20; t1058 first Gun-V ×3.46 → cap | D@1265 / p11, 2K |

Several seats earned more kills after capping, which is why hosted total kills can exceed the kill number at the cap. No positive factor after the clamp changes the bank; a later friendly-fire factor can halve it.

### The 56 capped seats without a local deed trace

These are still part of every frequency and entrant-rate calculation above. Each entry is `episode suffix / seat / entrant / hosted total kills / outcome`. `D` means the one-life seat did not win. The route itself is unresolved because its replay body is absent.

- **Round 4611 (7):** `3064144e` s8 Jordan 2K D; `3f70311c` s4 @lessandro-forum-power-user 2K D; `f2ee1d25` s0 richard 3K D; `f2ee1d25` s4 relh 1K D; `529c4ebe` s3 docxology 4K D; `f9db88b4` s6 Ari Sklar 4K W; `acac71ae` s10 richard 3K W.
- **Round 4614 (7):** `f41b2ea2` s1 daveey 3K W; `8946fc7a` s13 Andre von Auto 4K D; `472e2926` s13 Ari Sklar 2K D; `15646c3f` s4 docxology 2K D; `15646c3f` s15 Jordan 3K D; `28a400e6` s5 macromackie 1K D; `f0bea650` s9 relh 3K W.
- **Round 4615 (5):** `014b134e` s11 Andre von Auto 2K D; `2c4da23a` s10 @lessandro-forum-power-user 2K D; `5c07fedb` s12 relh 2K D; `8881d268` s7 softmaxwell 3K W; `8881d268` s9 pawchuck 3K D.
- **Round 4616 (8):** `e2622919` s13 Andre von Auto 2K D; `7c3ac6b5` s5 Andre von Auto 4K D; `1237f17e` s12 softmaxclaudius-t2 3K D; `0d1a746b` s15 soft-codexter-t2 6K W; `5e9c9e6d` s8 docxology 3K W; `f34cdd37` s5 Ari Sklar 2K D; `cf8ec069` s9 daveey 2K D; `cf8ec069` s15 Andre von Auto 3K W.
- **Round 4617 (5):** `f7bda239` s6 Jordan 2K W; `d760a137` s3 Andre von Auto 4K D; `94b1ef9c` s9 Games Bond 1K D; `b048486c` s2 Aaron 1K D; `0f833c17` s1 daveey-1 2K D.
- **Round 4618 (4):** `a701fd3d` s5 docxology 4K W; `943731e3` s3 soft-codexter-t2 3K D; `4e652105` s4 Lawrence 3K D; `f6f6b9db` s7 softmaxwell 3K D.
- **Round 4619 (5):** `ceddc86d` s9 macromackie 2K D; `278b4eec` s12 Aaron 2K D; `d5843d7c` s8 Ari Sklar 2K D; `d5843d7c` s10 softmaxclaudius-t2 2K D; `89851e37` s12 Aaron 6K W.
- **Round 4620 (9):** `82d8032b` s5 daveey 4K D; `31a97c75` s8 docxology 2K D; `92780073` s10 Games Bond 2K D; `62d8f464` s3 relh 2K D; `62d8f464` s4 Andre von Auto 2K D; `f3ffa4bf` s13 softmaxclaudius-t2 2K D; `b104d779` s13 daveey-1 2K D; `2b126a6a` s9 softmaxwell **0K D**; `3e6a26d3` s1 Aaron 4K D.
- **Round 4621 (6):** `92b876f8` s12 softmaxclaudius-t2 2K D; `8092869a` s4 Ari Sklar 2K D; `8092869a` s10 Lawrence 1K D; `c1158654` s5 pawchuck 3K D; `e0fac29f` s1 docxology 5K W; `6809767e` s13 @lessandro-forum-power-user 1K D.

The 0K softmaxwell cap cannot be a kill/First-Blood/Gun-V chain. It requires pact/co-damage or another non-kill deed path, but assigning a specific pact factor without the deed feed would be speculation. Likewise, a hosted 1K total is compatible with the verified longshot + First Blood + Gun-V route, but is not proof of it.

## Jordan diagnosis

### Hosted results

| Policy window | Seats | Kills | Kills/seat | Caps | Cap rate | Wins | Died with 0K |
|---|---:|---:|---:|---:|---:|---:|---:|
| v156, rounds 4611–4616 | 75 | 61 | 0.813 | 3 | 4.00% | 6 | 40 (53.3%) |
| v158, rounds 4617–4621 | 59 | 67 | 1.136 | 1 | 1.69% | 8 | 25 (42.4%) |
| **Combined** | **134** | **128** | **0.955** | **4** | **2.99%** | **14** | **65 (48.5%)** |

Kill distribution over all 134 seats was 0K: 65, 1K: 31, 2K: 23, 3K: 9, 4K: 6. There were 38 episodes with at least two kills. v158 materially improved raw kills and survival-to-first-kill versus v156, but produced only one cap in this short window. The bottleneck is therefore not merely “get more kills”; it is convert kills into First Blood, longshot/Gun-V, or a second high-factor deed before heat decays.

Jordan's four caps were:

- round 4611 `3064144e`, 2K, loss — route unavailable;
- round 4613 `297faa11`, 2K, loss — verified Tag + heated First Blood, then point-blank 207 ticks later;
- round 4614 `15646c3f`, 3K, loss — route unavailable; and
- round 4617 `f7bda239`, 2K, win — route unavailable.

### Exact timing and deed quality in the local 24-seat v156 subset

The two local rounds contain 24 Jordan seats, 18 kills (0.75/seat), 14 zero-kill deaths, four one-kill episodes, five two-kill episodes, and one four-kill episode. Only **one of 18 kills** was a longshot (`d=1049`); none of the other 17 reached 866 px. Jordan earned First Blood in **2/24 episodes**. One First Blood converted to a cap; the other cooled before the follow-up.

The eight consecutive kill gaps in the six multi-kill episodes were:

`207, 236, 245, 337, 365, 472, 612, 946` ticks (median 351).

Only 3/8 gaps were below the 270-tick heat window. One capped. The two sub-270 failures explain why “two quick kills” is necessary but not sufficient:

| Episode | Jordan kill ticks and gaps | Result | Why it did not cap |
|---|---|---|---|
| 4612 `2ee050ec` | t895 d1049; t1131 d638; Δ236 | score 21, D | K1 was Longshot ×6.24 and first Gun-V ×3.46, but Jordan did **not** get First Blood. K2 was reclassified as Closing Time ×1.27. Closing Time is below the small-factor gate at this accumulator, adds no useful product, and does not provide the expected heated ordinary-tag factor. |
| 4613 `88cfd920` | t1212; t1457 Δ245; t1929 Δ472; t2294 Δ365 | score 8, W | All four kills emitted Closing Time ×1.27. The first two were inside 270 ticks, but the small-gated, zero-drama deed did not build the tag/heat chain. The final score is the win multiplier on the seed product. |

The remaining multi-kill episodes were:

- `297faa11`: t849/t1056, Δ207; First Blood then point-blank; **capped**.
- `abc46e33`: t1204/t1541, Δ337; First Blood was earned, but the follow-up arrived 67 ticks after the heat window and emitted Closing Time; score 46.
- `df14e744`: t1031/t1643, Δ612; ordinary first tag, then Closing Time; score 2.
- `90c9da1c`: t893/t1839, Δ946; ordinary first tag, then Closing Time; score 2.

This gives three actionable failure modes:

1. **First-kill attrition:** 65/134 hosted seats died before a first kill. v191's removal of the opening hold directly targets this.
2. **Follow-up latency:** five of eight observed consecutive gaps missed 270 ticks; v191's recall move from 900 to 760 targets this.
3. **Low-value deed substitution:** two fast multi-kill episodes still failed because Closing Time replaced the ordinary heated tag. A recipe cannot directly guard on `self.heat` or `self.last_kill_tick`; those paths are not exposed. It must instead improve positioning and controller arbitration around weakened enemies.

## Ladder comparison

This comparison is based on all accepted calls in the 26 locally replayable episodes. It is population-level ladder behavior, not a cap-conditioned causal attribution: a call records the installed ladder, while cached controller intents and native reflexes can own later movement.

| Entrant / policy | Local seats | Calls/seat | K/seat | Local caps | Observed ladder character |
|---|---:|---:|---:|---:|---|
| Ari Sklar / `arisk-paintbot:v2` | 24 | 6.50 | 0.67 | 2 | Dynamic `target_law`; opening `scatter(320,300)` and `edge_ride`; later recalls commonly prefer weakened/isolated and add guarded supply/loot. Four pact calls. |
| docxology / `daf-paintbot-s2-v4:v1` | 24 | 7.88 | 0.83 | 0 | Every call has `target_law` + `edge_ride(240,260,0.8)`; preference `[bounty, revenge, weakened, isolated]`; frequent `jackal(900,bothWeakened,hpFloor=0)` above loot, plus scatter/supply. |
| softmaxclaudius-t2 / `apex:v38` | 23 | 0.96 | 0.87 | 2 | Nearly static custom `warden(holdTeams=0,lanePx=90,preferMode=3,protectOwn=true)` above `loot(detourMax=2500,medkits=false)`. No pact. |
| Jordan / `jordan-ctf-candidate:v156` | 24 | 3.00 | 0.75 | 1 | Three fixed calls. Opening target hold to zone phase 1, guarded supply/loot, edge. At t900: target > guarded supply > guarded loot > guarded `jackal(700,afterKill,hpFloor=2)` > edge; t1500 drops loot. v156 also required supply-run enemy clearance. |
| Andre von Houck / `vasilisa:v3` | 23 | 4.52 | 0.96 | 1 | Target weakened/isolated, supply, edge, with some loot/scatter. This is **not** Andre von Auto's v4. |

Play occurrence totals reinforce the architecture difference:

- Ari: 156 calls; target 155, edge 139, scatter 72, supply 45, loot 41, pact 4.
- docxology: 189 calls; target 189, edge 189, jackal 99, loot 76, scatter 71, supply 37.
- softmaxclaudius: 22 calls; custom warden 22, loot 22.
- Jordan: 72 calls; target/supply/edge 72 each, loot/jackal 48 each.

Andre von Auto led the hosted cap rate at 7/98, but no Auto replay or call report exists in this snapshot. Substituting Houck's v3 ladder for Auto's v4 would be false precision.

There is no single “cap ladder” in the exact routes. The last issued ladders before caps include two static `warden > loot` seats, several `target_law > scatter > edge_ride` seats, two `jackal > edge_ride` seats, and Jordan's `target > supply > loot > jackal > edge`. The repeatable commonality is the **combat geometry and timing**, not a shared public play.

Two differences are nevertheless useful:

1. Ari and docxology refresh their ladders roughly 2–2.6 times as often as Jordan, which refreshes cached controller intent and re-triggers finite controllers such as scatter. More calls are not automatically better, but three fixed calls give Jordan fewer chances to react to a new nearby fight.
2. docxology puts its aggressive jackal before loot. Jordan's t760 v191 recall still puts loot first. With an item within 250 px and the nearest enemy 501–700 px away, **both guards pass**; the first live movement controller wins, so loot can pre-empt the follow-up hunt. This overlap is exactly where the 700-px jackal should be useful.

v158 restored the [`v183-solo-margin240.env`](s2_patches/recipes/v183-solo-margin240.env) ladder after v156's rejected supply-clearance change. v191 keeps that structure, removes the opening `holdTrigger`, and advances the first recall from t900 to t760. Its hosted sample begins around round 4623 and is outside this report; do not attribute rounds 4611–4621 to v191.

## Three one-variable recipe tests after v191

These are ordered by expected value and reversibility. Each should be measured alone against v191 with comparable hosted rosters/episode counts. The quoted cap-rate changes are **absolute percentage-point priors** from a 3.0% Jordan baseline, not experimental estimates; 4 caps in 134 seats is far too sparse for precise prediction.

### 1. Put the t760 jackal above loot

Change only the order of the t760 recall from:

```text
target_law > supply_run(g) > loot(g) > jackal(g) > edge_ride
```

to:

```text
target_law > supply_run(g) > jackal(g) > loot(g) > edge_ride
```

Keep all v191 parameters and guards unchanged: `jackal(earshot=700, joinWhen=afterKill, exitAfter.hpFloor=2)` guarded by `0 < world.nearest_enemy_dist <= 700` and `self.hp_frac >= 0.4`; keep loot's item and enemy guards unchanged.

**Mechanism.** This changes behavior only in the meaningful guard overlap: item distance 1–250, enemy distance 501–700, and HP at least 40%. Today loot wins that arbitration and can spend part of the 270-tick window on a detour. Reordering makes the fight controller win. Thirty-seven of 74 hosted caps ended with 2K total, and every verified two-kill cap gap was at most 221 ticks. docxology's dynamic ladder also places jackal above loot.

**Expected cap-rate effect:** **+0.3 to +0.8 percentage points**. Downside is limited to extra `jackal:hold` ownership when an enemy is in the overlap but no qualifying recent kill exists; prior traces found that state rare, but the test should track it.

### 2. Add a hazard-gated longshot lane ahead of loot

Add `lane_warden` at t760 between supply and loot, so its long-range guard wins the otherwise overlapping loot guard: `target > supply(g) > lane(g) > loot(g) > jackal(g) > edge`. At t1500, where loot is absent, place it between jackal and edge. Use:

```json
{
  "play": "lane_warden",
  "params": {
    "margin": 240,
    "standoffMin": 866,
    "standoffMax": 1250,
    "coverRadius": 260,
    "hpFloor": 2
  },
  "when": [
    "and",
    [">=", ["get", "self.hp_frac"], 0.5],
    ["==", ["get", "world.enemy_count"], 1],
    [">=", ["get", "world.nearest_enemy_dist"], 866],
    ["<=", ["get", "world.nearest_enemy_dist"], 1300],
    ["get", "world.in_zone"],
    [">", ["get", "world.zone_ticks_until_outside"], 120],
    ["not", ["get", "world.grenade_threat"]],
    ["not", ["get", "world.spray_threat"]]
  ]
}
```

**Mechanism.** The controller holds a legal gun-range band at or beyond the 866-px longshot boundary, uses cover, and yields when multiple tracked enemies, gas timing, grenade threat, spray threat, or low HP make standoff unsafe. Eleven of 18 verified caps included a longshot, while Jordan produced only one longshot in 18 locally measured kills. A first longshot also opens the first Gun-V claim route.

**Expected cap-rate effect:** **+0.3 to +1.0 percentage points**. This must remain guarded. The prior unguarded/structural `v180f` longshot ladder produced a fatter tail but reduced pooled kills and wins (0.76 K/seat, 8% wins versus 0.88 and 10%); replacing edge wholesale is therefore not recommended. The guard makes this a narrow geometry test rather than a repeat of v180f.

### 3. Add the reciprocal Lawrence/softmaxwell pact overlay to v191

Add the already syntax-checked v190 overlay to every v191 call, without changing combat-controller order:

```json
{
  "play": "pact",
  "params": {
    "partners": ["$NAMES:Lawrence|softmaxwell"],
    "onBetrayal": "returnFire",
    "protect": false
  }
}
```

**Mechanism.** Lawrence named Jordan in every local call census and softmaxwell did so frequently, so this is likely to create actual mutual pacts rather than dead declarations. A mutual pact unlocks the ally-stack ×5 co-damage route, Joint Act ×2, pact-scoped down/wipe deeds, and revival. One of 18 exact caps was triggered by Pact Member Down, and the hosted census contains a 0K cap that requires a non-kill route.

**Expected cap-rate effect:** **+0.5 to +1.5 percentage points if mutuality remains high**, with the widest uncertainty of the three tests. The failure mode is uniquely severe: a pact ally's friendly down can halve an already capped bank outside the clamp. `protect=false` avoids bodyguard chasing and `returnFire` limits prolonged betrayal, but neither removes that economic risk. Track both raw `GLORY_CAP_HIT` and final reported 16,384; a halved post-cap seat should count as a pact failure, not a missed clamp.

## What not to retest first

- Do not add `bounty` preference: v184 fell to 0.96 K/episode versus v154's 1.30 and lost wins/jackpots.
- Do not restore v156's supply-clearance guard: its longer sample fell to 0.86 K/episode and sharply reduced wins. v158 correctly restored v183.
- Do not replace the ladder with scatter-only or an unconditional longshot warden: both have already traded away ordinary kill/win rate.
- Do not interpret Closing Time kills as useful heat-chain progress. Two exact Jordan counterexamples had sub-270 gaps and still failed because the ×1.27 deed was small-gated.

The target is not maximum aggression. It is more attempts at one of three specific conversions: early First Blood plus a second qualifying deed before tick +270; a safe >=866-px kill that can combine with First Blood/Gun-V; or a genuinely mutual pact co-damage sequence. v191 addresses the first attempt rate. The three tests above separately address controller arbitration, longshot geometry, and the pact multiplier path.
