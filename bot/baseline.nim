## Baseline capture-the-flag bot for Coworld CTF (8v8, classic two-flag,
## dense-cover arena, FOG-OF-WAR full-map vision).
##
## This is the shipped league champion and nothing else: every experimental
## lever and compile switch has been folded to the value it shipped with and
## the losing side deleted, so there is exactly one behaviour here and no way
## to configure it. See README.md for the fold table.
##
## Speaks the Bitworld Sprite v1 protocol over a websocket. The observation is
## the FULL map in map coordinates, but entities are fogged: an enemy (and an
## enemy carrying our flag) is only streamed while it sits inside OUR vision —
## a forward cone (half-angle ~60 degrees around our AIM ANGLE, unlimited
## range, walls block) plus a small omnidirectional bubble (~90px). Always
## visible: the static map, BOTH flag pedestals (teammates are fogged too),
## our own flag's state (an empty own pedestal means it is stolen), and
## ourselves via the distinct "self <color> right|left" marker. AIM IS
## DECOUPLED FROM MOVEMENT: a continuous per-player aim angle (0..255 brads,
## 0 = east, counter-clockwise on screen) turns while B (CCW) or Select (CW)
## is held at ~5 brads/tick; the d-pad never touches it. The aim drives the
## gun, the vision cone, and the sprite flip, so pointing it is THE core
## tactical decision. The bot keeps a persistent world model on top of that:
##
## - **Nav grid**: the full walkability mask arrives once at init; we erode it
##   by the player footprint into an 8px cell grid and run a cost field
##   (Dijkstra) to any goal, then follow the path with waypoint lookahead.
## - **Cover model**: walkable cells adjacent to an obstacle are "cover
##   cells". Cells a remembered enemy could shoot into (range + coarse LOS)
##   get a soft path cost, so movement naturally advances cover-to-cover and
##   keeps obstacles between us and known threats.
## - **Flag model** (two flags): pedestals are STATIC known positions and
##   pedestal flags are never fogged. Only OUR team can carry the enemy flag,
##   so the "<enemy color> heart" sprite is always visible and fully describes
##   our attack (pedestal / on me / on a mate). Only the enemy can carry OUR
##   heart: the "<my color> heart" sprite on its pedestal means safe, visible
##   off-pedestal is a live thief fix, and ABSENT means stolen by a fogged
##   carrier somewhere between our pedestal and its home edge.
## - **Memory**: visible players are matched to tracks (position, velocity,
##   last-seen tick) that persist through fog, and the last thief fix guides
##   the hunt after the carrier fogs out.
## - **Roles** (deterministic from the per-team seat, 8 seats): a mid QUAD
##   races lanes to the ENEMY pedestal, two flankers route wide and hit the
##   pocket from behind, one overwatch sniper holds a shielded cover post
##   whose peek cell owns the longest firing line over mid — under fog a lane
##   watcher SEES map-wide down its open lane, so overwatch is also the radar
##   — and one home defender guards the choke before our pedestal. The attack
##   wave is deliberately six strong: with no global flag tracking, a carrier
##   that slips the contest is hard to reacquire, so committed offense turns
##   steals into captures. While our flag is stolen the back line hunts the
##   thief along its predicted route toward ITS home edge; attackers press on
##   — captures are instant wins both ways, so the race stays on.
## - **Turret controller**: the bot dead-reckons its own aim (spawn aim is
##   toward the enemy side; each held rotate button turns it 5 brads/tick)
##   and bounds it every frame by the rotation step the server renders our own
##   soldier at, which pins the true aim to a 16-brad bucket.
##   Each tick it outputs the rotate button that traverses toward the desired
##   aim by the shortest arc, and fires only when the bullet corridor
##   (~14px half-width) covers the target at its range.
## - **Scanning**: units holding a position (overwatch posts, the defender's
##   choke, cooldown ducks) sweep the aim back and forth across the watch arc
##   with genuine rotate-button sweeps, raking the vision cone over it while
##   standing perfectly still. On the move, the aim leads the movement
##   direction when no target demands it, so attackers watch down-lane.
## - **Peek-and-shoot**: the default combat mode. With the gun up and a
##   remembered enemy blocked by a wall, PRE-LAY the aim on the firing line
##   while stepping sideways to the nearest cell that opens it — the shot is
##   ready the moment the ray clears; during the 12-tick cooldown, duck
##   behind the nearest cover that breaks the threat's line and hold there.
## - **Fire discipline**: the bullet is a corridor hitscan along the aim, so
##   the fire gate is geometric: shoot when the aim error's perpendicular
##   miss at the target's range is inside the corridor. Skip targets with a
##   remembered teammate near the fire axis (friendly fire is on; the server
##   kills the NEAREST player in the corridor).
##
## Coordinate model: the map object sits at (0, 0), so object positions ARE
## map coordinates; we find ourselves via the self marker. Only a fresh A
## press fires, and the aim angle locks at the pull (the bullet leaves after
## a short windup), so we stop rotating on the tick we pull.

import
  std/[algorithm, heapqueue, math, os, random, strutils, tables],
  bitworld/spriteprotocol,
  whisky,
  baseline/labels,
  baseline/protocols

const
  WebSocketPath = "/player"

  # All-in on the clock: past this tick a draw is the default outcome, so
  # commit to the capture. The game hard-stops at tick 5000 and a time-limit
  # draw scores exactly as badly as a loss, so a trigger past that tick can
  # never fire at all and the posts are held into a guaranteed -1.
  LatePushTick = 3400
                              # Object coordinates and sprite sizes arrive
                              # multiplied by this; sprites stay centered on
                              # the same map points, so dividing the object
                              # center recovers exact legacy map coordinates.
  PlayerHalf = 6              # solid footprint half-extent, matches the sim
  NavCell = 8                 # nav grid cell size in px
  RepathTicks = 10            # refresh the cost field at least this often
  LookaheadCells = 6          # how far ahead on the path we aim the waypoint

  CarrierFireRange = 110.0    # while carrying, only shoot enemies this close
  RushEngageRange = 230.0     # racing for the steal: only fight what blocks it
  EscortEngageRange = 320.0   # escorting a run: only fight near threats
  PocketRushRange = 210.0     # this close to the enemy pedestal, just GRAB
  ThreatRange = 200.0         # react to a visible enemy this close facing us
  DuckRange = 340.0           # duck from remembered threats this close on cooldown
  MateSpacing = 40.0          # soft repulsion radius between teammates
  CorridorHalfWidth = 15.0    # friendly-fire corridor half width along the ray
  LeadTicks = 6.0             # aim this many ticks ahead of a moving enemy:
                              # the 5-tick windup releases the bullet late
  TrackMatchDist = 40.0       # a sighting matches a track within this distance
  TrackCap = 8                # eight real opponents / teammates per side

  # The overhead identity badge. Its object id is a fixed base plus the
  # player's own index, so the id alone names WHICH player wears it and never
  # renames them for the length of the match. The disc is centred on the body,
  # so a tight radius pins each badge to the soldier under it.
  BadgeObjectBase = 19040
  BadgeObjectSpan = 32        # badges live in this many consecutive ids
  BadgeAnchorSlack = 4.0      # px between a badge centre and its body centre

  # Shot landings are audible map-wide: the server sends every living viewer
  # a ring near where each shot hit, through walls and fog alike, and the ring
  # says nothing about which team fired. The position is deliberately fuzzed
  # by up to SonarJitterPx px, so a ring locates a neighbourhood, not a body.
  SonarObjectBase = 19120
  SonarObjectSpan = 16        # 19120..19135, one per recent shot
  SonarJitterPx = 20          # px of deliberate fuzz on every heard landing
  SonarCalMin = -700          # how far back the server clock might sit from
  SonarCalMax = 200           # ours; wide on purpose until it is measured
  SonarCalRings = 90          # heard landings to spend pinning that offset
  SonarCalMinRings = 30       # landings to hear before trusting a winner
  SonarSeenTtl = 40           # forget a spot well after its ring stops drawing
  SonarTtl = 90               # forget a landing after ~4s
  SonarCap = 24               # plenty: the server sends at most 16 at once
  SonarHotTtl = 20            # only a landing this fresh can be tied to a death
  SonarHotRadius = 90.0       # how near a heard landing still counts as danger
  SonarExactRadius = 34.0     # the same, once the landing is pinned to a spot

  # Pre-aim: the turret traverses slowly, so the swing has to be paid for
  # before contact or it gets paid during it. Everything the sonar and the
  # tracks know is scored as an effective distance -- nearest wins -- with
  # weaker evidence pushed further away rather than excluded outright.
  PreAimRange = 320.0         # ignore evidence further off than this
  PreAimTrackTtl = 90         # a remembered enemy this fresh still points
  PreAimPingTtl = 60          # a heard landing this fresh still points
  PreAimAgePx = 1.2           # px of doubt added per tick of staleness
  PreAimPingCost = 120.0      # a landing is weaker evidence than a sighting
  PreAimHotBonus = 90.0       # unless a kill landed with it
  PreAimExactBonus = 45.0     # and more so when it is pinned to one spot
  PreAimArc = 20              # while moving, never look further off-lane than
                              # this. The cone rides the aim, so a wide licence
                              # here buys a faster swing onto one threat by
                              # going blind to the ground we are walking onto,
                              # which is a bad trade at any angle worth naming
  PreAimWatchRange = 200.0    # a keeper only leaves its sweep for something
                              # this close, and only while it is fresh
  PreAimWatchTtl = 30         # ticks: past this the sweep is the better bet

  # An enemy that steps behind a corner has not stopped existing. Hold the
  # sighting long enough to cover the wait, and keep facing it: every gate
  # that decides whether to SHOOT already tests freshness for itself, so a
  # held sighting can never turn into a shot at a place nobody is standing.
  TrackHoldTtl = 400          # keep a lost enemy in mind roughly this long
  FeasHorizon = 60            # ticks ahead we ask whether a shot could happen
  FeasSteps = 3               # sample points along that stretch
  OwnEstSpeed = 1.0           # px/tick we make good while walking
  BackGuardRange = 260.0      # a live enemy nearer than this stays covered
  BackGuardArc = 96           # never let the aim sit further off it than this
  BackGuardTtl = 200          # a sighting this old still counts as known
  FreshShotTicks = 24         # only fire at tracks seen this recently; the
                              # turret needs traverse time, so chases keep
                              # shooting a bit after the target fogs out
  ThiefFixTtl = 40            # a thief position fix guides the chase this long

  AimBrads = 256              # aim angle units per full turn
  AimRate = 5                 # brads/tick a held rotate button turns the aim
                              # (matches the server's aimTurnRate default)
  SelfSpriteBase = 5100       # first id of the pre-rotated self-soldier pool;
                              # the pool is laid out skin-major, so the
                              # rotation step is the id modulo SoldierRots
  SoldierRots = 16            # pre-rendered aim steps the soldier art ships in
  SoldierRotBrads = AimBrads div SoldierRots
                              # brads per rotation step: the width of the aim
                              # bucket one rendered sprite stands for
  SoldierRotHalf = SoldierRotBrads div 2
                              # half a bucket: the server rounds the aim to the
                              # nearest step, so the true aim is within this of
                              # the step's centre
  SelfAimFuzzStrikes = 3      # impossible self-marker jumps tolerated before
                              # the turret clamp is abandoned for the rest of
                              # the episode; see trackSelfAimTrust
  MaxHp = 3                   # hitPoints per life (config default); pip labels
                              # read "hp <n>/<MaxHp>"
  HpPipOffsetY = 22.0         # the overhead hp bar is centered exactly this
                              # far ABOVE its player's center — the bar sits
                              # at the body's top edge minus the overhead gap
                              # and its own height
  HpPipAnchorSlack = 3.0      # px of slop allowed against that exact anchor.
                              # The bar lands within a hundredth of a pixel of
                              # it, and bodies can stand closer than a body
                              # width apart, so keep this far below that gap:
                              # a loose window lets stacked players swap health
                              # readings, and the pip label carries no colour
                              # to catch it when they are on opposite teams
  ArcThreatBonus = 70.0       # px of credit for holding the plasma arc
  ShieldCostPenalty = 45.0    # px of debit for the extra shot a shield eats
  HpFocusBonus = 60.0         # px of effective-distance credit per missing
                              # enemy hit point — a tiebreak between
                              # comparably-engageable targets, never a reason
                              # to swing the turret across the map
  ThiefFocusBonus = 400.0     # px of credit for the enemy RUNNING OUR FLAG:
                              # dominates every positional tiebreak — killing
                              # the thief returns the flag instantly
  # Focus fire (FocusFireBonus / MateAimRayLen / MateAimHitSlack) is GONE. It
  # discounted a target a visible mate's aim line already covered, and it read
  # that aim line off the "aim dot <color>" sprites. The engine RETIRED those
  # in coworld-ctf e3bcf2e (2026-07-16) — six days before this archive's fork
  # base — replacing them with the soldier's held gun, which sweeps with the
  # aim. `spriteObjectsWithLabel("aim dot ...")` has returned an empty seq
  # ever since, so mateAimBrads always answered -1 and the discount NEVER
  # applied in any build made from this archive. Same silent shape as the
  # ButtonC truncation: valid code, no error, feature simply absent.
  #
  # It is not portable to the replacement channel either. GV24 fuzzes the
  # rendered gun rotation of every OTHER soldier by +-14 brads (~20°, held 12
  # ticks then re-rolled), so a mate's aim is now unreadable BY DESIGN. Only
  # the self marker is exact, and only since GV26. Anything rebuilt here would
  # be reading noise, so the feature is deleted rather than re-pointed.
  TraversePxPerBrad = 1.6     # px of effective distance per brad of turret
                              # swing needed to lay on the target: err/AimRate
                              # ticks of traverse at ~8px of enemy closing
                              # motion per tick = 8/5 px per brad
  # ButtonC (grenade charge/throw, input mask bit 128) is imported from
  # bitworld/spriteprotocol, NOT redefined here. Only the pinned bitworld
  # lineage (nimby.lock: 5d229ac, branch daveey/hd-client-pin) exports it —
  # bitworld master never received the 8-bit input mask and still ANDs the
  # mask with 0x7f, which silently deletes every grenade throw on the wire.
  # A local `ButtonC = 1'u8 shl 7` is exactly what made that truncation
  # invisible: it compiled cleanly against the wrong engine and cost v25-v27
  # ~0.4 K/D against v9. Importing the symbol turns the wrong engine commit
  # into a compile error instead of a silent regression.
  NadeMaxRange = 240.0        # full-charge throw distance (~fifth of the field)
  NadeMinRange = 72.0         # never lob inside this — the 52px blast + drift
                              # would clip us (GV17: blast 40 -> 52)
  NadeBlast = 52.0            # blast radius; a pair this close dies together
  NadeFullChargeTicks = 24    # ~1s of holding C reaches max range
  NadeMemTtl = 150            # bomb a sighting this old even if out of sight
  NadeFoePingTtl = 45         # bomb a spot they lost someone on, this recently
  NadeHeldCost = 60.0         # px of doubt for a target we cannot currently see
  NadeFoePingCost = 150.0     # px of doubt for a spot, rather than a body
  HoldLineKills = 6           # enemy deaths before the wave commits forward:
                              # two players' worth of lives, out of 24
  HoldLineDepth = 80.0        # px past the centre line we allow while holding
  NadeMateTtl = 150           # mates seen this recently veto a landing
  NadeMateDrift = 0.45        # px a mate could have wandered per tick unseen
  NadeTapRange = 30.0         # an uncharged tap lands this close; the throw
                              # distance runs from here to NadeMaxRange in
                              # equal steps over NadeFullChargeTicks
  OwnNadeRingSlack = 28.0     # a throw-target ring within this of our OWN
                              # predicted landing point is our own preview
  NadePickupDetour = 90.0     # grab a corner pickup within this detour range
  MedKitDetour = 80.0         # heal-detour budget when merely wounded
  MedKitCriticalReach = 180.0 # at 1 hp a heal outranks the current errand
  MedKitRespawn = 30 * 24     # a taken kit refills after 30s (sim constant)
  MedKitSeenClear = 55.0      # inside this range an empty spot is truly
                              # empty (bubble vision), not just fogged
  PlasmaReach = 136.0         # plasma cone reach: 4 squares (sim
                              # PlasmaArcReach)
  PlasmaHalfBrads = 10        # cone half-angle in brads: the cone is 2
                              # squares wide at max reach, atan(1/4) ~ 14
                              # degrees (sim PlasmaArcMaxWidth / Reach)
  PlasmaDetour = 70.0         # attacker detour budget for a plasma arc pickup
  ShieldStealDetour = 480.0   # MidGuard's shield trip: the enemy endzone
                              # shield sits low in their back column
                              # (~215px from the pedestal since the game-v7
                              # split), so the round trip costs ~430 path px
  PickupRespawn = 30 * 24     # plasma arc/shield respawn timer (sim constant)
  NadeRespawn = 5 * 24        # a taken corner grenade refills after 5s
  NadeSpawnInset = 50.0       # px in from each map corner the spawn sits
  NadeFarmReach = 340.0       # how far a flanker will go out of its way to arm
  MedKitCarrierBudget = 90.0  # extra path px a hurt CARRIER spends to heal:
                              # a full-heal carrier survives pocket exits
                              # that kill a 1 hp one
  CarrySelfRadius = 26.0      # the carried flag banner is centered on its
                              # carrier: anything inside this slack that no
                              # visible mate sits closer to is OUR carry
  CarrierEstSpeed = 1.0       # px/tick a fogged mate-carrier is assumed to
                              # advance homeward (carrier moves at ~70% speed)
  CombatDeadband = 2          # stop the traverse within this error (brads);
                              # AimRate 5 cannot settle tighter than +-2
  CruiseDeadband = 8          # sloppier deadband for non-combat aim
  FireSlackPx = 11.0          # fire when the aim error's perpendicular miss
                              # at the target's range is inside this (the
                              # corridor half-width is ~14px; keep margin)
  ScanArc = 44                # scan sweeps this many brads each side of the
                              # watch heading (cone half-angle is 32 brads)
  PushOutTicks = 360          # endgame push: no enemy seen for ~15s...
  PushOutMinGame = 2400       # ...this deep into the game breaks the posts

  CoverShieldDist = 42.0      # an obstacle this close blocks a threat direction
  PeekLineDist = 150.0        # floor for an overwatch peek firing line; post
                              # scoring strongly prefers the longest line
  DuckSearchCells = 3         # duck-cell search radius in nav cells
  PeekSearchCells = 6         # peek-cell search radius in nav cells. Wide
                              # enough that backing away from the corner is
                              # actually among the options offered
  PeekStandoffCap = 96.0      # px of stand-off from the corner worth paying for
  PeekStandoffWeight = 0.9    # px of extra walking each px of it is worth
  ExposureRange = 380.0       # enemy threat radius used for exposure costing
  ExposureThreats = 3         # cost only the freshest few remembered threats
  ExposureTrackTtl = 60       # only cost threats remembered this recently
  EnemyRespawnSamples = 3     # points down the enemy endzone column standing
                              # in for GV25's uniform respawn draw; at
                              # ExposureRange these overlap into one frontage,
                              # and overlapping cells are skipped by the
                              # exposure pass, so the marginal cost is small
  UnderFireTrackTtl = 16      # tracks this fresh can pin us on open ground
  SerpentineNear = 100.0      # serpentine band: closer threats are jink/duck
  SerpentineFar = 400.0       # ... and farther tracks cannot really aim at us
  StepCost = 5'i32            # orthogonal move cost in the nav field
  DiagCost = 7'i32            # ~sqrt(2) * StepCost
  ExposedCost = 14'i32        # extra cost to enter a threat-exposed cell:
                              # under fog the exposure model (enemy sniper
                              # posts + fresh tracks) is the only warning of
                              # watched lanes, so routes respect it hard
  FlankDepth = 260.0          # wide flankers cross this far past mid
  WeaveBand = 280.0           # rushers serpentine within this x-band of mid

  LaneTop = 40.0              # open corridor above the mirrored obstacles

## Map dimensions, adopted at nav-grid build from the walkability sprite
## (which spans the whole arena). The game supports multiple maps —
## "arena" (1235x659, the default) and "arena-large" (1606x858) — and this
## bot plays either; everything position-shaped below derives from these.
## Initialized to the default arena.
var
  MapW = 1235
  MapH = 659
  CenterX = MapW div 2
  CenterY = MapH div 2
  GridW = (MapW + NavCell - 1) div NavCell
  GridH = (MapH + NavCell - 1) div NavCell
  LaneMid = float(CenterY)
  LaneBottom = float(MapH) - LaneTop  # open corridor below the obstacles
  FireRange = float(MapW) + 15.0
    # engage distance: every map's gun range is comfortably over its own
    # width (1300 on the 1235px arena, 1690 on the 1606px arena-large), so
    # a hair past a map-width is always inside it. 1250.0 on the default
    # arena — the value this bot always used.

type
  Team = enum
    Red, Blue

  Role = enum
    MidTop, MidBottom, MidGuard, FlankTop, FlankBottom,
    Overwatch, HomeDefender

  Vec = object                # a map-space point or direction
    x, y: float

  Actor = object              # a player visible this frame
    pos: Vec
    facingRight: bool
    hp: int                   # from the overhead pip bar; 0 = not read
    pid: int                  # which player this is; -1 when unidentified
    shield, nade, arc: bool   # what the identity badge says it is carrying

  Track = object              # a remembered player
    pos, vel: Vec
    lastSeen: int
    facingRight: bool
    hp: int                   # last observed hit points; 0 = never read
    pid: int                  # which player this is; -1 when unidentified
    shield, nade, arc: bool   # last known carry, from the identity badge

  Ping = object               # one heard shot landing, position only
    pos: Vec
    tick: int
    hot: bool                 # OUR side lost someone here: danger, avoid
    foe: bool                 # THEIR side lost someone here: enemies were here
    exact: bool               # the ring resolved to one spot, not a neighbourhood

  Bot = ref object
    slot: int
    team: Team
    role: Role
    tick: int                 # sim ticks, advanced by frames received
    navBuilt: bool
    cellWalkable: seq[bool]   # eroded walkability, GridW x GridH
    coverCell: seq[bool]      # walkable cells hugging an obstacle
    exposure: seq[bool]       # cells a remembered enemy could shoot into
    navDist: seq[int32]       # cost field toward navGoal
    navGoal: int              # goal cell of the current field, -1 = stale
    navStamp: int             # tick the field was computed
    postHold, postPeek: Vec   # overwatch cover post and its peek cell
    postReady: bool
    enemyPosts: seq[Vec]      # the mirrored ENEMY sniper peek cells
    enemyRespawnSpots: seq[Vec]   # samples of the enemy endzone, the ground
                              # GV25 respawns land on (see findEnemyPosts)
    chokeHold: Vec            # defender hold point snapped to cover
    behindLines: bool         # flanker has crossed deep into the enemy half
    enemies: seq[Track]
    mates: seq[Track]
    carrierPos, carrierVel: Vec   # last fix on the thief carrying OUR flag
    carrierSeen: int
    lastEnemySeen: int        # last tick ANY enemy was inside our vision
    gameStart: int            # tick of the last lobby-to-playing transition
    firedLast: bool           # A was set on the previous sent mask
    estAim: int               # dead-reckoned own aim angle in brads
    rotSign: int              # rotation of the last sent mask: +1 B, -1 Select
    wasDead: bool             # respawn resets the aim to the spawn heading
    selfAimTrusted: bool      # the self marker still renders our TRUE aim
    selfAimPrev: int          # previous frame's self-marker bucket centre, or
                              # -1 when there was no readable marker
    selfAimStrikes: int       # physically impossible bucket jumps seen so far
    scanHigh: bool            # scan sweep currently heading to the high end
    lastPos: Vec
    stuckTicks: int
    jinkUntil: int
    jinkBits: uint8
    nadeCharge: int           # ticks the C button has been held; 0 = idle
    sonar: seq[Ping]          # shot landings heard recently, anywhere on the map
    sonarSeen: Table[(int, int), int]  # landing spot -> tick first heard
    kills: array[Team, int]   # running team totals off the scoreboard
    killsInit: bool           # false until the first scoreboard read lands
    clockVotes: seq[int]      # how often each candidate clock offset explained
                              # a heard landing, indexed from SonarCalMin
    clockRings: int           # heard landings spent on that question so far
    clockLag: int             # the winning offset, once one has won
    clockKnown: bool          # true after it wins by a clear margin
    mateFixPos: Vec           # last SEEN position of a mate-carried enemy heart
    mateFixTick: int          # tick of that sighting; 0 = never seen this game
    nadeNeed: int             # charge ticks required for the planned throw
    hp: int                   # own hit points, read from the HUD lives label
    kitPos: seq[Vec]          # discovered med kit spots (two, center line)
    kitAbsentAt: seq[int]     # tick a spot was last seen empty; -1 = present
    plasmaPos: seq[Vec]       # discovered plasma arc spots (side midpoints)
    plasmaAbsentAt: seq[int]
    shieldPos: seq[Vec]       # discovered shield spots (endzone back columns)
    shieldAbsentAt: seq[int]
    nadePos: seq[Vec]         # the four corner grenade spawns
    nadeAbsentAt: seq[int]

proc roleForSeat(seat: int, team: Team): Role =
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

proc vec(x, y: float): Vec =
  Vec(x: x, y: y)

proc `+`(a, b: Vec): Vec = vec(a.x + b.x, a.y + b.y)
proc `-`(a, b: Vec): Vec = vec(a.x - b.x, a.y - b.y)
proc `*`(a: Vec, s: float): Vec = vec(a.x * s, a.y * s)

proc len(a: Vec): float =
  hypot(a.x, a.y)

proc dist(a, b: Vec): float =
  len(a - b)

proc norm(a: Vec): Vec =
  let l = a.len()
  if l < 1e-6: vec(0, 0) else: a * (1.0 / l)

proc dot(a, b: Vec): float =
  a.x * b.x + a.y * b.y

proc cross(a, b: Vec): float =
  a.x * b.y - a.y * b.x

proc octantBits(d: Vec): uint8 =
  ## D-pad bits for the 8-way direction nearest to `d`. The worst-case aim
  ## error is 22.5 degrees, safely inside the 25-degree firing cone.
  if d.len() < 1e-6:
    return 0
  let octant = (int(round(arctan2(d.y, d.x) / (PI / 4))) + 8) mod 8
  case octant
  of 0: ButtonRight
  of 1: ButtonRight or ButtonDown
  of 2: ButtonDown
  of 3: ButtonDown or ButtonLeft
  of 4: ButtonLeft
  of 5: ButtonLeft or ButtonUp
  of 6: ButtonUp
  else: ButtonUp or ButtonRight

proc bradsOf(d: Vec): int =
  ## The aim angle in brads pointing along `d`: 0 = east (+x), increasing
  ## counter-clockwise on screen (64 = north; map y grows downward).
  if d.len() < 1e-6:
    return 0
  (int(round(arctan2(-d.y, d.x) * float(AimBrads div 2) / PI)) +
    AimBrads) mod AimBrads

proc bradsDir(brads: int): Vec =
  ## The unit vector of one aim angle in brads (the true fire axis).
  let angle = float(brads) * PI / float(AimBrads div 2)
  vec(cos(angle), -sin(angle))

proc bradsErr(desired, current: int): int =
  ## The signed shortest arc from `current` to `desired` in -128..127:
  ## positive means rotate counter-clockwise (hold B).
  (desired - current + AimBrads + AimBrads div 2) mod AimBrads -
    AimBrads div 2

proc spawnAim(team: Team): int =
  ## The spawn/respawn aim angle: toward the enemy side.
  if team == Red: 0 else: AimBrads div 2

proc slotFromUrl(url: string): int =
  ## Reads the `slot` query parameter from the websocket URL.
  let key = "slot="
  let at = url.find(key)
  if at < 0:
    return 0
  var i = at + key.len
  var digits = ""
  while i < url.len and url[i] in {'0' .. '9'}:
    digits.add(url[i])
    inc i
  if digits.len == 0: 0 else: digits.parseInt()

proc mapPos(client: ProtocolClient, o: SpriteObjectInfo): Vec =
  ## Map-space center of a sprite object (the map object sits at the origin,
  ## so the camera offset is zero; keep it for exactness). Since the 0.7.8
  ## renderer restore the wire is back to 1x map pixels (the 0.6-0.7.7 HD
  ## era carried 3x-scaled coordinates), with sprites centered on their map
  ## points.
  vec(
    float(o.x + o.width div 2 + client.mapCameraX),
    float(o.y + o.height div 2 + client.mapCameraY)
  )

proc findSelf(
    client: ProtocolClient, color: string): tuple[alive: bool, pos: Vec] =
  ## Our avatar via the distinct self marker, only drawn while we are alive.
  for facingRight in [true, false]:
    let label = labelSelf(color,
      if facingRight: LabelSideRight else: LabelSideLeft)
    for o in client.spriteObjectsWithLabel(label):
      return (alive: true, pos: client.mapPos(o))

proc selfAimBucket(client: ProtocolClient, color: string): int =
  ## The CENTRE of the aim bucket the server is currently drawing us in. Our
  ## self marker is one of SoldierRots pre-rotated sprites, numbered
  ## SelfSpriteBase + skin * SoldierRots + step, and the server picks the step
  ## by rounding the aim to the nearest one — so the sprite id alone pins the
  ## true aim to within half a bucket of step * SoldierRotBrads. The label is
  ## the same for every step, so this reads the id, not the label. Returns -1
  ## when no self marker is on screen (we are dead, or the frame predates our
  ## spawn).
  result = -1
  for facingRight in [true, false]:
    let label = labelSelf(color,
      if facingRight: LabelSideRight else: LabelSideLeft)
    for o in client.spriteObjectsWithLabel(label):
      if o.spriteId < SelfSpriteBase:
        continue                         # not from the pre-rotated self pool
      return floorMod(o.spriteId - SelfSpriteBase, SoldierRots) *
        SoldierRotBrads

proc badgesFor(
    client: ProtocolClient, color: string): seq[tuple[pos: Vec, pid: int,
    shield, nade, arc: bool]] =
  ## Every visible identity badge of one team, with the player it names and
  ## what that player is carrying. The badge ships one sprite per player with
  ## a label of the form "identity <team> <name>" followed by the carry
  ## tokens, and sits in an object-id pool indexed by the player's own slot —
  ## so the id is a stable name for that soldier, steady across the whole
  ## match, while the label tells us what they are holding right now. A
  ## weapon token is always present, so the absence of the spray token is a
  ## positive reading of "ordinary gun", not a gap.
  ##
  ## The weapon token is LabelWeaponSpray ("spray"), NOT "arc". The 0.7.x
  ## spray-can reskin (coworld-ctf 3428bd8, 2026-07-28) renamed the wire
  ## token; upstream's internal `hasPlasmaArc` field kept the old name, which
  ## is why the rename is easy to miss reading the sim. This archive forked
  ## before it and went on testing for " arc", so `arc` came back FALSE for
  ## every badge on the map — the spray-can carrier, the one enemy worth
  ## swinging the turret onto first (ArcThreatBonus), was invisible as such.
  let prefix = LabelPrefixIdentity & color & " "
  for o in client.spriteObjects():
    if o.objectId < BadgeObjectBase or
        o.objectId >= BadgeObjectBase + BadgeObjectSpan:
      continue
    if not o.label.startsWith(prefix):
      continue
    result.add((
      pos: vec(float(o.x + o.width div 2 + client.mapCameraX),
               float(o.y + o.height div 2 + client.mapCameraY)),
      pid: o.objectId - BadgeObjectBase,
      shield: (" " & LabelTokenShield) in o.label,
      nade: (" " & LabelTokenNade) in o.label,
      arc: (" " & LabelWeaponSpray) in o.label
    ))

proc ringOffset(firedTick, x1, y1: int): (int, int) =
  ## The exact displacement the server applies to one shot landing before it
  ## sends it to us, recomputed from the three numbers that feed it. Nothing
  ## about it is secret or per-viewer: the same shot is displaced the same way
  ## for everybody, every time, which is what makes it reproducible here.
  var h = 0x9E3779B9'u32 xor 0x5F356495'u32
  h = (h xor uint32(firedTick)) * 0x85EBCA6B'u32
  h = (h xor uint32(x1)) * 0xC2B2AE35'u32
  h = (h xor uint32(y1)) * 0x27D4EB2F'u32
  h = h xor (h shr 15)
  let span = uint32(2 * SonarJitterPx + 1)
  (int(h mod span) - SonarJitterPx, int((h shr 16) mod span) - SonarJitterPx)

proc solveRing(ox, oy, firedTick: int): seq[(int, int)] =
  ## Every true landing that would have been displaced onto exactly this heard
  ## spot at this tick. The displacement is bounded, so the true landing is
  ## inside a box of that half-width around what we heard; walk the box and
  ## keep whichever entries reproduce the observation. For a wrong tick this
  ## still tends to turn up about one match by chance, so a single answer here
  ## is not yet an answer — the tick has to be right first.
  if firedTick < 0:
    return
  for x1 in ox - SonarJitterPx .. ox + SonarJitterPx:
    for y1 in oy - SonarJitterPx .. oy + SonarJitterPx:
      let (ix, iy) = ringOffset(firedTick, x1, y1)
      if x1 + ix == ox and y1 + iy == oy:
        result.add((x1, y1))

proc readScoreboard(client: ProtocolClient): tuple[ok: bool, red, blue: int] =
  ## The running kill totals, read off the scoreboard text. The scoreboard is
  ## drawn for everyone with no fog test at all, so this is the one count of
  ## the fighting that is true across the WHOLE map — a kill in a corner we
  ## have never seen still moves it. The label reads "team score RED k/d".
  var got = 0
  for o in client.spriteObjects():
    for (tag, slot) in [("team score RED ", 0), ("team score BLUE ", 1)]:
      if not o.label.startsWith(tag):
        continue
      let body = o.label[tag.len .. ^1]
      let cut = body.find('/')
      if cut <= 0:
        continue
      try:
        let n = body[0 ..< cut].strip().parseInt()
        if slot == 0: result.red = n else: result.blue = n
        inc got
      except ValueError:
        discard
  result.ok = got == 2

proc hearShots(bot: Bot, client: ProtocolClient) =
  ## Bank every shot landing the server let us hear this frame. These rings
  ## ignore walls and fog completely: any shot that lands anywhere on the map
  ## is reported to every living player, which makes them the only sense we
  ## have that reaches past what we can see. What they do NOT carry is who
  ## fired, which team, or the exact spot — the position is fuzzed by up to
  ## SonarJitterPx px on purpose, so a ring means "a shot landed near here",
  ## never "a body is exactly there".
  ##
  ## A ring persists for several frames while its shot fades, and the ids are
  ## a small recycled pool, so remember where each id sat when we first heard
  ## it and only count a landing again once that id MOVES — which only happens
  ## when the slot has been handed to a genuinely new shot.
  for o in client.spriteObjects():
    if o.objectId < SonarObjectBase or
        o.objectId >= SonarObjectBase + SonarObjectSpan:
      continue
    if o.label != LabelShotImpact:
      continue
    let
      ox = o.x + o.width div 2 + client.mapCameraX
      oy = o.y + o.height div 2 + client.mapCameraY
      p = vec(float(ox), float(oy))
    # Identify a landing by WHERE it is, never by which object id carries it.
    # The id is just this shot's index in the server's recent-shot list, and
    # that list is pruned from the front, so a shot slides down through the
    # ids as older ones expire and would otherwise read as a brand new landing
    # several times over — once per slot it passes through. Position is what
    # actually stays put for the life of a shot.
    let key = (ox, oy)
    if key in bot.sonarSeen:
      continue                           # this landing is already counted
    bot.sonarSeen[key] = bot.tick
    var
      pos = p
      exact = false
    if not bot.clockKnown:
      # Work out how far the server's clock sits from ours, which is the one
      # number standing between a heard ring and the spot it came from. A
      # wrong offset explains a given ring about two times in three, purely
      # by chance; the right one explains every ring, because the landing
      # that produced it really is in there. So let every offset that can
      # explain this ring score a point and wait: chance answers drift
      # apart, the true one never misses, and the gap only widens.
      if bot.clockVotes.len == 0:
        bot.clockVotes = newSeq[int](SonarCalMax - SonarCalMin + 1)
      if bot.clockRings < SonarCalRings:
        inc bot.clockRings
        for u in SonarCalMin .. SonarCalMax:
          if solveRing(ox, oy, bot.tick + u).len > 0:
            inc bot.clockVotes[u - SonarCalMin]
        # Lock on when exactly one offset has explained EVERY landing so
        # far. The true one can never miss; a chance one survives n rings
        # with probability about 0.63^n, so once enough have gone by, a
        # single unbeaten offset is the real one and not a lucky one.
        var
          perfect = 0
          perfectU = 0
        for i, v in bot.clockVotes:
          if v == bot.clockRings:
            inc perfect
            perfectU = i + SonarCalMin
        if bot.clockRings >= SonarCalMinRings and perfect == 1:
          bot.clockLag = perfectU
          bot.clockKnown = true
    if bot.clockKnown:
      # The tick is settled, so the only question left is which entry of the
      # box produced this ring. A shot keeps being drawn for a bounded run of
      # ticks after it is fired, so try that run and take the answer only
      # when exactly one entry across the whole run can be responsible. Two
      # survivors mean the ring genuinely cannot be told apart, and a guess
      # there is worse than the honest fuzzy reading we started with.
      # One tick, not a window. A shot is traced the instant it is fired,
      # so the tick a landing is first heard on IS the tick it was fired on,
      # and widening the search past that would only pile on coincidences
      # and bury the true answer among them. Accept the reading only when a
      # single entry can be responsible; when two can, the ring honestly
      # does not say which, and the fuzzy spot we already had is better than
      # a coin flip between them.
      let hits = solveRing(ox, oy, bot.tick + bot.clockLag)
      if hits.len == 1:
        pos = vec(float(hits[0][0]), float(hits[0][1]))
        exact = true
    bot.sonar.add(Ping(pos: pos, tick: bot.tick, hot: false, exact: exact))
  var goneKeys: seq[(int, int)]
  for k, t in bot.sonarSeen:
    if bot.tick - t > SonarSeenTtl:
      goneKeys.add(k)
  for k in goneKeys:
    bot.sonarSeen.del(k)
  var kept: seq[Ping]
  for s in bot.sonar:
    if bot.tick - s.tick <= SonarTtl:
      kept.add(s)
  if kept.len > SonarCap:
    kept = kept[kept.len - SonarCap .. ^1]
  bot.sonar = kept

proc actorsFor(client: ProtocolClient, color: string): seq[Actor] =
  ## Visible players of one color in map coordinates plus horizontal facing
  ## and hit points. The overhead "hp <n>/<max>" pip bar is fog-culled with
  ## its player, so whenever the player is visible its hp is too. The bar is
  ## not merely NEAR its player, it is centered exactly HpPipOffsetY above the
  ## body center, so match each bar to the body whose anchor point it sits on
  ## — a radius test around the body itself measures exactly HpPipOffsetY and
  ## can never come in under a radius of the same size.
  for facingRight in [true, false]:
    let label = labelPlayer(color,
      if facingRight: LabelSideRight else: LabelSideLeft)
    for o in client.spriteObjectsWithLabel(label):
      result.add(Actor(
        pos: client.mapPos(o), facingRight: facingRight, pid: -1))
  # Pin each badge to the soldier standing under it. The badge is centred on
  # the same body the sprite is drawn around, so the true pairing sits within
  # a pixel or two and a tight radius cannot reach a neighbour. Claim each
  # body once: two badges resolving onto one soldier would mean the reading
  # is wrong, and a wrong name is worse than no name.
  var taken = newSeq[bool](result.len)
  for b in client.badgesFor(color):
    var
      best = -1
      bestD = BadgeAnchorSlack
    for i in 0 ..< result.len:
      if taken[i]:
        continue
      let d = dist(result[i].pos, b.pos)
      if d < bestD:
        bestD = d
        best = i
    if best >= 0:
      taken[best] = true
      result[best].pid = b.pid
      result[best].shield = b.shield
      result[best].nade = b.nade
      result[best].arc = b.arc
  # The overhead bar is drawn in LabelHpBarSegments thirds, and labelHp owns
  # the denominator so the scan cannot spell it differently from the engine —
  # an exact-match for "hp 2/3" finds nothing in a world emitting "hp 2/4".
  # The bot still reads a LIT SEGMENT as a hit point below, which is only true
  # while the game's hitPoints equals LabelHpBarSegments (both 3 today). A
  # hitPoints retune would keep this scan correct and make that equation
  # wrong; see LabelHpBarSegments in baseline/labels.nim.
  for hp in 1 .. LabelHpBarSegments:
    for o in client.spriteObjectsWithLabel(labelHp(hp)):
      let p = client.mapPos(o)
      var best = -1
      var bestD = HpPipAnchorSlack
      for i in 0 ..< result.len:
        let anchor = vec(result[i].pos.x, result[i].pos.y - HpPipOffsetY)
        let d = dist(anchor, p)
        if d < bestD:
          bestD = d
          best = i
      if best >= 0:
        result[best].hp = hp

proc walkableAt(client: ProtocolClient, x, y: int): bool =
  if x < 0 or y < 0 or x >= client.walkabilityWidth or
      y >= client.walkabilityHeight:
    return false
  client.walkabilityMask[y * client.walkabilityWidth + x]

proc footprintFits(client: ProtocolClient, x, y: int): bool =
  ## True when the player's solid box centered at (x, y) is all walkable,
  ## mirroring canOccupy in the sim.
  for dy in -PlayerHalf .. PlayerHalf:
    for dx in -PlayerHalf .. PlayerHalf:
      if not client.walkableAt(x + dx, y + dy):
        return false
  true

proc cellOf(p: Vec): int =
  let
    cx = clamp(int(p.x) div NavCell, 0, GridW - 1)
    cy = clamp(int(p.y) div NavCell, 0, GridH - 1)
  cy * GridW + cx

proc cellCenter(cell: int): Vec =
  vec(
    float((cell mod GridW) * NavCell + NavCell div 2),
    float((cell div GridW) * NavCell + NavCell div 2)
  )

proc pixelRayClear(client: ProtocolClient, a, b: Vec): bool =
  ## True when no wall pixel blocks the segment; mirrors lineOfSightClear in
  ## the sim (walls are exactly the non-walkable pixels).
  let
    ax = int(a.x)
    ay = int(a.y)
    bx = int(b.x)
    by = int(b.y)
    steps = max(abs(bx - ax), abs(by - ay))
  if steps == 0:
    return true
  for s in 1 .. steps:
    if not client.walkableAt(ax + (bx - ax) * s div steps,
                             ay + (by - ay) * s div steps):
      return false
  true

proc rayClearCoarse(client: ProtocolClient, a, b: Vec, step: float): bool =
  ## Coarsely-sampled walkability raycast for cover scoring and exposure
  ## costing, where an occasional missed thin corner is an acceptable trade.
  let
    d = b - a
    l = d.len()
  if l < 1e-6:
    return true
  let n = max(1, int(l / step))
  for s in 1 .. n:
    let p = a + d * (float(s) / float(n))
    if not client.walkableAt(int(p.x), int(p.y)):
      return false
  true

proc openLineLen(client: ProtocolClient, a, dir: Vec, maxLen, step: float): float =
  ## Length of the wall-free ray from `a` along unit `dir`, capped at maxLen.
  ## Sizes sniper firing lines and arrow-snipe rays under the map-wide gun.
  var l = step
  while l <= maxLen:
    let p = a + dir * l
    if not client.walkableAt(int(p.x), int(p.y)):
      return l - step
    l += step
  maxLen

proc homeSign(team: Team): float =
  ## -1 toward Red's home edge (left), +1 toward Blue's (right).
  if team == Red: -1.0 else: 1.0

proc homeDeepX(team: Team): float =
  ## A point well inside our capture zone, mirrored across the map's
  ## vertical center line (150 on the default 1235px arena, scaled with
  ## the map).
  let deep = float(MapW * 150 div 1235)
  if team == Red: deep else: float(MapW - 1) - deep

proc enemy(team: Team): Team =
  ## The opposing team.
  if team == Red: Blue else: Red

proc flagHome(team: Team): Vec =
  ## The STATIC pedestal position of one team's flag: the center of the
  ## team's protected spawn pocket (matches flagHome in src/ctf/sim.nim,
  ## computed from the map size instead of the old hardcoded 186/1049).
  if team == Red:
    vec(float(CenterX - CenterX * 7 div 10), float(CenterY))
  else:
    vec(float(CenterX + (MapW - CenterX) * 7 div 10), float(CenterY))

proc chokeSpot(team: Team): Vec =
  ## Defender hold point between the flag and our home edge, mirrored
  ## exactly across the map's vertical center line. (390, 340) on the
  ## default 1235x659 arena — the gap between the diamond and disc
  ## columns — scaled proportionally so it lands in the same tactical
  ## pocket on every map.
  let
    x = float(MapW * 390 div 1235)
    y = float(MapH * 340 div 659)
  if team == Red: vec(x, y) else: vec(float(MapW - 1) - x, y)

proc nearestOpenCell(bot: Bot, cell: int): int =
  ## The nearest walkable nav cell, searched in expanding rings.
  if bot.cellWalkable[cell]:
    return cell
  let
    cx = cell mod GridW
    cy = cell div GridW
  for r in 1 .. 16:
    for dy in -r .. r:
      for dx in -r .. r:
        if abs(dx) != r and abs(dy) != r:
          continue
        let
          nx = cx + dx
          ny = cy + dy
        if nx < 0 or ny < 0 or nx >= GridW or ny >= GridH:
          continue
        if bot.cellWalkable[ny * GridW + nx]:
          return ny * GridW + nx
  cell

proc snapToCover(bot: Bot, p: Vec): Vec =
  ## The nearest cover cell within a few cells of a point, else the point.
  let
    c0 = bot.nearestOpenCell(cellOf(p))
    cx = c0 mod GridW
    cy = c0 div GridW
  var bestD = 1e18
  result = p
  for dy in -6 .. 6:
    for dx in -6 .. 6:
      let
        nx = cx + dx
        ny = cy + dy
      if nx < 0 or ny < 0 or nx >= GridW or ny >= GridH:
        continue
      let nc = ny * GridW + nx
      if not bot.coverCell[nc]:
        continue
      let d = dist(cellCenter(nc), p)
      if d < bestD:
        bestD = d
        result = cellCenter(nc)

proc scanPost(
    bot: Bot, client: ProtocolClient, eSign, wantY: float
): tuple[hold, peek: Vec, ready: bool] =
  ## Finds one overwatch sniper post for the side whose guns point along
  ## `eSign`: a cover cell hugging the center ring, shielded from the front,
  ## with a sideways peek cell that owns the LONGEST clear firing line — the
  ## map-wide gun makes the lane length the post's value.
  var bestScore = 1e18
  for cy in 0 ..< GridH:
    for cx in 0 ..< GridW:
      let c = cy * GridW + cx
      if not bot.coverCell[c]:
        continue
      let
        p = cellCenter(c)
        fwd = eSign * (p.x - float(CenterX))
      if fwd > -40.0 or fwd < -160.0:
        continue                         # this side of the ring, hugging it
      if rayClearCoarse(client, p, p + vec(eSign * CoverShieldDist, 0.0), 4.0):
        continue                         # nothing shields us from the front
      var
        peek: Vec
        peekLine = 0.0
      for dyc in [-2, 2, -1, 1]:
        let ny = cy + dyc
        if ny < 0 or ny >= GridH or not bot.cellWalkable[ny * GridW + cx]:
          continue
        let q = cellCenter(ny * GridW + cx)
        let line = openLineLen(client, q, vec(eSign, 0.0), FireRange, 6.0)
        if line > peekLine:
          peekLine = line
          peek = q
      if peekLine < PeekLineDist:
        continue
      # The firing-line length dominates; the position terms break near-ties
      # toward the wanted flank height and hugging the flag ring.
      let score = abs(p.y - wantY) + abs(fwd + 90.0) * 0.7 - peekLine * 0.7
      if score < bestScore:
        bestScore = score
        result.hold = p
        result.peek = peek
        result.ready = true

proc pickPost(bot: Bot, client: ProtocolClient) =
  ## Chooses our own overwatch post (the overwatch seat only): fire from the
  ## peek, duck back to the hold during cooldown.
  bot.postReady = false
  if bot.role != Overwatch:
    return
  let
    eSign = -homeSign(bot.team)
    wantY = float(CenterY) + 60.0
  let post = bot.scanPost(client, eSign, wantY)
  if post.ready:
    bot.postHold = post.hold
    bot.postPeek = post.peek
    bot.postReady = true

proc findEnemyPosts(bot: Bot, client: ProtocolClient) =
  ## Precomputes the standing virtual threats every carrier run has to
  ## respect, fed into exposure costing and lane choice: the mirrored ENEMY
  ## overwatch post (a stationary, hidden killer), and the ENEMY RESPAWN
  ## GROUND — every kill puts an armed enemy back on the map facing our way,
  ## so that ground is permanently watched even when no track remembers
  ## anybody there.
  ##
  ## GV25 (coworld-ctf 72fd075, 2026-07-29) is why the second one is a ZONE
  ## and no longer a point. Respawns used to land on the pedestal, so
  ## `flagHome(enemy)` named the pocket mouth exactly and the threat was a
  ## genuine chokepoint. They now land at a uniform random walkable spot
  ## anywhere in the team's home capture zone (`randomEndzonePosition`), which
  ## on a sides map is a full-height column at that end of the arena — a fixed
  ## respawn point can no longer be camped, and by the same token can no
  ## longer be predicted. Keeping the single pedestal point would concentrate
  ## avoidance on one square of a column that respawns spread across.
  ##
  ## Sampled rather than swept: the exposure pass costs a ray per candidate
  ## cell per spot, and with ExposureRange at 380px a few samples down the
  ## column already union into its whole reachable frontage. The samples sit
  ## at the pedestal's x, which is the column edge NEAREST us — the outer part
  ## of the zone is deeper still, so this errs toward treating respawns as
  ## closer than average rather than further.
  bot.enemyPosts.setLen(0)
  bot.enemyRespawnSpots.setLen(0)
  let post = bot.scanPost(client, homeSign(bot.team), float(CenterY) + 60.0)
  if post.ready:
    bot.enemyPosts.add(post.peek)
  let zoneX = flagHome(enemy(bot.team)).x
  for i in 1 .. EnemyRespawnSamples:
    bot.enemyRespawnSpots.add(
      vec(zoneX, float(MapH) * float(i) / float(EnemyRespawnSamples + 1)))

proc adoptMapSize(client: ProtocolClient) =
  ## The walkability sprite spans the whole arena: adopt its dimensions as
  ## THE map size and rederive everything position-shaped. The game selects
  ## its map per episode (config mapPath: "arena" or "arena-large"), so the
  ## bot must read the size off the wire instead of assuming it.
  MapW = client.walkabilityWidth
  MapH = client.walkabilityHeight
  CenterX = MapW div 2
  CenterY = MapH div 2
  GridW = (MapW + NavCell - 1) div NavCell
  GridH = (MapH + NavCell - 1) div NavCell
  LaneMid = float(CenterY)
  LaneBottom = float(MapH) - LaneTop
  FireRange = float(MapW) + 15.0

proc buildNavGrid(bot: Bot, client: ProtocolClient) =
  ## Erodes the pixel walkability mask into a footprint-safe nav grid, then
  ## derives the cover model (cover cells, overwatch post, defender choke).
  adoptMapSize(client)
  bot.cellWalkable = newSeq[bool](GridW * GridH)
  for cy in 0 ..< GridH:
    for cx in 0 ..< GridW:
      bot.cellWalkable[cy * GridW + cx] = client.footprintFits(
        cx * NavCell + NavCell div 2, cy * NavCell + NavCell div 2)
  bot.coverCell = newSeq[bool](GridW * GridH)
  for cy in 0 ..< GridH:
    for cx in 0 ..< GridW:
      let c = cy * GridW + cx
      if not bot.cellWalkable[c]:
        continue
      block adjacency:
        for dy in -1 .. 1:
          for dx in -1 .. 1:
            if dx == 0 and dy == 0:
              continue
            let
              nx = cx + dx
              ny = cy + dy
            if nx < 0 or ny < 0 or nx >= GridW or ny >= GridH:
              continue
            if not bot.cellWalkable[ny * GridW + nx]:
              bot.coverCell[c] = true
              break adjacency
  bot.exposure = newSeq[bool](GridW * GridH)
  bot.navDist = newSeq[int32](GridW * GridH)
  bot.navGoal = -1
  bot.pickPost(client)
  bot.findEnemyPosts(client)
  bot.chokeHold = bot.snapToCover(chokeSpot(bot.team))
  bot.navBuilt = true

const NavNeighbors = [
  (1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)
]

proc rebuildExposure(bot: Bot, client: ProtocolClient) =
  ## Marks nav cells the freshest remembered enemies — plus the mirrored
  ## enemy sniper posts, which are stationary hidden threats all game —
  ## could shoot into (inside gun range with a coarsely-clear line). Used as
  ## a soft path cost.
  for i in 0 ..< bot.exposure.len:
    bot.exposure[i] = false
  var
    threatSpots: seq[Vec] = bot.enemyPosts & bot.enemyRespawnSpots
    threats = 0
  for t in bot.enemies:                  # already sorted freshest-first
    if threats >= ExposureThreats or bot.tick - t.lastSeen > ExposureTrackTtl:
      break
    inc threats
    threatSpots.add(t.pos)
  for spot in threatSpots:
    let
      x0 = max(0, int(spot.x - ExposureRange) div NavCell)
      x1 = min(GridW - 1, int(spot.x + ExposureRange) div NavCell)
      y0 = max(0, int(spot.y - ExposureRange) div NavCell)
      y1 = min(GridH - 1, int(spot.y + ExposureRange) div NavCell)
    for cy in y0 .. y1:
      for cx in x0 .. x1:
        let c = cy * GridW + cx
        if bot.exposure[c] or not bot.cellWalkable[c]:
          continue
        let p = cellCenter(c)
        if dist(p, spot) <= ExposureRange and
            rayClearCoarse(client, spot, p, 8.0):
          bot.exposure[c] = true
  # Ground where a teammate was just shot dead is ground somebody has a
  # clear line onto, whether or not we can see who or from where. Mark it
  # directly: no line-of-sight test belongs here, because the whole point is
  # that this reaches places we cannot see. The radius stays tight — the
  # heard position is fuzzed by up to SonarJitterPx px and the danger is at
  # the spot itself, not spread over a gun's range around it, so widening
  # this would wall off honest routes on the strength of one death.
  for s in bot.sonar:
    if not s.hot or bot.tick - s.tick > ExposureTrackTtl:
      continue
    # A spot we pinned exactly needs only the ground around the spot; a spot
    # we merely heard has to cover everywhere the fuzz could have moved it,
    # which is most of why the wide radius exists at all.
    let
      r = if s.exact: SonarExactRadius else: SonarHotRadius
      x0 = max(0, int(s.pos.x - r) div NavCell)
      x1 = min(GridW - 1, int(s.pos.x + r) div NavCell)
      y0 = max(0, int(s.pos.y - r) div NavCell)
      y1 = min(GridH - 1, int(s.pos.y + r) div NavCell)
    for cy in y0 .. y1:
      for cx in x0 .. x1:
        let c = cy * GridW + cx
        if bot.exposure[c] or not bot.cellWalkable[c]:
          continue
        if dist(cellCenter(c), s.pos) <= r:
          bot.exposure[c] = true

proc computeField(bot: Bot, client: ProtocolClient, goal: int) =
  ## Cost field (Dijkstra) over the nav grid toward one goal cell. Steps cost
  ## StepCost/DiagCost and entering a threat-exposed cell adds ExposedCost, so
  ## paths prefer segments that keep obstacles between us and known enemies.
  ## Diagonal steps require both orthogonal neighbors open (no corner cuts).
  bot.rebuildExposure(client)
  for i in 0 ..< bot.navDist.len:
    bot.navDist[i] = -1
  var heap = initHeapQueue[(int32, int32)]()
  bot.navDist[goal] = 0
  heap.push((0'i32, int32(goal)))
  while heap.len > 0:
    let
      (dcur, cur32) = heap.pop()
      cur = int(cur32)
    if dcur > bot.navDist[cur]:
      continue
    let
      cx = cur mod GridW
      cy = cur div GridW
    for (dx, dy) in NavNeighbors:
      let
        nx = cx + dx
        ny = cy + dy
      if nx < 0 or ny < 0 or nx >= GridW or ny >= GridH:
        continue
      let nc = ny * GridW + nx
      if not bot.cellWalkable[nc]:
        continue
      if dx != 0 and dy != 0 and
          not (bot.cellWalkable[cy * GridW + nx] and
               bot.cellWalkable[ny * GridW + cx]):
        continue
      var step = (if dx != 0 and dy != 0: DiagCost else: StepCost)
      if bot.exposure[nc]:
        step += ExposedCost
      let nd = bot.navDist[cur] + step
      if bot.navDist[nc] < 0 or nd < bot.navDist[nc]:
        bot.navDist[nc] = nd
        heap.push((nd, int32(nc)))

proc gridRayClear(bot: Bot, a, b: Vec): bool =
  ## True when the eroded nav grid is open along the whole segment.
  let
    d = b - a
    steps = int(d.len() / 4.0) + 1
  for s in 0 .. steps:
    let p = a + d * (float(s) / float(steps))
    if not bot.cellWalkable[cellOf(p)]:
      return false
  true

proc navSteer(bot: Bot, client: ProtocolClient, me, target: Vec): Vec =
  ## Direction along the cost-field path toward `target`, with waypoint
  ## lookahead. Falls back to a beeline before the grid exists or when
  ## unreachable.
  if not bot.navBuilt:
    return target - me
  let goal = bot.nearestOpenCell(cellOf(target))
  if goal != bot.navGoal or bot.tick - bot.navStamp >= RepathTicks:
    bot.computeField(client, goal)
    bot.navGoal = goal
    bot.navStamp = bot.tick
  let start = bot.nearestOpenCell(cellOf(me))
  if bot.navDist[start] < 0:
    return target - me
  if bot.navDist[start] == 0:
    return target - me
  var
    node = start
    waypoint = cellCenter(start)
    haveClear = false
  for _ in 0 ..< LookaheadCells:
    var next = -1
    var bestD = bot.navDist[node]
    let
      cx = node mod GridW
      cy = node div GridW
    for (dx, dy) in NavNeighbors:
      let
        nx = cx + dx
        ny = cy + dy
      if nx < 0 or ny < 0 or nx >= GridW or ny >= GridH:
        continue
      let nc = ny * GridW + nx
      if bot.navDist[nc] < 0 or bot.navDist[nc] >= bestD:
        continue
      if dx != 0 and dy != 0 and
          not (bot.cellWalkable[cy * GridW + nx] and
               bot.cellWalkable[ny * GridW + cx]):
        continue
      bestD = bot.navDist[nc]
      next = nc
    if next < 0:
      break
    node = next
    if bot.gridRayClear(me, cellCenter(node)):
      waypoint = cellCenter(node)
      haveClear = true
    else:
      break
  if not haveClear:
    waypoint = cellCenter(node)
  waypoint - me

proc findDuckCell(bot: Bot, client: ProtocolClient, me, threat: Vec): int =
  ## The nearest directly-reachable cell around us whose center the threat
  ## cannot see; -1 when no nearby cover breaks the line.
  result = -1
  let
    c0 = cellOf(me)
    cx0 = c0 mod GridW
    cy0 = c0 div GridW
  var bestD = 1e18
  for dy in -DuckSearchCells .. DuckSearchCells:
    for dx in -DuckSearchCells .. DuckSearchCells:
      let
        nx = cx0 + dx
        ny = cy0 + dy
      if nx < 0 or ny < 0 or nx >= GridW or ny >= GridH:
        continue
      let nc = ny * GridW + nx
      if not bot.cellWalkable[nc]:
        continue
      let p = cellCenter(nc)
      if not bot.gridRayClear(me, p):
        continue
      if client.pixelRayClear(p, threat):
        continue                          # the threat can still see this cell
      let d = dist(p, me)
      if d < bestD:
        bestD = d
        result = nc

proc firstBlockPoint(bot: Bot, a, b: Vec): Vec =
  ## Where the line from a to b first runs into something solid — the corner
  ## we would be peeking around. Returns b when the line is already open.
  let
    d = b - a
    steps = max(1, int(dist(a, b) / float(NavCell)))
  for i in 1 .. steps:
    let p = a + d * (float(i) / float(steps))
    if not bot.cellWalkable[cellOf(p)]:
      return p
  b

proc nadeSafe(bot: Bot, me, p: Vec): bool =
  ## True when a blast landing at p would not also catch us or one of ours.
  ##
  ## This matters far more than it looks. The blast is a plain radius test on
  ## the server with no wall check and no team check at all: everyone inside
  ## it loses two of three hit points, through cover, teammates and thrower
  ## included. Cover does not protect our own side from our own grenade any
  ## more than it protects theirs.
  ##
  ## A mate's position is only as good as its age, so the exclusion grows with
  ## staleness rather than trusting a fix from seconds ago. Mates we have not
  ## seen at all are not accounted for here, which is the honest limit of this
  ## guard -- so the throws it clears are the ones we can see are clear.
  if dist(p, me) < NadeMinRange:
    return false
  for m in bot.mates:
    let age = bot.tick - m.lastSeen
    if age > NadeMateTtl:
      continue
    if dist(m.pos, p) <= NadeBlast + NadeMateDrift * float(age):
      return false
  true

proc findPeekCell(bot: Bot, client: ProtocolClient, me, aim: Vec): int =
  ## A directly-reachable cell that opens a firing line to `aim` within gun
  ## range; -1 when no sidestep grants the shot.
  ##
  ## Of the cells that grant it, take the one standing FURTHEST BACK from the
  ## corner rather than the nearest one. Both get the same shot, but they do
  ## not cost the same to take. Hugging the corner and leaning out swings the
  ## whole body into the open room at once, in view of everything in it. From
  ## further back the same corner still hides most of that room: the wedge that
  ## opens past it is narrow, so the shot comes with far less of us on show,
  ## and only what is inside that narrow slice can shoot back.
  ##
  ## Walking is not free, so the stand-off is bought, not demanded: each pixel
  ## of it is worth a little less than a pixel of extra travel, and past
  ## PeekStandoffCap it stops being worth anything at all.
  result = -1
  let
    c0 = cellOf(me)
    cx0 = c0 mod GridW
    cy0 = c0 div GridW
    corner = bot.firstBlockPoint(me, aim)
  var bestD = 1e18
  for dy in -PeekSearchCells .. PeekSearchCells:
    for dx in -PeekSearchCells .. PeekSearchCells:
      let
        nx = cx0 + dx
        ny = cy0 + dy
      if nx < 0 or ny < 0 or nx >= GridW or ny >= GridH:
        continue
      let nc = ny * GridW + nx
      if not bot.cellWalkable[nc]:
        continue
      let p = cellCenter(nc)
      if dist(p, aim) > FireRange or not bot.gridRayClear(me, p):
        continue
      if not client.pixelRayClear(p, aim):
        continue
      let d = dist(p, me) -
        min(dist(p, corner), PeekStandoffCap) * PeekStandoffWeight
      if d < bestD:
        bestD = d
        result = nc

proc updateTracks(bot: Bot, tracks: var seq[Track], seen: seq[Actor]) =
  ## Matches this frame's sightings to remembered tracks and prunes stale
  ## ones. Velocity is a blended px/tick estimate used to lead shots.
  var claimed = newSeq[bool](tracks.len)
  # Named sightings first, and by name alone. Proximity is only ever a guess
  # at which remembered player a body is, and it guesses wrong exactly when it
  # matters most — two enemies crossing swap their tracks, so the velocity we
  # lead shots with inverts on both. A badge settles it outright, and it stays
  # right however far the player moved since we last saw them, which is what
  # makes a sighting after a long blind stretch usable instead of a new track.
  var order: seq[int]
  for i in 0 ..< seen.len:
    if seen[i].pid >= 0:
      order.add(i)
  for i in 0 ..< seen.len:
    if seen[i].pid < 0:
      order.add(i)
  for ai in order:
    let a = seen[ai]
    var
      best = -1
      bestD = TrackMatchDist
    if a.pid >= 0:
      for i in 0 ..< tracks.len:
        if not claimed[i] and tracks[i].pid == a.pid:
          best = i
          break
    if best < 0:
      for i in 0 ..< tracks.len:
        if claimed[i]:
          continue
        # A track that already answers to a different name is not this body.
        if a.pid >= 0 and tracks[i].pid >= 0:
          continue
        let d = dist(tracks[i].pos, a.pos)
        if d < bestD:
          bestD = d
          best = i
    if best >= 0:
      let
        dt = float(max(1, bot.tick - tracks[best].lastSeen))
        v = (a.pos - tracks[best].pos) * (1.0 / dt)
      tracks[best].vel = vec(
        clamp((tracks[best].vel.x + v.x) * 0.5, -3.0, 3.0),
        clamp((tracks[best].vel.y + v.y) * 0.5, -3.0, 3.0)
      )
      tracks[best].pos = a.pos
      tracks[best].facingRight = a.facingRight
      tracks[best].lastSeen = bot.tick
      if a.hp > 0:
        tracks[best].hp = a.hp
      if a.pid >= 0:
        # The badge is the only reading here that cannot be stale: it is on
        # screen right now, so it overwrites the carry outright rather than
        # being merged with what we last believed.
        tracks[best].pid = a.pid
        tracks[best].shield = a.shield
        tracks[best].nade = a.nade
        tracks[best].arc = a.arc
      claimed[best] = true
    else:
      tracks.add(Track(
        pos: a.pos, lastSeen: bot.tick, facingRight: a.facingRight, hp: a.hp,
        pid: a.pid, shield: a.shield, nade: a.nade, arc: a.arc))
      claimed.add(true)
  var kept: seq[Track]
  for t in tracks:
    if bot.tick - t.lastSeen <= TrackHoldTtl:
      kept.add(t)
  kept.sort(proc(a, b: Track): int = cmp(b.lastSeen, a.lastSeen))
  if kept.len > TrackCap:                # there are only eight real players
    kept.setLen(TrackCap)
  tracks = kept

proc trackPickups(
  positions: var seq[Vec],
  absentAt: var seq[int],
  seen: seq[Vec],
  me: Vec,
  tick: int,
) =
  ## Shared fog-honest pickup memory: learn spots on sight, mark a spot
  ## taken only when we pass close enough that the bubble would show it,
  ## and believe it restocked once its respawn timer has elapsed.
  for p in seen:
    var known = false
    for i in 0 ..< positions.len:
      if dist(positions[i], p) < 24.0:
        known = true
        absentAt[i] = -1
    if not known:
      positions.add(p)
      absentAt.add(-1)
  for i in 0 ..< positions.len:
    if dist(positions[i], me) <= MedKitSeenClear and absentAt[i] < 0:
      var present = false
      for p in seen:
        if dist(positions[i], p) < 24.0:
          present = true
      if not present:
        absentAt[i] = tick

proc pickupAvailable(absentAt: seq[int], i, tick: int): bool =
  absentAt[i] < 0 or tick - absentAt[i] > PickupRespawn + 48

proc nadeAvailable(bot: Bot, i: int): bool =
  ## Whether a corner grenade is believed to be sitting there right now. The
  ## refill is quick, so a corner we emptied is worth returning to sooner than
  ## any other pickup on the map.
  bot.nadeAbsentAt[i] < 0 or bot.tick - bot.nadeAbsentAt[i] > NadeRespawn + 24

proc kitAvailable(bot: Bot, i: int): bool =
  ## Whether a discovered med kit spot is believed stocked right now: never
  ## seen empty, or its 30s respawn has elapsed since we saw it taken.
  bot.kitAbsentAt[i] < 0 or bot.tick - bot.kitAbsentAt[i] > MedKitRespawn + 48

proc bestKitDetour(bot: Bot, me, dest: Vec, budget: float): int =
  ## The stocked kit spot whose me->kit->dest detour costs the fewest extra
  ## path px over going straight to dest; -1 when none fits the budget.
  result = -1
  var best = budget
  for i in 0 ..< bot.kitPos.len:
    if not bot.kitAvailable(i):
      continue
    let cost = dist(me, bot.kitPos[i]) + dist(bot.kitPos[i], dest) - dist(me, dest)
    if cost < best:
      best = cost
      result = i

proc resetTransient(bot: Bot) =
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
  # Re-trust the self marker each round: the fuzz verdict is a property of the
  # SERVER build, so it will simply be re-earned within seconds if the marker
  # really is fuzzed, and a stale distrust would cost us the clamp all match.
  bot.selfAimTrusted = true
  bot.selfAimPrev = -1
  bot.selfAimStrikes = 0
  bot.scanHigh = false
  bot.stuckTicks = 0
  bot.jinkUntil = 0
  bot.behindLines = false
  bot.navGoal = -1

proc scanAim(bot: Bot, watch: Vec): int =
  ## The scan-sweep aim while holding a position: rake the vision cone back
  ## and forth across the arc around the `watch` heading with real rotation.
  ## Flip the sweep direction whenever the current end is nearly reached.
  let center = bradsOf(watch)
  var goal = (center + (if bot.scanHigh: ScanArc else: -ScanArc) +
    AimBrads) mod AimBrads
  if abs(bradsErr(goal, bot.estAim)) <= CombatDeadband:
    bot.scanHigh = not bot.scanHigh
    goal = (center + (if bot.scanHigh: ScanArc else: -ScanArc) +
      AimBrads) mod AimBrads
  goal

proc couldTrade(bot: Bot, me, myDir: Vec, at: Vec, vel: Vec,
    age: float, reach: float): bool =
  ## Could this enemy and us plausibly get a shot at each other within the
  ## next couple of seconds, given where each of us is going?
  ##
  ## This is the difference between watching something and staring at scenery.
  ## A body parked behind a wall we are walking parallel to will never be
  ## shootable no matter how long we point at it, and every tick spent aiming
  ## there is a tick the cone is not covering ground that matters. So walk
  ## both of us forward a little and ask whether the line ever opens: theirs
  ## from where they were last going, ours from where our feet are taking us.
  ##
  ## A stale sighting is treated as standing still. It is the only honest
  ## guess -- running an old velocity out for seconds would fling the estimate
  ## somewhere nobody ever was, and then confidently aim at it.
  let him0 = if age > float(FreshShotTicks): at else: at + vel * age
  for step in 0 .. FeasSteps:
    let
      dt = float(FeasHorizon * step div FeasSteps)
      him = if age > float(FreshShotTicks): him0 else: him0 + vel * dt
      us = me + myDir * (OwnEstSpeed * dt)
    if dist(us, him) <= reach and bot.gridRayClear(us, him):
      return true
  false

proc preAimBearing(bot: Bot, me, myDir: Vec, reach: float,
    maxRange = PreAimRange, maxAge = PreAimPingTtl): int =
  ## The bearing contact is most likely to arrive from, or -1 when nothing we
  ## know says anything useful about it.
  ##
  ## The turret is the slow part of a fight: target priority already prices a
  ## swing at TraversePxPerBrad because a target near the current aim line dies
  ## sooner than a nearer one behind us. That price is avoidable. Every fight
  ## we can hear is a fight we could already be pointing at, so when nothing is
  ## engageable the gun should be laid on wherever a body is most likely to
  ## step out, instead of idly following our own feet.
  ##
  ## A remembered sighting beats a heard landing: it is an enemy's position,
  ## while a landing is only where a shot stopped. But a landing carries
  ## through walls from anywhere on the map, so it is very often the only
  ## thing on offer -- and one that killed someone, at a spot we pinned
  ## exactly, is worth nearly as much as having seen them.
  result = -1
  var best = -1.0
  for t in bot.enemies:
    let age = bot.tick - t.lastSeen
    if age > min(PreAimTrackTtl, maxAge):
      continue
    let d = dist(t.pos, me)
    if d > maxRange:
      continue
    if not bot.couldTrade(me, myDir, t.pos, t.vel, float(age), reach):
      continue
    let score = d + float(age) * PreAimAgePx
    if best < 0.0 or score < best:
      best = score
      result = bradsOf(t.pos - me)
  for s in bot.sonar:
    let age = bot.tick - s.tick
    if age > min(PreAimPingTtl, maxAge):
      continue
    let d = dist(s.pos, me)
    if d > maxRange:
      continue
    var score = d + float(age) * PreAimAgePx + PreAimPingCost
    if s.hot:
      score -= PreAimHotBonus
    if s.exact:
      score -= PreAimExactBonus
    # A landing is not a body, so ask the same question of the spot it marks:
    # if nothing could shoot from there at us, or us at it, it is scenery.
    if not bot.couldTrade(me, myDir, s.pos, vec(0.0, 0.0), 0.0, reach):
      continue
    if best < 0.0 or score < best:
      best = score
      result = bradsOf(s.pos - me)

proc safestLaneY(bot: Bot, me: Vec): float =
  ## The carrier's lane home: fewest remembered enemies AND the best cover
  ## continuity — under map-wide guns a lane whose run has no cover nearby is
  ## a shooting gallery even when it looks empty.
  var
    bestLane = LaneMid
    bestScore = 1e18
  for lane in [LaneTop, LaneMid, LaneBottom]:
    var score = abs(me.y - lane) / 500.0     # mild bias toward the nearest lane
    for t in bot.enemies:
      let towardHome =
        if bot.team == Red: t.pos.x < me.x + 200
        else: t.pos.x > me.x - 200
      if towardHome and abs(t.pos.y - lane) < 120:
        score += 1.0
    for post in bot.enemyPosts:
      # The mirrored enemy sniper posts are standing threats on the run home
      # even when nobody has been seen there.
      if abs(post.y - lane) < 120:
        score += 1.0
    # Respawn ground is charged at most ONCE, however many samples stand in
    # for it: the samples are one diffuse threat, not N independent snipers,
    # and letting them stack would swamp both the sniper post and every
    # remembered enemy above. Under GV25's full-height column this lands on
    # every lane equally — which is the honest answer, since a uniform respawn
    # draw no longer favours any lane — and so cancels out of the comparison.
    for spot in bot.enemyRespawnSpots:
      if abs(spot.y - lane) < 120:
        score += 1.0
        break
    if bot.navBuilt:
      # Cover continuity: sample the run home along the lane and charge each
      # sample with no cover cell in its 3x3 nav neighborhood.
      let
        goalX = homeDeepX(bot.team)
        stepX = (if goalX > me.x: 32.0 else: -32.0)
      var
        x = me.x
        samples = 0
        bare = 0
      while (stepX > 0.0 and x < goalX) or (stepX < 0.0 and x > goalX):
        inc samples
        let
          c = cellOf(vec(x, lane))
          cx = c mod GridW
          cy = c div GridW
        block covered:
          for dy in -1 .. 1:
            for dx in -1 .. 1:
              let
                nx = cx + dx
                ny = cy + dy
              if nx >= 0 and ny >= 0 and nx < GridW and ny < GridH and
                  bot.coverCell[ny * GridW + nx]:
                break covered
          inc bare
        x += stepX
      if samples > 0:
        score += float(bare) / float(samples) * 2.0
    if score < bestScore:
      bestScore = score
      bestLane = lane
  bestLane

proc friendlyBlocked(bot: Bot, me, aim: Vec, enemyDist: float): bool =
  ## True when a remembered teammate could eat the shot: the bullet is a
  ## corridor hitscan (~14px half width) along the aim ray and the server
  ## kills the NEAREST player inside it, friend or foe — 8v8 puts many
  ## teammates downrange. The fire axis is the exact angle the turret would
  ## fire at right now.
  let dir = bradsDir(bradsOf(aim - me))
  for t in bot.mates:
    let age = float(bot.tick - t.lastSeen)
    if age > 36:
      continue
    let
      rel = t.pos - me
      d = rel.len()
      along = dot(rel, dir)
    if along <= 0 or d < 1e-6:
      continue
    if along >= enemyDist + 14.0:
      continue                          # beyond the target: the target dies first
    if abs(cross(rel, dir)) < CorridorHalfWidth + age * 0.35:
      return true
  false

proc trackSelfAimTrust(bot: Bot, centre, advance: int) =
  ## Decides whether the self marker is still an honest readback of our aim,
  ## and latches it off for the episode once it demonstrably is not.
  ##
  ## GV24 (coworld-ctf d2526eb, 2026-07-29) renders soldier sprites in PLAYER
  ## views at a fuzzed aim: a deterministic offset within +-AimRenderFuzzBrads
  ## (14 brads, ~20 degrees), held 12 ticks and then re-rolled. As shipped it
  ## covered every soldier "self included", which would make the turret clamp
  ## below actively harmful — it is the one place the bot treats a rendered
  ## value as ground truth. GV26 exempted the self marker again, so on GV26+
  ## the clamp is exactly as sound as it always was.
  ##
  ## ANSWERED, 2026-07-30: the league runs coworld package `ctf` v0.7.124,
  ## built from coworld-ctf beae1614, where GameVersion is 27 and the GV26
  ## self exemption is present. So the clamp below is CORRECT as it stands
  ## and this check never fires today. It is kept as a regression tripwire,
  ## not a live unknown: GV24 did fuzz the self marker once and GV26 walked
  ## it back, and the game moved GV24 -> GV27 inside two days, so "self is
  ## exempt" is a current fact rather than a guarantee. If it ever stops
  ## being true, this fails loudly instead of quietly corrupting estAim.
  ##
  ## The test is PHYSICAL, not statistical: our own aim turns at most AimRate
  ## brads per elapsed tick, so between two frames that both drew a marker, an
  ## honest bucket centre cannot have moved further than that plus one bucket
  ## of quantisation. A fuzz re-roll swings the reported centre by up to 28
  ## brads while the turret has barely moved, which no true readback can do.
  ## That asymmetry is what makes this safe to run unconditionally: under an
  ## exact marker the bound holds by construction, so it cannot fire on GV26+.
  ## The bound depends on AimRate matching the server's aimTurnRate — verified
  ## equal to 5 in the league's own game_config on 2026-07-30. A retune there
  ## would break the bot's dead reckoning first and this check second.
  ##
  ## Three strikes, not one, so a dropped packet cannot cost us the clamp; and
  ## irregular frames are skipped outright, because a long gap is exactly
  ## where `advance` is least trustworthy as a tick count.
  if not bot.selfAimTrusted:
    return
  if centre < 0:
    bot.selfAimPrev = -1        # dead or not yet drawn: no continuity to test
    return
  if bot.selfAimPrev >= 0 and advance <= 4:
    let
      moved = abs(bradsErr(centre, bot.selfAimPrev))
      possible = AimRate * advance + SoldierRotBrads
    if moved > possible:
      inc bot.selfAimStrikes
      if bot.selfAimStrikes >= SelfAimFuzzStrikes:
        bot.selfAimTrusted = false
        echo "self marker renders FUZZED aim (GV24 without the GV26 self ",
          "exemption): turret clamp disabled, dead reckoning only"
  bot.selfAimPrev = centre

proc decide(bot: Bot, client: ProtocolClient): uint8 =
  ## Core CTF policy for one frame.
  let
    myColor = (if bot.team == Red: "red" else: "blue")
    enemyColor = (if bot.team == Red: "blue" else: "red")
    (alive, me) = client.findSelf(myColor)
  if not alive:
    # Dead: inputs are ignored, so there is nothing to steer. But a dead
    # viewer is a GHOST viewer — the server sends no fog at all and streams
    # every living BODY on the map, both teams, so the respawn wait is three
    # seconds of free full-map positions. Bank them before dropping the frame.
    # Only the "player <color>" bodies are alive: our own body and every other
    # corpse ship under the distinct "corpse <color>" label and never enter a
    # track. We have no self marker while dead, so nothing here may use our
    # position; the track update does not need one.
    #
    # Update BOTH sides, never the enemy alone. The friendly-fire guard only
    # weighs mates seen recently, so refreshing enemies by themselves would
    # leave every mate stale at exactly the moment we respawn holding eight
    # fresh enemy fixes — the guard would wave through every shot and we would
    # cut down our own escorts along the spawn axis.
    #
    # Bodies are all that arrive. The overhead hp bars are gated on ordinary
    # visibility with no ghost exemption, and vision reports nothing at all for
    # a dead viewer, so a ghost frame carries no pips at all. updateTracks
    # reads a missing pip as "no news" and keeps the last value — which, on a
    # track the ghost refreshes every tick, would pin a stale reading in place
    # indefinitely, leaving a wounded enemy that reached a med kit still
    # marked as nearly dead. Drop what we cannot see rather than preserve it.
    bot.updateTracks(bot.enemies, client.actorsFor(enemyColor))
    bot.updateTracks(bot.mates, client.actorsFor(myColor))
    for t in bot.enemies.mitems:
      t.hp = 0
    for t in bot.mates.mitems:
      t.hp = 0
    # The server drops a carried charge on death; keep our mirror of it in
    # step, or the next life predicts a throw preview that does not exist
    # and waves off a real grenade landing near that phantom point.
    bot.nadeCharge = 0
    bot.firedLast = false
    bot.rotSign = 0
    bot.wasDead = true
    return 0
  if bot.wasDead:
    # Respawned: the server points the aim back at the enemy side.
    bot.wasDead = false
    bot.estAim = spawnAim(bot.team)
  # Absolute turret bound. Our own soldier ships as one of SoldierRots
  # pre-rotated sprites and the server picks the one nearest the real aim, so
  # the sprite id proves the true aim lies within SoldierRotHalf brads of that
  # step's centre. That is a BOUND, not a reading: inside the bucket the dead
  # reckoning is already consistent with what the server drew and is the finer
  # estimate of the two, so snapping it to the centre would usually make it
  # WORSE. Correct only when the estimate has drifted clean out of the bucket,
  # and then only as far as the nearest edge that is still possible.
  #
  # The rounding is to the NEAREST step, which makes the bucket half-open:
  # centre - SoldierRotHalf is still this step, but centre + SoldierRotHalf
  # already rounds into the next one. So the last angle this sprite proves is
  # one brad below that, and the high side has to be corrected one brad early
  # or it would park the estimate on a value the sprite rules out.
  #
  # All of that holds only while the marker draws our TRUE aim. GV24 can make
  # it draw a fuzzed one, in which case this "bound" would be a lie that drags
  # the estimate off a correct dead reckoning — so the marker has to earn the
  # trust first. See trackSelfAimTrust.
  let centre = client.selfAimBucket(myColor)
  bot.trackSelfAimTrust(centre, max(1, client.frameAdvance))
  if centre >= 0 and bot.selfAimTrusted:
    let c = bradsErr(centre, bot.estAim)
    if c > SoldierRotHalf:
      # The bucket sits counter-clockwise of the estimate: the estimate is
      # below the bucket's low edge, so the nearest possible aim is the
      # low edge itself.
      bot.estAim = floorMod(centre - SoldierRotHalf, AimBrads)
    elif c < -SoldierRotHalf + 1:
      # Mirror case: the estimate has run past the bucket's high edge.
      bot.estAim = floorMod(centre + SoldierRotHalf - 1, AimBrads)
  # Plasma arcs and shields share the endzone back columns (inset 50)
  # but are vertically SEPARATED: plasma arcs in the top half (quarter height),
  # shields in the bottom half (three-quarter height). Seed the spots up
  # front (they are deterministic; the fog would otherwise hide them until
  # we are already on top of them), then let sightings refine the nudged
  # positions.
  if bot.plasmaPos.len == 0:
    for spot in [vec(50.0, float(MapH div 4)),
                 vec(float(MapW) - 50.0, float(MapH div 4))]:
      bot.plasmaPos.add(spot)
      bot.plasmaAbsentAt.add(-1)
    for spot in [vec(50.0, float(3 * MapH div 4)),
                 vec(float(MapW) - 50.0, float(3 * MapH div 4))]:
      bot.shieldPos.add(spot)
      bot.shieldAbsentAt.add(-1)
    # The four corner grenade spawns, seeded for the same reason: they sit at
    # a fixed inset from each corner, and waiting to SEE one means never going
    # for it, because nothing routes near a corner by accident.
    for spot in [vec(NadeSpawnInset, NadeSpawnInset),
                 vec(NadeSpawnInset, float(MapH) - NadeSpawnInset),
                 vec(float(MapW) - NadeSpawnInset, NadeSpawnInset),
                 vec(float(MapW) - NadeSpawnInset, float(MapH) - NadeSpawnInset)]:
      bot.nadePos.add(spot)
      bot.nadeAbsentAt.add(-1)
  var plasmaSeen, shieldSeen: seq[Vec]
  # LabelSprayCan, not "plasma arc": coworld-ctf 3428bd8 (2026-07-28) reskinned
  # the cone weapon and renamed its wire label. The internal `hasPlasmaArc`
  # field kept the old name upstream, and so do the identifiers here, but the
  # LABEL is the observation contract and it changed. This archive forked at
  # 5997098 (07-22) and kept scanning for the dead string, which is why sighting
  # refinement for spray-can spots and every carrier read had gone silently
  # blind — an empty seq, no error, exactly the ButtonC shape.
  for o in client.spriteObjectsWithLabel(LabelSprayCan):
    plasmaSeen.add(client.mapPos(o))
  for o in client.spriteObjectsWithLabel(LabelShield):
    shieldSeen.add(client.mapPos(o))
  trackPickups(bot.plasmaPos, bot.plasmaAbsentAt, plasmaSeen, me, bot.tick)
  trackPickups(bot.shieldPos, bot.shieldAbsentAt, shieldSeen, me, bot.tick)
  var nadeSeen: seq[Vec]
  for o in client.spriteObjectsWithLabel(LabelGrenade):
    let gp = client.mapPos(o)
    if gp.x < 40.0 or gp.y < 40.0 or gp.x > float(MapW - 40) or
        gp.y > float(MapH - 40):
      continue                           # the HUD indicator shares the label
    nadeSeen.add(gp)
  trackPickups(bot.nadePos, bot.nadeAbsentAt, nadeSeen, me, bot.tick)
  # Own carry state: the carried markers float over their carrier, and a
  # shield carrier's HUD reads 6 hp (the marker is the fallback).
  var hasPlasma = false
  for o in client.spriteObjectsWithLabel(LabelSprayCanCarried):
    if dist(client.mapPos(o), me) <= 30.0:
      hasPlasma = true
      break
  var hasShield = bot.hp > MaxHp
  if not hasShield:
    for o in client.spriteObjectsWithLabel(LabelShieldCarried):
      if dist(client.mapPos(o), me) <= 30.0:
        hasShield = true
        break

  let
    shotReady = client.spriteObjectsWithLabel(LabelFireIcon).len > 0 and
      not hasPlasma                      # the spray can replaces the gun; a shield
                                         # only slows it (3x cooldown)
    seenEnemies = client.actorsFor(enemyColor)
    seenMates = client.actorsFor(myColor)
  bot.updateTracks(bot.enemies, seenEnemies)
  bot.updateTracks(bot.mates, seenMates)
  if seenEnemies.len > 0:
    bot.lastEnemySeen = bot.tick
  bot.hearShots(client)
  # Two weak senses make one strong one. A landing ring says a shot hit
  # somewhere near a spot but never who or what it hit; the scoreboard says
  # a player died but never where. Put them together and the pair pins the
  # kill: the shot that killed a teammate landed ON that teammate, so a ring
  # heard in the same breath as our own death count rising marks a place an
  # enemy was shooting into a moment ago, from somewhere with a clear line
  # to it. That holds anywhere on the map, through any wall, with nothing
  # visible. Mark the freshest unclaimed landings rather than every recent
  # one, so a single death lights a single spot.
  let sb = client.readScoreboard()
  if sb.ok:
    let now = [Red: sb.red, Blue: sb.blue]
    if bot.killsInit:
      let
        foeTeam = if bot.team == Red: Blue else: Red
        theirKills = now[foeTeam] - bot.kills[foeTeam]
        ourKills = now[bot.team] - bot.kills[bot.team]
      if theirKills > 0:
        var want = theirKills
        for i in countdown(bot.sonar.high, 0):
          if want <= 0:
            break
          if bot.sonar[i].hot or bot.tick - bot.sonar[i].tick > SonarHotTtl:
            continue
          bot.sonar[i].hot = true
          dec want
      # The mirror reading, and the useful one for going on the offensive.
      # A landing that coincides with THEIR loss is a spot one of them was
      # standing on a moment ago, which is worth throwing at. A landing that
      # coincides with OURS is a spot one of US was standing on, and the
      # shooter is somewhere else entirely along a line we cannot see —
      # bombing that marks our own casualty, not their killer.
      if ourKills > 0:
        var want = ourKills
        for i in countdown(bot.sonar.high, 0):
          if want <= 0:
            break
          if bot.sonar[i].foe or bot.sonar[i].hot or
              bot.tick - bot.sonar[i].tick > SonarHotTtl:
            continue
          bot.sonar[i].foe = true
          dec want
    bot.kills = now
    bot.killsInit = true

  # Flag bookkeeping (two flags; a carried flag rides its carrier's exact
  # position). The enemy flag can only be carried by OUR team, so its sprite
  # is never fogged and fully describes our attack (pedestal / on me / on a
  # mate). Our own flag can only be carried by the enemy: on its pedestal it
  # is safe, visible off-pedestal is a live thief fix, and ABSENT means a
  # fogged thief is running it toward its home edge.
  var
    iCarry = false
    mateCarry = false
    mateCarryPos: Vec
  let
    stealTarget = flagHome(enemy(bot.team))  # the enemy pedestal is static
    ownHome = flagHome(bot.team)
    # Since the 0.7.8 renderer restore the objective is labeled a FLAG again,
    # split into distinct pedestal/carried sprites: "<color> flag planted" is
    # the always-visible pedestal banner, "<color> flag" the carried banner
    # centered exactly on its carrier (fogged with the carrier).
    enemyPlanted = client.spriteObjectsWithLabel(labelFlagPlanted(enemyColor))
    enemyFlags = client.spriteObjectsWithLabel(labelFlag(enemyColor))
    ownPlanted = client.spriteObjectsWithLabel(labelFlagPlanted(myColor))
    ownFlags = client.spriteObjectsWithLabel(labelFlag(myColor))
  # Own hit points from the HUD "lives <hp>hp x<lives>" text sprite.
  for o in client.spriteObjects():
    if o.label.startsWith(LabelPrefixLives):
      let text = o.label[LabelPrefixLives.len .. ^1]
      let cut = text.find("hp")
      if cut > 0:
        try:
          # Unclamped past MaxHp: a shield carrier reads 6 hp on the HUD.
          bot.hp = clamp(parseInt(text[0 ..< cut]), 1, 9)
        except ValueError:
          discard
      break

  # Med kits: learn the two center-line spots on sight; presence is
  # fog-gated, so an empty spot only counts as TAKEN when we pass close
  # enough that the bubble would show it.
  var kitSeen: seq[Vec]
  for o in client.spriteObjectsWithLabel(LabelMedKit):
    kitSeen.add(client.mapPos(o))
  for p in kitSeen:
    var known = false
    for i in 0 ..< bot.kitPos.len:
      if dist(bot.kitPos[i], p) < 24.0:
        known = true
        bot.kitAbsentAt[i] = -1
    if not known:
      bot.kitPos.add(p)
      bot.kitAbsentAt.add(-1)
  for i in 0 ..< bot.kitPos.len:
    if dist(bot.kitPos[i], me) <= MedKitSeenClear and bot.kitAbsentAt[i] < 0:
      var present = false
      for p in kitSeen:
        if dist(bot.kitPos[i], p) < 24.0:
          present = true
      if not present:
        bot.kitAbsentAt[i] = bot.tick



  if enemyPlanted.len > 0:
    discard                              # enemy flag sits home: nobody carries
  elif enemyFlags.len > 0:
    # Carried banner in sight, centered exactly on its carrier. "Am I the
    # carrier" is "is the flag on ME and on nobody else" — a visible mate
    # closer to it than us means the mate is the carrier.
    let fp = client.mapPos(enemyFlags[0])
    var mateCloser = false
    let dSelf = dist(fp, me)
    for t in bot.mates:
      if bot.tick - t.lastSeen <= 2 and dist(t.pos, fp) < dSelf:
        mateCloser = true
        break
    if dSelf <= CarrySelfRadius and not mateCloser:
      iCarry = true
    else:
      mateCarry = true                   # only a teammate can be carrying it
      mateCarryPos = fp
      bot.mateFixPos = fp
      bot.mateFixTick = bot.tick
  else:
    # No planted banner and no carried banner in the frame: the flag is off
    # its pedestal on a FOGGED carrier — and only OUR team can carry it, so a
    # teammate is running it home right now even though we cannot see it.
    # Without this inference the whole wave keeps pressing an empty pedestal
    # instead of covering the run. Escort a dead-reckoned fix: the last
    # sighting (or the pedestal it was lifted from) advanced homeward at
    # carrier speed.
    mateCarry = true
    var est =
      if bot.mateFixTick > 0: bot.mateFixPos
      else: stealTarget
    let elapsed = float(bot.tick - max(bot.mateFixTick, bot.gameStart))
    est.x += homeSign(bot.team) * min(
      abs(ownHome.x - est.x),
      elapsed * CarrierEstSpeed
    )
    mateCarryPos = est
  var ownStolen = ownPlanted.len == 0
  if ownPlanted.len > 0:
    bot.carrierSeen = -100_000           # our flag is safely home
  elif ownFlags.len > 0:
    # The thief holding our flag is inside our vision: take a fresh fix.
    let fp = client.mapPos(ownFlags[0])
    bot.carrierPos = fp
    bot.carrierVel = vec(0, 0)
    for t in bot.enemies:
      if dist(t.pos, fp) <= 8:
        bot.carrierVel = t.vel
        break
    bot.carrierSeen = bot.tick




  # Flank progress: sticky so lane-runners do not oscillate at the boundary.
  if bot.role in {FlankTop, FlankBottom}:
    let fwd = -homeSign(bot.team) * (me.x - float(CenterX))
    if fwd >= FlankDepth - 50.0:
      bot.behindLines = true
    elif fwd < 20.0:
      bot.behindLines = false

  # Endgame push: our flag is safe and nobody on OUR side has seen an enemy
  # for a long while deep into the game. The survivors by then are usually
  # the defensive seats, and holding their posts forever is a guaranteed
  # tiebreak stalemate — break the posts and go win by capture (the enemy
  # team pushes symmetrically, so somebody makes something happen).
  let pushOut = not ownStolen and (
    (bot.tick - bot.gameStart > PushOutMinGame and
     bot.tick - bot.lastEnemySeen > PushOutTicks) or
    # Late all-in: a timeout is a scoreless draw, so deep into a game with no
    # capture the posts are worth nothing — break them and go win. Standoffs
    # keep enemies in sight, so the quiet-field trigger above never fires
    # against a peek-duck opponent; this one is on the clock.
    bot.tick - bot.gameStart > LatePushTick
  )

  # Movement target from role and flag situation.
  var target: Vec
  if iCarry:
    # Run the stolen enemy flag home along the emptiest lane; the exposure
    # cost in the path field keeps the route hugging cover past remembered
    # enemies.
    let
      pocket = flagHome(enemy(bot.team))
      laneY = bot.safestLaneY(me)
    if abs(me.x - pocket.x) < 60.0 and abs(me.y - laneY) > 70.0:
      # Bug out of the pocket VERTICALLY first: every kill respawns an
      # armed enemy at this pedestal whose spawn aim points
      # along the east-west axis — pure-vertical movement exits that cone
      # fastest, then the border lane runs home outside it.
      target = vec(pocket.x, laneY)
    else:
      target = vec(homeDeepX(bot.team), laneY)
    # A hurt carrier detours through a stocked med kit on the way home: the
    # run crosses the center line anyway, kits are hurt-only pickups (a
    # healthy escort cannot waste one), and a full-heal carrier survives
    # pocket exits and mid crossings that kill a 1 hp one.
    if bot.hp < MaxHp:
      let kit = bot.bestKitDetour(me, target, MedKitCarrierBudget)
      if kit >= 0:
        target = bot.kitPos[kit]
  elif ownStolen and (bot.role == HomeDefender or
      bot.tick - bot.carrierSeen <= ThiefFixTtl):
    # An enemy is RUNNING OUR FLAG: with a fresh fix on it, EVERY role drops
    # what it is doing and converges on the thief's predicted route — an
    # enemy capture ends the episode against us, so nothing we were
    # otherwise doing outranks the intercept. Without
    # a fix, only the back line guards the crossing lanes: the thief is
    # fogged but MUST cross mid toward its home edge, so the defender holds
    # the lane nearest the last fix and sweeps its vision — reacquisition
    # takes eyes, not magic.
    if bot.tick - bot.carrierSeen <= ThiefFixTtl:
      # Converge on the thief's predicted path toward the enemy capture edge.
      var predicted = bot.carrierPos +
        bot.carrierVel * float(18 + bot.tick - bot.carrierSeen)
      predicted.x += -homeSign(bot.team) * 40.0
      target = vec(clamp(predicted.x, 20.0, float(MapW - 20)),
                   clamp(predicted.y, 20.0, float(MapH - 20)))
    else:
      var laneY = LaneMid
      if bot.carrierSeen > -100_000:
        var bestD = 1e18
        for lane in [LaneTop, LaneMid, LaneBottom]:
          if abs(bot.carrierPos.y - lane) < bestD:
            bestD = abs(bot.carrierPos.y - lane)
            laneY = lane
      target = vec(float(CenterX) - homeSign(bot.team) * 60.0, laneY)
  elif mateCarry:
    case bot.role
    of MidTop, FlankTop:
      target = mateCarryPos + vec(homeSign(bot.team) * 46.0, -30.0)
    of MidBottom, FlankBottom:
      # Rear guard: sit between the carrier and the enemy pocket it just
      # robbed — respawners chase from there, and the gun kills the NEAREST
      # player in the cone, so a body on the ray shields the carrier.
      target = mateCarryPos + vec(
        -homeSign(bot.team) * 42.0,
        (if bot.role == MidBottom: 22.0 else: -22.0)
      )
    of MidGuard:
      # Screen the carrier from the nearest remembered threat.
      var threat = -1
      var threatD = 1e18
      for i in 0 ..< bot.enemies.len:
        let d = dist(bot.enemies[i].pos, mateCarryPos)
        if d < threatD:
          threatD = d
          threat = i
      if threat >= 0:
        target = mateCarryPos + norm(bot.enemies[threat].pos - mateCarryPos) * 30.0
      else:
        target = mateCarryPos + vec(-homeSign(bot.team) * 32.0, 0.0)
    of Overwatch:
      # The posts already overwatch the carrier's retreat across mid.
      target =
        if bot.postReady: bot.postHold
        else: mateCarryPos + vec(-homeSign(bot.team) * 32.0, 0.0)
    of HomeDefender:
      target = bot.chokeHold
  elif bot.role == HomeDefender and not pushOut:
    # Hold the choke on our pedestal approach; break off to chase the nearest
    # intruder on our half (every steal has to come through here).
    var intruder = -1
    var intruderD = 1e18
    for i in 0 ..< bot.enemies.len:
      let onOurHalf =
        if bot.team == Red: bot.enemies[i].pos.x < float(CenterX) + 60
        else: bot.enemies[i].pos.x > float(CenterX) - 60
      if not onOurHalf:
        continue
      let d = dist(bot.enemies[i].pos, me)
      if d < intruderD:
        intruderD = d
        intruder = i
    if intruder >= 0:
      target = bot.enemies[intruder].pos + bot.enemies[intruder].vel * 6.0
    else:
      target = bot.chokeHold
  elif bot.role == Overwatch and not pushOut:
    if bot.postReady:
      # Peek-and-shoot cycle: hold behind the post; with the gun up and a
      # remembered enemy in reach, sidestep to the peek cell to open the
      # line (the combat block below takes the shot and ducks us back).
      target = bot.postHold
      if shotReady:
        for t in bot.enemies:
          if bot.tick - t.lastSeen <= 24 and
              dist(t.pos, bot.postHold) < FireRange + 30.0:
            target = bot.postPeek
            break
    else:
      target = vec(float(CenterX) + homeSign(bot.team) * 70.0, float(CenterY))
  else:
    # Attackers: route to the ENEMY pedestal — a fixed, known position by
    # team side. The lead rusher races it dead straight (its seat spawns at
    # pedestal height), the second mid trails behind and offset so one enemy
    # cone cannot kill the pair; flankers run the extreme lanes deep past
    # mid, then hit the pedestal pocket from behind.
    target = stealTarget
    case bot.role
    of MidBottom:
      if dist(me, stealTarget) > 90:
        target = stealTarget + vec(homeSign(bot.team) * 34.0, 26.0)
    of MidGuard:
      if dist(me, stealTarget) > 90:
        target = stealTarget + vec(homeSign(bot.team) * 60.0, -26.0)
    of FlankTop, FlankBottom:
      # Run the wide lane deep, then turn straight in for the grab so the
      # flankers hit the pocket together with the mid trio instead of
      # trickling in.
      let laneY = (if bot.role == FlankTop: LaneTop else: LaneBottom)
      if not bot.behindLines and dist(me, stealTarget) > 170.0:
        target = vec(float(CenterX) - homeSign(bot.team) * FlankDepth, laneY)
    else:
      discard

  # The mid trio plays for the flag, not for position: pickup races and
  # carrier chases are lost to peek/duck detours, so mids keep moving and
  # shoot on the move whenever a mate is not already carrying.
  let rushing = not iCarry and not mateCarry and
    bot.role in {MidTop, MidBottom, MidGuard}
  # The pocket endgame: duelling at the pocket edge is an infinite respawn
  # grinder (respawners reappear armed AT the pedestal), so the
  # attacker CLOSEST to the pedestal commits to the touch, unarmed and
  # undistracted, while the rest of the wave keeps its guns up to cover the
  # grab — even a suicide grab forces the enemy back onto defense, and a
  # lucky one starts the capture run.
  var nearestMateToSteal = 1e18
  for t in bot.mates:
    if bot.tick - t.lastSeen > 48:
      continue
    nearestMateToSteal = min(nearestMateToSteal, dist(t.pos, stealTarget))
  let pocketRush = not iCarry and not mateCarry and
    bot.role in {MidTop, MidBottom, MidGuard, FlankTop, FlankBottom} and
    dist(me, stealTarget) < PocketRushRange and
    dist(me, stealTarget) < nearestMateToSteal + 8.0

  # Combat: the nearest fresh track with a clear pixel ray AND a mate-free
  # fire cone is the engage target; the nearest fresh-but-wall-blocked track
  # is the peek candidate. The map-wide gun engages fresh tracks far beyond
  # the view, so chases keep killing after the target leaves the window —
  # but objective play caps the range: the carrier only fights point-blank,
  # rushers racing for the steal and escorts guarding a run only fight what
  # is actually in the way, instead of frag-chasing across the map.
  let maxEngage =
    if hasShield and not hasPlasma:      # slow gun (3x cooldown): only fight
      CarrierFireRange                   # what is point-blank in the way
    elif hasPlasma: PlasmaReach + 6.0    # cone weapon: only close range matters
    elif pocketRush: 0.0
    elif iCarry: CarrierFireRange
    elif ownStolen and bot.tick - bot.carrierSeen <= ThiefFixTtl: FireRange
      # A live fix on the enemy running our flag lifts every role's range
      # cap: the map-wide gun is the fastest flag return there is.
    elif rushing: RushEngageRange
    elif mateCarry: EscortEngageRange
    else: FireRange
  # (Focus-fire intel used to be computed here, off the mates' rendered aim
  # dots. The engine retired that sprite family in 2026-07-16 and GV24 fuzzed
  # the replacement, so there is no longer any readback of where a mate is
  # about to shoot. See the note by TraversePxPerBrad.)
  var
    engage = -1
    engageD = maxEngage
    engagePrio = maxEngage
    aim: Vec
    blockedAim: Vec
    haveBlocked = false
    blockedD = maxEngage
  for i in 0 ..< bot.enemies.len:
    let t = bot.enemies[i]
    if bot.tick - t.lastSeen > FreshShotTicks:
      continue
    let predicted = t.pos + t.vel * (float(bot.tick - t.lastSeen) + LeadTicks)
    let d = dist(predicted, me)
    if d >= maxEngage:
      continue
    # Target priority: distance plus the turret swing needed to lay on the
    # target (the traverse is slow, so a target near the current aim line
    # dies sooner than a nearer one behind us), discounted for wounded
    # targets (a 1-hp enemy dies to one shot — finish it before it resets on
    # respawn) and for targets a visible mate is already lined up on (focus
    # fire). The discounts are tiebreaks between comparably-engageable
    # targets, deliberately smaller than a real positional difference.
    var prio = d +
      float(abs(bradsErr(bradsOf(predicted - me), bot.estAim))) * TraversePxPerBrad
    if t.hp in 1 ..< MaxHp:
      prio -= float(MaxHp - t.hp) * HpFocusBonus
    # What the target is holding changes what it costs us to leave alive and
    # what it costs to kill. A spray can out-ranges and out-damages our gun,
    # so the arc carrier is the one that decides the fight and is worth
    # swinging onto first. A shield soaks a shot before any of them count,
    # so an unshielded enemy beside a shielded one dies sooner for the same
    # effort. Both stay smaller than a real difference in position, like the
    # discounts above — this orders comparable targets, it does not drag us
    # across the map.
    if t.arc:
      prio -= ArcThreatBonus
    if t.shield:
      prio += ShieldCostPenalty
    if ownStolen and bot.tick - bot.carrierSeen <= ThiefFixTtl and
        dist(t.pos, bot.carrierPos) <= 48.0:
      # This track IS (or shadows) the enemy running our flag: shoot it
      # before anything else — a dead carrier returns the flag instantly.
      prio -= ThiefFocusBonus
    if client.pixelRayClear(me, predicted):
      if bot.friendlyBlocked(me, predicted, d):
        continue                        # prefer a target with an empty corridor
      if engage < 0 or prio < engagePrio:
        engagePrio = prio
        engageD = d
        engage = i
        aim = predicted
    elif d < blockedD:
      blockedD = d
      blockedAim = predicted
      haveBlocked = true

  # The nearest remembered enemy that could be threatening us right now,
  # used to pick which line to break when ducking through cooldown.
  var
    nearThreat = -1
    nearThreatD = DuckRange
  for i in 0 ..< bot.enemies.len:
    if bot.tick - bot.enemies[i].lastSeen > 30:
      continue
    let d = dist(bot.enemies[i].pos, me)
    if d < nearThreatD:
      nearThreatD = d
      nearThreat = i

  # Grenades (0.7.0): a lobbed 2-hp blast that flies over every wall — the
  # counter to cover-campers the hitscan gun can never reach. Carry one when a
  # corner pickup is a short detour away; spend it on a wall-blocked fresh
  # track (value the gun cannot collect) or on a tight enemy pair in range.
  var carryingNade = false
  for o in client.spriteObjectsWithLabel(LabelGrenadeCarried):
    # The marker floats above-right of its carrier (+8 x, ~-20 y from center).
    if dist(client.mapPos(o), me) <= 30.0:
      carryingNade = true
      break
  var
    nadeAim = -1
    nadeThrowD = 0.0
  if carryingNade and not iCarry:
    # What a grenade is FOR here: it flies over walls in a straight line and
    # bursts on a plain radius, with no wall test on the damage either. Cover
    # stops bullets and does nothing whatever against this. So the throws worth
    # making are exactly the ones the gun cannot make -- and that includes
    # enemies we can no longer see at all, not merely ones we can see but
    # cannot shoot.
    var bestScore = 1e18
    proc offer(p: Vec, cost: float) =
      ## Weigh one candidate landing, nearest-and-surest first.
      let d = dist(p, me)
      if d < NadeMinRange or d > NadeMaxRange:
        return
      if d + cost >= bestScore:
        return
      if not bot.nadeSafe(me, p):
        return
      bestScore = d + cost
      nadeAim = bradsOf(p - me)
      nadeThrowD = d
    for i in 0 ..< bot.enemies.len:
      let
        t = bot.enemies[i]
        age = bot.tick - t.lastSeen
      if age > NadeMemTtl:
        continue
      if age <= FreshShotTicks:
        # Seen right now: lead it, and throw only when the gun cannot do the
        # job anyway, or when two of them are stood close enough to share one.
        let p = t.pos + t.vel * float(age)
        let blocked = not client.pixelRayClear(me, p)
        var paired = false
        if not blocked:
          for j in 0 ..< bot.enemies.len:
            if j != i and bot.tick - bot.enemies[j].lastSeen <= FreshShotTicks and
                dist(bot.enemies[j].pos, p) <= NadeBlast:
              paired = true
              break
        if blocked or paired:
          offer(p, 0.0)
      else:
        # Out of sight but not out of mind: someone who stepped behind cover
        # is still standing roughly where we last had them, and cover is no
        # defence against this weapon. Do not run the old velocity out over
        # the gap -- a stale heading extrapolated for seconds lands the throw
        # somewhere nobody ever was.
        offer(t.pos, NadeHeldCost)
    for sp in bot.sonar:
      if not sp.foe or bot.tick - sp.tick > NadeFoePingTtl:
        continue
      offer(sp.pos, NadeFoePingCost)

  # Weapon pickups. SHIELD-THEN-STEAL: the enemy endzone shield sits just
  # behind their pedestal — a rusher near the pocket grabs 6 hp first and
  # steals second (the run home is what kills 3 hp carriers). Defensive
  # roles never take a shield (it slows the gun 3x). PLASMA ARCS arm the
  # pocket brawlers: attackers detour a little for one on the way in — the
  # pocket duel is close-range, where an instant lethal cone beats any gun.
  if not iCarry and not hasShield and bot.role == MidGuard and
      not (ownStolen and bot.tick - bot.carrierSeen <= ThiefFixTtl):
    # ONE designated shield-runner (MidGuard, the trailing mid): the shield
    # sits ~136px BEYOND the enemy pedestal, so the trip costs ~270 path px —
    # never spend the LEAD rusher's tempo on it (first steal wins races).
    # The second wave arrives as a 6 hp bruiser: it steals if the flag is
    # still planted, escorts (and re-steals after a failed run) if not.
    var best = -1
    var bestCost = ShieldStealDetour
    for i in 0 ..< bot.shieldPos.len:
      if not pickupAvailable(bot.shieldAbsentAt, i, bot.tick):
        continue
      if homeSign(bot.team) * (bot.shieldPos[i].x - float(CenterX)) > 0.0:
        continue                         # OUR endzone shield: leave the gun
      let cost = dist(me, bot.shieldPos[i]) + dist(bot.shieldPos[i], stealTarget) -
        dist(me, stealTarget)
      if cost < bestCost:
        bestCost = cost
        best = i
    if best >= 0:
      target = bot.shieldPos[best]
  elif not iCarry and not hasPlasma and
      bot.role in {MidTop, MidBottom, MidGuard, FlankTop, FlankBottom} and
      not mateCarry and not pocketRush:
    # Plasma top-up: cone-armed pocket brawls win close range. Cheap when we
    # are already visiting the endzone column (shield chain) or passing by.
    #
    # Keepers are left out of this on purpose, and it is not an oversight to
    # be tidied up: the arc REPLACES the gun rather than adding to it, so a
    # defender holding one can only reach about four squares and stops being
    # able to turn anything back before it arrives. Ranged denial is the whole
    # job of the post.
    for i in 0 ..< bot.plasmaPos.len:
      if not pickupAvailable(bot.plasmaAbsentAt, i, bot.tick):
        continue
      if dist(me, bot.plasmaPos[i]) <= PlasmaDetour:
        target = bot.plasmaPos[i]
        break

  # Med kit heal detour (hurt bots only; the carrier handles its own detour
  # in the carry branch). Wounded: a short opportunistic detour. Critical
  # (1 hp): a heal outranks the current errand at much longer reach — a
  # healed body is a respawn we did not spend. Never while committing to the
  # pocket touch or chasing the enemy running our flag, and the CARRIER gets
  # right of way: if our flag runner is closer to the kit than we are, we
  # leave it — kits are hurt-only pickups, so deferring costs nothing when
  # the carrier turns out healthy.
  if bot.hp < MaxHp and not iCarry and not pocketRush and
      not (ownStolen and bot.tick - bot.carrierSeen <= ThiefFixTtl):
    let reach = if bot.hp <= 1: MedKitCriticalReach else: MedKitDetour
    let kit = bot.bestKitDetour(me, target, reach)
    if kit >= 0 and not (mateCarry and
        dist(mateCarryPos, bot.kitPos[kit]) < dist(me, bot.kitPos[kit]) + 100.0):
      target = bot.kitPos[kit]

  var armed = false
  if not carryingNade and not iCarry and not mateCarry and not pocketRush:
    # Collect a pickup: anyone grabs one within a short detour, and the two
    # flankers own their lane's friendly-side corner spawn — it sits right on
    # their border route, so they arm up on the way out every respawn cycle.
    for o in client.spriteObjectsWithLabel(LabelGrenade):
      let p = client.mapPos(o)
      if p.x < 40.0 or p.y < 40.0 or p.x > float(MapW - 40) or
          p.y > float(MapH - 40):
        continue                     # HUD indicator shares the label
      let laneMatch =
        (bot.role == FlankTop and p.y < float(CenterY) and
         homeSign(bot.team) * (p.x - float(CenterX)) > 0) or
        (bot.role == FlankBottom and p.y > float(CenterY) and
         homeSign(bot.team) * (p.x - float(CenterX)) > 0)
      let reach = if laneMatch: 1e9 else: NadePickupDetour
      if dist(p, me) <= reach:
        target = p
        armed = true
        break
    if not armed:
      # Go and FETCH, rather than wait to trip over one. The corner spawns
      # refill every few seconds all match, so the supply is effectively
      # endless and the team was collecting about two of them a game — not
      # because grenades are scarce but because nothing ever walks into a
      # corner. Each flanker owns the corner on its own side of its own lane,
      # which is close to the route it already runs, and only goes when it is
      # empty-handed and the corner is believed stocked.
      var
        bestD = NadeFarmReach
        pick = -1
      for i in 0 ..< bot.nadePos.len:
        let p = bot.nadePos[i]
        let mine =
          (bot.role == FlankTop and p.y < float(CenterY)) or
          (bot.role == FlankBottom and p.y > float(CenterY))
        if not mine or homeSign(bot.team) * (p.x - float(CenterX)) <= 0:
          continue
        if not bot.nadeAvailable(i):
          continue
        let d = dist(p, me)
        if d < bestD:
          bestD = d
          pick = i
      if pick >= 0:
        target = bot.nadePos[pick]

  # Grenade danger: a visible throw-target ring marks where an enemy's lob
  # will land, and an airborne grenade is seconds from bursting — anything
  # inside the blast radius eats 2 of 3 hit points. Fleeing the marked spot
  # outranks every movement goal except nothing: dead carriers drop the run.
  var
    nadeDanger = false
    nadeDangerFrom: Vec
  # Our OWN windup draws that ring too: the server previews the landing point
  # of every charging player we can see, and we can always see ourselves. The
  # preview starts at a tap's distance and stretches with the charge, so for
  # the first few ticks of every throw it sits just inside the flee radius and
  # the bot sprints backwards away from its own grenade. Predict where our own
  # ring must be and skip THAT ONE ring; every other ring, and every airborne
  # grenade, still counts.
  #
  # Exactly one ring is ours, so pick the single closest match rather than
  # discarding everything near the prediction. In a mutual grenade duel both
  # previews sit on the line joining the two throwers, so a plain radius test
  # would swallow the enemy's ring along with ours and leave us standing in
  # the blast.
  let ownNadeLanding =
    if bot.nadeCharge > 0:
      me + bradsDir(bot.estAim) * (NadeTapRange +
        (NadeMaxRange - NadeTapRange) *
          float(min(bot.nadeCharge, NadeFullChargeTicks)) /
          float(NadeFullChargeTicks))
    else:
      vec(-1e9, -1e9)                    # off-map: matches nothing
  var
    ownRingId = -1
    ownRingD = OwnNadeRingSlack
  if bot.nadeCharge > 0:
    for o in client.spriteObjectsWithLabel(LabelThrowTarget):
      let d = dist(client.mapPos(o), ownNadeLanding)
      if d < ownRingD:
        ownRingD = d
        ownRingId = o.objectId
  block nadeDangerScan:
    for label in [LabelThrowTarget, LabelGrenadeAir]:
      for o in client.spriteObjectsWithLabel(label):
        let p = client.mapPos(o)
        if label == LabelThrowTarget and o.objectId == ownRingId:
          continue                       # our own charge preview
        if dist(p, me) <= NadeBlast + 18.0:
          nadeDanger = true
          nadeDangerFrom = p
          break nadeDangerScan

  # Turret + locomotion, decided together but on separate buttons: moveMask
  # is the d-pad, desiredAim feeds the rotate buttons, wantFire pulls A.
  var
    moveMask: uint8
    desiredAim = -1
    deadband = CombatDeadband
    wantFire = false
    acted = false
    holdStill = false
    nadeC = false
  if bot.nadeCharge > 0 or nadeAim >= 0:
    # Charge-throw: lay the turret on the lob line, then hold C for the ticks
    # the planned distance needs and release — the grenade leaves along the
    # CURRENT aim on release, so the turret keeps correcting while charging.
    if bot.nadeCharge == 0:
      bot.nadeNeed = max(3, int(float(NadeFullChargeTicks) *
        (nadeThrowD - NadeTapRange) / (NadeMaxRange - NadeTapRange)))
    if nadeAim >= 0:
      desiredAim = nadeAim
    if bot.nadeCharge > 0 or (desiredAim >= 0 and
        abs(bradsErr(desiredAim, bot.estAim)) <= CombatDeadband + 2):
      if bot.nadeCharge < bot.nadeNeed:
        nadeC = true
        inc bot.nadeCharge
      else:
        bot.nadeCharge = 0           # release this tick = the throw
    holdStill = true
    acted = true
  elif hasPlasma and engage >= 0:
    # Plasma cone: ignition is INSTANT (no windup, no aim lock), reaches 4
    # squares in a ~14-degree half-angle cone, stays on 5 ticks, and deals
    # 3 hp (lethal to bare cogs) — press A the moment the victim is inside
    # reach and roughly in front.
    desiredAim = bradsOf(aim - me)
    let err = abs(bradsErr(desiredAim, bot.estAim))
    # Ignite a little early on the angle: the cone stays on 5 ticks and
    # tracks our aim, so the ongoing traverse sweeps it across the target.
    if engageD <= PlasmaReach - 6.0 and err <= PlasmaHalfBrads + 3:
      wantFire = true
      holdStill = true
    else:
      moveMask = octantBits(aim - me)    # charge in
    acted = true
  elif engage >= 0 and shotReady:
    # Traverse onto the target and fire once the corridor covers it: the
    # perpendicular miss of the current aim error at the target's range must
    # sit inside the ~14px bullet corridor. Advancing scales that miss down
    # linearly, so keep closing while the turret settles.
    desiredAim = bradsOf(aim - me)
    let
      err = abs(bradsErr(desiredAim, bot.estAim))
      perpMiss = engageD * sin(float(err) * PI / float(AimBrads div 2))
    wantFire = perpMiss <= FireSlackPx
    moveMask = octantBits(aim - me)
    acted = true
  elif not iCarry and not rushing and not pocketRush and not shotReady and
      nearThreat >= 0:
    # Cooldown: duck behind the nearest cover that breaks the threat's line
    # and hold there until the gun is back up, keeping the aim (and the
    # vision cone) on the arc the threat would push through.
    let duck = bot.findDuckCell(client, me, bot.enemies[nearThreat].pos)
    if duck >= 0:
      desiredAim = bradsOf(bot.enemies[nearThreat].pos - me)
      if dist(cellCenter(duck), me) < 5.0:
        holdStill = true
      else:
        moveMask = octantBits(cellCenter(duck) - me)
      acted = true
  elif not iCarry and not rushing and shotReady and haveBlocked:
    # Peek: PRE-LAY the aim on the blocked target while stepping sideways to
    # the nearest cell that opens the firing line — the engage branch fires
    # the moment the ray clears, with the traverse already done.
    desiredAim = bradsOf(blockedAim - me)
    let peek = bot.findPeekCell(client, me, blockedAim)
    if peek >= 0 and dist(cellCenter(peek), me) > 4.0:
      moveMask = octantBits(cellCenter(peek) - me)
      acted = true

  if not acted:
    # Threat jink: sidestep a visible enemy that is aiming our way while our
    # own shot is not lined up, instead of walking into its muzzle.
    var threat = -1
    var threatD = ThreatRange
    for i in 0 ..< seenEnemies.len:
      let a = seenEnemies[i]
      let facingMe =
        (a.facingRight and a.pos.x < me.x) or
        (not a.facingRight and a.pos.x > me.x)
      let d = dist(a.pos, me)
      if facingMe and d < threatD:
        threatD = d
        threat = i
    if threat >= 0 and not iCarry and not pocketRush:
      let away = norm(me - seenEnemies[threat].pos)
      var side = vec(-away.y, away.x)
      if (bot.tick div 12 + bot.slot div 2) mod 2 == 0:
        side = side * -1.0
      if not bot.gridRayClear(me, me + side * 24.0):
        side = side * -1.0
      moveMask = octantBits(side + away * 0.4)
      if desiredAim < 0:
        desiredAim = bradsOf(seenEnemies[threat].pos - me)
    elif bot.role in {Overwatch, HomeDefender} and
        dist(me, target) < 6.0:
      # Holding a watch position: the aim carries the vision cone, so sweep
      # it back and forth across the arc threats cross while standing still.
      # While our flag is stolen the thief comes from our own half;
      # otherwise intruders come from the enemy half.
      let watch =
        if ownStolen: vec(homeSign(bot.team), 0.0)
        else: vec(-homeSign(bot.team), 0.0)
      if desiredAim < 0:
        # Standing a watch, there are no feet to follow -- but the sweep is
        # not idleness, it is what covers the whole approach. Only give it up
        # for something close and current enough to be worth staring at; for
        # anything older or further off, raking the arc finds more than
        # fixing on a spot a body has already left.
        let pa = bot.preAimBearing(me, vec(0.0, 0.0), maxEngage,
          PreAimWatchRange, PreAimWatchTtl)
        if pa >= 0:
          desiredAim = pa
        if desiredAim < 0:
          desiredAim = bot.scanAim(watch)
      holdStill = true
    else:
      # Take ground, then hold it, for as long as the match is level or
      # losing. Pushing into their half while even spends the one advantage
      # holding ground buys, so the hold runs until we are genuinely ahead
      # AND have banked enough kills. Clamping the GOAL rather than the step
      # keeps the whole navigation stack intact -- cover-aware routing, mate
      # spacing, everything -- and simply refuses to aim it deeper than the
      # line. Roles already behind the line are unaffected, so this costs
      # the defence nothing. Exempt while carrying (the carrier runs the
      # other way anyway) and while our own flag is out, since recovering it
      # means chasing a thief heading exactly where this would forbid us to
      # go. Reads the SCOREBOARD, which is ungated: our kill total is their
      # death count.
      let
        foeSide = (if bot.team == Red: Blue else: Red)
        holdNow = bot.kills[bot.team] < HoldLineKills or
          bot.kills[bot.team] <= bot.kills[foeSide]
      if bot.killsInit and not iCarry and not ownStolen and holdNow:
        let depth = -homeSign(bot.team) * (target.x - float(CenterX))
        if depth > HoldLineDepth:
          target.x = float(CenterX) - homeSign(bot.team) * HoldLineDepth
      # Navigate: cover-aware path steering plus soft repulsion from nearby
      # teammates so one burst (or our own shot) cannot hit two of us.
      var steer = norm(bot.navSteer(client, me, target))
      for t in bot.mates:
        if bot.tick - t.lastSeen > 12:
          continue
        let d = dist(t.pos, me)
        if d < MateSpacing and d > 0.5:
          steer = steer + norm(me - t.pos) * ((MateSpacing - d) / MateSpacing) * 0.9
      # Serpentine when a straight run would cross watched ground. Fog cuts
      # both ways: a fresh remembered enemy with a clear pixel line pins
      # anyone, and rushers crossing the contested MIDDLE weave even without
      # intel — the snipers watching their lane are exactly the enemies they
      # cannot see. Close threats are the jink/duck branches' job; carriers
      # and the pocket grab skip it — for them speed beats evasion.
      if not iCarry and not pocketRush:
        var weave = false
        if rushing:
          weave = abs(me.x - float(CenterX)) < WeaveBand
        else:
          for t in bot.enemies:
            if bot.tick - t.lastSeen > UnderFireTrackTtl:
              continue
            let d = dist(t.pos, me)
            if d >= SerpentineNear and d <= SerpentineFar and
                client.pixelRayClear(me, t.pos):
              weave = true
              break
        if weave:
          var side = vec(-steer.y, steer.x)
          if (bot.tick div 8 + bot.slot div 2) mod 2 == 0:
            side = side * -1.0
          steer = norm(steer) + side * 0.6
      steer = steer + vec(rand(-0.12 .. 0.12), rand(-0.12 .. 0.12))
      moveMask = octantBits(steer)
      if bot.tick < bot.jinkUntil:
        moveMask = bot.jinkBits            # unsticking burst
      if desiredAim < 0:
        # No target demands the turret: the aim leads the movement direction
        # so the vision cone watches down-lane where we are heading. Movement
        # no longer leaks our vision, so this is a choice, not a side effect.
        desiredAim = bradsOf(steer)
        deadband = CruiseDeadband
        # Something we heard or remember beats watching our own feet -- but
        # only while it is roughly ahead. The cone rides the aim, so laying
        # the gun behind us to cover a noise would walk the rest of us
        # blindly into whatever is in front, and trade a fight we might win
        # for one we never see coming.
        let pa = bot.preAimBearing(me, norm(steer), maxEngage)
        if pa >= 0 and abs(bradsErr(pa, desiredAim)) <= PreAimArc:
          desiredAim = pa
          deadband = CombatDeadband     # laid on a real expectation now

  # Stuck detection: if we have not moved for a second (and are not holding
  # behind cover on purpose), burst in a random direction and force a repath.
  if dist(me, bot.lastPos) < 0.8:
    inc bot.stuckTicks
  else:
    bot.stuckTicks = 0
  bot.lastPos = me
  if holdStill:
    bot.stuckTicks = 0
  # A held target vetoes the burst: while a fight is on, staying put is the
  # point.
  if bot.stuckTicks > 20 and engage < 0:
    bot.stuckTicks = 0
    bot.jinkUntil = bot.tick + 10
    bot.jinkBits = octantBits(vec(rand(-1.0 .. 1.0), rand(-1.0 .. 1.0)))
    bot.navGoal = -1
    if bot.jinkBits == 0:
      bot.jinkBits = ButtonUp
    moveMask = bot.jinkBits

  if nadeDanger:
    # Sprint straight out of the marked blast zone; drop any hold/duck.
    let away = me - nadeDangerFrom
    moveMask = octantBits(
      if len(away) < 1.0: vec(homeSign(bot.team), 0.3) else: away
    )
    holdStill = false

  if moveMask == 0 and not holdStill:
    moveMask = octantBits(vec(rand(-1.0 .. 1.0), rand(-1.0 .. 1.0)))

  if desiredAim >= 0 and engage < 0 and bot.nadeCharge == 0 and not iCarry:
    # Not while carrying. The run home is the whole point of the match and it
    # is a race, so a carrier owes its attention to the route, not to whoever
    # is behind it: the cone rides the aim, and a carrier staring back at a
    # chaser is a carrier not seeing what it is running into. Being shot in
    # the back on the way to a capture still beats never arriving.
    #
    # Never present our back to someone we know is there. Losing sight of an
    # enemy is not the same as being rid of one: step behind a corner and the
    # sighting goes stale while the body stays exactly where it was, so the
    # old behaviour was to forget a live threat and walk on facing away from
    # it. Pick the nearest enemy still close enough and recent enough to be
    # real, and only one that could actually reach us or be reached.
    #
    # Then CLAMP rather than snap. Turning fully onto the threat would throw
    # away whatever the aim was doing, and the cone rides the aim, so this
    # keeps as much of the intended heading as it can while refusing to let
    # the threat sit behind us.
    var
      guard = -1
      guardD = BackGuardRange
    for i in 0 ..< bot.enemies.len:
      let t = bot.enemies[i]
      let age = bot.tick - t.lastSeen
      if age > BackGuardTtl:
        continue
      let d = dist(t.pos, me)
      if d < guardD and
          bot.couldTrade(me, vec(0.0, 0.0), t.pos, t.vel, float(age), maxEngage):
        guardD = d
        guard = i
    if guard >= 0:
      let
        threatAim = bradsOf(bot.enemies[guard].pos - me)
        e = bradsErr(threatAim, desiredAim)
      if e > BackGuardArc:
        desiredAim = floorMod(threatAim - BackGuardArc, AimBrads)
      elif e < -BackGuardArc:
        desiredAim = floorMod(threatAim + BackGuardArc, AimBrads)

  # Rotate toward the desired aim by the shortest arc; inside the deadband
  # (AimRate cannot settle tighter than +-AimRate/2) hold the turret still.
  var rotBits: uint8 = 0
  if desiredAim >= 0:
    let err = bradsErr(desiredAim, bot.estAim)
    if err > deadband:
      rotBits = ButtonB
    elif err < -deadband:
      rotBits = ButtonSelect

  # Only a FRESH A press fires, and the pull locks the aim angle on the same
  # tick — never rotate on the pull tick so the lock takes the settled aim.
  var mask = moveMask or rotBits
  if wantFire and not bot.firedLast:
    mask = moveMask or ButtonA
  if nadeC:
    mask = mask or ButtonC
  bot.firedLast = (mask and ButtonA) != 0
  bot.rotSign =
    if (mask and ButtonB) != 0: 1
    elif (mask and ButtonSelect) != 0: -1
    else: 0
  mask

proc runBot(url: string) =
  ## Connects, then loops frames forever, reconnecting on disconnect.
  let
    slot = slotFromUrl(url)
    team = (if slot mod 2 == 0: Team.Red else: Team.Blue)
    role = roleForSeat(clamp(slot div 2, 0, 7), team)
    endpoint = ensureWsPath(url, WebSocketPath)
  randomize(slot * 7919 + 1)
  let bot = Bot(slot: slot, team: team, role: role)
  bot.resetTransient()
  echo "baseline slot=", slot, " team=", team, " role=", role, " -> ", endpoint
  let client = initProtocolClient()
  var everConnected = false
  while true:
    try:
      let ws = newWebSocket(endpoint)
      echo "connected ", endpoint
      everConnected = true
      client.reset()
      bot.navBuilt = false
      bot.resetTransient()
      var lastMask = 0xff'u8
      while true:
        if not client.receiveLatestFrame(ws):
          continue
        let advance = max(1, client.frameAdvance)
        bot.tick += advance
        # Dead-reckon the aim: the last sent mask keeps rotating on the
        # server for every elapsed sim tick until we change it.
        bot.estAim = floorMod(
          bot.estAim + bot.rotSign * AimRate * advance, AimBrads)
        if not client.mapCameraReady:
          bot.resetTransient()             # lobby / game-over interstitial
          continue
        if not bot.navBuilt and client.walkabilityReady:
          bot.buildNavGrid(client)
        let mask = bot.decide(client)
        if mask != lastMask:
          ws.send(inputBlob(mask), BinaryMessage)
          lastMask = mask
    except Exception as e:
      if everConnected:
        # The game ended and the server went away: exit so the episode
        # runner sees a clean player shutdown.
        echo "game over, exiting: ", e.msg
        quit(0)
      echo "connect retry: ", e.msg
      sleep(250)

when isMainModule:
  let url = getEnv("COWORLD_PLAYER_WS_URL", getEnv("COGAMES_ENGINE_WS_URL"))
  if url.len == 0:
    raise newException(ValueError, "COWORLD_PLAYER_WS_URL is required.")
  runBot(url)
