# Handoff

Read this before touching anything. `README.md` says what the files are;
this says what will waste your time if nobody tells you.

## READ FIRST: every lever below was re-measured on v29+. See `NOTES-abv2.md`.

Thirteen experiments, both directions, 40 episodes a side, on images built
through the restored `nimby.lock` so the bot can actually throw a grenade.
Anything in this file that cites a v12–v27 number is superseded. Short form:

- **Nothing in the queue is shippable.** Eleven of thirteen are level.
- **`CTF_LEVER_ODDS` is a real regression**, −0.139 K/D, CI [−0.218, −0.061],
  both directions agreeing. Leave it off.
- **`CTF_LEVER_HOLDEVEN` is the only positive**, +0.109 against a hold-line
  control — but marginal, and being re-measured against the champion.
- **`CTF_LEVER_HOLDLINE`'s +0.125 is gone** (+0.009, CI crosses zero). It was
  the one recorded improvement in this repo and it was a gun-only artifact.
- **`CTF_LEVER_NADEDUCK`'s −0.124 is gone** (+0.030, CI crosses zero). The old
  arm gave up a shot to lob a grenade that the build then deleted.
- **The Shout-Intel family is level**, not the "marginal but real" −0.083
  recorded below — `-d:shoutIntel` level over 160 episodes, and both send
  policies level.
- **n=80 is not enough for a marginal call.** A −0.076 CI [−0.150, −0.0011]
  "regression" on 80 episodes became level on 160. See `NOTES-abv2.md`.

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

## READ THIS FIRST: the ~0.40 K/D gap is RESOLVED — rebuilds could not throw grenades

The measurement stands (v27, plain archive HEAD, all new levers off, −0.401
K/D vs v9, 95% CI [−0.485, −0.318]) and the cause is found, verified at the
wire, and fixed in this tree. Full story and evidence: `NOTES-provenance.md`.
Short form:

- The lost `nimby.lock` pinned MORE than dependency versions — its first line
  pinned **the engine itself**: `bitworld 5d229ac`, a commit on branch
  `daveey/hd-client-pin` that is **not on bitworld master**. That lineage
  passes all 8 input-mask bits; master ANDs the mask with `0x7f`, which
  silently deletes **ButtonC (bit 128) — the grenade throw** — from every
  packet while keeping it structurally valid. The follow-up session cloned
  master, so v12–v27 pressed the button 35 times a match and never once threw.
  v9's headline feature ("grenade memory, friendly-fire guard, grenade
  farming") was amputated by the build, with no error anywhere.
- Verified locally with two builds differing only in the bitworld commit:
  the server-side replay records **38 of 8608** received inputs carrying
  bit 128 for the pinned build, **0 of 8396** for the master build
  (`scripts/buttonc_probe.nim`).
- The dependency-version theory (pixie/supersnappy/whisky/curly) was checked
  first and refuted — see `NOTES-provenance.md` before re-suspecting it.
- Fixed here: `bot/nimby.lock` restored (it is coworld-ctf's own lock —
  the original project root was a `Metta-AI/coworld-ctf` checkout, fork base
  commit `5997098`); `ButtonC` is now imported instead of locally redefined,
  and a compile-time assert makes the wrong engine FAIL THE BUILD instead of
  silently regressing; `bot/Dockerfile.sandbox` is rewritten to a recipe
  verified end-to-end in this sandbox.

Two consequences for reading the follow-up results:

1. **Every A/B in the follow-up session (v12–v27) ran grenade-blind on both
   sides.** Internally valid, but measured in a gun-only meta. None of the
   numbers transfer, `CTF_LEVER_HOLDLINE` +0.125 first among them — holding
   your half is far cheaper when nobody can lob over walls. The NADEDUCK
   "regression" is retro-explained (the lob was a no-op; its disengage cost
   was real), and the Shout-Intel sizes need re-measuring even though the
   proposed mechanism is grenade-independent.
2. **The confirmation ran, and the pin closes the whole gap.** v28 (the
   pinned rebuild of the same source, same v27 config) pooled LEVEL with v9
   over both directions, 80 episodes, zero failures: **K/D gap +0.021, 95%
   CI [−0.056, +0.098]**, win rate and captures also crossing zero —
   −0.401 to +0.021 with one variable changed, the bitworld commit.
   Requests `xreq_f727811a` / `xreq_ee04dc1f`. The archive plus
   `bot/nimby.lock` is a faithful champion base again; v9 stays champion
   (v28 is v11-config, and like v11 it is level, not ahead).

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
  sightings, deaths and resource pickups as 10-char shouts. The v13-vs-v12
  measurement recorded here was **K/D 0.959 against 1.043, a 0.083 loss**,
  P(gap ≤ 0) ≈ 0.02 — "marginal but real". **That is retired.** It was
  measured grenade-blind, and re-run on a correct build the whole family is
  level: `-d:shoutIntel` −0.039 over 160 episodes, CI [−0.091, +0.014]; the
  shout-only-when-seen send policy level; spawn intel level. The protocol is
  still correct (54,800 invariant checks) and the position-leak mechanism is
  still plausible — it just does not show up in K/D either way. See
  `NOTES-abv2.md`.
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

## Queued — ALL THREE ARE NOW IMPLEMENTED AND MEASURED

All three were built as levers and run as both-directions head-to-heads on
v29+ (`NOTES-abv2.md`). **All three are level.** The descriptions below are
kept because the mechanisms are accurate and worth knowing; the "not yet
started" framing is not. Per item: (1) `CTF_FIX_STAREBREAK`, −0.003, the
flattest result in the whole queue; (2) `CTF_LEVER_CARRIERSHY`, −0.016 on K/D
with captures +4 the right way but nowhere near separable — and read the power
caveat in `NOTES-abv2.md` before treating that null as settled, because the
lever only acts while carrying; (3) `CTF_LEVER_CROSSFIRE`, −0.029.

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

   **Update from the v29+ re-measurement.** The crude version was built and
   measured: `CTF_LEVER_CROSSFIRE` stands on an angle nobody else covers, and
   it is level (−0.029, CI [−0.100, +0.046]) against a hold-line control. It
   is not a lever that failed to fire — the instrumentation counted 573
   attempts and 494 posts actually taken. And the foundation this was to be
   built on is gone: `CTF_LEVER_HOLDLINE`'s +0.125 was a grenade-blind
   artifact and re-measures at +0.009, CI crossing zero. `HoldLineKills = 6`
   is still unswept, but sweeping a threshold inside a lever that does
   nothing is not obviously worth the episodes.
