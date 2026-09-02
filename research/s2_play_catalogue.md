## Season 2 play catalogue

The callable reference library is the seven advertised core plays plus later `loot` and `scatter`. `bounding_overwatch`, `duo_guard`, `warden`, `spread_out`, `hunt`, `ambush`, and `camp` do not exist; `hold` is an emitted intent, while `grenade` and `spray` are weapons/items, not plays. `panicoverride.nim` is only a trap helper without a manifest. `play_sdk/README.md:23-25`, `play_sdk/reference/scatter.nim:17-19`, `src/shell/finisher.nim:23-26`, `play_sdk/reference/panicoverride.nim:1`

| Play / class | Parameters: default; accepted range | Movement and fire behavior |
|---|---|---|
| `pact` / overlay | `partners` required set 1–8 `seat:`/`duo:` refs; `holdFire={aliveTeams:2}` or `{aliveTeams:2..16}`, `{zonePhase:1..8}`, `{tick:≥0}`; `onBetrayal=returnFire\|disengage`; `protect=false` | No movement. Until the named end condition, partners are `noShoot` and optionally protected wards. `returnFire` removes a betrayer from both sets; `disengage` removes only protection. Despite its name, `holdFire` is the pact-ending trigger, not a global fire hold. `play_sdk/reference/pact.nim:1-11,93-100,146-155,182-200` |
| `edge_ride` / controller | `margin=220` `[40,600]`; `enterLead=120` `[0,600]`; `coverBias=.8` `[0,1]` | Returns inside the current zone; enters the next rectangle when shrink is within `enterLead`; otherwise maintains the inset margin, optionally diverting toward cover within `331×coverBias` px; holds when satisfied. Fire comes only from overlays. `play_sdk/reference/edge_ride.nim:1-13,56-104,114-120` |
| `bodyguard` / controller | `ward` optional ref; omitted means configured duo mate; `leash=[80,220]`, each `[0,4096]` and min≤max; `interpose=true`; `peelHp=2` `[0,64]` | Maintains the leash, interposes between ward and nearest threat, or moves onto a threat within 331 px when ward HP `<peelHp`; holds without a known ward. Fire is overlay-owned. Caveat: the manifest accepts a duo ref, but this SDK parser currently accepts only explicit `seat:N`; omit `ward` for the normal mate. `play_sdk/reference/bodyguard.nim:3-16,87-119,145-171`; `play_sdk/play.nim:1571-1616` |
| `jackal` / controller | `earshot=500` `[100,1200]`; `joinWhen=afterKill\|bothWeakened`; `exitAfter={kills:1}` with kills `[1,4]`, or `{hpFloor:0..3}` | Tracks enemies inside `earshot`. `afterKill` joins after any ≤240-tick-old public kill; `bothWeakened` loiters at earshot and joins only when at least two known-HP tracks are all at 1 HP. Once engaged, moves away after its team’s kill-row quota or HP falls below the floor. `play_sdk/reference/jackal.nim:3-19,79-143`; `play_sdk/play.nim:1243-1314` |
| `target_law` / overlay | `never=[]`, set 0–8 refs; `prefer=[]`, unique ordered list 0–4 from `weakened, isolated, revenge, bounty`; optional `holdTrigger={aliveTeams:2..16}\|{zonePhase:1..8}\|{tick:≥0}` | No movement. Excludes `never`, lexicographically prioritizes `prefer`, and—if `holdTrigger` is present—refuses to initiate until the trigger, while still permitting return fire. Release latches permanently. `play_sdk/reference/target_law.nim:3-16,62-71,90-105` |
| `supply_run` / controller | `whenHpBelow=3` `[0,64]`; `detourMax=500` `[0,4096]`; `contested=avoid\|race` | At HP below threshold, runs to the nearest usable medkit within the straight-line detour. `avoid` rejects an enemy at the pickup; `race` proceeds only if strictly closer. Otherwise emits an explicit hold, so it blocks lower controllers. `play_sdk/reference/supply_run.nim:16-19,48-86,136-155`; `play_sdk/play.nim:1155-1203` |
| `crossfire` / controller | `spacing=[120,320]`, each `[0,600]` and min≤max; `minAngle=32` `[0,128]` brads | Closes/backoffs to spacing; when both duo bearings to its nearest enemy differ by less than `minAngle`, moves perpendicular—preferring the safer zone side—to open the firing angle; otherwise holds. `play_sdk/reference/crossfire.nim:3-15,121-180,241-252` |
| `scatter` / controller | `distance=320` `[60,1200]`; `ticks=300` `[24,2400]` | For `ticks` after initialization, moves `distance` away from the nearest tracked enemy, or toward zone centre if none, clamped inside the current zone. It then emits nothing—but the ladder retains its last cached navigation, so it does **not** truly yield without a false guard or a re-call. `play_sdk/reference/scatter.nim:9-19,84-110`; `src/shell/ladder.nim:530-560,609-631` |
| `loot` / controller | `detourMax=400` `[0,4096]`; `contested=avoid\|race`; `medkits=false` | Fetches the nearest usable pickup—grenade, shield, spray, barrier, and optionally medkit—within the detour. It has no enemy/coast-clear trigger internally and emits nothing when no item qualifies; prior cached navigation can consequently persist. `play_sdk/reference/loot.nim:1-21,50-90,128-150`; `src/shell/ladder.nim:530-560` |

## Ladder/controller semantics

| Rule | Exact effect |
|---|---|
| Ordering | Every passing live overlay is stepped and folded; the first passing live controller is selected. Later controllers are considered only if the selected controller faults—not when it holds or emits nothing. A silent controller without cache gets the native default. `src/shell/ladder.nim:562-645` |
| Movement vs fire | The selected controller/reflex supplies the base movement `Intent`; overlays union `noShoot`/`protect`, concatenate-and-deduplicate preferences in ladder order, and OR `holdFire`. The body then executes movement and combat independently. `src/shell/ladder.nim:498-514,591-645`; `src/shell/body.nim:1210-1270` |
| Arming fire | Combat runs only if the folded policy has a hold, preference, `noShoot`, or `protect`. Thus a movement-only ladder never shoots; a nonempty `target_law` or `pact` arms auto-target/fire. Gun trigger ticks normally freeze movement; spray does not. `src/shell/body.nim:719-722,1252-1270` |
| Guards | This checkout compiles guards and evaluates them every tick against live paths. The deployed behavior specified in the question instead supplies `0.0/false`; expressions still evaluate against those values. Consequently, avoid `when` and assume the first controller runs. `src/shell/ladder.nim:367-372`; `src/shell/episode.nim:485-494,507-576` |
| Default | With no usable controller output: rotate to the next zone at ≤120 ticks, regroup if partner is >256 px away, seek cover when threatened, otherwise hold. `src/shell/default_play.nim:29-42,78-112` |
| Reflex override | Hardwired priority is clear-grenade → clear-spray → zone-escape. A selected reflex replaces controller movement for that tick, but overlays are still folded afterward, so firing may continue. `src/shell/episode.nim:479-483`; `src/shell/ladder.nim:600-645` |
| Reflex triggers | Grenade: predicted blast covers the body plus 24 px. Spray: visible cone covers self or ≥2 anonymous impacts occurred within 48 ticks. Zone: outside the current rectangle or ≤72 ticks before shrink; it releases above 96. The integration’s zone adapter returns only `0` or `ticksToShrink`. `src/shell/reflexes.nim:16-24,144-152,581-591,636-671`; `src/shell/episode.nim:890-917` |
| Re-call | A valid call atomically replaces the entire ladder; a rejected call leaves the old ladder intact. Matching `entry_id`+play+hash with `retune:true` preserves guest state; identical params also preserve cache, changed params clear it pending successful retune. `src/shell/ladder.nim:297-365`; `src/shell/replacement.nim:32-63` |
| Re-upload/reconnect | A name is immutable per seat/episode; identical bytes are a no-op/refunded re-upload, changed code needs a new name. Limits: 16 modules/seat, 2 MiB, one upload/tick, two calls/tick, 16 ladder entries, two overlays. Disconnect leaves the server ladder running; recovery context permits reconnect without re-upload. `src/shell/compile_plane.nim:530-540`; `src/shell/types.nim:294-305`; `docs/designs/strategy-play-calling-shell-2026-08-29.md:560-598,813-836` |

## `target_law` vocabulary

| Tag | Score |
|---|---|
| `weakened` | `1 − knownHP/maxHP`; unknown HP scores 0. |
| `isolated` | 1 with no tracked same-team ally; otherwise nearest-ally distance divided by live weapon range, capped at 1. |
| `revenge` | 1 when this target is an identified aggressor from the last 120 ticks. |
| `bounty` | 1 only on a fresh track carrying the veteran marker. |

Tags are compared lexicographically in the supplied order; normal firefight score and target stickiness break later ties. `src/shell/body.nim:20-24,627-685,935-999`

`never` accepts `seat:0`…`seat:31` syntactically—only 0…15 are occupied here—or a configured `duo:red|blue|green|yellow|black|silver|ivory|pink`; sets must be sorted and unique. Season-2 pairings are `(0,8)…(7,15)`. `src/shell/call_validation.nim:159-191,276-292`; `coworld_manifest_paintbot.json:1129-1193`

`holdTrigger` is exactly `{aliveTeams:N}`, `{zonePhase:k}`, or `{tick:t}`. Before the threshold it sets hold-fire; at `aliveTeams≤N`, `zonePhase≥k`, or `tick≥t`, it releases permanently. Hold-fire still permits return fire against a recorded aggressor from the last 120 ticks. `play_sdk/reference/target_law.nim:62-102`; `src/shell/body.nim:880-885,953-978`

## Kill-relevant mechanics

| Mechanic | Effect |
|---|---|
| Base cog/gun | One life, 3 HP; 1300 px range; 5-tick windup and 12-tick cooldown. Each normal hit deals 1. A fully exposed body at maximum range is calibrated to 80% hit probability; the ray stops at the first exposed body or wall, with friendly fire. `coworld_manifest_paintbot.json:1195-1218`; `src/ctf/sim_types.nim:543-576`; `src/ctf/sim.nim:2581-2592,2611-2676,2831-2939` |
| Spray can | Auto-fire replaces the gun while carried. Shell acquisition range is 170 px; physics uses a 170 px cone plus 17 px target-body radius, 85 px maximum centreline width. It deals 3 damage to every victim in the cone once per activation, stays active 5 ticks, then resets for 20; friendly collateral is possible. `src/shell/body.nim:46-50,1080-1146`; `src/ctf/sim_types.nim:858-888`; `src/ctf/sim.nim:2302-2378,2431-2535` |
| Grenade | Auto-actuation has priority over gun/spray when carried and requires a target at least 90 px away. Physics throw range is 30 px to `MapWidth/5`, charged over 24 ticks, with a fixed 10-tick flight. Blast radius 52 px—58 to an on-axis body—deals 2 open-field, 6 in the landing trench, or 1 to another-trench occupants; it hits thrower and teammates too. `src/shell/body.nim:46-50,1092-1208`; `src/ctf/sim_types.nim:797-819,1322-1329`; `src/ctf/sim.nim:3083-3135,3223-3229,3270-3304` |
| Pickups/healing | Medkits restore base HP to full and respawn after 720 ticks. Shields add a 3-HP layer but triple gun cooldown until broken. Shields and spray cans respawn after 720 ticks; grenades after 120. `src/ctf/sim_types.nim:797-823,842-898`; `src/ctf/sim.nim:3511-3560,3660-3700` |
| Policy limits | No play parameter directly changes weapon range, damage, windup, or rate. Plays affect kills through positioning, target selection, fire holds, and pickup acquisition. `play_sdk/reference/*.nim` manifests above. `never` protects direct targets and blocks gun lanes/predicted grenade splash, but an area spray or unpredicted grenade can still collateral-hit allies. `src/shell/body.nim:700-760,1001-1031`; `src/ctf/sim.nim:2302-2350,3223-3229` |

## Ranked kill/win recommendations

These are source-derived tactical rankings, not measured A/B results. Examples use the red duo, seats 0 and 8; substitute the actual `duo:<team>`.

1. **Best balance: scatter → asymmetric third-party/escort → crossfire endgame.**

   Opening, both seats; explicitly re-call around 150 ticks because `scatter` cannot truly yield:

   `{"plays":[{"params":{"never":["duo:red"],"prefer":["weakened","isolated"]},"play":"target_law"},{"params":{"distance":320,"ticks":150},"play":"scatter"}]}`

   Midgame hunter, seat 0:

   `{"plays":[{"params":{"never":["duo:red"],"prefer":["weakened","isolated"]},"play":"target_law"},{"params":{"earshot":600,"exitAfter":{"hpFloor":2},"joinWhen":"afterKill"},"play":"jackal"}]}`

   Midgame escort, seat 8; omit `ward` so the configured mate is used:

   `{"plays":[{"params":{"never":["duo:red"],"prefer":["weakened","isolated"]},"play":"target_law"},{"params":{"interpose":true,"leash":[80,220],"peelHp":2},"play":"bodyguard"}]}`

   Before each shrink, temporarily re-call both with `edge_ride` (`enterLead:180`), then restore hunter/escort after entering the next rectangle. At two duos, switch both to `crossfire` `[120,260]`, angle 32. This combines spawn separation, opportunistic fights, mate preservation, proactive rotation, and safe final firing geometry. `play_sdk/reference/scatter.nim:3-13`; `jackal.nim:102-143`; `bodyguard.nim:87-119`; `edge_ride.nim:85-104`; `crossfire.nim:151-180`

2. **Win-first, lower kill opportunity: symmetric edge control.**

   `{"plays":[{"params":{"never":["duo:red"],"prefer":["weakened","isolated"]},"play":"target_law"},{"params":{"coverBias":0.5,"enterLead":180,"margin":140},"play":"edge_ride"}]}`

   This avoids controller switching and rotates earlier than the 72-tick emergency reflex, but it does not actively pursue fights. `play_sdk/reference/edge_ride.nim:85-120`; `src/shell/reflexes.nim:20-24,636-642`

3. **Kill-first, highest elimination risk: dual wide-earshot jackal.**

   `{"plays":[{"params":{"never":["duo:red"],"prefer":["weakened","isolated"]},"play":"target_law"},{"params":{"earshot":900,"exitAfter":{"kills":2},"joinWhen":"afterKill"},"play":"jackal"}]}`

   Run only after the opening scatter and explicitly re-call to `edge_ride` before shrinks. The large earshot finds more post-kill third parties, while the two-kill exit keeps the duo engaged longer; it is less compatible with the “still winning” constraint. `play_sdk/reference/jackal.nim:17-19,102-143`

For recovery, re-call `supply_run` only when already wounded and a known kit is within 500 px; for weapons, re-call `loot` only when the desired grenade/spray is the nearest safe item, then immediately restore the combat ladder. With zero-valued guards, leaving either fetcher above another controller can strand movement on hold or cached navigation. `play_sdk/reference/supply_run.nim:48-86,136-155`; `play_sdk/reference/loot.nim:50-90,128-150`; `src/shell/ladder.nim:609-631`

