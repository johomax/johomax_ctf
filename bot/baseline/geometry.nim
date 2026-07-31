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
