## Track and pickup memory — what the bot keeps believing once it can no
## longer see.
##
## `updateTracks` folds this frame's sightings into the remembered players,
## matching by badge before proximity so two enemies crossing cannot swap
## their velocities. The pickup half is fog-honest bookkeeping: a spot is
## learned on sight, marked taken only when we walk close enough that the
## bubble would have shown it, and believed restocked once its timer elapses.

import
  std/[algorithm],
  world,
  geometry,
  tuning

proc updateTracks*(bot: Bot, tracks: var seq[Track], seen: seq[Actor]) =
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

proc trackPickups*(
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

proc pickupAvailable*(absentAt: seq[int], i, tick: int): bool =
  absentAt[i] < 0 or tick - absentAt[i] > PickupRespawn + 48

proc nadeAvailable*(bot: Bot, i: int): bool =
  ## Whether a corner grenade is believed to be sitting there right now. The
  ## refill is quick, so a corner we emptied is worth returning to sooner than
  ## any other pickup on the map.
  bot.nadeAbsentAt[i] < 0 or bot.tick - bot.nadeAbsentAt[i] > NadeRespawn + 24

proc kitAvailable*(bot: Bot, i: int): bool =
  ## Whether a discovered med kit spot is believed stocked right now: never
  ## seen empty, or its 30s respawn has elapsed since we saw it taken.
  bot.kitAbsentAt[i] < 0 or bot.tick - bot.kitAbsentAt[i] > MedKitRespawn + 48

proc bestKitDetour*(bot: Bot, me, dest: Vec, budget: float): int =
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
