## Who the players are, what the bot remembers between frames, and the fixed
## landmarks of the arena.
##
## `Actor` is a player seen this frame, `Track` one remembered after it leaves
## vision, `Ping` a shot heard landing; `Bot` is everything that survives to the
## next tick. The landmarks mirror across the map center, so they hold anywhere.

import
  std/[random, tables],
  geometry,
  tuning

type
  Team* = enum
    Red, Blue

  Role* = enum
    MidTop, MidBottom, MidGuard, FlankTop, FlankBottom,
    Overwatch, HomeDefender

  Actor* = object              # a player visible this frame
    pos*: Vec
    facingRight*: bool
    hp*: int                   # from the overhead pip bar; 0 = not read
    pid*: int                  # which player this is; -1 when unidentified
    shield*, nade*, arc*: bool   # what the identity badge says it is carrying

  Track* = object              # a remembered player
    pos*, vel*: Vec
    lastSeen*: int
    facingRight*: bool
    hp*: int                   # last observed hit points; 0 = never read
    pid*: int                  # which player this is; -1 when unidentified
    shield*, nade*, arc*: bool   # last known carry, from the identity badge

  Ping* = object               # one heard shot landing, position only
    pos*: Vec
    tick*: int
    hot*: bool                 # OUR side lost someone here: danger, avoid
    foe*: bool                 # THEIR side lost someone here: enemies were here
    exact*: bool               # the ring resolved to one spot, not a neighbourhood

  ExpSpot* = object            # one moving-threat input to the exposure field
    pos*: Vec
    r*: float
    los*: bool                 # marked through line-of-sight, not a plain disc

  Bot* = ref object
    slot*: int
    team*: Team
    role*: Role
    rng*: Rand                 # this seat's own jink/steer noise. Seeded from
                               # the slot by `seedRng`, which reproduces the
                               # stream `randomize(slot * 7919 + 1)` used to
                               # put on `std/random`'s process-wide generator
                               # bit for bit -- one bot per process cannot tell
                               # the difference. The local simulator runs all
                               # sixteen seats in ONE process, where a shared
                               # generator would make each seat's draws depend
                               # on how often the other fifteen had drawn.
    tick*: int                 # sim ticks, advanced by frames received
    navBuilt*: bool
    cellWalkable*: seq[bool]   # eroded walkability, GridW x GridH
    coverCell*: seq[bool]      # walkable cells hugging an obstacle
    exposure*: seq[bool]       # cells a remembered enemy could shoot into
    exposureStatic*: seq[bool] # the part of that which never moves: the
                               # mirrored enemy post and the respawn ground.
                               # Computed once with the nav grid; every
                               # rebuild starts from a copy of it
    navDist*: seq[int32]       # cost field toward navGoal
    navQueue*: array[NavBuckets, seq[int32]]
                               # the cost field's frontier, bucketed by
                               # distance. Lives here rather than inside
                               # computeField so a repath reuses the memory
                               # instead of building a queue every time
    navGoal*: int              # goal cell of the current field, -1 = stale
    navStamp*: int             # tick the field was computed
    expSpots*: seq[ExpSpot]    # the exact inputs exposure[] was built from,
                               # in consumption order -- the change detector
                               # that lets an unchanged repath skip the rebuild
    expValid*: bool            # exposure[] matches expSpots
    fieldGoal*: int            # goal cell navDist[] was last computed for
    fieldValid*: bool          # navDist[] matches (fieldGoal, exposure[])
    postHold*, postPeek*: Vec   # overwatch cover post and its peek cell
    postReady*: bool
    enemyPosts*: seq[Vec]      # the mirrored ENEMY sniper peek cells
    enemyRespawnSpots*: seq[Vec]   # samples of the enemy endzone, the ground
                              # GV25 respawns land on (see findEnemyPosts)
    chokeHold*: Vec            # defender hold point snapped to cover
    behindLines*: bool         # flanker has crossed deep into the enemy half
    enemies*: seq[Track]
    mates*: seq[Track]
    carrierPos*, carrierVel*: Vec   # last fix on the thief carrying OUR flag
    carrierSeen*: int
    lastEnemySeen*: int        # last tick ANY enemy was inside our vision
    gameStart*: int            # tick of the last lobby-to-playing transition
    firedLast*: bool           # A was set on the previous sent mask
    estAim*: int               # dead-reckoned own aim angle in brads
    rotSign*: int              # rotation of the last sent mask: +1 B, -1 Select
    wasDead*: bool             # respawn resets the aim to the spawn heading
    scanHigh*: bool            # scan sweep currently heading to the high end
    lastPos*: Vec
    stuckTicks*: int
    jinkUntil*: int
    jinkBits*: uint8
    nadeCharge*: int           # ticks the C button has been held; 0 = idle
    sonar*: seq[Ping]          # shot landings heard recently, anywhere on the map
    sonarSeen*: Table[(int, int), int]  # landing spot -> tick first heard
    kills*: array[Team, int]   # running team totals off the scoreboard
    killsInit*: bool           # false until the first scoreboard read lands
    clockCands*: seq[int32]    # the candidate clock offsets still unbeaten:
                              # every one that has explained EVERY landing
                              # heard so far. An offset that misses once can
                              # never be the true one, so it leaves for good
    clockRings*: int           # heard landings spent on that question so far
    clockLag*: int             # the winning offset, once one has won
    clockKnown*: bool          # true after it wins by a clear margin
    mateFixPos*: Vec           # last SEEN position of a mate-carried enemy heart
    mateFixTick*: int          # tick of that sighting; 0 = never seen this game
    nadeNeed*: int             # charge ticks required for the planned throw
    hp*: int                   # own hit points, read from the HUD lives label
    kitPos*: seq[Vec]          # discovered med kit spots (two, center line)
    kitAbsentAt*: seq[int]     # tick a spot was last seen empty; -1 = present
    plasmaPos*: seq[Vec]       # discovered plasma arc spots (side midpoints)
    plasmaAbsentAt*: seq[int]
    shieldPos*: seq[Vec]       # discovered shield spots (endzone back columns)
    shieldAbsentAt*: seq[int]
    nadePos*: seq[Vec]         # the four corner grenade spawns
    nadeAbsentAt*: seq[int]

proc roleForSeat*(seat: int, team: Team): Role =
  ## Deterministic role spread over the 8 per-team seats. Seats 2 and 3 both
  ## spawn at flag height, but the sim's un-mirrored +-6px spawn offset makes
  ## seat 3 the closest spawn to the flag for Red and seat 2 for Blue — the
  ## rusher takes whichever is closest so we win the opening pickup race.
  ## Under fog the attack wave is six strong (a mid quad plus two flankers):
  ## with no global flag tracking a carrier that slips the contest is hard to
  ## reacquire, so committed offense converts steals into captures, and the
  ## back line is one lane sniper plus the home defender.
  case seat
  of 0: FlankBottom        # wide bottom lane, get behind the contest
  of 1: MidGuard           # third mid, trails offset high and cleans up
  of 2: (if team == Blue: MidTop else: MidBottom)
  of 3: (if team == Red: MidTop else: MidBottom)
  of 4: MidBottom          # fourth mid: the second trailing attacker
  of 5: Overwatch          # cover post flanking the ring: the lane sniper
  of 6: FlankTop           # wide top lane, get behind the contest
  else: HomeDefender       # choke guard before our capture column

proc spawnAim*(team: Team): int =
  ## The spawn/respawn aim angle: toward the enemy side.
  if team == Red: 0 else: AimBrads div 2

proc scanArcFor*(team: Team): int =
  ## The scan-sweep half-arc for one side. tuning.nim carries a literal per
  ## team (ScanArcRed / ScanArcBlue) so each side is its own knob; they read
  ## the same number until an experiment moves one. tuning sits below world
  ## and cannot name a Team, so the selector lives here with the other
  ## team-indexed landmarks.
  if team == Red: ScanArcRed else: ScanArcBlue

proc homeSign*(team: Team): float =
  ## -1 toward Red's home edge (left), +1 toward Blue's (right).
  if team == Red: -1.0 else: 1.0

proc homeDeepX*(team: Team): float =
  ## A point well inside our capture zone, mirrored across the map's
  ## vertical center line (150 on the default 1235px arena, scaled with
  ## the map).
  let deep = float(MapW * 150 div 1235)
  if team == Red: deep else: float(MapW - 1) - deep

proc enemy*(team: Team): Team =
  ## The opposing team.
  if team == Red: Blue else: Red

proc flagHome*(team: Team): Vec =
  ## The STATIC pedestal position of one team's flag: the center of the
  ## team's protected spawn pocket (matches flagHome in src/ctf/sim.nim,
  ## computed from the map size instead of the old hardcoded 186/1049).
  if team == Red:
    vec(float(CenterX - CenterX * 7 div 10), float(CenterY))
  else:
    vec(float(CenterX + (MapW - CenterX) * 7 div 10), float(CenterY))

proc chokeSpot*(team: Team): Vec =
  ## Defender hold point between the flag and our home edge, mirrored
  ## exactly across the map's vertical center line. (390, 340) on the
  ## default 1235x659 arena — the gap between the diamond and disc
  ## columns — scaled proportionally so it lands in the same tactical
  ## pocket on every map.
  let
    x = float(MapW * 390 div 1235)
    y = float(MapH * 340 div 659)
  if team == Red: vec(x, y) else: vec(float(MapW - 1) - x, y)

proc seedRng*(bot: Bot) =
  ## Seeds this seat's generator from its slot.
  ##
  ## `initRand(n)` and `randomize(n)` seed the same algorithm identically, so
  ## a bot that owns its generator draws exactly what the same bot drew off
  ## the process-wide one. Seat noise stays a property of the seat rather than
  ## of how many other seats happen to share the process.
  bot.rng = initRand(bot.slot * 7919 + 1)

proc resetTransient*(bot: Bot) =
  ## Drops per-game memory between rounds (lobby / game-over interstitials).
  bot.enemies.setLen(0)
  bot.mates.setLen(0)
  bot.nadeCharge = 0
  bot.mateFixTick = 0
  bot.hp = MaxHp
  for i in 0 ..< bot.kitAbsentAt.len:
    bot.kitAbsentAt[i] = -1              # both kits restock at game start
  for i in 0 ..< bot.plasmaAbsentAt.len:
    bot.plasmaAbsentAt[i] = -1
  for i in 0 ..< bot.shieldAbsentAt.len:
    bot.shieldAbsentAt[i] = -1
  for i in 0 ..< bot.nadeAbsentAt.len:
    bot.nadeAbsentAt[i] = -1
  bot.carrierSeen = -100_000
  bot.lastEnemySeen = bot.tick
  bot.gameStart = bot.tick
  bot.firedLast = false
  bot.estAim = spawnAim(bot.team)
  bot.rotSign = 0
  bot.wasDead = false
  bot.scanHigh = false
  bot.stuckTicks = 0
  bot.jinkUntil = 0
  bot.behindLines = false
  bot.navGoal = -1
  bot.expValid = false
  bot.fieldValid = false
