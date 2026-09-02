# Source-verified constraints

The current champion has two hidden movement shadows:

- Unguarded `edge_ride` always wins controller selection, so the later `jackal` never controls movement. All passing overlays still fold, but only the first passing controller runs (`src/shell/ladder.nim:591-645`).
- The checked-in `spread_out` does **not** yield after arrival: it emits and caches a hold. Every design below therefore removes it with a shared recall at tick 160 or 180 (`bot/plays/spread_out.nim:215-264`; `src/shell/ladder.nim:615-631`).

Guards use live fogged state. Every distance test first excludes sentinel `-1`; “no nearby enemy” explicitly accepts either `-1` or a sufficiently large distance (`src/shell/episode.nim:507-576`).

All recalls shown apply identically to both seats.

## 1. Longshot ambush — best win/Glory balance

```json
LOWER={"plays":[{"play":"pact","params":{"partners":["$PARTNER"],"holdFire":{"tick":10000},"protect":true,"onBetrayal":"disengage"}},{"play":"target_law","params":{"never":["$PARTNER"],"prefer":["weakened","isolated","bounty"]}},{"play":"edge_ride","params":{"margin":140,"enterLead":120,"coverBias":0.6}}]}
UPPER={"plays":[{"play":"spread_out","params":{"distance":180,"bearing_brads":0}},{"play":"pact","params":{"partners":["$PARTNER"],"holdFire":{"tick":10000},"protect":true,"onBetrayal":"disengage"}},{"play":"target_law","params":{"never":["$PARTNER"],"prefer":["weakened","isolated","bounty"]}},{"play":"edge_ride","params":{"margin":140,"enterLead":120,"coverBias":0.6}}]}
S2_RECALLS=[{"at_tick":160,"call":{"plays":[{"play":"pact","params":{"partners":["$PARTNER"],"holdFire":{"tick":10000},"protect":true,"onBetrayal":"disengage"}},{"play":"target_law","params":{"never":["$PARTNER"],"prefer":["weakened","isolated","bounty"]}},{"play":"supply_run","params":{"whenHpBelow":3,"detourMax":420,"contested":"avoid"},"when":["and",["get","world.in_zone"],["<",["get","self.hp_frac"],0.67],[">=",["get","world.medkit_dist"],0],["<=",["get","world.medkit_dist"],420],["or",["==",["get","world.nearest_enemy_dist"],-1],[">",["get","world.nearest_enemy_dist"],650]]]},{"play":"jackal","params":{"earshot":900,"exitAfter":{"hpFloor":2},"joinWhen":"bothWeakened"},"when":["and",["get","world.in_zone"],["get","partner.alive"],[">=",["get","partner.dist"],0],["<=",["get","partner.dist"],450],[">=",["get","self.hp_frac"],0.66],[">=",["get","world.nearest_enemy_dist"],0],["<=",["get","world.nearest_enemy_dist"],900]]},{"play":"edge_ride","params":{"margin":140,"enterLead":120,"coverBias":0.6}}]}}]
```

Why: `bothWeakened` backs toward its 900-px earshot ring until at least two known-HP enemies are all at 1 HP, then joins them—placing ordinary shots above the supplied 866-px longshot threshold while preserving a late double-finisher opportunity (`play_sdk/reference/jackal.nim:122-143`). Both seats use identical target ordering; `weakened` is lexicographically decisive (`src/shell/body.nim:627-685,935-999`).

No stall: jackal emits an explicit hold when it cannot move, so it remains a firing platform; `edge_ride` is the terminal navigation/hold fallback (`play_sdk/reference/jackal.nim:153-162,197-218`; `play_sdk/reference/edge_ride.nim:85-120`). Supply can only preempt with a visible nearby kit and no plausible contest.

Main risk: the “all known enemies weak” condition is strict; extra healthy tracks make jackal remain at standoff instead of converting the cluster.

## 2. Four-kill heat ride — highest chaining pressure

```json
LOWER={"plays":[{"play":"pact","params":{"partners":["$PARTNER"],"holdFire":{"tick":10000},"protect":true,"onBetrayal":"disengage"}},{"play":"target_law","params":{"never":["$PARTNER"],"prefer":["weakened","isolated","bounty"]}},{"play":"edge_ride","params":{"margin":160,"enterLead":180,"coverBias":0.7}}]}
UPPER={"plays":[{"play":"spread_out","params":{"distance":180,"bearing_brads":0}},{"play":"pact","params":{"partners":["$PARTNER"],"holdFire":{"tick":10000},"protect":true,"onBetrayal":"disengage"}},{"play":"target_law","params":{"never":["$PARTNER"],"prefer":["weakened","isolated","bounty"]}},{"play":"edge_ride","params":{"margin":160,"enterLead":180,"coverBias":0.7}}]}
S2_RECALLS=[{"at_tick":160,"call":{"plays":[{"play":"pact","params":{"partners":["$PARTNER"],"holdFire":{"tick":10000},"protect":true,"onBetrayal":"disengage"}},{"play":"target_law","params":{"never":["$PARTNER"],"prefer":["weakened","isolated","bounty"]}},{"play":"supply_run","params":{"whenHpBelow":2,"detourMax":320,"contested":"avoid"},"when":["and",["get","world.in_zone"],["<",["get","self.hp_frac"],0.34],[">=",["get","world.medkit_dist"],0],["<=",["get","world.medkit_dist"],320],["or",["==",["get","world.nearest_enemy_dist"],-1],[">",["get","world.nearest_enemy_dist"],650]]]},{"play":"jackal","params":{"earshot":1100,"exitAfter":{"kills":4},"joinWhen":"afterKill"},"when":["and",["get","world.in_zone"],["get","partner.alive"],[">=",["get","partner.dist"],0],["<=",["get","partner.dist"],520],[">=",["get","self.hp_frac"],0.66],[">=",["get","world.nearest_enemy_dist"],0],["<=",["get","world.nearest_enemy_dist"],1100]]},{"play":"edge_ride","params":{"margin":160,"enterLead":180,"coverBias":0.7}}]}}]
```

Why: after any public kill, both controllers pursue their freshest in-earshot track; each counts the duo’s team kill rows and stays engaged until four have landed, directly matching the x2 heat band and carrying momentum toward kills five and six (`play_sdk/reference/jackal.nim:3-19,102-129`).

No stall: before a public kill, jackal explicitly holds but auto-fire remains armed by the overlays; after the guard closes, edge immediately owns movement. Native hazard/zone reflexes still preempt guest movement (`src/shell/ladder.nim:597-645`).

Main risk: the 1100-px chase may follow stale or unrelated public-kill activity and pull both cogs into a fresh duo.

## 3. One-cog weapon pickup, then clustered conversion

```json
LOWER={"plays":[{"play":"pact","params":{"partners":["$PARTNER"],"holdFire":{"tick":10000},"protect":true,"onBetrayal":"disengage"}},{"play":"target_law","params":{"never":["$PARTNER"],"prefer":["weakened","isolated"]}},{"play":"loot","params":{"detourMax":260,"contested":"avoid","medkits":false},"when":["and",["get","world.in_zone"],["get","partner.alive"],[">=",["get","partner.dist"],0],["<=",["get","partner.dist"],450],[">=",["get","world.item_dist"],0],["<=",["get","world.item_dist"],260],["or",["==",["get","world.nearest_enemy_dist"],-1],[">",["get","world.nearest_enemy_dist"],650]]]},{"play":"edge_ride","params":{"margin":140,"enterLead":120,"coverBias":0.6}}]}
UPPER={"plays":[{"play":"spread_out","params":{"distance":180,"bearing_brads":0}},{"play":"pact","params":{"partners":["$PARTNER"],"holdFire":{"tick":10000},"protect":true,"onBetrayal":"disengage"}},{"play":"target_law","params":{"never":["$PARTNER"],"prefer":["weakened","isolated"]}},{"play":"edge_ride","params":{"margin":140,"enterLead":120,"coverBias":0.6}}]}
S2_RECALLS=[{"at_tick":180,"call":{"plays":[{"play":"pact","params":{"partners":["$PARTNER"],"holdFire":{"tick":10000},"protect":true,"onBetrayal":"disengage"}},{"play":"target_law","params":{"never":["$PARTNER"],"prefer":["weakened","isolated"]}},{"play":"jackal","params":{"earshot":800,"exitAfter":{"kills":4},"joinWhen":"afterKill"},"when":["and",["get","world.in_zone"],["get","partner.alive"],[">=",["get","partner.dist"],0],["<=",["get","partner.dist"],450],[">=",["get","self.hp_frac"],0.66],[">=",["get","world.nearest_enemy_dist"],0],["<=",["get","world.nearest_enemy_dist"],800]]},{"play":"edge_ride","params":{"margin":140,"enterLead":120,"coverBias":0.6}}]}}]
```

Why: only the lower seat detours, while the upper separates. A carried grenade automatically takes weapon priority; spray replaces normal gun actuation, creating the only library-supported path to same-activation Splash kills (`src/shell/body.nim:1117-1208`). The subsequent tighter jackal keeps the armed cog and partner on one cluster.

No stall: `loot` is silent if no candidate. With no cached intent the ladder uses native default—not the lower `edge_ride`; after it has emitted navigation, that cache persists until the guard closes (`play_sdk/reference/loot.nim:128-150`; `src/shell/ladder.nim:615-631`). The item-distance and enemy-distance guard closely matches its usable-candidate test.

Main risk: `loot` cannot select item kind; the lower seat may spend the opening on a shield or barrier rather than grenade/spray.

## 4. Survive first, burst from tick 1000

```json
LOWER={"plays":[{"play":"pact","params":{"partners":["$PARTNER"],"holdFire":{"tick":10000},"protect":true,"onBetrayal":"disengage"}},{"play":"target_law","params":{"holdTrigger":{"tick":1000},"never":["$PARTNER"],"prefer":["weakened","isolated"]}},{"play":"edge_ride","params":{"margin":438,"enterLead":378,"coverBias":0.8}}]}
UPPER={"plays":[{"play":"spread_out","params":{"distance":180,"bearing_brads":0}},{"play":"pact","params":{"partners":["$PARTNER"],"holdFire":{"tick":10000},"protect":true,"onBetrayal":"disengage"}},{"play":"target_law","params":{"holdTrigger":{"tick":1000},"never":["$PARTNER"],"prefer":["weakened","isolated"]}},{"play":"edge_ride","params":{"margin":438,"enterLead":378,"coverBias":0.8}}]}
S2_RECALLS=[{"at_tick":160,"call":{"plays":[{"play":"pact","params":{"partners":["$PARTNER"],"holdFire":{"tick":10000},"protect":true,"onBetrayal":"disengage"}},{"play":"target_law","params":{"holdTrigger":{"tick":1000},"never":["$PARTNER"],"prefer":["weakened","isolated"]}},{"play":"edge_ride","params":{"margin":438,"enterLead":378,"coverBias":0.8}}]}},{"at_tick":1000,"call":{"plays":[{"play":"pact","params":{"partners":["$PARTNER"],"holdFire":{"tick":10000},"protect":true,"onBetrayal":"disengage"}},{"play":"target_law","params":{"never":["$PARTNER"],"prefer":["weakened","isolated","bounty"]}},{"play":"supply_run","params":{"whenHpBelow":3,"detourMax":420,"contested":"avoid"},"when":["and",["get","world.in_zone"],["<",["get","self.hp_frac"],0.67],[">=",["get","world.medkit_dist"],0],["<=",["get","world.medkit_dist"],420],["or",["==",["get","world.nearest_enemy_dist"],-1],[">",["get","world.nearest_enemy_dist"],650]]]},{"play":"jackal","params":{"earshot":900,"exitAfter":{"kills":4},"joinWhen":"afterKill"},"when":["and",["get","world.in_zone"],["get","partner.alive"],[">=",["get","partner.dist"],0],["<=",["get","partner.dist"],500],[">=",["get","self.hp_frac"],0.66],[">=",["get","world.nearest_enemy_dist"],0],["<=",["get","world.nearest_enemy_dist"],900]]},{"play":"edge_ride","params":{"margin":180,"enterLead":180,"coverBias":0.8}}]}}]
```

Why: `holdTrigger` blocks initiating fire but still allows return fire; release is permanent at tick 1000 (`play_sdk/reference/target_law.nim:62-102`; `src/shell/body.nim:953-978`). Deep-margin early rotation protects the win condition, then both seats switch atomically to the four-kill chase.

No stall: before tick 1000 edge owns movement; afterward guarded supply/jackal precede a total edge fallback.

Main risk: holding initiation compresses the six-kill window and may surrender First Blood or uncontested wounded enemies.

## 5. Partner-triggered Ace raid, then wounded endgame harvest

```json
LOWER={"plays":[{"play":"pact","params":{"partners":["$PARTNER"],"holdFire":{"tick":10000},"protect":true,"onBetrayal":"disengage"}},{"play":"target_law","params":{"never":["$PARTNER"],"prefer":["bounty","weakened","isolated","revenge"]}},{"play":"edge_ride","params":{"margin":160,"enterLead":180,"coverBias":0.7}}]}
UPPER={"plays":[{"play":"spread_out","params":{"distance":180,"bearing_brads":0}},{"play":"pact","params":{"partners":["$PARTNER"],"holdFire":{"tick":10000},"protect":true,"onBetrayal":"disengage"}},{"play":"target_law","params":{"never":["$PARTNER"],"prefer":["bounty","weakened","isolated","revenge"]}},{"play":"edge_ride","params":{"margin":160,"enterLead":180,"coverBias":0.7}}]}
S2_RECALLS=[{"at_tick":160,"call":{"plays":[{"play":"pact","params":{"partners":["$PARTNER"],"holdFire":{"tick":10000},"protect":true,"onBetrayal":"disengage"}},{"play":"target_law","params":{"never":["$PARTNER"],"prefer":["bounty","weakened","isolated","revenge"]}},{"play":"jackal","params":{"earshot":1200,"exitAfter":{"hpFloor":1},"joinWhen":"afterKill"},"when":["and",["get","world.in_zone"],["get","partner.alive"],[">=",["get","partner.dist"],0],["<=",["get","partner.dist"],600],[">=",["get","self.hp_frac"],0.33],[">=",["get","world.nearest_enemy_dist"],0],["<=",["get","world.nearest_enemy_dist"],1200],["or",["get","partner.in_combat"],["and",[">=",["get","world.weakest_enemy_hp"],0],["<=",["get","world.weakest_enemy_hp"],1]]]]},{"play":"edge_ride","params":{"margin":160,"enterLead":180,"coverBias":0.7}}]}},{"at_tick":1800,"call":{"plays":[{"play":"pact","params":{"partners":["$PARTNER"],"holdFire":{"tick":10000},"protect":true,"onBetrayal":"disengage"}},{"play":"target_law","params":{"never":["$PARTNER"],"prefer":["bounty","weakened","isolated","revenge"]}},{"play":"jackal","params":{"earshot":1000,"exitAfter":{"kills":4},"joinWhen":"bothWeakened"},"when":["and",["get","world.in_zone"],[">=",["get","self.hp_frac"],0.33],[">=",["get","world.nearest_enemy_dist"],0],["<=",["get","world.nearest_enemy_dist"],1000]]},{"play":"edge_ride","params":{"margin":140,"enterLead":180,"coverBias":0.6}}]}}]
```

Why: the first phase activates when the mate is already within 200 px of an enemy or a known 1-HP target exists, making one cog reinforce the other’s cluster (`src/shell/episode.nim:523-538`). `bounty` is a fresh veteran-marker preference; weakened targets follow (`src/shell/body.nim:627-685`). At tick 1800 the partner requirement is removed so a surviving solo can still harvest weakened endgame cogs.

No stall: all distance sentinels are excluded. Jackal’s inactive decision is an explicit hold with live auto-fire; edge resumes whenever the guard closes.

Main risk: bounty-first can redirect the partners toward different fresh veteran tracks, and the solo-capable final recall can split a still-living duo.

## Parameter and play-surface audit

Every value is manifest-valid: `spread_out` distance 180 ∈ 40–600 and bearing 0 ∈ 0–255 (`bot/plays/spread_out.nim:5-7`); pact has one partner, legal `tick`, Boolean protection and `disengage` (`play_sdk/reference/pact.nim:9-11`); target lists contain 1 unique protected ref and 2–4 valid tags (`play_sdk/reference/target_law.nim:14-16`). Edge values are within margin 40–600, lead 0–600 and bias 0–1 (`play_sdk/reference/edge_ride.nim:10-13`). Jackal earshots 800–1200, kill exit 4, HP exits 1–2 and both join modes are accepted (`play_sdk/reference/jackal.nim:15-19`). Supply and loot detours/thresholds/modes are inside their manifests (`play_sdk/reference/supply_run.nim:16-19`; `play_sdk/reference/loot.nim:19-22`).

I deliberately excluded `bodyguard` and `crossfire`: their controllers must find the partner in ordinary play tracks and explicitly hold when it has never appeared, while `partner.*` guards come from a separate partner grant (`play_sdk/reference/bodyguard.nim:59-100`; `play_sdk/reference/crossfire.nim:63-162`; `src/shell/episode.nim:507-576`). That creates exactly the pass-but-hold trap to avoid. No exposed guard or controller identifies anchor ownership, so enemy-ground scoring cannot be selected directly; following public-kill clusters is the available proxy.

These are source-derived, unmeasured proposals. No files were modified and no engine, simulator, build, or policy was executed.

Codex session ID: 01a06412-dcb1-75d0-abfd-43441cd036f9
Resume in Codex: codex resume 01a06412-dcb1-75d0-abfd-43441cd036f9
