## The two grids the bot reasons over, and the raycasts that read them.
##
## The first is the pixel walkability mask the server sends down as a sprite:
## one bool per map pixel, walls are exactly the non-walkable pixels. The second
## is the NavCell (8px) lattice eroded from it, which `bot.cellWalkable` holds —
## a cell is open only where the whole player footprint fits. Pixel rays answer
## line of sight and firing lines; the coarse and grid rays trade accuracy for
## the thousands of samples cover scoring and exposure costing need.
##
## Three loops here read a grid through a `ptr UncheckedArray` rather than as
## a seq. That is the one place this tree spends its safety, and it is spent
## deliberately rather than by turning checks off globally: each cast sits
## under a line that has just PROVED the index in range, and the proof is
## written above it. `-d:danger` cannot make that distinction — it does not
## know which indices were proved — which is why the flag stays off and these
## four sites are hand-picked. `navgrid.nim` holds the fourth and says the
## same thing.

import
  protocols,
  world,
  geometry,
  tuning

proc walkableAt*(client: ProtocolClient, x, y: int): bool {.inline.} =
  ## Inlined deliberately: this is the innermost line of every raycast on the
  ## map, and the rays are where the policy spends most of its geometry —
  ## exposure costing alone samples it a few million times per repath. A
  ## cross-module call per pixel is most of what one sample costs.
  if x < 0 or y < 0 or x >= client.walkabilityWidth or
      y >= client.walkabilityHeight:
    return false
  client.walkabilityMask[y * client.walkabilityWidth + x]

proc footprintFits*(client: ProtocolClient, x, y: int): bool =
  ## True when the player's solid box centered at (x, y) is all walkable,
  ## mirroring canOccupy in the sim.
  for dy in -PlayerHalf .. PlayerHalf:
    for dx in -PlayerHalf .. PlayerHalf:
      if not client.walkableAt(x + dx, y + dy):
        return false
  true

proc cellOf*(p: Vec): int {.inline.} =
  let
    cx = clamp(int(p.x) div NavCell, 0, GridW - 1)
    cy = clamp(int(p.y) div NavCell, 0, GridH - 1)
  cy * GridW + cx

proc cellCenter*(cell: int): Vec {.inline.} =
  vec(
    float((cell mod GridW) * NavCell + NavCell div 2),
    float((cell div GridW) * NavCell + NavCell div 2)
  )

proc cellOffset*(p: Vec, cell: int): Vec {.inline.} =
  ## The shortest displacement that puts `p` inside `cell`; zero on an axis
  ## that is already inside it.
  ##
  ## Per axis rather than as a distance, because the d-pad drives the two axes
  ## independently — and because the fog asks only WHICH cell the body is in,
  ## never where in it, so the nearest inside pixel is worth exactly as much
  ## as the centre and costs less to reach.
  let
    x0 = float((cell mod GridW) * NavCell)
    y0 = float((cell div GridW) * NavCell)
    hi = float(NavCell - 1)
  vec(
    (if p.x < x0: x0 - p.x elif p.x > x0 + hi: x0 + hi - p.x else: 0.0),
    (if p.y < y0: y0 - p.y elif p.y > y0 + hi: y0 + hi - p.y else: 0.0)
  )

proc pixelRayClearEdge(
  client: ProtocolClient, ax, ay, dx, dy, steps: int
): bool =
  ## The general ray: a sample may leave the map, where `walkableAt` reads
  ## off-map ground as wall. Its own loop rather than a branch inside the fast
  ## one, because what the fast one buys is not having that test at all.
  ##
  ## The samples are exactly `ax + (bx - ax) * s div steps` (and same for y),
  ## but carried incrementally: vx holds the quotient and ex the remainder of
  ## `(bx - ax) * s / steps`, restored each step to |ex| < steps with the
  ## dividend's sign — the unique truncating-division pair, so vx equals the
  ## `div` it replaces at every s. Two integer divisions per pixel were most
  ## of what a ray cost.
  let
    qx = dx div steps
    rx = dx - qx * steps
    qy = dy div steps
    ry = dy - qy * steps
  var
    vx = 0
    ex = 0
    vy = 0
    ey = 0
  for _ in 1 .. steps:
    vx += qx
    ex += rx
    if ex >= steps:
      ex -= steps
      inc vx
    elif ex <= -steps:
      ex += steps
      dec vx
    vy += qy
    ey += ry
    if ey >= steps:
      ey -= steps
      inc vy
    elif ey <= -steps:
      ey += steps
      dec vy
    if not client.walkableAt(ax + vx, ay + vy):
      return false
  true

proc pixelRayClear*(client: ProtocolClient, a, b: Vec): bool =
  ## True when no wall pixel blocks the segment; mirrors lineOfSightClear in
  ## the sim (walls are exactly the non-walkable pixels).
  ##
  ## This is the dearest proc in a Paintbot tick — 30% of one on `4ffa` —
  ## because the searches that call it (`findPeekCell`, `findDuckCell`, the
  ## engagement tests) buy a ray as long as the board per candidate cell. What
  ## makes the common one cheap is that its BOUNDS TEST IS ANSWERED ONCE: `vx`
  ## is `dx * s div steps` truncated toward zero, so it never leaves `[0, dx]`
  ## (or `[dx, 0]`) and x therefore never leaves `[ax, bx]`; same for y. Both
  ## endpoints inside the mask puts every sample inside it, so the loop below
  ## reads the mask through a raw pointer with no per-sample range test —
  ## neither `walkableAt`'s four comparisons (each reloading a field through
  ## the client ref) nor the seq bounds check under them.
  ##
  ## And `steps` is the LONGER of the two spans, so the axis it came from
  ## moves exactly one pixel every step: its `q` is the sign, its `r` is zero,
  ## and its remainder bookkeeping can never fire. Only the short axis needs
  ## the recurrence, which makes the flat index a constant stride plus a
  ## single `w` when the short axis wraps. Same samples in the same order;
  ## what is gone is arithmetic that was provably a no-op.
  ##
  ## NOT DONE, and measured, so it is not tried twice: an index of the 8x8
  ## squares whose every pixel is walkable, so a ray inside one could skip
  ## every sample that provably stays in it. It is correct and it is SLOWER —
  ## a square is worth three or four samples, against a per-square lookup plus
  ## either two integer divisions to restate the recurrence or the same steps
  ## run without the load. Alternated five times a side at `--tick-cap 1500`:
  ## restated 8.99 s, run 9.04 s, no index at all 8.67 s on `4ffa`, and
  ## 10.60 / 10.69 / 9.72 s on `2v2`. The instruction counts preferred the
  ## divisions, which is the trap `sim/README.md` warns about — take the
  ## ranking from callgrind and the verdict from the stopwatch.
  let
    ax = int(a.x)
    ay = int(a.y)
    bx = int(b.x)
    by = int(b.y)
    dx = bx - ax
    dy = by - ay
    steps = max(abs(dx), abs(dy))
  if steps == 0:
    return true
  let
    w = client.walkabilityWidth
    h = client.walkabilityHeight
  if not (ax >= 0 and ay >= 0 and ax < w and ay < h and
          bx >= 0 and by >= 0 and bx < w and by < h and
          client.walkabilityMask.len == w * h):
    return client.pixelRayClearEdge(ax, ay, dx, dy, steps)
  let
    mask = cast[ptr UncheckedArray[bool]](addr client.walkabilityMask[0])
    xMajor = steps == abs(dx)
    shortSpan = (if xMajor: dy else: dx)
    shortStride = (if xMajor: w else: 1)
    longStride =
      (if xMajor: (if dx > 0: 1 else: -1) else: (if dy > 0: w else: -w))
    qShort = shortSpan div steps        # 0, or the sign on a 45-degree ray
    rShort = shortSpan - qShort * steps
    stride = longStride + qShort * shortStride
  var
    eShort = 0
    index = ay * w + ax
  for _ in 1 .. steps:
    index += stride
    eShort += rShort
    if eShort >= steps:
      eShort -= steps
      index += shortStride
    elif eShort <= -steps:
      eShort += steps
      index -= shortStride
    if not mask[index]:
      return false
  true

proc coarsePoint(a, d: Vec, s, n: int): Vec {.inline.} =
  ## Sample `s` of `n` along `a -> a + d`. Spelled once because both loops in
  ## `rayClearCoarse` take it and the two must not drift: the sample POINTS
  ## are upstream's float expression untouched, and moving one by a rounding
  ## error is a different cell and so a different episode.
  a + d * (float(s) / float(n))

proc rayClearCoarse*(client: ProtocolClient, a, b: Vec, step: float): bool =
  ## Coarsely-sampled walkability raycast for cover scoring and exposure
  ## costing, where an occasional missed thin corner is an acceptable trade.
  ##
  ## What is cheaper than it was is READING the samples, on the same argument
  ## `pixelRayClear` makes: a segment whose endpoints are inside the map has
  ## every `int(p)` inside it too. `int` truncates toward zero, so the ulp of
  ## slop the multiply can add at either end still lands in range — which is
  ## why the test is against `w - 1` rather than `w`.
  let
    d = b - a
    l = d.len()
  if l < 1e-6:
    return true
  let
    n = max(1, int(l / step))
    w = client.walkabilityWidth
    h = client.walkabilityHeight
  if not (min(a.x, b.x) >= 0.0 and max(a.x, b.x) <= float(w - 1) and
          min(a.y, b.y) >= 0.0 and max(a.y, b.y) <= float(h - 1) and
          client.walkabilityMask.len == w * h):
    for s in 1 .. n:
      let p = coarsePoint(a, d, s, n)
      if not client.walkableAt(int(p.x), int(p.y)):
        return false
    return true
  let mask = cast[ptr UncheckedArray[bool]](addr client.walkabilityMask[0])
  for s in 1 .. n:
    let p = coarsePoint(a, d, s, n)
    if not mask[int(p.y) * w + int(p.x)]:
      return false
  true

proc openLineLen*(client: ProtocolClient, a, dir: Vec, maxLen, step: float): float =
  ## Length of the wall-free ray from `a` along unit `dir`, capped at maxLen.
  ## Sizes sniper firing lines and arrow-snipe rays under the map-wide gun.
  var l = step
  while l <= maxLen:
    let p = a + dir * l
    if not client.walkableAt(int(p.x), int(p.y)):
      return l - step
    l += step
  maxLen

proc nearestOpenCell*(bot: Bot, cell: int): int =
  ## The nearest walkable nav cell, searched in expanding rings.
  if bot.cellWalkable[cell]:
    return cell
  let
    cx = cell mod GridW
    cy = cell div GridW
  for r in 1 .. 16:
    for dy in -r .. r:
      for dx in -r .. r:
        if abs(dx) != r and abs(dy) != r:
          continue
        let
          nx = cx + dx
          ny = cy + dy
        if nx < 0 or ny < 0 or nx >= GridW or ny >= GridH:
          continue
        if bot.cellWalkable[ny * GridW + nx]:
          return ny * GridW + nx
  cell

proc snapToCover*(bot: Bot, p: Vec): Vec =
  ## The nearest cover cell within a few cells of a point, else the point.
  let
    c0 = bot.nearestOpenCell(cellOf(p))
    cx = c0 mod GridW
    cy = c0 div GridW
  var bestD = 1e18
  result = p
  for dy in -6 .. 6:
    for dx in -6 .. 6:
      let
        nx = cx + dx
        ny = cy + dy
      if nx < 0 or ny < 0 or nx >= GridW or ny >= GridH:
        continue
      let nc = ny * GridW + nx
      if not bot.coverCell[nc]:
        continue
      let d = dist(cellCenter(nc), p)
      if d < bestD:
        bestD = d
        result = cellCenter(nc)

proc gridRayClear*(bot: Bot, a, b: Vec): bool =
  ## True when the eroded nav grid is open along the whole segment.
  ##
  ## `cellOf` clamps, so every index is in range by construction and the seq
  ## range check on top of it is a test that cannot fail; read through a raw
  ## pointer instead. The sample points stay upstream's float expression, for
  ## the reason `rayClearCoarse` gives.
  let
    d = b - a
    steps = int(d.len() / 4.0) + 1
    cells = cast[ptr UncheckedArray[bool]](addr bot.cellWalkable[0])
  for s in 0 .. steps:
    let p = a + d * (float(s) / float(steps))
    if not cells[cellOf(p)]:
      return false
  true
