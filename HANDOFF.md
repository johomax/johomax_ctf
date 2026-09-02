# Handoff

State that lives outside the repo and would otherwise be lost. Everything with a
measurement behind it is in `research/LEDGER.md` and `research/state.json`; this
file is only the things a new machine cannot reconstruct.

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
| Paintbot champion | **v140** (since 15:07Z; v137 recipe) — 28 rounds while stopped, mean 14.8, best episode 363 = our standing (rank 2 behind richard 375 under the new max-episode rule). **v141** (clone of v130: jackal, no hold, pact/never; our record episode 462) is uploaded and rotates in at 21:05Z right after the daily award, because one high-glory episode now decides the standing. Local: jackal with/without spread being measured on the new engine (self-mirrors + vs starters). v138 (truce line) ran 6.8 / 3.8 / -1.8 / 1.5 — dropped. A 15:06Z auto-decision keeps whichever recipe leads since round 3676 and otherwise rotates to v140 (clone of v137, mean 17.9). Standings 14:13Z: richard 56.17, codex 53.58, Jordan 50.92, relh 49.00. v137 ran 7.2 / 25.8 / 17.2 / 26.6 (mean 19.2, best in the co-gas field) (richard-like: pact + target_law{holdTrigger tick 1000, never partner} + crossfire + edge_ride 438/378/.8, upper seat spread_out first; local gate tk 0/0/0/0). v136 (truce line on the v132 recipe) ran one round (4.5). Queued uploads: v139 = v137 with holdTrigger tick 1300 (rotates 14:12Z), v140 = clone of v137 (rotation back if the trials lose; re-submitting a benched version returns 409). v135 (= v132 recipe) fell to 13.4 / 8.5 / 3.8 / 10.7 once two new "co-gas-paintbot-s2-cautious" entrants (richard, relh) arrived: richard's ladder = custom scatter edge_ride + crossfire{40,[140,300]} + target_law{holdTrigger tick 1000, never partner} → 32.5 mean, 50% duo wins, a 54.9 round. Our answer v137 (same structure on our spread_out) is uploaded, unsubmitted, gated locally. Division standing 50.92 (rank 2-3). |
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
