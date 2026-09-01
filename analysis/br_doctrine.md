# Paintbot 32-seat battle-royale doctrine

This is a source audit of the pinned `br-gen-1339` board and GameVersion 50 (`.engine/src/ctf/sim_types.nim:31-52`), not a claim based on classic-board results. Times below are measured from the first `Playing` tick; the configured 120-tick pre-game wait is not part of the zone clock. The engine runs at 24 ticks/s (`sim/paintbot_br.json:2251`, `.engine/src/ctf/sim_types.nim:499`, `.engine/src/ctf/sim.nim:5029-5036`).

## 1. Zone, final centre, and spawn deal

### Exact zone clock

The scheduler holds the previous scale for `waitTicks`, then interpolates to the phase target over `shrinkTicks`. Its `t + 1` interpolation means the target is reached on the last tick of the half-open interval shown below; the next phase begins on the following tick. After the last interval, the final rectangle is held forever (`.engine/src/ctf/sim.nim:5038-5077`). Width and height are integer floors of `3211*z` and `1713*z`, with a minimum of one pixel (`.engine/src/ctf/sim.nim:4983-4998`); the authored phases and damage rates are in `sim/paintbot_br.json:2208-2244`.

| Phase | Phase start | Hold interval | Shrink interval | Raw scale during phase | Target raw size | DPS |
|---|---:|---:|---:|---:|---:|---:|
| 0 | tick 0 / 0.000 s | `[0,345)` | `[345,558)` | `1.00 -> 0.75` | 2408 x 1284 | 0 |
| 1 | tick 558 / 23.250 s | none | `[558,802)` | `0.75 -> 0.55` | 1766 x 942 | 3 |
| 2 | tick 802 / 33.417 s | none | `[802,1150)` | `0.55 -> 0.35` | 1123 x 599 | 6 |
| 3 | tick 1150 / 47.917 s | none | `[1150,1750)` | `0.35 -> 0.20` | 642 x 342 | 10 |
| 4 | tick 1750 / 72.917 s | none | `[1750,3300)` | `0.20 -> 0.08` | 256 x 137 | 15 |
| 5 | tick 3300 / 137.500 s | none | `[3300,5000)` | `0.08 -> 0.001` | 3 x 1 | 20 |
| Final hold | tick 5000 / 208.333 s | `[5000,...)` | none | `0.001` | 3 x 1 | 20 |

Two boundary details matter:

- Phase 0's shrink starts at tick 345 (14.375 s), although phase 0 itself starts at tick 0. Phase 1's lethal DPS begins exactly at tick 558, not when the rectangle first starts moving.
- The live rectangle is the raw rectangle intersected with the board. Early off-board portions therefore do not create phantom safe ground, and damage, art, `zone`, and `zonenext` all use the same clamped rectangle (`.engine/src/ctf/sim.nim:5000-5027`, `.engine/src/ctf/sim.nim:5079-5098`). The episode cap is tick 10000 (416.667 s), but the 3 x 1 final hold should decide ordinary games much earlier (`sim/paintbot_br.json:2204`).

### Outside-zone survival

Damage is applied after each complete 24 ticks of continuous exposure. Re-entering the current rectangle resets the counter; the hit goes through the shield layer first and an environmental kill has no killer (`.engine/src/ctf/sim_types.nim:926-931`, `.engine/src/ctf/sim.nim:5101-5157`, `.engine/src/ctf/sim.nim:2243-2254`). Therefore a fresh, bare 3-HP cog survives as follows:

| Active phase | DPS | Time from freshly stepping outside to death |
|---|---:|---:|
| 0 | 0 | indefinitely |
| 1 | 3 | 24 ticks = 1.000 s |
| 2 | 6 | 24 ticks = 1.000 s |
| 3 | 10 | 24 ticks = 1.000 s |
| 4 | 15 | 24 ticks = 1.000 s |
| 5/final | 20 | 24 ticks = 1.000 s |

The word “freshly” is important. Even at DPS 0 the engine resets an outside cog's counter every 24 ticks. A cog already outside when phase 1 begins can thus have 1–24 ticks left before the next roll (`.engine/src/ctf/sim.nim:5128-5133`). A fresh 3+3 shield lasts 48 ticks at DPS 3, but only 24 ticks at DPS 6 or above because one application can exhaust the armor and base HP together (`.engine/src/ctf/sim.nim:2235-2254`).

### Centre draw and maximum spawn displacement

There is no authored `zoneCenter` in this config. Once per episode the engine draws a deterministic, uniform sim-RNG centre among positions where the **final** rectangle fits with the 10-pixel arena border; all earlier centres drift linearly from board centre toward that draw as the scale falls from 1.0 to 0.001 (`.engine/src/ctf/sim.nim:1037-1083`, `.engine/src/ctf/arena.nim:272-275`, `.engine/src/ctf/sim.nim:4941-4981`). For this 3 x 1 final rectangle:

- centre `x` can be 11..3199 and centre `y` can be 10..1702;
- the final inclusive rectangle is `[cx-1,cx+1] x [cy,cy]`;
- the furthest authored spawn/final-rectangle pairing is spawn group 3 at `(3020,337)` versus centre `(11,1702)`, whose closest final pixel is `(12,1702)`: `sqrt(3008^2 + 1365^2) = 3303.22 px` straight-line. Obstacles can only increase the walkable route.

That 3303 px is not a rare numerical mistake: the final centre is intentionally allowed almost anywhere. A policy must read `zonenext`; no spawn owns a reliably short rotation.

### Spawn group to team

The map authors one point per group in the order below (`sim/paintbot_br.json:119-185`). With one point per team, both team members wrap onto the same point. The engine hashes the episode seed to an offset and assigns `group = (team ordinal + offset) mod 16`; seat order within a team is `slot div 16` (`.engine/src/ctf/sim_state.nim:533-580`, `.engine/src/ctf/roster.nim:50-62`, `.engine/src/ctf/roster.nim:501-512`). For the config seed 679961 the hash is 185209587, hence offset 3.

| Team colour | Seats | Spawn group | Authored point |
|---|---:|---:|---:|
| red | 0, 16 | 3 | (3020, 337) |
| blue | 1, 17 | 4 | (301, 599) |
| green | 2, 18 | 5 | (1045, 666) |
| yellow | 3, 19 | 6 | (1852, 536) |
| black | 4, 20 | 7 | (2788, 750) |
| silver | 5, 21 | 8 | (481, 1058) |
| ivory | 6, 22 | 9 | (1109, 1125) |
| pink | 7, 23 | 10 | (2032, 944) |
| umber | 8, 24 | 11 | (2885, 968) |
| rust | 9, 25 | 12 | (522, 1613) |
| orange | 10, 26 | 13 | (1341, 1388) |
| plum | 11, 27 | 14 | (1889, 1449) |
| lime | 12, 28 | 15 | (2657, 1583) |
| navy | 13, 29 | 0 | (229, 278) |
| azure | 14, 30 | 1 | (988, 156) |
| peach | 15, 31 | 2 | (1916, 164) |

The explicit slot list pairs `k` with `k+16` (`sim/paintbot_br.json:4-100`), and `spawnGroups: 16` overrides the otherwise misleading `layout: sides` team count (`sim/paintbot_br.json:102-119`, `.engine/src/ctf/sim_types.nim:3746-3770`). Local `simulate --seed` replaces the episode seed after parsing the pinned map, so another seed rotates the colour-to-group deal while leaving terrain and the authored point order unchanged (`sim/simulate.nim:151-190`).

## 2. BR glory economy

### What actually reaches the league score

A seat banks its team's full `teamGlory` only when the episode has concluded and that team won; every losing seat and every aborted/drawn seat banks zero (`.engine/src/ctf/roster.nim:990-1023`). Under the supplied hosted format, if one of an entrant's four duos wins with glory `G`, exactly its two winning seats score, so that entrant's per-episode eight-seat mean is `2G/8 = G/4`; if none wins it is zero. Thus the quantity behind a round mean is

`E[entrant seat score] = P(one of its four duos wins) * E[G | entrant win] / 4`.

The four duos running the same entrant image remain four enemy colours. They must never treat build identity or shared policy as an alliance; only the other cog of the same colour is a teammate.

### Deed prices and BR gates

Positive deed mints apply site ownership first, then heat; penalties are never multiplied. Home ground is 100%, enemy ground 150%, and the nominal 120% neutral branch is unreachable because every point is assigned to its nearest team anchor (`.engine/src/ctf/glory.nim:760-837`, `.engine/src/ctf/glory.nim:2139-2163`, `.engine/src/ctf/sim.nim:54-76`). BR's flagless map can never activate the flag-carry multiplier (`.engine/src/ctf/sim.nim:192-208`). One kill resolves to exactly one kill-class deed in the precedence shown by the engine; First Blood is the only stack (`.engine/src/ctf/glory.nim:2191-2193`, `.engine/src/ctf/glory.nim:2255-2278`).

| Deed | Base glory | Status on this BR map |
|---|---:|---|
| First Blood | 12 | Can mint once and stacks on the first enemy kill. |
| Honorable gun kill | 10 | Can mint. |
| Spray kill | 12 | Can mint when no higher-priority descriptor wins. |
| Grenade kill | 12 | Can mint when no higher-priority descriptor wins. |
| Point-blank kill | 12 | Can mint at <=136 px (`110*1300 div 1050`). |
| Longshot kill | 30 | Can mint at >=866 px (`700*1300 div 1050`). |
| Splash multi-kill | 35 | Can mint for a spray/grenade activation killing 2+. |
| Revenge | 18 | Can mint by killing the cog that killed the dead duo partner; once per surviving cog in BR. |
| Run Down | 16 | Can mint when victim velocity is opening the range. |
| Ace Tag | 40 | Can mint against a level-3+ cog. |
| Team kill | -60 | Can mint; no site/heat multiplier. |
| Flag steal | 40 | Structurally unreachable: no flags exist. |
| Capture | 250 | Hard-disabled by `brMode`, and independently unreachable on a flagless map. |
| Carrier kill | 90 | Unreachable: there is no carrier. |
| Denial | 120 | Unreachable: there is no carrier/capture doorstep. |
| Escort kill | 14 | Unreachable: no teammate can carry a flag. |
| Assist | 14 | Counter still increments, but deed mint is hard-gated by `not brMode`. |
| Rescue | 18 | Counter still increments, but deed mint is hard-gated by `not brMode`. |
| Clutch heal | 0 | Call site may fire; deliberately zero-valued. |
| Shield soak | 4 per armor HP | Can mint; site multiplier applies, heat does not. |
| Wipe | 400 | Hard-disabled in `brMode`; there is no fixed last-team-standing bonus. |
| Level up | 0 | Call site may fire; deliberately zero-valued. |
| Achievement | tier I–V: 9, 11, 14, 18, 23 | Can mint if its tier is attainable; site applies, heat never does. Only the episode's first tier-V claim gets 3x (69 before site). |

Base prices are the engine table (`.engine/src/ctf/glory.nim:603-640`), and Ace begins at level 3 (`.engine/src/ctf/glory.nim:1055-1061`). Live-range point-blank/longshot scaling is `.engine/src/ctf/glory.nim:1175`, `.engine/src/ctf/glory.nim:1215`, and `.engine/src/ctf/glory.nim:1291`, `.engine/src/ctf/glory.nim:2238-2253`; the partner-revenge BR gate is `.engine/src/ctf/sim.nim:1937-1951`. Assist and rescue counters survive but their money is gated at `.engine/src/ctf/sim.nim:2015-2047`. Shields award the soak deed per absorbed point at `.engine/src/ctf/sim.nim:2243-2252`. Captures are gated at `.engine/src/ctf/sim.nim:5396-5407`, while wipe glory returns immediately in BR at `.engine/src/ctf/sim.nim:5239-5272`.

Attainable achievement money is narrower than the table suggests:

- Gun, spray, and grenade tiers can mint from their weapon counters. Gun I/II require one/three gun kills by one cog; its other tiers require an ace, max level, and a longshot. Spray and grenade thresholds are explicit in `.engine/src/ctf/sim.nim:362-378`.
- The teamwork tree can mint I (an assist counter), III (a rescue counter), and IV (Second Wind). II needs an escort and is flag-impossible; V requires three distinct teammate killers, impossible for a two-cog team (`.engine/src/ctf/sim.nim:380-383`, `.engine/src/ctf/sim.nim:428`, `.engine/src/ctf/glory.nim:1413-1416`).
- Squad I/II can mint after two/three converted legs (grenade kill, spray kill, assist). Squad III and the entire med-kit tree are explicitly unattainable; Squad IV Clean Sheet mints at conclusion if the team made no team kill. Squad V also requires a capture and is therefore impossible here (`.engine/src/ctf/sim.nim:257-271`, `.engine/src/ctf/sim.nim:407-441`, `.engine/src/ctf/sim.nim:4518-4527`).
- Carrier and defender trees are flag-impossible. Achievement amounts are `[9,11,14,18,23]`; only tier V can take the first-claim multiplier (`.engine/src/ctf/glory.nim:1483-1528`, `.engine/src/ctf/sim.nim:273-309`).

### Winning glory as a function of kills

Glory is not a function of kill count alone. For a winning duo with `K` credited enemy kills, its exact decomposition is

`G = sum(j=1..K) floor(B_j*S_j/100)*H(E_j) + FB + Soak + Achievements - 60*T`,

where `B_j` is the one resolved kill-deed base, `S_j` is 100 or 150 by nearest anchor, `H(E_j)` is the heat multiplier at the pre-mint ember count, `FB` is 0 or the separately site/heat-priced First Blood, and `T` is team kills. The heat ladder is x1/x2/x4/x8 at 0/2/5/10 embers, loses two embers after 45 quiet ticks, and is updated after each drama mint (`.engine/src/ctf/glory.nim:718-745`, `.engine/src/ctf/sim.nim:209-240`). Consequently,

`E[G | K, win] = sum E[floor(B_j*S_j/100)*H(E_j)] + E[FB+Soak+Achievements-60T]`.

A useful low-heat benchmark assumes all kills are plain gun kills by one cog, no First Blood, no team kill, and the normal 18-point Clean Sheet. It includes gun tier I at one kill and tier II at three:

| K | All kills on own-priced ground | All kills on enemy-priced ground |
|---:|---:|---:|
| 0 | 18 | 18 |
| 1 | 37 | 42 |
| 2 | 47 | 57 |
| 3 | 68 | 83 |
| 5 | 88 | 113 |

First Blood adds 12 home or 18 enemy before considering the extra heat ember. Five rapid plain kills with no First Blood use kill multipliers `[1,1,2,2,2]`, producing 118 home or 158 enemy after the two gun tiers and Clean Sheet. If the first kill is First Blood, that extra deed supplies another ember: the five kill multipliers become `[1,2,2,2,4]`, for 160 home or 221 enemy including First Blood and the same achievements.

This makes roughly 80–120 glory a good, active BR win and 130+ a clearly strong one; 18 is the hiding/no-team-kill floor and 200+ needs a hot streak, rarer kill classes, soak, or more achievements. These are arithmetic planning bands, not hosted-BR percentiles. They should not displace `P(win)`: a 200-glory loss still banks zero.

The classic 618–706 range is not a valid BR target. `dWipe` is 400 and an enemy-ground site makes it 600; Clean Sheet is 18. Thus 618 has the exact signature `600 + 18`, before any other credited act. The source's own replay audit found that disabling one wipe mint moved a winner from 626 to 26—exactly 600 glory (`.engine/src/ctf/sim.nim:5251-5269`). The wipe is priced at the last fallen enemy's position (`.engine/src/ctf/sim.nim:5273-5297`), and BR removes it before that lookup. A classic 706 is therefore plausibly the same 618 floor plus 88 in kills/other tiers; BR starts without the 600-point structural subsidy.

## 3. What kills in BR

### Frame data and survival consequences

The live config has 3 base HP, 1300 px gun range, a 5-tick windup, and a 12-tick release cadence (`sim/paintbot_br.json:2202-2205`, `sim/paintbot_br.json:2253-2257`). Aim jitter is derived from the live range: a fully exposed body is hit 80% at 1300 px and about 99% at 650 px (`.engine/src/ctf/sim_types.nim:521-534`). Vision is only `3/2*gunRange = 1950 px`, through a forward cone plus the 90 px bubble—not unlimited (`.engine/src/ctf/sim.nim:4189-4195`, `.engine/src/ctf/sim.nim:4231-4263`).

The practical lethality table is:

| Threat | Bare 3 HP | Fresh shield (3 armor + 3 base) | Tactical consequence |
|---|---|---|---|
| Gun | 3 hits | 6 hits | At perfect aim, one shooter releases at ticks 5, 17, 29; two focused shooters need two volleys for bare and at least three for shield. |
| Spray cone | One touch kills | First touch strips the armor and leaves 3 base HP | A spray within its effective 187 px body reach is an ambush/finisher, not a poke. |
| Grenade | 2 damage, leaving 1 HP | 2 damage, leaving 4 effective HP | One grenade plus one bullet kills bare; two grenades kill bare. A shield survives two ordinary blasts with 2 effective HP. |
| Zone at DPS >=3 | First 24-tick roll kills bare | Two rolls only at DPS 3; one roll at DPS >=6 | Crossing the current edge is an emergency, not a path cost. |
| Med kit | Restores hurt base HP to full | Restores base HP; shield remains a separate layer | At 1 HP, a safe in-zone kit can turn any grazing hit from lethal to survivable. |

Gun hitscan, body blocking, wall blocking, partial exposure, and simultaneous same-tick resolution are specified at `.engine/docs/RULES.md:299-342`; exact windup/cooldown semantics are `.engine/docs/RULES.md:344-378`. Spray lasts five ticks, resets for 20, deals 3, and reaches 170 px centerline plus a 17 px body radius (`.engine/docs/RULES.md:415-460`, `.engine/src/ctf/sim_types.nim:825-855`). Shields add 3 armor but impose 3x fire cooldown while intact (`.engine/docs/RULES.md:613-648`, `.engine/src/ctf/sim_types.nim:859-865`). Med kits heal to full at `.engine/docs/RULES.md:601-611`.

This board has no trenches (`sim/paintbot_br.json:115`), so player grenades use the ordinary 2-damage result. Full charge is 24 ticks, maximum range is `3211 div 5 = 642 px`, flight after release is a fixed two windups = 10 ticks, and a body is caught up to about 58 px from the landing centre (`.engine/src/ctf/sim_types.nim:764-786`, `.engine/src/ctf/sim_types.nim:1289-1295`, `.engine/docs/RULES.md:380-413`).

### Rules of thumb

**Shield.** A fresh shield doubles effective HP but cuts gun throughput to one third while intact. In a sustained isolated gun duel that is not automatically favorable; it pays when the carrier is likely to absorb a short focus burst while the partner supplies full-rate damage, when crossing an exposed rotation, or when carrying a grenade/spray (grenades remain usable). Its largest discrete payoff is surviving a 3-damage spray. Skip a long shield detour for the duo's primary gun unless the route is already useful; favor it on the scout/bait/tool carrier. The three soaked points also mint 12 home or 18 enemy glory, but that is secondary to survival.

**Engagement gate.** Do not voluntarily open a clean 2v2 at 1300 px. Engage when the duo has at least one of: local 2v1, a pre-laid first shot, hard cover and a retreat cell, a wounded/unshielded focus target, a spray/grenade conversion, or an enemy forced across the ring. Otherwise preserve both lives and rotate. At half range the gun is nearly deterministic; at max range a missed first volley is common.

**Cover and first shot.** Cover can hide part of the silhouette and a target that breaks LOS during the five-tick windup survives; conversely, stepping behind the wall before one's own release wastes the shot (`.engine/docs/RULES.md:306-329`, `.engine/docs/RULES.md:366-375`). Pre-lay aim from cover, expose only for the release, and duck during cooldown. A one-tick first-shot lead matters because a lethal earlier release cancels a later windup, while same-tick lethal releases trade simultaneously. Preserve lateral room so the partner is not the first body in the bullet corridor; friendly fire is live.

**Grenades.** Obstacles do not stop the lob, and this map has no trench protection. Treat a visible carrier or throw ring inside 642 px as a forced-spacing event. Two cog centres more than 116 px apart cannot both be within the same 58 px body-touch radius; use >116 px separation around grenade threats and do not share a choke. The release itself is silent and the reaction window is only ten ticks (`.engine/docs/RULES.md:387-410`). A grenade hit leaves a bare cog at one HP, so immediately focus the tagged target; conversely, abandon a static firing plan when a landing marker covers it.

**Duo exchange math.** At 1300 px, two independent 80%-accurate shots deal 1.6 expected damage per focused volley. Across two volleys, `P(at least 3 hits in 4 shots) = 81.92%`; the expected number of two-shot volleys to accumulate three hits is 2.199. At 650 px (99%), those figures are 99.94% and 2.001. A split-fire duo cannot kill either fresh target by its second volley even at perfect accuracy; a focus-fire duo usually removes one at the tick-17 release and creates a 2v1. If both duos focus and release together, simultaneous resolution makes the common outcome a one-for-one trade. The winning edge is therefore not merely “focus”: it is focus **plus** an earlier release, cover, shield/tool asymmetry, or an angle that prevents both enemies replying.

## 4. Prioritised duo behaviour plan

The order below is by expected effect on `P(win)`, not by implementation convenience.

### 1. Make the policy BR-literate before tuning combat

- **Trigger:** init marker says `game teams 16 map 3211x1713`, `zone` exists, and no `endzone` marker exists.
- **Action:** finish and connect the new 16-colour/zone plumbing: set BR mode during init, identify self as `slot mod 16` and the sole partner as the other same-colour seat, and treat every other colour—including other duos running this entrant—as hostile. Feed parsed current/next rectangles into decisions; disable flag, capture, classic lane-role, and respawn branches; preserve the dynamic HP/shield parser.
- **Wire signal:** the game marker states team count/map size (`.engine/src/ctf/global.nim:3990-4030`); flagless suppresses endzone markers (`.engine/src/ctf/global.nim:4033-4043`); identity labels state colour and loadout (`.engine/src/ctf/global.nim:6806-6849`); HP is `hp <base>/<max>[ shield <s>]` (`.engine/src/ctf/labels.nim:399-416`).
- **Local verification:** across paired seed batches, require all 16 `teamStats` rows and inspect per-seat `shotsFired/kills/deaths/alive`. There must be no systematic zero-action/death-at-spawn cluster among black through peach. Use per-team `livesLeft` and `score` to ensure each same-colour pair behaves as one team, not as two solo seats.

### 2. Pre-rotate on `zonenext`; let current-zone escape preempt everything

- **Trigger:** self is outside/within a safety margin of `zone`, or estimated path time to the nearest point safely inside `zonenext` exceeds time remaining to that boundary. Use at least one second (66 px at maximum 2.75 px/tick) of margin when geometry permits (`.engine/src/ctf/sim_types.nim:487-499`).
- **Action:** if outside current `zone`, cancel aim, loot, and chase and take the shortest walkable route in. Otherwise rotate both cogs early toward different covered cells inside `zonenext`, keeping their paths mutually supporting. Never wait for phase-1 damage: a partially accumulated outside counter can kill in one tick.
- **Wire signal:** `zone x0,y0 x1,y1` is current and `zonenext ...` is the phase target, both inclusive and re-emitted as they change (`.engine/src/ctf/labels.nim:307-328`, `.engine/src/ctf/global.nim:7131-7157`).
- **Local verification:** primary endpoints are entrant `P(win)`, lower per-seat `deaths`, higher `alive`, and more winning-team `livesLeft=2`. As a zone-death proxy, track deaths in excess of credited kills across the episode; also compare `aliveTicks`. Do not accept a change that merely lowers `shotsFired` while leaving wins flat.

### 3. Keep a real two-cog formation and focus one target

- **Trigger:** partner is visible/recently tracked or either cog acquires an enemy within 1300 px.
- **Action:** travel within mutual support range, but keep >116 px separation when a grenade is present and avoid lining up on the same enemy ray. On contact, both pick one target: exposed spray/grenade carrier first, then lowest effective HP, then nearest unshielded. One cog fixes from cover; the other shifts enough to make one wall unable to hide the victim from both. If the partner dies, immediately downgrade to ambush/placement play rather than continuing a two-cog plan.
- **Wire signal:** same-colour identity/player labels locate the partner; identity loadout and HP/shield tails identify tool carriers and effective HP; fresh actor tracks provide the common target (`.engine/src/ctf/global.nim:6815-6849`, `.engine/src/ctf/labels.nim:399-416`).
- **Local verification:** compare team kills, deaths, end `livesLeft`, and the fraction of wins ending with both seats `alive`. A successful focus change raises kills per `shotsFired` and reduces episodes where both seats die with zero team kills.

### 4. Gate gunfights on first-shot/cover advantage

- **Trigger:** visible enemy within live range and a clear release-time corridor. Initiate only with 2v1, cover, first-shot, wounded-target, ring, or tool advantage; otherwise shadow/rotate.
- **Action:** pre-lay aim while hidden, step out for release, then duck for the 12-tick cooldown. At long range prefer closing under cover to gambling at 80%. Abort if the partner crosses the corridor or two enemies can answer from independent angles.
- **Wire signal:** actor position/HP, own authoritative aim, wall mask, shot/impact labels, and current ring edge. Aim cone vision reaches 1950 px, so “seen” does not mean “shootable” (`.engine/src/ctf/sim.nim:4189-4195`).
- **Local verification:** jointly examine `shotsFired`, kills, deaths, and wins. The desired signature is fewer low-value shots, higher kills per shot, and lower deaths—not simply less firing. Per-seat `shotsHit` is also emitted for diagnosis even though the league fields of interest remain the requested four (`sim/simulate.nim:285-308`).

### 5. Convert nearby loot without sacrificing the rotation

- **Trigger:** an item is visible and its route detour still reaches `zonenext` with the safety margin. Med: base HP <3. Shield: expected exposure/ambush or designated scout/tool carrier. Spray: a covered route can reach <187 px. Grenade: a cluster/choke/forced edge is within 642 px.
- **Action:** med at 1 HP is the highest loot priority; at 2 HP take it only on a cheap safe detour. Put shield on the likely focus target, not automatically the best gunner. Use spray from corners and grenade to dislodge cover or tag both cogs; keep the partner out of both effects. Memorize authored neutral pickup locations rather than fabricating endzone/corner spawns: this board has 33 med kits, 13 shields, 20 grenade spawns, and 37 spray spawns (`sim/paintbot_br.json:186-607`).
- **Wire signal:** fog-gated `med kit`, `shield`, `grenade`, and `spray can`; identity loadout tails; HP/shield tail; `zone`/`zonenext`.
- **Local verification:** one loot rule per experiment. Check entrant wins, seat kills/deaths/alive, team `livesLeft`, and glory as a diagnostic. A shield rule should reduce carrier deaths; spray/grenade rules should raise kills without raising duo deaths or depressing wins.

### 6. Turn the shrinking endgame into a controlled hunt

- **Trigger:** safe inside current zone and either live zone area <=18% of board area or alive-team count <=4. A team is alive while its scoreboard deaths are <2.
- **Action:** if leading with two cogs, hold two covered, non-clustered angles on the next rectangle rather than charging its centre. If trailing on living cogs/kills/damage, close the freshest track and force an engagement before timeout. Hunt as a pincer, not a same-corridor train. Ring safety remains higher priority.
- **Wire signal:** `team score <COLOR> <kills>/<deaths>` exists for every active team on the player stream (`.engine/src/ctf/global.nim:4519-4567`), plus current zone area and enemy tracks. At timeout the executable ranks living cogs, latest last death, kills, damage, then lowest slot; it never draws (`.engine/src/ctf/sim.nim:4412-4484`).
- **Local verification:** compare `finished`, episode ticks, winner, each team `score`, and `livesLeft`; use seat kills/deaths/alive to distinguish an effective hunt from mutual suicide. The local `score` is engine reward (winner +15 under 16-team classic scoring, placement-shaped losses), not league glory (`.engine/src/ctf/sim_types.nim:623-628`, `.engine/src/ctf/sim.nim:4555-4599`).

### 7. Use communication only for the true partner

- **Trigger:** partner is inside shout range and a compact enemy/rotation message changes its next action.
- **Action:** send only target cell, ring urgency, or “hold/flank”; never infer cooperation from identical policy behavior across another colour. Keep messages sparse because nearby enemies hear them through walls and fog (`.engine/src/ctf/sim.nim:3770-3774`, `.engine/src/ctf/sim.nim:3821-3832`).
- **Wire signal:** exact same-colour identity is the authentication boundary; team colour, not policy build, defines friendly fire and victory. Shout range is `MapWidth div 5 = 642 px` on this map (`.engine/src/ctf/sim_types.nim:1289-1295`).
- **Local verification:** compare paired runs with shouts off/on. Require higher wins or duo kills with no rise in deaths and no collapse in `shotsFired`; reject apparent gains isolated to one colour/spawn group.

For all verification, run the same seed list and rotate build letters through the 32-seat assignment. `abcdabcdabcdabcdabcdabcdabcdabcd` gives each of four builds four complete duos because slots `k` and `k+16` receive the same letter. `sim/simulate.nim` rejects an assignment whose length differs from the 32 configured slots (`sim/simulate.nim:218-237`) and emits per-seat `shotsFired/kills/deaths/alive` plus per-team `livesLeft/score/glory/placement` (`sim/simulate.nim:285-365`). The primary hosted proxy is `I(build owns winner) * winning team glory / 4`; `score` is an outcome/placement check, not the banked-glory metric.

## 5. One-variable hypotheses for an auto-research loop

Use paired seeds, identical opponent builds, the same four-build seat pattern, and rotate letter-to-policy assignment. Change exactly one listed variable. Rank first by entrant win rate, then by estimated entrant seat score `I(win)*glory/4`; use kills, deaths, alive, shots fired, team lives, and local score as diagnostics rather than substitute objectives.

| Single variable | Values to sweep | Falsifiable prediction | Guardrail/readout |
|---|---|---|---|
| Pre-rotation lead | 24, 48, 72, 96 ticks | 48–72 raises wins by avoiding late lethal crossings without surrendering too much loot/contact | deaths, aliveTicks, shotsFired |
| Inside-zone margin | 48, 66, 90, 120 px | >=66 cuts edge deaths; 120 may over-concentrate the duo | deaths, alive, kills |
| Formation target distance | 80, 120, 160, 220 px | 120–160 best balances mutual fire and grenade safety | team kills/deaths, both-alive wins |
| Grenade separation floor | 60, 90, 117, 150 px | 117+ reduces double damage/death when grenade carriers are visible | duo deaths, livesLeft, wins |
| Voluntary gun engage range | 450, 650, 900, 1300 px | 650–900 beats 1300 by trading fewer 80%-accuracy volleys | shotsFired, kills/shot, deaths |
| Required engage advantage | any 2v2, cover-or-first-shot, 2v1/tool-only | cover-or-first-shot improves wins; 2v1-only may become too passive | wins, kills, timeout rate |
| Focus selector | nearest, lowest effective HP, tool carrier then lowest HP | tool/HP priority raises probability of a removal by volley two | team kills, deaths, shotsFired |
| Shield detour cap | 0, 80, 160, 260 px | modest detour helps scout/tool carrier; long detour loses rotations | carrier alive, team livesLeft, wins |
| Shield role | either cog, scout/tool only, primary gun only | scout/tool-only beats primary-gun due the 3x cooldown tax | shotsFired split, kills, deaths |
| Med detour at 2 HP | 0, 60, 120, 180 px | small safe detour helps; 180 loses tempo/zone safety | deaths, alive, wins |
| Med detour at 1 HP | 60, 120, 180, 260 px | a larger budget remains positive because any bullet is otherwise lethal | deaths, alive, shotsFired |
| Spray detour cap | 0, 50, 100, 160 px | cheap spray pickups improve close conversion, long detours do not | kills, deaths, glory |
| Grenade detour cap | 0, 60, 120, 200 px | moderate detour improves forced-edge fights | kills, duo deaths, glory |
| Track capacity | 5, 8, 16, 24, 31 | >5 improves endgame acquisition on a 30-enemy board until stale tracks add noise | endgame ticks, kills, wins |
| Track freshness for a hunt | 24, 48, 90, 150 ticks | moderate freshness avoids idle endgames without chasing ghosts | ticks, deaths, winner score |
| Endgame alive-team threshold | 2, 3, 4, 6 | 4 is a plausible balance; 6 over-hunts | wins, kills, mutual deaths |
| Endgame zone-area trigger | 0.08, 0.12, 0.18, 0.25 | 0.18 starts pressure before the final 8% shrink without needless midgame fights | ticks, deaths, wins |
| Endgame posture when both partners live | centre stack, 80 px split, 120 px split, opposite cover | split cover raises wins and reduces grenade double deaths | both-alive wins, livesLeft |
| Partner shouts | off, target-only, target+ring | compact partner-only messages improve focus/rotation; verbose messages leak too much | wins, team kills/deaths |

An auto-loop should reject unfinished runs, aggregate at episode/team level (the two seats share a result), and report confidence intervals over paired seed differences. Because the leaderboard takes the maximum round rather than a grand mean (league rule supplied in the brief), retain per-round distributions as well as pooled results; do not select a variant solely on one lucky max.

## 6. Current-policy assumptions contradicted by this map/engine

| Current assumption | Contradicting fact | Consequence |
|---|---|---|
| “8v8, classic two-flag” with two/four-team adaptation (`bot/baseline.nim:1-18`) | The config is 32 seats, 16 teams, flagless BR (`sim/paintbot_br.json:3-119`); BR death is permanent (`.engine/src/ctf/sim.nim:2150-2164`). | Flag races, eight-seat roles, respawn defense, and capture urgency are dead strategy. |
| Vision cone has unlimited range and lane watchers see map-wide (`bot/baseline.nim:20-24`, `bot/baseline.nim:51-56`) | Vision is capped at 1950 px and wall/cone filtered (`.engine/src/ctf/sim.nim:4189-4263`). | On a 3211 px map, overwatch is not radar; unexplored enemies and loot remain fogged. |
| `FireRange = MapW + 15` (`bot/baseline/tuning.nim:582-586`, `bot/baseline/navgrid.nim:30-38`) | That becomes 3226 px, but live gun range is 1300 (`sim/paintbot_br.json:2202`); paint beyond live range hits nothing (`.engine/docs/RULES.md:310-323`). | Engagement, open-line scoring, and threat geometry admit impossible shots far beyond both gun range and even the 1950 px vision cap. |
| `LatePushTick = 3400` because the game hard-stops at 5000 (`bot/baseline/tuning.nim:11-15`) | `maxTicks` is 10000; the **zone** begins its final lethal shrink at 3300 and reaches 3 x 1 at 5000 (`sim/paintbot_br.json:2204`, `sim/paintbot_br.json:2239-2244`). | Tick 3400 is already 100 ticks into the DPS-20 final shrink, not a safe generic late push. Trigger on zone/alive teams instead. |
| Fixed horizontal lanes at y=40, 856, 1673 (`bot/baseline/tuning.nim:526`, `bot/baseline/tuning.nim:573-582`) | The map is asymmetric and the zone centre can finish almost anywhere (`sim/paintbot_br.json:104-120`, `.engine/src/ctf/sim.nim:1037-1083`). | Top/mid/bottom paths have no stable relationship to spawn, safety, loot, or endgame. Route to the live next rectangle through actual cover. |
| `NadeMaxRange = 240` and four corner spawns around inset 50 (`bot/baseline/tuning.nim:354-386`, `bot/baseline/tuning.nim:409-415`) | Live max is `MapWidth div 5 = 642`, and the map authors 20 arbitrary grenade spawns (`.engine/src/ctf/sim_types.nim:1289-1295`, `sim/paintbot_br.json:526-607`). | Throw charging under-ranges targets by ~402 px; fabricated corner farming ignores the real neutral supply. |
| Two centre med kits, endzone shields/sprays, four grenades (`bot/baseline/world.nim:226-234`, `bot/baseline/tuning.nim:404-415`) | Authored lists contain 33 med kits, 13 shields, 37 sprays, and 20 grenades (`sim/paintbot_br.json:186-607`); flagless maps emit no endzone geometry (`.engine/src/ctf/global.nim:4033-4043`). | Endzone-relative loot heuristics and fixed spawn memories target nonexistent objects while discarding abundant real loot. |
| The new dynamic HP parser reads only the base numerator and discards the published `shield <s>` amount (`bot/baseline/perception.nim:633-672`) | Engine labels true base/max HP plus the shield layer's exact remaining HP (`.engine/src/ctf/labels.nim:399-416`). | Identity can say that a shield exists, but focus selection cannot distinguish one remaining armor point from three; use the tail to rank effective HP exactly. |
| Enemy respawn exposure samples and respawn-ground logic (`bot/baseline/tuning.nim:495-503`, `bot/baseline/posts.nim:208-231`) | `brMode` forces lives to zero at first death and never starts a respawn timer (`.engine/src/ctf/sim.nim:2150-2164`). | Path cost is spent avoiding imaginary future enemies; a corpse should permanently remove that seat from the threat set. |
| `TrackCap = 5`, calibrated around 8/24 opponents (`bot/baseline/tuning.nim:45-53`) | A duo begins against 30 enemy cogs, and timeout ranking explicitly values living cogs, kills, and damage (`.engine/src/ctf/sim.nim:4412-4467`). | The policy discards most strategic memory and can enter the final zone unaware of surviving teams. |
| `HoldLineKills = 4` gates a classic attack wave (`bot/baseline/tuning.nim:367-378`) | Every enemy has one permanent life, the winning condition is last team standing, and captures are disabled (`.engine/src/ctf/sim.nim:5383-5407`, `.engine/src/ctf/sim.nim:5484-5521`). | “Four deaths before committing” has no stable meaning across 15 rival duos; use local advantage, ring phase, and alive-team count. |
| Header assumes flags/endzones remain the strategic frame (`bot/baseline.nim:41-61`, `bot/baseline.nim:107-113`) | Flagless reset arms no flags, and the capture branch is doubly suppressed (`.engine/src/ctf/sim_state.nim:800-826`, `.engine/src/ctf/sim.nim:5396-5407`). | No target, home edge, defender, carrier, escort, thief, or capture race survives. The only true objective state is duo lives, combat position, loot, and zone. |
| Classic timeout intuition is “draw equals loss” (`bot/baseline/tuning.nim:11-15`) | BR timeout is a strict total order: living cogs, latest last death, kills, damage, then slot, with no draw (`.engine/src/ctf/sim.nim:4412-4484`, `.engine/src/ctf/sim.nim:5523-5536`). | Endgame aggression should be conditional: a two-cog leader preserves position; a trailing solo must force damage/kills before the clock. |

One documentation trap should not be copied into the bot: `RULES.md` still says the BR timeout tiebreak is living players then damage and may draw (`.engine/docs/RULES.md:786-791`), but the GameVersion-50 executable has the newer five-key strict ranking above. For policy behavior, executable `sim.nim` is authoritative.
