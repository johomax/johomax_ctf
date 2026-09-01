# Adversarial review of BR port v1 (b7b0bfc)

Read-only Codex review, 2026-09-01. Findings feed the v2 fix job; verify each against the tree before trusting a line number.

## Findings

1. **loses games — final-zone target is snapped outside the 3×1 safe rectangle.**  
   `bot/baseline/royale.nim:52-56` initially replaces the exact clamped pixel with `cellCenter(c0)`. In phase 5, almost every `[cx-1,cx+1] × [cy,cy]` rectangle contains no nav-cell centre or cover cell, so the bot parks outside and dies after 24 ticks.  
   **Fix:** initialize `result = wanted`; replace it only with a cover point proven inside the inset.

2. **loses games — zone-safe endpoints do not produce zone-safe paths, and failure becomes a beeline.**  
   `bot/baseline/royale.nim:90-95`, `bot/baseline/navgrid.nim:342-350`, `bot/baseline/navgrid.nim:470-489`. The cost field knows walls/exposure but not the current zone, so an obstacle detour can leave the lethal rectangle. If disconnected, line 489 drives directly through blocked cells.  
   **Fix:** exclude cells outside the current zone during urgent routing; on failure select the nearest reachable in-zone cell instead of returning `target - me`.

3. **loses games — enemy-on-enemy kills are interpreted as friendly casualties.**  
   `bot/baseline/sense.nim:158-177`. `theirKills` sums all 15 hostile teams. Most BR increments are one enemy duo killing another, yet each marks a sonar landing as hot friendly-death ground, poisoning exposure and routing.  
   **Fix:** retain previous scoreboard deaths and use only `sb.deaths[bot.colour]` deltas for friendly casualties.

4. **loses games — the bullet guard is unsafe across the five-tick windup.**  
   `bot/baseline/tactics.nim:219-235`. It tests a partner’s old position, ignores `Track.vel`, and unconditionally permits a partner beyond the intended target. If the target leaves the corridor before release, that partner becomes the nearest body. Late frames make this worse because the retained fire input can complete the windup without another check.  
   **Fix:** predict both bodies at release time; in BR, do not waive a partner beyond the target when it remains inside the 1300px shot corridor.

5. **loses games — fogged-partner grenade uncertainty is understated by roughly 6×.**  
   `bot/baseline/tactics.nim:30-36`, `bot/baseline/tuning.nim:384-385`. BR extends the veto to 400 ticks but grows uncertainty by only `0.45 px/tick`; tracks permit movement near `3 px/tick`. A partner can therefore occupy the landing circle while the throw is declared safe.  
   **Fix:** use a velocity/reachable-position capsule, or stop clearing throws from stale partner fixes beyond a short BR TTL.

6. **loses games — engagement rules alternate between helpless and indiscriminate.**  
   `bot/baseline/engage.nim:49-66`, `bot/baseline/engage.nim:107-117`. Before tick 700, gun range is exactly zero even against a point-blank attacker. A shielded anchor remains capped at 180px. After tick 1400, any fresh clear target within 900px qualifies; the “clean duel” code merely adjusts priority and does not enforce cover, 2v1, first-shot, or retreat advantage.  
   **Fix:** separate voluntary initiation from defensive/focus fire, then require an explicit advantage predicate for initiating BR fights.

7. **loses games — endgame always hunts the nearest possibly stale/dead track.**  
   `bot/baseline/royale.nim:164-184`, `bot/baseline/tuning.nim:290`. Once the trigger fires, a leading two-cog duo abandons cover and chases a track as old as 400 ticks. Tracks have no colour/death association, so the target may already be eliminated.  
   **Fix:** hunt only fresh, still-live-team tracks and only when trailing; leaders should hold two separated covered angles.

8. **cost — moving objectives and moving threats repeatedly clear an ~86k-cell field.**  
   `bot/baseline/navgrid.nim:374-387`, `bot/baseline/navgrid.nim:455-489`, `bot/baseline/royale.nim:92,105-107`. Each changed goal or exposure spot clears every `navDist` entry and starts another Dijkstra traversal. Urgent projections and rendezvous goals depend on the bot’s moving position; enemy tracks change cells frequently.  
   **Fix:** retain phase-stable waypoints, quantize goal changes, and rebuild only when the old route becomes invalid.

9. **cost — initial sonar calibration can perform about 1.5 million inner probes in one frame.**  
   `bot/baseline/perception.nim:133-165`, `bot/baseline/perception.nim:337-357`. The first ring tests 901 clock offsets, each searching up to a 41×41 box. Dense BR makes that likely during combat, exactly when a late decision is costly.  
   **Fix:** amortize candidates across frames or keep fuzzy sonar in BR until spare CPU is demonstrated.

10. **nit — a failed first sprites-off send can enter the connection-retry loop indefinitely.**  
    `bot/baseline.nim:168-171`, `bot/baseline.nim:200-207`. The websocket handshake may succeed and the send fail while `everConnected` is still false, causing repeated reconnect attempts instead of clean termination.  
    **Fix:** set `everConnected = true` immediately after `newWebSocket`. Sending sprites-off before the first receive is otherwise correctly ordered.

11. **nit — both members of every duo use the same legacy jink/weave phase.**  
    `bot/baseline/act.nim:124,237`. Partner slots differ by 16, so `slot div 2` differs by 8 and has identical parity. A stacked duo therefore sidesteps together and remains stacked.  
    **Fix:** on BR frames phase the movement by anchor/scout role or `slot div GameTeams`.

No crash/OOB was found in the audited paths: `Colour` has 16 entries, team count is clamped to that size, colour-indexed arrays expand with the enum, scoreboard parsing requires all 16 chips, and `slot div GameTeams` yields BR seats 0/1. I also found no current `GameTeams <= 4` classic-board leakage; the BR gates preserve the committed classic paths.

## Five highest-value missing changes

1. Pixel-exact, current-zone-constrained routing with stable phase waypoints and reachable fallbacks.
2. Shared target identity plus coordinated focus/pincer angles for the duo.
3. Advantage-gated combat with defensive-fire overrides and release-time corridor checks.
4. Leader/trailer-aware endgame behavior using fresh, team-identified survivor tracks.
5. Authored BR loot routing and weapon-specific tactics, including the actual 642px grenade range instead of `NadeMaxRange = 240` at `tuning.nim:359`.

