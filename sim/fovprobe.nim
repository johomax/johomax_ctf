## Measures mirror-symmetry of the engine's fog-of-war on the league arena.
##
## The map's obstacle union is (claimed) exactly x-mirror symmetric, and the
## bullet raycast provably mirrors (trunc div is odd). The fog, though, runs
## on a west/north-anchored 8px cell grid over a 1235px-wide map: cells do
## not map onto cells under x -> 1234-x. This probe quantifies what that does
## to what a player can actually see.
##
## Checks:
##  1. wall mask pixel mirror-exactness (control; should be 0 mismatches)
##  2. fovBlocked cell classification vs the mirrored geometry
##  3. end-to-end: visible(v, aim, t) vs visible(M v, M aim, M t) over
##     sampled walkable viewer/target pairs, cone neutralized (shadow only)
##  4. same, with the league 45-degree cone at mirrored aims

import std/[json, os, strformat, strutils]
import ctf/sim

proc mirrorX(x: int): int = MapWidth - 1 - x
proc mirrorBrads(a: int): int = (AimBradsTurn div 2 - a + AimBradsTurn * 2) mod AimBradsTurn

when isMainModule:
  let args = commandLineParams()
  if args.len < 2:
    quit("usage: fovprobe <engineDir> <configPath>", 2)
  let engineDir = absolutePath(args[0])
  let configPath = absolutePath(args[1])
  setCurrentDir(engineDir)

  var config = defaultGameConfig()
  config.update(readFile(configPath))
  config.seed = 1
  var s = initSimServer(config)
  echo &"map {MapWidth}x{MapHeight}  fovGrid {FovGridW}x{FovGridH} cell {FovCellSize}px"

  # -- 1. wall mask mirror check (static art walls, tick 0 diamonds) -------
  var wallMismatch = 0
  for y in 0 ..< MapHeight:
    for x in 0 ..< MapWidth:
      if s.isWall(x, y) != s.isWall(mirrorX(x), y):
        inc wallMismatch
  echo &"wall pixel mirror mismatches: {wallMismatch}"

  # -- 2. fovBlocked vs mirrored-geometry classification --------------------
  # For each cell, reclassify "mostly wall" over the mirrored pixel window
  # and compare with the stored fovBlocked of the cell holding the mirrored
  # center. This shows cells whose opacity has no mirror twin.
  var
    blockedCells = 0
    unpaired = 0
  for cy in 0 ..< FovGridH:
    for cx in 0 ..< FovGridW:
      if not s.fovBlocked[fovCellIndex(cx, cy)]:
        continue
      inc blockedCells
      # does the mirrored center's cell agree?
      let (px, py) = fovCellCenter(cx, cy)
      let (mcx, mcy) = fovCellAt(mirrorX(min(px, MapWidth - 1)), py)
      if not s.fovBlocked[fovCellIndex(mcx, mcy)]:
        inc unpaired
  echo &"opaque fov cells: {blockedCells}; opaque with a transparent mirror-twin: {unpaired}"

  # -- 3/4. end-to-end visibility, shadow-only and league cone -------------
  # Viewers on a coarse walkable lattice, targets likewise; aim east for the
  # west copy and mirrored (west) for the east copy.
  const
    ViewerStride = 40
    TargetStride = 56
  var
    shadowPairs, shadowMismatch, shadowWestSees, shadowEastSees = 0
    conePairs, coneMismatch, coneWestSees, coneEastSees = 0
  var visA = newSeq[bool](FovCellCount)
  var visB = newSeq[bool](FovCellCount)
  var coneA = newSeq[bool](FovCellCount)
  var coneB = newSeq[bool](FovCellCount)

  var shadowCfg = s
  # neutralize the cone/bubble by widening the cone to a full circle
  shadowCfg.config.visionConeDeg = 180

  let aims = [0, 32, 64, 96]           # east, NE, north, NW (west copy)
  for vy in countup(ViewerStride, MapHeight - ViewerStride, ViewerStride):
    for vx in countup(ViewerStride, MapWidth div 2, ViewerStride):
      if not s.canOccupy(vx, vy):
        continue
      let mvx = mirrorX(vx)
      if not s.canOccupy(mvx, vy):
        continue                        # mirror spot blocked: skip (counted via walls above)
      let (cxA, cyA) = fovCellAt(vx, vy)
      let (cxB, cyB) = fovCellAt(mvx, vy)
      for aim in aims:
        let maim = mirrorBrads(aim)
        shadowCfg.computeFovVisible(cxA, cyA, aim, visA)
        shadowCfg.computeFovVisible(cxB, cyB, maim, visB)
        s.computeFovVisible(cxA, cyA, aim, coneA)
        s.computeFovVisible(cxB, cyB, maim, coneB)
        for ty in countup(TargetStride, MapHeight - TargetStride, TargetStride):
          for tx in countup(TargetStride, MapWidth - TargetStride, TargetStride):
            if not s.canOccupy(tx, ty):
              continue
            let mtx = mirrorX(tx)
            if not s.canOccupy(mtx, ty):
              continue
            let (tcA, trA) = fovCellAt(tx, ty)
            let (tcB, trB) = fovCellAt(mtx, ty)
            let
              sa = visA[fovCellIndex(tcA, trA)]
              sb = visB[fovCellIndex(tcB, trB)]
              ca = coneA[fovCellIndex(tcA, trA)]
              cb = coneB[fovCellIndex(tcB, trB)]
            inc shadowPairs
            if sa != sb:
              inc shadowMismatch
              if sa: inc shadowWestSees else: inc shadowEastSees
            inc conePairs
            if ca != cb:
              inc coneMismatch
              if ca: inc coneWestSees else: inc coneEastSees
  echo &"shadow-only: {shadowPairs} mirrored pairs, {shadowMismatch} disagree " &
    &"({100.0 * float(shadowMismatch) / float(shadowPairs):.2f}%)  " &
    &"west-viewer-sees-only {shadowWestSees}  east-viewer-sees-only {shadowEastSees}"
  echo &"league cone: {conePairs} mirrored pairs, {coneMismatch} disagree " &
    &"({100.0 * float(coneMismatch) / float(conePairs):.2f}%)  " &
    &"west-viewer-sees-only {coneWestSees}  east-viewer-sees-only {coneEastSees}"
