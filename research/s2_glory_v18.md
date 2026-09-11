# Paintbot solo battle royale: GLORYVERSION 18

Date: 2026-09-11  
Engine: `1b92ec46` (`S8 SHIP`, `paintbot-v0.7.397`)  
Live from: round 4828, approximately 21:20Z

## Verdict

The new 2,097,152 ceiling is not a conventional ceiling. The live percentage-fold implementation still checks

```text
P >= floor(C / q)
```

before applying `q%`, rather than comparing against roughly `100*C/q`. Here `P` is the raw fixed-point accumulator, `C = 2^31 = 2,147,483,648`, and the displayed score is `floor(P / 1024)`. The check therefore saturates about 100 times earlier than the multiplication itself would require.

That bug makes the practical routes much shorter than a literal product of 2,097,152 would suggest:

- without pact help, the shortest ordinary routes take two hostile kills: First Blood plus a longshot/Gun-V package and one more heated deed, followed by the conclusion-time Clean Sheet claim;
- three rapid gun tags cap directly if the first tag also earns First Blood; four rapid tags do it without First Blood;
- a First-Blood spray double-kill caps at the conclusion, and a First-Blood grenade double-kill plus a third grenade kill does too;
- the new tier-completion bonus makes a deliberately delayed first longshot after three gun kills a three-kill loss cap, first or non-first;
- with a real pact ally in the victim's damage incident, a single First-Blood Bounty kill at longshot range can cap at Clean Sheet.

Winning is neither required nor, in the normal 16-team sequence, capable of being the first cap-triggering fold. FINAL 2 happens before the whole-number win ×8 and its faulty percentage precheck constrains every still-uncapped finalist. The win remains valuable only for a leg that is still below the ceiling. Once `P == C`, hostile death and losing cost no Glory; friendly-fire halvings are the sole remaining way to reduce the reported bank.

The first five live rounds contain nine capped legs in 1,200 field seats, or 0.09 caps per 12 seats. That is far too short a window to rank entrants. A sustainable target is at least **0.5 caps per 12**—one cap every two approximately 12-seat rounds—and the minimum competitive gate is to clear the current noisy best point estimate of roughly 0.4 per 12.

## 1. Exact fold law

These results extend the established GV17 analysis in [s2_glory_v17.md](s2_glory_v17.md), [s2_glory_v17_legs.md](s2_glory_v17_legs.md), and [s2_v17_cap_routes.md](s2_v17_cap_routes.md). Only the S8 changes are different: `C`, Tier IV, Tier V non-first, the mode-light bonus, and placement.

Let:

```text
S = 1024
C = 2^31 = 2,147,483,648 raw = 2,097,152 reported
P0 = S = 1,024 raw = 1 reported
```

For a percentage factor `q`, the engine computes:

```text
Fq(P) = P                         if q <= 100
        P                         if 100 < q < 200 and P < 64*S
        C                         if P >= floor(C/q)       # premature precheck
        floor(P*q/100)            otherwise
```

For a whole-number factor `m`, including the mode-light bonus and win:

```text
Wm(P) = C                         if P >= floor(C/m)
        P*m                       otherwise
```

After `h` friendly-fire incidents, the displayed result is:

```text
floor(floor(P / 2^h) / 1024)
```

The following raw thresholds are the useful tripwires. Reaching the threshold **before** the named percentage fold makes that fold return `C` immediately.

| Fold | `q` | Raw precheck `floor(C/q)` | Approximately reported before fold |
|---|---:|---:|---:|
| FINAL 8 | 115 | 18,673,770 | 18,236 |
| FINAL 4 | 130 | 16,519,104 | 16,132 |
| FINAL 2 | 160 | 13,421,772 | 13,107 |
| ordinary tag | 220 | 9,761,289 | 9,533 |
| Tier IV / Clean Sheet | 250 | 8,589,934 | 8,389 |
| Tier V, non-first | 300 | 7,158,278 | 6,991 |
| Tier V, first | 346 | 6,206,600 | 6,061 |
| unheated home longshot | 600 | 3,579,139 | 3,495 |
| heated-5 tag | 1,100 | 1,952,257 | 1,907 |
| heated-5 home First Blood | 2,000 | 1,073,741 | 1,049 |
| heated-5 enemy First Blood | 2,120 | 1,012,963 | 989 |
| heated-14 tag | 3,080 | 697,234 | 681 |
| heated-14 point-blank | 3,500 | 613,566 | 599 |
| heated-14 home longshot/splash | 8,400 | 255,652 | 250 |
| heated-14 enemy longshot/splash | 8,736 | 245,820 | 240 |
| heated-14 home Bounty | 12,600 | 170,435 | 166 |

The small-factor gate matters only to `100 < q < 200`: placement and Closing Time are skipped while the displayed accumulator is below 64. Tier/deed folds of `q >= 200` apply from the seed.

One kill supplies only one primary kill deed. Precedence is friendly/carrier/Ace/multi/longshot/point-blank/revenge/rundown/escort/spray/grenade/tag, so a longshot kill of an Ace is a **Bounty deed**, not both Bounty and longshot deeds. The same kill can still increment the Gun-tree Bounty and Longshot achievement counters.

The route arithmetic below assumes that the kill is early enough not to be replaced by Closing Time or Last Light and that no victim-side pact-down/wipe marquee overrides it. Closing Time's `q120` is a weak, no-heat fold and usually destroys rather than extends a heat-chain route.

### Heat timing

The primary hostile deed folds first, then raises heat. First Blood is a separate deed for the same kill and reads the newly raised heat, so an ordinary first kill makes First Blood `4 * 5 = q2000` at home (`q2120` on enemy ground). It adds another ember. A prompt second deed therefore reads the ×14 rung. Two heat embers decay after 270 quiet ticks, so the fast-chain routes below require the next deed inside that window.

### Route A: First Blood plus two heated tags — three kills, direct cap

Home-ground arithmetic:

| Event | Fold | Raw `P` after fold | Displayed floor |
|---|---:|---:|---:|
| seed | — | 1,024 | 1 |
| K1 Tag | `q220` | 2,252 | 2 |
| K1 First Blood at heat ×5 | `q2000` | 45,040 | 43 |
| K2 Tag at heat ×14 | `q3080` | 1,387,232 | 1,354 |
| K3 Tag at heat ×14 | `q3080` | **2,147,483,648** | **2,097,152** |

The last precheck is `1,387,232 >= floor(C/3080) = 697,234`. On enemy ground First Blood produces 47,742 and K2 produces 1,470,453; K3 still caps. Minimum: three kill deeds, plus the separate First Blood deed, across three kills.

Without First Blood, four prompt tags are sufficient:

```text
1,024 --tag q220--> 2,252
      --tag heat5 q1100--> 24,772
      --tag heat14 q3080--> 762,977
      --tag heat14 q3080, precheck 762,977 >= 697,234--> C
```

Minimum: four deeds/four kills. Three plain tags do not cap through placement, Clean Sheet, and a win.

### Route B: first longshot + First Blood + Gun V + heated tag — two-kill loss cap

Assume home ground and first Gun-V claim:

```text
seed                                      1,024  (1)
K1 Longshot, q600                         6,144  (6)
K1 First Blood, heat5 q2000             122,880  (120)
Gun V first, q346                       425,164  (415)
K2 Tag, heat14 q3080                 13,095,051  (12,788)
Clean Sheet, q250 precheck                  C     (2,097,152)
```

Clean Sheet caps because 13,095,051 exceeds 8,589,934. A non-first Gun V also works: `122,880 -> 368,640 -> 11,354,112 -> C`.

If K2 is a heated longshot/splash (`q8400`), revenge/rundown (`q5600`), or Bounty (`q12600`), K2 itself caps. A heated tag or point-blank does not cap directly from 425,164 but leaves enough for Clean Sheet. A common spray/grenade primary deed (`q100`) or Closing Time (`q120`) does not complete this route.

Minimum: two kill deeds plus First Blood, Gun V, and Clean Sheet; two hostile kills.

### Route C: tag + First Blood, then longshot + Gun V — two-kill loss cap

This is the reverse order of Route B:

```text
1,024 --tag q220--> 2,252
      --First Blood heat5 q2000--> 45,040
      --K2 longshot heat14 q8400--> 3,783,360
      --Gun V first q346--> 13,090,425
      --Clean Sheet q250 precheck--> C
```

Non-first Gun V produces 11,350,080 before Clean Sheet and also caps. Minimum: two kills. This is the cleanest explanation for a two-kill capped loss without a pact stack or tool multi-kill.

### Route D: no First Blood, repeated longshots — three-kill cap

With a first Gun-V claim on K1:

```text
1,024 --K1 longshot q600--> 6,144
      --Gun V first q346--> 21,258
      --K2 longshot heat5 q3000--> 637,740
      --K3 longshot heat14 q8400, precheck 637,740 >= 255,652--> C
```

If K3 is only a tag, it makes `19,642,392`, and Clean Sheet then caps. Minimum: three kills either way.

### Route E: delay the first longshot until Gun II is banked — three-kill loss cap

This is the most important new Gun-tree route. Make two prompt gun tags, then make K3 the first longshot. Gun I and Gun II are already claimed when Gun V is processed, so the top-tier claim receives the new ×2 light bonus:

```text
1,024 --K1 tag q220--> 2,252
      --K2 tag heat5 q1100--> 24,772
      --K3 first longshot heat14 q8400--> 2,080,848
      --Gun V first q346--> 7,199,734
      --two-lower-tier light bonus, whole x2--> 14,399,468
      --Clean Sheet q250 precheck--> C
```

Gun V non-first also works: `2,080,848 -> 6,242,544 -> 12,485,088 -> C`. Minimum: three gun-kill deeds/three kills. An early Gun-V claim never receives a later retroactive bonus, so a K1 longshot permanently gives up the Gun-II light for that tree.

### Route F: Spray double- and triple-splash

A spray activation that kills two enemies necessarily satisfies Spray I, II, III, and V before the achievement sweep. The engine claims lower tiers in order, so V sees three lower tiers and receives whole ×3.

With First Blood:

```text
1,024 --K1 Spray common q100--> 1,024
      --First Blood heat5 q2000--> 20,480
      --K2 Splash heat14 q8400--> 1,720,320
      --Spray III q200--> 3,440,640
      --Spray V first q346--> 11,904,614
      --three-lower-tier light bonus, whole x3--> 35,713,842
      --Clean Sheet q250 precheck--> C
```

Minimum: two kills in one activation, one of them the episode's First Blood. Without First Blood the corresponding result is only 637,746 raw before lifecycle folds and does not cap.

A three-kill activation on one pickup can cap without First Blood. The first kill is common, the next two can be splash deeds:

```text
1,024 -> 30,720 -> 2,580,480
      --Spray III q200--> 5,160,960
      --Spray IV q250--> 12,902,400
      --Spray V first q346 precheck 12,902,400 >= 6,206,600--> C
```

The displayed sequence applies when all three kills are present before the next achievement sweep, normally on the same engine tick. If V claims after the second kill, earning Spray IV later does not relight V; a third kill in the still-live activation can nevertheless cap directly if it is another heated Splash deed. Three kills on one pickup across separate activations do not get that guarantee.

### Route G: Grenade double-blast plus a third grenade kill — three-kill loss cap

Grenade V needs three grenade kills. One multi-kill blast supplies two kills and Grenade III; a third grenade kill then opens V with three lower tiers already claimed:

```text
1,024 --K1 Grenade common q100--> 1,024
      --First Blood heat5 q2000--> 20,480
      --K2 Splash heat14 q8400--> 1,720,320
      --Grenade III q200--> 3,440,640
      --K3 Grenade common q100--> 3,440,640
      --Grenade V first q346--> 11,904,614
      --three-lower-tier light bonus, whole x3--> 35,713,842
      --Clean Sheet q250 precheck--> C
```

Minimum: three grenade kills, including a two-kill blast, with First Blood. A second multi-kill blast can claim Grenade IV before V only if both facts are visible to the same first V sweep; otherwise V has already claimed at the third grenade kill and cannot be relit.

### Route H: pact-stacked Bounty-longshot First Blood — one-kill loss cap

This is the absolute shortest realistic composite route for the current recipe. A named active pact ally must also have damaged the victim inside the joint incident, making `stackK=2` and the kill stack ×5. The victim must be L3+, and the kill must be at longshot range. Bounty wins deed precedence, but the same kill satisfies Gun III and Gun V.

At home, the Bounty deed is `q900 * 5 = q4500`:

```text
1,024 --K1 Bounty with pact stack q4500--> 46,080
      --First Blood heat5 q2000--> 921,600
      --Gun III q200--> 1,843,200
      --Gun V first q346--> 6,377,472
      --Gun light count 2, whole x2--> 12,754,944
      --Clean Sheet q250 precheck--> C
```

Enemy ground is even larger (`Bounty q927 * stack5 = q4635`, First Blood `q2120`) and reaches 13,925,724 before Clean Sheet. Without the pact stack, the home route reaches only 6,377,470 after Clean Sheet and does not cap. Minimum: one hostile kill, but it needs First Blood, an Ace victim, longshot geometry, a co-damaging pact ally, first Gun V, and no friendly-fire incident.

This route is why the existing Lawrence/softmaxwell pact is still strategically valuable despite its post-cap risk.

## 2. Achievement claimability for a solo seat

Achievement state belongs to the actual team. In this variant the team is one seat: a pact ally can supply the kill stack and alliance deeds, but does not merge counters into the solo seat's achievement tree.

Tier factors are now:

| Tier | Factor | Notes |
|---|---:|---|
| I | `q100` | score identity |
| II | `q100` | score identity |
| III | `q200` | real ×2 fold |
| IV | `q250` | raised from `q105` |
| V | `q300`, or `q346` if first | raised from `q200` for non-first only |

Only a Tier V claim invokes the lightable-mode ladder. It counts how many of tiers I–IV in the **same tree** the same team has already claimed at that instant, then folds a whole factor after Tier V:

```text
lower tiers already claimed: 0  1  2  3  4
mode-light factor:           x1 x1 x2 x3 x4
```

Claims are processed tree-by-tree and tier I through V. Thus lower tiers that become satisfied in the same evaluation tick count for V. There is no retroactive relight after V has claimed.

| Tree | Solo-reachable tiers | Exact requirements and practical reading |
|---|---|---|
| Gun | I–V, all in principle | I: one gun kill. II: three gun kills. III: kill an L3+ enemy; this is also a Bounty primary deed unless a higher-precedence deed applies. IV: reach L5. V: a kill at least 866 px away with the 1,300 px gun. |
| Spray | I–V | I: one spray kill. II: two spray kills. III: two kills from the same pickup. IV: three kills from the same pickup. V: two or more kills in one cone activation. A V claim normally has at least I–III lit, so ×3 is the normal V bonus. |
| Grenade | I–V | I: one grenade kill. II: two grenade kills. III: one grenade blast killing at least two enemies. IV: two such multi-kill blasts. V: three grenade kills. A multi-blast plus a third grenade kill normally lights I–III for ×3. |
| Backup / Shield | No realistic solo tiers | Assist, escort, rescue, Second Wind, and three-distinct-teammate Squad Volley all require literal teammate mechanics. A cross-team pact is not that teammate. |
| Provider / MedKit | None | The tree is omitted on this port because the `supplyShared`/`supplySaves` leg is not implemented. `supply_run` heals the seat; it does not claim this tree. |
| Carrier | None in flagless BR | Contested steals, carry kills, and capture are unavailable. |
| Defender | None in flagless BR | Carrier kills, denials, and peel/steal sequences are unavailable. |
| Squad | I and IV | I: convert two implemented kit legs—normally one spray kill plus one grenade kill. II needs all three implemented legs, the third being an assist, so a literal solo cannot claim it. III Full Kit is tombstoned. IV Clean Sheet claims at conclusion if the team recorded no team kill. V needs all three legs plus a capture and is impossible here. |

Gun IV is technically reachable but rare. BR doubles the level thresholds to `[18, 30, 48, 66, 96]` XP; damage awards 3 XP per enemy HP, so L5 requires 32 HP of enemy damage in the seat's one life. Merely having three kills does not guarantee it. By contrast, Gun III is often actionable late because an L3 victim needs only 48 XP, or 16 damage.

Clean Sheet is the routine conclusion lever for a solo episode with no team kill. It is evaluated for dead teams as well as the winner and its `q250` precheck caps any product already at 8,589,934 raw. It does not receive a mode-light bonus because it is Tier IV, and the impossible Squad V never fires. End-card labels such as `almost`, `sniper`, and `silent` are distinctions, not additional score factors.

## 3. Placement, the win, and what to do after capping

### Placement can cap; it also pushes near-misses into Clean Sheet

For a product measured just before FINAL 8, the minimum raw values that cap by successive lifecycle folds are:

| First cap no later than | Minimum raw `P` before FINAL 8 | Approximately reported |
|---|---:|---:|
| FINAL 8 itself | 18,673,770 | 18,236 |
| FINAL 4 | 14,364,439 | 14,028 |
| FINAL 2 | 8,977,774 | 8,767 |
| Clean Sheet after surviving FINAL 8 | 7,469,508 | 7,294 |
| Clean Sheet after surviving FINAL 4 | 5,745,776 | 5,611 |
| Clean Sheet after surviving FINAL 2 | 3,591,111 | 3,507 |

The last three rows assume no team kill. They show why placement matters even though its direct multipliers are small: it can lift a 3,507–8,388 displayed combat product onto Clean Sheet's premature threshold.

At the exact lower edge of the full placement-plus-Clean route, every fold is ordinary until Clean Sheet:

```text
before FINAL 8     3,591,111  (3,506)
FINAL 8 q115       4,129,777  (4,032)
FINAL 4 q130       5,368,710  (5,242)
FINAL 2 q160       8,589,936  (8,388)
Clean Sheet q250, precheck 8,589,936 >= 8,589,934 -> C
```

At the exact direct-FINAL-2 edge, `8,977,774 -> 10,324,440 -> 13,421,772`, and FINAL 2 immediately returns `C` because its threshold is 13,421,772.

It does not turn every modest chain into a cap. For example, tag + First Blood + one heated tag starts the lifecycle at 1,387,232 raw:

```text
after combat       1,387,232  (1,354)
FINAL 8 q115       1,595,316  (1,557)
FINAL 4 q130       2,073,910  (2,025)
FINAL 2 q160       3,318,256  (3,240)
Clean Sheet q250   8,295,640  (8,101)
win whole x8      66,365,120  (64,809)
```

That winner is valuable but remains below the ceiling.

### The win cannot be the first cap trigger in the normal 16-team path

FINAL 2 is minted before finalization. If a finalist is still uncapped at that point, its pre-FINAL-2 product was below `floor(C/160) = 13,421,772`; after the ordinary 1.60 multiplication it is below about 21.5 million raw. Any attainable conclusion-time percentage claim either hits its own much lower premature threshold or again leaves less than about 21.5 million raw. A Tier-V mode-light fold can multiply that by at most four, leaving less than about 85.9 million; if Clean Sheet is available it then caps that product, and if Clean Sheet is unavailable the product is still well below the win fold's proper threshold `floor(C/8) = 268,435,456`.

Thus the whole ×8 win can never be the first cap-triggering fold in the ordinary 16-team solo path. A product big enough for its proper precheck would already have been capped by placement or an achievement percentage fold; a still-uncapped product is too small for the ordinary multiplication by eight to reach `C`. Therefore:

- the observed three-kill capped loss is expected, not anomalous;
- winning is not needed to retain the product;
- the win only separates uncapped legs—commonly tens of thousands, and below roughly 671,000 even after the largest possible late ×4 light bonus;
- a capped winner and capped loser both report 2,097,152 before friendly-fire halvings.

### After `GLORY_CAP_HIT`

All positive folds are score-identities after `P == C`; they cannot raise the bank beyond the ceiling. More kills, achievements, placement, and the win have zero marginal Glory.

A hostile or zone death after capping does not reduce the product, and the loss gate is gone, so dying is free **for that seat's Glory arithmetic**. Deliberate death is not generally useful—it gives up match influence and can help rivals—but preserving the win has no score value for a saturated leg.

Friendly fire is different. It is applied outside the product clamp and is irreversible because later positive factors see `P` already at `C`:

```text
cap with 0 FF incidents = 2,097,152
cap with 1 FF incident  = 1,048,576
cap with 2 FF incidents =   524,288
cap with 3 FF incidents =   262,144
```

After capping, stop taking any action that can be charged as a friendly/pact incident. Do not chase a pact ally, spray through one, grenade a shared pocket, or use a friendly down as the way to exit. A hostile or gas death is arithmetically safe; a friendly incident is not.

## 4. Ladder economics

The league round value is the sum of an entrant's top 12 legs, and standing updates as:

```text
standing_new = 0.95 * standing_old + 0.05 * round_top12
```

The EMA half-life is `ln(0.5)/ln(0.95) = 13.51` rounds. One new capped leg contributes 2,097,152 to the round and about **104,858** to the next displayed standing before accounting for the simultaneous 5% decay of the old standing.

Let `r` be expected capped legs per 12 retained legs and let `mu` be the retained non-cap mean. Then:

```text
E[round_top12] ~= r * 2,097,152 + (12-r) * mu
```

The steady-state expected standing equals the expected round input; `k=0.05` changes response time, not the long-run ordering.

| Caps per 12, `r` | Cap-only contribution to expected round/standing |
|---:|---:|
| 0.10 | 209,715 |
| 0.20 | 419,430 |
| 0.25 | 524,288 |
| 0.40 | 838,861 |
| 0.50 | 1,048,576 |
| 1.00 | 2,097,152 |

In rounds 4828–4832, nine of 1,200 field seats capped: a 0.75% seat rate, or **0.09 caps per 12** pooled. One cap in roughly 60–65 entrant seats is about 0.19 per 12; two is about 0.38. Those are counts of one and two, not stable skill estimates. The design document's pre-S8 cap sweep estimated a 0.312% seat rate on the older refolded cohort; the first live 0.75% is compatible with a changed field plus the new achievement multipliers and is still far too small a sample for a contradiction.

The largest other observed leg in the supplied window was 38,179. A cap is about 55 such legs, and even twelve 38,179 legs total only 458,148. In this early distribution, cap count is effectively lexicographic: an entrant with one more cap wins the round-sum comparison regardless of its other retained legs.

The practical ladder targets are therefore:

- **below 0.25 caps per 12:** unlikely to lead once the field adapts;
- **about 0.4 per 12:** clears the strongest first-five-round point estimate, but with no margin;
- **at least 0.5 per 12:** credible leadership target—one cap every two rounds at approximately 12 seats per round;
- **1.0 per 12:** dominant, adding about 2.10 million to the steady round input before tail legs.

The exact winning rate is relative: it is the highest sustainable `r`, with tail score breaking ties. Five live rounds cannot establish that threshold, so 0.5 is an engineering target, not a measured law.

## 5. Implications for `jordan-ctf-candidate:v163`

The live recipe is [v195-solo-jackal-above-loot-pact.env](s2_patches/recipes/v195-solo-jackal-above-loot-pact.env): no opening hold; guarded `supply_run` above `loot`; from tick 760, `supply_run > jackal(700, afterKill, hpFloor=2) > loot > edge_ride(240,80,0.5)`; and a Lawrence/softmaxwell pact. That recipe was field-best at the old GV17 ceiling, 99 caps in 2,174 seats or 0.55 per 12, but that figure is not transferable to GV18. Its first GV18 point is one cap in roughly five rounds, about 0.19 per 12.

Keep the two mechanisms that still directly match the route book:

- `jackal` above `loot` owns the 270-tick follow-up window needed by Routes A–E;
- the reciprocal pact can turn one co-damaged Bounty-longshot First Blood into the one-kill Route H and also supplies Joint Act/pact-down factors.

Do not broaden the pact list without evidence of reciprocal declarations, and count a raw cap that reports halved as a pact failure.

### Ranked one-variable experiments

The expected effects below are screening priors in **capped legs per 12**, not confidence intervals. Run them one at a time against the same roster and rotations.

| Rank | One-variable change | Expected caps/12 effect | Mechanism |
|---:|---|---:|---|
| 1 | Recalled `edge_ride.enterLead: 80 -> 160`; leave opening `420/320/1.0` unchanged | **+0.02 to +0.08** | Enter the next safe rectangle earlier, preserving a 3,507–8,388 displayed combat product long enough for FINAL 8/4/2 to push it onto the Clean Sheet precheck. It also reduces gas deaths without altering target or weapon choice. |
| 2 | Append `bounty` third: `prefer:[weakened, isolated, bounty]` in every `target_law` call | **0.00 to +0.05** | Retains the existing weakened/isolated ordering, but among otherwise tied targets prefers the L3 victim that gives a `q900` Bounty deed, Gun III `q200`, and an extra Gun-V light. With the current pact stack it opens the one-kill cap route. |
| 3 | Add a corrected, weak-target `lane_warden` rung below the existing finish/loot owners | **central +0.02; plausible -0.05 to +0.08** | Creates 866–1,100 px gun finishes and Gun V while allowing the controller's own retreat/flee branches and limiting stale-track ownership. It has the most direct longshot upside and the largest measured downside prior. |

#### 1. Earlier recalled edge entry

Change only `enterLead` in the tick-760 and tick-1500 `edge_ride` calls:

```text
edge_ride { margin:240, enterLead:160, coverBias:0.5 }  # tick 760
edge_ride { margin:240, enterLead:160, coverBias:0.9 }  # tick 1500
```

This is the already-staged v187 axis, now justified more strongly by placement's `115/130/160` folds. It should be judged on capped legs, survival to each milestone, zone-death rate, and the number of products entering FINAL 8 in the 3.5k–18.2k reported band. Do not reuse v198's negative old-cap result against it: v198 also replaced the opening shelter, a different intervention.

#### 2. Add Bounty as a third tie-break, not as a replacement

The rejected v184 test changed `[weakened, isolated]` to `[weakened, bounty]` and fell from 1.30 to 0.96 kills per episode with far fewer wins. Do not repeat that test. The GV18 test is narrower:

```json
{"play":"target_law","params":{"prefer":["weakened","isolated","bounty"]}}
```

It preserves the safe-target discriminator and uses Bounty only as a later preference. The new upside is mechanical, not speculative: Tier III is ×2, it increases Gun V's light count, and a pact-stacked longshot Bounty First Blood caps through Clean Sheet in one kill. Reject promptly if kills per seat or survival materially falls; the old v184 result is a strong downside prior.

#### 3. Reintroduce `lane_warden` only with a repaired guard and lower priority

The prior v161 lane cannot simply be restored. Its external `nearest_enemy_dist >= 866` and `self.hp_frac >= 0.5` guard made the controller's internal retreat and flee paths unreachable; `enemy_count == 1` admitted remembered stale tracks; and its position above useful controllers let those tracks own movement. v161 produced 0.24 old caps per 12 versus v160's 0.48 point estimate, with the difference statistically level but conversion among killful seats lower. The later hunter-lane local screen was 0/64. Those are warnings, not proof against every lane design.

Use one late rung with:

```text
lane_warden {
  margin: 240,
  standoffMin: 866,
  standoffMax: 1100,
  coverRadius: 260,
  hpFloor: 2
}
```

and this guard shape:

```json
["and",
  [">",  ["get","self.hp_frac"], 0],
  ["==", ["get","world.enemy_count"], 1],
  [">=", ["get","world.nearest_enemy_dist"], 500],
  ["<=", ["get","world.nearest_enemy_dist"], 1300],
  [">",  ["get","world.weakest_enemy_hp"], 0],
  ["<=", ["get","world.weakest_enemy_hp"], 2],
  ["get","world.in_zone"],
  [">",  ["get","world.zone_ticks_until_outside"], 120],
  ["not",["get","world.grenade_threat"]],
  ["not",["get","world.spray_threat"]]
]
```

At tick 760 use `supply_run > jackal > loot > lane_warden > edge_ride`; at tick 1500 use `supply_run > jackal > lane_warden > edge_ride`. The 500-px external floor allows the lane controller to retreat through 500–865 instead of disappearing at 866, while `standoffMin=866` preserves the desired firing band. `hpFloor=2` can now execute because the external guard merely requires the seat to be alive. Weak-target gating aims the expensive movement at a finish rather than a healthy standoff.

Do not duplicate `item_dist` and `medkit_dist` in this lane guard: the higher-priority `loot` and `supply_run` guards already arbitrate them. Do not add a separate `zone_dist` condition either: `in_zone`, `zone_ticks_until_outside`, and the controller's `margin` cover that risk. Every extra remembered-world condition creates another stale ownership seam.

The success measurements are longshots per 12, Gun-V claims split by light count, kills within 270 ticks of a prior deed, lane-owned deaths, stale `lane_warden:hold` time, and caps per 12. Promote only if the cap-conversion gain survives without a material kill-rate loss.

### Lower-priority changes

- **Keep `jackal` at 700.** Raising it to 900 scored 0.19 old caps per 12 versus v195's 0.44 in the local screen. Its present after-kill mechanism is still exactly aligned to the heat window.
- **Keep the guarded `loot` rung for now.** Spray and grenade pickups have enormous GV18 upside, but `loot` cannot prefer a specific weapon, and changing it to an indiscriminate contested race mixes pickup rate with exposure. Measure pickup-to-tier conversion before buying that risk.
- **Keep `supply_run` as the low-HP override.** The prior enemy-clearance variant reduced kills and wins. Survival is now useful for placement; abandoning an available medkit at low HP moves in the wrong direction.
- **Do not add standalone `scatter` first.** Earlier scatter-only/longshot substitutions traded away ordinary kill and win rate. Reference agents can cap with scatter, but that does not identify scatter as the cause.
- **Keep the pact, with telemetry.** It is the only current reference play that unlocks the one-kill cap and large ally-stack routes. Its downside is uniquely severe after a cap, so compare raw `GLORY_CAP_HIT` count with final reported-cap count and inspect every discrepancy for an FF halve.

## Decision rule

The metric is now capped legs per 12, not mean score and not the old `>=10k` proxy. For each candidate, also retain the mechanism metric named above. A single extra 2,097,152 leg can dominate several rounds and influence the EMA for many subsequent rounds, so do not promote on round sum. Require the cap-rate interval to exclude a meaningful loss, or extend the sample; if a 95% interval crosses zero, record the result as level.

The immediate experiment order is:

1. recalled `enterLead 80 -> 160`;
2. append third-choice `bounty` without removing `isolated`;
3. the corrected, low-priority weak-target lane rung.

The current v195 recipe remains the control until one of those clears the one-variable gate.
