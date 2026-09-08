# Policy-designer changelog: `fad3029` → `c3f7781b`

Read-only inspection completed; no files modified. HEAD verified as `c3f7781b` dated 2026-09-08.

| Command | Result |
|---|---|
| `git log --oneline fad3029..HEAD` | 67 commits. Main policy deltas: solo seating/map (`9a318548`), partnerless context (`3eed397f`), pact registry (`df499966`, `8e6fd4e5`), recut (`82e4f547`), armed win/downed modes (`2b66cec4`, `1991f684`), ally revive (`decb97fd`), HP/zone retune (`ef3b180e`), shell behavior changes. |
| `git diff --stat fad3029..HEAD` | 158 files changed, 11,842 insertions, 2,471 deletions. |

## 1. Solo mode, partner meaning, pacts, revive

| Question | Current answer |
|---|---|
| How are solos seated? | The variant defines 16 slots, each with a different team and `control:"play"`; `num_agents=16`, `teams=16`, one life, 4 HP. [manifest:1189–1328](/private/tmp/engine-main-v43/coworld_manifest_paintbot.json:1189) |
| Is `duo_partner` present? | No. `shellPartner` only finds another player on the same team; none exists here. `play_context.self.duo_partner` is emitted only when such a player exists. [server.nim:3683–3703](/private/tmp/engine-main-v43/src/ctf/server.nim:3683), [view.nim:650–690](/private/tmp/engine-main-v43/src/shell/view.nim:650) |
| What is the “duo grant”? | Exact teammate position/aim/alive/downed and optionally gun/hopper state; HP remains ordinary fog information. It is only for a literal same-team player, never a pact ally. [body.nim:686–701](/private/tmp/engine-main-v43/src/shell/body.nim:686) |
| What do `partner.*` guards read? | On every solo seat: `partner.alive=false`, `partner.dist=-1`, `partner.in_combat=false`. A pact does not change these values. [episode.nim:584–653](/private/tmp/engine-main-v43/src/shell/episode.nim:584) |
| Pact parameters | Required `partners` set, 1–8 `seat_or_duo_ref`; `holdFire` end trigger defaults to `{aliveTeams:2}` and also accepts `{tick:t}`/`{zonePhase:k}`; `onBetrayal` defaults `returnFire`; `protect` defaults false. [pact.nim:10–11](/private/tmp/engine-main-v43/play_sdk/reference/pact.nim:10) |
| References in solo | Use actual `seat:0`…`seat:15`. `duo:*` requires a configured two-seat duo and is therefore unsuitable here. [call_validation.nim:168–191](/private/tmp/engine-main-v43/src/shell/call_validation.nim:168) |
| How is a pact registered? | The engine reads the first `pact` entry’s static `partners` params from each ladder. Teams become allied only after both declare each other; withdrawal, damage, or death dissolves the symmetric registry. [episode.nim:1394–1409](/private/tmp/engine-main-v43/src/shell/episode.nim:1394), [sim.nim:915–969](/private/tmp/engine-main-v43/src/ctf/sim.nim:915), [sim_state.nim:214–254](/private/tmp/engine-main-v43/src/ctf/sim_state.nim:214) |
| What does mutual registration grant? | It keeps a downed solo alive while an upright pact ally exists, lets that ally revive it, prevents pact paint from splat-confirming its ghost, and permits pact participants in the kill’s Fibonacci ally-stack. [sim.nim:7905–7966](/private/tmp/engine-main-v43/src/ctf/sim.nim:7905), [sim.nim:8030–8058](/private/tmp/engine-main-v43/src/ctf/sim.nim:8030), [sim.nim:3936–3953](/private/tmp/engine-main-v43/src/ctf/sim.nim:3936), [sim.nim:2699–2760](/private/tmp/engine-main-v43/src/ctf/sim.nim:2699) |
| Does registration enforce peace? | No. Attacks remain legal. `noShoot` and `protect` come only from each seat’s local overlay: `noShoot` vetoes targets; `protect` additionally blocks firing through the ward and boosts threats aiming at it. [sim_types.nim:199–225](/private/tmp/engine-main-v43/src/ctf/sim_types.nim:199), [body.nim:781–831](/private/tmp/engine-main-v43/src/shell/body.nim:781), [body.nim:920–949](/private/tmp/engine-main-v43/src/shell/body.nim:920) |
| Betrayal/end sharp edge | `returnFire` removes both protection and no-shoot for the betrayer; `disengage` removes protection but retains no-shoot. The `holdFire` end condition clears the emitted overlay, but does **not** remove the static registry declaration. Retune/remove the entry to withdraw cleanly; otherwise the first “post-pact” hit is still pact damage and dissolves it. [pact.nim:93–155](/private/tmp/engine-main-v43/play_sdk/reference/pact.nim:93), [pact.nim:177–203](/private/tmp/engine-main-v43/play_sdk/reference/pact.nim:177) |
| Do guards gate registration? | Not currently: declaration extraction iterates ladder snapshots without checking the entry’s guard/state, and stops at the first `pact` entry. A guarded-off pact can therefore still register. [ladder.nim:302–313](/private/tmp/engine-main-v43/src/shell/ladder.nim:302), [episode.nim:1401–1406](/private/tmp/engine-main-v43/src/shell/episode.nim:1401) |

A downed solo is finalized immediately unless at least one registered pact team has an upright member. Otherwise it receives the normal 360-tick bleed window, halved on repeated downs to a 48-tick minimum. An upright same-team or currently pacted player must remain within 40 px for 48 consecutive ticks; progress resets on separation or painted ground. The lowest-index qualifying player is the reviver; the revived cog returns at 1 HP, while the reviver receives `dTagBack`. [sim_types.nim:1072–1080](/private/tmp/engine-main-v43/src/ctf/sim_types.nim:1072), [sim_config.nim:101–117](/private/tmp/engine-main-v43/src/ctf/sim_config.nim:101), [sim.nim:7922–8081](/private/tmp/engine-main-v43/src/ctf/sim.nim:7922)

One surprising implementation detail: when a pact ally causes the lethal down, `dTeamKill` is awarded to `victim.team`; consequently the **victim’s** product is halved, not the attacking pact ally’s. Same-team play previously hid that distinction. [sim.nim:2580–2601](/private/tmp/engine-main-v43/src/ctf/sim.nim:2580), [sim.nim:2664–2670](/private/tmp/engine-main-v43/src/ctf/sim.nim:2664)

## 2. Exact scoring pipeline

For each team, the recut starts at 1:

`score = floor(capped_product / 2^friendly_fire_halvings)`

Every positive fold saturates the product at `2^24 = 16,777,216`; in solo, team and seat are identical. [glory.nim:2423–2446](/private/tmp/engine-main-v43/src/ctf/glory.nim:2423), [glory.nim:2540–2565](/private/tmp/engine-main-v43/src/ctf/glory.nim:2540), [glory.nim:2791–2815](/private/tmp/engine-main-v43/src/ctf/glory.nim:2791)

| Pipeline component | Current behavior |
|---|---|
| Deed base | Common tags/spray/grenade/point-blank are ×1; first blood/revenge/rundown ×2; longshot/splash ×3; ace ×4. Closing Time is promoted to ×3 under `winAsMultiplier`; Last Light ×4. One kill selects one kill deed. [glory.nim:2448–2504](/private/tmp/engine-main-v43/src/ctf/glory.nim:2448), [sim.nim:2945–3019](/private/tmp/engine-main-v43/src/ctf/sim.nim:2945) |
| Territory | For any base class ≥2, a deed on another team’s nearest-pedestal Voronoi cell gains one integer rung: 2→3, 3→4, 4→5, etc. Commons never shift. [sim.nim:220–242](/private/tmp/engine-main-v43/src/ctf/sim.nim:220), [glory.nim:2724–2742](/private/tmp/engine-main-v43/src/ctf/glory.nim:2724) |
| Heat | Multiplier ladder ×1/×2/×4/×8 at pre-mint embers 0/1/2/4; drama adds one ember after pricing, cap 11, and quiet decay removes 2 after 270 ticks. Closing Time, Last Light, Tag Back, Joint Act, placement, and achievements do not use or raise heat. [glory.nim:953–990](/private/tmp/engine-main-v43/src/ctf/glory.nim:953), [glory.nim:850–905](/private/tmp/engine-main-v43/src/ctf/glory.nim:850), [sim.nim:409–478](/private/tmp/engine-main-v43/src/ctf/sim.nim:409) |
| Ally stack | On a kill, `k` counts the killer plus same-team or **currently pacted** co-damagers of that victim within 120 ticks. Factors for k=1…6+ are ×1, ×2, ×3, ×5, ×8, ×13. Random third parties no longer increase the kill factor. [glory.nim:2513–2522](/private/tmp/engine-main-v43/src/ctf/glory.nim:2513), [sim.nim:2699–2760](/private/tmp/engine-main-v43/src/ctf/sim.nim:2699) |
| Joint Act | Separate from the kill stack: any ≥2 distinct attacking teams in one victim incident mint base ×2 for each contributor, even without a pact. It is victim-site territory-priced and capped at six paying mints per team. [sim.nim:2762–2822](/private/tmp/engine-main-v43/src/ctf/sim.nim:2762) |
| Achievements | Tiers I–V fold ×1, ×1, ×2, ×2, ×4; the first Tier-V claim folds ×12. They use neither heat nor territory. [glory.nim:2506–2511](/private/tmp/engine-main-v43/src/ctf/glory.nim:2506), [sim.nim:511–545](/private/tmp/engine-main-v43/src/ctf/sim.nim:511) |
| Placement | Survivors crossing final 8, 4, and 2 receive ×2, ×3, and ×4. A winner necessarily accumulates ×24. [glory.nim:2679–2690](/private/tmp/engine-main-v43/src/ctf/glory.nim:2679), [sim.nim:6616–6652](/private/tmp/engine-main-v43/src/ctf/sim.nim:6616) |
| Win | `dVictory` is retired. After conclusion achievements, a one-seat BR winner folds a composition-neutral ×8; the product cap applies to this final fold. [glory.nim:2817–2853](/private/tmp/engine-main-v43/src/ctf/glory.nim:2817), [sim.nim:5873–5918](/private/tmp/engine-main-v43/src/ctf/sim.nim:5873) |
| Friendly fire | Each BR `dTeamKill` incident divides the derived score by 2, after the capped product; division floors. Under downed mode it is charged at the lethal down, not later finalization. [glory.nim:2781–2815](/private/tmp/engine-main-v43/src/ctf/glory.nim:2781), [sim.nim:2650–2670](/private/tmp/engine-main-v43/src/ctf/sim.nim:2650) |
| Mint caps | Per episode/team: `dShieldSoak=3` (currently ×1), `dDuoDown=4` (cannot mint against a one-seat team), `dTagBack=3`, `dJointAct=6`; every other deed is uncapped. Excess occurrences still appear/count but fold ×1. [glory.nim:2567–2677](/private/tmp/engine-main-v43/src/ctf/glory.nim:2567), [sim.nim:411–448](/private/tmp/engine-main-v43/src/ctf/sim.nim:411) |
| `results.scores` | Exactly one integer per seat, in seat order, holding that seat’s own `teamGlory` at `GameOver`, win or loss. It is **not winner-gated**; incomplete episodes report zero. [roster.nim:888–948](/private/tmp/engine-main-v43/src/ctf/roster.nim:888), [roster.nim:1015–1048](/private/tmp/engine-main-v43/src/ctf/roster.nim:1015) |

Thus the fixed win fold is ×8, not dynamically decaying. Automatic winner composition is `2×3×4×8 = ×192`; relative to a bare final-eight loser already holding ×2, the extra endgame advantage is ×96. Saturation makes the observed ratio approach ×1 as both sides reach the cap. A zero-tag win of 384 therefore contains the automatic ×192 plus one other ×2 fold; “zero tags” does not mean “zero deeds.” A bare loss of 2 is consistent with only the final-eight fold.

## 3. Reference plays

No reference play was added in this range. The only reference-source diff is `edge_ride` gaining a successful-init diagnostic log. The directory currently contains nine actual play manifests; `panicoverride.nim` is only a trap/output helper include and has no manifest or params. [edge_ride.nim:137–144](/private/tmp/engine-main-v43/play_sdk/reference/edge_ride.nim:137), [panicoverride.nim:1](/private/tmp/engine-main-v43/play_sdk/reference/panicoverride.nim:1)

| Play | Exact current parameters |
|---|---|
| `bodyguard` | `ward?:seat_or_duo_ref`; `interpose=true`; `leash=[80,220]`, each 0…4096 integer; `peelHp=2`, 0…64. [bodyguard.nim:14–15](/private/tmp/engine-main-v43/play_sdk/reference/bodyguard.nim:14) |
| `crossfire` | `minAngle=32`, 0…128 integer; `spacing=[120,320]`, each 0…600 integer. [crossfire.nim:14–15](/private/tmp/engine-main-v43/play_sdk/reference/crossfire.nim:14) |
| `edge_ride` | `coverBias=0.8`, 0…1; `enterLead=120`, 0…600 integer; `margin=220`, 40…600 integer. There is no `scatterHeading` or `scatterSteps`. [edge_ride.nim:11–14](/private/tmp/engine-main-v43/play_sdk/reference/edge_ride.nim:11) |
| `jackal` | `earshot=500`, 100…1200; `joinWhen=afterKill\|bothWeakened`; `exitAfter={kills:1}` with 1…4, or `{hpFloor:h}` with 0…3. [jackal.nim:16–18](/private/tmp/engine-main-v43/play_sdk/reference/jackal.nim:16) |
| `loot` | `contested=avoid\|race`; `detourMax=400`, 0…4096; `medkits=false`. [loot.nim:20–22](/private/tmp/engine-main-v43/play_sdk/reference/loot.nim:20) |
| `pact` | `partners` required set 1…8; `holdFire={aliveTeams:2}` or tick/zonePhase; `onBetrayal=returnFire\|disengage`; `protect=false`. [pact.nim:10–11](/private/tmp/engine-main-v43/play_sdk/reference/pact.nim:10) |
| `scatter` | `distance=320`, 60…1200; `ticks=300`, 24…2400. [scatter.nim:18–19](/private/tmp/engine-main-v43/play_sdk/reference/scatter.nim:18) |
| `supply_run` | `contested=avoid\|race`; `detourMax=500`, 0…4096; `whenHpBelow=3`, 0…64. With 4 HP it starts only at HP 2 or lower. [supply_run.nim:17–18](/private/tmp/engine-main-v43/play_sdk/reference/supply_run.nim:17), [supply_run.nim:48–51](/private/tmp/engine-main-v43/play_sdk/reference/supply_run.nim:48) |
| `target_law` | `holdTrigger?={aliveTeams:2…16}\|{tick:≥0}\|{zonePhase:1…8}`; `never=[]`, set 0…8 refs; `prefer=[]`, list 0…4 of bounty/isolated/revenge/weakened. [target_law.nim:15–16](/private/tmp/engine-main-v43/play_sdk/reference/target_law.nim:15) |

Passing `scatterHeading`/`scatterSteps` to stock `edge_ride` is an `unknownField` call rejection. Use the separate `scatter(distance,ticks)` module or your own uploaded module. [call_validation.nim:334–355](/private/tmp/engine-main-v43/src/shell/call_validation.nim:334)

Effective semantic changes:

- `jackal` now receives real public kill-feed rows; `loot`/`supply_run` now receive real fog-safe item sightings. Previously those live inputs were empty. [server.nim:3792–3808](/private/tmp/engine-main-v43/src/ctf/server.nim:3792), [server.nim:3841–3860](/private/tmp/engine-main-v43/src/ctf/server.nim:3841)
- `crossfire` always holds in solo because it has no configurable partner. `bodyguard` also holds without an explicit `ward`; an external solo ward remains an other-team fog track and is consequently also considered by its enemy-threat scan. [crossfire.nim:151–162](/private/tmp/engine-main-v43/play_sdk/reference/crossfire.nim:151), [bodyguard.nim:54–69](/private/tmp/engine-main-v43/play_sdk/reference/bodyguard.nim:54)
- Empty combat policy now means shoot all visible non-team tracks, so Hold/navigation plays fire while moving unless `pact`/`target_law` veto or hold fire. The engine finisher was removed; idle aim defaults to 0 unless the play sets it. [types.nim:72–95](/private/tmp/engine-main-v43/src/shell/types.nim:72), [body.nim:1334–1364](/private/tmp/engine-main-v43/src/shell/body.nim:1334)
- `loot` and `scatter` comments say “emit nothing and yield,” but the runtime retains the last accepted emission and the ladder retains its cache. After either has emitted once, silence preserves that order; before its first emission, the first passing controller falls back to engine default rather than trying the next controller. Only a false guard, fault, or replacement reliably yields. [instance.nim:570–597](/private/tmp/engine-main-v43/src/shell/instance.nim:570), [ladder.nim:662–689](/private/tmp/engine-main-v43/src/shell/ladder.nim:662)
- With `lootStart=false`, marker/hopper crates are absent and every seat starts with gun and hopper. Loot now targets only the remaining pickups; supply is 6 sprays and 22 grenades, with give/drop/bandages disabled. [sim.nim:1620–1626](/private/tmp/engine-main-v43/src/ctf/sim.nim:1620), [sim.nim:2027–2032](/private/tmp/engine-main-v43/src/ctf/sim.nim:2027), [manifest:1382–1393](/private/tmp/engine-main-v43/coworld_manifest_paintbot.json:1382)

## 4. Guards, ladder, protocol

| Surface | Delta/current contract |
|---|---|
| Guard paths | No path-registry change from `fad3029`. There are no pact/ally facts. Current paths are `self.hp_frac`; three `partner.*`; enemy/zone/item/carrying-spray world facts; and `intent.*` annotations. [policy_page.nim:144–226](/private/tmp/engine-main-v43/src/ctf/policy_page.nim:144) |
| Resolver gaps | Ladder guards resolve `intent.*` to false/−1. `world.carrying_spray` is registered but has no resolver arm, so it currently reads false. Missing enemy/item distances read −1; zone distance is 0 inside. [episode.nim:584–653](/private/tmp/engine-main-v43/src/shell/episode.nim:584) |
| Evaluation | Guards are canonical-JSON parsed, type/depth/node validated and compiled once; absent guard passes. They are evaluated against live fogged body state every tick. [guards.nim:51–78](/private/tmp/engine-main-v43/src/shell/guards.nim:51), [ladder.nim:401–406](/private/tmp/engine-main-v43/src/shell/ladder.nim:401) |
| Selection/folding | Every passing live overlay steps and folds by unioning `noShoot`/`protect`, ordered-deduping `prefer`, and OR-ing `holdFire`. The first passing live controller owns movement. [ladder.nim:546–562](/private/tmp/engine-main-v43/src/shell/ladder.nim:546), [ladder.nim:614–699](/private/tmp/engine-main-v43/src/shell/ladder.nim:614) |
| Uploads | Upload all modules before play begins. New module uploads during `Playing` reject with `uploadWindowClosed`; already-uploaded modules may still receive live calls/retunes. [ingress.nim:259–297](/private/tmp/engine-main-v43/src/shell/ingress.nim:259), [server.nim:5181](/private/tmp/engine-main-v43/src/ctf/server.nim:5181) |
| Retune/recall | Each accepted call atomically replaces the whole ladder. Retune reuse requires the same `entry_id`, play name and module hash plus `"retune":true`; identical params retain state/cache, changed params call `play_retune`, and refusal removes the entry. There is no recall opcode: a scheduled recall is another full `PlayCall`. [replacement.nim:32–63](/private/tmp/engine-main-v43/src/shell/replacement.nim:32), [ladder.nim:329–399](/private/tmp/engine-main-v43/src/shell/ladder.nim:329) |
| Throughput | Initialization/retune budget rose from 1/seat and 2/server to 3/seat and 16/server per tick, round-robin. Guest view bytes are now built lazily only if a live play steps. [types.nim:410–414](/private/tmp/engine-main-v43/src/shell/types.nim:410), [ladder.nim:510–543](/private/tmp/engine-main-v43/src/shell/ladder.nim:510), [ladder.nim:578–589](/private/tmp/engine-main-v43/src/shell/ladder.nim:578) |
| Fault codes | No additions/reordering: current stable codes remain `unknown`, Wasmtime traps, `hostError`, `returnedNonzero`, `refused`, `abiViolation`, `instantiateFailed`, and `retuneAbsent`. `uploadWindowClosed` is a rejection reason, not a new fault code. [types.nim:150–174](/private/tmp/engine-main-v43/src/shell/types.nim:150) |
| Reconnect | Control context now returns the accepted call bytes/proposal ID and ready playbook names/hashes, in addition to epoch/floors/budgets/transcript mark. [outbound.nim:20–38](/private/tmp/engine-main-v43/src/shell/outbound.nim:20), [outbound.nim:224–260](/private/tmp/engine-main-v43/src/shell/outbound.nim:224) |
| Diagnostics | `log()` is surfaced; one 256-byte call per invocation, excess silently dropped. Live output is limited to four escaped lines per seat per 24 ticks and is public/non-durable. [types.nim:447–450](/private/tmp/engine-main-v43/src/shell/types.nim:447), [episode.nim:1138–1174](/private/tmp/engine-main-v43/src/shell/episode.nim:1138) |
| Lobby/chat | Wire opcodes remain v1 `A3/B2`; the lobby window remains 600 ticks. The temporary `+X/-X` pact grammar landed and was then retired in this range—general chat remains unchanged. In-game cross-seat shouts now reach solo bodies. [types.nim:279–306](/private/tmp/engine-main-v43/src/shell/types.nim:279), [sim_types.nim:199–225](/private/tmp/engine-main-v43/src/ctf/sim_types.nim:199), [server.nim:3922–3935](/private/tmp/engine-main-v43/src/ctf/server.nim:3922) |

## 5. Zone schedule and map pool

`startWaitTicks=120`; `maxTicks=10,000`. The authored zone completes its waits/shrinks after 3,751 gameplay ticks and then holds the final 0.1%-scale rectangle. [manifest:1322–1325](/private/tmp/engine-main-v43/coworld_manifest_paintbot.json:1322)

| Phase | `z` | Wait | Shrink | DPS | Cumulative end |
|---:|---:|---:|---:|---:|---:|
| 1 | 0.75 | 259 | 160 | 0 | 419 |
| 2 | 0.55 | 0 | 183 | 3 | 602 |
| 3 | 0.35 | 0 | 261 | 6 | 863 |
| 4 | 0.20 | 0 | 450 | 10 | 1,313 |
| 5 | 0.08 | 0 | 1,163 | 15 | 2,476 |
| 6 | 0.001 | 0 | 1,275 | 20 | 3,751 |

Source: [manifest:1337–1373](/private/tmp/engine-main-v43/coworld_manifest_paintbot.json:1337).

`brpool16` seed-selects one of eleven 3211×1713, 16-spawn-group maps, without a ballot: `br-gen-505`, `5001`, `5040`, `5120`, `5161`, `5204`, `5263`, `5312`, `5359`, `5400`, `5448`. [br_map_pool.nim:170–213](/private/tmp/engine-main-v43/src/ctf/br_map_pool.nim:170), [data/br_map_pool.json:3](/private/tmp/engine-main-v43/data/br_map_pool.json:3), [sim_config.nim:1356–1375](/private/tmp/engine-main-v43/src/ctf/sim_config.nim:1356)

Sharp edge: pool metadata says gun range 331, but the flagship manifest explicitly sets 1300, and explicit config overrides map metadata. Longshot therefore keys off roughly `1300×0.667 ≈ 867 px`, not the pool’s 331-px value. [manifest:1315](/private/tmp/engine-main-v43/coworld_manifest_paintbot.json:1315), [sim_config.nim:1371–1380](/private/tmp/engine-main-v43/src/ctf/sim_config.nim:1371), [glory.nim:2929–2933](/private/tmp/engine-main-v43/src/ctf/glory.nim:2929)

## 6. Ranked solo tactics

Factors below are deterministic engine multipliers, not probability-adjusted EV.

| Rank | Tactic | Mechanical factor / design target |
|---:|---|---|
| 1 | Reach final two, then win | Automatic ×192 from placement and solo win; ×96 versus a finalist/final-eight baseline already holding ×2. A pre-placement product of 87,382 is sufficient to saturate after ×192. [sim.nim:6616–6652](/private/tmp/engine-main-v43/src/ctf/sim.nim:6616), [sim.nim:5904–5916](/private/tmp/engine-main-v43/src/ctf/sim.nim:5904) |
| 2 | Prefer premium tags over tag count | A common tag is ×1. Cold Ace is ×4; on enemy ground at maximum heat it is `(4+1)×8 = ×40`, or ×80 with one pacted co-damager. Three tags alone do **not** guarantee the cap. [glory.nim:2450–2463](/private/tmp/engine-main-v43/src/ctf/glory.nim:2450), [glory.nim:2724–2765](/private/tmp/engine-main-v43/src/ctf/glory.nim:2724) |
| 3 | Form mutual pacts, then synchronize damage | A qualifying Joint Act is base ×2 for each contributor, capped at six; the kill additionally receives pact-only stack ×2/×3/×5/×8/×13 as participation grows. Even two-seat cooperation can contribute a separate Joint Act ×2 and kill-stack ×2. [sim.nim:2762–2822](/private/tmp/engine-main-v43/src/ctf/sim.nim:2762), [glory.nim:2513–2522](/private/tmp/engine-main-v43/src/ctf/glory.nim:2513) |
| 4 | Route toward attainable high-tier achievements | Tier III/IV ×2, Tier V ×4, first Tier V ×12. Gun/longshot achievements are more solo-realistic than teammate-dependent trees. [glory.nim:2506–2511](/private/tmp/engine-main-v43/src/ctf/glory.nim:2506), [sim.nim:511–545](/private/tmp/engine-main-v43/src/ctf/sim.nim:511) |
| 5 | Revive pact allies on dry ground | Each of the first three completed revives folds base ×2, or ×3 if the ghost lies on another team’s territory. Being revived gives no direct deed to the ghost, but preserves its accumulated product and placement route. [sim.nim:8056–8081](/private/tmp/engine-main-v43/src/ctf/sim.nim:8056), [glory.nim:2495–2496](/private/tmp/engine-main-v43/src/ctf/glory.nim:2495) |
| 6 | Make peace mechanically safe | Preventing one pact/friendly lethal down preserves ×2 of the victim’s score and keeps the registry’s revive/stack benefits. Use both `pact.noShoot` and `target_law.never`; chat agreement alone grants nothing. [glory.nim:2781–2815](/private/tmp/engine-main-v43/src/ctf/glory.nim:2781), [body.nim:1006–1080](/private/tmp/engine-main-v43/src/shell/body.nim:1006) |

Codex session ID: 01a0821e-ea13-7440-8844-e1ac1533c143
Resume in Codex: codex resume 01a0821e-ea13-7440-8844-e1ac1533c143
