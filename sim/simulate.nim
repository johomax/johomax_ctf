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
## ('a' or 'b'), so one binary runs the mirror both ways.

import
  std/[json, os, strformat, strutils],
  bitworld/[profile, spriteprotocol],
  ctf/[sim, global],
  a/host as buildA,
  b/host as buildB

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
    onPacket: proc(packet: string): uint8 {.closure.}
    describe: proc(): string {.closure.}

proc seatA(slot: int): Seat =
  let seat = buildA.newSeat(slot)
  Seat(
    build: "a",
    onPacket: proc(packet: string): uint8 = buildA.onPacket(seat, packet),
    describe: proc(): string = buildA.describe(seat)
  )

proc seatB(slot: int): Seat =
  let seat = buildB.newSeat(slot)
  Seat(
    build: "b",
    onPacket: proc(packet: string): uint8 = buildB.onPacket(seat, packet),
    describe: proc(): string = buildB.describe(seat)
  )

proc teamName(team: Team): string =
  if team == Red: "red" else: "blue"

proc ending(sim: SimServer, captures: int): string =
  ## Which of the three terminations fired. A capture is decisive and ends the
  ## game outright, so any capture at all names the ending; the clock draw is
  ## flagged by the sim; anything else that reached GameOver is a wipe.
  if captures > 0: "capture"
  elif sim.timeLimitReached: "timeout"
  elif sim.phase == GameOver: "wipe"
  else: "unfinished"

proc runEpisode(
  configJson: string,
  seed: int,
  assign: string,
  tickCap: int
): JsonNode =
  ## Runs one episode start to finish and returns its record.
  var config = defaultGameConfig()
  if configJson.len > 0:
    config.update(configJson)
  # After `update`, so a seed in the config file cannot clobber the one this
  # episode was asked for. (Only matters for `mapPath` gen/pool, where the
  # terrain derives from the seed inside `update`; the league runs "arena".)
  config.seed = seed

  var sim = initSimServer(config)
  sim.gameEventLoggingEnabled = false

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
    discard sim.addPlayer(name, requestedSlot = slot, trusted = true)
    seats.add(if assign[slot] == 'a': seatA(slot) else: seatB(slot))
  sim.startGame()

  # FNV-1a over every observation byte sent to every seat, in seat order.
  # `gameHash` only sees state the game reacts to; a fog run or a marker is
  # cosmetic and could regress without moving it. This hash covers the actual
  # wire bytes, so "bit-identical" engine changes are checkable against what a
  # viewer would have been sent, not just against what the policy did with it.
  const
    FnvOffset = 14695981039346656037'u64
    FnvPrime = 1099511628211'u64
  var
    inputs = newSeq[InputState](seats.len)
    prevInputs = newSeq[InputState](seats.len)
    viewers = newSeq[PlayerViewerState](seats.len)
    ticks = 0
    obsHash = FnvOffset

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
      let blob = blobFromBytes(packet)
      for c in blob:
        obsHash = (obsHash xor uint64(ord(c))) * FnvPrime
      inputs[i] = decodeInputMask(seats[i].onPacket(blob))
    sim.step(inputs, prevInputs)
    prevInputs = inputs
    inc ticks

  var
    seatsJson = newJArray()
    totalCaptures = 0
  for i in 0 ..< seats.len:
    let player = sim.players[i]
    totalCaptures += player.captures
    seatsJson.add(%*{
      "slot": i,
      "build": seats[i].build,
      "team": teamName(player.team),
      "kills": player.kills,
      "deaths": player.deaths,
      "captures": player.captures,
      "reward": player.reward,
      "shotsFired": player.shotsFired,
      "shotsHit": player.shotsHit
    })

  %*{
    "seed": seed,
    "assign": assign,
    "ticks": ticks,
    "gameTicks": sim.tickCount,
    "ending": sim.ending(totalCaptures),
    "draw": sim.isDraw,
    "winner": (if sim.isDraw: "none" else: teamName(sim.winner)),
    "gameHash": $sim.gameHash(),
    "obsHash": $obsHash,
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
  --assign STR     one char per slot, 'a' or 'b' (default: 16 x 'a')
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
    if c notin {'a', 'b'}:
      quit("--assign takes only 'a' and 'b', got '" & c & "'", 2)

  let configJson =
    if configPath.len > 0: readFile(absolutePath(configPath)) else: ""

  when ProfileTracePath.len > 0:
    startProfileTrace()
    setTraceEnabled(false)               # armed by the tick window above

  # `initSimServer` bakes the map and loads fonts and sprite sheets relative to
  # the current directory, so the engine checkout has to BE the working
  # directory -- the same reason every upstream tool and test does this.
  engineDir = absolutePath(engineDir)
  if not dirExists(engineDir / "data"):
    quit("no data/ under " & engineDir & ": not a coworld-ctf checkout", 2)
  setCurrentDir(engineDir)

  for seed in seedList:
    let
      record = runEpisode(configJson, seed, assign, tickCap)
      ending = record["ending"].getStr
      winner = record["winner"].getStr
      ticks = record["ticks"].getInt
    echo $record
    if not quiet:
      stderr.writeLine(
        &"seed {seed} assign {assign} -> {ending} {winner} in {ticks} ticks")

  when ProfileTracePath.len > 0:
    finishProfileTrace()
