## Measures fog-of-war RECIPROCITY on the league arena: cell pairs where the
## shadowcast lights A -> B but not B -> A. Such pairs are one-way vision:
## standing at A you can watch (and, if the pixel ray is clear, shoot) B,
## while B cannot see A no matter where B aims. Bullet LOS is reciprocal, so
## any asymmetry here is pure fog-grid artifact — and a standing tactical
## exploit for whoever holds the seeing end.

import std/[os, strformat]
import ctf/sim

when isMainModule:
  let args = commandLineParams()
  if args.len < 2:
    quit("usage: recipprobe <engineDir> <configPath>", 2)
  setCurrentDir(absolutePath(args[0]))
  let configPath = absolutePath(args[1])

  var config = defaultGameConfig()
  config.update(readFile(configPath))
  config.seed = 1
  config.visionConeDeg = 180        # neutralize the cone: shadow only
  var s = initSimServer(config)

  # Standable cells: the center pixel fits a player footprint.
  var standable: seq[int] = @[]
  for cy in 0 ..< FovGridH:
    for cx in 0 ..< FovGridW:
      let (px, py) = fovCellCenter(cx, cy)
      if px < MapWidth and py < MapHeight and s.canOccupy(px, py):
        standable.add(fovCellIndex(cx, cy))
  echo &"standable cells: {standable.len} of {FovCellCount}"

  # Shadow set per standable origin.
  var shadow = newSeq[seq[bool]](standable.len)
  var cellPos = newSeq[tuple[cx, cy: int]](standable.len)
  for i, cell in standable:
    let cx = cell mod FovGridW
    let cy = cell div FovGridW
    cellPos[i] = (cx, cy)
    shadow[i] = newSeq[bool](FovCellCount)
    s.computeFovVisible(cx, cy, 0, shadow[i])

  # index of standable cell by cell id
  var idxOf = newSeq[int](FovCellCount)
  for k in 0 ..< idxOf.len: idxOf[k] = -1
  for i, cell in standable: idxOf[cell] = i

  var
    pairs = 0
    oneWay = 0
    oneWayShootable = 0
    examples: seq[string] = @[]
  for i in 0 ..< standable.len:
    for j in i + 1 ..< standable.len:
      let
        ab = shadow[i][standable[j]]
        ba = shadow[j][standable[i]]
      inc pairs
      if ab == ba:
        continue
      inc oneWay
      # seeing end -> blind end: is the pixel bullet ray also clear?
      let (seer, blind) = (if ab: (i, j) else: (j, i))
      let (ax, ay) = fovCellCenter(cellPos[seer].cx, cellPos[seer].cy)
      let (bx, by) = fovCellCenter(cellPos[blind].cx, cellPos[blind].cy)
      if s.lineOfSightClear(ax, ay, bx, by):
        inc oneWayShootable
        if examples.len < 12:
          examples.add(&"see from ({ax},{ay}) shoot ({bx},{by}); reverse blind")
  echo &"cell pairs: {pairs}"
  echo &"one-way visible: {oneWay} ({100.0 * float(oneWay) / float(pairs):.3f}%)"
  echo &"one-way AND bullet-clear (shoot from the dark): {oneWayShootable}"
  for e in examples:
    echo "  ", e
