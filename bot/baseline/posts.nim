## The fixed firing positions on the map: our own overwatch post, and the
## mirrored enemy one.
##
## `scanPost` scores every cover cell on one side of the flag ring and returns
## the best hold/peek pair; `pickPost` claims it for the overwatch seat, and
## `findEnemyPosts` runs the same scan mirrored to name the standing threats —
## the enemy sniper's peek cell and the respawn ground — that every run home
## has to respect.

import
  std/tables,
  protocols,
  fov,
  grid,
  world,
  geometry,
  tuning

## --- the one-way term -------------------------------------------------------
##
## The engine's quantized shadowcast is not reciprocal (fov.nim): some cell
## pairs are one-way visible, and a post whose peek holds the seeing end of
## such a pair over an enemy lane gets shots the victim can never answer with
## vision. While OneWayBonus is nonzero, scanPost credits each candidate's
## peek for every enemy-side target cell it can see that can never see it
## back and that a bullet reaches. Everything below runs only inside the
## nav-grid build, only while the knob is nonzero, and only on the map whose
## fog geometry fov.nim vendors; shadowcasts are computed for exactly the
## peek and target cells actually scored and cached by cell index.

const
  OneWayBandNear = 40.0        # the target band starts this far past mid —
                              # the enemy side of the flag ring, mirroring
                              # where scanPost's own candidates stand
  OneWayBandDeep = 320.0       # ...and stops this far past it. Measured on
                              # the arena, every one-way pair with a clear
                              # bullet ray from a candidate peek has its
                              # target inside this band: the pairs are
                              # diagonal mid-range lines threading the
                              # center, not map-length lane shots (those
                              # are reciprocal, or run through glass that
                              # blocks the bullet)

type
  OneWayScan* = object
    ## The per-scan working set: the occlusion grid, the spinning-diamond
    ## sweep, the enemy-lane target cells, and the shadowcast cache.
    ready*: bool
    blocked: seq[bool]
    spins: seq[SpinDiamond]
    targets: seq[int]
    casts: Table[int, seq[bool]]

proc newOneWayScan*(bot: Bot, client: ProtocolClient, eSign: float): OneWayScan =
  ## Builds the working set for one scanPost direction. Targets are every
  ## standable cell in the enemy APPROACH BAND — the ground the enemy has to
  ## cross toward the contest, on the side the guns point into (~1.6k cells
  ## on the arena). The set is deliberately dense: a one-way cell is an 8px
  ## quantization artifact and a sparser lattice misses most of them. Only
  ## the few targets a candidate peek actually sees ever pay a reverse
  ## shadowcast (ensureCast is lazy), so density costs lookups, not casts.
  result.ready = true
  result.blocked = buildFovBlocked(client)
  result.spins = spinDiamonds()
  for c in 0 ..< GridW * GridH:
    if not bot.cellWalkable[c]:
      continue
    let fwd = eSign * (cellCenter(c).x - float(CenterX))
    if fwd >= OneWayBandNear and fwd <= OneWayBandDeep:
      result.targets.add c

proc ensureCast(scan: var OneWayScan, cell: int) =
  ## The shadowcast from one cell, computed once and cached by cell index.
  if cell notin scan.casts:
    var vis = newSeq[bool](GridW * GridH)
    shadowcastFrom(scan.blocked, cell mod GridW, cell div GridW, vis)
    scan.casts[cell] = vis

proc oneWayCount*(
    scan: var OneWayScan, client: ProtocolClient, postCell: int, post: Vec
): int =
  ## How many targets the peek cell sees one-way with a live firing line:
  ## the peek's cast reaches the target, no spinning diamond ever sweeps
  ## near the sightline (else it is wrong for part of every rotation), the
  ## target's own cast can never reach back, and the bullet ray is clear.
  scan.ensureCast(postCell)
  for t in scan.targets:
    if not scan.casts[postCell][t]:
      continue
    let tc = cellCenter(t)
    if crossesSpinSweep(scan.spins, post, tc):
      continue
    scan.ensureCast(t)
    if scan.casts[t][postCell]:
      continue
    if not client.pixelRayClear(post, tc):
      continue
    inc result

proc scanPost*(
    bot: Bot, client: ProtocolClient, eSign, wantY: float
): tuple[hold, peek: Vec, ready: bool] =
  ## Finds one overwatch sniper post for the side whose guns point along
  ## `eSign`: a cover cell hugging the center ring, shielded from the front,
  ## with a sideways peek cell that owns the LONGEST clear firing line — the
  ## map-wide gun makes the lane length the post's value.
  var
    bestScore = 1e18
    oneWay: OneWayScan                   # built on the first scored candidate
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
        peekCell = -1
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
          peekCell = ny * GridW + cx
      if peekLine < PeekLineDist:
        continue
      # The firing-line length dominates; the position terms break near-ties
      # toward the wanted flank height and hugging the flag ring.
      var score = abs(p.y - wantY) + abs(fwd + 90.0) * 0.7 - peekLine * 0.7
      if OneWayBonus != 0.0 and oneWayFogReady():
        if not oneWay.ready:
          oneWay = bot.newOneWayScan(client, eSign)
        score -= float(oneWay.oneWayCount(client, peekCell, peek)) * OneWayBonus
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
