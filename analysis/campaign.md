# Campaign mode and the territory mechanic

Research note, 2026-08-03. Sources: platform backend at `/home/agent/metta`
(spec `docs/specs/0075-campaign-league.md`, code under
`app_backend/src/metta/app_backend/v2/`), the engine manifest at
`/workspace/.engine/coworld_manifest_paintbot.json`, and live read-only queries
against the production Observatory API.

**Path convention.** Backend citations below are relative to
`/home/agent/metta/app_backend/src/metta/app_backend/v2/` unless written out in
full. So `campaign/engine.py:286` means
`/home/agent/metta/app_backend/src/metta/app_backend/v2/campaign/engine.py:286`.

---

## The answer that matters

**My policy cannot see or reason about territory — it is purely a server-side
aggregation between episodes, and the only thing the policy controls is winning
individual episodes decisively.** But territory is *not* simply "win more
episodes": the settlement rules convert episode results into cells through a
2-0 sweep gate and a staked-forfeit penalty (`campaign/engine.py:286-295`), and
a *drawn* episode is worth exactly zero to everyone
(`campaign/episodes.py:665-666`) — so **decisiveness matters as much as
win rate**, and there is a second, entirely separate lever I am currently not
using at all: the player-authored LLM strategist prompt that decides *which*
cells I attack.

Two findings make this urgent:

1. My policy wins **48% of decisive episodes on 2-team maps** (`default`,
   `2v2`) but **0% on `4ffa` and 8.7% on `4ffa8`**. Yet over the last 20 rounds
   my strategist aimed **15 of 34 invasions and 8 of 11 airdrops at FFA cells**.
   That is a pure own goal, and it is fixed by editing a prompt, not the policy.
2. **8 of the 10 cells I have ever lost were forfeitures** — cells surrendered
   because I attacked from them and got swept 0-2. My attacking, not my
   defending, is what costs me territory.

---

## 1. What is a campaign?

A **campaign is a league "round brain"** — a drop-in replacement for the
platform *ladder*, sitting at the same level, not above it.

`LeagueSettings` carries `ladder` and `campaign` as siblings, and they are
**mutually exclusive**:

- `league_settings_schema.py:46-49` — `ladder: LeagueLadderConfig | None`,
  `campaign: LeagueCampaignConfig | None` ("Territory-on-a-planar-graph round
  brain; mutually exclusive with an enabled ladder").
- `league_settings_schema.py:68-72` — validator: *"ladder and campaign cannot
  both be enabled"*.
- `campaign/config.py:1-10` — *"A campaign league replaces the ladder round
  brain: policies occupy cells of a planar graph, per-player LLM strategists
  order staked invasions each round, and standings are territory."*

Everything below the round brain is reused unchanged
(`docs/specs/0075-campaign-league.md:43-46`): player submissions, one champion
`PolicyVersion` per player, divisions, the k8s episode job runner, replays,
leaderboard publishing.

**Relation to the CLI's concepts:**

| CLI concept | Under a campaign |
| --- | --- |
| **League** | Unchanged. Holds `settings.campaign` and the whole board in `League.commissioner_state` (`campaign/state.py:1-7`). |
| **Division** | Unchanged. The campaign schedules its rounds on the league's *Competition* entry division (`campaign/episodes.py:253`), and overwrites that division's leaderboard with territory (`campaign/runner.py:636-650`). |
| **Round** | Still a real platform `Round` row, one per campaign round, `commissioner_key="platform"`, idempotency key `campaign:{league}:e{epoch}:{n}` (`campaign/episodes.py:63-66`, `549-555`). One campaign round = one platform round = all that round's battles' episodes. |
| **Episode** | Unchanged. Each battle authors 1..N `ExplicitEpisode`s in that round's plan (`campaign/episodes.py:286-302`). Replays and `episode-stats` work normally. |
| **Matchmaking** | **Gone.** No Elo pairing. Who fights whom is decided entirely by the per-player LLM strategists' invasion orders (`campaign/strategist.py:176-259`, `campaign/engine.py:127-223`). |

### Is my league a campaign? Yes — it is one right now.

Verified live via `GET /api/observatory/v2/leagues/{id}` (the CLI's
`coworld leagues <id> --json` shows the same `settings` blob):

```
league_b8fa9b35-ac22-48cf-a03f-07b397aff1c7  "Paintbot"
  settings.ladder.enabled   = false
  settings.campaign.enabled = true
  settings.campaign.outcomes = "episodes"     <- real episodes, not emulated
  settings.campaign.board    = {width: 10, height: 10, mode_mix: {"1v1": 1.0}}
  settings.campaign.max_invasions = 3
  settings.campaign.round_interval_seconds = 600
  settings.campaign.episode_timeout_seconds = 1800
  settings.campaign.strategist.model = "us.anthropic.claude-sonnet-5"
  settings.campaign.strategist.default_prompt =
      "Expand cautiously. Prefer weak neighbors and empty cells; avoid fights you keep losing."
```

Unset keys take their `campaign/config.py` defaults: **`best_of = 1`**
(`config.py:102`), **`min_airdrops = 1`, `max_airdrops = 1`**
(`config.py:92-93`), `baseline_policy_version_id = None` → first-listed league
filler (`config.py:97`, `episodes.py:269`).

The `mode_mix: {"1v1": 1.0}` in the settings is **inert**. In `outcomes:
"episodes"` mode, cell modes are derived from each variant's team structure and
rewritten every round by `align_cell_modes` (`campaign/config.py:122-124`,
`campaign/state.py:101-113`, `campaign/runner.py:355`). Live, the board has
**zero 1v1 cells**: 45 cells are mode `2v2` and 55 are mode `ffa4`.

So the ladder I thought I was competing in has been switched off, and the
division standings I am ranked by are territory (confirmed below, §3).

---

## 2. What exactly is the territory mechanic?

### Representation

The board is a **10×10 grid, 4-neighbour adjacency**, stored as plain JSON in
`League.commissioner_state` under `version: "campaign_v1"` — **no new tables**
(`campaign/state.py:1-7`, `19-47`).

A cell (`campaign/state.py:30-31`, `136-147`) is:

```json
{"owner": player_id | null, "since_round": int, "map_ref": "<variant id>",
 "mode": "1v1"|"2v2"|"ffa4", "map_seed": int, "map_size": "small|...|giant"}
```

**A cell *is* a map.** `map_ref` picks the coworld variant; `map_seed` is a
deterministic per-cell terrain seed (`campaign/state.py:50-53`) that never
changes, so *the same cell replays the same terrain every round*. Territory
literally means "maps you rule" (`docs/specs/0075-campaign-league.md:76-78`).

Live board composition (100 cells, all seeds distinct):

| variant | cells | derived mode | episode score scale |
| --- | --- | --- | --- |
| `4ffa8` | 29 | `ffa4` | −1 / +4 |
| `4ffa` | 26 | `ffa4` | −1 / +4 |
| `default` | 25 | `2v2` | −1 / +1 |
| `2v2` | 20 | `2v2` | −2 / +2 |

Also stored: `history` (per-cell ownership list, drives recruitment —
`campaign/state.py:34`), `prompts` (player-editable strategy prompts —
`state.py:36`), `frames` (per-round replay of the whole war — `state.py:42`),
and `pending_round` (the in-flight platform round — `state.py:47`).

### How territory is gained and lost

Territory is **not** derived from in-episode paint coverage, and it is **not**
"who won the round" in the ladder sense. It is a war-game settlement over
per-battle outcomes. The round loop (`campaign/runner.py:1-9`, `256-564`):

> snapshot board → one Claude Sonnet strategist call per player → validate
> orders → freeze battles → run real episodes → settle → append frame →
> publish territory leaderboard.

**Orders** (`campaign/engine.py:53-112`, limits from live config):

- up to **3 staked invasions** of cells *adjacent* to cells you own, each from
  a distinct owned source cell;
- **exactly 1 airdrop** — attack *any* cell on the board, no adjacency, **stakes
  nothing**. `min_airdrops=1` means if the strategist aims fewer, the league
  spends the shortfall on a **random** valid target (`campaign/runner.py:434-438`).

**Settlement arithmetic** (`campaign/engine.py:226-314`). With `best_of=1`, each
"slot" is one episode.

*2-team cells (`2v2` mode — this is `default` and `2v2` variants here). Two
slots, one per side assignment:*

| slots | outcome | territory effect |
| --- | --- | --- |
| 2-0 attacker | `conquered` | attacker takes the target cell |
| 0-2 attacker | `repelled_forfeit` | **defender takes the attacker's source cell** |
| 1-1 | `split_held` | nothing moves |
| any slot undecided | `unresolved` | **nothing moves at all** |

Code: `engine.py:286-295`. Airdrops set `staked=False`, so 0-2 costs nothing
(`engine.py:170`, `291-293`).

*Empty cells (`claim`):* one episode against the league baseline/filler policy;
win to take it, never staked (`engine.py:279-284`). Only **2 of 100 cells are
still empty** — this path is essentially closed.

*FFA cells (`ffa4` mode — `4ffa` and `4ffa8` here):* all attackers of that cell,
the defender, and recruits are seated in **one 4-team episode**
(`engine.py:178-207`). Then (`engine.py:248-274`):

- an **attacker** tops the board → takes the cell **and every other attacker's
  staked source cell**;
- the **defender**, a **recruit**, or **filler** tops the board → defender holds
  **and collects every attacker's staked source**;
- no strict winner → `unresolved`, nothing moves.

Recruits are the cell's **previous owners, newest first**
(`engine.py:115-124`), and when there is still a spare seat the engine
**conscripts a random other league player** rather than seating filler
(`engine.py:186-192`). Recruits can spoil but can never gain territory
(`engine.py:252-262`).

*Conflicts:* all orders are frozen against the **pre-round** board, so a cell can
be claimed several ways in a round; **one claimant is picked uniformly at
random** (`engine.py:299-303`).

### From episode scores to a battle result — the decisive detail

`campaign/episodes.py:634-689` converts real episode scores into the
attacker-won booleans that `settle` consumes. It prefers **per-seat** scores
and compares the attacker's best seat score to the defender's best:

```python
att, opponent = max(att_scores), max(other)
if att == opponent:
    return None, "tie"          # episodes.py:665-666
return att > opponent, None
```

A `None` counts for **neither** side. A slot only decides on a strict majority
of its `best_of` series; otherwise the whole battle is `undecided` and
`b["episodes"] = []` → `unresolved` → **no-op** (`episodes.py:739-755`). Same
for FFA: a tied top score means nobody wins the episode
(`episodes.py:826-830`, `837-844`).

**This is the single most important mechanical fact for a Paintbot policy.**
Paintbot uses `scoring: "pot"`: every team antes, the winner takes the pot. When
an episode ends with *no* winner (timeout, no heart captured, no wipe), **every
team scores −1.0** — identical scores — which the campaign reads as a tie.

Measured across every scored episode on the live board (rounds 42–65, 691
episodes):

```
all-equal (every party −1.0):  188 episodes  → 188/188 produced `unresolved` battles
decisive:                      503 episodes
```

Draw rate by map:

| variant | episodes | drawn | draw % |
| --- | --- | --- | --- |
| `4ffa` | 150 | 70 | **47%** |
| `4ffa8` | 223 | 76 | **34%** |
| `2v2` | 107 | 16 | 15% |
| `default` | 211 | 26 | 12% |

Nearly half of all `4ffa` episodes end with nobody winning, and every one of
those is worth zero territory to everybody.

---

## 3. How territory affects scoring, standing, and matchmaking

**Standings are a plain cell count.** No weighting, no Elo, no map value.

- `campaign/runner.py:214-219` — `_territory()` counts cells whose `owner` is
  the player. That is the entire metric.
- `campaign/runner.py:222-253` — `_territory_snapshot()` sorts by
  `(-cells, name)` and emits columns `rank`, `territory` (cell count),
  `territory_pct` = `round(100 * cells / 100, 1)`.
- `campaign/runner.py:636-650` — that snapshot is written to
  `division.leaderboard_config` for **every** division in the league, and the
  leaderboard cache is invalidated.

Confirmed live at
`GET /api/observatory/v2/divisions/div_aa7825db-262f-4a62-b01a-177c1b48f7ee/leaderboards`:

```
default_view_key: territory
view "territory" | "Territory" | "Campaign territory — cells held on the board (emulated outcomes)"
columns: [rank, territory, territory_pct]
  1 daveey           69  (69.0%)
  2 richard          13  (13.0%)
  3 James Botts       5
  4 Jordan            5   <- me
  5 NanosaurusX       5
  6 Rohit Mukherjee   1
  (six more players on 0)
```

Note the description string says *"(emulated outcomes)"* — that text is
**hardcoded** at `campaign/runner.py:247` and is simply stale; this league runs
`outcomes: "episodes"`, i.e. real episodes. Don't be misled by the label.

**No Elo, no rating, no per-map bonus.** Every cell is worth exactly 1, whether
it is a giant `4ffa8` or a small `default`. There is no "value of a win depends
on standing" term anywhere in the arithmetic.

**Matchmaking is replaced, not weighted.** There is no rating-based pairing at
all: opponents are whoever's strategist aims at whom
(`campaign/engine.py:127-223`). The only automatic, non-chosen matchups are:

- the **random shortfall airdrop** when a strategist aims fewer than
  `min_airdrops` (`campaign/runner.py:434-438`);
- **random conscription into someone else's FFA** as a recruit
  (`campaign/engine.py:186-192`) — 21 of my 254 recorded battles are recruit
  seats, and they cost me nothing since recruits hold no stake.

**Territory does not feed back into who I fight**, except indirectly and
strongly: adjacency. Owning cells is what *enables* staked invasions, and
`history` (past ownership) is what gets you recruited back into FFAs on cells
you used to hold (`engine.py:115-124`).

---

## 4. Is any of it visible to a policy at runtime? No.

**Purely server-side.** I traced the full path from campaign battle to policy
container and found exactly one campaign-derived thing that reaches an episode,
and it is not territory.

Each battle authors episodes as `ExplicitEpisode` objects
(`campaign/episodes.py:286-302`) carrying only:

```python
ExplicitEpisode(
    variant_id=...,          # which coworld variant
    seed=base_seed + job_index,
    policy_version_ids=roster,
    filler_seats=filler_seats,
    game_config_overrides=_cell_overrides(cells[target], schema_props),
)
```

and `_cell_overrides` (`campaign/episodes.py:205-214`) sets **only two keys**:

```python
overrides["mapSeed"] = cell["map_seed"]     # if the schema has mapSeed
overrides["mapSize"] = cell["map_size"]     # if the schema has mapSize
```

`round_lifecycle.py:1319` then shallow-merges that over the variant's
`game_config` and the result is a normal `PlannedEpisode`. Corroborating
negative evidence: `grep -rn "campaign" app_backend/src/.../orchestration/
episode_requests.py round_lifecycle.py` returns **one comment** and no code
(`round_lifecycle.py:1563`). Nothing named campaign, territory, cell, board,
owner, round-number or standing is injected into the episode config, the pod
env, or the observation stream.

So the bot sees a Paintbot episode indistinguishable from a ladder episode. It
cannot know it is fighting for cell `7,3`, who owns it, whether the attack is
staked, or what the standings are. **There is no "be campaign-aware" option for
the policy.**

Two consequences of `mapSeed`/`mapSize` pinning that *are* worth knowing, even
though they are not territory data:

1. **Every cell has a fixed terrain forever** (`campaign/state.py:50-53`,
   all 100 live `map_seed`s distinct). The same map recurs every time that cell
   is fought over. A policy with cross-episode memory could exploit this — mine
   has none, so this is currently only a note.
2. **`mapSize` is overridden per cell, including for `4ffa8`.** The `4ffa8`
   variant ships `mapSize: "giant"`
   (`/workspace/.engine/coworld_manifest_paintbot.json`), but the campaign
   overwrites it with the cell's own size class, and overrides win the merge
   (`round_lifecycle.py:1319`). Live, of 29 `4ffa8` cells: 16 `standard`,
   7 `large`, 5 `small`, 1 `giant`. **Campaign `4ffa8` battles run 32 agents on
   standard and even small maps** — a density the ladder never produces. Since
   my policy adopts map size off the wire (`bot/baseline/tuning.nim`, per
   `/workspace/README.md`), this is a real distribution shift worth testing
   against locally.

---

## 5. What a campaign-aware operator would optimise differently

The policy itself can only do one thing: **win episodes decisively**. But the
strategist prompt is a separate, live, player-owned lever, and mine is
**still the league default** — verified:

```
GET /leagues/{id}/campaign/prompt?player_id=ply_bcb80069-...
{"prompt":"Expand cautiously. Prefer weak neighbors and empty cells; avoid fights you keep losing.",
 "is_default":true}
```

### (a) Draws are worthless — decisiveness is a first-class objective

A 1-1 split holds the status quo; a tie in *either* slot voids the battle
entirely. For an **attacker**, a draw is a wasted move. For a **defender**, a
draw is a successful defence. So the value of "close but inconclusive" is
asymmetric and depends on which side I am on — but the policy can't tell which
side it is on, so the only coherent policy-level target is: **convert games into
decisive wins, and prefer decisive outcomes over safe stalemates.** On `4ffa`
maps, where 47% of episodes end −1/−1/−1/−1, a policy that reliably *finishes*
(captures or wipes) would gain far more than one that marginally improves its
head-to-head.

### (b) Staked invasion EV is negative below a 50% win rate

With `best_of=1`, per-episode win rate `w` and loss rate `l` (`w + l + draw = 1`):

```
P(conquer target)      = w²
P(forfeit source)      = l²
EV(cells, staked)      = w² − l²   →  positive iff w > l
EV(cells, airdrop)     = w²        →  never negative
```

My measured per-map decisive record (rounds 42–65):

| variant | W | L | D | win% of decisive | EV per staked 2-team invasion |
| --- | --- | --- | --- | --- | --- |
| `2v2` | 11 | 6 | 7 | 64.7% | **+0.15 cells** |
| `default` | 28 | 30 | 7 | 48.3% | −0.03 cells |
| `4ffa` | 0 | 10 | 9 | **0.0%** | FFA rules; ≈ −0.5 cells |
| `4ffa8` | 2 | 21 | 9 | 8.7% | FFA rules; ≈ −0.5 cells |

This is not theoretical. **8 of the 10 cells I have ever lost were
`forfeiture`** — surrendered by attacking from them and losing 0-2 — versus 2
lost to being conquered on defence. My gains: 6 `conquest`, 5 `claim`,
3 `forfeiture` collected. Net +4 over 65 rounds.

### (c) The concrete misallocation

Over the last 20 rounds my strategist ordered:

- **34 invasions**: 18 at `default`, 11 at `4ffa8`, 4 at `4ffa`, 1 at `2v2`
- **11 airdrops**: 6 at `4ffa8`, 2 at `4ffa`, 2 at `default`, 1 at `2v2`
  (2 of these were random league-spent shortfalls)

So **15 of 34 staked invasions and 8 of 11 free airdrops were aimed at FFA
cells where my policy has won 2 of 33 decisive episodes.** Meanwhile the `2v2`
variant — where I am 64.7% and EV-positive — got **1 invasion and 1 airdrop in
20 rounds**. The default prompt's "prefer weak neighbors and empty cells" has no
notion of map type, and the strategist's context message does show cell mode and
`map_ref` (`campaign/strategist.py:136-144`), so a prompt that says so would be
acted on.

### (d) Exploitable asymmetries in the rules

- **Airdrops are free.** They stake nothing (`engine.py:170`), so their EV is
  `w² ≥ 0` always. With `max_airdrops=1` I get exactly one per round; aiming it
  at a `2v2` cell rather than letting it land randomly is strictly better
  (`campaign/strategist.py:62-64`).
- **Recruit seats are free upside-free downside.** I get conscripted into
  others' FFAs (`engine.py:186-192`); I can't gain territory there
  (`engine.py:252-262`) but I can't lose any either. Nothing to optimise, but
  it explains ~8% of my battle log and should not be read as losses that matter.
- **FFA attacking is catastrophic for me and lucrative for the leader.** An
  attacker who tops an FFA takes the cell *plus every other attacker's staked
  source* — one episode can swing several cells to one player
  (`engine.py:266-271`). daveey wins 85% of his decisive episodes and holds 69
  cells; every FFA I enter as an attacker alongside him is a donation.
- **Claim conflicts are a coin flip** (`engine.py:299-303`) — piling onto a
  contested cell has diminishing returns.
- **Cell modes follow the variant, not the config.** Because `mode_mix` is inert
  here, there is no 1v1 cell on the board at all; every "duel" is really a
  16-seat 2-team game where the captain's policy occupies 7 of its 8 team seats
  and the recruited "ally" occupies 1 (`campaign/episodes.py:82-101`, slot
  layout alternates red/blue). So allies barely matter; captain skill is
  essentially the whole result.

**Nothing about (a)–(d) changes what the policy binary should do beyond "win
decisively".** Items (b)–(d) are strategist-prompt work.

---

## 6. How to find out whether I'm in a campaign, and see its state

**The `coworld` CLI does not expose campaign at all.** `grep -rn "campaign"` over
the installed CLI package
(`/home/agent/.local/share/uv/tools/coworld/lib/python3.14/site-packages/coworld/`)
returns **zero hits**. There is no `coworld campaign` command.

**Two things the CLI *can* tell you:**

```bash
PATH="$HOME/.local/bin:$PATH" coworld leagues league_b8fa9b35-... --json
# -> .settings.campaign.enabled / .outcomes / .board / .max_invasions
```

and the division leaderboard, which will show `Territory` columns instead of Elo
when a campaign is running.

**Everything else is the HTTP API.** Base URL is `{server}/observatory` +
`/v2` (`coworld/api_client.py:429`, `routes/__init__.py:35`), i.e.
`https://softmax.com/api/observatory/v2/...`, with
`Authorization: Bearer <token from ~/.softmax/credentials.yaml>`.

Endpoints (`routes/campaign.py:1-11`):

| method | path | notes |
| --- | --- | --- |
| GET | `/leagues/{league_id}/campaign` | the whole board: config, players+symbols, per-cell `map_refs`/`modes`/`map_seeds`/`map_sizes`, all retained frames (battles, transfers, orders), `pending_round`. ~1.4 MB here. `routes/campaign.py:173-210` |
| GET | `/leagues/{league_id}/campaign/history?player_id=...` | one player's typed battle/transfer/territory/h2h history. `routes/campaign.py:227-259` |
| GET | `/leagues/{league_id}/campaign/conversation?player_id=...&round=N` | **owner-only** full strategist exchange, newest `conversation_rounds` (default 10). `routes/campaign.py:283-350` |
| GET | `/leagues/{league_id}/campaign/full-prompt?player_id=...` | **owner-only** exactly what will be sent next round: system frame + tools + rendered context. `routes/campaign.py:353-392` |
| GET | `/leagues/{league_id}/campaign/prompt?player_id=...` | **owner-only** current standing orders, with `is_default`. `routes/campaign.py:402-423` |
| POST | `/leagues/{league_id}/campaign/prompt` | **owner-only write** — set standing orders (≤4000 chars). Takes effect next round. `routes/campaign.py:426-443` |
| POST | `/leagues/{league_id}/campaign/restart` | commissioner/owner only; wipes the board. |
| POST | `/leagues/{league_id}/campaign/trigger-round` | team-only. |

Working read-only example (used for this report):

```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://softmax.com/api/observatory/v2/leagues/league_b8fa9b35-ac22-48cf-a03f-07b397aff1c7/campaign"
```

**Database:** there are **no campaign tables**. All state lives in
`leagues.commissioner_state` (JSONB) tagged `version: "campaign_v1"`, plus
`leagues.settings.campaign`; battles reference ordinary `rounds` /
`episode_requests` rows (`campaign/state.py:1-7`,
`docs/specs/0075-campaign-league.md:10-13`).

**UI:** an enabled campaign league opens on a **Campaign tab** by default
(`/home/agent/metta/web/softmax.com/src/app/(observatory)/observatory/v2/details/LeagueDetail.tsx:271`,
`741-756`), rendering
`.../v2/components/CampaignBoard.tsx`.

**Live status of my player** (`Jordan`, `ply_bcb80069-fb0c-4ba5-a45c-06b647870aeb`,
symbol `M`), round 65: 5 cells, rank 4 of 12, peak 7 cells; 254 battles logged
(200 as attacker, 33 defender, 21 recruit); 169 of them (66%) `unresolved`; a
round is in flight.

---

## What I could not determine

- **Why the campaign was enabled on the Paintbot league, or for how long.** The
  settings blob has no audit trail exposed through the API, and
  `commissioner_migration_version` is opaque.
- **The `unresolved_reason` for any specific past battle.** The runner records
  it internally (`campaign/episodes.py:756-765`) but `_frame_battles`
  (`campaign/runner.py:567-592`) does **not** include it in the public frame, so
  the API never serves it. I inferred the dominant cause (all-parties-`−1.0`
  ties) from the `scores` array, which *is* served — that accounts for 188
  episodes with certainty, but a residual set of unresolved battles carry
  `episode_ids` with no `scores`, which means the episode did not complete
  (failed/cancelled/timed out). **I could not separate infrastructure failures
  from genuine draws for those.** Rounds before 42 carry no `scores` at all, so
  the whole early war is uncharacterisable from the public payload.
- **Whether `best_of` was ever higher than 1.** Live frames record
  `best_of: null` for older rounds and the config omits the key, so I read the
  default of 1; I could not confirm it has been 1 for the entire campaign.
- **The upstream "prod Paintbot campaign R.433" per-seat alive-time statistics.**
  Nothing in the campaign code computes or consumes alive-time; that breadcrumb
  points at engine/reporter work outside this backend, which I did not locate.
- **Whether the FFA `mapSize` override was intentional.** It follows
  mechanically from `_cell_overrides` + the merge order, but no comment or spec
  line acknowledges that it defeats `4ffa8`'s `mapSize: "giant"`.

---

## Addendum: figures re-derived first-hand, and one correction

The research above was verified against the live API before anything was acted
on. Most of it held. One headline did not, and it pointed the opposite way.

**Board state, round 66, read from `/v2/leagues/{id}/campaign`:**
100 cells, `ffa4` 55 / `2v2` 45. Owners: **daveey 71, richard 13,
NanosaurusX 5, Jordan 5, James Botts 3, Rohit 1, unowned 2.** Our five cells
(67, 68, 75, 76, 77) form one contiguous block, four `2v2` and one `ffa4`.
Its frontier is 10 daveey-owned `ffa4` cells, 1 richard `ffa4`, 1 richard
`2v2` — i.e. almost everything we can reach is the mode we are worst at,
owned by the runaway leader.

**Our own battle record, split by mode AND by whether the attack was staked** —
this is the split the earlier pass did not make, and it inverts the advice:

| mode | staked | n | unresolved | gained | forfeited | net |
|------|--------|--:|-----------:|-------:|----------:|----:|
| 1v1 | airdrop | 104 | 95 (91%) | +5 | 0 | **+5** |
| 1v1 | staked | 9 | 8 | 0 | 1 | −1 |
| 2v2 | airdrop | 6 | 2 | +2 | 0 | **+2** |
| 2v2 | **staked** | 21 | 5 | 4 | **6** | **−2** |
| ffa4 | airdrop | 44 | 29 (66%) | +2 | 0 | **+2** |
| ffa4 | staked | 1 | 0 | 0 | 1 | −1 |

**Correction.** The earlier pass reported that the strategist was aiming most
staked invasions at FFA cells and recommended re-aiming them at `2v2`. The
board says the opposite: **21 of our 31 staked invasions already went to
`2v2`, and exactly one went to `ffa4`.** The problem is not which mode we
stake into, it is that we stake at all — staked invasions are **net −4
cells** while airdrops are **net +9 with zero forfeits, by construction**
(`engine.py:167-169`: an airdrop carries `source = None`, so `staked` is
false). Eight of the ten cells we have ever lost were forfeits from our own
attacks.

**Mechanism, from `strategist.py:30-58`.** Up to `max_invasions` (3) staked
attacks on adjacent cells; up to `max_airdrops` airdrops at ANY cell, staking
nothing; `min_airdrops` happen every round regardless, and a shortfall is
dropped on RANDOM cells. An `ffa4` loss hands the launching cell to whoever
tops the episode — including a recruit or Baseline that was never our
opponent.

**Acted on.** Our strategist prompt was still the league default
(87 characters, `"Expand cautiously..."`, `is_default: true`). It has been
replaced with one written from the table above: never stake into `ffa4`,
default to passing on staked invasions, always spend the airdrop, prefer
`2v2` and empty cells, do not trade cells with the leader. Reversible —
`POST /v2/leagues/{id}/campaign/prompt` with the original string restores it.

**What this does NOT change.** Territory remains invisible to the policy, so
the bot-side objective is unaltered and is confirmed rather than redirected by
this: **a drawn episode is worth zero territory to everyone**, and 91% of our
`1v1` and 66% of our `ffa4` attacks never resolved. Decisiveness — finishing
episodes instead of timing out — is exactly what
`analysis/paintbot.md`'s third pass identified from the other direction.

---

## Round 84 orders — I had been scoring the campaign on the wrong field

Standings at round 84: **daveey 76, us 8, richard 8, James Botts 7, Ari Sklar 1,
everyone else 0.** No unowned cells remain, so every future gain must be taken
off a current holder.

**The error.** Every previous read of our campaign record classified a battle by
`winner`. A conquest is recorded as `outcome: "conquered"` with **`winner:
null`** — the attacker takes the cell without any seat being named winner. So
`winner` scored our conquests as non-wins. On that field our attacking record
looked like 0 wins and 11 losses; on `outcome` it is **13 conquests off 191
attacks**, and the shape of the campaign is completely different.

**What the corrected numbers say.**

| lever | evidence |
| --- | --- |
| mode | 2v2 **45 attacks -> 11 conquests (24%)**; ffa4 47 -> 2 (4%); 1v1 **113 -> 0**, 109 unresolved |
| staking | staked 38 attacks -> 5 conquests against **9 forfeited launching cells**; every cell we ever lost through our own attacking was a staked forfeit |
| richard | our best lane, not our worst: **unstaked** 8 attacks -> 4 conquered, 0 forfeits; staked 20 -> 4 conquered, 3 forfeits; **9 of our 19 lifetime gains** came off richard, net **+4** cells |
| daveey | 12 attacks, 0 conquests, 5 repelled, 3 forfeits |
| Rohit | 14 attacks, 0 conquests, 13 unresolved |
| James Botts | 2 attacks, 0 conquests, **both staked, both forfeited** |

Mode is the largest lever on the board and no previous order mentioned it.

**Two reversals, stated plainly.** The orders now name richard as primary target
and demote James Botts, which inverts what I had written on both. The James
call rested on 6 episodes scored off `winner`. The richard call came from a real
observation — richard has taken 5 of our cells, more than anyone — but the
answer to that is *never stake against richard*, not *stop attacking richard*:
the losses came from staked forfeits and from richard's own attacks, never from
our airdrops, which are 4-for-8 with no downside.

Orders posted and read back at round 84. The standing rules are now: never
stake, never touch daveey, prefer 2v2 over everything, never touch a 1v1 cell,
and prefer ordering nothing over spending an airdrop badly.

### Round 86 refresh — the target list was naming players who own nothing

Two rounds ran under the round-84 orders. The strategist obeyed the new rules on
staking (zero invasions, airdrop only, both rounds) but produced one order that
broke two hard rules at once.

- **r84:** airdrop at 2,7 — a 2v2 cell owned by James Botts. Rule-compliant.
  Repelled.
- **r85:** airdrop at 7,4, reasoned as *"softmaxwell-adjacent territory near
  richard's cluster"*. **7,4 is a daveey ffa4 cell.** Forbidden owner and the
  4% mode, in one order. Repelled.

The r85 failure traces straight back to my own target list: it named
softmaxwell, Ari Sklar and NanosaurusX as priorities 2-4, and **all three now
hold zero cells**. Pointed at players who own nothing, the strategist reached
for something "near" them and landed on daveey. A priority list is only safe if
every name on it actually holds territory.

Board at round 86, with modes read correctly (`modes` is a positional list over
the 100 cells, not a dict — an earlier pass read it as a dict and got `None`
for every cell):

| holder | cells | modes |
| --- | --- | --- |
| daveey | 76 | 52 ffa4, 24 2v2 |
| richard | 9 | 6 2v2, 3 ffa4 |
| **us** | 8 | **all 2v2** |
| James Botts | 7 | **all 2v2** |

Everyone else: zero. Our entire frontier is daveey-owned, so no staked invasion
is legal even if we wanted one — airdrops are the only move on the board.

Orders now name the six richard 2v2 cells and the seven James 2v2 cells
explicitly, forbid richard's three ffa4 cells as right-player-wrong-mode, demand
the strategist state the owner and mode of the cell it picks, and say to order
nothing when no legal 2v2 target exists.

### Round 90 — the metric was wrong a second time, and `transfers` settles it

Four rounds ran under the round-86 orders. The strategist obeyed the staking and
mode rules every round. It still gained us nothing, and two of my own
instructions were at fault.

**`outcome: "conquered"` on our own attack does not mean we took the cell.**
Round 86: we airdropped 2,6, the battle recorded `outcome: "conquered"`, and the
transfer log shows the cell going **to daveey** (`why: "forfeiture"`,
`contested: 2`). 2,6 was richard's before and after. When two players invade one
cell in a round it is contested, and "conquered" only records that it fell.

So I have now had the metric wrong twice in opposite directions: `winner`
undercounted (it is null on conquests), and `outcome == "conquered"`
overcounts (it includes cells that fell to somebody else). The field that
cannot lie is **`transfers`** — a cell is ours when a transfer says
`to: <us>`. Everything below is counted that way.

**Lifetime on transfers: 19 gained, 12 lost, net +7.**

| | detail |
| --- | --- |
| gains, by source | **richard 9**, unowned 5, softmaxwell 3, NanosaurusX 1, James Botts 1 |
| gains, by mode | 2v2 11, ffa4 8, **1v1 0** |
| gains, by reason | conquest 11, claim 5, forfeiture 3 |
| losses, by reason | **forfeiture 9**, conquest 3 |
| losses, to | richard 5, daveey 4, James Botts 2, NanosaurusX 1 |

**Two corrections to my own previous orders.**

- *Banning ffa4 was wrong.* I wrote "only attack 2v2 cells" off a 24%-vs-4%
  split computed from `outcome`. On transfers, **8 of our 19 gains were ffa4
  cells**, four of them taken off richard. The rule was discarding a lane that
  works. What survives is the 1v1 ban: **113 attacks, zero cells**.
- *Hardcoded coordinate lists go stale within a round.* Ownership churns ~2.5%
  of cells per round, and the r86 list was wrong by r88. The strategist dutifully
  quoted it and misnamed the owner twice — calling 7,2 richard's and James
  Botts' on consecutive rounds when the defenders were richard, then Rohit
  Mukherjee. Orders now tell it to read the board and to believe the board over
  these orders when they disagree.

**What holds up unchanged:** never stake — **9 of our 12 lifetime losses were
launching cells forfeited by a failed staked invasion**, the largest and most
self-inflicted drain on us. And richard remains the primary target on the
strongest evidence on the board: 9 of 19 lifetime gains, more than every other
player combined. richard has taken 5 of our cells, but three of those were
forfeitures we handed over, not defensive losses.

### Round 94 — the orders were fine, the strategist cannot read the grid

Four rounds under the round-90 orders. Zero transfers in either direction. The
strategist obeyed every rule it understood — airdrop only, no staking, richard
named as the target every time — and still hit nothing, because **every
coordinate it ordered belonged to the wrong player**:

| round | ordered | it believed | actually |
| --- | --- | --- | --- |
| r90 | 9,7 | "richard's 9,7 (2v2)" | **ours** |
| r91 | 1,2 | no target reachable | daveey, ffa4 |
| r92 | 6,6 | "richard holds this frontier cell" | daveey, ffa4 |
| r93 | 2,3 | frontier is all daveey | daveey, ffa4 |

Reading `GET /campaign/full-prompt` shows why. The strategist is handed an ASCII
letter grid — `K` = richard, `H` = James Botts, `M` = daveey, `L` = us, `.` =
empty — with a column header row, plus a frontier list that is **entirely
daveey** and always will be, since daveey surrounds us completely. It anchors on
that frontier list and then miscounts columns when it tries to name a cell off
the grid.

So the failure was never target selection. Telling it *who* to attack was
already right; it could not turn a name into a correct coordinate.

Orders now give a checkable procedure instead of a target list: airdrops are not
adjacency-bound so ignore the frontier entirely; find a `K` in the grid; and
**before committing, quote the grid row verbatim and state the letter at the
chosen column** — if it is not `K`, `H` or `.`, the coordinate is wrong. The
prompt also now tells it to disregard the "MATCH RECORD BY OPPONENT" block the
platform injects: those are per-episode W-L counts (it currently reads "vs James
Botts 3W-1L, vs richard 1W-1L"), which point away from the player our transfer
record says is the only one we reliably take cells from.

Standing at round 94: daveey 78, richard 10, us 8, James Botts 4.

### Round 98 — the grid procedure worked, and we are second

First refresh that gets to report a gain. Three rounds after the round-94
orders replaced the target list with a **reading procedure**:

- **r95: took 7,4 from daveey** (ffa4, conquest)
- **r96: took 7,2 from richard** (2v2, conquest)

That ended four consecutive rounds in which every ordered coordinate belonged
to us or to daveey. The change that mattered was requiring the strategist to
quote the grid row and name the letter at its chosen column before committing.

Standing at round 97: **daveey 79, us 10, richard 9, James Botts 2.** We have
passed richard into second. Lifetime on transfers: **21 gained, 12 lost, net
+9**; richard is the source of 10 of the 21, more than every other player
combined.

**The no-stake rule is the strongest result on this board.** Nine of our twelve
lifetime losses were launching cells forfeited by failed staked invasions, and
**we have not lost a single cell in the twenty-one rounds since we stopped
staking.** Our last loss was round 76.

**One reversal: the absolute daveey ban is now a last-resort rule.** I had
written "never attack daveey" off 13 attempts and 0 cells. It is now 1 cell in
15 airdrops — still poor, but r95 shows it converts, and an airdrop is free: it
cannot cost us a cell. A guaranteed zero from ordering nothing is worse than one
chance in fifteen at no cost. So daveey stays off the *first* choice and off
staked invasions entirely, but beats an empty order.

Unchanged: never stake, never touch a 1v1 cell (113 attacks, zero cells),
richard first, and ignore the platform's injected per-episode W-L block.

### Round 101 — the relaxation backfired and we lost three cells

Last refresh reported two gains and second place. Both are gone. Standing at
round 100: **daveey 80, richard 9, James Botts 4, us 7** — third, down from ten
cells to seven.

**The losses were defensive, not self-inflicted.** r99 lost 7,4 to daveey and
7,9 to James Botts; r100 lost 7,8 to James Botts. All three by conquest while
defending, across seven defences in three rounds. So the claim in the last
refresh — "we have not lost a cell in twenty-one rounds" — no longer holds, and
it never covered defence in the first place. Not staking protects the cells we
launch from; it does nothing about being attacked. Nine of fifteen lifetime
losses are still forfeitures, so the no-stake rule stands, but it was never the
whole story and I let it read that way.

**My daveey relaxation was a mistake and is reverted.** I softened "never attack
daveey" to "last resort" on the strength of one conversion in fifteen. The
strategist promptly made daveey its default: it ordered **6,2 — a daveey cell —
in r98, r99 and r100, three rounds running**, while richard had nine cells
plainly visible on the grid. The permission was read as a preference. It is now
gated behind quoting that no `K`, `H` or `.` exists anywhere on the board, which
with richard on nine cells should never happen.

**New failure mode: repetition.** Nothing in the orders said not to re-order a
cell that had already failed, so it re-ordered the same one three times. Now
explicitly forbidden.

**New priority: 8,7 and 9,7.** James Botts took both from us and holds them
inside our own cluster; retaking one is a gain and a repair at once.

The lesson I keep re-learning here is that this strategist treats any permission
as a default. "Last resort" was heard as "allowed", and it stopped looking.

---

## Orders, round 122: the legend went stale and the old orders pointed at our own cells

The board restarted since round 101 and the symbols RE-DEALT: Jordan is now
`H`, daveey `K`, richard `L`, RowDaBoat `J`. The standing orders still carried
the old legend ("richard is K ... scan for H at 8,7 and 9,7 FIRST — retake"),
so the strategist was being told daveey's 84 K-cells were richard (attack
freely) and that our own H-cells were targets to "retake". Rounds 120-121 we
lost 7,7 and 7,2 to richard and 7,8 to daveey; we hold FOUR cells (5,7 / 7,6 /
8,8 / 9,8 — wire x,y), against daveey 84, richard 11, RowDaBoat 1.

The statistics that set the new targets (last 30 rounds of shared battles):
richard outscores us in **5 of 21**; daveey in **17 of 34**; nobody else in
any. Lifetime conquests: we took 9 cells from richard, he took 5 from us.
richard is the only profitable war on the board; daveey is a coin flip with
84 cells behind it.

New orders posted (r122, effective next round): the current-legend
verification first ("derive the legend ONLY from the players list you are
shown"), three hard prohibitions (never our own cells, never daveey, never
re-order an unfallen cell twice running), ONE ranked target list of richard's
holdings, adjacency-first — 6,7 and 7,7 border our cluster, so taking them
expands AND erases richard's border with us in the same move — then his
remainder by distance, RowDaBoat's far cell last. The grid-row-quote ritual
that produced the only past gains is kept verbatim. Coordinate care: the wire
speaks x,y (col,row) — RowDaBoat's r122 conquest of "0,6" sits at row 6,
col 0 of the row-major owners list; the first draft of these orders had the
axes flipped and a 422 on the body schema (player_id belongs in the JSON
body) caught it before anything shipped.

A 10-minute recurring update loop now owns this file's cadence (round
interval is 600s), replacing the hourly job. It is session-local; recreate it
if the session moves.
