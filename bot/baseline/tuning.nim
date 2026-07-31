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

  # The shout channel. The engine gives every player a 10-character message
  # audible to anyone within ShoutRange (MapWidth div 5, ~247px) THROUGH WALLS
  # AND FOG, at most one per second, and puts the speech bubble on the wire as
  # a `<color> shout <player>: <text>` sprite. All eight seats run one policy,
  # so the vocabulary can be private: this one says "an enemy is in cell
  # (gx, gy)" and nothing else. The heard position is jittered like a shot
  # ring, so the TEXT is the payload and the bubble's position is discarded.
  #
  # ShoutMode is the whole feature's gate, and the levels are cumulative --
  # each adds one consumer of a heard fix, in increasing order of how much of
  # the policy it can disturb:
  #   0  silent. Nothing is emitted, nothing is parsed, no shout ever exists,
  #      and the episode hash is byte-identical to the build before this
  #      landed. This is what the tree ships until an experiment says
  #      otherwise.
  #   1  emit + pre-aim. A heard fix is a third pre-aim source alongside the
  #      tracks and the sonar. The vision cone rides the aim, so pointing it
  #      at a mate's sighting is how a shout turns into our OWN sighting, and
  #      the aim can neither pull a trigger nor route a path -- the cheapest
  #      consumer there is.
  #   2  + grenades. A heard fix also becomes a lob target, like a foe ping.
  #   3  + peek. A heard fix also enters the enemy tracks as a PEEK candidate:
  #      it can pre-lay the aim through a wall and open a firing line, but it
  #      is never itself a fire target (the fix is a 32px cell, the fire gate
  #      is a 14px corridor, and a shot down the wrong corridor kills mates).
  ShoutMode* = 3
  ShoutCellPx* = 32            # px per grid cell in the vocabulary: 39x21
                              # cells on the arena, two digits each, which is
                              # what fits in ten characters with the tag
  ShoutHearFoe* = 1            # 1 = also take a fix off every HOSTILE bubble
                              # in earshot. Independent of the vocabulary: the
                              # bubble hangs on the speaker, so its anchor is
                              # an enemy standing within the same +-20px the
                              # engine fuzzes a shot ring by, delivered
                              # through walls and fog. NOT MEASURABLE IN A
                              # LOCAL MIRROR until the TREE emits: the other
                              # side of a local mirror is this same policy, so
                              # a silent tree means a silent enemy and this
                              # gate measures a level that means nothing
  ShoutFloatPx* = 13           # px the bubble's tail tip floats above the
                              # speaker's head (engine: ShoutFloat). The
                              # object is placed at (anchorX - w div 2,
                              # tailTipY - h), so the speaker is at
                              # (o.x + w div 2, o.y + h + this)
  ShoutEveryTicks* = 24        # our own emit gate. The engine drops a shout
                              # made inside ShoutCooldownTicks (= ReplayFps =
                              # 24) of the last one, so anything faster is
                              # packets we know the server will refuse
  ShoutTtl* = 96               # forget a heard fix after ~4s, like the sonar
  ShoutCap* = 8                # eight mates, one live bubble each
  ShoutMergeDist* = 40.0       # a fix this near one we already hold refreshes
                              # it instead of adding a second
  ShoutSeeDist* = 900.0        # only shout about an enemy we can see this far
  PreAimShoutCost* = 100.0     # a mate's fix is weaker evidence than our own
                              # sighting and stronger than a landing: it names
                              # a body rather than a bullet, but through
                              # another seat's eyes and a 32px cell
  PreAimShoutTtl* = 72         # a fix this fresh still points the turret

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
  PreAimWatchTtl* = 60         # ticks: past this the sweep is the better bet

  # How close is "arrived", for the three places the feet stop. These were
  # bare literals in act.nim and are named here so each is an axis rather
  # than a number nobody can sweep. The values are exactly what the tree read
  # before they were lifted, so lifting them changed nothing.
  DuckArriveDist* = 5.0        # stop stepping toward the duck cell. The cell
                              # was chosen because the THREAT'S RAY cannot
                              # reach its centre, and 5px short of a centre is
                              # a different pixel with a different ray
  PeekArriveDist* = 6.0        # ...and toward the peek cell, which was chosen
                              # because OUR ray does reach the target from it
  HoldArriveDist* = 10.0        # a watch keeper this near its post is standing
                              # it; a nav cell is 8px across, so this radius
                              # spills over the cell the post was scored in

  # Visibility flips at the 8px fog lattice and nowhere in between: the engine
  # keys a player's whole shadowcast on (originCell, aimBrads) and caches it
  # there (sim.nim refreshPlayerFov), so two bodies in one cell see exactly the
  # same map and one pixel across the boundary sees a different one. A watch
  # keeper therefore collects the one-way sightlines OneWayBonus paid for only
  # if it settles in the cell those sightlines were scored FOR -- and
  # HoldArriveDist is 6px against an 8px cell, so it does not have to.
  LatticeHoldSlack* = 6.0      # px of extra positioning a standing seat will
                              # spend to finish inside its post's own cell.
                              # At 0.0 the branch is compile-time dead

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
  # aim. The scan for "aim dot ..." has returned nothing ever since, so
  # mateAimBrads always answered -1 and the discount NEVER applied in any
  # build made from this archive. Same silent shape as the ButtonC
  # truncation: valid code, no error, feature simply absent. (That scan went
  # through `spriteObjectsWithLabel`, which no longer exists; a label the
  # engine does not emit is now unspellable — see labelkind.nim.)
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
  HoldLineDepth* = 160.0        # px past the centre line we allow while holding
  NadeMateTtl* = 150           # mates seen this recently veto a landing
  NadeMateDrift* = 0.45        # px a mate could have wandered per tick unseen
  NadeTapRange* = 30.0         # an uncharged tap lands this close; the throw
                              # distance runs from here to NadeMaxRange in
                              # equal steps over NadeFullChargeTicks
  OwnNadeRingSlack* = 28.0     # a throw-target ring within this of our OWN
                              # predicted landing point is our own preview
  NadePickupDetour* = 90.0     # grab a corner pickup within this detour range
  MedKitDetour* = 120.0         # heal-detour budget when merely wounded
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
  NadeFarmReach* = 500.0       # how far a flanker will go out of its way to
                              # arm. Was 340 and badly underpriced against a
                              # resource that refills every 5s (~80 grenades a
                              # match against ~7 of everything else) and that
                              # cover is worth nothing against. Walked up in
                              # two measured steps, each against the champion
                              # the previous one produced:
                              #   340 -> 420  +0.064 K/D [+0.026, +0.100],
                              #               +25.1 pts win rate, +22 captures
                              #               [+4, +40] -- the only result here
                              #               where captures ever separated
                              #   420 -> 500  +0.068 K/D [+0.035, +0.101],
                              #               +16.7 pts win rate [+0.046,
                              #               +0.287], captures -8 [-29, +13]
                              # Note the captures: +22 and separating at 420,
                              # gone at 500 while K/D and wins kept climbing.
                              # The capture benefit looks like it peaks below
                              # 500 and the fighting benefit does not, so the
                              # next step up is not obviously free. 580 was
                              # never measured. See research/LEDGER.md.
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
  ScanArcRed* = 28             # scan sweeps this many brads each side of the
  ScanArcBlue* = 28            # watch heading (cone half-angle is 32 brads).
                              # ONE literal per side, selected by world's
                              # scanArcFor(team): the sides are free to differ,
                              # and both read the shared 28 until an experiment
                              # moves exactly one of them
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
  ExposedCost* = 22'i32        # extra cost to enter a threat-exposed cell:
                              # under fog the exposure model (enemy sniper
                              # posts + fresh tracks) is the only warning of
                              # watched lanes, so routes respect it hard
  NavMaxStep* = DiagCost + ExposedCost
                              # the dearest single move there is: a diagonal
                              # onto exposed ground. Every step costs one of
                              # four small integers between StepCost and this
  NavBuckets* = int(NavMaxStep) + 1
                              # one cyclic bucket per distance the cost field's
                              # frontier can hold at once. A relaxation from
                              # distance d always lands in (d, d + NavMaxStep],
                              # so that many buckets can never collide — which
                              # is what lets computeField use them instead of a
                              # heap. Keep it one MORE than the dearest step
  FlankDepth* = 260.0          # wide flankers cross this far past mid
  WeaveBand* = 280.0           # rushers serpentine within this x-band of mid

  LaneTop* = 40.0              # open corridor above the mirrored obstacles
  CorpseClearRadius* = 40.0    # a foe-marked landing wipes the nearest track
                              # within this: that enemy is dead and respawning,
                              # and a kept track is a phantom to duck from

  OneWayBonusRed* = 40.0        # px of post-score credit per enemy-lane cell
  OneWayBonusBlue* = 40.0       # the peek can see that can NEVER see it back
                              # (the engine's quantized shadowcast is not
                              # reciprocal; see fov.nim) with a clear bullet
                              # ray. At 0.0 that side's term is off and
                              # scanPost never builds its one-way table at
                              # all. PER SIDE because the fog lattice does not
                              # mirror: the map mirrors as x' = MapW-1-x, 1235
                              # is not a multiple of NavCell, so a cell's
                              # mirror image straddles two cells and the sides
                              # hold different one-way tables -- 52 red
                              # candidates to 50 blue, 13 clear-ray pairs to
                              # 16. The two read the same number until an
                              # experiment moves one; analysis/role_bleed.md
                              # says blue's Overwatch is the seat to move

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
