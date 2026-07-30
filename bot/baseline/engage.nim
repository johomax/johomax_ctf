## Target selection: which remembered enemy is worth the turret.
##
## `selectEngagement` prices every fresh track in distance PLUS the traverse the
## swing costs, discounts the ones that are cheap to finish or expensive to
## leave alive, and keeps the best one. The errand caps the reach first — a
## carrier, a rusher or an escort only fights what is actually in the way — and
## a track behind a wall is remembered separately as the peek candidate. The
## last scan is cheaper still: the nearest enemy worth ducking from.

import
  protocols,
  frame,
  grid,
  tactics,
  world,
  geometry,
  tuning

proc selectEngagement*(bot: Bot, client: ProtocolClient, f: var Frame) =
  # The mid trio plays for the flag, not for position: pickup races and
  # carrier chases are lost to peek/duck detours, so mids keep moving and
  # shoot on the move whenever a mate is not already carrying.
  f.rushing = not f.iCarry and not f.mateCarry and
    bot.role in {MidTop, MidBottom, MidGuard}
  # The pocket endgame: duelling at the pocket edge is an infinite respawn
  # grinder (respawners reappear armed AT the pedestal), so the
  # attacker CLOSEST to the pedestal commits to the touch, unarmed and
  # undistracted, while the rest of the wave keeps its guns up to cover the
  # grab — even a suicide grab forces the enemy back onto defense, and a
  # lucky one starts the capture run.
  var nearestMateToSteal = 1e18
  for t in bot.mates:
    if bot.tick - t.lastSeen > 48:
      continue
    nearestMateToSteal = min(nearestMateToSteal, dist(t.pos, f.stealTarget))
  f.pocketRush = not f.iCarry and not f.mateCarry and
    bot.role in {MidTop, MidBottom, MidGuard, FlankTop, FlankBottom} and
    dist(f.me, f.stealTarget) < PocketRushRange and
    dist(f.me, f.stealTarget) < nearestMateToSteal + 8.0

  # Combat: the nearest fresh track with a clear pixel ray AND a mate-free
  # fire cone is the engage target; the nearest fresh-but-wall-blocked track
  # is the peek candidate. The map-wide gun engages fresh tracks far beyond
  # the view, so chases keep killing after the target leaves the window —
  # but objective play caps the range: the carrier only fights point-blank,
  # rushers racing for the steal and escorts guarding a run only fight what
  # is actually in the way, instead of frag-chasing across the map.
  f.maxEngage =
    if f.hasShield and not f.hasPlasma:       # slow gun (3x cooldown): only fight
      CarrierFireRange                        # what is point-blank in the way
    elif f.hasPlasma: PlasmaReach + 6.0       # cone weapon: only close range matters
    elif f.pocketRush: 0.0
    elif f.iCarry: CarrierFireRange
    elif f.ownStolen and bot.tick - bot.carrierSeen <= ThiefFixTtl: FireRange
      # A live fix on the enemy running our flag lifts every role's range
      # cap: the map-wide gun is the fastest flag return there is.
    elif f.rushing: RushEngageRange
    elif f.mateCarry: EscortEngageRange
    else: FireRange
  # (Focus-fire intel used to be computed here, off the mates' rendered aim
  # dots. The engine retired that sprite family in 2026-07-16 and GV24 fuzzed
  # the replacement, so there is no longer any readback of where a mate is
  # about to shoot. See the note by TraversePxPerBrad.)
  f.engage = -1
  f.engageD = f.maxEngage
  f.engagePrio = f.maxEngage
  f.haveBlocked = false
  f.blockedD = f.maxEngage
  for i in 0 ..< bot.enemies.len:
    let t = bot.enemies[i]
    if bot.tick - t.lastSeen > FreshShotTicks:
      continue
    let predicted = t.pos + t.vel * (float(bot.tick - t.lastSeen) + LeadTicks)
    let d = dist(predicted, f.me)
    if d >= f.maxEngage:
      continue
    # Target priority: distance plus the turret swing needed to lay on the
    # target (the traverse is slow, so a target near the current aim line
    # dies sooner than a nearer one behind us), discounted for wounded
    # targets (a 1-hp enemy dies to one shot — finish it before it resets on
    # respawn) and for targets a visible mate is already lined up on (focus
    # fire). The discounts are tiebreaks between comparably-engageable
    # targets, deliberately smaller than a real positional difference.
    var prio = d +
      float(abs(bradsErr(bradsOf(predicted - f.me), bot.estAim))) * TraversePxPerBrad
    if t.hp in 1 ..< MaxHp:
      prio -= float(MaxHp - t.hp) * HpFocusBonus
    # What the target is holding changes what it costs us to leave alive and
    # what it costs to kill. A spray can out-ranges and out-damages our gun,
    # so the arc carrier is the one that decides the fight and is worth
    # swinging onto first. A shield soaks a shot before any of them count,
    # so an unshielded enemy beside a shielded one dies sooner for the same
    # effort. Both stay smaller than a real difference in position, like the
    # discounts above — this orders comparable targets, it does not drag us
    # across the map.
    if t.arc:
      prio -= ArcThreatBonus
    if t.shield:
      prio += ShieldCostPenalty
    if f.ownStolen and bot.tick - bot.carrierSeen <= ThiefFixTtl and
        dist(t.pos, bot.carrierPos) <= 48.0:
      # This track IS (or shadows) the enemy running our flag: shoot it
      # before anything else — a dead carrier returns the flag instantly.
      prio -= ThiefFocusBonus
    if client.pixelRayClear(f.me, predicted):
      if bot.friendlyBlocked(f.me, predicted, d):
        continue                        # prefer a target with an empty corridor
      if f.engage < 0 or prio < f.engagePrio:
        f.engagePrio = prio
        f.engageD = d
        f.engage = i
        f.aim = predicted
    elif d < f.blockedD:
      f.blockedD = d
      f.blockedAim = predicted
      f.haveBlocked = true

  # The nearest remembered enemy that could be threatening us right now,
  # used to pick which line to break when ducking through cooldown.
  f.nearThreat = -1
  f.nearThreatD = DuckRange
  for i in 0 ..< bot.enemies.len:
    if bot.tick - bot.enemies[i].lastSeen > 30:
      continue
    let d = dist(bot.enemies[i].pos, f.me)
    if d < f.nearThreatD:
      f.nearThreatD = d
      f.nearThreat = i
