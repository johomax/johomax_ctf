## The actuator: one frame's decisions arbitrated onto the d-pad, the two
## rotate buttons, A and C.
##
## Every stage above this one decided what it WANTED; here those wants are
## ranked against each other and collapse into the single input mask the
## server accepts. Turret and legs are decided together but ride separate
## bits, so a branch can pin the aim and still walk — and the first combat
## branch that claims the frame (`acted`) stops the rest from arguing.

import
  std/[math, random],
  bitworld/spriteprotocol,
  protocols,
  frame,
  navgrid,
  grid,
  tactics,
  world,
  geometry,
  tuning

proc arbitrateCombat(bot: Bot, client: ProtocolClient, f: var Frame) =
  ## The combat branch chain: the first one that fits claims the frame.
  if bot.nadeCharge > 0 or f.nadeAim >= 0:
    # Charge-throw: lay the turret on the lob line, then hold C for the ticks
    # the planned distance needs and release — the grenade leaves along the
    # CURRENT aim on release, so the turret keeps correcting while charging.
    if bot.nadeCharge == 0:
      bot.nadeNeed = max(3, int(float(NadeFullChargeTicks) *
        (f.nadeThrowD - NadeTapRange) / (NadeMaxRange - NadeTapRange)))
    if f.nadeAim >= 0:
      f.desiredAim = f.nadeAim
    if bot.nadeCharge > 0 or (f.desiredAim >= 0 and
        abs(bradsErr(f.desiredAim, bot.estAim)) <= CombatDeadband + 2):
      if bot.nadeCharge < bot.nadeNeed:
        f.nadeC = true
        inc bot.nadeCharge
      else:
        bot.nadeCharge = 0           # release this tick = the throw
    f.holdStill = true
    f.acted = true
  elif f.hasPlasma and f.engage >= 0:
    # Plasma cone: ignition is INSTANT (no windup, no aim lock), reaches 4
    # squares in a ~14-degree half-angle cone, stays on 5 ticks, and deals
    # 3 hp (lethal to bare cogs) — press A the moment the victim is inside
    # reach and roughly in front.
    f.desiredAim = bradsOf(f.aim - f.me)
    let err = abs(bradsErr(f.desiredAim, bot.estAim))
    # Ignite a little early on the angle: the cone stays on 5 ticks and
    # tracks our aim, so the ongoing traverse sweeps it across the target.
    if f.engageD <= PlasmaReach - 6.0 and err <= PlasmaHalfBrads + 3:
      f.wantFire = true
      f.holdStill = true
    else:
      f.moveMask = octantBits(f.aim - f.me)    # charge in
    f.acted = true
  elif f.engage >= 0 and f.shotReady:
    # Traverse onto the target and fire once the corridor covers it: the
    # perpendicular miss of the current aim error at the target's range must
    # sit inside the ~14px bullet corridor. Advancing scales that miss down
    # linearly, so keep closing while the turret settles.
    f.desiredAim = bradsOf(f.aim - f.me)
    let
      err = abs(bradsErr(f.desiredAim, bot.estAim))
      perpMiss = f.engageD * sin(float(err) * PI / float(AimBrads div 2))
    f.wantFire = perpMiss <= FireSlackPx
    f.moveMask = octantBits(f.aim - f.me)
    f.acted = true
  elif not f.iCarry and not f.rushing and not f.pocketRush and not f.shotReady and
      f.nearThreat >= 0:
    # Cooldown: duck behind the nearest cover that breaks the threat's line
    # and hold there until the gun is back up, keeping the aim (and the
    # vision cone) on the arc the threat would push through.
    let duck = bot.findDuckCell(client, f.me, bot.enemies[f.nearThreat].pos)
    if duck >= 0:
      f.desiredAim = bradsOf(bot.enemies[f.nearThreat].pos - f.me)
      if dist(cellCenter(duck), f.me) < 5.0:
        f.holdStill = true
      else:
        f.moveMask = octantBits(cellCenter(duck) - f.me)
      f.acted = true
  elif not f.iCarry and not f.rushing and f.shotReady and f.haveBlocked:
    # Peek: PRE-LAY the aim on the blocked target while stepping sideways to
    # the nearest cell that opens the firing line — the engage branch fires
    # the moment the ray clears, with the traverse already done.
    f.desiredAim = bradsOf(f.blockedAim - f.me)
    let peek = bot.findPeekCell(client, f.me, f.blockedAim)
    if peek >= 0 and dist(cellCenter(peek), f.me) > 4.0:
      f.moveMask = octantBits(cellCenter(peek) - f.me)
      f.acted = true

proc chooseMovement(bot: Bot, client: ProtocolClient, f: var Frame) =
  ## Where the feet go when no combat branch claimed the frame.
  # Threat jink: sidestep a visible enemy that is aiming our way while our
  # own shot is not lined up, instead of walking into its muzzle.
  var threat = -1
  var threatD = ThreatRange
  for i in 0 ..< f.seenEnemies.len:
    let a = f.seenEnemies[i]
    let facingMe =
      (a.facingRight and a.pos.x < f.me.x) or
      (not a.facingRight and a.pos.x > f.me.x)
    let d = dist(a.pos, f.me)
    if facingMe and d < threatD:
      threatD = d
      threat = i
  if threat >= 0 and not f.iCarry and not f.pocketRush:
    let away = norm(f.me - f.seenEnemies[threat].pos)
    var side = vec(-away.y, away.x)
    if (bot.tick div 12 + bot.slot div 2) mod 2 == 0:
      side = side * -1.0
    if not bot.gridRayClear(f.me, f.me + side * 24.0):
      side = side * -1.0
    f.moveMask = octantBits(side + away * 0.4)
    if f.desiredAim < 0:
      f.desiredAim = bradsOf(f.seenEnemies[threat].pos - f.me)
  elif bot.role in {Overwatch, HomeDefender} and
      dist(f.me, f.target) < 6.0:
    # Holding a watch position: the aim carries the vision cone, so sweep
    # it back and forth across the arc threats cross while standing still.
    # While our flag is stolen the thief comes from our own half;
    # otherwise intruders come from the enemy half.
    let watch =
      if f.ownStolen: vec(homeSign(bot.team), 0.0)
      else: vec(-homeSign(bot.team), 0.0)
    if f.desiredAim < 0:
      # Standing a watch, there are no feet to follow -- but the sweep is
      # not idleness, it is what covers the whole approach. Only give it up
      # for something close and current enough to be worth staring at; for
      # anything older or further off, raking the arc finds more than
      # fixing on a spot a body has already left.
      let pa = bot.preAimBearing(f.me, vec(0.0, 0.0), f.maxEngage,
        PreAimWatchRange, PreAimWatchTtl)
      if pa >= 0:
        f.desiredAim = pa
      if f.desiredAim < 0:
        f.desiredAim = bot.scanAim(watch)
    f.holdStill = true
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
    if bot.killsInit and not f.iCarry and not f.ownStolen and holdNow:
      let depth = -homeSign(bot.team) * (f.target.x - float(CenterX))
      if depth > HoldLineDepth:
        f.target.x = float(CenterX) - homeSign(bot.team) * HoldLineDepth
    # Navigate: cover-aware path steering plus soft repulsion from nearby
    # teammates so one burst (or our own shot) cannot hit two of us.
    var steer = norm(bot.navSteer(client, f.me, f.target))
    for t in bot.mates:
      if bot.tick - t.lastSeen > 12:
        continue
      let d = dist(t.pos, f.me)
      if d < MateSpacing and d > 0.5:
        steer = steer + norm(f.me - t.pos) * ((MateSpacing - d) / MateSpacing) * 0.9
    # Serpentine when a straight run would cross watched ground. Fog cuts
    # both ways: a fresh remembered enemy with a clear pixel line pins
    # anyone, and rushers crossing the contested MIDDLE weave even without
    # intel — the snipers watching their lane are exactly the enemies they
    # cannot see. Close threats are the jink/duck branches' job; carriers
    # and the pocket grab skip it — for them speed beats evasion.
    if not f.iCarry and not f.pocketRush:
      var weave = false
      if f.rushing:
        weave = abs(f.me.x - float(CenterX)) < WeaveBand
      else:
        for t in bot.enemies:
          if bot.tick - t.lastSeen > UnderFireTrackTtl:
            continue
          let d = dist(t.pos, f.me)
          if d >= SerpentineNear and d <= SerpentineFar and
              client.pixelRayClear(f.me, t.pos):
            weave = true
            break
      if weave:
        var side = vec(-steer.y, steer.x)
        if (bot.tick div 8 + bot.slot div 2) mod 2 == 0:
          side = side * -1.0
        steer = norm(steer) + side * 0.6
    steer = steer + vec(rand(-0.12 .. 0.12), rand(-0.12 .. 0.12))
    f.moveMask = octantBits(steer)
    if bot.tick < bot.jinkUntil:
      f.moveMask = bot.jinkBits            # unsticking burst
    if f.desiredAim < 0:
      # No target demands the turret: the aim leads the movement direction
      # so the vision cone watches down-lane where we are heading. Movement
      # no longer leaks our vision, so this is a choice, not a side effect.
      f.desiredAim = bradsOf(steer)
      f.deadband = CruiseDeadband
      # Something we heard or remember beats watching our own feet -- but
      # only while it is roughly ahead. The cone rides the aim, so laying
      # the gun behind us to cover a noise would walk the rest of us
      # blindly into whatever is in front, and trade a fight we might win
      # for one we never see coming.
      let pa = bot.preAimBearing(f.me, norm(steer), f.maxEngage)
      if pa >= 0 and abs(bradsErr(pa, f.desiredAim)) <= PreAimArc:
        f.desiredAim = pa
        f.deadband = CombatDeadband     # laid on a real expectation now

proc assembleMask(bot: Bot, f: var Frame): uint8 =
  ## The back-guard clamp, the rotate bits, and the buttons packed into one
  ## input mask.
  if f.desiredAim >= 0 and f.engage < 0 and bot.nadeCharge == 0 and not f.iCarry:
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
      let d = dist(t.pos, f.me)
      if d < guardD and
          bot.couldTrade(f.me, vec(0.0, 0.0), t.pos, t.vel, float(age), f.maxEngage):
        guardD = d
        guard = i
    if guard >= 0:
      let
        threatAim = bradsOf(bot.enemies[guard].pos - f.me)
        e = bradsErr(threatAim, f.desiredAim)
      if e > BackGuardArc:
        f.desiredAim = floorMod(threatAim - BackGuardArc, AimBrads)
      elif e < -BackGuardArc:
        f.desiredAim = floorMod(threatAim + BackGuardArc, AimBrads)

  # Rotate toward the desired aim by the shortest arc; inside the deadband
  # (AimRate cannot settle tighter than +-AimRate/2) hold the turret still.
  var rotBits: uint8 = 0
  if f.desiredAim >= 0:
    let err = bradsErr(f.desiredAim, bot.estAim)
    if err > f.deadband:
      rotBits = ButtonB
    elif err < -f.deadband:
      rotBits = ButtonSelect

  # Only a FRESH A press fires, and the pull locks the aim angle on the same
  # tick — never rotate on the pull tick so the lock takes the settled aim.
  var mask = f.moveMask or rotBits
  if f.wantFire and not bot.firedLast:
    mask = f.moveMask or ButtonA
  # ButtonC (grenade charge/throw, input mask bit 128) is imported from
  # bitworld/spriteprotocol, NOT redefined here. Only the pinned bitworld
  # lineage (nimby.lock: 5d229ac, branch daveey/hd-client-pin) exports it —
  # bitworld master never received the 8-bit input mask and still ANDs the
  # mask with 0x7f, which silently deletes every grenade throw on the wire.
  # A local `ButtonC = 1'u8 shl 7` is exactly what made that truncation
  # invisible: it compiled cleanly against the wrong engine and cost v25-v27
  # ~0.4 K/D against v9. Importing the symbol turns the wrong engine commit
  # into a compile error instead of a silent regression.
  if f.nadeC:
    mask = mask or ButtonC
  bot.firedLast = (mask and ButtonA) != 0
  bot.rotSign =
    if (mask and ButtonB) != 0: 1
    elif (mask and ButtonSelect) != 0: -1
    else: 0
  mask

proc actOn*(bot: Bot, client: ProtocolClient, f: var Frame): uint8 =
  ## Arbitrates one frame's decisions into the input mask the server reads.
  # Turret + locomotion, decided together but on separate buttons: moveMask
  # is the d-pad, desiredAim feeds the rotate buttons, wantFire pulls A.
  f.moveMask = 0
  f.desiredAim = -1
  f.deadband = CombatDeadband
  f.wantFire = false
  f.acted = false
  f.holdStill = false
  f.nadeC = false
  bot.arbitrateCombat(client, f)

  if not f.acted:
    bot.chooseMovement(client, f)

  # Stuck detection: if we have not moved for a second (and are not holding
  # behind cover on purpose), burst in a random direction and force a repath.
  if dist(f.me, bot.lastPos) < 0.8:
    inc bot.stuckTicks
  else:
    bot.stuckTicks = 0
  bot.lastPos = f.me
  if f.holdStill:
    bot.stuckTicks = 0
  # A held target vetoes the burst: while a fight is on, staying put is the
  # point.
  if bot.stuckTicks > 20 and f.engage < 0:
    bot.stuckTicks = 0
    bot.jinkUntil = bot.tick + 10
    bot.jinkBits = octantBits(vec(rand(-1.0 .. 1.0), rand(-1.0 .. 1.0)))
    bot.navGoal = -1
    if bot.jinkBits == 0:
      bot.jinkBits = ButtonUp
    f.moveMask = bot.jinkBits

  if f.nadeDanger:
    # Sprint straight out of the marked blast zone; drop any hold/duck.
    let away = f.me - f.nadeDangerFrom
    f.moveMask = octantBits(
      if len(away) < 1.0: vec(homeSign(bot.team), 0.3) else: away
    )
    f.holdStill = false

  if f.moveMask == 0 and not f.holdStill:
    f.moveMask = octantBits(vec(rand(-1.0 .. 1.0), rand(-1.0 .. 1.0)))

  bot.assembleMask(f)
