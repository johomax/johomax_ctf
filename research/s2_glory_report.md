# Battle-royale Glory report

Scope: `battle-royale-s2` is 16 seats on eight two-seat teams, `brMode=true`, one life, explicit `gunRange=1300` (`coworld_manifest_paintbot.json:1075-1078,1195-1218`). Its rotating maps have eight spawn groups and are flagless (`src/ctf/br_map_pool.nim:75-83`; `data/br_s2_map_pool.json:905-906`). The explicit 1300 range overrides the map’s default because map range is adopted only when the config omits `gunRange` (`src/ctf/sim_config.nim:1221-1228`).

## 1. What each seat reports

There is one Glory pool per team: `teamGlory[Team]`; no per-player Glory pool exists (`src/ctf/sim_types.nim:3612-3624`). Every deed and score-bearing curriculum achievement credits that pool (`src/ctf/sim.nim:163-212,273-289`).

At episode end:

```text
scores[seat] =
  teamGlory[seat.team]  if GameOver and that seat's team won
  0                     otherwise
```

That is the literal reporting gate (`src/ctf/roster.nim:1000-1022`). Consequently:

- Both duo seats report the identical full team total; it is copied, never divided or summed per player.
- Losing teams may have accumulated substantial `teamGlory`, but reporting discards it and emits zero.
- A draw or incomplete episode emits zero for everybody.
- The older RL `player.reward`—win/loss and BR placement reward—is a separate websocket channel and is not `results.scores` (`src/ctf/roster.nim:898-915`).

## 2. BR deeds and exact pricing

For positive deeds, the mint order is:

```text
floor(base × sitePct / 100) × heatMultiplier
```

then the carrier multiplier, which is impossible on these flagless maps. Site is 100% where the nearest team anchor is yours, otherwise 150%; there is no reachable neutral site (`src/ctf/sim.nim:54-76`; `src/ctf/glory.nim:767-839,2147-2163`). Heat is team-shared: multipliers `1,2,4,8` at `0,2,5,10` embers; a drama deed adds one ember after paying, and two embers decay every 45 quiet ticks (1.875 s) (`src/ctf/glory.nim:718-745`; `src/ctf/sim.nim:83-93,238-240`).

Each kill takes exactly the first matching kill-class deed below; First Blood alone stacks separately (`src/ctf/glory.nim:2191-2193,2255-2278`).

| Mint, base Glory | Exact BR trigger |
|---|---|
| `dTeamKill`, **−60** | Victim is a teammate. Highest priority; fixed −60 with no site/heat multiplier. |
| `dAceTag`, **40** | Enemy victim is level ≥3 at death. BR levels use XP thresholds `[18,30,48,66,96]`, so Ace begins at 48 current-life XP (`src/ctf/glory.nim:852-857,909-918,1055-1061,2085-2101`). |
| `dSplashMultiKill`, **35** | Second and every later enemy kill from one grenade explosion or spray activation, unless shadowed by Team Kill/Ace. A triple can therefore mint Splash on kills 2 and 3. |
| `dLongshotKill`, **30** | Stored-position distance `int(sqrt(dx²+dy²)) >= floor(700×1300/1050) = 866 px`. |
| `dPointBlankKill`, **12** | Same distance `<= floor(110×1300/1050) = 136 px`. |
| `dRevengeKill`, **18** | In BR: kill the cog that killed your now-dead duo partner. No time limit; at most once per surviving cog, and only latched if this deed wins precedence. The ordinary “kill your own killer within 240 ticks/10 s” form is structurally unreachable after permanent BR death (`src/ctf/sim.nim:1945-1960,1972-1995`). |
| `dRunDown`, **16** | `(victim.x−killer.x)×victim.velX + (victim.y−killer.y)×victim.velY > 0`: any positive velocity component directly away from the killer; no minimum speed or time window (`src/ctf/sim.nim:1925-1927,1976`). |
| `dSprayKill`, **12** | Spray kill not captured by any higher-priority descriptor. |
| `dGrenadeKill`, **12** | Grenade kill not captured by any higher-priority descriptor. |
| `dHonorableKill`, **10** | Final fallback: an enemy kill that is not Ace, multi, longshot, point-blank, revenge, rundown, spray, or grenade—in practice a plain gun kill. |
| `dFirstBlood`, **12** | Episode’s first non-friendly, player-attributed kill. It stacks after that kill’s class deed and is globally one-shot (`src/ctf/sim.nim:2061-2064`). Environmental deaths do not qualify. |
| `dShieldSoak`, **4 per HP** | Each HP absorbed by the victim’s shield: 4/HP on own ground or 6/HP on another team’s ground; no heat (`src/ctf/sim.nim:2198-2261`). |
| `dClutchHeal`, **0** | An alive player at ≤1 HP takes a med kit. It deliberately fires but pays zero (`src/ctf/sim.nim:3519-3551`). |
| `dLevelUp`, **0** | Damage XP crosses one or more BR level thresholds. It deliberately fires but pays zero (`src/ctf/sim.nim:539-572`). |
| `dAchievement`, **tier-priced** | A new Glory-curriculum tier is satisfied; see §4. |

The spray multi window is one five-tick activation (0.208 s), with each victim hittable once (`src/ctf/sim_types.nim:882-888`; `src/ctf/sim.nim:2352-2367,2372-2441,2521-2550`). Grenade multi means the same single explosion/simulation step; its second and later enemy kills receive `multi=true` (`src/ctf/sim.nim:3368-3379,3409-3444`). There is no generic “N kills within X seconds” multi-kill deed.

Disabled or unreachable in the actual S2 BR variant:

| Deed | Base | Why absent |
|---|---:|---|
| `dAssist`, `dRescue` | 14, 18 | Their counters still update, but their deed mints are explicitly `not brMode` (`src/ctf/sim.nim:2024-2056`). |
| `dWipe` | 400 | `awardWipe` immediately returns in BR (`src/ctf/sim.nim:5248-5281`). |
| `dCapture` | 250 | The capture/scoring branch is explicitly disabled in BR (`src/ctf/sim.nim:5405-5416,5450-5454`). |
| `dFlagSteal`, `dCarrierKill`, `dDenial`, `dEscortKill` | 40, 90, 120, 14 | S2 maps are flagless; pickup returns immediately, so nobody can carry a heart (`src/ctf/sim.nim:3865-3871`). |

Base prices come directly from `src/ctf/glory.nim:603-640`.

## 3. End-of-episode and survival scoring

There is no Glory bonus for winning, placement, number of survivors, survival time, or being last team alive.

BR placement ranks—living cogs, latest last death, kills, damage, then seat index—affect only the separate legacy `reward` (`src/ctf/sim.nim:4421-4476,4575-4608`). Winning merely permits the already-earned team Glory to be reported.

There is also no per-tick survival Glory. The only ledger writes are deed minting and curriculum-claim minting (`src/ctf/sim.nim:209-212,284-289`). Per-tick processing only cools heat and detects newly completed one-shot tiers (`src/ctf/sim.nim:6707-6724`).

One qualification: `finishGame` performs a final curriculum sweep before reward bookkeeping. This can mint a threshold reached by the final kill and the conclusion-only **Clean Sheet** tier; it is not a win/placement/survivor bonus and is evaluated for every team, including losers (`src/ctf/sim.nim:4527-4536`; `src/ctf/sim.nim:475-515`).

## 4. The two different “achievement” systems

### Score-bearing Glory curriculum

Tiers I–V pay exactly **9, 11, 14, 18, 23** Glory. Claims are priced at the team’s own anchor, hence 100%; they never use heat. Only tier V can receive the first-team multiplier, becoming **69** (`src/ctf/glory.nim:1483-1527`; `src/ctf/sim.nim:273-300`).

| Tree | I / 9 | II / 11 | III / 14 | IV / 18 | V / 23 or 69 |
|---|---|---|---|---|---|
| Gun | First Tag: ≥1 gun kill | Marksman: one cog ≥3 | Bounty: one cog killed an Ace | Sharpshooter: one cog L5 | Longshot: one longshot |
| Spray | First Coat: ≥1 | Full Coverage: ≥2 | Repainted: ≥2 on one can | Muralist: ≥3 on one can | Double Splash: ≥2 in one activation |
| Grenade | Delivery: ≥1 | Splatterbomb: ≥2 | Blast Radius: one 2+ blast | Double Blast: two such blasts | Bombardier: ≥3 |
| Backup | Cover Fire: teammate’s last nonlethal hit, then partner finishes within 120 ticks | Escort Duty: impossible—no heart | The Save: kill within 120 ticks after that enemy left a teammate at ≤1 HP | Second Wind: rescued cog kills within 120 ticks | Squad Volley: 3 distinct team killers within 90 ticks—impossible for a duo |
| Provider | First/Clutch Delivery | Regular Route | Emergency Route | Supply Chain | Entire tree omitted on this port |
| Heart | Hands On | Fighting Carry | Double Steal | Hard Carry | Delivered—all impossible, flagless |
| Peel | Peel | Doorstep | Double Peel | Turnaround | Lockdown—all impossible, flagless |
| Squad | Kitted: two of grenade-kill, spray-kill, assist | Full Loadout: all three | Full Kit: tombstoned | Clean Sheet: zero team kills at conclusion | Victory Lap: impossible—needs capture |

Names are defined at `src/ctf/glory.nim:1611-1887`; executable predicates are `src/ctf/sim.nim:326-428`. Notably, Cover Fire/The Save can score even though the separate `dAssist`/`dRescue` deeds are disabled in BR.

### Hosted lowercase badges

These are tierless and worth **0 Glory**. They are analysis-only, win-gated, copied to both winning teammates, and never touch `teamGlory` (`src/ctf/sim_types.nim:687-747`; `src/ctf/sim.nim:4628-4637,4705-4740`).

| Badge | Tier / Glory | Exact winning-team condition |
|---|---:|---|
| `pacifist` | — / 0 | Zero attacks; deliberately impossible in BR because BR additionally requires engagement. |
| `spotless` | — / 0 | Zero damage taken, including shield-absorbed/environmental damage, plus BR engagement. |
| `almost` | — / 0 | Remaining team life budget `<2`; in one-life BR, effectively exactly one living HP total. |
| `grenadier` | — / 0 | Damage dealt >0 and grenade damage ≥80%. |
| `rambo` | — / 0 | One cog made ≥9 kills in its life. |
| `medic` | — / 0 | One cog took ≥4 med kits in its life. |
| `sniper` | — / 0 | Damage dealt >0 and every damage point was from the gun. |
| `banksy` | — / 0 | Damage dealt >0 and spray supplied ≥90%. |
| `pack` | — / 0 | Every cog spent ≥90% of alive ticks near ≥2 living teammates; impossible for a two-cog duo. |
| `pit-master` | — / 0 | Damage dealt >0 and ≥90% was dealt while standing in a pit. |
| `heist` | — / 0 | Capture-ended win with zero kills; impossible in BR. |
| `silent` | — / 0 | Neither cog had an applied shout. |
| `assassin` | — / 0 | One cog made ≥10 enemy gun/grenade kill shots that were its first damage to that victim’s life. |
| `lucky` | — / 0 | One cog survived ≥5 grenade blasts. |

Thus `spotless` is unrelated to score-bearing **Clean Sheet**: the former means no damage taken and pays zero; the latter means no friendly kills and pays 18.

## 5. Why six kills can score 413 while eight score 307

Kill count cannot uniquely reconstruct either ledger. Required missing facts are deed classification, kill coordinates, ordering/gaps, First Blood, shield soak, friendly fire, and curriculum claims.

For an uninterrupted six-kill streak that also takes First Blood, the event multipliers are:

```text
kill1 ×1, First Blood ×1, kills2–4 ×2, kills5–6 ×4
```

A late enemy-ground Ace at ×4 pays `40×150%×4 = 240`; a Splash pays `floor(35×150%)×4 = 208`; a Longshot pays `30×150%×4 = 180`. By contrast, an isolated own-ground Honorable kill pays only 10. Therefore a six-kill game containing hot late Ace/Splash/Longshot deeds and tier claims can readily exceed eight spaced, mostly plain/home-ground kills whose heat repeatedly decayed. The lowercase badges do not explain any difference.

Concrete maximisation priorities:

1. Win first—otherwise all Glory is reported as zero.
2. Chain either partner’s kills with gaps under 45 ticks so the shared heat persists.
3. Prefer Ace targets, 2+ enemy grenade/spray clusters, and ≥866 px longshots; these outrank ordinary weapon deeds.
4. Fight in another team’s nearest-anchor Voronoi region for the 150% site multiplier.
5. Mix grenade and spray kills and coordinate a nonlethal partner tag before the finish to unlock weapon tiers, Cover Fire, Kitted, and Full Loadout.
6. Avoid friendly fire: it costs 60 immediately and also forfeits Clean Sheet’s 18, a minimum 78-Glory swing before the lost partner is considered.
7. Shield absorption adds 4–6 Glory per HP, but survival itself adds nothing.
8. Ignore `silent`, `sniper`, `almost`, `spotless`, `banksy`, and `grenadier` when optimising score; they are badges only.

Codex session ID: 01a06406-3749-7a31-a389-62c728043e72
Resume in Codex: codex resume 01a06406-3749-7a31-a389-62c728043e72
