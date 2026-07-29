# Handoff

Read this before touching anything. `README.md` says what the files are;
this says what will waste your time if nobody tells you.

## Where it stands

Champion is server **v9**, submitted and placed. Server tags are NOT the local
Docker tags — the Observatory assigns the next sequential version on upload no
matter what you called the image locally. The map is in `README.md`; check it
before referring to a version by number.

**Resolved — do not ship v11.** Server v11 (attackers take the enemy-side plasma
arc) is level with v9. The mirror direction returned and reversed the result the
first direction implied:

| direction | RED | RED record | RED K/D | BLUE K/D |
|---|---|---|---|---|
| `xreq_beadfec8` | v11 | 27-13 (67.5%) | 1.093 | 0.912 |
| `xreq_3d6b59e5` | v9 | 29-10 (74.4%) | 1.052 | 0.951 |

Each build wins big when it holds RED. **RED won 56 of 79 episodes (70.9%)
regardless of which build sat there** — the 27-13 was a side effect, not a build
effect. Pooled over both directions (`scripts/pool_h2h.py`), nothing separates:

- K/D: v11 1.020 vs v9 0.980, gap +0.041, 95% CI [−0.033, +0.114]
- Win rate: v11 46.8% vs v9 53.2%, gap −6.3%, 95% CI [−29.1%, +16.5%]
- Captures: 22 vs 23, gap −1, 95% CI [−14, +12]

All three cross zero, and K/D and win rate point in *opposite* directions — the
signature of no real difference. v9 stays champion. This is the second time the
arc has failed to pay (v10 was the keeper version, a clear regression); the
difference is that v11 is not harmful, just not an improvement.

The 39th episode of `xreq_3d6b59e5` failed — `Timed out waiting for game
container to finish writing episode artifact(s)`. That is harness flake, not a
bot crash: it produced no `results.json`, so it is excluded and that direction
pools 39 episodes rather than 40. It was not retried. One episode does not move
any of the intervals above.

## READ THIS FIRST: builds from this archive are ~0.40 K/D below v9

Measured, not suspected. `v27` is plain archive HEAD with **every** lever added
in the follow-up session forced off — nothing changed, nothing added — against
the real uploaded champion:

| build | what it is | K/D vs v9 | win rate |
|---|---|---|---|
| v27 | plain archive HEAD, all new levers off | **−0.401** | 25.0% |
| v26 | + aim fix, hold-line, cross-fire, stare-break | −0.309 | 16.2% |
| v25 | + look-around as well | −0.355 | 12.5% |

95% CI on v27 is [−0.485, −0.318]. The gap is not a behaviour problem and it is
not caused by any change made here — **it is present before any change is
applied.** Something about building this source in this environment produces a
materially weaker bot than the binary that was uploaded as v9.

Two consequences, and the second is the one that will waste your time:

1. **The archive is not the champion.** Do not treat a build from `bot/` as
   v9-equivalent, and do not assume `CTF_LEVER_ARCRAID=0` recovers v9. It does
   not — that assumption was made here and it was wrong by 0.4 K/D.
2. **Every A/B in the follow-up session was HEAD against HEAD.** Those
   comparisons are internally valid — same commit, both directions, same
   episodes — but they all sit on a floor 0.4 below the champion. A change that
   helps two weak builds beat each other need not help against a strong one,
   and `CTF_LEVER_HOLDLINE` is the worked example: +0.125 K/D against a HEAD
   control, and against v9 its captures collapse to 1 of 24. Holding your own
   half is affordable when the opponent also sits and ruinous when they push.

The stack does help *on that floor*: v27 −0.401 to v26 −0.309 is about +0.09
from the aim fix, hold-line, cross-fire and stare-break together, consistent
with their individual measurements. It just does not come close to closing 0.4.

**The next question is provenance, not behaviour.** Prime suspect is
dependencies: `nimby.lock` pinned exact versions and was not in the archive, so
this build used whatever `nimble install` gave for `pixie`, `supersnappy`,
`whisky` and `curly`. A protocol-decoding difference would degrade every
reading the bot makes without any visible error. Second suspect is source
drift — the archived `baseline.nim` is v11-era and may carry post-v9 changes
that were never individually measured. Get `nimby.lock`, rebuild with the
pinned set, and re-run `v?? vs v9` before spending another episode on
behaviour.

## The rules that were paid for

These are in `NOTES-dejitter.md` with the evidence. Short form:

1. **Only compare builds measured at the same time.** A pinned opponent list
   does not hold time still: the same policy against the same version-pinned
   field moved K/D 0.823 to 0.852 in a few hours, about thirty times the
   concurrent reproducibility. Any candidate-today-versus-baseline-yesterday
   comparison is noise wearing a number.
2. **Head-to-head, both directions, always.** Both builds in the same episodes,
   one per side, then swap and repeat. Everything that drifts drifts for both
   and cancels. One direction cannot separate "better build" from "better side".
   The side is worth a lot: over the 79-episode v11/v9 mirror, **RED won 70.9%
   of episodes whatever build held it**. A one-direction result has that baked
   into it and will read as a ~20 point build effect that does not exist.
3. **Read `RED_is` / `BLUE_is` from `ab_by_seat.py`, never the arm name.** The
   name is a label chosen at creation. A 33-7 arm was once read as the champion
   beating the candidate when it was the reverse, and the best build of the
   session was nearly discarded on it. The analyzer now reads seats out of the
   episode participants so this cannot recur — trust that field.
4. **Read K/D.** Two identical binaries scored 17.5% and 30.0% win rate over 40
   episodes each. Win rate needs roughly a twelve point gap to mean anything.
   Captures turn on five to thirteen events per arm — never settle a close call
   on captures.

## Verify mechanically before spending an A/B

Every lever is an env-var flag (`CTF_LEVER_*`, `CTF_FIX_*`), on by default, read
once at startup. `coworld run-episode ... --secret-env CTF_LEVER_X=0` toggles one
without a rebuild, so one instrumented image measures both arms.

Build with `--build-arg NIM_DEFINES=-d:leverDebug` and put `when
defined(leverDebug):` blocks in the hot path. Then confirm the change does what
you think BEFORE buying 80 episodes. This repeatedly paid:

- Identity badges looked broken (`arc=0 shield=0` all game). Dumping every
  distinct badge label across all 16 viewpoints found `identity red eta nade
  gun` — the parser was right, arcs and shields are just genuinely rare.
- Pre-aim was blamed on turret churn. Measuring said only 6% of ticks moved the
  bearing more than 8 brads. Hypothesis dead, cheaply.
- Grenade farming was verified as pickups 4 to 16 before any league run.

A local `run-episode` puts YOUR policy in all 16 slots, both teams. Good for
mechanism, useless for strength.

`dockerd` is not running at session start and dies with the container. Start it
before building.

## Game facts dug out of the server source

Expensive to rediscover, all confirmed in `source/coworld-ctf/src/ctf/`:

- **Grenades ignore walls twice over.** Flight is a straight line over
  everything, and the blast is a bare radius test with **no wall check and no
  team check** — 2 of 3 HP to everyone within 52px, through cover, teammates and
  thrower included. Cover is worth nothing against them. `nadeSafe` in the bot
  is the only thing preventing self-slaughter; keep it if you widen throwing.
- **The plasma arc REPLACES the gun**, it does not add to it. 3 HP on contact
  kills outright, but carrying one collapses engagement range to about four
  squares. It suits an attacker at the flag scrum and ruins a defender, which
  is why keepers are excluded from picking it up. That exclusion is deliberate.
  Do not "fix" it — it was tried, it cost 3x the captures.
- **Shot-impact rings ignore walls and fog entirely** and go to every living
  player. The only map-wide sense available. Jitter is invertible; see
  `NOTES-dejitter.md`.
- **Object ids in the recent-shot pool are ARRAY INDICES** and the array is
  pruned from the front, so one shot slides down through several ids and reads
  as several new events. Dedupe sonar rings by POSITION, never by object id.
  This silently corrupted the sonar and broke the first jitter calibration.
- **Identity badges are fog-gated** but their object id is `19040 + player
  index`, a stable name for that soldier all match. Absent while dead (ghost
  frames carry bodies but no badges and no hp pips).
- **The scoreboard is ungated** — the one honest count of the whole map.
- Pickup supply per ~100s match: grenades ~80 (4 spawns, 5s), everything else
  ~7 (2 spawns, 30s).

## Tried and failed — don't re-propose without new reasoning

- **Wide pre-aim** (turret anticipates off the movement lane). Aim and vision
  are the same resource in this game; every brad spent anticipating is bought
  with blindness. Narrower arcs hurt less, which is the tell.
- **Keeper farms the friendly plasma arc.** Regression, both directions,
  captures fell 3x. Cause above.
- **Shout-Intel** (`-d:shoutIntel`, `NOTES-shoutintel.md`): teammates gossip
  sightings, deaths and resource pickups as 10-char shouts. Measured both
  directions against an identical control build (v13 vs v12, 80 episodes):
  **K/D 0.959 against 1.043, a 0.083 loss**, P(gap ≤ 0) ≈ 0.02, with win rate
  agreeing in sign. Marginal but real, and the mechanism fits — it shouts at
  nearly the 1/s limit from every seat, so every flanker broadcasts its
  position to ±20px all game. The protocol itself is correct (54,800 invariant
  checks) and the code is still there behind the define; it is the SEND POLICY
  that does not pay. Shouting rarely — heart-carrier sightings only — was
  never tried and is a different question.
- **Feeding intel into avoidance.** Sonar and memory only ever fed the
  `exposure` path, which makes the bot more timid; deaths rose with each
  intel addition. Perception needs a consumer that does not spend vision or
  nerve — target *selection* is the one that costs nothing.

Caveat on all of the above: several were measured against cross-time baselines
before rule 1 was understood, so the *numbers* are unreliable even where the
*mechanism* is sound. The arc and keeper results are solid (concurrent
head-to-heads). The pre-aim dose-response curve is not.

## Leads worth trying

- Shields sit at ~13% take rate, but they triple gun cooldown — unlike the arc
  this is genuinely ambiguous, so measure before assuming more is better.
- The jitter inversion resolves ~38% of shot landings to the exact pixel and
  currently only feeds avoidance. Its value has never been isolated.
- Grenade targeting still ignores the sonar's `foe` pings beyond a short TTL.

## About the prose in this repo

The comments and notes were written by an agent that got four confident
behavioural predictions wrong this session and had to retract them. The
mechanisms described from the server source are reliable — they were read out
of the code. The claims about what will help are not, unless a both-directions
head-to-head is cited next to them. Trust the code and the measurements over
the narrative, including this file.

## Queued, not yet started

Three requests logged during the session, in the order they were raised.
None is implemented; each needs its own both-directions head-to-head.

1. **Staring contests still happen.** `CTF_FIX_AIMBAND` made the *aim* stall
   unrepresentable (31 stalled ticks -> 0, one binary, lever toggled) but that
   was only one of the two causes identified in `NOTES-combat.md`. The second
   is still there and was never touched: the anti-stuck jink is gated
   `if bot.stuckTicks > 20 and engage < 0`, so while a target is held the
   unsticking burst is disabled and anything that pins the bot keeps it
   pinned. That is the remaining path to a bot frozen in front of an enemy.
   Fixing it means letting the jink fire while engaged, which trades a settled
   aim for movement -- measure it, do not assume it.

2. **Flag carriers walk into enemies.** The carrier route is chosen by
   `safestLaneY` plus the path field's exposure cost, which is about
   REMEMBERED enemies and lane traffic; there is no rule that says "do not
   path through a body you can see right now". A carrier has one job and
   dying with the flag undoes the whole steal, so carrier pathing should
   treat a visible enemy as near-impassable rather than merely expensive.

3. **Sight lines and cross-fires.** The bot has no concept of holding an
   angle: `findPeekCell` and `findDuckCell` reason about a single line to a
   single target, and nothing reasons about which cells COVER an approach, or
   about two teammates covering the same approach from different bearings.
   This is the largest of the three by far and probably wants a precomputed
   per-cell visibility summary rather than another per-frame ray walk.
   Related and already measured: `CTF_LEVER_HOLDLINE` (+0.125 K/D) is the
   crude version of "stop pushing while the match is even" and is the natural
   thing to build this on top of -- its `HoldLineKills = 6` threshold was
   picked by reasoning and has never been swept.
