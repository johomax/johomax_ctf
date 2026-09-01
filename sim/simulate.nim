## The local CTF simulator: real engine, real wire, real policy, no network.
##
## `coworld run-episode` needs a Docker daemon, seventeen containers and a
## server that paces itself against the wall clock. An XP request needs the
## league. Neither is a good way to ask "does this change do what I think it
## does" a hundred times. This binary answers that question by linking the
## three pieces that actually matter into one process:
##
## - the REAL engine (`ctf/sim` from a pinned coworld-ctf checkout), stepped
##   directly through the `step(inputs, prevInputs)` entry point the server
##   and the replay player both use;
## - the REAL observation, built by the server's own
##   `buildSpriteProtocolPlayerUpdates` and handed to the policy as the same
##   sprite-protocol bytes a websocket would have carried, fog and aim fuzz
##   included -- there is no second implementation of what a player can see;
## - the REAL policy, compiled from the tree under test and decoding those
##   bytes through its own `protocols.nim`.
##
## What is left out is the transport and the clock. That buys roughly three
## orders of magnitude, and it costs the two things named in `sim/README.md`:
## the policy never misses a frame, and grader/commissioner scoring is not
## modelled. Read those before quoting a number from here.
##
## Seats are assigned per episode from a build string, one character per slot
## ('a'..'d'), so one binary runs the mirror both ways -- or, on a four-team
## Paintbot board, seats up to four entrant policies at once.

import
  std/[json, os, strformat, strutils],
  bitworld/[profile, spriteprotocol],
  ctf/[sim, global],
  a/host as buildA,
  b/host as buildB

const SimBuilds* {.intdefine: "simBuilds".} = 2
  ## How many policy trees `build.sh` laid out beside this file. Two is the
  ## CTF mirror and costs what it always did; three and four exist because a
  ## Paintbot episode seats FOUR entrant policies and a faithful measurement
  ## may want four distinct ones. Guarded by `when` rather than always
  ## compiled, because each extra tree is a whole extra module set: unused
  ## trees would be compile time every head-to-head pays for nothing.

when SimBuilds >= 3:
  import c/host as buildC
when SimBuilds >= 4:
  import d/host as buildD

## Profiling: build with -d:ProfileTracePath=<out.json> (via SIM_NIM_FLAGS)
## and every {.measure.}'d proc in the engine and the policy records into a
## fluffy Chrome-trace (github.com/treeform/fluffy). SIM_TRACE_FROM/_TO bound
## the traced tick window, since a whole episode of events is gigabytes.
## fluffy echoes on stdout, so profile manually, not through local_sim.py.

type
  Seat = object
    ## A hosted policy instance, behind the build it came from. The two hosts
    ## are separate types from separate module trees, so the only thing they
    ## can share is this closure pair.
    build: string
    onPacket: proc(packet: seq[uint8]): uint8 {.closure.}
    takeShout: proc(): string {.closure.}
    describe: proc(): string {.closure.}

# One constructor per tree, spelled out rather than generated: a module alias
# cannot be a template parameter (`host.newSeat` is not a dot expression Nim
# will accept from an `untyped`), and that qualification is the whole point --
# it is what binds each closure to its own tree's module-level state.
proc seatA(slot: int): Seat =
  let seat = buildA.newSeat(slot)
  Seat(
    build: "a",
    onPacket: proc(packet: seq[uint8]): uint8 = buildA.onPacket(seat, packet),
    takeShout: proc(): string = buildA.takeShout(seat),
    describe: proc(): string = buildA.describe(seat)
  )

proc seatB(slot: int): Seat =
  let seat = buildB.newSeat(slot)
  Seat(
    build: "b",
    onPacket: proc(packet: seq[uint8]): uint8 = buildB.onPacket(seat, packet),
    takeShout: proc(): string = buildB.takeShout(seat),
    describe: proc(): string = buildB.describe(seat)
  )

when SimBuilds >= 3:
  proc seatC(slot: int): Seat =
    let seat = buildC.newSeat(slot)
    Seat(
      build: "c",
      onPacket: proc(packet: seq[uint8]): uint8 = buildC.onPacket(seat, packet),
      takeShout: proc(): string = buildC.takeShout(seat),
      describe: proc(): string = buildC.describe(seat)
    )

when SimBuilds >= 4:
  proc seatD(slot: int): Seat =
    let seat = buildD.newSeat(slot)
    Seat(
      build: "d",
      onPacket: proc(packet: seq[uint8]): uint8 = buildD.onPacket(seat, packet),
      takeShout: proc(): string = buildD.takeShout(seat),
      describe: proc(): string = buildD.describe(seat)
    )

proc newSeatFor(build: char, slot: int): Seat =
  ## Maps an `--assign` character to the tree that holds that seat. A character
  ## past what this binary was built with is fatal rather than silently folded
  ## back onto 'a': an episode that quietly ran four copies of one build would
  ## report a flat zero and look like a measurement.
  if build == 'a': return seatA(slot)
  if build == 'b': return seatB(slot)
  when SimBuilds >= 3:
    if build == 'c': return seatC(slot)
  when SimBuilds >= 4:
    if build == 'd': return seatD(slot)
  quit("--assign asks for build '" & build & "' but this binary holds only " &
    $SimBuilds & " policy trees; rebuild with sim/build.sh --tree-c/--tree-d", 2)

proc anyBuildReadsLabel(label: string): bool =
  ## The union over every tree in this binary. The packet a seat gets must
  ## never depend on which build the OTHER seats are running -- see the
  ## `spriteObservedHook` comment in `runEpisode`.
  result = buildA.readsLabel(label) or buildB.readsLabel(label)
  when SimBuilds >= 3:
    result = result or buildC.readsLabel(label)
  when SimBuilds >= 4:
    result = result or buildD.readsLabel(label)

proc totalCaptures(sim: SimServer): int =
  for player in sim.players:
    result += player.captures

proc ending(sim: SimServer, endedOnCapture: bool): string =
  ## Which of the three terminations fired.
  ##
  ## `endedOnCapture` is "a capture landed on the tick that reached GameOver",
  ## not "a capture happened at all". The two agree on a two-team board, where
  ## capturing the only rival heart eliminates the only rival team and ends the
  ## game on the spot -- but on a four-team board a capture eliminates ONE team
  ## and play continues (`checkWinCondition`, sim.nim), so an episode can carry
  ## captures and still end by wipe or on the clock.
  ##
  ## A mutual wipe stays "wipe" and is told apart by the record's `draw` flag,
  ## which is how this has always read on two teams.
  if sim.phase != GameOver: "unfinished"
  elif sim.timeLimitReached: "timeout"
  elif endedOnCapture: "capture"
  else: "wipe"

proc parseConfig(configJson: string): GameConfig =
  ## The config every episode of this process runs, parsed ONCE.
  ##
  ## `update` is not the cheap JSON read its name suggests. On a `mapPath:
  ## "gen"` variant -- which is every Paintbot board -- it RESOLVES THE MAP:
  ## it runs the generator, validates the draw (retrying seeds until one
  ## passes), and pins the winner into `config.mapSpec` as JSON so a replay
  ## carries the exact geometry and playback never re-runs the generator.
  ## That is the dearest thing a Paintbot episode used to set up, and it was
  ## paid per episode for an answer that is a pure function of THIS STRING:
  ## the map is drawn from the seed the JSON carries, and `runEpisode` sets
  ## the episode's own seed afterwards precisely so a config seed cannot
  ## clobber it. So every episode of a process regenerated, revalidated and
  ## re-serialized the identical terrain -- 0.3 s an episode on `4ffa`, 2.7 s
  ## on the giant `4ffa8` board, none of it visible to a fluffy profile
  ## because `update` carries no `{.measure.}` mark and none of it inside the
  ## engine's own `MapBake` cache, which starts one call later.
  ##
  ## Hoisting it here changes nothing about what runs: the terrain a Paintbot
  ## episode plays on was already fixed for the whole run by the config file
  ## rather than by the episode seed (the seed still draws spawns, and every
  ## other roll of the episode), and that is upstream's design, not this
  ## tool's. It is worth knowing when reading a Paintbot number: seeds vary
  ## the game on ONE board, and `--config` is what varies the board.
  result = defaultGameConfig()
  if configJson.len > 0:
    result.update(configJson)

proc runEpisode(
  baseConfig: GameConfig,
  seed: int,
  assign: string,
  tickCap: int
): JsonNode =
  ## Runs one episode start to finish and returns its record. `baseConfig` is
  ## parsed once per process; see `parseConfig`.
  var config = baseConfig
  # Set after the parse, so a seed in the config file cannot clobber the one
  # this episode was asked for.
  config.seed = seed

  var sim = initSimServer(config)
  sim.gameEventLoggingEnabled = false

  # Headless observation: tell the engine which sprite labels the policies on
  # this wire can actually read, so it stops building the ones they cannot.
  # The union of BOTH builds, because one binary holds two policy trees and
  # the packet a seat gets must never depend on which build the OTHER seats
  # are running -- an A/B where a is starved of a family b receives would be
  # measuring the plumbing.
  #
  # This changes what is SENT, never what is OBSERVED: a suppressed sprite is
  # one whose definition the policy's frame index drops on arrival (see
  # host.nim's readsLabel), and the objects that reference it are still
  # placed and still dropped, for the same reason, at the same point. The one
  # emitter that also drops its objects is the fog overlay, which emits a
  # single label and so cannot drop half of one; it argues the case at its
  # own definition. The check is the six-seed gameHash comparison, same as
  # every other pass.
  #
  # `when declared`, because the hook comes from engine-patches/perf.patch and
  # a CTF_ENGINE_DIR checkout is deliberately never patched: pointed at a
  # stock engine this still builds and still runs, it just draws the whole
  # game to nobody again.
  when declared(spriteObservedHook):
    spriteObservedHook = anyBuildReadsLabel

  # A short --assign would seat fewer than the roster the config declares,
  # which starts a game the league never runs and quietly changes every number
  # that comes out of it.
  if config.slots.len > 0 and assign.len != config.slots.len:
    quit("--assign has " & $assign.len & " seats but the config declares " &
      $config.slots.len, 2)

  var seats: seq[Seat] = @[]
  for slot in 0 ..< assign.len:
    let name =
      if slot < config.slots.len and config.slots[slot].name.len > 0:
        config.slots[slot].name
      else:
        "player" & $(slot + 1)
    # A DISTINCT name per seat, which the engine also uses as the reward
    # account key (`addPlayer` -> `ensureRewardAccount`). Two seats sharing a
    # name would share an account, and `player.reward` -- the pot score this
    # record reports -- would come back as the sum of both.
    discard sim.addPlayer(name, requestedSlot = slot, trusted = true)
    seats.add(newSeatFor(assign[slot], slot))
  sim.startGame()

  var
    inputs = newSeq[InputState](seats.len)
    prevInputs = newSeq[InputState](seats.len)
    viewers = newSeq[PlayerViewerState](seats.len)
    ticks = 0
    captures = 0            # total captures as of the end of the last tick
    endedOnCapture = false  # ... and whether the LAST tick added one

  when ProfileTracePath.len > 0:
    let
      traceFrom = getEnv("SIM_TRACE_FROM", "0").parseInt
      traceTo = getEnv("SIM_TRACE_TO", $tickCap).parseInt
  while sim.phase != GameOver and ticks < tickCap:
    when ProfileTracePath.len > 0:
      if ticks == traceFrom: setTraceEnabled(true)
      if ticks == traceTo: setTraceEnabled(false)
    for i in 0 ..< seats.len:
      var nextViewer: PlayerViewerState
      let packet = sim.buildSpriteProtocolPlayerUpdates(i, viewers[i], nextViewer)
      viewers[i] = nextViewer
      # Build the frame, decide, then step -- the server's own order, and at
      # the league's `speed: 1` its own cadence too: one observation per sim
      # step, and the mask a seat derives from state S is the mask that
      # advances S. What the server does that this cannot is give up waiting;
      # see sim/README.md on frames a hosted policy never gets to answer.
      inputs[i] = decodeInputMask(seats[i].onPacket(packet))
    # The shout channel. The server collects chat off the sockets between
    # gathering the masks and stepping, and applies it there
    # (`src/ctf/server.nim`, the `applyShout` loop); do the same, in slot
    # order — the server iterates a hash table, so it has no order worth
    # reproducing, and slot order is the one that reproduces itself. A shout
    # is gameplay state (`recentShouts` is in `gameHash`), so this is a real
    # part of the episode and not a debug channel: with no policy shouting,
    # nothing is applied and the hash is unchanged.
    for i in 0 ..< seats.len:
      let text = seats[i].takeShout()
      if text.len > 0:
        sim.applyShout(i, text)
    sim.step(inputs, prevInputs)
    prevInputs = inputs
    inc ticks
    let nowCaptures = sim.totalCaptures()
    endedOnCapture = nowCaptures > captures
    captures = nowCaptures

  var seatsJson = newJArray()
  for i in 0 ..< seats.len:
    let
      player = sim.players[i]
      aliveTicks =
        if player.alive: sim.tickCount else: player.lastDeathTick
    seatsJson.add(%*{
      "slot": i,
      "build": seats[i].build,
      "team": teamText(player.team),
      "kills": player.kills,
      "deaths": player.deaths,
      "captures": player.captures,
      "lives": player.lives,
      "alive": player.alive,
      # The death tick, or the final tick for a survivor.
      "aliveTicks": aliveTicks,
      # The raw team ledger. The league banks it only for the winning team.
      "glory": sim.teamGlory[player.team],
      # The engine's OWN end-of-game award, not a rule reimplemented here:
      # `finishGame` writes classic (+1 per losing team / -1) or pot (+teams to
      # the winner, -(teams div loserTeams) to each loser) into the seat's
      # reward account, and a time-limit draw pays TimeoutReward to everybody.
      # Whatever `sim/*.json` asks for under `scoring`, this is what it paid.
      # Zero on an unfinished episode, which is why `finished` is reported.
      "reward": player.reward,
      "shotsFired": player.shotsFired,
      "shotsHit": player.shotsHit
    })

  # Per team, because on a four-team board the team is the unit the league
  # pays: every seat of a team takes the same pot score, and an entrant holds
  # a team (4ffa) or half of one (2v2). Only the ACTIVE teams -- the engine
  # seats a prefix of the enum, so a two-team game reports exactly red/blue.
  var teamsJson = newJArray()
  var placements: array[Team, int]
  if config.brMode:
    placements = sim.brPlacements()
  for team in sim.teams():
    var
      kills, deaths, teamCaptures, shotsFired, shotsHit, score = 0
      builds: seq[string] = @[]
    for i in 0 ..< seats.len:
      let player = sim.players[i]
      if player.team != team: continue
      kills += player.kills
      deaths += player.deaths
      teamCaptures += player.captures
      shotsFired += player.shotsFired
      shotsHit += player.shotsHit
      score = player.reward       # one award per team, so every seat has it
      if seats[i].build notin builds: builds.add(seats[i].build)
    teamsJson.add(%*{
      "team": teamText(team),
      "kills": kills,
      "deaths": deaths,
      "captures": teamCaptures,
      "shotsFired": shotsFired,
      "shotsHit": shotsHit,
      "livesLeft": sim.teamLivesRemaining(team),
      "score": score,
      "glory": sim.teamGlory[team],
      "placement": (if config.brMode: placements[team] else: 0),
      "builds": builds
    })

  %*{
    "seed": seed,
    "assign": assign,
    "ticks": ticks,
    "gameTicks": sim.tickCount,
    "teams": sim.gameMap.teamCount(),
    "scoring": config.scoring,
    "layout": $sim.gameMap.layout,
    "mapPath": config.mapPath,
    "ending": sim.ending(endedOnCapture),
    "draw": sim.isDraw,
    # A tick-capped episode never reached `finishGame`, so every reward in it
    # is 0 -- a number that looks exactly like a real pot score and is not one.
    # The pooler drops these loudly rather than averaging them in.
    "finished": sim.phase == GameOver,
    "winner": (if sim.isDraw or sim.phase != GameOver: "none"
               else: teamText(sim.winner)),
    "gameHash": $sim.gameHash(),
    "teamStats": teamsJson,
    "seats": seatsJson
  }

proc usage() =
  echo """
usage: simulate --engine DIR [options]

  --engine DIR     coworld-ctf checkout (needs data/ for the map bake)
  --config FILE    game config JSON (default: the engine's own defaults)
  --seeds A,B,..   explicit seed list
  --seed N         first seed, with --count
  --count N        how many episodes from --seed (default 1)
  --assign STR     one char per slot, 'a'..'d' (default: 16 x 'a'); how many
                   of the four this binary holds is a build-time choice, see
                   sim/build.sh --tree-c/--tree-d
  --tick-cap N     hard stop, in ticks (default 20000)
  --quiet          suppress the per-episode progress line on stderr

Writes one JSON record per episode to stdout, one per line."""

when isMainModule:
  var
    engineDir = ""
    configPath = ""
    seedList: seq[int] = @[]
    firstSeed = 1
    count = 1
    assign = repeat('a', 16)
    tickCap = 20000
    quiet = false
    args = commandLineParams()
    i = 0

  while i < args.len:
    let flag = args[i]
    if flag == "--quiet":
      quiet = true
      inc i
      continue
    if flag == "-h" or flag == "--help":
      usage()
      quit(0)
    if i + 1 >= args.len:
      quit("missing value for " & flag, 2)
    let value = args[i + 1]
    case flag
    of "--engine": engineDir = value
    of "--config": configPath = value
    of "--seeds":
      for part in value.split(','):
        if part.strip().len > 0: seedList.add(part.strip().parseInt())
    of "--seed": firstSeed = value.parseInt()
    of "--count": count = value.parseInt()
    of "--assign": assign = value
    of "--tick-cap": tickCap = value.parseInt()
    else: quit("unknown argument: " & flag, 2)
    i += 2

  if engineDir.len == 0:
    usage()
    quit("--engine is required", 2)
  if seedList.len == 0:
    for n in 0 ..< count:
      seedList.add(firstSeed + n)
  for c in assign:
    if c notin {'a' .. char(ord('a') + SimBuilds - 1)}:
      quit("--assign takes 'a'..'" & char(ord('a') + SimBuilds - 1) &
        "' in this binary, got '" & c & "'", 2)

  let configJson =
    if configPath.len > 0: readFile(absolutePath(configPath)) else: ""

  when ProfileTracePath.len > 0:
    startProfileTrace()
    # A NEGATIVE SIM_TRACE_FROM traces from process start, which is the only
    # way to see the per-episode setup — initSimServer's map bake and the
    # first frame's init snapshot both run before tick 0, so the tick window
    # below cannot arm early enough to cover them. Otherwise: armed by the
    # tick window, since a whole episode of events is gigabytes.
    setTraceEnabled(getEnv("SIM_TRACE_FROM", "0").parseInt < 0)

  # `initSimServer` bakes the map and loads fonts and sprite sheets relative to
  # the current directory, so the engine checkout has to BE the working
  # directory -- the same reason every upstream tool and test does this.
  engineDir = absolutePath(engineDir)
  if not dirExists(engineDir / "data"):
    quit("no data/ under " & engineDir & ": not a coworld-ctf checkout", 2)
  setCurrentDir(engineDir)

  let baseConfig = parseConfig(configJson)

  for seed in seedList:
    let
      record = runEpisode(baseConfig, seed, assign, tickCap)
      ending = record["ending"].getStr
      winner = record["winner"].getStr
      ticks = record["ticks"].getInt
    echo $record
    if not quiet:
      stderr.writeLine(
        &"seed {seed} assign {assign} -> {ending} {winner} in {ticks} ticks")

  when ProfileTracePath.len > 0:
    finishProfileTrace()
  # `declared` as well as `defined`, matching the hook above: -d:dumpLabels
  # against a stock CTF_ENGINE_DIR is then a quiet no-op rather than a
  # compile error about a symbol the patch would have supplied.
  when defined(dumpLabels) and declared(dumpLabelVocab):
    dumpLabelVocab()
