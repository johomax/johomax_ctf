## The read side of the protocol — turning labelled sprite objects into the
## bot's picture of the field.
##
## Everything here takes a `ProtocolClient` frame and hands back map-space
## facts: where we are, which aim bucket the server is drawing us in, who is
## visible and what they carry. Two of these senses reach past the fog — the
## map-wide scoreboard and the heard shot landings — which is why the sonar
## de-jitter machinery lives here too.
##
## Two more reach past it in a different way: `readGameTeams` and
## `readEndzones` read the invisible init markers the engine states the
## episode's SHAPE with — how many teams share the arena, and where each
## one's capture zone is. They are read once, at nav-grid build, and are
## the whole of what the multi-team strategy frame is anchored on.

import
  bitworld/profile,
  std/[math, strutils, tables],
  protocols,
  labelkind,
  labels,
  world,
  geometry,
  tuning

const
  ## Colour-indexed label kinds. These used to be built as strings on every
  ## call — `labelSelf(color, side)` concatenates three pieces, and the
  ## policy asks for self, players, badges and both flags several times a
  ## frame — so the lookups allocated before they could even start comparing.
  ## The inner index is the facing: 0 right, 1 left, the order the scans use.
  ##
  ## Indexed by `Colour`, not by `Team`: these are wire lookups, and the wire
  ## has four colours. A table with two rows is what made green and yellow
  ## seats unable to find themselves.
  SelfKinds* = [
    cRed: [lkSelfRedRight, lkSelfRedLeft],
    cBlue: [lkSelfBlueRight, lkSelfBlueLeft],
    cGreen: [lkSelfGreenRight, lkSelfGreenLeft],
    cYellow: [lkSelfYellowRight, lkSelfYellowLeft]]
  PlayerKinds* = [
    cRed: [lkPlayerRedRight, lkPlayerRedLeft],
    cBlue: [lkPlayerBlueRight, lkPlayerBlueLeft],
    cGreen: [lkPlayerGreenRight, lkPlayerGreenLeft],
    cYellow: [lkPlayerYellowRight, lkPlayerYellowLeft]]
  IdentityKinds* = [
    cRed: lkIdentityRed, cBlue: lkIdentityBlue,
    cGreen: lkIdentityGreen, cYellow: lkIdentityYellow]
  FlagKinds* = [
    cRed: lkFlagRed, cBlue: lkFlagBlue,
    cGreen: lkFlagGreen, cYellow: lkFlagYellow]
  FlagPlantedKinds* = [
    cRed: lkFlagPlantedRed, cBlue: lkFlagPlantedBlue,
    cGreen: lkFlagPlantedGreen, cYellow: lkFlagPlantedYellow]
  ScoreKinds* = [
    cRed: lkScoreRed, cBlue: lkScoreBlue,
    cGreen: lkScoreGreen, cYellow: lkScoreYellow]
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
    client: ProtocolClient, colour: Colour): tuple[alive: bool, pos: Vec] {.measure.} =
  ## Our avatar via the distinct self marker, only drawn while we are alive.
  for side in 0 .. 1:
    for o in client.objectsOf(SelfKinds[colour][side]):
      return (alive: true, pos: client.mapPos(o))

proc selfAimBucket*(client: ProtocolClient, colour: Colour): int =
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
    for o in client.objectsOf(SelfKinds[colour][side]):
      if o.spriteId < SelfSpriteBase:
        continue                         # not from the pre-rotated self pool
      return floorMod(o.spriteId - SelfSpriteBase, SoldierRots) *
        SoldierRotBrads

proc badgesFor*(
    client: ProtocolClient, colour: Colour): seq[tuple[pos: Vec, pid: int,
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
  for o in client.objectsOf(IdentityKinds[colour]):
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

iterator ringSolutions(ox, oy, firedTick: int): (int, int) =
  ## Every true landing that would have been displaced onto exactly this heard
  ## spot at this tick. The displacement is bounded, so the true landing is
  ## inside a box of that half-width around what we heard; walk the box and
  ## yield whichever entries reproduce the observation. For a wrong tick this
  ## still tends to turn up about one match by chance, so a single answer here
  ## is not yet an answer — the tick has to be right first.
  ##
  ## The box and the negative-tick guard live here once. Both callers below
  ## are the same search and differ only in what they do with a hit, and two
  ## copies of a bound is how one of them ends up searching a different box.
  if firedTick >= 0:
    for x1 in ox - SonarJitterPx .. ox + SonarJitterPx:
      for y1 in oy - SonarJitterPx .. oy + SonarJitterPx:
        let (ix, iy) = ringOffset(firedTick, x1, y1)
        if x1 + ix == ox and y1 + iy == oy:
          yield (x1, y1)

proc solveRing*(ox, oy, firedTick: int): seq[(int, int)] =
  ## Every landing that could be responsible for this ring, as a list — for
  ## the caller that has to know whether there is exactly ONE of them.
  for hit in ringSolutions(ox, oy, firedTick):
    result.add(hit)

proc ringExplained*(ox, oy, firedTick: int): bool =
  ## Whether ANY landing could be responsible — `solveRing(...).len > 0`
  ## without building the list.
  ##
  ## The clock calibration below asks exactly that and never looks at the
  ## entries, so it stops at the first one; about two offsets in three have
  ## one, and the walk that finds nothing is the same walk either way.
  for _ in ringSolutions(ox, oy, firedTick):
    return true
  false

proc readScoreboard*(
    client: ProtocolClient): tuple[ok: bool, kills: array[Colour, int]] =
  ## The running kill totals, read off the scoreboard text. The scoreboard is
  ## drawn for everyone with no fog test at all, so this is the one count of
  ## the fighting that is true across the WHOLE map — a kill in a corner we
  ## have never seen still moves it. The label reads "team score RED k/d",
  ## one chip per ACTIVE team.
  ##
  ## `ok` demands every active team's chip, not two: a partial read would
  ## hand `updateSenses` a delta for teams it could see and a frozen count
  ## for the rest, which is a kill attributed to the wrong side rather than a
  ## kill missed.
  var got = 0
  for colour in activeColours():
    let tag = LabelScorePrefixes[colour]
    for o in client.objectsOf(ScoreKinds[colour]):
      let body = client.labelOf(o.spriteId)[tag.len .. ^1]
      let cut = body.find('/')
      if cut <= 0:
        continue
      try:
        result.kills[colour] = body[0 ..< cut].strip().parseInt()
        inc got
      except ValueError:
        discard
  result.ok = got == GameTeams

proc readGameTeams*(client: ProtocolClient): int =
  ## How many teams share this arena, from the init marker
  ## `game teams <count> map <width>x<height>` (labels.nim,
  ## LabelPrefixGameParams), or 0 when no marker states it.
  ##
  ## Only the count is read. The map size the same marker carries is the
  ## walkability sprite's own dimensions, which `adoptMapSize` has already
  ## taken from the sprite itself — a second source for a number we hold
  ## exactly is a second thing that can disagree.
  for o in client.objectsOf(lkGameParams):
    let parts = client.labelOf(o.spriteId)[
      LabelPrefixGameParams.len .. ^1].split(' ')
    if parts.len != 3:
      continue
    try:
      return clamp(parts[0].parseInt(), 2, 4)
    except ValueError:
      discard
  0

proc readEndzones*(bot: Bot, client: ProtocolClient) =
  ## Reads every team's stated home capture region off the per-team init
  ## markers `endzone <color> <shape> <x0>,<y0> <x1>,<y1>` (labels.nim,
  ## LabelPrefixEndzone) into `bot.endzones`.
  ##
  ## The shape token is validated against labels.nim's CLOSED vocabulary
  ## before any corner is parsed, which is also what keeps the spectator glow
  ## overlays out: those are `endzone <color> power <n> band <n>`, share the
  ## prefix exactly, and would otherwise parse `power`'s tail as a bounding
  ## box. They reach no player stream today — the guard is here so that stays
  ## a fact about the engine rather than a thing this depends on.
  bot.endzones.setLen(0)
  for o in client.objectsOf(lkEndzone):
    let parts = client.labelOf(o.spriteId)[LabelPrefixEndzone.len .. ^1].split(' ')
    if parts.len != 4 or parts[1] notin LabelEndzoneShapes:
      continue
    var colour = cRed
    var known = false
    for c in Colour:
      if ColourNames[c] == parts[0]:
        colour = c
        known = true
        break
    if not known:
      continue
    let
      lo = parts[2].split(',')
      hi = parts[3].split(',')
    if lo.len != 2 or hi.len != 2:
      continue
    try:
      bot.endzones.add(EndzoneMark(
        colour: colour,
        centre: vec(
          float(lo[0].parseInt() + hi[0].parseInt()) * 0.5,
          float(lo[1].parseInt() + hi[1].parseInt()) * 0.5)))
    except ValueError:
      discard

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
      # Seed the candidates on the FIRST ring only. An empty list means two
      # different things and this tells them apart: before any ring, nothing
      # has been asked yet and every offset is still open; after one, every
      # offset has been eliminated. The second is reachable — a ring the true
      # offset cannot explain would do it — and it must stay empty, because
      # re-seeding there would hand a beaten offset a clean record and let it
      # win. As before this change, an emptied field simply never locks, and
      # the fuzzy reading stands.
      if bot.clockCands.len == 0 and bot.clockRings == 0:
        for u in SonarCalMin .. SonarCalMax:
          bot.clockCands.add(int32(u))
      if bot.clockRings < SonarCalRings:
        inc bot.clockRings
        # Only offsets that have explained every landing so far are still in
        # the running, so only those are worth asking about the next one:
        # keep the survivors and drop the rest, rather than re-testing all
        # 901 candidates against every ring and counting votes that can no
        # longer reach the total. The list falls off by about a third per
        # ring, so the whole calibration now costs roughly what its FIRST
        # ring used to. Nothing observable changes -- a beaten offset's vote
        # count was only ever compared against the ring count it could no
        # longer match.
        var kept = 0
        for i in 0 ..< bot.clockCands.len:
          let u = bot.clockCands[i]
          if ringExplained(ox, oy, bot.tick + int(u)):
            bot.clockCands[kept] = u
            inc kept
        bot.clockCands.setLen(kept)
        # Lock on when exactly one offset has explained EVERY landing so
        # far. The true one can never miss; a chance one survives n rings
        # with probability about 0.63^n, so once enough have gone by, a
        # single unbeaten offset is the real one and not a lucky one.
        if bot.clockRings >= SonarCalMinRings and bot.clockCands.len == 1:
          bot.clockLag = int(bot.clockCands[0])
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

const
  ShoutKinds* = [
    cRed: lkShoutRed, cBlue: lkShoutBlue,
    cGreen: lkShoutGreen, cYellow: lkShoutYellow]
  ShoutTagEnemy = 'E'          ## an enemy fix
  ShoutTagKill = 'K'           ## a body dropped in this cell

proc shoutForEnemy*(p: Vec): string =
  ## The message naming an enemy at `p`: `E<gx>,<gy>` in ShoutCellPx cells.
  ##
  ## Ten characters is the whole budget (the engine truncates past
  ## ShoutMaxChars), which is why this is a CELL and not a pixel: two
  ## coordinates at full precision do not fit, and a 32px cell is inside the
  ## distance a body covers in the second the message takes to arrive anyway.
  ShoutTagEnemy & $(int(p.x) div ShoutCellPx) & "," &
    $(int(p.y) div ShoutCellPx)

proc shoutForKill*(p: Vec): string =
  ## `K<gx>,<gy>` — a body dropped in this cell. Same grid as the enemy fix,
  ## so a listener that can read one can read the other.
  ShoutTagKill & $(int(p.x) div ShoutCellPx) & "," &
    $(int(p.y) div ShoutCellPx)

proc decodeShout(text: string, tag: char): (bool, Vec) =
  ## The inverse: a cell name back to the centre of that cell.
  if text.len < 4 or text[0] != tag:
    return (false, vec(0.0, 0.0))
  let comma = text.find(',')
  if comma < 2 or comma == text.len - 1:
    return (false, vec(0.0, 0.0))
  var gx, gy: int
  try:
    gx = text[1 ..< comma].parseInt()
    gy = text[comma + 1 .. ^1].parseInt()
  except ValueError:
    return (false, vec(0.0, 0.0))
  if gx < 0 or gy < 0 or gx * ShoutCellPx >= MapW or gy * ShoutCellPx >= MapH:
    return (false, vec(0.0, 0.0))
  (true, vec(float(gx * ShoutCellPx + ShoutCellPx div 2),
             float(gy * ShoutCellPx + ShoutCellPx div 2)))

proc hearShouts*(bot: Bot, client: ProtocolClient) =
  ## Rebuild the heard-fix list from this frame's own-team speech bubbles.
  ##
  ## Only the TEXT is read. The bubble's position is jittered exactly like a
  ## shot ring (the engine salts it per shout so a listener learns the
  ## neighbourhood a shout came from, never the exact spot), and the payload
  ## is a cell the speaker chose deliberately — so the label carries strictly
  ## better information than the sprite it is attached to.
  ##
  ## Rebuilt, not accumulated: a bubble is re-sent every frame for the three
  ## seconds it lives, so what the frame carries is what is still live.
  bot.shoutFixes.setLen(0)
  if ShoutHearFoe != 0:
    # Eavesdropping, and it does not need their vocabulary. A hostile bubble
    # is drawn hanging on the enemy who made it, so its ANCHOR is that enemy —
    # jittered by the same +-20px the engine fuzzes a shot ring by, and
    # delivered through walls and fog like one. The words are theirs; the
    # position is ours to read. The anchor is not `mapPos`, which returns the
    # bubble's centre: the object is placed at (anchorX - w div 2,
    # tailTipY - h) with tailTipY the speaker's y plus jitter minus the float.
    # Every hostile colour, not one: on a free-for-all board a bubble from
    # the third team hangs on a body that will shoot at us exactly like the
    # raid target's does.
    for foe in bot.foes:
      for o in client.objectsOf(ShoutKinds[foe]):
        let p = vec(float(o.x + o.width div 2 + client.mapCameraX),
                    float(o.y + o.height + ShoutFloatPx + client.mapCameraY))
        var merged = false
        for f in bot.shoutFixes.mitems:
          if dist(f.pos, p) < ShoutMergeDist:
            merged = true
            break
        if not merged:
          bot.shoutFixes.add(Fix(pos: p, tick: bot.tick))
  if ShoutMode <= 0:
    return
  for o in client.objectsOf(ShoutKinds[bot.colour]):
    let label = client.labelOf(o.spriteId)
    let cut = label.rfind(": ")          # the tail is player-authored text
    if cut < 0:
      continue
    let text = label[cut + 2 .. ^1]
    if text == bot.lastShoutText and bot.tick - bot.lastShoutTick <= ShoutTtl:
      continue                           # our own bubble, heard at zero range
    when ShoutKillHere >= 1:
      # `K<gx>,<gy>` read James's way: the tag says a kill happened, the
      # payload is where the SHOUTER is standing. Mutually exclusive with the
      # ShoutKillCalls reading of the same tag -- both are rungs on one word
      # and only one may be on.
      let (hereOk, herePos) = decodeShout(text, ShoutTagKill)
      if hereOk:
        var known = false
        for f in bot.mateFixes.mitems:
          if dist(f.pos, herePos) < ShoutMergeDist:
            known = true
            break
        if not known:
          bot.mateFixes.add(Fix(pos: herePos, tick: bot.tick))
        continue
    when ShoutKillCalls >= 1:
      # A mate saw a body drop. Drop our own track for it, at the radius the
      # local scoreboard-plus-ring inference already uses -- the same clean-up
      # `corpse-track-cleanup` promoted on, but sourced from a seat that saw
      # it rather than from a delta this seat had to attribute. A dead body's
      # stale track is a grenade target for six seconds otherwise.
      let (killOk, killAt) = decodeShout(text, ShoutTagKill)
      if killOk:
        var i = 0
        while i < bot.enemies.len:
          if dist(bot.enemies[i].pos, killAt) < CorpseClearRadius:
            bot.enemies[i] = bot.enemies[^1]
            bot.enemies.setLen(bot.enemies.len - 1)
          else:
            inc i
        continue                         # a kill call is not a live fix
    let (ok, p) = decodeShout(text, ShoutTagEnemy)
    if not ok:
      continue
    var merged = false
    for f in bot.shoutFixes.mitems:
      if dist(f.pos, p) < ShoutMergeDist:
        merged = true
        break
    if merged:
      continue
    bot.shoutFixes.add(Fix(pos: p, tick: bot.tick))
    if bot.shoutFixes.len >= ShoutCap:
      break

proc speakShout*(bot: Bot, seen: seq[Actor], me: Vec) =
  ## Broadcast the nearest enemy we can see right now, once a second.
  ##
  ## What we can see is what a mate cannot: the cone is ours alone, and a
  ## sighting is worth more to the seat that has no line on it than to us.
  ## Nothing else is worth ten characters — our own position is already
  ## implied by the bubble the shout hangs on.
  if ShoutMode <= 0:
    return
  when ShoutKillHere >= 1:
    # Fired on a kill, carrying where WE are. Rare by construction, and it
    # spends a slot the fix cadence skips (the engine accepts one shout every
    # ShoutKillEveryTicks and the fixes only use every other one).
    if bot.tick - bot.lastShoutTick >= ShoutKillEveryTicks and
        bot.tick - bot.pendingKillTick <= ShoutKillTtl:
      bot.pendingShout = shoutForKill(me)
      bot.lastShoutText = bot.pendingShout
      bot.lastShoutTick = bot.tick
      bot.pendingKillTick = -100_000
      return
  when ShoutKillCalls >= 1:
    # Two ways to pay for a second word, and which one is being used is the
    # whole difference between the two rungs.
    #
    #   1  the kill call PREEMPTS the fix for this slot. Written when airtime
    #      looked like the scarcest thing in the channel, because
    #      ShoutEveryTicks 24 -> 48 had just measured +0.1454.
    #   2  the kill call gets its OWN slot. The engine accepts one shout per
    #      ShoutCooldownTicks (24) and the fix cadence is 48, so every other
    #      slot goes unused: a call sent there spends airtime the tree is
    #      currently throwing away rather than airtime a sighting wanted.
    #
    # The audit is why rung 2 exists. That +0.1454 fell to +0.0114 -- level --
    # once the opponent's ability to read our bubbles was switched off on both
    # sides, so the premise rung 1 was priced against is mostly gone. Rung 1
    # measured level; if rung 2 also measures level, the explanation is not
    # airtime but redundancy -- `corpse-track-cleanup` (+0.096) already infers
    # the same deaths from the scoreboard delta and a map-wide landing ring,
    # and the call is telling seven seats something they had worked out.
    # These two rungs are what tells those apart.
    let killReady =
      when ShoutKillCalls >= 2: ShoutKillEveryTicks
      else: ShoutEveryTicks
    if bot.tick - bot.lastShoutTick >= killReady and
        bot.tick - bot.pendingKillTick <= ShoutKillTtl:
      bot.pendingShout = shoutForKill(bot.pendingKill)
      bot.lastShoutText = bot.pendingShout
      bot.lastShoutTick = bot.tick
      bot.pendingKillTick = -100_000
      when ShoutKillCalls < 2:
        bot.lastFixTick = bot.tick       # rung 1: the fix's slot was spent
      return
  if bot.tick - bot.lastFixTick < ShoutEveryTicks:
    return
  if bot.tick - bot.lastShoutTick < ShoutKillEveryTicks:
    return                               # the server would refuse it anyway
  if seen.len == 0:
    return
  var
    best = ShoutSeeDist
    at = -1
  for i in 0 ..< seen.len:
    let d = dist(seen[i].pos, me)
    if d < best:
      best = d
      at = i
  if at < 0:
    return
  bot.pendingShout = shoutForEnemy(seen[at].pos)
  bot.lastShoutText = bot.pendingShout
  bot.lastShoutTick = bot.tick
  bot.lastFixTick = bot.tick

proc actorsFor*(client: ProtocolClient, colour: Colour): seq[Actor] {.measure.} =
  ## Visible players of one color in map coordinates plus horizontal facing
  ## and hit points. The overhead "hp <n>/<max>" pip bar is fog-culled with
  ## its player, so whenever the player is visible its hp is too. The bar is
  ## not merely NEAR its player, it is centered exactly HpPipOffsetY above the
  ## body center, so match each bar to the body whose anchor point it sits on
  ## — a radius test around the body itself measures exactly HpPipOffsetY and
  ## can never come in under a radius of the same size.
  for side in 0 .. 1:
    for o in client.objectsOf(PlayerKinds[colour][side]):
      result.add(Actor(
        pos: client.mapPos(o), facingRight: side == 0, pid: -1))
  # Pin each badge to the soldier standing under it. The badge is centred on
  # the same body the sprite is drawn around, so the true pairing sits within
  # a pixel or two and a tight radius cannot reach a neighbour. Claim each
  # body once: two badges resolving onto one soldier would mean the reading
  # is wrong, and a wrong name is worse than no name.
  var taken = newSeq[bool](result.len)
  for b in client.badgesFor(colour):
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
