# Handoff

Read this before touching anything. `README.md` says what the files are;
this says what will waste your time if nobody tells you.

## Where it stands

Champion is server **v9**, submitted and placed. Server tags are NOT the local
Docker tags — the Observatory assigns the next sequential version on upload no
matter what you called the image locally. The map is in `README.md`; check it
before referring to a version by number.

**Unfinished:** server v11 (attackers take the enemy-side plasma arc) was being
tested against v9 when this was packaged. One direction came back strongly for
v11 — 27-13, K/D 1.093 against 0.912 — and the second direction had not
returned. Do not ship it on that. One direction is exactly how this session
got its worst call wrong. Run the mirror, pool them, then decide.

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
- **Feeding intel into avoidance.** Sonar and memory only ever fed the
  `exposure` path, which makes the bot more timid; deaths rose with each
  intel addition. Perception needs a consumer that does not spend vision or
  nerve — target *selection* is the one that costs nothing.

Caveat on all of the above: several were measured against cross-time baselines
before rule 1 was understood, so the *numbers* are unreliable even where the
*mechanism* is sound. The arc and keeper results are solid (concurrent
head-to-heads). The pre-aim dose-response curve is not.

## Leads worth trying

- Finish the v11 mirror direction. Likely the cheapest real win on the table.
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
