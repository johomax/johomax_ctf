## Dump the walkability mask of a pinned map, for embedding in the policy.
##
##   walkdump --engine DIR --config FILE --out FILE
##
## Loads the game config exactly as simulate.nim does (which resolves and
## pins the map), seats the declared roster, starts the game so the terrain
## is laid down, and writes `W H` then H rows of W chars ('1' walkable, '0'
## not) -- the engine's own `walkMask`, the same bits the walkability sprite
## carries on the wire. Hosted, a giant map's walkability sprite is a single
## ~2 MB websocket message and never reaches a policy (2026-09-01); a policy
## that ships this mask can navigate without it.

import
  std/[os, strutils],
  ctf/[sim, global]

proc main() =
  var engineDir, configPath, outPath: string
  var i = 1
  while i <= paramCount():
    let a = paramStr(i)
    if a == "--engine": engineDir = paramStr(i + 1); i += 2
    elif a == "--config": configPath = paramStr(i + 1); i += 2
    elif a == "--out": outPath = paramStr(i + 1); i += 2
    else: quit("unknown argument: " & a, 2)
  if engineDir.len == 0 or configPath.len == 0 or outPath.len == 0:
    quit("usage: walkdump --engine DIR --config FILE --out FILE", 2)
  let configJson = readFile(absolutePath(configPath))
  let outFile = absolutePath(outPath)
  setCurrentDir(engineDir)
  var config = defaultGameConfig()
  config.update(configJson)
  var sim = initSimServer(config)
  sim.gameEventLoggingEnabled = false
  for slot in 0 ..< config.slots.len:
    discard sim.addPlayer("player" & $(slot + 1), requestedSlot = slot,
                          trusted = true)
  sim.startGame()
  let
    w = sim.gameMap.width
    h = sim.gameMap.height
  var lines = newSeqOfCap[string](h + 1)
  lines.add($w & " " & $h)
  for y in 0 ..< h:
    var row = newStringOfCap(w)
    for x in 0 ..< w:
      let idx = y * w + x
      let walkable =
        if idx < sim.walkMask.len: sim.walkMask[idx]
        elif idx < sim.wallMask.len: not sim.wallMask[idx]
        else: true
      row.add(if walkable: '1' else: '0')
    lines.add(row)
  writeFile(outFile, lines.join("\n") & "\n")
  echo "walkdump: ", w, "x", h, " walkMask.len ", sim.walkMask.len,
    " phase ", ord(sim.phase), " -> ", outFile

main()
