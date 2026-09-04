# Policy-designer changelog: `11b1f1c..9f17087`

Bottom line: **yes—`battle-royale-s2` now spawns every seat without a marker or hopper, and both are required to fire.** An `11b1f1c`-built `loot.wasm` accepts the new frame structurally but decodes item IDs 5/6 as `sikUnknown`, which `loot` refuses to pursue. That is a mechanically sufficient explanation for zero damage unless the seat happens to walk over both crates accidentally. `coworld_manifest_paintbot.json:1286-1313`, `src/ctf/sim.nim:1654-1659`, `11b1f1c:play_sdk/play.nim:912-921`, `play_sdk/reference/loot.nim:50-58`

The requested `git log` and `git diff --stat` were checked; the range contains 67 commits and 93 changed files.

## 1. ARMING / LOADOUT

| Question | Current `battle-royale-s2` behavior |
|---|---|
| Spawn armed? | **No.** With `lootStart:true`, both `hasGun` and `hasHopper` initialize false. Without that flag, both initialize true. `src/ctf/sim.nim:1654-1659`, `coworld_manifest_paintbot.json:1310-1313` |
| What is required to shoot? | A living, upright seat needs **both** the marker crate (`hasGun`) and hopper crate (`hasHopper`), must not be carrying a spray can, and must have completed cooldown. `src/ctf/sim.nim:2891-2902` |
| How are crates picked up? | Pure walk-over collision: every tick the engine checks player-centre distance, takes the first present crate within **12 px**, and sets the corresponding boolean. No play intent, interact intent, or explicit pickup action exists. `src/ctf/sim.nim:4076-4097`, `src/ctf/sim.nim:4234-4271`, `src/ctf/sim.nim:7499-7509`, `src/ctf/sim_types.nim:822-832` |
| Are both acquired by one touch? | Normally no: marker and hopper sites are deliberately offset by 24 px, twice the touch radius. `src/ctf/sim_types.nim:843-849`, `src/ctf/sim.nim:1351-1361` |
| Base placement | Authored `weaponSpawns`/`hopperSpawns` win; otherwise markers use grenade sites and hoppers use medkit/retreat sites, with 75% of fallback hoppers re-sited toward traffic sites. `src/ctf/sim.nim:1256-1265`, `src/ctf/sim.nim:1287-1317`, `src/ctf/sim.nim:1334-1368` |
| Respawn/reload | Marker and hopper crates are one-shot and never refill. `src/ctf/sim.nim:1266-1270`, `src/ctf/sim_types.nim:4050-4054` |
| Ammo quantity/capacity | There is **no numeric ammunition or hopper capacity**: hopper possession is one boolean. Firing sets a cooldown and increments shot counters but never decrements ammunition. Thus ammo cannot “run out”; firing remains unlimited while both booleans remain true. `src/ctf/sim_types.nim:3027-3031`, `src/ctf/sim.nim:3323-3350` |
| Shot timing | The variant has a 5-tick windup and 12-tick cooldown—not an ammo reload. `coworld_manifest_paintbot.json:1292-1306` |
| Losing equipment | Downing preserves the two flags, but final death/splat/bleed-out clears both. A HANDOFF also removes the transferred half from the giver. `src/ctf/sim.nim:2669-2680`, `src/ctf/sim.nim:7357-7363` |

Spawn seeding is live:

| Parameter | Value | Effect |
|---|---:|---|
| `lootSpawnSeedGuns` | 3 | Three extra marker crates per duo spawn cluster. `coworld_manifest_paintbot.json:1360-1362` |
| `lootSpawnSeedHoppers` | 3 | Three extra hopper crates per duo spawn cluster. `coworld_manifest_paintbot.json:1360-1362` |
| `lootSpawnSeedRadius` | 48 px | Crates are ring-placed around each team/duo anchor and moved to the nearest walkable cell. `src/ctf/sim.nim:1178-1200`, `src/ctf/sim.nim:1220-1254` |

These seeds encourage accidental acquisition but do not guarantee it: pickup remains 12 px while crates may be 48 px from the shared anchor. `src/ctf/sim_types.nim:832`, `src/ctf/sim.nim:1197-1200`

## 2. Reference plays and starter ladders

| Play | Can acquire marker/hopper? |
|---|---|
| Current `loot` | **Yes.** It accepts every known non-medkit item, chooses the nearest within `detourMax`, and navigates to it. `play_sdk/reference/loot.nim:50-90`, `play_sdk/reference/loot.nim:128-151` |
| `supply_run` | **No.** It activates only while wounded and filters strictly for `sikMedkit`. `play_sdk/reference/supply_run.nim:48-55`, `play_sdk/reference/supply_run.nim:76-87` |
| Old `11b1f1c` `loot` | **No deliberate acquisition.** IDs 5/6 decode as unknown, and unknown items fail `itemUsable`. `11b1f1c:play_sdk/play.nim:912-921`, `11b1f1c:play_sdk/reference/loot.nim:50-58` |

The starter `policy.py` files themselves are byte-identical across this range. Fresh starter images nevertheless compile every reference play against the current SDK, so their existing generic `loot` rung now understands marker/hopper crates. `policies/starters/common/build_playbook.sh:38-48`, `policies/starters/aggressive/policy.py:52-55`, `policies/starters/cautious/policy.py:83-91`, `policies/starters/collaborative/policy.py:61-68`

Ignoring clone-only overlays, their effective first-turn ladders are:

| Starter | During spawn phase | After spawn, when the loot gate opens | Later canned ladder |
|---|---|---|---|
| Aggressive | `["scatter", {"edge_ride":{"margin":200,"enterLead":140,"coverBias":0.5}}]` | `[{"loot":{"detourMax":500,"contested":"race"}}, "edge_ride"]` | `["edge_ride","target_law"]`, then `["jackal","edge_ride"]`. `policies/starters/aggressive/policy.py:88-125` |
| Cautious | `[{"target_law":{"holdTrigger":{"zonePhase":1}}},"scatter",{"edge_ride":{"margin":420,"enterLead":320,"coverBias":1.0}}]` | `["target_law",{"loot":{"detourMax":300,"contested":"avoid"}},"edge_ride"]` | `[{"supply_run":{"whenHpBelow":5,"detourMax":900,"contested":"avoid"}},"edge_ride"]`. `policies/starters/cautious/policy.py:120-147` |
| Collaborative | `["pact","target_law","scatter","edge_ride"]` with actual partner injected | `["pact","target_law",{"loot":{"detourMax":400,"contested":"avoid"}},"edge_ride"]` | `["pact","bodyguard","crossfire"]`. `policies/starters/collaborative/policy.py:110-145` |

The harness deliberately removes `loot` and every other gated controller during the opening scatter phase; afterwards `loot` is present only when an item is within range and no fresh enemy is within 500 px. In a dense lobby this can still leave a seat unarmed. `policies/starters/common/starter_harness.py:621-627`, `policies/starters/common/starter_harness.py:643-695`, `policies/starters/common/starter_harness.py:827-855`

## 3. SDK / ABI compatibility

| Change | Effect on an `11b1f1c` module |
|---|---|
| Module ABI | ABI remains **1**, with the same required exports/import signatures. A previously valid module is not rejected merely for being old. `src/shell/types.nim:346-352`, `src/shell/module_interface.nim:189-248`, `src/shell/manifest.nim:312-325`, `src/shell/module_validation.nim:26-72` |
| Binary frame | `PV1`, version 1, and self/track/item strides remain 32/32/24 bytes. New state occupies reserved flag bits, explicitly intended for old readers to ignore. `src/shell/binary_view.nim:28-84`, `src/shell/binary_view.nim:430-449` |
| Downed state | New `SelfDownedFlag` and `TrackDownedFlag`; old modules remain valid but treat downed seats as ordinary alive seats. `play_sdk/play.nim:70-83`, `play_sdk/play.nim:397-405`, `play_sdk/play.nim:953-967` |
| Item kinds | Gun and hopper were appended as IDs 5 and 6. An old SDK maps both to `sikUnknown`, so old reference `loot` is accepted but blind. `play_sdk/play.nim:139-149`, `play_sdk/play.nim:934-945`, `11b1f1c:play_sdk/play.nim:912-921` |
| Loadout perception | Replay/spectator frames expose every seat’s booleans, but a play receives them only on its **duo partner’s track**, never enemy tracks. `coworld_manifest_paintbot.json:741-744`, `src/ctf/server.nim:3644-3663`, `src/shell/view.nim:1032-1048` |
| Own loadout | Even the current guest `SdkSelf` has no `hasGun`/`hasHopper`; its self record contains position, HP, aim, alive and downed only. A play must infer its own pickups or maintain state. `play_sdk/play.nim:70-83`, `src/shell/view.nim:332-346` |
| HANDOFF | Optional intent field with closed vocabulary `"gun"`, `"hopper"`, `"bandage"`; the target is always the duo partner. Old modules remain valid but cannot request transfers. Invalid vocabulary or use outside BR rejects the emission, not the uploaded module. `src/shell/types.nim:96-105`, `play_sdk/play.nim:2072-2111`, `src/shell/emit_validator.nim:228-237` |
| HANDOFF execution | A standing declaration plus 40 px adjacency held for 48 ticks transfers one binary marker/hopper flag. Proximity alone does nothing. `src/ctf/sim_types.nim:856-862`, `src/ctf/sim_types.nim:883-888`, `src/ctf/sim.nim:7271-7318`, `src/ctf/sim.nim:7332-7369` |
| Outer `0xB1` JSON | New optional `downed`, item kinds, and partner `has_gun`/`has_hopper` fields are additive. A tolerant old client works; a client-side strict JSON schema may fail even though the engine accepts its wasm. `src/shell/view.nim:332-389`, `src/ctf/server.nim:1794-1803` |

## 4. GLORY / scoring

The authoritative final switchboard is:

| Flag | Current value |
|---|---:|
| `gloryMultiplierRecut` | `true` |
| `winAsMultiplier` | `false` |
| `deedMintCaps` | `false` |
| `zoneDamageByPaint` / `zoneBlocksRevive` | `true` / `true` |

`coworld_manifest_paintbot.json:1357-1367`

| Range change | Current consequence |
|---|---|
| Every team reports Glory | `results.scores[seat]` now receives that seat’s own team ledger after GameOver, regardless of win; `win[]` remains separate. `src/ctf/roster.nim:898-921`, `src/ctf/roster.nim:1006-1027` |
| ×4 win experiment | `winAsMultiplier` introduced a deterministic, composition-neutral BR ×4, retired `dVictory`, added `dTagBack`/`dJointAct` ×2, and raised `dClosingTime` 2→3. `src/ctf/glory.nim:2367-2383`, `src/ctf/glory.nim:2665-2682` |
| Rollback | The flagship flag is now false after the revive-loop incident produced 24–27 tag-backs and roughly `9.15e15`. Current wins therefore use the older `dVictory` deed again, not flat ×4. `src/ctf/glory.nim:2413-2418`, `coworld_manifest_paintbot.json:1365-1367`, `src/ctf/sim.nim:5150-5183` |
| `dTagBack` | When enabled, one completed revive mints ×2 for the reviving tagger. It is currently score-dark because `winAsMultiplier:false`. `src/ctf/sim.nim:7239-7255` |
| `dJointAct` | When enabled, damage by at least two distinct duos within a 120-tick victim incident mints once for every contributing seat. It too is currently dark. `src/ctf/sim.nim:2326-2386`, `src/ctf/sim.nim:2819-2842` |
| Mint caps | New optional per-duo episode caps are TagBack 3, JointAct 6, DuoDown 4 and ShieldSoak 3, plus a `2^26` product backstop. They are implemented but **not armed** on this variant. `src/ctf/glory.nim:2420-2434`, `src/ctf/glory.nim:2500-2538`, `src/ctf/sim.nim:245-274`, `coworld_manifest_paintbot.json:1367` |
| Painted zone | Zone damage now tests whether the player’s cell has been reached by the painted arrival surface, retaining the same DPS cadence and environment attribution. `src/ctf/sim.nim:5585-5644` |
| Paintdeath | A downed ghost on painted ground bleeds twice as fast, cannot accrue revive progress, and loses previously banked progress; this blocks the exploit’s revive-under-zone loop. `src/ctf/sim.nim:7150-7189`, `src/ctf/sim.nim:7191-7211` |

`results.scores` now has exactly **16 entries**, one per seat. Both members of a duo report the same team scalar, so the eight duo values appear twice; an episode that never reaches GameOver still reports zeroes. `src/ctf/roster.nim:866-896`, `src/ctf/roster.nim:1006-1026`, `src/ctf/sim_types.nim:3900-3904`, `coworld_manifest_paintbot.json:1220-1288`

Expect nonnegative integer scores ranging from 0/1 into the millions—not ±1 rewards and not winner-only values. The recut starts at 1, common kills are ×1, marquee deeds multiply the product, and friendly-fire divisions can floor it to zero. The code documents a current live design ceiling near **9,437,184** and a legitimate observed high of **3,375,440**. `src/ctf/sim.nim:688-705`, `src/ctf/glory.nim:2317-2324`, `src/ctf/glory.nim:2341-2383`, `src/ctf/glory.nim:2420-2425`, `src/ctf/glory.nim:2654-2663`

## 5. Guards, ladder, reflexes, and play-seat protocol

| Area | Changelog / current meaning |
|---|---|
| Guards | No range edit to the guard engine. Live seats already evaluate guards against fogged HP, partner, enemy, zone and item facts. Gun/hopper now enter the undifferentiated `world.item_dist` bucket, but there is no `self.has_gun`, `self.has_hopper`, or typed item guard path. `src/shell/episode.nim:540-609`, `src/ctf/policy_page.nim:175-190` |
| Ladder | No semantic change: overlays fold first; the first live controller whose guard passes wins. A new accepted call replaces the ladder and increments its epoch; identical entries can retain state. `src/shell/ladder.nim:297-365`, `src/shell/ladder.nim:562-645` |
| Reflexes | Native grenade, spray and zone-escape reflexes remain above play controllers. The zone reflex and `world.in_zone` still use zone rectangles, while actual damage now uses painted cells—so the reflex can consider a position safe after the damaging surface reaches it. `src/shell/episode.nim:513-516`, `src/shell/episode.nim:583-608`, `src/shell/episode.nim:923-950`, `src/shell/reflexes.nim:636-685`, `src/ctf/sim.nim:5619-5624` |
| Socket protocol | Still protocol version 1: `A0` upload, `A1` call, `A2` status acknowledgement, `A3` lobby send; `B0` context, `B1` view, `B2` lobby broadcast. There is no recall opcode—“recall” means sending another `A1` ladder call. `src/shell/types.nim:230-264`, `src/shell/packets.nim:61-90` |
| Lobby | Still an open 600-tick window; chat is broadcast individually to every play seat and replayed before views after reconnect. `coworld_manifest_paintbot.json:1352-1355`, `src/shell/types.nim:248-264`, `src/ctf/server.nim:1701-1804` |
| New observability | Play faults now carry cause-first reasons and the server logs fault, navigation-budget and combat-path summaries; this changes diagnosis, not ladder selection. `src/shell/episode.nim:1174-1180`, `src/ctf/server.nim:5004-5023` |

## Prioritized policy changes

1. **Rebuild and re-upload every wasm play against current `play_sdk/play.nim`.** Replacing only the outer policy is insufficient: the old `loot.wasm` itself maps marker/hopper to unknown. `play_sdk/play.nim:139-149`, `play_sdk/play.nim:934-945`
2. **Put an arming controller above normal combat until both halves are inferred acquired.** Do not rely solely on spawn scatter or a “no enemy within 500 px” loot gate; an unarmed seat cannot win that nearby fight. `src/ctf/sim.nim:2891-2902`, `policies/starters/common/starter_harness.py:621-627`
3. **Route explicitly to both distinct kinds and confirm each touch statefully.** Self loadout is not exposed, and the two crates require separate 12 px walk-overs; record reaching a crate plus its subsequent disappearance rather than repeatedly fetching the nearest marker. `src/shell/view.nim:332-346`, `play_sdk/play.nim:139-155`, `src/ctf/sim_types.nim:832-849`
4. **Use partner flags and HANDOFF to repair asymmetric duos.** Transfer only a half the giver actually holds and the partner lacks; remember that doing so disarms the giver if it was their sole copy. `src/ctf/server.nim:3644-3663`, `src/ctf/sim.nim:7332-7363`
5. **Update the outer `0xB1` parser for `downed`, `gun`, `hopper`, `has_gun`, and `has_hopper`, tolerating unknown future fields.** `src/shell/view.nim:332-389`, `src/shell/view.nim:980-1052`
6. **Score for today’s flags:** prioritize survival/win and high-factor longshots, revenge/run-down, DuoDown, Last Light, wipe and current `dVictory`; do not farm TagBack/JointAct while their switch is off. `src/ctf/glory.nim:2341-2383`, `coworld_manifest_paintbot.json:1365-1367`
7. **Keep a conservative zone margin and rescue only on dry ground.** The built-in guard/reflex sees rectangles, not the now-authoritative painted damage surface. `src/shell/episode.nim:583-608`, `src/shell/episode.nim:923-950`, `src/ctf/sim.nim:7191-7211`

Codex session ID: 01a06e1e-4b98-7bb2-8563-599252f009fa
Resume in Codex: codex resume 01a06e1e-4b98-7bb2-8563-599252f009fa
