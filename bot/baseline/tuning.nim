## Tuned constants for the baseline policy: the ranges, budgets, timers and
## costs every decision is measured against. The comments are the point — each
## number records a measured experiment or a failure it was chosen to avoid.
## The map dimensions at the bottom are NOT constants: they are adopted off the
## wire at nav-grid build from the walkability sprite, and everything
## position-shaped elsewhere derives from them.

const
  WebSocketPath* = "/player"

  # All-in on the clock: past this tick a draw is the default outcome, so
  # commit to the capture. The game hard-stops at tick 5000 and a time-limit
  # draw scores exactly as badly as a loss, so a trigger past that tick can
  # never fire at all and the posts are held into a guaranteed -1.
  LatePushTick* = 3400
                              # Object coordinates and sprite sizes arrive
                              # multiplied by this; sprites stay centered on
                              # the same map points, so dividing the object
                              # center recovers exact legacy map coordinates.
  PlayerHalf* = 6              # solid footprint half-extent, matches the sim
  NavCell* = 8                 # nav grid cell size in px
  RepathTicks* = 10            # refresh the cost field at least this often
  LookaheadCells* = 6          # how far ahead on the path we aim the waypoint

  CarrierFireRange* = 110.0    # while carrying, only shoot enemies this close
  RushEngageRange* = 230.0     # racing for the steal: only fight what blocks it
  EscortEngageRange* = 320.0   # escorting a run: only fight near threats
  PocketRushRange* = 210.0     # this close to the enemy pedestal, just GRAB
  ThreatRange* = 200.0         # react to a visible enemy this close facing us
  DuckRange* = 340.0           # duck from remembered threats this close on cooldown
  MateSpacing* = 40.0          # soft repulsion radius between teammates
  CorridorHalfWidth* = 15.0    # friendly-fire corridor half width along the ray
  LeadTicks* = 6.0             # aim this many ticks ahead of a moving enemy:
                              # the 5-tick windup releases the bullet late
  TrackMatchDist* = 40.0       # a sighting matches a track within this distance
  TrackCap* = 8                # eight real opponents / teammates per side

  # The overhead identity badge. Its object id is a fixed base plus the
  # player's own index, so the id alone names WHICH player wears it and never
  # renames them for the length of the match. The disc is centred on the body,
  # so a tight radius pins each badge to the soldier under it.
  BadgeObjectBase* = 19040
  BadgeObjectSpan* = 32        # badges live in this many consecutive ids
  BadgeAnchorSlack* = 4.0      # px between a badge centre and its body centre

  # Shot landings are audible map-wide: the server sends every living viewer
  # a ring near where each shot hit, through walls and fog alike, and the ring
  # says nothing about which team fired. The position is deliberately fuzzed
  # by up to SonarJitterPx px, so a ring locates a neighbourhood, not a body.
  SonarObjectBase* = 19120
  SonarObjectSpan* = 16        # 19120..19135, one per recent shot
  SonarJitterPx* = 20          # px of deliberate fuzz on every heard landing
  SonarCalMin* = -700          # how far back the server clock might sit from
  SonarCalMax* = 200           # ours; wide on purpose until it is measured
  SonarCalRings* = 90          # heard landings to spend pinning that offset
  SonarCalMinRings* = 30       # landings to hear before trusting a winner
  SonarSeenTtl* = 40           # forget a spot well after its ring stops drawing
  SonarTtl* = 90               # forget a landing after ~4s
  SonarCap* = 24               # plenty: the server sends at most 16 at once
  SonarHotTtl* = 20            # only a landing this fresh can be tied to a death
  SonarHotRadius* = 90.0       # how near a heard landing still counts as danger
  SonarExactRadius* = 34.0     # the same, once the landing is pinned to a spot

  # Pre-aim: the turret traverses slowly, so the swing has to be paid for
  # before contact or it gets paid during it. Everything the sonar and the
  # tracks know is scored as an effective distance -- nearest wins -- with
  # weaker evidence pushed further away rather than excluded outright.
  PreAimRange* = 320.0         # ignore evidence further off than this
  PreAimTrackTtl* = 90         # a remembered enemy this fresh still points
  PreAimPingTtl* = 60          # a heard landing this fresh still points
  PreAimAgePx* = 1.2           # px of doubt added per tick of staleness
  PreAimPingCost* = 120.0      # a landing is weaker evidence than a sighting
  PreAimHotBonus* = 90.0       # unless a kill landed with it
  PreAimExactBonus* = 45.0     # and more so when it is pinned to one spot
  PreAimArc* = 20              # while moving, never look further off-lane than
                              # this. The cone rides the aim, so a wide licence
                              # here buys a faster swing onto one threat by
                              # going blind to the ground we are walking onto,
                              # which is a bad trade at any angle worth naming
  PreAimWatchRange* = 200.0    # a keeper only leaves its sweep for something
                              # this close, and only while it is fresh
  PreAimWatchTtl* = 30         # ticks: past this the sweep is the better bet

  # An enemy that steps behind a corner has not stopped existing. Hold the
  # sighting long enough to cover the wait, and keep facing it: every gate
  # that decides whether to SHOOT already tests freshness for itself, so a
  # held sighting can never turn into a shot at a place nobody is standing.
  TrackHoldTtl* = 400          # keep a lost enemy in mind roughly this long
  FeasHorizon* = 60            # ticks ahead we ask whether a shot could happen
  FeasSteps* = 3               # sample points along that stretch
  OwnEstSpeed* = 1.0           # px/tick we make good while walking
  BackGuardRange* = 260.0      # a live enemy nearer than this stays covered
  BackGuardArc* = 96           # never let the aim sit further off it than this
  BackGuardTtl* = 200          # a sighting this old still counts as known
  FreshShotTicks* = 24         # only fire at tracks seen this recently; the
                              # turret needs traverse time, so chases keep
                              # shooting a bit after the target fogs out
  ThiefFixTtl* = 40            # a thief position fix guides the chase this long

  AimBrads* = 256              # aim angle units per full turn
  AimRate* = 5                 # brads/tick a held rotate button turns the aim
                              # (matches the server's aimTurnRate default)
  SelfSpriteBase* = 5100       # first id of the pre-rotated self-soldier pool;
                              # the pool is laid out skin-major, so the
                              # rotation step is the id modulo SoldierRots
  SoldierRots* = 16            # pre-rendered aim steps the soldier art ships in
  SoldierRotBrads* = AimBrads div SoldierRots
                              # brads per rotation step: the width of the aim
                              # bucket one rendered sprite stands for
  SoldierRotHalf* = SoldierRotBrads div 2
                              # half a bucket: the server rounds the aim to the
                              # nearest step, so the true aim is within this of
                              # the step's centre
  MaxHp* = 3                   # hitPoints per life (config default); pip labels
                              # read "hp <n>/<MaxHp>"
  HpPipOffsetY* = 22.0         # the overhead hp bar is centered exactly this
                              # far ABOVE its player's center — the bar sits
                              # at the body's top edge minus the overhead gap
                              # and its own height
  HpPipAnchorSlack* = 3.0      # px of slop allowed against that exact anchor.
                              # The bar lands within a hundredth of a pixel of
                              # it, and bodies can stand closer than a body
                              # width apart, so keep this far below that gap:
                              # a loose window lets stacked players swap health
                              # readings, and the pip label carries no colour
                              # to catch it when they are on opposite teams
  ArcThreatBonus* = 70.0       # px of credit for holding the plasma arc
  ShieldCostPenalty* = 45.0    # px of debit for the extra shot a shield eats
  HpFocusBonus* = 60.0         # px of effective-distance credit per missing
                              # enemy hit point — a tiebreak between
                              # comparably-engageable targets, never a reason
                              # to swing the turret across the map
  ThiefFocusBonus* = 400.0     # px of credit for the enemy RUNNING OUR FLAG:
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
  TraversePxPerBrad* = 1.6     # px of effective distance per brad of turret
                              # swing needed to lay on the target: err/AimRate
                              # ticks of traverse at ~8px of enemy closing
                              # motion per tick = 8/5 px per brad
  NadeMaxRange* = 240.0        # full-charge throw distance (~fifth of the field)
  NadeMinRange* = 72.0         # never lob inside this — the 52px blast + drift
                              # would clip us (GV17: blast 40 -> 52)
  NadeBlast* = 52.0            # blast radius; a pair this close dies together
  NadeFullChargeTicks* = 24    # ~1s of holding C reaches max range
  NadeMemTtl* = 150            # bomb a sighting this old even if out of sight
  NadeFoePingTtl* = 45         # bomb a spot they lost someone on, this recently
  NadeHeldCost* = 60.0         # px of doubt for a target we cannot currently see
  NadeFoePingCost* = 150.0     # px of doubt for a spot, rather than a body
  HoldLineKills* = 4           # enemy deaths before the wave commits forward.
                              # Was 6 (two players' worth of lives out of 24)
                              # and never swept. 4 measures +0.034 K/D against
                              # 6, 95% CI [+0.001, +0.067] over 398 episodes
                              # in five separately-bought samples whose point
                              # estimates ran +0.028 to +0.040 -- and level
                              # with the shipped champion on an independent
                              # 80-episode gate. Small, and the interval only
                              # just excludes zero after three looks, so treat
                              # the SIZE as soft; the sign replicated four
                              # times. See research/LEDGER.md.
  HoldLineDepth* = 80.0        # px past the centre line we allow while holding
  NadeMateTtl* = 150           # mates seen this recently veto a landing
  NadeMateDrift* = 0.45        # px a mate could have wandered per tick unseen
  NadeTapRange* = 30.0         # an uncharged tap lands this close; the throw
                              # distance runs from here to NadeMaxRange in
                              # equal steps over NadeFullChargeTicks
  OwnNadeRingSlack* = 28.0     # a throw-target ring within this of our OWN
                              # predicted landing point is our own preview
  NadePickupDetour* = 90.0     # grab a corner pickup within this detour range
  MedKitDetour* = 80.0         # heal-detour budget when merely wounded
  MedKitCriticalReach* = 180.0 # at 1 hp a heal outranks the current errand
  MedKitRespawn* = 30 * 24     # a taken kit refills after 30s (sim constant)
  MedKitSeenClear* = 55.0      # inside this range an empty spot is truly
                              # empty (bubble vision), not just fogged
  PlasmaReach* = 136.0         # plasma cone reach: 4 squares (sim
                              # PlasmaArcReach)
  PlasmaHalfBrads* = 10        # cone half-angle in brads: the cone is 2
                              # squares wide at max reach, atan(1/4) ~ 14
                              # degrees (sim PlasmaArcMaxWidth / Reach)
  PlasmaDetour* = 70.0         # attacker detour budget for a plasma arc pickup
  ShieldStealDetour* = 480.0   # MidGuard's shield trip: the enemy endzone
                              # shield sits low in their back column
                              # (~215px from the pedestal since the game-v7
                              # split), so the round trip costs ~430 path px
  PickupRespawn* = 30 * 24     # plasma arc/shield respawn timer (sim constant)
  NadeRespawn* = 5 * 24        # a taken corner grenade refills after 5s
  NadeSpawnInset* = 50.0       # px in from each map corner the spawn sits
  NadeFarmReach* = 420.0       # how far a flanker will go out of its way to
                              # arm. Was 340, and the detour was underpriced:
                              # 420 measures +0.064 K/D, +25.1 points of win
                              # rate and +22 captures against 340 over 240
                              # episodes, all three intervals excluding zero
                              # ([+0.026, +0.100], [+0.130, +0.372], [+4, +40])
                              # and winning on BOTH sides of the mirror. The
                              # only result in this repository's record where
                              # captures have ever separated. It fits the
                              # supply: corner grenades refill every 5s, ~80 a
                              # match against ~7 of everything else, and the
                              # blast ignores walls, cover and teams alike.
                              # See research/LEDGER.md.
  MedKitCarrierBudget* = 90.0  # extra path px a hurt CARRIER spends to heal:
                              # a full-heal carrier survives pocket exits
                              # that kill a 1 hp one
  CarrySelfRadius* = 26.0      # the carried flag banner is centered on its
                              # carrier: anything inside this slack that no
                              # visible mate sits closer to is OUR carry
  CarrierEstSpeed* = 1.0       # px/tick a fogged mate-carrier is assumed to
                              # advance homeward (carrier moves at ~70% speed)
  CombatDeadband* = 2          # stop the traverse within this error (brads);
                              # AimRate 5 cannot settle tighter than +-2
  CruiseDeadband* = 8          # sloppier deadband for non-combat aim
  FireSlackPx* = 11.0          # fire when the aim error's perpendicular miss
                              # at the target's range is inside this (the
                              # corridor half-width is ~14px; keep margin)
  ScanArc* = 44                # scan sweeps this many brads each side of the
                              # watch heading (cone half-angle is 32 brads)
  PushOutTicks* = 360          # endgame push: no enemy seen for ~15s...
  PushOutMinGame* = 2400       # ...this deep into the game breaks the posts

  CoverShieldDist* = 42.0      # an obstacle this close blocks a threat direction
  PeekLineDist* = 150.0        # floor for an overwatch peek firing line; post
                              # scoring strongly prefers the longest line
  DuckSearchCells* = 3         # duck-cell search radius in nav cells
  PeekSearchCells* = 6         # peek-cell search radius in nav cells. Wide
                              # enough that backing away from the corner is
                              # actually among the options offered
  PeekStandoffCap* = 96.0      # px of stand-off from the corner worth paying for
  PeekStandoffWeight* = 0.9    # px of extra walking each px of it is worth
  ExposureRange* = 380.0       # enemy threat radius used for exposure costing
  ExposureThreats* = 3         # cost only the freshest few remembered threats
  ExposureTrackTtl* = 60       # only cost threats remembered this recently
  EnemyRespawnSamples* = 3     # points down the enemy endzone column standing
                              # in for GV25's uniform respawn draw; at
                              # ExposureRange these overlap into one frontage,
                              # and overlapping cells are skipped by the
                              # exposure pass, so the marginal cost is small
  UnderFireTrackTtl* = 16      # tracks this fresh can pin us on open ground
  SerpentineNear* = 100.0      # serpentine band: closer threats are jink/duck
  SerpentineFar* = 400.0       # ... and farther tracks cannot really aim at us
  StepCost* = 5'i32            # orthogonal move cost in the nav field
  DiagCost* = 7'i32            # ~sqrt(2) * StepCost
  ExposedCost* = 14'i32        # extra cost to enter a threat-exposed cell:
                              # under fog the exposure model (enemy sniper
                              # posts + fresh tracks) is the only warning of
                              # watched lanes, so routes respect it hard
  FlankDepth* = 260.0          # wide flankers cross this far past mid
  WeaveBand* = 280.0           # rushers serpentine within this x-band of mid

  LaneTop* = 40.0              # open corridor above the mirrored obstacles

## Map dimensions, adopted at nav-grid build from the walkability sprite
## (which spans the whole arena). The game supports multiple maps —
## "arena" (1235x659, the default) and "arena-large" (1606x858) — and this
## bot plays either; everything position-shaped below derives from these.
## Initialized to the default arena.
var
  MapW* = 1235
  MapH* = 659
  CenterX* = MapW div 2
  CenterY* = MapH div 2
  GridW* = (MapW + NavCell - 1) div NavCell
  GridH* = (MapH + NavCell - 1) div NavCell
  LaneMid* = float(CenterY)
  LaneBottom* = float(MapH) - LaneTop  # open corridor below the obstacles
  FireRange* = float(MapW) + 15.0
    # engage distance: every map's gun range is comfortably over its own
    # width (1300 on the 1235px arena, 1690 on the 1606px arena-large), so
    # a hair past a map-width is always inside it. 1250.0 on the default
    # arena — the value this bot always used.
