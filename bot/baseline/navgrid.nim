## The cost field the bot walks on, and the sidestep searches combat asks for.
##
## The pixel mask is eroded once into footprint-safe cells; every repath marks
## the ground known enemies can shoot into and runs a Dijkstra out from the
## goal that charges extra for crossing it. `navSteer` follows that field with
## waypoint lookahead; `findDuckCell` and `findPeekCell` search the same cells
## sideways for one that breaks a line or opens one.

import
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

proc buildNavGrid*(bot: Bot, client: ProtocolClient) =
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

const NavNeighbors* = [
  (1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)
]

proc rebuildExposure*(bot: Bot, client: ProtocolClient) =
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

proc computeField*(bot: Bot, client: ProtocolClient, goal: int) =
  ## Cost field (Dijkstra) over the nav grid toward one goal cell. Steps cost
  ## StepCost/DiagCost and entering a threat-exposed cell adds ExposedCost, so
  ## paths prefer segments that keep obstacles between us and known enemies.
  ## Diagonal steps require both orthogonal neighbors open (no corner cuts).
  ##
  ## The frontier is a cyclic bucket array, not a binary heap. Every step
  ## costs one of four small integers, so a relaxation from distance d always
  ## produces a key in (d, d + NavMaxStep] -- never below the level being
  ## drained and never a whole cycle above it. That makes a push an append and
  ## a pop a truncation, where the heap paid O(log n) of sifting for both, and
  ## the buckets live on the Bot so a repath allocates nothing at all. This
  ## field is rebuilt whenever the goal moves, which for a seat chasing
  ## anything is most ticks, so both of those are paid constantly.
  ##
  ## The frontier comes out in a different order than the heap gave; the field
  ## does not change. These are positive weights and a plain Dijkstra, so
  ## `navDist` settles on the one set of shortest distances however the
  ## frontier is drained -- the answer is a property of the grid, not of the
  ## queue.
  bot.rebuildExposure(client)
  for i in 0 ..< bot.navDist.len:
    bot.navDist[i] = -1
  for bucket in bot.navQueue.mitems:
    bucket.setLen(0)
  bot.navDist[goal] = 0
  bot.navQueue[0].add(int32(goal))
  var
    queued = 1
    level = 0'i32
  while queued > 0:
    while bot.navQueue[level.int mod NavBuckets].len > 0:
      let cur = int(bot.navQueue[level.int mod NavBuckets].pop())
      dec queued
      if bot.navDist[cur] != level:
        continue                         # a cheaper route already claimed it
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
        let nd = level + step
        if bot.navDist[nc] < 0 or nd < bot.navDist[nc]:
          bot.navDist[nc] = nd
          bot.navQueue[nd.int mod NavBuckets].add(int32(nc))
          inc queued
    inc level

proc navSteer*(bot: Bot, client: ProtocolClient, me, target: Vec): Vec =
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

proc findDuckCell*(bot: Bot, client: ProtocolClient, me, threat: Vec): int =
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

proc findPeekCell*(bot: Bot, client: ProtocolClient, me, aim: Vec): int =
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
