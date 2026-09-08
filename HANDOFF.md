# Handoff

State that lives outside the repo and would otherwise be lost. Everything with a
measurement behind it is in `research/LEDGER.md` and `research/state.json`; this
file is only the things a new machine cannot reconstruct.


### Ladder semantics (verified 2026-09-02 21:55Z, engine GV52)
- The FIRST live controller whose `when` guard passes owns movement (src/shell/ladder.nim:562-630). A live controller with no intent falls to the native default play; only a faulted controller advances to the next entry. Guards ARE evaluated on GV52 (paths self.hp_frac, partner.alive/dist/in_combat, world.enemy_count/in_zone/item_dist/medkit_dist/nearest_enemy_dist/weakest_enemy_hp/zone_dist; ops < <= > >= == and or not if).
- Consequence: in the v142 ladder `edge_ride` always moves and `jackal` never runs; the upper seat's `spread_out` caches a hold after arriving, so it camps 180 px from spawn (v142 = edge_ride lower + camper upper). Put guarded controllers BEFORE the terminal edge_ride.
- Scoring: only the winning duo scores (its team glory, both seats). Kill deeds: ace 40 / splash 35 / longshot ≥866 px 30 / honorable 10, first blood +12, team kill −60; heat ×2 (kills 2-4) and ×4 (5-6) when gaps <45 ticks. See research/s2_glory_report.md, s2_play_catalogue.md, s2_ladder_designs.md.

### Experiment matrix at 22:20Z 2026-09-04 (local, engine 9f17087/fad3029)
| recipe | idea | same-duo 12 seeds (kills/ep, tk/ep, duo-score sum) | mixed 8 seeds (meanSeat, tk/seat) |
|---|---|---|---|
| v149 (=v145 live earlier) | arm_up, hold to 1st shrink, shelter, crossfire late, 32 px guard | 8.8, 1.1, 232k | 3,991, 0.05 |
| v152 | v149 + hold to 2nd shrink | 7.9, 0.33, 2.61M (one 2.5M) | 26,900, 0.17 |
| v151 | hunt lane + guarded jackal from 1st shrink, 32 px guard | 10.8, 0.5, 9.3M (one 8.96M grenade duo-kill) | 421, 0.00 |
| v154 | v150 + 48 px guard | 7.4, 0.33, 352k | — |
| v155 (=v146 LIVE) | v151 + 48 px guard | 9.4, 0.25, 396k | 43,728, 0.03 (seeds 1410); 4,208, 0.03 (seeds 1418) |
| v156 | v155 + guarded loot after the 1st shrink | 8.6, 0.17, 404k (7 eps ≥15k, most consistent) | 28,545, 0.05 |
| v157 (=v147 uploaded, unsubmitted) | v155 + arm_up grenade phase (bot v6, stall fixed 7f83f02) | 9.2, 0.33, 1.52M (max 933k, 9 wins ≥200), grenade 36% | 4,591, 0.00, kills/seat 1.41, grenade 47% |
| v159 (→ v148 upload) | v156 + arm_up grenade phase | 8.3, 0.25, ≈409M (816M spray-double-kill episode + 2.16M), grenade 35% | 686, 0.03 (seeds 1410); seeds 1418 running |
| v158 | v155 + hold to 2nd shrink | — | 1,072, 0.02 |
Levers proven: arming (arm_up), no friendly fire (adjacency guard), hunt during shrinks (kill volume compounds), grenades (a duo double-kill = 10^6-10^7). Leader to beat on consistency: paintbot-huddle (median round sum 132k; custom kind-aware loot with prefer:grenade, hunt lane 140, chain jackal, late bodyguard).

## Solo era (from 2026-09-05) — state at 18:00Z 2026-09-08
- Rules: 16 solo seats, spawn armed, 4 HP; placement ×2/×3/×4 at final 8/4/2, win ×8 (×192), cap 2^24 per seat-episode; round = sum of 12 episodes; standing = EMA k=0.05. See research/s2_changelog_fad3029_c3f7781b.md and the wiki snapshots in research/wiki/.
- Any recipe with `$PARTNER` is rejected in solo mode (partnerSeat -1) and the bot falls back to a bare edge_ride. v170 (live as v150 since 17:52Z): target_law hold to zonePhase 1 + hardened supply_run + guarded loot + shelter; recall 900 hunt lane + guarded jackal; 1500 tight. Local solo smoke: 0.38 kills/seat vs starter:cautious 1.12 (its ladder: target_law hold zp1 > scatter 320/300 > edge_ride 420/320/1.0, later supply_run whenHpBelow 5 + loot 300 + edge_ride 340).
- Local solo results (8 eps, 4 of our seats vs 12 starter seats; analysis/s2_seat_glory.py): v170 (live v150) meanSeat 425k / win 12% / kills 0.91; v171 (uploaded v151) 529k / 12% / 0.75; v172 (hold to 2nd shrink, bounty) 526k / 9% / 0.66; starters 2-14k. Each caps once (16.8M) on seed 1416 — within noise; seed extension 1418-1433 for v170/v171 in episodes/s3-*-1418; v174 (shelter + late guarded jackal) in episodes/s3-v174. Rule: hosted rounds arbitrate; rotate only on a clear local + hosted signal.
- Harness: engine clone /private/tmp/engine-main-v43 (c3f7781b), server /tmp/johomax-ctf-server-runtime7, bot /tmp/e12-bot-v7, solo config /tmp/johomax-s2-config-solo-v2.json, starters rebuilt; `scripts/s2_local.py` auto-detects solo configs.

## Resume (stopped 23:13Z 2026-09-04)
1. **First: is v149 active and dealing damage?** `uvx coworld@latest memberships -l league_b8fa9b35-...` (Jordan rows: active/qualifying) and `python3 analysis/br_rounds.py fetch --since 3984 --limit 20 && python3 analysis/s2_rounds.py --since 3984` — kills must be > 0. v149 = the v146 hunt recipe with guard-hardened supply_run (medkit_dist > 0, 0 < hp_frac < 0.67) and the stall-fixed arm_up build; it was submitted 23:11Z after coworld 0.7.328 (round 3983) let supply_run win the ladder at full HP and every v146 seat camped unarmed. If v149 also shows 0 kills, fetch a replay (`analysis/s2_replays.py fetch --since N --limit 3`, `mine`, then print our seat's annotations via parse_replay(...)["annotations"]) and check which play holds the ladder.
2. Check `coworld_version` in every new round's request JSON; any bump → re-verify kills immediately (0.7.303 unarmed spawn, 0.7.328 dead guards). Fetch the engine (`git -C /private/tmp/engine-main-v42 fetch`) and rebuild if the play SDK changed (server /tmp/johomax-ctf-server-runtime6 = fad3029; bot /tmp/e12-bot-v6 has the stall-fixed arm_up with the grenade phase).
3. Candidates in order: v163 (= v147 grenade phase, hardened) and v162 (= v148 loot + grenade phase, hardened) — both need a mixed-duo run on a fresh seed set vs v161 before rotating (rule: rotate only on a clear win over ≥12 episodes; judge on kills/seat, tk/seat, weapon pickups; meanSeat is jackpot noise). Local evidence so far: v157 (grenade phase) kills/seat 1.22-1.41, tk 0-0.05, grenade pickups 36-47%; v159 (loot + grenade) had an 816M spray-double-kill episode; v160 (loot from spawn) untested.
4. Standing at stop: rank 1 (2,376,738 at 23:07Z, decaying 5%/round toward round sums) after v146's 10.08M (round 3978) and 35.8M (3980) episodes; Ari Sklar 1.68M, daveey-1 0.71M. paintbot-huddle is the consistency leader (median round sum 132k).
5. Push loop is stopped; push after committing (`git push origin main`).

## Resumed 2026-09-04 20:30Z — state at 21:00Z
- The zero-damage break was loot-at-start (engine 0.7.303): seats spawn unarmed and must walk over a gun and a hopper; a held half makes same-kind crates untakeable so the reference `loot` parks after one pickup. Fixed by the custom `arm_up` play (bot/plays/arm_up.nim, seeks the missing half, faults itself to retire) + all plays rebuilt on the current SDK (+ loot, scatter) + the PV1 decoder accepting the downed/loadout flag bits.
- v144 (arm_up + hold until the first shrink + shelter edge_ride; recipe v144-armup-hold-shelter.env) submitted 20:56Z. Local: 7-8/8 seats armed by tick ~900, 7-9 kills per episode, wins every local episode vs the new starters.
- Scoring now: product of factors (×1 kills worthless; VICTORY ×8, CLOSING TIME ×3 during any active shrink, LONGSHOT ×3, DUO DOWN ×2, LAST LIGHT ×4 after tick ~4035; friendly fire ÷2 per incident), every seat banks; round = sum of best 12 episode scores; standing = EMA k=0.05 of round scores (leaderboard). Field median round sums 2k-90k (paintbot-huddle 93k top); jackpots 10^5-10^7. Reference: research/wiki/glory-season-2.md, research/s2_changelog_11b1f1c_9f17087.md, forum GET /v2/forums/paintbot/posts?sort=new.
- Harness: server /tmp/johomax-ctf-server-runtime5 (engine 9f17087), bot /tmp/e12-bot-v3, config /tmp/johomax-s2-config-16-v2.json (variant game_config + 16 tokens), starters rebuilt; recipes v148a-d in research/s2_patches/recipes/. Judge locally with analysis/s2_local_glory.py.

## Resume (stopped 23:10Z 2026-09-02)
1. **First: the hosted break.** Since round 3736 (coworld 0.7.303) all our seats deal zero damage (v142 and v143 alike; ledger 23:10Z). Fetch the engine (`git -C /private/tmp/engine-main-v42 fetch && log HEAD..origin/main`), find what 0.7.303 changed in combat arming / module ABI (src/shell/body.nim, ladder.nim, module validation), rebuild the playbook wasm + bot image, test locally on the new engine (`scripts/s2_build_starters.sh`, server rebuild per s2-local-harness memory), then re-upload. Check `python3 analysis/s2_rounds.py --since 3736` for kills > 0 before anything else.
2. v143 (d1 longshot ambush) is champion but unjudged: its only round (3737) was under the break. Local: seeds 1410-1417 meanWin 137 max 443; seeds 1420-1427 meanWin 56 max 143 — the tail did not repeat, so treat d1 as unproven. v142 (edge_ride lower + camper upper) is the fallback (9 rounds, best 257).
3. Objective reminder: standing = best single winning duo score (ours 363, richard 375). Winners only score; kills chained <45 ticks and longshots ≥866 px pay most (research/s2_glory_report.md). Judge locally with `analysis/s2_local_glory.py`, hosted with `analysis/s2_rounds.py` (best column) and `analysis/s2_kill_gaps.py` on mined replays.
4. Harness: server /tmp/johomax-ctf-server-runtime4 (engine worktree /private/tmp/engine-main-v42 @ 11b1f1c), bot /tmp/e12-bot, config /tmp/johomax-s2-config-16.json, recipes in research/s2_patches/recipes/ (v144-*, v145-*, v146-d1camp, v143-d1-longshot-ambush). Two batches run fine in parallel on different ports.

## Resumed 2026-09-02 20:06Z

The coworld CLI `rounds` command broke against an API change (entries/next_cursor); analysis/br_rounds.py and analysis/s2_replays.py now read the API directly. /tmp was cleared: harness rebuilt at /tmp/johomax-ctf-server-runtime4 (engine worktree /private/tmp/engine-main-v42 = origin/main b672ea8c, 0.7.297 on hosted), bot /tmp/e12-bot, config /tmp/johomax-s2-config-16.json, recipes copied to /tmp from research/s2_patches/recipes/. **Scoring rule changed while stopped: `round_scoring_rule: max` — the standing is a player's best single seat score in any round** (richard 375, Jordan 363 rank 2, nancy 337, Eckstar 333 after 12 rounds). That rewards one high-glory episode (kills + win), not consistency.

## Earlier stop note (16:10Z)

Nothing is running locally. On the platform v140 (the richard-like ladder on
our `spread_out` play, holdTrigger tick 1000 — see research/s2_patches/recipes/v137b-richardlike.env)
is the competing champion and keeps playing rounds every ~10 min. To resume:

1. `python3 analysis/br_rounds.py fetch --since 3690 --limit 200 && python3 analysis/s2_rounds.py --since 3690` — our per-round means since the stop.
2. Division leaderboard: `curl -s -H "Authorization: Bearer $(grep -m1 usr_ ~/.softmax/credentials.yaml | awk '{print $NF}')" https://softmax.com/api/observatory/v2/divisions/div_aa7825db-262f-4a62-b01a-177c1b48f7ee/leaderboard` (standing = max round mean per player).
3. Mine new entrants' ladders before changing recipes: `cd /tmp/johomax-replay && python3 analysis/s2_replays.py fetch --since <round> --limit 40 && python3 analysis/s2_replays.py mine research/s2_replays/<round_dir>` (the miner is also committed at analysis/s2_replays.py; the worktree has the downloaded replays).
4. Rotate a candidate: `scripts/ship.sh bot jordan-ctf-candidate --env-file <recipe.env> --tag change=...` then `uvx coworld@latest submit jordan-ctf-candidate:vN -l league_b8fa9b35-ac22-48cf-a03f-07b397aff1c7 --auto-champion always --no-open-browser`; re-submitting a benched version returns 409 (upload a clone instead). Judge by hosted rounds (3+ per version); local canned-starter batches only test partner kills and call acceptance.
5. Local harness: server /tmp/johomax-ctf-server-runtime3 (engine worktree /private/tmp/engine-main-v41-ro, wasmtime 48), config /tmp/johomax-s2-config-16.json, bot build `cd bot && nim c -d:release -d:useMalloc --opt:speed --out:/tmp/bot baseline.nim` (PATH=$HOME/.nimby/nim/bin), `scripts/s2_local.py batch --bot /tmp/bot:4 --bot starter:aggressive:2 --bot starter:cautious:1 --bot starter:collaborative:1 --bot-env-file bot=<recipe.env> ...`. /tmp is volatile: the recipes are in research/s2_patches/recipes/, the engine deps refetch via tools/runtime_spike/fetch_deps.sh.

## Live state

| | |
| --- | --- |
| CTF champion | **v117**, rank 6. Untouched this session; v118 was PROMOTE-LOCAL only. |
| Paintbot champion | **v150 ACTIVE 2026-09-08 17:52Z** = v170 solo recipe (research/s2_patches/recipes/v170-solo.env: target_law hold to the first shrink + hardened supply_run + guarded loot + shelter; recall 900 hunt lane + guarded jackal; recall 1500 tight; NO partner refs). Why: the league went SOLO on 09-05 (16 one-policy teams, spawn armed, no duo partner) and every `$PARTNER` recipe is rejected → the bot fell back to a bare edge_ride that never fires; v149 sat at rank 15 (202k) for days. Field medians 75-89k/round (apex, co-gas, Monet) with 16.8M capped legs. v150 rounds 4474-4476: sums ≈ 58k / 860k (top of round 4475, a 663,552 leg) / 25k vs v149's ≈1k. Ready alternatives: v151 (= v171 shelter), v174 (shelter + late jackal, best local win rate). |
| Paintbot league state (2026-09-02 08:00Z) | League is "Paintbot (Season 2)" on `battle-royale-s2`: 8 duos / 16 seats, fresh pooled map per episode, JSON socket views, engine 0.7.287. Rounds every ~10 min. **Our v126 membership was disqualified 03:41Z** on a note (baked-in ws://127.0.0.1:21815) that does not match our code; every round we played failed on other pods. Hosted XP on 0.7.287 runs our image fine but the server drops our play socket right after the first accepted call (also reproduced locally, `git bisect` on the engine in progress), so v126 plays the whole game on its first standing order: 0 wins vs starters v3, 14 team kills in a self-mirror. Competing: lessandro-forum-power-user-envoy:v3 (champion, 31.5/seat), Monet:v4, paintbot-huddle:v2, focusfire-s2, codex-paintbot-t1 x2. |
| CTF league / div | `league_3243d905-...` / `div_37361341-2970-4dac-9528-55398bab0d1a` |
| Paintbot league / div | `league_b8fa9b35-ac22-48cf-a03f-07b397aff1c7` / `div_aa7825db-262f-4a62-b01a-177c1b48f7ee` |
| Campaign standing, r122 | daveey 84, richard 11, us (Jordan) **4**, RowDaBoat 1. Board restarted since r101; symbols RE-DEALT (we are `H` now). Orders rewritten r122 — the stale legend had been pointing us at our own cells. |
| Our campaign player id | `ply_bcb80069-fb0c-4ba5-a45c-06b647870aeb` |
| Engine pin | `sim/engine.pin` = 9d26cc26 (GV50), bitworld 9af28b41; season-2 local server `/tmp/johomax-ctf-server-runtime2` from `/private/tmp/engine-main-v40` (see `sim/README.md` "Season 2 locally") |

3 commits on `main` are **unpushed** as of this file. A 10-minute campaign
orders loop (user-requested, `*/10 * * * *`) is SESSION-ONLY — recreate it on
a new session; it replaced the old hourly job. Campaign wire cells are x,y =
(col,row); orders POST body needs `{player_id, prompt}`.

## The loop

1. Download replays vs the player ranked just above us. 2. Analyse. 3. Design
experiments. 4. Local A/B. 5. Combine winners, re-verify. 6. Hosted A/B,
**never more than 80 episodes**. 7. If it improves, submit with
`--auto-champion always`. 8. Wait for a round. 9. Goto 1. **10. `/compact`** —
added by the user; run it at the iteration boundary only, never with a
measurement in flight. It cannot be self-invoked (built-in CLI command, the
Skill tool rejects it), so end the iteration by asking the user to run it.

A recurring hourly job fires "update campaign orders based on current
standings". It is machine-local and will not follow to a new host — recreate it
if the campaign work continues.

## Open work

**Season-2 status 2026-09-02 09:20Z.** Recipes are env-configurable (S2_OPENING_CALL / S2_UPPER_OPENING_CALL / S2_RECALLS, canonical JSON, `$PARTNER`), baked into images with `scripts/ship.sh --env-file` (escape `$`). Local: `scripts/s2_local.py batch --bot /tmp/e8-bot-asym:4 --bot starter:... --bot-env-file LABEL=FILE` (four of our duos vs starters) and 16-seat self-mirrors for partner kills (`team_kill_lines`). Replays of every round expose all calls (`analysis/s2_replays.py`); `analysis/s2_rounds.py` prints our per-round means. Current line: the custom `spread_out` play (bot/plays/spread_out.nim; the duo's upper seat walks 180 px at game start via S2_UPPER_OPENING_CALL) removed partner kills in local self-mirrors (tk 0/0/0/0 vs control 1/1/1/2); combine it with the kill-oriented jackal recipe (v133) and read hosted rounds with analysis/s2_rounds.py.

**Older 08:20Z note.** v127 submitted (clean exit, `{}` sentinel, env-configurable ladder, pact). The overnight "socket drop" was a misread of the normal episode end. Next: E8 recipe sweep (starters' recipes via S2_OPENING_CALL env files, runbook /tmp/e8-runbook.md, results under episodes/e8-*) and the replay miner (`analysis/s2_replays.py` in worktree /tmp/johomax-replay; public replays expose every seat's calls) to copy what the champion lessandro v3 does.

**E5 duo formation (older) — MEASURED, FAILED.** Gates (seeds 1400-1403): e5-sep128 9 partner kills vs 9 enemy, e5-sym128 10 vs 11, e4-base 9 vs 7, HEAD 12 vs 8. `[s2] geo` logged `partner_d=-1` on every seat: plays never see the partner, so bodyguard-first is a hold. The same duo (pale blue, seats 15/31) shoots itself at ticks 1461-1499 in E4 and 1464-1502 in E5 — the margin asymmetry (220 vs 300) does not move them apart either. Next levers that need no partner position: different `enterLead` per seat, follower `supply_run`-first at spawn, or `holdTrigger` never releasing (aliveTeams 2) to test whether zero-fire survival scores more than mutual kills. Working tree is clean; sep128 lives in `research/s2_patches/e5-sep128.patch`. Local 32-seat
self-mirrors on the real wasmtime server show our duos die to EACH OTHER: both
seats sit on the spawn pixel until the zone bites (edge_ride holds inside its
band; the deployed view may lack `next`/`ticksToShrink`), and when the
`holdTrigger` releases, each partner's first shot lands on the other on the
same tick (seed 1402: ticks 1461/1480/1499). `never:["seat:a","seat:b"]` is
accepted but does not stop it; `duo:<team>` is rejected. Guards are zero-valued
on the deployed engine, so the first controller entry is the only one that runs
and our 4 Hz re-calls are the only switch. E4 (guard-free ordered ladder,
`/tmp/e4-base.patch`, applied uncommitted in the tree) failed its gate (9
partner kills vs 7 enemy over seeds 1400-1403) because its low-HP rule
(`hp_frac < 0.67`) fired on every seat at the first zone tick and put
supply_run first again. E5 (Codex worker, brief in the session scratchpad,
outputs `/tmp/e5-bot-{e4base,sep128,sep200,sym128}`, `/tmp/e5-*.patch`,
`/tmp/e5-runbook.md`): follower seat (slot >= 16) runs bodyguard-first with
leash [128,260] so it is pushed off the leader (bodyguard.nim:116), low HP
means `hp <= 1`, plus a `[s2] geo` log line (partner_d, zone_next,
ticks_to_shrink). Gate: self-mirror n=4 seeds 1400-1403, same-colour
"killed by" near zero with enemy kills >= 7; then 8/8 vs e4base, then vs the
starters. Only matters if the league runs `battle-royale-s2` again; the
classic path (v122+) already wins every hosted game.

**Classic path.** Next one-variable candidate: `BrHuntTrackTtl 90 -> 48`
(local BR A/B via `scripts/local_sim.py br`, then hosted rotation <= 80
episodes). Watch for the league un-disqualifying the field or flipping back to
`battle-royale-s2`; `analysis/br_rounds.py fetch/report` reads the rounds.

## Branches, with verdicts

- `axis-frame` — **rejected**, −0.2344 [−0.3458, −0.1201] over 288 seeds once
  rebased so it carried `roles4`. Its `carryHome` fix was extracted to `main`.
- `endgame-sweep` — **rejected**, level at both chase TTL 150 and 400.
- `feature/scaffolds`, `backup-pre-merge-main`, `claude/...autoresearch` — older,
  not part of current work.

## Traps this session actually hit

- **Check a branch's base before comparing it, not after.** One confounded run
  was voided for comparing "branch minus `roles4`" against "tree with `roles4`".
- **README rule 5 is real.** A gap whose CI near-edge sits at −0.07 needs a
  second seed block. Buy it.
- **Campaign: count `transfers`, nothing else.** `winner` is null on conquests
  so it undercounts; `outcome: "conquered"` includes cells that fell to a
  *different* attacker in a contested cell, so it overcounts. A cell is ours
  when a transfer says `to: <us>`. I got this wrong twice in opposite directions.
- **`modes` is a positional list over the 100 cells**, not a dict.
- **The campaign strategist treats any permission as a default.** "daveey is a
  last resort" became "daveey every round". Write hard prohibitions and one
  ranked target list; avoid "prefer X but Y is acceptable".
- **It also cannot reliably turn a player name into a coordinate.** It gets an
  ASCII letter grid; making it quote the grid row and name the letter at its
  chosen column before committing is what produced the only two gains.
- Campaign API: `{server}/api/observatory/v2/leagues/{id}/campaign`, bearer
  token from `~/.softmax/credentials.yaml`. Orders are POSTed to
  `.../campaign/prompt`, max 4000 chars, effective next round.
