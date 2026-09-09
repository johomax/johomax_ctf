# v161 cap-conversion window, rounds 4630–4641

Date: 2026-09-09

## Verdict

`jordan-ctf-candidate:v161` produced **3 caps in 152 seats, or 0.237 caps per 12**. The same-round point estimates were daveey 0.636, daveey-1 0.564, and Aaron 0.553 per 12. The counts are sparse: every pairwise 95% interval for the cap-rate difference crosses zero. This window establishes an under-capping point estimate, not a measured causal regression.

The hosted results do not show a general combat collapse. v161 made 0.908 kills/seat, versus 0.880 for v160, and its zero-kill-death point estimate fell from 49.3% to 45.4%. The weaker number is conversion among seats that killed: **3/82 (3.7%)** capped under v161, versus **3/38 (7.9%)** under v160. That pattern is consistent with poor deed geometry or timing, but does not identify which of v161's two simultaneous changes caused it.

The `lane_warden` guard has a static design mismatch. While the external guard passes, the controller's low-HP `flee` and sub-866-px `retreat` paths cannot run; almost all live decisions must be `cover`, `hold_cover`, `hold`, or `margin`, with `approach` possible only in the 1,250–1,300-px sliver. Remembered, non-fresh tracks can also pass the external guard and make the controller hold or cover. This makes the lane more likely to be narrow/inert or to pre-empt useful movement than to finish a target. It is a plausible cause, not a measured one.

The single best next recipe is **[`v192-solo-jackal-above-loot.env`](s2_patches/recipes/v192-solo-jackal-above-loot.env)**: remove only `lane_warden`, keep jackal above loot, and change nothing else. **Do not revert all the way to the v160/v191 recipe yet.** A full v191 rollback would change both bundled variables and would not tell us whether the lane or the jackal/loot order mattered. v191 is the fallback if a comparable v192 window or restored traces show that `jackal:hold` is consuming the post-kill window.

## Evidence boundary

The hosted result artifacts are present for all 178 valid episodes in rounds 4630–4641. They provide policies, kills, score, outcome, and cap membership.

The replay evidence named in the task is not present in this checkout. Under `research/s2_replays`, the only matching path is an **empty** round-4630 directory; there are no 4630–4641 replay bodies and no per-round `report.json` files. The hosted artifacts contain replay URLs, but network access is disabled in this environment, so a temporary out-of-tree fetch also failed.

That absence matters. Hosted totals cannot reveal a kill tick, shooter-to-victim distance, primary Glory deed, First Blood, Closing Time, inter-kill gap, controller guard pass, or intent duration. Accordingly, none of those values is silently treated as zero:

| Requested v161 measure | Result from the available evidence |
|---|---|
| Seats on which the lane guard passed | **Unresolved** |
| Number and duration of lane bouts | **Unresolved** |
| Lane reasons and what followed them | **Unresolved** |
| Lane-associated kills or deaths | **Unresolved** |
| Any lane-associated kill at >=866 px | **Unresolved; not demonstrated, but not zero** |
| Longshot / First Blood / Closing-Time kills | **Unresolved / unresolved / unresolved** |
| First-kill tick distribution | **Unresolved** |
| Inter-kill gaps | **Unresolved** |
| Deaths with zero kills | **69/152 (45.4%)**, exact from hosted results |

The same limitation applies to current-window rival deed sequences, kill distances, first-kill ticks, and dynamic calls. A seat ending on one or two kills is compatible with a known cap route, but is not proof of that route.

## Exact hosted census

The four submitted versions remained fixed throughout this window.

| Entrant / policy | Seats | Kills | K/seat | 0K deaths | Wins | Caps | Caps/12 | 95% Wilson interval, caps/12 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Jordan / `jordan-ctf-candidate:v161` | 152 | 138 | 0.908 | 69 | 16 | 3 | **0.237** | 0.081–0.677 |
| daveey / `paintbot-huddle:v159` | 151 | 137 | 0.907 | 59 | 15 | 8 | **0.636** | 0.325–1.213 |
| daveey-1 / `paintbot-huddle:v160` | 149 | 101 | 0.678 | 83 | 11 | 7 | **0.564** | 0.275–1.126 |
| Aaron / `aaron-paintbot:v7` | 152 | 109 | 0.717 | 81 | 10 | 7 | **0.553** | 0.270–1.104 |

The paired overlap is similar: Jordan/daveey shared 128 episodes and capped 3/7; Jordan/daveey-1 shared 124 and capped 3/6; Jordan/Aaron shared 127 and capped 2/5. Newcombe 95% intervals for Jordan minus each rival, expressed as caps/12, are respectively `[-0.997, +0.140]`, `[-0.910, +0.199]`, and `[-0.889, +0.207]`. All are level under the repository's measurement rule.

Jordan's kill distribution was 0K: 70, 1K: 47, 2K: 23, 3K: 6, 4K: 3, 5K: 3. Of the 70 zero-kill seats, 69 died and one won. The three caps were:

| Round / episode / seat | Hosted total kills | Outcome | Deed route |
|---|---:|---|---|
| 4636 / `4ae2a48c` / s12 | 1 | loss | unresolved |
| 4637 / `90e44410` / s11 | 3 | loss | unresolved |
| 4641 / `b3937331` / s1 | 2 | loss | unresolved |

All three capped losses still reported 16,384. Total kills do not say whether the three-kill seat capped on kill one, two, or three.

Across the rivals, 19/22 caps (86.4%) ended with only one or two hosted kills:

| Entrant | Cap-seat total-kill distribution | Cap outcomes | Current-window route status |
|---|---|---|---|
| daveey | 1K: 2, 2K: 6 | 8 losses | all unresolved |
| daveey-1 | 1K: 3, 2K: 4 | 7 losses | all unresolved |
| Aaron | 1K: 2, 2K: 2, 3K: 3 | 6 losses, 1 win | all unresolved |

This is the same low-kill shape expected from Glory v17's efficient routes, but it cannot distinguish tag + heated First Blood + fast follow-up from longshot + Gun-V.

## Comparison with v160

The previous `jordan-ctf-candidate:v160`, using [`v191-solo-cap-hunter.env`](s2_patches/recipes/v191-solo-cap-hunter.env), had 75 seats in rounds 4623–4628:

| Metric | v160 | v161 |
|---|---:|---:|
| Caps/12 | 0.480 (3/75) | 0.237 (3/152) |
| Kills/seat | 0.880 | 0.908 |
| Zero-kill deaths | 37/75 (49.3%) | 69/152 (45.4%) |
| Wins | 9/75 (12.0%) | 16/152 (10.5%) |
| Cap conversion among killful seats | 3/38 (7.9%) | 3/82 (3.7%) |

The cap-rate point change is -0.243 per 12; its Newcombe 95% interval is `[-1.111, +0.298]` per 12. The windows were sequential, the fields were not held fixed, and the interval crosses zero. Therefore the correct experimental verdict is **level**, not “lane_warden cut caps in half.”

v161 also bundles two changes relative to v160: the t760 jackal moved above loot, and `lane_warden` was added. The hosted comparison cannot attribute their combined result to either one.

## Rival routes and ladders

There are no current-window call reports, so current call frequencies and cap-specific ladders are unresolved. The call reports that are present for the same version labels in rounds 4612–4613 give useful architecture references, not substitute measurements for rounds 4630–4641:

- `paintbot-huddle:v159` made 104 calls over 23 traced seats. Its recurring pieces were grenade-seeking race loot (`detourMax=400`), `scatter(320,340)`, a conservative `edge_ride` (usually margin 220, enter lead 160, cover bias 0.75), guarded supply, `target_law(weakened, isolated, bounty)`, and `jackal(earshot=900, afterKill, hpFloor=2)`. Its two verified caps were direct fast chains: tag + heated First Blood, then a tag 40 ticks later; and point-blank + heated First Blood, then a tag 19 ticks later.
- `paintbot-huddle:v160` made 121 calls over 24 traced seats. It added frequent `jackal(earshot=600, afterKill, hpFloor=2)` and `crossfire`, used aggressive grenade loot, and usually rode much tighter (margin 140, enter lead 80, cover bias 0.5). Its verified cap was an ordinary tag followed 45 ticks later by a 950-px heated longshot and the first Gun-V claim.
- `aaron-paintbot:v7` made 162 calls over 23 traced seats, almost entirely `target_law(prefer=[weakened, isolated]) > scatter(320,300) > edge_ride(margin=240, enterLead=260, coverBias=0.8)`. It had no custom longshot controller. No Aaron cap was trace-covered in those two rounds.

The rivals therefore do not share a special cap play. Their available reference traces show both known mechanisms: very fast close/mid-range follow-ups and an incidental >=866-px kill from reference-play movement. Aaron's current 7 caps despite a simple target/scatter/edge architecture is further evidence that `lane_warden` is not required, though the missing current traces prevent assigning Aaron's seven routes.

## What the v161 guards actually select

The ladder uses the first live controller whose guard passes; `target_law` is an overlay. At tick 760 the movement order is guarded supply, guarded lane, guarded jackal, guarded loot, edge. At tick 1500 it is guarded supply, guarded jackal, guarded lane, edge.

For `lane_warden`, `world.enemy_count == 1` means exactly one **remembered** enemy track, not exactly one enemy visible this tick; enemy/item tracks have about five seconds of memory. With the external guard active:

1. `self.hp_frac >= 0.5` means at least 2 HP on the four-HP body, so the internal `hp < hpFloor(2)` flee branch is unreachable.
2. Nearest distance must be 866–1,300 px. With exactly one track, its candidate cannot be closer than 866, so both internal retreat branches are unreachable.
3. A fresh candidate at 866–1,250 reaches the normal cover/hold path. Only 1,250–1,300 reaches `approach`.
4. A remembered but non-fresh candidate passes the ladder guard but fails the controller's freshness test, leaving margin/cover/hold behavior while pre-empting loot or edge movement.
5. When the target closes below 866, the lane immediately loses ownership. Jackal does not take over until <=700, leaving a 701–865-px handoff band to loot or edge rather than a finishing controller.

This guard is protective against gas and splash threats, but it also gates away the controller's own escape behavior and makes one stale track sufficient to own movement. The design can preserve longshot distance; it does not create a reliable kill by itself.

Putting jackal above loot has a different mechanism. In the t760 overlap where an item is within 250 px and an enemy is 501–700 px away, jackal now wins. After a fresh public kill-feed event it can issue `jackal:join`, which is aligned with the <=270-tick second-deed route. Before such an event, however, `joinWhen=afterKill` emits `jackal:hold`, so the same ordering can freeze a loot detour without producing a chase. Missing annotations prevent counting either path in this window.

## Causal answer and next recipe

The empirical answer is: **lane harm versus inertia is unresolved**. There is no trace evidence here that the guard ever passed or that a lane-owned shot killed at >=866 px. Static analysis leans toward “mostly narrow/inert, with a credible pre-emption failure mode,” not toward a working longshot generator. Stable kills and slightly fewer zero-kill deaths rule out a large general combat failure, but they do not rule out lost First Bloods or spoiled follow-ups in the small number of cap-eligible fights.

The jackal-above-loot effect is also unresolved because it was shipped in the same version. It has a route-aligned upside and a specific `jackal:hold` downside. Its mechanism is more direct than the lane's: it gives an after-kill join priority over a loot detour precisely where a second deed inside 270 ticks matters.

Therefore ship/test **v192** next:

```text
opening: target_law > supply_run(g) > loot(g) > edge_ride 420/320/1.0
t760:    target_law > supply_run(g) > jackal(g, <=700, afterKill) > loot(g) > edge_ride 240/80/0.5
t1500:   target_law > supply_run(g) > jackal(g, <=700, afterKill) > edge_ride 240/80/0.9
```

Mechanism: remove the stale-track-sensitive 866–1,300 standoff owner and its 701–865 handoff, while preserving the one change aimed directly at converting a first deed into a heated second deed. This is the clean one-variable rollback from v161.

**Explicit decision:** do **not** revert to v160/v191 for the next test. Test v192 first. Revert to v191 only if v192 remains level/down in a comparable hosted A/B or restored intent traces show material `jackal:hold` ownership without `jackal:join` and without a <=270-tick follow-up.

## Evidence needed to close the unresolved rows

Restore the 4630–4641 replay bodies, regenerate each `report.json`, then run `analysis/s2_replay_positions.py` and the matching `/private/tmp/engine-main-v44/tools/extract_events.nim`. The audit should join, per Jordan and rival seat: ladder guard truth, selected-entry intent intervals, kill ticks and positions, deed feed, and `GLORY_CAP_HIT`. That one joined table will answer guard-pass frequency, lane duration/outcome, longshot attribution, First Blood/Closing-Time counts, first-kill timing, and inter-kill gaps without inference from end-card totals.
