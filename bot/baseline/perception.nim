## The read side of the protocol — turning labelled sprite objects into the
## bot's picture of the field.
##
## Everything here takes a `ProtocolClient` frame and hands back map-space
## facts: where we are, which aim bucket the server is drawing us in, who is
## visible and what they carry. Two of these senses reach past the fog — the
## map-wide scoreboard and the heard shot landings — which is why the sonar
## de-jitter machinery lives here too.

import
  std/[math, strutils, tables],
  protocols,
  labelkind,
  labels,
  world,
  geometry,
  tuning

const
  ## Team-indexed label kinds. These used to be built as strings on every
  ## call — `labelSelf(color, side)` concatenates three pieces, and the
  ## policy asks for self, players, badges and both flags several times a
  ## frame — so the lookups allocated before they could even start comparing.
  ## The inner index is the facing: 0 right, 1 left, the order the scans use.
  SelfKinds* = [
    Red: [lkSelfRedRight, lkSelfRedLeft],
    Blue: [lkSelfBlueRight, lkSelfBlueLeft]]
  PlayerKinds* = [
    Red: [lkPlayerRedRight, lkPlayerRedLeft],
    Blue: [lkPlayerBlueRight, lkPlayerBlueLeft]]
  IdentityKinds* = [Red: lkIdentityRed, Blue: lkIdentityBlue]
  FlagKinds* = [Red: lkFlagRed, Blue: lkFlagBlue]
  FlagPlantedKinds* = [Red: lkFlagPlantedRed, Blue: lkFlagPlantedBlue]
  HpKinds* = [lkHp1, lkHp2, lkHp3]   ## indexed by lit-segment count minus one

  # The identity badge's optional tokens, spelled once. Concatenating them per
  # badge per frame allocated three strings for every player on screen.
  TokenShield = " " & LabelTokenShield
  TokenNade = " " & LabelTokenNade
  TokenSpray = " " & LabelWeaponSpray

static:
  # The bar's segment count owns the number of hp kinds; a redesign of the bar
  # that adds a segment has to add one here rather than silently scan for two
  # thirds of it.
  doAssert HpKinds.len == LabelHpBarSegments

proc mapPos*(client: ProtocolClient, o: SpriteObjectInfo): Vec =
  ## Map-space center of a sprite object (the map object sits at the origin,
  ## so the camera offset is zero; keep it for exactness). Since the 0.7.8
  ## renderer restore the wire is back to 1x map pixels (the 0.6-0.7.7 HD
  ## era carried 3x-scaled coordinates), with sprites centered on their map
  ## points.
  vec(
    float(o.x + o.width div 2 + client.mapCameraX),
    float(o.y + o.height div 2 + client.mapCameraY)
  )

proc findSelf*(
    client: ProtocolClient, team: Team): tuple[alive: bool, pos: Vec] =
  ## Our avatar via the distinct self marker, only drawn while we are alive.
  for side in 0 .. 1:
    for o in client.objectsOf(SelfKinds[team][side]):
      return (alive: true, pos: client.mapPos(o))

proc selfAimBucket*(client: ProtocolClient, team: Team): int =
  ## The CENTRE of the aim bucket the server is currently drawing us in. Our
  ## self marker is one of SoldierRots pre-rotated sprites, numbered
  ## SelfSpriteBase + skin * SoldierRots + step, and the server picks the step
  ## by rounding the aim to the nearest one — so the sprite id alone pins the
  ## true aim to within half a bucket of step * SoldierRotBrads. The label is
  ## the same for every step, so this reads the id, not the label. Returns -1
  ## when no self marker is on screen (we are dead, or the frame predates our
  ## spawn).
  result = -1
  for side in 0 .. 1:
    for o in client.objectsOf(SelfKinds[team][side]):
      if o.spriteId < SelfSpriteBase:
        continue                         # not from the pre-rotated self pool
      return floorMod(o.spriteId - SelfSpriteBase, SoldierRots) *
        SoldierRotBrads

proc badgesFor*(
    client: ProtocolClient, team: Team): seq[tuple[pos: Vec, pid: int,
    shield, nade, arc: bool]] =
  ## Every visible identity badge of one team, with the player it names and
  ## what that player is carrying. The badge ships one sprite per player with
  ## a label of the form "identity <team> <name>" followed by the carry
  ## tokens, and sits in an object-id pool indexed by the player's own slot —
  ## so the id is a stable name for that soldier, steady across the whole
  ## match, while the label tells us what they are holding right now. A
  ## weapon token is always present, so the absence of the spray token is a
  ## positive reading of "ordinary gun", not a gap.
  ##
  ## The weapon token is LabelWeaponSpray ("spray"), NOT "arc". The 0.7.x
  ## spray-can reskin (coworld-ctf 3428bd8, 2026-07-28) renamed the wire
  ## token; upstream's internal `hasPlasmaArc` field kept the old name, which
  ## is why the rename is easy to miss reading the sim. This archive forked
  ## before it and went on testing for " arc", so `arc` came back FALSE for
  ## every badge on the map — the spray-can carrier, the one enemy worth
  ## swinging the turret onto first (ArcThreatBonus), was invisible as such.
  for o in client.objectsOf(IdentityKinds[team]):
    if o.objectId < BadgeObjectBase or
        o.objectId >= BadgeObjectBase + BadgeObjectSpan:
      continue
    # The kind already established the `identity <color> ` prefix; only the
    # tail is left to read, and `labelOf` borrows it rather than copying it.
    let label = client.labelOf(o.spriteId)
    result.add((
      pos: vec(float(o.x + o.width div 2 + client.mapCameraX),
               float(o.y + o.height div 2 + client.mapCameraY)),
      pid: o.objectId - BadgeObjectBase,
      shield: TokenShield in label,
      nade: TokenNade in label,
      arc: TokenSpray in label
    ))

proc ringOffset*(firedTick, x1, y1: int): (int, int) {.inline.} =
  ## The exact displacement the server applies to one shot landing before it
  ## sends it to us, recomputed from the three numbers that feed it. Nothing
  ## about it is secret or per-viewer: the same shot is displaced the same way
  ## for everybody, every time, which is what makes it reproducible here.
  var h = 0x9E3779B9'u32 xor 0x5F356495'u32
  h = (h xor uint32(firedTick)) * 0x85EBCA6B'u32
  h = (h xor uint32(x1)) * 0xC2B2AE35'u32
  h = (h xor uint32(y1)) * 0x27D4EB2F'u32
  h = h xor (h shr 15)
  let span = uint32(2 * SonarJitterPx + 1)
  (int(h mod span) - SonarJitterPx, int((h shr 16) mod span) - SonarJitterPx)

proc solveRing*(ox, oy, firedTick: int): seq[(int, int)] =
  ## Every true landing that would have been displaced onto exactly this heard
  ## spot at this tick. The displacement is bounded, so the true landing is
  ## inside a box of that half-width around what we heard; walk the box and
  ## keep whichever entries reproduce the observation. For a wrong tick this
  ## still tends to turn up about one match by chance, so a single answer here
  ## is not yet an answer — the tick has to be right first.
  if firedTick < 0:
    return
  for x1 in ox - SonarJitterPx .. ox + SonarJitterPx:
    for y1 in oy - SonarJitterPx .. oy + SonarJitterPx:
      let (ix, iy) = ringOffset(firedTick, x1, y1)
      if x1 + ix == ox and y1 + iy == oy:
        result.add((x1, y1))

proc ringExplained*(ox, oy, firedTick: int): bool =
  ## Whether ANY true landing would have been displaced onto this heard spot
  ## at this tick — `solveRing(...).len > 0` without building the list.
  ##
  ## The clock calibration below asks exactly that, once per candidate offset,
  ## which is 901 times for every ring it spends. Answering it through
  ## `solveRing` walked the whole 41x41 box every time and allocated a seq to
  ## carry away an answer nobody read. This stops at the first entry that
  ## explains the ring, and about two offsets in three have one.
  if firedTick < 0:
    return false
  for x1 in ox - SonarJitterPx .. ox + SonarJitterPx:
    for y1 in oy - SonarJitterPx .. oy + SonarJitterPx:
      let (ix, iy) = ringOffset(firedTick, x1, y1)
      if x1 + ix == ox and y1 + iy == oy:
        return true
  false

proc readScoreboard*(client: ProtocolClient): tuple[ok: bool, red, blue: int] =
  ## The running kill totals, read off the scoreboard text. The scoreboard is
  ## drawn for everyone with no fog test at all, so this is the one count of
  ## the fighting that is true across the WHOLE map — a kill in a corner we
  ## have never seen still moves it. The label reads "team score RED k/d".
  var got = 0
  for (kind, tag, slot) in [(lkScoreRed, LabelScoreRedPrefix, 0),
                            (lkScoreBlue, LabelScoreBluePrefix, 1)]:
    for o in client.objectsOf(kind):
      let body = client.labelOf(o.spriteId)[tag.len .. ^1]
      let cut = body.find('/')
      if cut <= 0:
        continue
      try:
        let n = body[0 ..< cut].strip().parseInt()
        if slot == 0: result.red = n else: result.blue = n
        inc got
      except ValueError:
        discard
  result.ok = got == 2

proc hearShots*(bot: Bot, client: ProtocolClient) =
  ## Bank every shot landing the server let us hear this frame. These rings
  ## ignore walls and fog completely: any shot that lands anywhere on the map
  ## is reported to every living player, which makes them the only sense we
  ## have that reaches past what we can see. What they do NOT carry is who
  ## fired, which team, or the exact spot — the position is fuzzed by up to
  ## SonarJitterPx px on purpose, so a ring means "a shot landed near here",
  ## never "a body is exactly there".
  ##
  ## A ring persists for several frames while its shot fades, and the ids are
  ## a small recycled pool, so remember where each id sat when we first heard
  ## it and only count a landing again once that id MOVES — which only happens
  ## when the slot has been handed to a genuinely new shot.
  for o in client.objectsOf(lkShotImpact):
    if o.objectId < SonarObjectBase or
        o.objectId >= SonarObjectBase + SonarObjectSpan:
      continue
    let
      ox = o.x + o.width div 2 + client.mapCameraX
      oy = o.y + o.height div 2 + client.mapCameraY
      p = vec(float(ox), float(oy))
    # Identify a landing by WHERE it is, never by which object id carries it.
    # The id is just this shot's index in the server's recent-shot list, and
    # that list is pruned from the front, so a shot slides down through the
    # ids as older ones expire and would otherwise read as a brand new landing
    # several times over — once per slot it passes through. Position is what
    # actually stays put for the life of a shot.
    let key = (ox, oy)
    if key in bot.sonarSeen:
      continue                           # this landing is already counted
    bot.sonarSeen[key] = bot.tick
    var
      pos = p
      exact = false
    if not bot.clockKnown:
      # Work out how far the server's clock sits from ours, which is the one
      # number standing between a heard ring and the spot it came from. A
      # wrong offset explains a given ring about two times in three, purely
      # by chance; the right one explains every ring, because the landing
      # that produced it really is in there. So let every offset that can
      # explain this ring score a point and wait: chance answers drift
      # apart, the true one never misses, and the gap only widens.
      if bot.clockVotes.len == 0:
        bot.clockVotes = newSeq[int](SonarCalMax - SonarCalMin + 1)
      if bot.clockRings < SonarCalRings:
        inc bot.clockRings
        for u in SonarCalMin .. SonarCalMax:
          if ringExplained(ox, oy, bot.tick + u):
            inc bot.clockVotes[u - SonarCalMin]
        # Lock on when exactly one offset has explained EVERY landing so
        # far. The true one can never miss; a chance one survives n rings
        # with probability about 0.63^n, so once enough have gone by, a
        # single unbeaten offset is the real one and not a lucky one.
        var
          perfect = 0
          perfectU = 0
        for i, v in bot.clockVotes:
          if v == bot.clockRings:
            inc perfect
            perfectU = i + SonarCalMin
        if bot.clockRings >= SonarCalMinRings and perfect == 1:
          bot.clockLag = perfectU
          bot.clockKnown = true
    if bot.clockKnown:
      # The tick is settled, so the only question left is which entry of the
      # box produced this ring. A shot keeps being drawn for a bounded run of
      # ticks after it is fired, so try that run and take the answer only
      # when exactly one entry across the whole run can be responsible. Two
      # survivors mean the ring genuinely cannot be told apart, and a guess
      # there is worse than the honest fuzzy reading we started with.
      # One tick, not a window. A shot is traced the instant it is fired,
      # so the tick a landing is first heard on IS the tick it was fired on,
      # and widening the search past that would only pile on coincidences
      # and bury the true answer among them. Accept the reading only when a
      # single entry can be responsible; when two can, the ring honestly
      # does not say which, and the fuzzy spot we already had is better than
      # a coin flip between them.
      let hits = solveRing(ox, oy, bot.tick + bot.clockLag)
      if hits.len == 1:
        pos = vec(float(hits[0][0]), float(hits[0][1]))
        exact = true
    bot.sonar.add(Ping(pos: pos, tick: bot.tick, hot: false, exact: exact))
  var goneKeys: seq[(int, int)]
  for k, t in bot.sonarSeen:
    if bot.tick - t > SonarSeenTtl:
      goneKeys.add(k)
  for k in goneKeys:
    bot.sonarSeen.del(k)
  var kept: seq[Ping]
  for s in bot.sonar:
    if bot.tick - s.tick <= SonarTtl:
      kept.add(s)
  if kept.len > SonarCap:
    kept = kept[kept.len - SonarCap .. ^1]
  bot.sonar = kept

proc actorsFor*(client: ProtocolClient, team: Team): seq[Actor] =
  ## Visible players of one color in map coordinates plus horizontal facing
  ## and hit points. The overhead "hp <n>/<max>" pip bar is fog-culled with
  ## its player, so whenever the player is visible its hp is too. The bar is
  ## not merely NEAR its player, it is centered exactly HpPipOffsetY above the
  ## body center, so match each bar to the body whose anchor point it sits on
  ## — a radius test around the body itself measures exactly HpPipOffsetY and
  ## can never come in under a radius of the same size.
  for side in 0 .. 1:
    for o in client.objectsOf(PlayerKinds[team][side]):
      result.add(Actor(
        pos: client.mapPos(o), facingRight: side == 0, pid: -1))
  # Pin each badge to the soldier standing under it. The badge is centred on
  # the same body the sprite is drawn around, so the true pairing sits within
  # a pixel or two and a tight radius cannot reach a neighbour. Claim each
  # body once: two badges resolving onto one soldier would mean the reading
  # is wrong, and a wrong name is worse than no name.
  var taken = newSeq[bool](result.len)
  for b in client.badgesFor(team):
    var
      best = -1
      bestD = BadgeAnchorSlack
    for i in 0 ..< result.len:
      if taken[i]:
        continue
      let d = dist(result[i].pos, b.pos)
      if d < bestD:
        bestD = d
        best = i
    if best >= 0:
      taken[best] = true
      result[best].pid = b.pid
      result[best].shield = b.shield
      result[best].nade = b.nade
      result[best].arc = b.arc
  # The overhead bar is drawn in LabelHpBarSegments thirds, and labelHp owns
  # the denominator so the scan cannot spell it differently from the engine —
  # an exact-match for "hp 2/3" finds nothing in a world emitting "hp 2/4".
  # The bot still reads a LIT SEGMENT as a hit point below, which is only true
  # while the game's hitPoints equals LabelHpBarSegments (both 3 today). A
  # hitPoints retune would keep this scan correct and make that equation
  # wrong; see LabelHpBarSegments in baseline/labels.nim.
  for hp in 1 .. LabelHpBarSegments:
    for o in client.objectsOf(HpKinds[hp - 1]):
      let p = client.mapPos(o)
      var best = -1
      var bestD = HpPipAnchorSlack
      for i in 0 ..< result.len:
        let anchor = vec(result[i].pos.x, result[i].pos.y - HpPipOffsetY)
        let d = dist(anchor, p)
        if d < bestD:
          bestD = d
          best = i
      if best >= 0:
        result[best].hp = hp
