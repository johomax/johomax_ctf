## The bot's own copy of the engine's fog-of-war occlusion model, rebuilt
## from the walkability sprite so post scoring can ask which cell pairs the
## fog makes ONE-WAY visible.
##
## The engine fogs entities on an 8px cell grid: `buildFovBlocked` downsamples
## the pixel wall mask (a cell is opaque when at least half its pixels are
## wall), and `computeFovVisible` runs a recursive shadowcast from the
## viewer's cell over all eight octants, then intersects with the aim cone
## and the vision bubble (src/ctf/sim.nim at the pinned engine commit). The
## quantized shadowcast is NOT reciprocal: for some standable cell pairs A
## sees B while B can never see A whatever it aims, and a post on the seeing
## end of such a pair over an enemy lane gets shots the victim cannot answer
## with vision. Both procs below are ports of the engine's, cell for cell:
## the engine's fog grid (FovCellSize = 8) is the bot's nav lattice
## (NavCell = 8), so the grid here shares GridW/GridH indexing with
## `bot.cellWalkable`.
##
## `shadowcastFrom` deliberately stops before the engine's cone/bubble
## intersection: both only REMOVE cells from the cast and the aim is free to
## turn (unlimited cone range), so the raw cast is exactly "visible under
## some aim" and its complement "never visible, whatever the aim" — which is
## the pair of questions the one-way term asks.
##
## Three deliberate departures from a naive `not walkable` occlusion build,
## all engine facts:
##
## - **Glass windows** stay in the wall mask (they block movement and
##   bullets, so they block `pixelRayClear`) but are exempt from fog
##   occlusion — shadowcasting sees straight through them. Which pixels are
##   glass is not on the wire, so the authored arena's window shapes are
##   vendored below from the engine's obstacle table.
## - **The spinning center diamonds** are live geometry: the walkability
##   bake leaves them out and the sim stamps the rotated footprint into the
##   masks as the spin frame advances, so the snapshot the bot received
##   holds ONE frame of a shape that keeps turning. Their pixels are ERASED
##   from the occlusion build (any stamped pixel lies inside the L2 disc of
##   the diamond's radius). On the resulting diamond-free grid a "B can
##   never see A" verdict holds at every spin frame — live stone only ever
##   removes visibility — while "A sees B" holds only if the sightline keeps
##   clear of every disc a turning diamond sweeps, which is what
##   `crossesSpinSweep` tests.
## - Both vendored shape sets are keyed to the default arena's exact
##   dimensions (the map the league runs). On any other map `oneWayFogReady`
##   is false and callers must keep the one-way term off: a table computed
##   with the wrong window/diamond geometry is wrong in the dangerous
##   direction, claiming safety the engine does not grant.
##
## Bottom-layered like grid.nim, and allocation-light on purpose: everything
## here runs only at nav-grid build, and only while OneWayBonus is nonzero.

import
  protocols,
  geometry,
  tuning

type
  SpinDiamond* = object        # one spinning center diamond: center + radius
    cx*, cy*, r*: int

const
  ArenaW = 1235                # the default arena, the map the league runs;
  ArenaH = 659                 # both vendored shape sets are exact for it
  SpinSweepSlack* = 12.0       # px a sightline must keep clear of a swept
                              # disc beyond its radius: occlusion lives on
                              # 8px cells, so stone can shadow a line up to
                              # a cell and a half off the pixel geometry

proc oneWayFogReady*(): bool =
  ## Whether the vendored window/spin geometry describes the adopted map.
  MapW == ArenaW and MapH == ArenaH

proc spinDiamonds*(): seq[SpinDiamond] =
  ## The eight spinning center diamonds of the default arena: the engine
  ## spins every diamond-shaped obstacle whose center sits within 80px of
  ## the vertical symmetry axis (DiamondSpinBand), which on this map is
  ## column 5's four diamonds and their x-mirrors (ArenaLeftObstacles,
  ## mirrored as cx' = MapW - 1 - cx). Empty on any other map.
  if not oneWayFogReady():
    return
  for cy in [156, 252, 406, 502]:
    result.add SpinDiamond(cx: 565, cy: cy, r: 30)
    result.add SpinDiamond(cx: ArenaW - 1 - 565, cy: cy, r: 30)

proc windowRects(): seq[tuple[x, y, w, h: int]] =
  ## The default arena's glass windows: column 1's alternating stubs and the
  ## center pane of the mid bracket, plus their x-mirrors (rects mirror as
  ## x' = MapW - x - w). All lie fully outside the protected-floor carves,
  ## so the full rect is glass. Empty on any other map.
  if not oneWayFogReady():
    return
  for (x, y, w, h) in [
    (268, 108, 18, 60), (268, 300, 18, 59), (268, 491, 18, 60),
    (479, 312, 12, 36)
  ]:
    result.add (x, y, w, h)
    result.add (ArenaW - x - w, y, w, h)

proc buildFovBlocked*(client: ProtocolClient): seq[bool] =
  ## Ports the engine's buildFovBlocked: downsamples the pixel wall mask
  ## (wall = not walkable; the bake makes them exact complements) into the
  ## fog occlusion grid, a cell opaque when at least half its pixels are
  ## wall — minus glass, minus anything a spinning diamond can ever cover.
  let
    w = client.walkabilityWidth
    h = client.walkabilityHeight
    windows = windowRects()
    spins = spinDiamonds()
  result = newSeq[bool](GridW * GridH)
  for cy in 0 ..< GridH:
    for cx in 0 ..< GridW:
      var
        walls = 0
        pixels = 0
      for py in cy * NavCell ..< min((cy + 1) * NavCell, h):
        for px in cx * NavCell ..< min((cx + 1) * NavCell, w):
          inc pixels
          if client.walkabilityMask[py * w + px]:
            continue
          block opacity:
            for r in windows:
              if px >= r.x and px < r.x + r.w and py >= r.y and py < r.y + r.h:
                break opacity              # glass: wall, but never occludes
            for d in spins:
              let
                dx = px - d.cx
                dy = py - d.cy
              if dx * dx + dy * dy <= d.r * d.r:
                break opacity              # a turning diamond's ground: the
                                           # snapshot holds one spin frame
            inc walls
      result[cy * GridW + cx] = walls * 2 >= pixels

proc castOctant(
  blocked: openArray[bool],
  visible: var seq[bool],
  originCx, originCy, row: int,
  startSlope, endSlope: float,
  xx, xy, yx, yy: int
) =
  ## Verbatim port of the engine's castFovOctant: recursive shadowcasting
  ## over one octant (Bergstrom-style). Row distance is unbounded; scanning
  ## stops at the grid edge, so vision range is limited only by walls.
  if startSlope < endSlope:
    return
  var
    start = startSlope
    rowBlocked = false
    newStart = 0.0
  let maxDist = GridW + GridH
  for dist in row .. maxDist:
    if rowBlocked:
      break
    var anyInside = false
    for dx in -dist .. 0:
      let
        dy = -dist
        lSlope = (float(dx) - 0.5) / (float(dy) + 0.5)
        rSlope = (float(dx) + 0.5) / (float(dy) - 0.5)
      if start < rSlope:
        continue
      if endSlope > lSlope:
        break
      let
        cx = originCx + dx * xx + dy * xy
        cy = originCy + dx * yx + dy * yy
      if cx < 0 or cy < 0 or cx >= GridW or cy >= GridH:
        continue
      anyInside = true
      let index = cy * GridW + cx
      visible[index] = true
      if rowBlocked:
        if blocked[index]:
          newStart = rSlope
        else:
          rowBlocked = false
          start = newStart
      elif blocked[index]:
        rowBlocked = true
        castOctant(
          blocked,
          visible,
          originCx,
          originCy,
          dist + 1,
          start,
          lSlope,
          xx, xy, yx, yy
        )
        newStart = rSlope
    if not anyInside and dist > row:
      break

proc shadowcastFrom*(
  blocked: openArray[bool],
  originCx, originCy: int,
  visible: var seq[bool]
) =
  ## Ports the shadowcast half of the engine's computeFovVisible: every cell
  ## a viewer standing in the origin cell could ever see. The cone/bubble
  ## intersection is deliberately absent (see the module header).
  if visible.len != GridW * GridH:
    visible.setLen(GridW * GridH)
  for i in 0 ..< visible.len:
    visible[i] = false
  visible[originCy * GridW + originCx] = true
  const Octants = [
    (1, 0, 0, 1), (0, 1, 1, 0), (0, -1, 1, 0), (-1, 0, 0, 1),
    (-1, 0, 0, -1), (0, -1, -1, 0), (0, 1, -1, 0), (1, 0, 0, -1)
  ]
  for (xx, xy, yx, yy) in Octants:
    castOctant(
      blocked,
      visible,
      originCx,
      originCy,
      1,
      1.0,
      0.0,
      xx, xy, yx, yy
    )

proc crossesSpinSweep*(spins: openArray[SpinDiamond], a, b: Vec): bool =
  ## Whether the segment a-b passes within a turning diamond's reach: inside
  ## its swept disc (radius r — the rotated footprint never leaves it) plus
  ## SpinSweepSlack of quantization margin. A sightline that crosses is
  ## wrong for part of every rotation and disqualifies the pair.
  for d in spins:
    let
      c = vec(float(d.cx), float(d.cy))
      ab = b - a
      len2 = dot(ab, ab)
      t = if len2 < 1e-9: 0.0 else: clamp(dot(c - a, ab) / len2, 0.0, 1.0)
    if dist(a + ab * t, c) <= float(d.r) + SpinSweepSlack:
      return true
  false
