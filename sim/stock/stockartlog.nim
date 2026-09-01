## No-op replacement for the stock bot's optional artifact telemetry.

import std/json

export json

type FrameSnap* = object
  tick*: int
  alive*: bool
  x*, y*: int
  hp*: int
  aim*: int
  objective*: string
  action*: string
  targetX*, targetY*: int
  iCarry*, mateCarry*, ownStolen*, sawThief*, pushOut*: bool
  hasShield*, hasSpraypaint*, carryNade*: bool
  nadeCharge*: int
  jinked*: bool
  nadeDanger*: bool
  enemiesVisible*: int
  engageDist*: int
  mask*: uint8
  fired*: bool

proc artInit*(slot: int, team, role: string) = discard
proc artEvent*(tick: int, kind: string, fields: JsonNode = nil) = discard
proc artFrame*(snap: FrameSnap) = discard
proc artFlush*() = discard
