## Production-shell harness coverage for bot/plays/arm_up.nim.
##
## Compile from the engine checkout with its src directory on Nim's path, then
## set ARM_UP_WASM to the built module before running the test binary.

import std/[options, os, unittest]

import shell/[binary_view, body_map, emit_validator, play_harness_core, types,
  view]

proc loot(kind: PlayItemKind; x, y: int;
          present = none(bool); tick = 1'u32): PlayItem =
  PlayItem(kind: kind, pos: (x, y), present: present, freshTick: tick)

proc frame(tick: uint32; selfPos: BodyPoint;
           items: openArray[PlayItem]): HarnessFrame =
  var source = PlayViewSource(
    tick: tick,
    mode: gmBr,
    self: PlaySelf(pos: selfPos, hp: 4, hpFrac: 1.0, alive: true),
    aliveTeams: 16)
  for item in items:
    source.items.add(item)
  HarnessFrame(kind: hfStep, tick: tick,
    viewBytes: buildBinaryPlayView(source))

proc initFrame(params = "{}"): HarnessFrame =
  HarnessFrame(kind: hfInit, paramsBytes: params, contextBytes: "{}")

proc retuneFrame(params = "{}"): HarnessFrame =
  HarnessFrame(kind: hfRetune, oldParamsBytes: params, newParamsBytes: params)

proc run(modulePath: string; frames: openArray[HarnessFrame]): HarnessTrace =
  var caseData = HarnessCase(modulePath: modulePath, selfPos: (30, 30),
    emitClass: ecController, mode: gmBr)
  for item in frames:
    caseData.frames.add(item)
  runHarnessCase(caseData)

proc navigate(x, y: int; reason: string): string =
  "{\"arrive_radius\":12.0,\"kind\":\"navigate_to\",\"point\":[" &
    $x & "," & $y & "],\"reason\":\"" & reason &
    "\",\"schema\":\"intent\",\"v\":1}"

let modulePath = getEnv("ARM_UP_WASM")
require modulePath.len > 0

suite "arm_up production play harness":
  test "collects gun then hopper, survives unchanged retune, and retires":
    let trace = run(modulePath, [
      initFrame(),
      frame(1, (30, 30), [loot(pikGun, 40, 30),
        loot(pikHopper, 70, 30)]),
      frame(2, (40, 30), [loot(pikHopper, 70, 30, tick = 2)]),
      retuneFrame(),
      frame(3, (70, 30), [loot(pikHopper, 70, 30,
        present = some(false), tick = 3)])])

    check trace.accepted
    check trace.manifestName == "arm_up"
    check trace.frames.len == 5
    check trace.frames[1].lastAcceptedBytes == navigate(40, 30, "arm_up:gun")
    check trace.frames[2].lastAcceptedBytes == navigate(70, 30,
      "arm_up:hopper")
    check not trace.frames[3].refused
    check trace.frames[4].returned == -1
    check trace.frames[4].faulted
    check trace.frames[4].reason == "play_step returned nonzero"

  test "ignores absent rows and retargets a crate taken at a distance":
    let trace = run(modulePath, [
      initFrame(),
      frame(1, (30, 30), [loot(pikGun, 40, 30, present = some(false)),
        loot(pikHopper, 70, 30)]),
      frame(2, (30, 30), [loot(pikGun, 50, 30), loot(pikGun, 60, 30)]),
      frame(3, (30, 30), [loot(pikHopper, 70, 30, tick = 3)]),
      frame(4, (30, 30), [loot(pikGun, 60, 30, tick = 4)])])

    check trace.accepted
    check trace.frames.len == 5
    check trace.frames[1].lastAcceptedBytes.len == 0
    check trace.frames[2].lastAcceptedBytes == navigate(50, 30, "arm_up:gun")
    check trace.frames[3].counters.emits == 0
    # The production instance still reports its standing accepted intent; an
    # external guard must close if native default movement is wanted here.
    check trace.frames[3].lastAcceptedBytes == navigate(50, 30, "arm_up:gun")
    check trace.frames[4].lastAcceptedBytes == navigate(60, 30, "arm_up:gun")
    check not trace.frames[4].faulted

  test "hopper_first overrides a nearer gun":
    let trace = run(modulePath, [
      initFrame("{\"detourMax\":600,\"order\":\"hopper_first\"}"),
      frame(1, (30, 30), [loot(pikGun, 40, 30),
        loot(pikHopper, 60, 30)])])

    check trace.accepted
    check trace.frames.len == 2
    check trace.frames[1].lastAcceptedBytes == navigate(60, 30,
      "arm_up:hopper")
