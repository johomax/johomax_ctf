# What separates the Season 2 solo leaders

## Bottom line

The leaders separate from `jordan-ctf-candidate` in two different ways:

1. **More ordinary combat conversion.** Across 34 complete rounds, `apex:v38`
   made 0.963 kills/episode and won 12.0%, versus Jordan's pooled 0.463 and
   5.1%. Its damage rate was 4.76 versus 2.27. Several other leaders were in
   the 0.78--0.87 kill/episode band.
2. **Much fatter Glory tails.** Jordan's maximum seat-episode was 3,317,760.
   Four policies hit the current 16,777,216 cap, and `apex` reached
   14,929,920. Median scores remain tiny (usually 4--16), so these rare factor
   chains, not a smooth uplift, determine round sums and then the leaderboard
   EMA.

The v149/v150 split matters. V149 (360 episodes) made 0.411 kills/episode and
won 3.9%; v150 (48 episodes) made 0.854 and won 14.6%. V150 is a small sample,
but it has already closed most of the ordinary-kill gap. Its replay-visible
failure is much more specific: `supply_run` owns or stalls the base controller,
and the zone reflex rescues it until it sometimes cannot.

One naming correction from the dumps: `softmaxclaudius-t2` is the entrant
running `apex:v38`; there is no separate `softmaxcla` participant in this
cohort. The two co-gas entrants are `relh` and `richard`. `NanosaurusX` runs
`nancy-paintbot-s2:v5`.

## Data and method

- Round statistics use the 34 complete 12-episode bundles from rounds
  **4440--4477**: 4440--4449, 4451--4460, 4462--4470, 4472, and 4474--4477.
  That is 408 seat-episodes per continuing entrant and 6,528 seat-episodes in
  total. Round 4478 is deliberately excluded because it changes the stated
  cohort to Jordan v152 and substitutes another entrant. Source:
  [`research/br_rounds/`](br_rounds/).
- Replay timing and ladders use every supplied replay for the requested
  rounds. The repository actually contains **3 of 12** episodes for round
  4469 and all **12 of 12** for round 4475, hence 15 rather than 24 episodes.
  Sources: [round 4469](s2_replays/4469_round_a95503b7-44dc-4ca6-83c8-8f78512355d7/)
  and [round 4475](s2_replays/4475_round_d0e30825-8a0c-4a13-bdf1-79b4ada66192/).
- I parsed the shell records as documented by
  [`analysis/s2_replays.py`](../analysis/s2_replays.py), then re-simulated all
  15 replays under the matching GV59 engine. Every terminal replay hash
  matched. This exposed exact kill/deed events and a per-tick position/HP
  stream. The new decoder is
  [`analysis/s2_replay_positions.py`](../analysis/s2_replay_positions.py).
- “Early/mid/late” means tick `<1500`, `1500--2499`, and `>=2500`. Placement
  buckets exclude the one all-dead draw (`4475 ...96be`), so their denominator
  is 14 decisive replays. Intent-update rates are per 1,000 ticks alive after
  play begins at tick 800.
- These are descriptive associations, not isolated A/B effects. In
  particular, raw means over the 34 rounds are not the leaderboard: the board
  applies an EMA to each 12-episode sum.

## Per-policy results: 408 seat-episodes each

`D/ep` is hit damage per episode. `Death%` includes zone deaths. Achievement
counts are the end-card labels present in result JSON, not inferred deeds.

| Entrant (policy versions) | Median | Mean | Max | Win | K/ep | D/ep | Death | Round sum median / max / count >=1M |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| softmaxwell (`Monet:v41/v42`) | 12 | 171,234.9 | 16,777,216 | 7.1% | 0.816 | 3.87 | 92.9% | 52,949 / 16,881,910 / 6 |
| softmaxclaudius-t2 (`apex:v38`) | 12 | 116,148.5 | 14,929,920 | 12.0% | 0.963 | 4.76 | 88.0% | 99,152 / 15,068,868 / 7 |
| daveey (`paintbot-huddle:v159`) | 12 | 94,345.8 | 16,777,216 | 7.8% | 0.809 | 3.46 | 92.2% | 25,046 / 16,779,568 / 3 |
| docxology (`daf-paintbot-s2-v4:v1`) | 16 | 79,416.7 | 16,777,216 | 9.1% | 0.873 | 4.15 | 90.9% | 48,463 / 25,419,934 / 2 |
| NanosaurusX (`nancy-paintbot-s2:v5`) | 4 | 66,129.4 | 16,777,216 | 4.2% | 0.404 | 2.07 | 95.8% | 1,575 / 16,777,302 / 4 |
| Lawrence (`lw-pax:v1`) | 16 | 60,847.4 | 15,925,248 | 6.6% | 0.777 | 4.08 | 93.4% | 32,618 / 15,931,646 / 3 |
| Ari Sklar (`arisk-paintbot:v2`) | 6 | 59,654.1 | 16,777,216 | 4.4% | 0.578 | 3.10 | 95.6% | 7,605 / 17,219,736 / 2 |
| Aaron (`aaron-paintbot:v7`) | 12 | 57,086.3 | 10,616,832 | 5.6% | 0.782 | 4.07 | 94.4% | 24,353 / 11,253,018 / 3 |
| relh (`co-gas-...-relhalpha:v16`) | 16 | 52,937.1 | 16,777,216 | 7.4% | 0.848 | 3.94 | 92.6% | 11,792 / 16,778,366 / 2 |
| daveey-1 (`paintbot-huddle:v160`) | 6 | 49,532.9 | 16,777,216 | 6.1% | 0.576 | 2.91 | 93.9% | 6,296 / 16,976,274 / 2 |
| macromackie (`macromackie-paintbot:v1`) | 12 | 25,662.4 | 5,308,416 | 3.9% | 0.703 | 3.55 | 96.1% | 9,888 / 5,320,982 / 2 |
| **Jordan (`jordan-ctf-candidate:v149/v150`)** | **4** | **20,739.3** | **3,317,760** | **5.1%** | **0.463** | **2.27** | **94.9%** | **1,152 / 3,459,012 / 2** |
| richard (`co-gas-...-richard:v1`) | 12 | 16,081.3 | 4,147,200 | 5.9% | 0.716 | 3.76 | 94.1% | 7,099 / 4,148,280 / 1 |
| soft-codexter-t2 (`...jackal-radius600:v1`) | 4 | 14,968.3 | 3,981,312 | 2.9% | 0.407 | 2.07 | 97.1% | 375 / 3,984,454 / 1 |
| @lessandro (`...envoy:v28/v29`) | 12 | 8,240.8 | 1,327,104 | 5.1% | 0.703 | 3.38 | 94.9% | 7,210 / 1,361,038 / 1 |
| pawchuck (`bruce:v3`) | 6 | 4,330.5 | 663,552 | 3.9% | 0.635 | 3.60 | 96.1% | 9,942 / 664,288 / 0 |

Achievements observed:

| Entrant | End-card achievements (episode counts) |
|---|---|
| softmaxwell | silent 29; sniper 25; almost 10; spotless 8 |
| softmaxclaudius-t2 / apex | silent 49; sniper 39; almost 8; spotless 5; banksy 3; grenadier 1 |
| daveey | silent 32; sniper 21; spotless 11; banksy 5; almost 4 |
| docxology | silent 37; sniper 34; spotless 15; almost 8 |
| NanosaurusX / nancy | silent 17; sniper 12; spotless 4; almost 3; banksy 2 |
| Lawrence | silent 27; sniper 26; spotless 14; almost 3 |
| Ari Sklar | silent 18; sniper 15; spotless 10; almost 4; banksy 1 |
| Aaron | silent 23; sniper 20; spotless 11; almost 6 |
| relh | silent 30; sniper 28; spotless 15; almost 3; banksy 1 |
| daveey-1 | silent 25; sniper 18; almost 8; spotless 6; grenadier 1 |
| macromackie | sniper 16; silent 16; spotless 7; almost 4 |
| **Jordan** | **silent 21; sniper 17; spotless 8; almost 6** |
| richard | silent 24; sniper 23; spotless 13; almost 6 |
| soft-codexter-t2 | silent 12; sniper 11; almost 6; spotless 3 |
| @lessandro | silent 21; sniper 20; spotless 6; almost 5 |
| pawchuck | silent 16; sniper 14; almost 4; spotless 3 |

All 6,528 rows reported zero team kills. Nine rows hit the current
16,777,216 score cap. The modal score was 2 (1,701 rows); only two rows
scored 1.

### The version split

| Version | n | Median | Mean | Max | Win | K/ep | Four v150 round sums |
|---|---:|---:|---:|---:|---:|---:|---|
| Jordan v149 | 360 | 4 | 20,167.4 | 3,317,760 | 3.9% | 0.411 | -- |
| Jordan v150 | 48 | 12 | 25,028.7 | 663,552 | 14.6% | 0.854 | 57,940; 860,562; 24,710; 258,164 |
| Monet v41 | 384 | 12 | 179,960.6 | 16,777,216 | 7.0% | 0.815 | -- |
| Monet v42 | 24 | 11 | 31,623.3 | 663,552 | 8.3% | 0.833 | 737,430; 21,530 |

V150 and Monet v42 are too small for a stable tail estimate. In particular,
v150's higher win rate should not be read as proven superiority from 48
episodes.

## Kill timing, death timing, and placement in the 15 replays

`E/M/L` uses the tick bands defined above. Placement columns are
`1 / 2--4 / 5--8 / 9--12 / 13--16` over 14 decisive episodes.

| Entrant | Replay kills | Kill E/M/L | Deaths | Median death tick | Death E/M/L | Placement buckets |
|---|---:|---:|---:|---:|---:|---:|
| @lessandro | 9 | 5/4/0 | 14 | 1,195.5 | 10/3/1 | 1/3/1/2/7 |
| Aaron | 9 | 5/4/0 | 15 | 1,427 | 9/6/0 | 0/3/5/4/2 |
| Ari Sklar | 10 | 10/0/0 | 14 | 1,183.5 | 11/3/0 | 1/1/1/9/2 |
| **Jordan** | **21** | **11/9/1** | **12** | **1,730** | **5/5/2** | **3/7/1/0/3** |
| Lawrence | 13 | 13/0/0 | 15 | 1,536 | 7/7/1 | 0/3/7/1/3 |
| NanosaurusX | 7 | 5/2/0 | 15 | 1,259 | 11/4/0 | 0/1/4/3/6 |
| daveey | 15 | 10/5/0 | 15 | 1,449 | 8/6/1 | 0/4/4/4/2 |
| daveey-1 | 10 | 7/3/0 | 14 | 1,387.5 | 9/5/0 | 1/2/7/2/2 |
| docxology | 18 | 8/9/1 | 12 | 1,220 | 9/3/0 | 3/3/1/5/2 |
| macromackie | 8 | 5/3/0 | 14 | 1,386 | 9/5/0 | 1/4/2/4/3 |
| pawchuck | 10 | 8/2/0 | 13 | 1,220 | 10/3/0 | 2/0/5/3/4 |
| relh | 11 | 8/3/0 | 15 | 1,413 | 9/5/1 | 0/4/5/3/2 |
| richard | 13 | 10/3/0 | 15 | 1,541 | 7/7/1 | 0/5/3/2/4 |
| soft-codexter-t2 | 5 | 5/0/0 | 15 | 994 | 14/1/0 | 0/0/4/5/5 |
| softmaxclaudius-t2 / apex | 13 | 7/6/0 | 13 | 1,319 | 9/4/0 | 2/2/4/4/2 |
| softmaxwell | 3 | 2/1/0 | 15 | 1,140 | 13/2/0 | 0/0/2/6/6 |

This small replay slice happens to be excellent for v150 (18 kills and three
wins in its 12 episodes) and terrible for Monet (three kills, no wins), so the
408-episode table is the right source for rate comparisons. The timing slice
is useful for mechanisms: Jordan reaches late play much more often here, and
16 of its 21 kills are Closing Time or Last Light factor events.

## What a 1M+ twelve-episode round is made of

There were 41 entrant-rounds at or above 1,000,000 among the 544
entrant-rounds in scope.

| Quantity within those 41 rounds | Median | Mean | Range |
|---|---:|---:|---:|
| Twelve-episode sum | 4,423,902 | 7,919,264 | 1,112,298--25,419,934 |
| Wins | 1 | 1.73 | 0--5 |
| Kills | 12 | 12.71 | 6--25 |
| Best single episode | 4,423,680 | 7,558,581 | 829,440--16,777,216 |
| Episodes >=100k | 1 | 1.49 | 1--4 |
| Episodes >=1M | 1 | 0.98 | 0--3 |

The best episode supplied a median **99.31%** of the round sum; the best two
supplied **99.98%**, and the best three **99.996%**. Four useful near-threshold
examples show that even the win count is secondary to one factor chain:

| Entrant, round | Sum | Largest episode | Wins | Kills |
|---|---:|---:|---:|---:|
| relh, 4463 | 1,112,298 | 884,736 | 3 | 14 |
| softmaxwell, 4444 | 1,161,428 | 884,736 | 2 | 8 |
| Aaron, 4472 | 1,161,736 | 1,119,744 | 0 | 11 |
| apex, 4467 | 1,186,628 | 884,736 | 3 | 12 |

So “a 1M round” is normally eleven negligible episodes plus one jackpot.
Optimizing a median episode alone will not move the EMA enough; the policy
must preserve enough survival and positioning to assemble a rare multiplicative
chain.

## Which Glory factors actually appear

The supplied wiki page is stamped GV52 and describes the earlier duo regime:
[`research/wiki/glory-season-2.md`](wiki/glory-season-2.md). The hash-exact
GV59 solo replays show the current realized rules:

- product seed 1;
- Final 8 x2, Final 4 x3, Final 2 x4, and an implicit win x8;
- Longshot base x3 at this config's 866 px threshold, Ace base x4, Closing
  Time base x3, Last Light base x4;
- enemy territory shifts a positive deed up one rung; heat then contributes
  x1/x2/x4/x8;
- first Tier-V achievement claim is x12 (Tier V x4 times first-claim x3);
- the final squad/clean-sheet achievement contributed x2 to every seat in
  these 15 replays;
- `JointAct` is live and usually appeared as x3 on enemy territory;
- the realized product is capped at 16,777,216.

The following are exact event counts in the 15 replays. `Terr.` counts deed
events whose factor reveals the +1-rung enemy-territory premium; `Heat` counts
events whose remaining excess requires heat. `Place` is the number of
Final-8/Final-4/Final-2 factors, not final placement.

| Entrant | Longshot | First blood | Ace | Closing | Last light | Terr. | Heat | Place 8/4/2 | Win x8 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| softmaxwell | 0 | 0 | 0 | 2 | 0 | 13 | 0 | 2/0/0 | 0 |
| apex | 1 | 1 | 0 | 8 | 0 | 20 | 2 | 8/4/2 | 2 |
| daveey | 0 | 2 | 0 | 7 | 0 | 18 | 2 | 9/5/1 | 0 |
| daveey-1 | 1 | 3 | 0 | 6 | 0 | 20 | 4 | 11/4/2 | 1 |
| Lawrence | 4 | 1 | 0 | 4 | 0 | 23 | 3 | 11/4/1 | 0 |
| NanosaurusX / nancy | 0 | 0 | 0 | 4 | 0 | 10 | 0 | 6/1/0 | 0 |
| relh | 2 | 0 | 0 | 8 | 0 | 18 | 0 | 10/5/3 | 0 |
| richard | 3 | 2 | 0 | 5 | 0 | 21 | 4 | 8/5/1 | 0 |
| **Jordan** | **1** | **1** | **0** | **15** | **1** | **30** | **1** | **11/10/7** | **3** |

No Ace appeared. The leaders' distinguishing rare mechanism in this slice is
Longshot plus heat/Tier-V stacking, not Ace. Two exact products make the
economy concrete:

- Jordan's 663,552 win in round 4475 (`...3075`) is
  `clean x2 * JointAct x3^3 * Closing x4^3 * placement (x2*x3*x4) * win x8`.
  Source: [episode JSON](br_rounds/4475_round_d0e30825-8a0c-4a13-bdf1-79b4ada66192/ereq_2e7e1206-d527-42a2-b16c-b59d7d623075.json)
  and [replay](s2_replays/4475_round_d0e30825-8a0c-4a13-bdf1-79b4ada66192/ereq_2e7e1206-d527-42a2-b16c-b59d7d623075.replay).
- Lawrence's 221,184 loss in the all-dead draw (`...96be`) includes two
  Longshots worth x8 and x16, a first Tier-V x12, placement
  `x2*x3*x4`, JointAct x3, and clean x2. It needed no win factor.
  Source: [episode JSON](br_rounds/4475_round_d0e30825-8a0c-4a13-bdf1-79b4ada66192/ereq_d9af4a41-4bfe-4dab-94ef-acacc85496be.json)
  and [replay](s2_replays/4475_round_d0e30825-8a0c-4a13-bdf1-79b4ada66192/ereq_d9af4a41-4bfe-4dab-94ef-acacc85496be.replay).

## Leader ladders

An “appearance” below counts a play each time a ladder was called, so repeated
recalls count again.

| Entrant | Opening seen | Recalls and important parameters |
|---|---|---|
| softmaxwell | 14/15 `target_law > scatter`; 1/15 `target_law > edge_ride` | 6.9 calls/episode, median recall tick 944.5. Target preference usually `weakened, revenge, bounty, isolated`; scatter 320 px/300 t; conditional loot, supply, jackal and edge ride. Custom `fire_superiority` 58 appearances (`engageDist=600`, `coverMax=260`, `pressRange=220`), `ring_walker` 23, `hold_vs_gun` 12. |
| apex | 13/15 `warden > loot`; two episodes have no accepted call | No recalls. Custom `warden(holdTeams=0,lanePx=90,preferMode=3,protectOwn=true)` plus `loot(contested=avoid,detourMax=2500,medkits=false)`. This is the cleanest custom-play signature in the field. |
| daveey | 15/15 `loot > scatter > edge_ride` | 4.9 calls/episode; median recall 1,349. Adds `target_law`, `supply_run`, and `jackal(joinWhen=afterKill,earshot=900)`. Edge ride is usually margin 220, enter lead 160, cover bias .75. Three `bodyguard` appearances; it is an engine reference play but outside our allowed set. |
| daveey-1 | Usually `loot > scatter > edge_ride > jackal > crossfire` | 5.1 calls/episode; median recall 1,307. Jackal after-kill at earshot 600; edge margin 140/lead 80--100; frequent supply and target-law recalls. `crossfire` has 29 appearances; it too is a reference play outside our allowed set, not custom. |
| Lawrence | 13/15 `pact > target_law > scatter > edge_ride`; one jackal opener; one no call | 7.7 calls/episode; median recall 1,186. Always retains pact/law/edge, conditionally swapping scatter, jackal, loot and supply. Conservative edge settings: margin 300, enter lead 200, cover bias .9. No custom play. |
| NanosaurusX | 15/15 `target_law > scatter > edge_ride` | 7.9 calls/episode; median recall 995. Adds pact, supply and loot. Typical edge margin 240--260 and lead 120--180. No custom play. |
| relh | 15/15 `edge_ride > target_law` | Exactly one recall per episode, median tick 671 (pre-start); randomized margins/headings, then occasional pact. No custom play. |
| richard | 13/15 `edge_ride > target_law`; 2 add supply | Exactly one recall per episode, median tick 659 (pre-start); randomized margins/headings, occasional pact. No custom play. |
| **Jordan** | v149's three: `edge_ride`; v150's twelve: `target_law > supply_run > loot > edge_ride` | Exactly three calls/episode. V150 adds `jackal(afterKill,earshot=700)` near tick 902 and removes loot near 1,503. Its opening edge is margin 420/lead 320, but recalls replace that with margin 140 then 120 and lead 80. |

The custom status is inferred conservatively: the replay records a play name
and module hash, not source. `warden`, `fire_superiority`, `ring_walker`, and
`hold_vs_gun` have no matching GV59 reference module; `bodyguard` and
`crossfire` do.

### Intent churn

“Updates” counts every recorded effective intent change, including a controller
refreshing a nearby destination each tick. “Mode switches” collapses away
coordinates and combat overlays and counts changes of `(intent kind, reason)`.
This distinguishes smooth point refresh from a real controller-mode change.

| Entrant | Calls/ep | Intent updates / 1k alive ticks | Mode switches / 1k | Dominant movement reasons |
|---|---:|---:|---:|---|
| softmaxwell | 6.9 | 224.9 | 17.4 | zone escape, ring walker, scatter, fire superiority |
| apex | 0.9 | 181.0 | 5.6 | zone escape, loot |
| daveey | 4.9 | 291.4 | 5.1 | zone escape, scatter, loot |
| daveey-1 | 5.1 | 222.7 | 3.3 | zone escape, loot |
| Lawrence | 7.7 | 455.8 | 7.4 | zone escape, scatter |
| NanosaurusX | 7.9 | 273.6 | 11.9 | zone escape, scatter |
| relh | 2.0 | 497.1 | 3.4 | zone escape, edge ride |
| richard | 2.0 | 543.4 | 1.2 | zone escape, edge ride |
| **Jordan** | **3.0** | **200.3** | **5.0** | **zone escape, jackal, supply run** |

The high raw rates are mostly one-tick destination refreshes: the median gap
between update annotations is one tick for every listed entrant. There is no
simple “more churn wins” relationship. Apex is both low-churn and the best
ordinary converter; relh/richard refresh constantly but rarely change mode.

### Pacts and no-shoots

Pact declarations and `target_law.never` are local orders. A unilateral pact
is not a truce unless the other policy also suppresses fire.

- Lawrence declares both pact and no-shoot toward **Jordan, daveey and relh in
  14/15** episodes. Relh reciprocates the Lawrence pact in 9/15 and reciprocal
  no-shoot exists in 10/15. Jordan and daveey do not reciprocate.
- NanosaurusX pacts Lawrence in 12/15, daveey-1 in 3/15, and relh in 1/15.
  These are almost entirely unilateral.
- Relh pacts Jordan 7/15, daveey 6/15, @lessandro 4/15, Lawrence 9/15, and
  smaller sets. Jordan never calls `pact` or sets `never` in these replays.
- Monet's target law no-shoots Lawrence in 10/15, but it calls an explicit
  pact with Lawrence and docxology in only one episode.

Strict mutual pacts observed: Lawrence--relh 9/15,
@lessandro--relh 2/15, @lessandro--richard 1/15, and
NanosaurusX--relh 1/15. Reciprocal `never`/no-shoot pairs were:

| Pair | Episodes / 15 |
|---|---:|
| Lawrence--relh | 10 |
| @lessandro--richard | 3 |
| @lessandro--relh | 3 |
| NanosaurusX--relh | 2 |
| relh--softmaxwell | 2 |
| richard--softmaxwell | 1 |
| NanosaurusX--richard | 1 |

Apex's `warden(protectOwn=true)` emits protection/no-shoot for its own team;
in the 16-team solo config that is self-only, not a cross-entrant truce.

## How Jordan dies

There are 12 deaths and three wins in the 15 replay episodes. Killers were:
zone/environment 3, NanosaurusX 2, docxology 2, and one each by daveey,
soft-codexter-t2, apex, macromackie, and relh. For the nine combat deaths,
the reconstructed killer distance has median **232 px**, range **136--565**;
none was remotely close to the 866 px Longshot threshold.

`Edge margin` is signed distance from Jordan to the nearest edge of the exact
current zone rectangle: negative means already outside. Direction compares
that margin with the position 24 ticks earlier, holding the death-tick edge
fixed, so it describes player motion rather than ring shrink. The final column
shows the last non-reflex controller; a zone reflex may have overridden it at
the actual death tick.

| Round / episode suffix | Tick | Place | Killer | Distance px | Jordan xy | Edge margin | Motion over 24 t | Last non-reflex intent / owner |
|---|---:|---:|---|---:|---|---:|---|---|
| 4469 `2ac6` | 1,878 | 4 | daveey | 136 | 2194,346 | +140 | lateral/still (+0) | `edge_ride:cover` / `edge_ride#0` |
| 4469 `fdd6` | 874 | 15 | soft-codexter-t2 | 471 | 2640,276 | +276 | lateral/still (+0) | `edge_ride:hold` / `edge_ride#0` |
| 4475 `f1e9` | 1,767 | 4 | apex | 213 | 816,621 | +45 | inward (+32) | `supply_run:hold` / `supply_run#1` |
| 4475 `8909` | 2,229 | 2 | docxology | 232 | 2749,1276 | +55 | lateral/still (+0) | `supply_run:hold` / `supply_run#1` |
| 4475 `4040` | 924 | 14 | NanosaurusX | 565 | 2577,959 | +634 | inward (+9) | `edge_ride:hold` / `edge_ride#4` |
| 4475 `a4c7` | 3,285 | 2 | zone | -- | 1010,553 | **-3** | nearly stalled (+3) | `jackal:join` / `jackal#3` |
| 4475 `1e54` | 2,306 | 2 | macromackie | 203 | 698,1476 | +134 | lateral/still (+0) | `jackal:join` / `jackal#3` |
| 4475 `ae5a` | 1,693 | 4 | relh | 446 | 2354,619 | +88 | inward (+30) | `supply_run:hold` / `supply_run#1` |
| 4475 `96be` | 1,337 | draw | zone | -- | 703,629 | **-122** | inward (+31) | `supply_run:hold` / `supply_run#1` |
| 4475 `16f4` | 860 | 15 | NanosaurusX | 320 | 1352,935 | +778 | inward (+34) | `supply_run:medkit` / `supply_run#1` |
| 4475 `7800` | 3,300 | 2 | docxology | 209 | 2125,1134 | +23 | inward (+19) | `supply_run:hold` / `supply_run#1` |
| 4475 `29b8` | 1,287 | 7 | zone | -- | 2218,309 | **-33** | inward (+64) | `supply_run:hold` / `supply_run#1` |

Seven deaths show inward motion, five are lateral/stalled, and none is moving
outward. That does **not** exonerate zone control: all three zone deaths are
already outside and trying to return, i.e. the response is late. More
importantly, among v150's nine replay losses, the last non-reflex controller
is `supply_run` in seven (six holds and one medkit). Its high ladder position
lets a non-actionable supply play hold before `edge_ride`; the zone reflex is
doing most of the subsequent movement.

## Five changes to test, ranked

Effect sizes below are screening priors from observational data, not confidence
intervals. Per the repository's measurement rules, land none of them without
a one-variable, both-direction local test and a hosted A/B.

| Rank | One-variable ladder experiment | Evidence | Expected effect to screen for |
|---:|---|---|---|
| 1 | **Remove `supply_run` from v150.** Keep the rest of the three calls identical. | It appears in every v150 call and is the last non-reflex owner in 7/9 replay losses. Six are `supply_run:hold`; three episodes die outside the ring despite an active escape reflex. | Reduce zone deaths by roughly **0.15--0.25/episode** (2--3 per 12) and convert at least one runner-up/Final-8 run into another placement or win factor. This is the strongest mechanism-backed change. |
| 2 | **Raise only recalled `edge_ride.margin` from 120--140 to 240.** Do not change enter lead in the same experiment. | V150 replaces a safe opening margin 420 with 140 then 120. Lawrence uses 300, daveey 220, Nancy 240--260. Jordan's three zone deaths are 3--122 px outside and returning late. | Reduce zone deaths by **0.08--0.17/episode** (1--2 per 12) and increase Final-8 reach by a similar order. Crossing Final-8/4/2 is directly worth x2/x3/x4. |
| 3 | **Add one custom Nim `lane_warden` controller, modeled on the observable behavior rather than copied code, ahead of loot.** | Apex is the best converter over 408 episodes (0.963 K/ep, 12.0% win, 4.76 damage) with a nearly static `warden > loot` ladder and no recalls. Its custom params expose a lane width of 90 and `preferMode=3`; its intent modes change only 5.6/1k ticks. | A realistic first target is **+0.10--0.25 K/ep** and **+2--4 percentage points** survival. The full pooled gaps (+0.50 K/ep, +6.9 pp win) are an upper bound, not an expectation. |
| 4 | **Add `bounty` as the next `target_law.prefer` item; test `revenge` separately afterward.** | Jordan uses only `weakened, isolated`. Monet usually adds revenge+bounty; daveey adds bounty. Above-and-beyond bounty is base x4, x5 on enemy territory, then heat-scaled. V150 is only 0.109 K/ep behind apex, so target quality is now more important than adding indiscriminate aggression. | **+0.05--0.15 K/ep**, with a larger tail effect when one bounty produces x4--x10 before later heat deeds. Reject if survival falls by more than ~2 pp. |
| 5 | **Write a custom standoff/cover play whose sole trigger is a visible finish at >=866 px; keep it below zone safety.** | Lawrence recorded 4 Longshots/15, richard 3, relh 2, Jordan 1. Lawrence's 221,184 loss contains Longshot x8 and x16 plus first Tier-V x12. None of Jordan's deaths was at longshot distance, so this adds an earning surface rather than addressing a current incoming threat. | Add **0.07--0.13 Longshots/episode** (reach relh/richard frequency). Each hit was x4--x16 in these replays, with a possible first Tier-V x12; expect tail probability to move, not median score. |

I would not put a reciprocal pact in the first five. Lawrence already
unilaterally no-shoots Jordan in 14/15 and relh does so in 7/15, while only one
of Jordan's nine combat deaths came from either. Reciprocating would remove
targets without evidence of enough additional protection.

## Reproducibility notes

- Result fields and policy versions come directly from each episode's paired
  request/results JSON.
- Calls, parameters, death ticks, and annotations come from format-2 replay
  records verified by the terminal manifest.
- Kill ticks, deed factors, zone centers, and per-tick positions come from a
  deterministic re-simulation whose terminal hashes matched all 15 stored
  replays. Positions were decoded with the new helper linked above.
- Scores alone do not uniquely factor into deeds. Factor counts are therefore
  exact only for the 15 replay episodes; the 408-episode table does not pretend
  to reverse-factor ambiguous integers.
