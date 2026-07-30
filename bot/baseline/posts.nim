## The fixed firing positions on the map: our own overwatch post, and the
## mirrored enemy one.
##
## `scanPost` scores every cover cell on one side of the flag ring and returns
## the best hold/peek pair; `pickPost` claims it for the overwatch seat, and
## `findEnemyPosts` runs the same scan mirrored to name the standing threats —
## the enemy sniper's peek cell and the respawn ground — that every run home
## has to respect.

import
  protocols,
  grid,
  world,
  geometry,
  tuning

proc scanPost*(
    bot: Bot, client: ProtocolClient, eSign, wantY: float
): tuple[hold, peek: Vec, ready: bool] =
  ## Finds one overwatch sniper post for the side whose guns point along
  ## `eSign`: a cover cell hugging the center ring, shielded from the front,
  ## with a sideways peek cell that owns the LONGEST clear firing line — the
  ## map-wide gun makes the lane length the post's value.
  var bestScore = 1e18
  for cy in 0 ..< GridH:
    for cx in 0 ..< GridW:
      let c = cy * GridW + cx
      if not bot.coverCell[c]:
        continue
      let
        p = cellCenter(c)
        fwd = eSign * (p.x - float(CenterX))
      if fwd > -40.0 or fwd < -160.0:
        continue                         # this side of the ring, hugging it
      if rayClearCoarse(client, p, p + vec(eSign * CoverShieldDist, 0.0), 4.0):
        continue                         # nothing shields us from the front
      var
        peek: Vec
        peekLine = 0.0
      for dyc in [-2, 2, -1, 1]:
        let ny = cy + dyc
        if ny < 0 or ny >= GridH or not bot.cellWalkable[ny * GridW + cx]:
          continue
        let q = cellCenter(ny * GridW + cx)
        let line = openLineLen(client, q, vec(eSign, 0.0), FireRange, 6.0)
        if line > peekLine:
          peekLine = line
          peek = q
      if peekLine < PeekLineDist:
        continue
      # The firing-line length dominates; the position terms break near-ties
      # toward the wanted flank height and hugging the flag ring.
      let score = abs(p.y - wantY) + abs(fwd + 90.0) * 0.7 - peekLine * 0.7
      if score < bestScore:
        bestScore = score
        result.hold = p
        result.peek = peek
        result.ready = true

proc pickPost*(bot: Bot, client: ProtocolClient) =
  ## Chooses our own overwatch post (the overwatch seat only): fire from the
  ## peek, duck back to the hold during cooldown.
  bot.postReady = false
  if bot.role != Overwatch:
    return
  let
    eSign = -homeSign(bot.team)
    wantY = float(CenterY) + 60.0
  let post = bot.scanPost(client, eSign, wantY)
  if post.ready:
    bot.postHold = post.hold
    bot.postPeek = post.peek
    bot.postReady = true

proc findEnemyPosts*(bot: Bot, client: ProtocolClient) =
  ## Precomputes the standing virtual threats every carrier run has to
  ## respect, fed into exposure costing and lane choice: the mirrored ENEMY
  ## overwatch post (a stationary, hidden killer), and the ENEMY RESPAWN
  ## GROUND — every kill puts an armed enemy back on the map facing our way,
  ## so that ground is permanently watched even when no track remembers
  ## anybody there.
  ##
  ## GV25 (coworld-ctf 72fd075, 2026-07-29) is why the second one is a ZONE
  ## and no longer a point. Respawns used to land on the pedestal, so
  ## `flagHome(enemy)` named the pocket mouth exactly and the threat was a
  ## genuine chokepoint. They now land at a uniform random walkable spot
  ## anywhere in the team's home capture zone (`randomEndzonePosition`), which
  ## on a sides map is a full-height column at that end of the arena — a fixed
  ## respawn point can no longer be camped, and by the same token can no
  ## longer be predicted. Keeping the single pedestal point would concentrate
  ## avoidance on one square of a column that respawns spread across.
  ##
  ## Sampled rather than swept: the exposure pass costs a ray per candidate
  ## cell per spot, and with ExposureRange at 380px a few samples down the
  ## column already union into its whole reachable frontage. The samples sit
  ## at the pedestal's x, which is the column edge NEAREST us — the outer part
  ## of the zone is deeper still, so this errs toward treating respawns as
  ## closer than average rather than further.
  bot.enemyPosts.setLen(0)
  bot.enemyRespawnSpots.setLen(0)
  let post = bot.scanPost(client, homeSign(bot.team), float(CenterY) + 60.0)
  if post.ready:
    bot.enemyPosts.add(post.peek)
  let zoneX = flagHome(enemy(bot.team)).x
  for i in 1 .. EnemyRespawnSamples:
    bot.enemyRespawnSpots.add(
      vec(zoneX, float(MapH) * float(i) / float(EnemyRespawnSamples + 1)))
