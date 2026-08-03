## The questions the policy asks before committing the turret or the feet.
##
## Could this fight even happen (`couldTrade`), where is contact most likely
## to come from (`preAimBearing`, `scanAim`), which lane runs home
## (`safestLaneY`), and whose shot is it safe to take (`nadeSafe`,
## `friendlyBlocked`). Combat and routing both ask these, so they sit below
## either of them.

import
  grid,
  world,
  geometry,
  tuning

proc nadeSafe*(bot: Bot, me, p: Vec): bool =
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

proc scanAim*(bot: Bot, watch: Vec): int =
  ## The scan-sweep aim while holding a position: rake the vision cone back
  ## and forth across the arc around the `watch` heading with real rotation.
  ## Flip the sweep direction whenever the current end is nearly reached.
  let
    center = bradsOf(watch)
    arc = scanArcFor(bot.team)     # per side; the pair lives in tuning.nim
  var goal = (center + (if bot.scanHigh: arc else: -arc) +
    AimBrads) mod AimBrads
  if abs(bradsErr(goal, bot.estAim)) <= CombatDeadband:
    bot.scanHigh = not bot.scanHigh
    goal = (center + (if bot.scanHigh: arc else: -arc) +
      AimBrads) mod AimBrads
  goal

proc couldTrade*(bot: Bot, me, myDir: Vec, at: Vec, vel: Vec,
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

proc preAimBearing*(bot: Bot, me, myDir: Vec, reach: float,
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
  # A mate's shout: a body, seen by somebody, named to a 32px cell. Priced
  # between the two above for exactly that reason -- it is a sighting rather
  # than a bullet, but through another seat's eyes and a cell rather than a
  # point. The list is empty unless ShoutMode is on, so this loop is the whole
  # of what level 1 does.
  for x in bot.shoutFixes:
    let age = bot.tick - x.tick
    if age > min(PreAimShoutTtl, maxAge):
      continue
    let d = dist(x.pos, me)
    if d > maxRange:
      continue
    if not bot.couldTrade(me, myDir, x.pos, vec(0.0, 0.0), 0.0, reach):
      continue
    let score = d + float(age) * PreAimAgePx + PreAimShoutCost
    if best < 0.0 or score < best:
      best = score
      result = bradsOf(x.pos - me)

proc safestLaneY*(bot: Bot, me: Vec): float =
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
        goalX = bot.homeDeepX(bot.team)
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

proc friendlyBlocked*(bot: Bot, me, aim: Vec, enemyDist: float): bool =
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
  when ShoutKillHere >= 1:
    # The same test against teammates we cannot see. This is the whole point
    # of the word: the guard above weighs only mates sighted in the last 36
    # ticks, so the teammate it is blindest to is the fogged one downrange,
    # and the server kills the NEAREST body in the corridor whichever side it
    # is on. A heard position is exact where a track is absent.
    for x in bot.mateFixes:
      if bot.tick - x.tick > ShoutKillHereTtl:
        continue
      let
        rel = x.pos - me
        d = rel.len()
        along = dot(rel, dir)
      if along <= 0 or d < 1e-6 or along >= enemyDist + 14.0:
        continue
      if abs(cross(rel, dir)) < CorridorHalfWidth:
        return true
  false
