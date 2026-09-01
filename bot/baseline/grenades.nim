## Grenades in both directions: the throw worth making because the gun cannot
## make it, and the blast we have to be somewhere else for.
##
## `planGrenade` scores landing points from fresh tracks, held sightings and
## enemy sonar pings, since a lob clears every wall and collects the value
## cover denies the gun. `scanNadeDanger` reads the rings and airborne
## grenades coming the other way, minus the one our own charge preview draws.

import
  bitworld/profile,
  protocols,
  labelkind,
  frame,
  perception,
  grid,
  tactics,
  world,
  geometry,
  tuning

proc planGrenade*(bot: Bot, client: ProtocolClient, f: var Frame) {.measure.} =
  # `offer` below is a closure, and a closure cannot capture the `var`
  # parameter `f`, so our position and the throw it picks stay plain locals
  # and are copied into the frame at the end.
  let me = f.me
  if f.brMode and bot.tick < BrHeavyFightTick:
    f.carryingNade = false
    f.nadeAim = -1
    f.nadeThrowD = 0.0
    return
  # Grenades (0.7.0): a lobbed 2-hp blast that flies over every wall — the
  # counter to cover-campers the hitscan gun can never reach. Carry one when a
  # corner pickup is a short detour away; spend it on a wall-blocked fresh
  # track (value the gun cannot collect) or on a tight enemy pair in range.
  f.carryingNade = false
  for o in client.objectsOf(lkGrenadeCarried):
    # The marker floats above-right of its carrier (+8 x, ~-20 y from center).
    if dist(client.mapPos(o), me) <= 30.0:
      f.carryingNade = true
      break
  var
    nadeAim = -1
    nadeThrowD = 0.0
  if f.carryingNade and not f.iCarry:
    # What a grenade is FOR here: it flies over walls in a straight line and
    # bursts on a plain radius, with no wall test on the damage either. Cover
    # stops bullets and does nothing whatever against this. So the throws worth
    # making are exactly the ones the gun cannot make -- and that includes
    # enemies we can no longer see at all, not merely ones we can see but
    # cannot shoot.
    var bestScore = 1e18
    proc offer(p: Vec, cost: float) =
      ## Weigh one candidate landing, nearest-and-surest first.
      let d = dist(p, me)
      if d < NadeMinRange or d > NadeMaxRange:
        return
      if d + cost >= bestScore:
        return
      if not bot.nadeSafe(me, p):
        return
      bestScore = d + cost
      nadeAim = bradsOf(p - me)
      nadeThrowD = d
    for i in 0 ..< bot.enemies.len:
      let
        t = bot.enemies[i]
        age = bot.tick - t.lastSeen
      if age > NadeMemTtl:
        continue
      if age <= FreshShotTicks:
        # Seen right now: lead it, and throw only when the gun cannot do the
        # job anyway, or when two of them are stood close enough to share one.
        let p = t.pos + t.vel * float(age)
        let blocked = not client.pixelRayClear(me, p)
        var paired = false
        if not blocked:
          for j in 0 ..< bot.enemies.len:
            if j != i and bot.tick - bot.enemies[j].lastSeen <= FreshShotTicks and
                dist(bot.enemies[j].pos, p) <= NadeBlast:
              paired = true
              break
        if blocked or paired:
          offer(p, 0.0)
      else:
        # Out of sight but not out of mind: someone who stepped behind cover
        # is still standing roughly where we last had them, and cover is no
        # defence against this weapon. Do not run the old velocity out over
        # the gap -- a stale heading extrapolated for seconds lands the throw
        # somewhere nobody ever was.
        offer(t.pos, NadeHeldCost)
    for sp in bot.sonar:
      if not sp.foe or bot.tick - sp.tick > NadeFoePingTtl:
        continue
      offer(sp.pos, NadeFoePingCost)
    if ShoutMode >= 2:
      # A mate's shout, thrown at. A lob clears every wall between here and
      # there, which is exactly the case a shout describes and the gun cannot
      # answer: somebody else can see a body we have no line on. Priced like a
      # foe ping -- both are second-hand marks on ground rather than a target
      # we are looking at.
      for x in bot.shoutFixes:
        if bot.tick - x.tick > NadeFoePingTtl:
          continue
        offer(x.pos, NadeFoePingCost)
  f.nadeAim = nadeAim
  f.nadeThrowD = nadeThrowD

proc scanNadeDanger*(bot: Bot, client: ProtocolClient, f: var Frame) {.measure.} =
  # Grenade danger: a visible throw-target ring marks where an enemy's lob
  # will land, and an airborne grenade is seconds from bursting — anything
  # inside the blast radius eats 2 of 3 hit points. Fleeing the marked spot
  # outranks every movement goal except nothing: dead carriers drop the run.
  f.nadeDanger = false
  # Our OWN windup draws that ring too: the server previews the landing point
  # of every charging player we can see, and we can always see ourselves. The
  # preview starts at a tap's distance and stretches with the charge, so for
  # the first few ticks of every throw it sits just inside the flee radius and
  # the bot sprints backwards away from its own grenade. Predict where our own
  # ring must be and skip THAT ONE ring; every other ring, and every airborne
  # grenade, still counts.
  #
  # Exactly one ring is ours, so pick the single closest match rather than
  # discarding everything near the prediction. In a mutual grenade duel both
  # previews sit on the line joining the two throwers, so a plain radius test
  # would swallow the enemy's ring along with ours and leave us standing in
  # the blast.
  let ownNadeLanding =
    if bot.nadeCharge > 0:
      f.me + bradsDir(bot.estAim) * (NadeTapRange +
        (NadeMaxRange - NadeTapRange) *
          float(min(bot.nadeCharge, NadeFullChargeTicks)) /
          float(NadeFullChargeTicks))
    else:
      vec(-1e9, -1e9)                    # off-map: matches nothing
  var
    ownRingId = -1
    ownRingD = OwnNadeRingSlack
  if bot.nadeCharge > 0:
    for o in client.objectsOf(lkThrowTarget):
      let d = dist(client.mapPos(o), ownNadeLanding)
      if d < ownRingD:
        ownRingD = d
        ownRingId = o.objectId
  block nadeDangerScan:
    for kind in [lkThrowTarget, lkGrenadeAir]:
      for o in client.objectsOf(kind):
        let p = client.mapPos(o)
        if kind == lkThrowTarget and o.objectId == ownRingId:
          continue                       # our own charge preview
        if dist(p, f.me) <= NadeBlast + 18.0:
          f.nadeDanger = true
          f.nadeDangerFrom = p
          break nadeDangerScan
