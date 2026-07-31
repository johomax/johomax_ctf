## The sensor pass — everything the bot learns this tick before it decides
## anything.
##
## First the turret aim is put back in step with the server (the respawn reset
## and the bound the self sprite proves), then the pickups, tracks, sonar and
## hit points are folded into memory, and last the two flags are read, which
## drive every branch after this.

import
  bitworld/profile,
  std/[math, options, strutils],
  protocols,
  labelkind,
  labels,
  frame,
  perception,
  memory,
  world,
  geometry,
  tuning

proc syncAim*(bot: Bot, client: ProtocolClient, f: Frame) {.measure.} =
  ## Puts the dead-reckoned turret aim back in step with the server: the
  ## respawn reset, then the bound the self sprite's rotation step proves.
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
  # All of that holds only while the marker draws our TRUE aim, which is a
  # fact about the game version rather than something the bot can see. GV24
  # (2026-07-29) briefly fuzzed every soldier sprite "self included", which
  # would turn this bound into a lie that drags a correct dead reckoning off
  # true; GV26 exempted the self marker again. Verified 2026-07-30: the league
  # runs coworld `ctf` v0.7.124 from coworld-ctf beae1614, GameVersion 27,
  # self exempt — so this is sound as written. Re-check it if the self marker
  # is ever fuzzed again; nothing here would notice on its own.
  let centre = client.selfAimBucket(f.myTeam)
  if centre >= 0:
    let c = bradsErr(centre, bot.estAim)
    if c > SoldierRotHalf:
      # The bucket sits counter-clockwise of the estimate: the estimate is
      # below the bucket's low edge, so the nearest possible aim is the
      # low edge itself.
      bot.estAim = floorMod(centre - SoldierRotHalf, AimBrads)
    elif c < -SoldierRotHalf + 1:
      # Mirror case: the estimate has run past the bucket's high edge.
      bot.estAim = floorMod(centre + SoldierRotHalf - 1, AimBrads)

proc updateSenses*(bot: Bot, client: ProtocolClient, f: var Frame) {.measure.} =
  ## Folds this frame's wire into the bot's picture of the field: pickup
  ## spots, what we are carrying, who is visible, what we heard, what the
  ## scoreboard implies about the landings, and our own hit points.
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
  for o in client.objectsOf(lkSprayCan):
    plasmaSeen.add(client.mapPos(o))
  for o in client.objectsOf(lkShield):
    shieldSeen.add(client.mapPos(o))
  trackPickups(bot.plasmaPos, bot.plasmaAbsentAt, plasmaSeen, f.me, bot.tick)
  trackPickups(bot.shieldPos, bot.shieldAbsentAt, shieldSeen, f.me, bot.tick)
  var nadeSeen: seq[Vec]
  for o in client.objectsOf(lkGrenade):
    let gp = client.mapPos(o)
    if gp.x < 40.0 or gp.y < 40.0 or gp.x > float(MapW - 40) or
        gp.y > float(MapH - 40):
      continue                           # the HUD indicator shares the label
    nadeSeen.add(gp)
  trackPickups(bot.nadePos, bot.nadeAbsentAt, nadeSeen, f.me, bot.tick)
  # Own carry state: the carried markers float over their carrier, and a
  # shield carrier's HUD reads 6 hp (the marker is the fallback).
  f.hasPlasma = false
  for o in client.objectsOf(lkSprayCanCarried):
    if dist(client.mapPos(o), f.me) <= 30.0:
      f.hasPlasma = true
      break
  f.hasShield = bot.hp > MaxHp
  if not f.hasShield:
    for o in client.objectsOf(lkShieldCarried):
      if dist(client.mapPos(o), f.me) <= 30.0:
        f.hasShield = true
        break

  f.shotReady = client.countOf(lkFireIcon) > 0 and
    not f.hasPlasma                      # the spray can replaces the gun; a shield
                                         # only slows it (3x cooldown)
  f.seenEnemies = client.actorsFor(f.enemyTeam)
  f.seenMates = client.actorsFor(f.myTeam)
  bot.updateTracks(bot.enemies, f.seenEnemies)
  bot.updateTracks(bot.mates, f.seenMates)
  if f.seenEnemies.len > 0:
    bot.lastEnemySeen = bot.tick
  bot.hearShots(client)
  # The team channel, both directions. Reading first: a fix a mate shouted
  # this frame is usable this frame, and our own broadcast is about what we
  # can see, which nothing later in the decision changes.
  bot.hearShouts(client)
  bot.speakShout(f.seenEnemies, f.me)
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
          var ci = -1
          var cd = CorpseClearRadius
          for j in 0 ..< bot.enemies.len:
            let dj = dist(bot.enemies[j].pos, bot.sonar[i].pos)
            if dj < cd:
              cd = dj
              ci = j
          if ci >= 0:
            bot.enemies[ci] = bot.enemies[^1]
            bot.enemies.setLen(bot.enemies.len - 1)
          dec want
    bot.kills = now
    bot.killsInit = true

  # Own hit points from the HUD "lives <hp>hp x<lives>" text sprite.
  let lives = client.firstOf(lkLives)
  if lives.isSome:
    let text = client.labelOf(lives.get.spriteId)[LabelPrefixLives.len .. ^1]
    let cut = text.find("hp")
    if cut > 0:
      try:
        # Unclamped past MaxHp: a shield carrier reads 6 hp on the HUD.
        bot.hp = clamp(parseInt(text[0 ..< cut]), 1, 9)
      except ValueError:
        discard

  # Med kits: learn the two center-line spots on sight; presence is
  # fog-gated, so an empty spot only counts as TAKEN when we pass close
  # enough that the bubble would show it.
  var kitSeen: seq[Vec]
  for o in client.objectsOf(lkMedKit):
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
    if dist(bot.kitPos[i], f.me) <= MedKitSeenClear and bot.kitAbsentAt[i] < 0:
      var present = false
      for p in kitSeen:
        if dist(bot.kitPos[i], p) < 24.0:
          present = true
      if not present:
        bot.kitAbsentAt[i] = bot.tick

proc readFlagState*(bot: Bot, client: ProtocolClient, f: var Frame) {.measure.} =
  ## Reads both flags off this frame: where they are, who is carrying them,
  ## and — when nothing at all is visible — where the carrier must be.
  # Flag bookkeeping (two flags; a carried flag rides its carrier's exact
  # position). The enemy flag can only be carried by OUR team, so its sprite
  # is never fogged and fully describes our attack (pedestal / on me / on a
  # mate). Our own flag can only be carried by the enemy: on its pedestal it
  # is safe, visible off-pedestal is a live thief fix, and ABSENT means a
  # fogged thief is running it toward its home edge.
  f.iCarry = false
  f.mateCarry = false
  f.mateCarryPos = vec(0, 0)
  f.stealTarget = flagHome(enemy(bot.team))  # the enemy pedestal is static
  f.ownHome = flagHome(bot.team)
  # Since the 0.7.8 renderer restore the objective is labeled a FLAG again,
  # split into distinct pedestal/carried sprites: "<color> flag planted" is
  # the always-visible pedestal banner, "<color> flag" the carried banner
  # centered exactly on its carrier (fogged with the carrier). Only the count
  # and the first banner are ever read, so ask for exactly those.
  let
    enemyPlanted = client.countOf(FlagPlantedKinds[f.enemyTeam]) > 0
    enemyFlag = client.firstOf(FlagKinds[f.enemyTeam])
    ownPlanted = client.countOf(FlagPlantedKinds[f.myTeam]) > 0
    ownFlag = client.firstOf(FlagKinds[f.myTeam])

  if enemyPlanted:
    discard                              # enemy flag sits home: nobody carries
  elif enemyFlag.isSome:
    # Carried banner in sight, centered exactly on its carrier. "Am I the
    # carrier" is "is the flag on ME and on nobody else" — a visible mate
    # closer to it than us means the mate is the carrier.
    let fp = client.mapPos(enemyFlag.get)
    var mateCloser = false
    let dSelf = dist(fp, f.me)
    for t in bot.mates:
      if bot.tick - t.lastSeen <= 2 and dist(t.pos, fp) < dSelf:
        mateCloser = true
        break
    if dSelf <= CarrySelfRadius and not mateCloser:
      f.iCarry = true
    else:
      f.mateCarry = true                 # only a teammate can be carrying it
      f.mateCarryPos = fp
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
    f.mateCarry = true
    var est =
      if bot.mateFixTick > 0: bot.mateFixPos
      else: f.stealTarget
    let elapsed = float(bot.tick - max(bot.mateFixTick, bot.gameStart))
    est.x += homeSign(bot.team) * min(
      abs(f.ownHome.x - est.x),
      elapsed * CarrierEstSpeed
    )
    f.mateCarryPos = est
  f.ownStolen = not ownPlanted
  if ownPlanted:
    bot.carrierSeen = -100_000           # our flag is safely home
  elif ownFlag.isSome:
    # The thief holding our flag is inside our vision: take a fresh fix.
    let fp = client.mapPos(ownFlag.get)
    bot.carrierPos = fp
    bot.carrierVel = vec(0, 0)
    for t in bot.enemies:
      if dist(t.pos, fp) <= 8:
        bot.carrierVel = t.vel
        break
    bot.carrierSeen = bot.tick
