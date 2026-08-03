## Who the players are, what the bot remembers between frames, and the fixed
## landmarks of the arena.
##
## `Actor` is a player seen this frame, `Track` one remembered after it leaves
## vision, `Ping` a shot heard landing; `Bot` is everything that survives to the
## next tick.
##
## ## The two sides, and the four colours
##
## `Team` is the STRATEGY frame and is deliberately still two-sided: us, and
## the one side we raid. Every tuned constant in the tree is written against
## it — the mirrored-arena landmarks below, the per-side scan arc, the
## one-way post bonus — and none of that generalizes to a free-for-all. The
## WIRE's idea of a side is `labelkind.Colour`, of which there are four; a
## seat carries its own colour and the set of every colour that is not it.
##
## The landmarks come in two frames, selected by `multiFrameOn`. On a
## two-team board they are the mirrored-arena math this bot was tuned on,
## untouched to the pixel. On a four-team board that math describes nothing
## — the terrain is generated and the homes sit in corners or on the arms of
## a plus — so they anchor instead on the endzone marks the engine states
## outright at t=0 (labels.nim, LabelPrefixEndzone), refined by pedestal
## sightings, which are never fogged.

import
  std/[random, tables],
  labelkind,
  geometry,
  tuning

type
  Team* = enum
    Red, Blue

  EndzoneMark* = object
    ## One team's stated home capture region, reduced to the one point every
    ## consumer here wants: the centre of the inclusive bounding box the
    ## `endzone <color> <shape> <x0>,<y0> <x1>,<y1>` marker names.
    ##
    ## The centre is inside the zone for EVERY shape in labels.nim's closed
    ## vocabulary, which is why the shape token can be validated and then
    ## dropped: `column`, `square` and `arm` fill their box, `disc` is the
    ## inscribed circle (whose centre is the box centre), and `corner` is the
    ## L1 triangle hugging the map corner the box touches — the box is
    ## `diagLimit` on a side and its centre sits at L1 distance `diagLimit`
    ## from that corner, i.e. exactly on the threshold diagonal.
    colour*: Colour
    centre*: Vec

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

  Fix* = object                # one enemy position a teammate shouted
    pos*: Vec                  # the centre of the cell they named
    tick*: int                 # when we heard it, not when they saw it

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
    team*: Team                # the STRATEGY side, dealt slot mod 2 and never
                               # re-dealt: on a four-team board it is just a
                               # token meaning "us", picking which of the
                               # per-side tuned literals this seat reads
    colour*: Colour            # our WIRE colour, dealt Colour(slot mod
                               # GameTeams) once the team count is stated and
                               # confirmed by the self marker below
    colourLocked*: bool        # the self marker -- the one sprite only WE ever
                               # see -- has been found this process, so
                               # `colour` is observed rather than dealt
    foes*: set[Colour]         # every ACTIVE colour that is not ours. On a
                               # free-for-all board all three of them shoot at
                               # us, so the enemy scan unions over this rather
                               # than reading one opposing colour
    foeColour*: Colour         # the raid target: the one colour the flag
                               # bookkeeping is about. The classic opponent on
                               # two-team boards, the endzone-picked target on
                               # four-team ones
    endzones*: seq[EndzoneMark]  # every team's stated capture region, read
                               # once at nav-grid build from the init markers
    multiReady*: bool          # the endzone-anchored frame below is derived.
                               # Gated on GameTeams > 2, so a two-team board
                               # never leaves the tuned mirrored-arena math
    multiHome*: Vec            # our pedestal (the zone centre until one is
    multiCapture*: Vec         # seen) and our endzone centre, where a carry
                               # scores -- on a corner or arm home those are
                               # different points
    multiTarget*: Vec          # the raid target's pedestal
    multiSign*: float          # sign of our home->target axis, so the
                               # east-west advance math keeps a direction
    targetSeen*: int           # last tick the raid target's heart was
                               # accounted for, on a pedestal or in a carrier's
                               # hands; drives the re-target above
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
    navLevel*: int32           # the distance level the frontier is draining,
    navQueued*: int            # and how many entries are still in it: a
                               # paused Dijkstra, so a seat that walks past
                               # what the field was drained to RESUMES
    fieldHorizon*: int32       # every cell at or below this distance holds
                               # its final value; beyond it navDist[] is
                               # tentative (see driveField)
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
    shoutFixes*: seq[Fix]      # enemy fixes shouted by teammates. REBUILT FROM
                               # THE WIRE EVERY FRAME rather than accumulated:
                               # the engine keeps one live bubble per player
                               # for ShoutTicks and re-sends it while it lives,
                               # so the frame's bubbles ARE the live set and
                               # remembering them separately would only be a
                               # second, worse copy of the server's expiry
    pendingShout*: string      # the message this frame wants to broadcast, ""
                               # for none. The process (baseline.nim on the
                               # wire, sim/host.nim in the simulator) takes it
                               # and clears it; the policy never sends
    pendingKill*: Vec          # where we last saw a body drop, waiting for
    pendingKillTick*: int      # airtime. -1 tick = nothing to say
    lastShoutTick*: int        # our own last emit of ANY word: the physical
                               # channel, which the engine rate-limits
    lastFixTick*: int          # ...and of an enemy fix alone, so a kill call
                               # can be given its own slot without resetting
                               # the cadence a sighting is waiting on
    mateFixes*: seq[Fix]       # teammate positions heard off the channel,
                               # rebuilt from the wire every frame like
                               # shoutFixes. The one fact the ruleset
                               # deliberately withholds
    lastShoutText*: string     # and what it said. Our own bubble is audible
                               # to us at distance zero, so without this the
                               # channel reads its own echo back as a mate's
                               # intel and counts one sighting twice
    kills*: array[Colour, int] # running team totals off the scoreboard, per
                               # COLOUR: on a four-team board "their kills" is
                               # the sum over three of them
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

proc activeColours*(): set[Colour] =
  ## The colours actually on the board this episode. A game's active teams
  ## are always a PREFIX of the engine's enum (`activeTeams`), so the stated
  ## team count names the whole set and nothing has to be counted off the
  ## wire.
  for i in 0 ..< GameTeams:
    result.incl(Colour(i))

proc multiFrameOn*(bot: Bot): bool {.inline.} =
  ## Whether the landmarks below run on the endzone-anchored frame. Both
  ## halves matter: `GameTeams > 2` is the safety property (a two-team board
  ## can never reach the new math, whatever the markers said), and
  ## `multiReady` is the honesty one (a board that states four teams but no
  ## endzone we recognise stays on the tuned frame rather than anchoring on
  ## a guess).
  GameTeams > 2 and bot.multiReady

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

proc spawnAim*(bot: Bot, team: Team): int =
  ## The spawn/respawn aim angle the server hands a fresh body.
  ##
  ## The engine points it at the MAP CENTRE, so every team wakes facing the
  ## fight (`spawnAimBrads`): on a sides map that is the east/west pair below,
  ## on a corners map the 45-degree diagonal out of the corner, on a plus map
  ## along the arm. Our own anchor to the centre reproduces all three, because
  ## it is the same line the engine takes it from — NOT the raid axis, which
  ## on a corners board can sit 32 brads off it for the two teams whose target
  ## is their horizontal twin.
  ##
  ## Worth getting right rather than merely close: nothing else reads the true
  ## aim, and `syncAim`'s sprite bound only pulls a wrong estimate back to the
  ## edge of the bucket the server drew.
  if bot.multiFrameOn():
    return bradsOf(vec(float(CenterX), float(CenterY)) - bot.multiHome)
  if team == Red: 0 else: AimBrads div 2

proc scanArcFor*(team: Team): int =
  ## The scan-sweep half-arc for one side. tuning.nim carries a literal per
  ## team (ScanArcRed / ScanArcBlue) so each side is its own knob; they read
  ## the same number until an experiment moves one. tuning sits below world
  ## and cannot name a Team, so the selector lives here with the other
  ## team-indexed landmarks.
  if team == Red: ScanArcRed else: ScanArcBlue

proc homeSign*(bot: Bot, team: Team): float =
  ## -1 toward Red's home edge (left), +1 toward Blue's (right). On a
  ## multi-team board there are no home edges, so the frame is bot-relative
  ## instead: the sign of our own home->target axis. The target is picked for
  ## maximum HORIZONTAL offset (deriveMultiFrame) precisely so this never
  ## comes out of a north-south axis and degenerates — every "advance" and
  ## "fall back" in the tree is an x comparison.
  if bot.multiFrameOn():
    return (if team == bot.team: bot.multiSign else: -bot.multiSign)
  if team == Red: -1.0 else: 1.0

proc homeDeepX*(bot: Bot, team: Team): float =
  ## A point well inside our capture zone, mirrored across the map's
  ## vertical center line (150 on the default 1235px arena, scaled with
  ## the map). On a multi-team board: our stated endzone's centre, which IS
  ## where a carry scores.
  if bot.multiFrameOn():
    return bot.multiCapture.x
  let deep = float(MapW * 150 div 1235)
  if team == Red: deep else: float(MapW - 1) - deep

proc enemy*(team: Team): Team =
  ## The opposing team.
  if team == Red: Blue else: Red

proc flagHome*(bot: Bot, team: Team): Vec =
  ## The STATIC pedestal position of one team's flag: the center of the
  ## team's protected spawn pocket (matches flagHome in src/ctf/sim.nim,
  ## computed from the map size instead of the old hardcoded 186/1049).
  ## On a multi-team board: our own or the raid target's pedestal anchor —
  ## every call site passes `bot.team` or `enemy(bot.team)`, so the two-sided
  ## question is exactly the one the multi-team frame can answer.
  if bot.multiFrameOn():
    return (if team == bot.team: bot.multiHome else: bot.multiTarget)
  if team == Red:
    vec(float(CenterX - CenterX * 7 div 10), float(CenterY))
  else:
    vec(float(CenterX + (MapW - CenterX) * 7 div 10), float(CenterY))

proc chokeSpot*(bot: Bot, team: Team): Vec =
  ## Defender hold point between the flag and our home edge, mirrored
  ## exactly across the map's vertical center line. (390, 340) on the
  ## default 1235x659 arena — the gap between the diamond and disc
  ## columns — scaled proportionally so it lands in the same tactical
  ## pocket on every map. Those proportions describe a two-column arena and
  ## nothing else, so on a multi-team board hold part-way out from our own
  ## pedestal toward the open middle instead — the one direction every
  ## approach to a corner or arm home has to come from.
  if bot.multiFrameOn():
    return bot.multiHome +
      (vec(float(CenterX), float(CenterY)) - bot.multiHome) * MultiChokeFrac
  let
    x = float(MapW * 390 div 1235)
    y = float(MapH * 340 div 659)
  if team == Red: vec(x, y) else: vec(float(MapW - 1) - x, y)

proc deriveMultiFrame*(bot: Bot) =
  ## Anchors the two-sided strategy frame onto this seat's REAL multi-team
  ## home. Our own endzone mark is home and capture zone; the raid target is
  ## the enemy zone with the LARGEST horizontal offset, so the east-west
  ## advance math the whole tree is written in never degenerates on a home
  ## that faces north or south. On a plus board that is the opposite arm; on
  ## a corners board the horizontal twin and the diagonal twin tie exactly,
  ## and the first mark in engine team order takes it — either is a full
  ## map-width of x, which is all this has to guarantee. Pedestal sightings
  ## refine both anchors later (readFlagState); a pedestal is never fogged,
  ## so that refinement always arrives.
  ##
  ## Leaves the frame OFF and returns quietly when the board is two-team or
  ## the markers do not name our colour: a wrong anchor would steer every
  ## seat at a spot nothing is at, which is worse than the mirrored math
  ## being merely irrelevant.
  bot.multiReady = false
  if GameTeams <= 2:
    return
  var
    home: Vec
    haveHome = false
  for z in bot.endzones:
    if z.colour == bot.colour:
      home = z.centre
      haveHome = true
      break
  if not haveHome:
    return
  var
    target: Vec
    targetColour = bot.colour
    bestDx = -1.0
  for z in bot.endzones:
    if z.colour == bot.colour:
      continue
    let dx = abs(z.centre.x - home.x)
    if dx > bestDx:
      bestDx = dx
      target = z.centre
      targetColour = z.colour
  if bestDx < 0.0:
    return
  bot.multiHome = home
  bot.multiCapture = home
  bot.multiTarget = target
  bot.multiSign = (if home.x >= target.x: 1.0 else: -1.0)
  bot.foeColour = targetColour
  bot.targetSeen = bot.tick
  bot.multiReady = true

proc dealSeat*(bot: Bot) =
  ## Deals this seat its wire colour, its per-team seat and its role from the
  ## slot and the team count now in force.
  ##
  ## The engine seats players by join order round the ACTIVE teams, so slot n
  ## is `Colour(n mod GameTeams)` and holds per-team seat `n div GameTeams`.
  ## At two teams that is bit-for-bit the parity deal the process constructor
  ## already made, so this is a no-op there; at four it is the whole bug —
  ## parity calls green "red", every scan below then looks for the wrong
  ## sprite, and half the roster stands at spawn all game.
  ##
  ## `bot.team` is NOT re-dealt. It is the strategy side, and on a four-team
  ## board there is no such thing to read off the wire; it stays the parity
  ## token that selects between the per-side tuned literals.
  if not bot.colourLocked:
    bot.colour = Colour(bot.slot mod GameTeams)
  bot.foes = activeColours() - {bot.colour}
  # The classic opponent, until deriveMultiFrame picks a raid target. Not
  # `enemy(bot.team)`: bot.team is a parity token, and on a four-team board
  # the colour it names may not even be on the board's other side.
  for c in bot.foes:
    bot.foeColour = c
    break
  bot.role = roleForSeat(clamp(bot.slot div GameTeams, 0, 7), bot.team)

proc seedRng*(bot: Bot) =
  ## Seeds this seat's generator from its slot.
  ##
  ## `initRand(n)` and `randomize(n)` seed the same algorithm identically, so
  ## a bot that owns its generator draws exactly what the same bot drew off
  ## the process-wide one. Seat noise stays a property of the seat rather than
  ## of how many other seats happen to share the process.
  bot.rng = initRand(bot.slot * 7919 + 1)

proc takeShout*(bot: Bot): string =
  ## The message to broadcast this frame, and clears it. Called by whatever
  ## owns the connection -- there is none below this layer.
  result = bot.pendingShout
  bot.pendingShout.setLen(0)

proc resetTransient*(bot: Bot) =
  ## Drops per-game memory between rounds (lobby / game-over interstitials).
  ##
  ## Re-deals the seat as well, because this is the one proc the process
  ## constructor and every lobby frame both run: a bot built before the team
  ## count was stated is dealt on the default of 2, and the nav-grid build
  ## deals it again once the marker has arrived. Neither the colour nor the
  ## role is per-round state, so re-running the deal here costs nothing and
  ## removes the case where an interstitial leaves a seat holding a colour
  ## nobody dealt it.
  bot.dealSeat()
  bot.enemies.setLen(0)
  bot.mates.setLen(0)
  bot.shoutFixes.setLen(0)
  bot.mateFixes.setLen(0)
  bot.pendingShout.setLen(0)
  bot.lastShoutText.setLen(0)
  bot.lastShoutTick = -100_000
  bot.lastFixTick = -100_000
  bot.pendingKillTick = -100_000
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
  bot.estAim = bot.spawnAim(bot.team)
  bot.rotSign = 0
  bot.wasDead = false
  bot.scanHigh = false
  bot.stuckTicks = 0
  bot.jinkUntil = 0
  bot.behindLines = false
  bot.navGoal = -1
  bot.expValid = false
  bot.fieldValid = false
