## Production-shell harness coverage for bot/plays/lane_warden.nim.

import std/[options, os, unittest]

import ctf/sim_types
import shell/[binary_view, body_map, emit_validator, play_harness_core, types,
  view]

const TestParams =
  "{\"coverRadius\":0,\"hpFloor\":2,\"margin\":40," &
  "\"standoffMax\":900,\"standoffMin\":300}"

proc enemy(tick: uint32; x, y: int; hp = 4): PlayTrack =
  PlayTrack(seat: 1, team: Blue, pos: (x, y), hp: some(hp),
    freshTick: tick)

proc frame(tick: uint32; selfPos: BodyPoint; hp = 4;
           tracks: openArray[PlayTrack] = [];
           current = PlayRect(x: 0, y: 0, w: 720, h: 96);
           next = none(PlayRect); ticksToShrink = 500): HarnessFrame =
  var source = PlayViewSource(
    tick: tick,
    mode: gmBr,
    self: PlaySelf(pos: selfPos, hp: hp, hpFrac: hp.float / 4.0,
      alive: true),
    aliveTeams: 16,
    zone: some(PlayZone(phase: 1, current: current, next: next,
      ticksToShrink: ticksToShrink)))
  for track in tracks:
    source.tracks.add(track)
  HarnessFrame(kind: hfStep, tick: tick,
    viewBytes: buildBinaryPlayView(source))

proc initFrame(params = TestParams): HarnessFrame =
  HarnessFrame(kind: hfInit, paramsBytes: params, contextBytes: "{}")

proc run(modulePath: string; selfPos: BodyPoint;
         frames: openArray[HarnessFrame]): HarnessTrace =
  var caseData = HarnessCase(modulePath: modulePath, selfPos: selfPos,
    emitClass: ecController, mode: gmBr)
  for item in frames:
    caseData.frames.add(item)
  runHarnessCase(caseData)

proc navigate(x, y: int; reason: string): string =
  "{\"arrive_radius\":24.0,\"idle_aim_center_brads\":0," &
    "\"kind\":\"navigate_to\",\"point\":[" &
    $x & "," & $y & "],\"reason\":\"" & reason &
    "\",\"schema\":\"intent\",\"v\":1}"

const HoldCover =
  "{\"arrive_radius\":0.0,\"idle_aim_center_brads\":0," &
  "\"kind\":\"hold\"," &
  "\"reason\":\"lane_warden:hold_cover\"," &
  "\"schema\":\"intent\",\"v\":1}"

let modulePath = getEnv("LANE_WARDEN_WASM")
require modulePath.len > 0

suite "lane_warden production play harness":
  test "retreats from a close enemy when not winning":
    let trace = run(modulePath, (80, 36), [
      initFrame(),
      frame(10, (80, 36), tracks = [enemy(10, 90, 36)])])

    check trace.accepted
    check trace.manifestName == "lane_warden"
    check trace.frames.len == 2
    check trace.frames[1].lastAcceptedBytes ==
      navigate(40, 36, "lane_warden:retreat")
    check trace.frames[1].counters.spatialCalls == 1
    check not trace.frames[1].faulted

  test "holds when already parked at cover with no enemies":
    let params =
      "{\"coverRadius\":1,\"hpFloor\":2,\"margin\":40," &
      "\"standoffMax\":900,\"standoffMin\":300}"
    let trace = run(modulePath, (84, 36), [
      initFrame(params),
      frame(20, (84, 36))])

    check trace.accepted
    check trace.frames.len == 2
    check trace.frames[1].lastAcceptedBytes == HoldCover
    check trace.frames[1].counters.spatialCalls == 2
    check not trace.frames[1].faulted

  test "moves into the next inset before a shrink":
    let trace = run(modulePath, (80, 36), [
      initFrame(),
      frame(30, (80, 36),
        next = some(PlayRect(x: 0, y: 0, w: 40, h: 96)),
        ticksToShrink = 60)])

    check trace.accepted
    check trace.frames.len == 2
    check trace.frames[1].lastAcceptedBytes ==
      navigate(30, 36, "lane_warden:enter")
    check trace.frames[1].counters.spatialCalls == 1
    check not trace.frames[1].faulted

  test "does not emit an unchanged decision":
    let trace = run(modulePath, (80, 36), [
      initFrame(),
      frame(40, (80, 36), tracks = [enemy(40, 90, 36)]),
      frame(46, (80, 36), tracks = [enemy(46, 90, 36)])])

    check trace.accepted
    check trace.frames.len == 3
    check trace.frames[1].lastAcceptedBytes ==
      navigate(40, 36, "lane_warden:retreat")
    check trace.frames[1].counters.emits == 1
    check trace.frames[2].lastAcceptedBytes == trace.frames[1].lastAcceptedBytes
    check trace.frames[2].counters.emits == 0
    check trace.frames[2].counters.spatialCalls == 1
    check not trace.frames[2].faulted
