# Result

At HEAD `9f17087`, the reconstruction is:

```text
P = 1
P *= amount                 for each positive glory_deed assigned to the team
P *= amount                 for each achievement event assigned to the team
H += -amount                for each dTeamKill glory_deed
reported score = floor(P / 2^H)
```

For the stated flags, there is no hidden win multiplier: `winAsMultiplier=false`, so victory is an ordinary, logged `dVictory` deed. `deedMintCaps=false`, so factors fold normally, subject only to the remote `2^62` saturation guard. `coworld_manifest_paintbot.json:1357-1367`; `src/ctf/glory.nim:2404-2418`.

Therefore:

- `3,888 × 24 = 93,312`: the missing achievement-event product was `24`, necessarily `12×2`.
- `1,728 × 192 = 331,776`: the achievement product was `192`, for example `12×4×2×2` or `12×2×2×2×2`.
- Inspect the separate `achievement` events to identify the exact trees. Their `amount` is the folded factor, `weapon` is the tree, `hp` is the zero-based tier, and `blocked=1` marks a first Tier-V claim. `src/ctf/sim.nim:373-400`.

One scope correction: this manifest currently seats 16 players as eight duos, not 32 players/16 duos. `coworld_manifest_paintbot.json:1166-1218,1287-1305`.

## 1. What `glory_deed.amount` contains

For a positive deed, `amount` is the complete integer factor actually folded:

```text
territory-shifted class
× eligible heat
× eligible carry
× ally-stack
```

`awardDeed` calls `recutFactor`, folds that factor, assigns `amount = factor`, and then emits it unchanged in `GloryDeed`. `src/ctf/sim.nim:229-244,272-282,324-326`; composition is at `src/ctf/glory.nim:2592-2613`.

Consequences:

- It is not merely the base rung.
- Territory, heat and stack are already included.
- Carry would also be included, but BR is flagless, so `carrying=false`. `src/ctf/sim.nim:202-215`.
- An amount such as `9` is already composite—for example enemy-ground `DUO DOWN` class `3` × stack `3`.
- The amount alone does not reveal its decomposition.

For `dTeamKill`, `amount` is instead the negative number of newly charged halvings: normally `-1` per BR incident. `src/ctf/sim.nim:235-241`.

Team attribution is `target = ord(team)`, not necessarily `source`—a documented event quirk. Victory calls `awardDeed` without a player, hence `source=-1`; grouping only by source will miss it. `src/ctf/sim.nim:318-326,5157-5160`.

Achievements are not `glory_deed` events. They fold into the same product and emit separately as `Achievement`. `src/ctf/sim.nim:363-400`.

The result reporter copies final `teamGlory` exactly for every concluded team, including losers; there is no current winner gate. `src/ctf/roster.nim:1006-1027`. This contradicts the now-stale “losers still bank 0” comment at `src/ctf/glory.nim:2331-2333`; executable reporting code wins.

## 2. Heat under the recut

The ladder is:

| Embers before mint | Heat |
|---:|---:|
| 0–1 | ×1 |
| 2–4 | ×2 |
| 5–9 | ×4 |
| 10–11 | ×8 |

`HeatLadder=[1,2,4,8]`, thresholds `[2,5,10]`, cap `11`. `src/ctf/glory.nim:855-875`; lookup at `src/ctf/glory.nim:2208-2220`.

A deed with positive drama adds one ember—`times` embers for a batched mint—after its own factor is calculated. Thus it benefits from the pre-deed heat and cannot light its own rung. `src/ctf/sim.nim:216-244,310-312`.

Globally, heat-building deeds are the ten combat classifications through `dAceTag`; flag/capture/carrier/denial/escort/assist/rescue; `dWipe`; `dDuoDown`; and `dVictory`. The exact drama table is `src/ctf/glory.nim:760-811`; `paysHeat` is simply positive drama excluding achievements at `src/ctf/glory.nim:2130-2138`.

On this flagless BR variant, the reachable heat builders are:

- The ordinary combat kill classifications, including class-×1 commons.
- `dDuoDown`.
- `dVictory`.

Important exceptions:

- A class-×1 common always folds exactly `1`, even while hot, but still adds an ember. `src/ctf/glory.nim:2603-2610`.
- `DUO DOWN` does take heat and adds heat.
- `CLOSING TIME` and `LAST LIGHT` have zero drama: neither takes heat nor adds an ember.
- Achievements never take or add heat.
- `dVictory` takes current heat, then adds an otherwise-useless final ember.
- Because the ordinary kill is awarded before the separate `FIRST BLOOD`, the first kill normally supplies two embers in sequence; `FIRST BLOOD` sees only the first ember. `src/ctf/sim.nim:2551-2554,2626-2629`.

Cooling subtracts two embers after each 45-tick period without a drama deed, repeats every 45 quiet ticks, and floors at zero. `src/ctf/sim.nim:83-93`; constants at `src/ctf/glory.nim:875-882`.

## 3. Ally-stack: what “in context” means

The ladder is `k=1..6 → ×1/×2/×3/×5/×8/×13`, clamped at ×13. `src/ctf/glory.nim:2393-2402,2564-2570`.

For a BR kill, `k` is the number of distinct non-victim-team seats that:

- Include the killer unconditionally; plus
- Landed positive, non-self damage on that same victim within the last 120 ticks.

`src/ctf/sim.nim:2281-2324`; marks are opened and retained by positive damage at `src/ctf/sim.nim:2819-2842`; the window constant is `120` at `src/ctf/glory.nim:1520-1527`.

Thus:

- Your partner counts only if they actually hit that victim within the window.
- Other duos count even though they remain opponents.
- Repeated hits by one seat count once.
- The victim’s own duo never counts.
- Environmental damage never counts.
- Shield-absorbed positive hits still create marks.
- Pact declarations, lobby chat, proximity and team labels are irrelevant.
- The window is rolling damage history; permanent death clears it. `src/ctf/sim.nim:2643-2653`.
- A lone duo can reach `k=2 → ×2`; it needs outside attackers for `k≥3`.

Only the principal kill deed receives this computed `stackK`. The separately minted `FIRST BLOOD`, victory, and non-kill deeds retain the default `k=1`. `src/ctf/sim.nim:2507-2509,2551-2554,2626-2629`.

## 4. Achievement factors and BR-claimable tiers

Factors are Tier I/II `×1`, Tier III/IV `×2`, Tier V `×4`. Only Tier V can receive first-claim `×3`, making a first Tier V `×12`. `src/ctf/glory.nim:2386-2391,2615-2627`; Tier-V-only enforcement at `src/ctf/sim.nim:345-376`.

Same-tick claimants all count as first because satisfaction is read for every team before any claim is minted. `src/ctf/sim.nim:547-565`.

Claims that can fire in this flagless two-seat BR:

| Tree | Claimable tiers |
|---|---|
| Gun | I First Tag; II Marksman; III Bounty; IV Sharpshooter; V Longshot |
| Spray | I First Coat; II Full Coverage; III Repainted; IV The Muralist; V Double Splash |
| Grenade | I Delivery; II Splatterbomb; III Blast Radius; IV Double Blast; V The Bombardier |
| Backup | I Cover Fire; III The Save; IV Second Wind |
| Squad | I Kitted; II Full Loadout; IV Clean Sheet |

Names are defined at `src/ctf/glory.nim:1771-1788,1822-1895,1996-2018`; executable gates are `src/ctf/sim.nim:454-520`.

Unclaimable here:

- Backup II needs a heart escort; Backup V needs three distinct killers, impossible for a duo. `src/ctf/sim.nim:472-475,609-629`.
- All Provider/med tiers are omitted.
- All Carrier and Defender tiers require hearts.
- Squad III is tombstoned; Squad V requires a capture. `src/ctf/sim.nim:501-518,525-534`.

`Clean Sheet` is conclusion-only and requires zero `player.teamKills` across the duo. Every qualifying team—winner or loser—claims `×2`. `src/ctf/sim.nim:424-452,506-511`.

The conclusion sweep also catches any other tier first satisfied by the terminal kill; it scans every team/tree/tier on every normal conclusion. `src/ctf/sim.nim:567-607,5140-5161`.

Winner-only badges such as Spotless, Rambo, Sniper and Silent are separate results badges; they never fold the Glory product. `src/ctf/sim.nim:5277-5286,5354-5389`.

## 5. Enemy-ground ownership on `br_map_pool`

Ownership is a strict squared-Euclidean nearest-anchor Voronoi calculation. Ties stay with the earliest active `Team` enum because the update uses `<`, not `<=`; there is no neutral ground. `src/ctf/sim.nim:54-76`.

For an S2 pool map:

```text
perTeam = spawnPoints.len / teamCount
anchor(team) = spawnPoints[ord(team) * perTeam]
```

On current eight-duo maps, that is one authored spawn point per team. `src/ctf/arena.nim:675-697`; the pool declares eight groups and authored points, e.g. `data/br_s2_map_pool.json:871-908`.

Although BR is flagless and draws no real pedestal, `flagHome(team)` still returns that logical anchor for scoring. `src/ctf/arena.nim:732-741,790-793`.

A deed is “enemy ground” when the nearest anchor to its pricing point belongs to another team. For kills the pricing point is the victim’s stored `x,y`, not the killer’s position. `src/ctf/sim.nim:2551-2554`.

The recut does not multiply by 150%. It recognizes that signal and adds one to every class above 1: `2→3`, `3→4`, `4→5`, `6→7`, `8→9`; class 1 never shifts. `src/ctf/glory.nim:2572-2590`.

There is no direct `ground_owner` bit in the play context. A policy can reproduce it by using the resolved `context.map.name`, its roster team, its current position, and the public pool map’s ordered `spawnPoints`; the context exposes map identity but not those points. `src/ctf/server.nim:1661-1679`; `src/shell/view.nim:650-685`.

## 6. Friendly-fire division

A BR incident is one permanently finalized death whose valid killer has the same team as the victim. `KillContext.friendly` is same-team, and `killDeed` resolves that to `dTeamKill`. `src/ctf/sim.nim:2484-2486`; `src/ctf/glory.nim:2767-2779`.

With `downedMode`:

- The initial lethal friendly hit only downs and returns before pricing—no division yet. `src/ctf/sim.nim:2418-2430`.
- If that ghost bleeds out, finalization reuses `downedBy`; a friendly downer therefore causes one division. `src/ctf/sim.nim:2769-2785,7187-7189`.
- If revived, that down causes no division. A later down is a fresh opportunity; only the down leading to permanent finalization is charged.
- If an enemy gun splats the ghost, the enemy splatterer becomes the final killer, so there is no friendly-fire division. `src/ctf/sim.nim:3427-3435`.
- Shooting a downed partner with a gun does nothing; spray and grenades skip downed bodies entirely. `src/ctf/sim.nim:3427-3435,2940-2946,3885-3889`.
- A self-grenade permanent death also qualifies for the ledger division: same-team pricing has no self exclusion.

There is a separate Clean Sheet/stat wrinkle: weapon kill credit is recorded at the down, and teammate lethal downs increment `teamKills` even if later revived or enemy-confirmed. Self-kill credit is discarded. `src/ctf/roster.nim:621-641`; gun call order at `src/ctf/sim.nim:3545-3550`.

## 7. `CLOSING TIME` and `LAST LIGHT` tick windows

Elapsed time is `e = tickCount - gameStartTick`; `gameStartTick` is set exactly when phase becomes `Playing`. `src/ctf/sim.nim:1693-1695`.

| Elapsed `e` | Approx. absolute tick if Playing starts 735 | Classification |
|---:|---:|---|
| 0–344 | 735–1079 | Neither |
| 345–557 | 1080–1292 | Closing phase 0 |
| 558–801 | 1293–1536 | Closing phase 1 |
| 802–1149 | 1537–1884 | Closing phase 2 |
| 1150–1749 | 1885–2484 | Closing phase 3 |
| 1750–3299 | 2485–4034 | Closing phase 4 |
| 3300–4999 | 4035–5734 | Last Light; final phase is also shrinking |
| ≥5000 | ≥5735 | Last Light; final hold |

Schedule source: `coworld_manifest_paintbot.json:1314-1350`. Phase-walk boundary logic is `src/ctf/sim.nim:2254-2279`.

`LAST LIGHT` takes precedence from the instant the last authored phase begins, including its wait and shrink. `CLOSING TIME` therefore only has an effective window of `e=345..3299`.

These are upgrade-only classifications:

- `DUO DOWN` replaces `CLOSING TIME` at their equal base class.
- A marquee deed replaces the ordinary kill only if its base class is strictly higher.
- `LAST LIGHT` suppresses the Duo-Down check entirely.
- Consequently a Bounty can shadow Last Light, while a Longshot is upgraded to Last Light. `src/ctf/sim.nim:2510-2543`.

## 8. `DUO DOWN`

It does not require the scoring team to have downed both enemy seats.

At permanent finalization, the engine asks only whether any other member of the victim’s team still has `alive=true`. It never checks who downed or killed the partner. `src/ctf/sim.nim:2527-2540`.

Therefore:

- If another duo eliminated the partner and you finalize the survivor, you may receive `DUO DOWN`.
- A downed but unfinalized partner remains `alive=true`, preventing an early Duo Down.
- If both seats are downed, `updateDowned` finalizes both in index order; only the second finalization sees the team empty and can mint Duo Down. `src/ctf/sim.nim:7137-7149`.
- A bleed-out counts: it routes through `killPlayer` with the stored `downedBy`.
- An enemy splat credits the splatterer instead.
- During Last Light, no Duo Down is considered.
- Like every marquee label, it only replaces an underlying kill whose base class is lower than `2`.

## Six highest-value concrete tactics

These are deterministic factors once the stated conditions hold, ranked by immediate product impact; no empirical success probability is implied.

1. **First Longshot Tier V while hot, on enemy ground, with both seats having hit:** deed `(3+1)×8×2 = ×64`, plus first Tier-V `×12`, jointly `×768`. Other-duo contributors can raise the deed to `4×8×13=×416`, jointly `×4,992`. `src/ctf/glory.nim:2346,2386-2402,2592-2613`; `src/ctf/sim.nim:2571-2579`.

2. **Both focus-fire a visible level-3+ Ace on enemy ground while at ten embers:** Bounty deed `(4+1)×8×2 = ×80`; the team’s first Bounty also claims Tier III `×2`, jointly `×160`. `src/ctf/glory.nim:1192-1198,2350,2386`; `src/ctf/sim.nim:2580-2581`.

3. **Enter the decisive win with ten embers:** `dVictory 8×heat 8 = ×64`; it is home-priced and has no stack. `src/ctf/glory.nim:2374,2609-2613`; `src/ctf/sim.nim:5150-5160`.

4. **Finalize a plain enemy duo on its ground while hot and with both seats in context:** `(DUO 2+territory 1)×heat 8×stack 2 = ×48`. Finish within 120 ticks so the partner’s damage mark remains. `src/ctf/glory.nim:2368,2572-2613`; `src/ctf/sim.nim:2527-2540`.

5. **Convert a mundane late kill into Last Light:** on enemy ground with both seats in context, `(4+1)×2 = ×10`; it deliberately receives no heat. Before elapsed tick 3300, the analogous Closing-Time factor is `(2+1)×2 = ×6`. `src/ctf/glory.nim:2369-2373,2609-2613`; `src/ctf/sim.nim:2254-2279`.

6. **Never lethally hit the partner:** versus one finalized teammate death, zero FF preserves `Clean Sheet ×2` and avoids `/2`, a net `×4` advantage. Even a revived friendly down still forfeits the Clean Sheet `×2` through the team-kill statistic. `src/ctf/sim.nim:235-241,452,506-511`; `src/ctf/roster.nim:621-641`.

Codex session ID: 01a06e4b-000b-7643-87a4-801b96205112
Resume in Codex: codex resume 01a06e4b-000b-7643-87a4-801b96205112
