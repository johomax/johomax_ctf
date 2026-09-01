## Battle-royale movement objectives. Flagless boards never enter the classic
## pedestal, lane or endzone strategy; this layer is driven only by the live
## zone, duo tracks, known loot and remembered enemies.

import
  protocols,
  labelkind,
  frame,
  perception,
  memory,
  grid,
  world,
  geometry,
  tuning

proc inset(rect: ZoneRect): tuple[x0, y0, x1, y1: int] =
  let
    mx = min(BrZoneMargin, max(0, (rect.x1 - rect.x0) div 3))
    my = min(BrZoneMargin, max(0, (rect.y1 - rect.y0) div 3))
  (rect.x0 + mx, rect.y0 + my, rect.x1 - mx, rect.y1 - my)

proc inside(rect: ZoneRect, p: Vec): bool =
  if not rect.valid:
    return true
  let r = rect.inset()
  p.x >= float(r.x0) and p.x <= float(r.x1) and
    p.y >= float(r.y0) and p.y <= float(r.y1)

proc clampInside(rect: ZoneRect, p: Vec): Vec =
  if not rect.valid:
    return p
  let r = rect.inset()
  vec(clamp(p.x, float(r.x0), float(r.x1)),
      clamp(p.y, float(r.y0), float(r.y1)))

proc centre(rect: ZoneRect): Vec =
  vec(float(rect.x0 + rect.x1) * 0.5, float(rect.y0 + rect.y1) * 0.5)

proc areaFraction(rect: ZoneRect): float =
  if not rect.valid or MapW <= 0 or MapH <= 0:
    return 1.0
  float(max(0, rect.x1 - rect.x0)) * float(max(0, rect.y1 - rect.y0)) /
    (float(MapW) * float(MapH))

proc duoPoint(rect: ZoneRect, role: Role): Vec =
  ## A phase-stable pair of angles. The offset comes only from the stated next
  ## rectangle and role, never from either cog's moving position.
  if not rect.valid:
    return vec(float(CenterX), float(CenterY))
  let r = rect.inset()
  result = vec(float(r.x0 + r.x1) * 0.5, float(r.y0 + r.y1) * 0.5)
  let sign = if role == RoyaleAnchor: -1.0 else: 1.0
  if r.x1 - r.x0 >= r.y1 - r.y0:
    result.x += sign * min(BrPartnerMin * 0.75, float(r.x1 - r.x0) * 0.25)
  else:
    result.y += sign * min(BrPartnerMin * 0.75, float(r.y1 - r.y0) * 0.25)
  result = rect.clampInside(result)

proc quantizedRouteBounds(rect: ZoneRect): tuple[x0, y0, x1, y1: int] =
  ## Move each boundary inward to a 32px line. The field changes only when the
  ## shrinking edge crosses that line, and every admitted cell remains inside
  ## the exact current rectangle. Tiny late zones retain their exact pixels.
  let
    x0 = clamp(rect.x0, 0, MapW - 1)
    y0 = clamp(rect.y0, 0, MapH - 1)
    x1 = clamp(rect.x1, 0, MapW - 1)
    y1 = clamp(rect.y1, 0, MapH - 1)
    qx0 = ((x0 + BrRouteQuantumPx - 1) div BrRouteQuantumPx) * BrRouteQuantumPx
    qy0 = ((y0 + BrRouteQuantumPx - 1) div BrRouteQuantumPx) * BrRouteQuantumPx
    qx1 = (x1 div BrRouteQuantumPx) * BrRouteQuantumPx
    qy1 = (y1 div BrRouteQuantumPx) * BrRouteQuantumPx
  result.x0 = if qx0 <= qx1: qx0 else: x0
  result.x1 = if qx0 <= qx1: qx1 else: x1
  result.y0 = if qy0 <= qy1: qy0 else: y0
  result.y1 = if qy0 <= qy1: qy1 else: y1

proc coverNear(bot: Bot, desired: Vec, safe: ZoneRect): Vec =
  ## A local cover cell around the goal. The path to it still comes from the
  ## nav cost field, whose exposure surcharge makes the whole approach
  ## cover-to-cover rather than a straight-line sprint.
  if not bot.navBuilt:
    return safe.clampInside(desired)
  let
    wanted = safe.clampInside(desired)
    c0 = bot.nearestOpenCell(cellOf(wanted))
    cx = c0 mod GridW
    cy = c0 div GridW
  result = wanted
  var bestD = 1e18
  for dy in -BrCoverSearchCells .. BrCoverSearchCells:
    for dx in -BrCoverSearchCells .. BrCoverSearchCells:
      let
        nx = cx + dx
        ny = cy + dy
      if nx < 0 or ny < 0 or nx >= GridW or ny >= GridH:
        continue
      let nc = ny * GridW + nx
      if not bot.coverCell[nc]:
        continue
      let p = cellCenter(nc)
      if not safe.inside(p):
        continue
      let d = dist(p, wanted)
      if d < bestD:
        bestD = d
        result = p

proc chooseRoyaleObjective*(
    bot: Bot, client: ProtocolClient, f: var Frame) =
  f.brMode = true
  f.brZoneUrgent = false
  f.brHold = false
  f.brHaveWatch = false
  f.brRouteConstrained = false

  let
    current = client.readZoneRect(lkZone)
    statedNext = client.readZoneRect(lkZoneNext)
    next = if statedNext.valid: statedNext else: current
  if current.valid:
    # Moving before the interpolation begins is cheaper than racing a lethal
    # edge. Any frame outside the inset of either rect is a safety override.
    f.brZoneUrgent = not current.inside(f.me) or not next.inside(f.me)
    if f.brZoneUrgent:
      f.target = bot.coverNear(next.duoPoint(bot.role), next)
      let route = current.quantizedRouteBounds()
      f.brRouteConstrained = true
      f.brRouteX0 = route.x0
      f.brRouteY0 = route.y0
      f.brRouteX1 = route.x1
      f.brRouteY1 = route.y1
      f.brHaveWatch = true
      f.brWatch = next.centre()
      return

  var mate = -1
  for i in 0 ..< bot.mates.len:
    if bot.tick - bot.mates[i].lastSeen <= BrPartnerMemoryTtl:
      mate = i
      break
  if mate >= 0:
    let d = dist(bot.mates[mate].pos, f.me)
    if d > BrPartnerMax:
      let rendezvous = bot.mates[mate].pos +
        norm(f.me - bot.mates[mate].pos) * ((BrPartnerMin + BrPartnerMax) * 0.5)
      f.target = bot.coverNear(next.clampInside(rendezvous), next)
      f.brHaveWatch = true
      f.brWatch = bot.mates[mate].pos
      return
    if d <= 0.5:
      if bot.role == RoyaleAnchor:
        f.target = f.me
        f.brHold = true
      else:
        let away =
          if next.valid: norm(next.centre() - f.me)
          else: vec(if bot.slot mod 2 == 0: 1.0 else: -1.0, 0.0)
        f.target = bot.coverNear(next.clampInside(f.me + away * BrPartnerMin), next)
      f.brHaveWatch = true
      f.brWatch = bot.mates[mate].pos
      return
    if d < BrPartnerMin:
      f.target = bot.coverNear(
        next.clampInside(f.me + norm(f.me - bot.mates[mate].pos) * BrPartnerMin),
        next)
      f.brHaveWatch = true
      f.brWatch = bot.mates[mate].pos
      return

  # A bounded heal detour preserves the one life that matters. The anchor is
  # the designated shield carrier; the scout keeps the normal gun cadence.
  if bot.hp < MaxHp:
    var
      pick = -1
      best = BrLootReach
    for i in 0 ..< bot.kitPos.len:
      if not bot.kitAvailable(i) or not next.inside(bot.kitPos[i]):
        continue
      let d = dist(f.me, bot.kitPos[i])
      if d < best:
        best = d
        pick = i
    if pick >= 0:
      f.target = bot.kitPos[pick]
      return
  elif bot.role == RoyaleAnchor and not f.hasShield and
      f.seenEnemies.len == 0 and current.areaFraction() > BrEndgameZoneFrac:
    var
      pick = -1
      best = BrLootReach
    for i in 0 ..< bot.shieldPos.len:
      if not pickupAvailable(bot.shieldAbsentAt, i, bot.tick) or
          not next.inside(bot.shieldPos[i]):
        continue
      let d = dist(f.me, bot.shieldPos[i])
      if d < best:
        best = d
        pick = i
    if pick >= 0:
      f.target = bot.shieldPos[pick]
      return

  let scores = client.readScoreboard()
  var aliveTeams = GameTeams
  if scores.ok:
    aliveTeams = 0
    for c in activeColours():
      if scores.deaths[c] < 2:
        inc aliveTeams
  if current.areaFraction() <= BrEndgameZoneFrac or aliveTeams <= BrEndgameTeams:
    var
      trailing = false
      ownLives = 0
    if scores.ok:
      ownLives = max(0, 2 - scores.deaths[bot.colour])
      var
        bestRivalLives = 0
        bestRivalKills = 0
      for c in activeColours():
        if c == bot.colour or scores.deaths[c] >= 2:
          continue
        bestRivalLives = max(bestRivalLives, 2 - scores.deaths[c])
        bestRivalKills = max(bestRivalKills, scores.kills[c])
      trailing = ownLives < bestRivalLives or
        scores.kills[bot.colour] < bestRivalKills
    var
      hunt = -1
      best = 1e18
    if scores.ok and trailing:
      for i in 0 ..< bot.enemies.len:
        let t = bot.enemies[i]
        if bot.tick - t.lastSeen > BrHuntTrackTtl or t.pid < 0:
          continue
        let colour = Colour(t.pid mod GameTeams)
        if colour == bot.colour or scores.deaths[colour] >= 2:
          continue
        let d = dist(f.me, t.pos)
        if d < best:
          best = d
          hunt = i
    if hunt >= 0:
      f.target = bot.coverNear(next.clampInside(bot.enemies[hunt].pos), next)
      f.brHaveWatch = true
      f.brWatch = bot.enemies[hunt].pos
      return
    if scores.ok and not trailing and ownLives == 2:
      f.target = bot.coverNear(next.duoPoint(bot.role), next)
      f.brHold = dist(f.target, f.me) < HoldArriveDist
      f.brHaveWatch = true
      f.brWatch = next.centre()
      return

  # Safe and grouped: occupy nearby cover and sweep likely approaches. The
  # scout biases one short bound toward the next-zone centre so both duo
  # seats do not select the same cell.
  let holdSeed =
    if next.valid: next.duoPoint(bot.role)
    else: f.me
  f.target = bot.coverNear(holdSeed, next)
  f.brHold = dist(f.target, f.me) < HoldArriveDist
  if bot.enemies.len > 0:
    f.brHaveWatch = true
    f.brWatch = bot.enemies[0].pos
  elif mate >= 0 and (bot.tick div BrPartnerScanTicks) mod 2 == 0:
    f.brHaveWatch = true
    f.brWatch = bot.mates[mate].pos
  elif next.valid:
    f.brHaveWatch = true
    f.brWatch = next.centre()
