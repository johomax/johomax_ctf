## Map-space vectors and the brad angle system the turret is steered in.
##
## `Vec` is a point or direction in map pixels: x grows right, y grows DOWN,
## which is why the angle helpers flip the sign of y before `arctan2`. Brads
## are the sim's aim unit (`AimBrads` to a turn, 0 = east, counter-clockwise
## on screen): `octantBits` picks a d-pad direction, `bradsErr` the arc left.

import
  std/[math],
  bitworld/spriteprotocol,
  tuning

type
  Vec* = object                # a map-space point or direction
    x*, y*: float

# Every one of these is a line of arithmetic called from the innermost loop of
# something else -- a raycast steps `+` and `*` once per sample, exposure
# costing runs `dist` once per nav cell per threat. Nim does not inline across
# modules on its own, so without the pragma each of those samples paid a call,
# a stack frame and a 16-byte struct return: `+` alone came back as its own
# entry in the profile. Same arithmetic in the same order either way, so the
# floating-point results -- and the episode hash -- are untouched.

proc vec*(x, y: float): Vec {.inline.} =
  Vec(x: x, y: y)

proc `+`*(a, b: Vec): Vec {.inline.} = vec(a.x + b.x, a.y + b.y)
proc `-`*(a, b: Vec): Vec {.inline.} = vec(a.x - b.x, a.y - b.y)
proc `*`*(a: Vec, s: float): Vec {.inline.} = vec(a.x * s, a.y * s)

proc len*(a: Vec): float {.inline.} =
  hypot(a.x, a.y)

proc dist*(a, b: Vec): float {.inline.} =
  len(a - b)

proc norm*(a: Vec): Vec {.inline.} =
  let l = a.len()
  if l < 1e-6: vec(0, 0) else: a * (1.0 / l)

proc dot*(a, b: Vec): float {.inline.} =
  a.x * b.x + a.y * b.y

proc withinDist*(a, b: Vec, r: float): bool {.inline.} =
  ## `dist(a, b) <= r`, decided off the squares wherever they can decide it.
  ##
  ## The same comparison, not a cheaper restatement of it: a squared distance
  ## under `(r-1)^2` puts the true distance under `r - 1`, and one over
  ## `(r+1)^2` puts it over `r + 1` — a whole PIXEL clear of the boundary on
  ## either side, where the most rounding can move a correctly-rounded `hypot`
  ## of these magnitudes is about 1e-12. Only the annulus between the two is
  ## delicate enough to need the real thing, and it is a sliver of the cells a
  ## caller sweeps. That is the difference from the `sqrt(d2) <= R` versus
  ## `d2 <= R*R` trade `sim/README.md` warns off: this does not decide the
  ## boundary by another route, it declines to decide it at all.
  ##
  ## The `r > 1.0` guard is not decoration — below that, `(r-1)^2` grows again
  ## as r shrinks and the first test would start accepting points past r.
  ##
  ## It is a drop-in for ANY `dist(a, b) <= r` in the tree; it is used at the
  ## three that sweep thousands of cells (`markExposedFrom`, the sonar disc in
  ## `rebuildExposure`, `findPeekCell`'s range cull) and not at the rest
  ## because the rest are cold, not because they are different.
  let d = a - b
  let d2 = dot(d, d)
  var answer: bool
  if r > 1.0 and d2 <= (r - 1.0) * (r - 1.0):
    answer = true
  elif d2 >= (r + 1.0) * (r + 1.0):
    answer = false
  else:
    answer = d.len() <= r
  when defined(rayAudit):
    # -d:rayAudit, same flag `grid.nim` documents: the thing this proc claims
    # is that it equals `dist(a, b) <= r` for EVERY input, and the expression
    # it claims to equal is one line long. A pure observer, so an audit build
    # must hash the same as a plain one.
    doAssert answer == (dist(a, b) <= r),
      "withinDist disagreed with dist <= r at r=" & $r
  answer

proc cross*(a, b: Vec): float {.inline.} =
  a.x * b.y - a.y * b.x

proc octantBits*(d: Vec): uint8 =
  ## D-pad bits for the 8-way direction nearest to `d`. The worst-case aim
  ## error is 22.5 degrees, safely inside the 25-degree firing cone.
  if d.len() < 1e-6:
    return 0
  let octant = (int(round(arctan2(d.y, d.x) / (PI / 4))) + 8) mod 8
  case octant
  of 0: ButtonRight
  of 1: ButtonRight or ButtonDown
  of 2: ButtonDown
  of 3: ButtonDown or ButtonLeft
  of 4: ButtonLeft
  of 5: ButtonLeft or ButtonUp
  of 6: ButtonUp
  else: ButtonUp or ButtonRight

proc bradsOf*(d: Vec): int =
  ## The aim angle in brads pointing along `d`: 0 = east (+x), increasing
  ## counter-clockwise on screen (64 = north; map y grows downward).
  if d.len() < 1e-6:
    return 0
  (int(round(arctan2(-d.y, d.x) * float(AimBrads div 2) / PI)) +
    AimBrads) mod AimBrads

proc bradsDir*(brads: int): Vec =
  ## The unit vector of one aim angle in brads (the true fire axis).
  let angle = float(brads) * PI / float(AimBrads div 2)
  vec(cos(angle), -sin(angle))

proc bradsErr*(desired, current: int): int =
  ## The signed shortest arc from `current` to `desired` in -128..127:
  ## positive means rotate counter-clockwise (hold B).
  (desired - current + AimBrads + AimBrads div 2) mod AimBrads -
    AimBrads div 2
