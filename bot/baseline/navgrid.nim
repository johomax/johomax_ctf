## The cost field the bot walks on, and the sidestep searches combat asks for.
##
## The pixel mask is eroded once into footprint-safe cells; every repath marks
## the ground known enemies can shoot into and runs a Dijkstra out from the
## goal that charges extra for crossing it. `navSteer` follows that field with
## waypoint lookahead; `findDuckCell` and `findPeekCell` search the same cells
## sideways for one that breaks a line or opens one.

import
  bitworld/profile,
  protocols,
  posts,
  grid,
  world,
  geometry,
  tuning

proc adoptMapSize*(client: ProtocolClient) =
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

const NavNeighbors* = [
  (1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)
]

proc markExposedFrom(
  bot: Bot,
  client: ProtocolClient,
  field: var seq[bool],
  spot: Vec
) =
  ## Marks every walkable cell within ExposureRange of one threat spot that
  ## the spot has a coarsely-clear line to.
  let
    x0 = max(0, int(spot.x - ExposureRange) div NavCell)
    x1 = min(GridW - 1, int(spot.x + ExposureRange) div NavCell)
    y0 = max(0, int(spot.y - ExposureRange) div NavCell)
    y1 = min(GridH - 1, int(spot.y + ExposureRange) div NavCell)
  let gw = GridW                         # a local stays in a register; the
                                         # module var reloads after every store
  for cy in y0 .. y1:
    let py = float(cy * NavCell + NavCell div 2)
    for cx in x0 .. x1:
      let c = cy * gw + cx
      if field[c] or not bot.cellWalkable[c]:
        continue
      # cellCenter(c) spelled from the loop counters, saving its div/mod
      let p = vec(float(cx * NavCell + NavCell div 2), py)
      let l = dist(p, spot)                  # the ray's length as well
      if l <= ExposureRange and
          rayClearCoarseLen(client, spot, p, 8.0, l):
        field[c] = true

var staticExpMemo: MapMemo[(seq[Vec], seq[Vec]), seq[bool]]
  ## Same story as `posts.nim`'s post memo: the static exposure field is a
  ## pure function of the map and the two threat-spot lists, and an episode
  ## has one list pair per team, not one per seat.

proc computeStaticExposure(bot: Bot, client: ProtocolClient): seq[bool] =
  ## The field itself, for `buildStaticExposure` to memoize.
  result = newSeq[bool](GridW * GridH)
  for spot in bot.enemyPosts:
    bot.markExposedFrom(client, result, spot)
  for spot in bot.enemyRespawnSpots:
    bot.markExposedFrom(client, result, spot)

proc buildStaticExposure*(bot: Bot, client: ProtocolClient) {.measure.} =
  ## The exposure of the threats that never move: the mirrored enemy sniper
  ## post, and the enemy respawn ground.
  ##
  ## These were four of `rebuildExposure`'s seven threat spots, recomputed
  ## from scratch on every repath — which for a seat chasing anything is most
  ## ticks — and they were the four that did the MOST work, because they ran
  ## first against an empty field with nothing already marked to skip. They
  ## are fixed for the whole match, so they belong here, next to the nav grid
  ## they are derived from.
  ##
  ## Exposure is a union over spots: a cell is exposed if ANY threat can see
  ## it. So splitting the union does not change it — the `already marked`
  ## test is a shortcut, never part of the answer.
  bot.exposureStatic = staticExpMemo.mapMemoized(client,
    (bot.enemyPosts, bot.enemyRespawnSpots),
    bot.computeStaticExposure(client))

var gridMemo: MapMemo[int, (seq[bool], seq[bool])]
  ## The two grids every seat derives from the same walkability mask. Keyed
  ## on nothing but the map itself, so the key is a constant.

proc erodeWalkableAndCover(client: ProtocolClient): (seq[bool], seq[bool]) =
  ## Erodes the pixel mask into footprint-safe cells, then marks the ones
  ## hugging an obstacle. Split out so `buildNavGrid` can memoize it without
  ## pushing the file's deepest loop a level further in.
  var
    walkable = newSeq[bool](GridW * GridH)
    cover = newSeq[bool](GridW * GridH)
  for cy in 0 ..< GridH:
    for cx in 0 ..< GridW:
      walkable[cy * GridW + cx] = client.footprintFits(
        cx * NavCell + NavCell div 2, cy * NavCell + NavCell div 2)
  for cy in 0 ..< GridH:
    for cx in 0 ..< GridW:
      let c = cy * GridW + cx
      if not walkable[c]:
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
            if not walkable[ny * GridW + nx]:
              cover[c] = true
              break adjacency
  (walkable, cover)

proc buildNavGrid*(bot: Bot, client: ProtocolClient) {.measure.} =
  ## Erodes the pixel walkability mask into a footprint-safe nav grid, then
  ## derives the cover model (cover cells, overwatch post, defender choke).
  adoptMapSize(client)
  (bot.cellWalkable, bot.coverCell) =
    gridMemo.mapMemoized(client, 0, erodeWalkableAndCover(client))
  bot.exposure = newSeq[bool](GridW * GridH)
  bot.navDist = newSeq[int32](GridW * GridH)
  bot.navGoal = -1
  bot.expValid = false
  bot.fieldValid = false
  bot.pickPost(client)
  bot.findEnemyPosts(client)
  bot.buildStaticExposure(client)       # needs the enemy posts above
  bot.chokeHold = bot.snapToCover(chokeSpot(bot.team))
  bot.navBuilt = true

proc rebuildExposure*(bot: Bot, client: ProtocolClient): bool {.measure.} =
  ## Marks nav cells the freshest remembered enemies — plus the mirrored
  ## enemy sniper posts, which are stationary hidden threats all game —
  ## could shoot into (inside gun range with a coarsely-clear line). Used as
  ## a soft path cost.
  ##
  ## Returns whether exposure[] changed. The field is a pure function of the
  ## threat spots consumed below (the static part is fixed for the match, and
  ## nothing else writes exposure[]), and an unseen track keeps a bitwise-
  ## identical position between sightings — so a repath with the same spot
  ## list would recompute the exact bytes already there, and skips instead.
  var spots: seq[ExpSpot]
  var threats = 0
  for t in bot.enemies:                  # already sorted freshest-first
    if threats >= ExposureThreats or bot.tick - t.lastSeen > ExposureTrackTtl:
      break
    inc threats
    spots.add(ExpSpot(pos: t.pos, r: ExposureRange, los: true))
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
    spots.add(ExpSpot(
      pos: s.pos,
      r: (if s.exact: SonarExactRadius else: SonarHotRadius),
      los: false))
  if bot.expValid and spots == bot.expSpots:
    return false
  for i in 0 ..< bot.exposure.len:
    bot.exposure[i] = bot.exposureStatic[i]   # the standing threats, precomputed
  for spot in spots:
    if spot.los:
      bot.markExposedFrom(client, bot.exposure, spot.pos)
      continue
    let
      r = spot.r
      x0 = max(0, int(spot.pos.x - r) div NavCell)
      x1 = min(GridW - 1, int(spot.pos.x + r) div NavCell)
      y0 = max(0, int(spot.pos.y - r) div NavCell)
      y1 = min(GridH - 1, int(spot.pos.y + r) div NavCell)
    # Same two shapes as markExposedFrom above, for the same two reasons: a
    # local for GridW stays in a register where the module var reloads after
    # every array store, and cellCenter spelled from the loop counters saves
    # the div and mod it would do to recover them.
    let gw = GridW
    for cy in y0 .. y1:
      let py = float(cy * NavCell + NavCell div 2)
      for cx in x0 .. x1:
        let c = cy * gw + cx
        if bot.exposure[c] or not bot.cellWalkable[c]:
          continue
        let p = vec(float(cx * NavCell + NavCell div 2), py)
        if dist(p, spot.pos) <= r:
          bot.exposure[c] = true
  bot.expSpots = spots
  bot.expValid = true
  true

proc driveField(bot: Bot, horizon: int) {.measure.} =
  ## Drains the cost field's frontier until `horizon` is settled, or until it
  ## runs dry. Steps cost StepCost/DiagCost and entering a threat-exposed cell
  ## adds ExposedCost, so paths prefer segments that keep obstacles between us
  ## and known enemies. Diagonal steps require both orthogonal neighbors open
  ## (no corner cuts).
  ##
  ## The frontier is a cyclic bucket array, not a binary heap. Every step
  ## costs one of four small integers, so a relaxation from distance d always
  ## produces a key in (d, d + NavMaxStep] -- never below the level being
  ## drained and never a whole cycle above it. That makes a push an append and
  ## a pop a truncation, where the heap paid O(log n) of sifting for both, and
  ## the buckets live on the Bot so a repath allocates nothing at all.
  ##
  ## **It stops at the seat instead of at the map edge.** Dijkstra settles
  ## cells in ascending distance, so the moment `horizon` comes off the
  ## frontier every cell nearer than it already holds its FINAL value -- and
  ## those are the only cells anybody reads. `navSteer` descends strictly
  ## downhill from the seat's own cell, and its neighbour test skips any cell
  ## whose stored value is >= the one it is descending from; a stored value is
  ## never BELOW the final one, so a cell that is still tentative is a cell
  ## the descent would have skipped anyway. Same route, over the ground
  ## between the seat and its goal, where the old loop settled all ~12.9k
  ## cells to answer a question about that ground.
  ##
  ## What is left behind is a PAUSED Dijkstra, not a truncated one: the
  ## horizon cell's own neighbours are relaxed before the return, and the
  ## buckets, the level and the queue count live on the Bot -- so a later tick
  ## whose seat has walked past the horizon resumes from here rather than
  ## starting the field again.
  ##
  ## The frontier comes out in a different order than the heap gave; the field
  ## does not change. These are positive weights and a plain Dijkstra, so
  ## `navDist` settles on the one set of shortest distances however the
  ## frontier is drained -- the answer is a property of the grid, not of the
  ## queue.
  let
    gw = GridW                           # locals stay in registers; the module
    gh = GridH                           # vars reload after every array store
  var
    queued = bot.navQueued
    level = bot.navLevel
  while queued > 0:
    let bucket = level.int mod NavBuckets
    while bot.navQueue[bucket].len > 0:
      let cur = int(bot.navQueue[bucket].pop())
      dec queued
      if bot.navDist[cur] != level:
        continue                         # a cheaper route already claimed it
      let
        cx = cur mod gw
        cy = cur div gw
        # all eight neighbors of an interior cell are in-grid, so only the
        # border cells pay the per-neighbor range test
        interior = cx >= 1 and cy >= 1 and cx <= gw - 2 and cy <= gh - 2
      for (dx, dy) in NavNeighbors:
        if not interior:
          let
            nx = cx + dx
            ny = cy + dy
          if nx < 0 or ny < 0 or nx >= gw or ny >= gh:
            continue
        # nc = (cy+dy)*gw + (cx+dx) = cur + dy*gw + dx, and the two corner
        # cells likewise; spelling them as offsets drops the multiplies
        let nc = cur + dy * gw + dx
        if not bot.cellWalkable[nc]:
          continue
        if dx != 0 and dy != 0 and
            not (bot.cellWalkable[cur + dx] and
                 bot.cellWalkable[cur + dy * gw]):
          continue
        var step = (if dx != 0 and dy != 0: DiagCost else: StepCost)
        if bot.exposure[nc]:
          step += ExposedCost
        # The whole bucket scheme rests on this and nothing else checks it. A
        # step dearer than NavMaxStep lands in a bucket this level has already
        # drained, and the cost field comes out quietly wrong -- no crash, no
        # divergence at the point of the mistake, just worse routes. A new
        # surcharge here has to widen NavMaxStep with it. Live in the default
        # build and under selfcheck; compiled out by -d:danger.
        assert step <= NavMaxStep,
          "a nav step dearer than NavMaxStep needs NavBuckets widened to match"
        let nd = level + step
        if bot.navDist[nc] < 0 or nd < bot.navDist[nc]:
          bot.navDist[nc] = nd
          bot.navQueue[nd.int mod NavBuckets].add(int32(nc))
          inc queued
      if cur == horizon:
        bot.navQueued = queued
        bot.navLevel = level
        bot.fieldHorizon = level
        return
    inc level
  bot.navQueued = 0
  bot.navLevel = level
  bot.fieldHorizon = high(int32)         # drained: every reachable cell final

proc seedField(bot: Bot, goal: int) =
  ## An empty frontier holding only `goal`. Split out of `computeField` so the
  ## audit below can start a second field over the SAME exposure.
  for i in 0 ..< bot.navDist.len:
    bot.navDist[i] = -1
  for bucket in bot.navQueue.mitems:
    bucket.setLen(0)
  bot.navDist[goal] = 0
  bot.navQueue[0].add(int32(goal))
  bot.navQueued = 1
  bot.navLevel = 0
  bot.fieldHorizon = -1                  # nothing off the frontier yet
  bot.fieldGoal = goal
  bot.fieldValid = true

when defined(navFieldAudit):
  proc auditFieldHorizon(bot: Bot) =
    ## `-d:navFieldAudit`: check the pause invariant DIRECTLY, on every drain.
    ##
    ## Six identical `gameHash`es say the routes did not change, which is
    ## strong but indirect — it is the consequence of the invariant, not the
    ## invariant. This requires every cell the pause called settled to hold
    ## the distance a Dijkstra run FROM SCRATCH over the same exposure gives
    ## it.
    ##
    ## From scratch, not "drain the rest of this frontier": resuming what is
    ## already there compares a frontier against itself, so a pause that
    ## damaged the frontier — one that returned before relaxing the horizon
    ## cell, say — agrees with its own continuation and the check passes while
    ## testing nothing.
    ##
    ## And the audited field is PUT BACK afterwards, which matters for the
    ## same reason: a damaged frontier does its harm on later resumes, so an
    ## audit that left a freshly rebuilt field behind would repair the bug it
    ## is looking for on every drain and never see it. Both of these were
    ## found by perturbing driveField to pause before relaxing the horizon
    ## cell and watching the audit pass; it fails now.
    ##
    ## A pure observer, so an audit build must hash the same as a plain one —
    ## run both.
    let
      horizon = bot.fieldHorizon
      goal = bot.fieldGoal
      paused = bot.navDist
      queue = bot.navQueue
      queued = bot.navQueued
      level = bot.navLevel
    bot.seedField(goal)
    bot.driveField(-1)                   # no cell is -1, so this runs dry
    let truth = bot.navDist
    bot.navDist = paused
    bot.navQueue = queue
    bot.navQueued = queued
    bot.navLevel = level
    bot.fieldHorizon = horizon
    bot.fieldGoal = goal
    for i in 0 ..< paused.len:
      if paused[i] >= 0 and paused[i] <= horizon:
        doAssert truth[i] == paused[i],
          "cell " & $i & " was settled at " & $paused[i] &
          " but a field built from scratch says " & $truth[i]

proc reachField(bot: Bot, cell: int) =
  ## Extends the current field far enough to answer for `cell`. A no-op on the
  ## common tick, where the seat is still inside what the last repath drained:
  ## a stored value at or below the horizon is final, and anything past it, or
  ## unreached, is not.
  ##
  ## Resuming is only meaningful over a field somebody started, and what makes
  ## that true today is a coupling one file away: every `fieldValid = false`
  ## also sets `navGoal = -1`, which sends `navSteer` through `computeField`.
  ## Nothing else states that, and clearing the flag alone would leave this
  ## draining buckets belonging to a dead field — worse routes, no crash. So
  ## it is asserted here rather than assumed.
  assert bot.fieldValid, "reachField on a field nobody started"
  if bot.navDist[cell] >= 0 and bot.navDist[cell] <= bot.fieldHorizon:
    return
  bot.driveField(cell)
  when defined(navFieldAudit):
    bot.auditFieldHorizon()

proc computeField(bot: Bot, client: ProtocolClient, goal: int) {.measure.} =
  ## Starts a cost field toward one goal cell: nothing is settled yet, and
  ## `reachField` drains it as far as a reader needs. This field is restarted
  ## whenever the goal moves, which for a seat chasing anything is most ticks.
  ##
  ## Module-private, with `reachField` and `driveField`, because between the
  ## two calls `navDist` reads -1 for every cell the drain has not reached —
  ## which every consumer pattern in this policy would read as "unreachable"
  ## and answer with a beeline. `navSteer` below is the one reader, and it
  ## drains before it descends.
  if not bot.rebuildExposure(client) and bot.fieldValid and
      goal == bot.fieldGoal:
    return           # same goal over the same exposure: the field is already here
  bot.seedField(goal)

proc navSteer*(bot: Bot, client: ProtocolClient, me, target: Vec): Vec {.measure.} =
  ## Direction along the cost-field path toward `target`, with waypoint
  ## lookahead. Falls back to a beeline before the grid exists or when
  ## unreachable.
  if not bot.navBuilt:
    return target - me
  let
    goal = bot.nearestOpenCell(cellOf(target))
    start = bot.nearestOpenCell(cellOf(me))
  if goal != bot.navGoal or bot.tick - bot.navStamp >= RepathTicks:
    bot.computeField(client, goal)
    bot.navGoal = goal
    bot.navStamp = bot.tick
  # Separate from the repath rule above on purpose: extending the field costs
  # only frontier, where a repath also rebuilds exposure off the CURRENT
  # threat list. Repathing early because the seat outwalked the horizon would
  # be a different field, on a different tick, and no longer this policy.
  bot.reachField(start)
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
    let center = cellCenter(node)
    if bot.gridRayClear(me, center):
      waypoint = center
      haveClear = true
    else:
      break
  if not haveClear:
    waypoint = cellCenter(node)
  waypoint - me

proc findDuckCell*(bot: Bot, client: ProtocolClient, me, threat: Vec): int {.measure.} =
  ## The nearest directly-reachable cell around us whose center the threat
  ## cannot see; -1 when no nearby cover breaks the line.
  result = -1
  let c0 = cellOf(me)
  if not bot.cellWalkable[c0]:
    return          # gridRayClear from a closed cell fails at its first sample
  let
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
      # Score before the rays: a cell that cannot beat the best needs no rays,
      # and the rays are pure reads, so skipping them changes nothing.
      let d = dist(p, me)
      if d >= bestD:
        continue
      if not bot.gridRayClear(me, p):
        continue
      if client.pixelRayClear(p, threat):
        continue                          # the threat can still see this cell
      bestD = d
      result = nc

proc firstBlockPoint*(bot: Bot, a, b: Vec): Vec =
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

proc findPeekCell*(bot: Bot, client: ProtocolClient, me, aim: Vec): int {.measure.} =
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
  let c0 = cellOf(me)
  if not bot.cellWalkable[c0]:
    return          # gridRayClear from a closed cell fails at its first sample
  let
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
      if dist(p, aim) > FireRange:
        continue
      # Score before the rays: a cell that cannot beat the best needs no rays,
      # and the rays are pure reads, so skipping them changes nothing.
      let d = dist(p, me) -
        min(dist(p, corner), PeekStandoffCap) * PeekStandoffWeight
      if d >= bestD:
        continue
      if not bot.gridRayClear(me, p):
        continue
      if not client.pixelRayClear(p, aim):
        continue
      bestD = d
      result = nc
