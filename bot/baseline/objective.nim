## Where this seat is walking, and what is worth stepping aside for.
##
## `chooseObjective` turns the flag situation and the role into one movement
## goal: run the stolen flag home, cut off the thief carrying ours, escort a
## mate, hold the choke or the post, or route in for the steal. It also decides
## when the posts stop being worth holding at all. `applyPickupDetours` runs two
## stages later and only rewrites that goal — a shield, a plasma arc, a med kit
## or a grenade is each worth a few steps off the line.

import
  protocols,
  labels,
  frame,
  perception,
  memory,
  tactics,
  world,
  geometry,
  tuning

proc chooseObjective*(bot: Bot, f: var Frame) =
  # Flank progress: sticky so lane-runners do not oscillate at the boundary.
  if bot.role in {FlankTop, FlankBottom}:
    let fwd = -homeSign(bot.team) * (f.me.x - float(CenterX))
    if fwd >= FlankDepth - 50.0:
      bot.behindLines = true
    elif fwd < 20.0:
      bot.behindLines = false

  # Endgame push: our flag is safe and nobody on OUR side has seen an enemy
  # for a long while deep into the game. The survivors by then are usually
  # the defensive seats, and holding their posts forever is a guaranteed
  # tiebreak stalemate — break the posts and go win by capture (the enemy
  # team pushes symmetrically, so somebody makes something happen).
  f.pushOut = not f.ownStolen and (
    (bot.tick - bot.gameStart > PushOutMinGame and
     bot.tick - bot.lastEnemySeen > PushOutTicks) or
    # Late all-in: a timeout is a scoreless draw, so deep into a game with no
    # capture the posts are worth nothing — break them and go win. Standoffs
    # keep enemies in sight, so the quiet-field trigger above never fires
    # against a peek-duck opponent; this one is on the clock.
    bot.tick - bot.gameStart > LatePushTick
  )

  # Movement target from role and flag situation.
  if f.iCarry:
    # Run the stolen enemy flag home along the emptiest lane; the exposure
    # cost in the path field keeps the route hugging cover past remembered
    # enemies.
    let
      pocket = flagHome(enemy(bot.team))
      laneY = bot.safestLaneY(f.me)
    if abs(f.me.x - pocket.x) < 60.0 and abs(f.me.y - laneY) > 70.0:
      # Bug out of the pocket VERTICALLY first: every kill respawns an
      # armed enemy at this pedestal whose spawn aim points
      # along the east-west axis — pure-vertical movement exits that cone
      # fastest, then the border lane runs home outside it.
      f.target = vec(pocket.x, laneY)
    else:
      f.target = vec(homeDeepX(bot.team), laneY)
    # A hurt carrier detours through a stocked med kit on the way home: the
    # run crosses the center line anyway, kits are hurt-only pickups (a
    # healthy escort cannot waste one), and a full-heal carrier survives
    # pocket exits and mid crossings that kill a 1 hp one.
    if bot.hp < MaxHp:
      let kit = bot.bestKitDetour(f.me, f.target, MedKitCarrierBudget)
      if kit >= 0:
        f.target = bot.kitPos[kit]
  elif f.ownStolen and (bot.role == HomeDefender or
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
      f.target = vec(clamp(predicted.x, 20.0, float(MapW - 20)),
                     clamp(predicted.y, 20.0, float(MapH - 20)))
    else:
      var laneY = LaneMid
      if bot.carrierSeen > -100_000:
        var bestD = 1e18
        for lane in [LaneTop, LaneMid, LaneBottom]:
          if abs(bot.carrierPos.y - lane) < bestD:
            bestD = abs(bot.carrierPos.y - lane)
            laneY = lane
      f.target = vec(float(CenterX) - homeSign(bot.team) * 60.0, laneY)
  elif f.mateCarry:
    case bot.role
    of MidTop, FlankTop:
      f.target = f.mateCarryPos + vec(homeSign(bot.team) * 46.0, -30.0)
    of MidBottom, FlankBottom:
      # Rear guard: sit between the carrier and the enemy pocket it just
      # robbed — respawners chase from there, and the gun kills the NEAREST
      # player in the cone, so a body on the ray shields the carrier.
      f.target = f.mateCarryPos + vec(
        -homeSign(bot.team) * 42.0,
        (if bot.role == MidBottom: 22.0 else: -22.0)
      )
    of MidGuard:
      # Screen the carrier from the nearest remembered threat.
      var threat = -1
      var threatD = 1e18
      for i in 0 ..< bot.enemies.len:
        let d = dist(bot.enemies[i].pos, f.mateCarryPos)
        if d < threatD:
          threatD = d
          threat = i
      if threat >= 0:
        f.target = f.mateCarryPos + norm(bot.enemies[threat].pos - f.mateCarryPos) * 30.0
      else:
        f.target = f.mateCarryPos + vec(-homeSign(bot.team) * 32.0, 0.0)
    of Overwatch:
      # The posts already overwatch the carrier's retreat across mid.
      f.target =
        if bot.postReady: bot.postHold
        else: f.mateCarryPos + vec(-homeSign(bot.team) * 32.0, 0.0)
    of HomeDefender:
      f.target = bot.chokeHold
  elif bot.role == HomeDefender and not f.pushOut:
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
      let d = dist(bot.enemies[i].pos, f.me)
      if d < intruderD:
        intruderD = d
        intruder = i
    if intruder >= 0:
      f.target = bot.enemies[intruder].pos + bot.enemies[intruder].vel * 6.0
    else:
      f.target = bot.chokeHold
  elif bot.role == Overwatch and not f.pushOut:
    if bot.postReady:
      # Peek-and-shoot cycle: hold behind the post; with the gun up and a
      # remembered enemy in reach, sidestep to the peek cell to open the
      # line (the combat block below takes the shot and ducks us back).
      f.target = bot.postHold
      if f.shotReady:
        for t in bot.enemies:
          if bot.tick - t.lastSeen <= 24 and
              dist(t.pos, bot.postHold) < FireRange + 30.0:
            f.target = bot.postPeek
            break
    else:
      f.target = vec(float(CenterX) + homeSign(bot.team) * 70.0, float(CenterY))
  else:
    # Attackers: route to the ENEMY pedestal — a fixed, known position by
    # team side. The lead rusher races it dead straight (its seat spawns at
    # pedestal height), the second mid trails behind and offset so one enemy
    # cone cannot kill the pair; flankers run the extreme lanes deep past
    # mid, then hit the pedestal pocket from behind.
    f.target = f.stealTarget
    case bot.role
    of MidBottom:
      if dist(f.me, f.stealTarget) > 90:
        f.target = f.stealTarget + vec(homeSign(bot.team) * 34.0, 26.0)
    of MidGuard:
      if dist(f.me, f.stealTarget) > 90:
        f.target = f.stealTarget + vec(homeSign(bot.team) * 60.0, -26.0)
    of FlankTop, FlankBottom:
      # Run the wide lane deep, then turn straight in for the grab so the
      # flankers hit the pocket together with the mid trio instead of
      # trickling in.
      let laneY = (if bot.role == FlankTop: LaneTop else: LaneBottom)
      if not bot.behindLines and dist(f.me, f.stealTarget) > 170.0:
        f.target = vec(float(CenterX) - homeSign(bot.team) * FlankDepth, laneY)
    else:
      discard

proc applyPickupDetours*(bot: Bot, client: ProtocolClient, f: var Frame) =
  # Weapon pickups. SHIELD-THEN-STEAL: the enemy endzone shield sits just
  # behind their pedestal — a rusher near the pocket grabs 6 hp first and
  # steals second (the run home is what kills 3 hp carriers). Defensive
  # roles never take a shield (it slows the gun 3x). PLASMA ARCS arm the
  # pocket brawlers: attackers detour a little for one on the way in — the
  # pocket duel is close-range, where an instant lethal cone beats any gun.
  if not f.iCarry and not f.hasShield and bot.role == MidGuard and
      not (f.ownStolen and bot.tick - bot.carrierSeen <= ThiefFixTtl):
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
      let cost = dist(f.me, bot.shieldPos[i]) + dist(bot.shieldPos[i], f.stealTarget) -
        dist(f.me, f.stealTarget)
      if cost < bestCost:
        bestCost = cost
        best = i
    if best >= 0:
      f.target = bot.shieldPos[best]
  elif not f.iCarry and not f.hasPlasma and
      bot.role in {MidTop, MidBottom, MidGuard, FlankTop, FlankBottom} and
      not f.mateCarry and not f.pocketRush:
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
      if dist(f.me, bot.plasmaPos[i]) <= PlasmaDetour:
        f.target = bot.plasmaPos[i]
        break

  # Med kit heal detour (hurt bots only; the carrier handles its own detour
  # in the carry branch). Wounded: a short opportunistic detour. Critical
  # (1 hp): a heal outranks the current errand at much longer reach — a
  # healed body is a respawn we did not spend. Never while committing to the
  # pocket touch or chasing the enemy running our flag, and the CARRIER gets
  # right of way: if our flag runner is closer to the kit than we are, we
  # leave it — kits are hurt-only pickups, so deferring costs nothing when
  # the carrier turns out healthy.
  if bot.hp < MaxHp and not f.iCarry and not f.pocketRush and
      not (f.ownStolen and bot.tick - bot.carrierSeen <= ThiefFixTtl):
    let reach = if bot.hp <= 1: MedKitCriticalReach else: MedKitDetour
    let kit = bot.bestKitDetour(f.me, f.target, reach)
    if kit >= 0 and not (f.mateCarry and
        dist(f.mateCarryPos, bot.kitPos[kit]) < dist(f.me, bot.kitPos[kit]) + 100.0):
      f.target = bot.kitPos[kit]

  var armed = false
  if not f.carryingNade and not f.iCarry and not f.mateCarry and not f.pocketRush:
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
      if dist(p, f.me) <= reach:
        f.target = p
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
        let d = dist(p, f.me)
        if d < bestD:
          bestD = d
          pick = i
      if pick >= 0:
        f.target = bot.nadePos[pick]
