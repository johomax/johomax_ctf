import std/[options, unittest]

import baseline/shell_view
import ctf/sim_types
import shell/[binary_view, types, view]

proc p(x, y: int): PlayPoint = (x, y)

const
  # Exact buildPlayView outputs from coworld-ctf 6a913ebb.
  EngineLiveJson = """{"epoch":"17","items":[{"fresh_tick":4240,"kind":"medkit","pos":[200,260],"present":true},{"fresh_tick":4238,"kind":"shield","pos":[360,420]},{"fresh_tick":4230,"kind":"grenade","pos":[620,500],"present":false}],"kill_feed":[{"killer_team":"red","tick":4239,"victim_seat":5},{"killer_team":"blue","tick":4228,"victim_seat":14}],"schema":"play_view","self":{"aim_brads":224,"alive":true,"hp":3,"hp_frac":0.75,"pos":[120,180]},"tick":4242,"tracks":[{"aim_brads":16,"fresh_tick":4242,"hp":4,"pos":[220,180],"seat":10,"team":"green"},{"aim_brads":128,"bounty":true,"fresh_tick":4241,"hp":2,"pos":[480,210],"seat":4,"team":"black"},{"fresh_tick":4234,"hp":5,"pos":[740,380],"seat":7,"team":"pink"},{"fresh_tick":4200,"pos":[1000,700],"seat":13,"team":"silver"}],"v":1,"world":{"alive_teams":6,"zone":{"current":[40,60,1400,900],"dps":2,"next":[260,180,900,600],"phase":3,"ticks_to_shrink":96}}}"""
  EngineDeadJson = """{"epoch":"17","items":[{"fresh_tick":4240,"kind":"medkit","pos":[200,260],"present":true},{"fresh_tick":4238,"kind":"shield","pos":[360,420]},{"fresh_tick":4230,"kind":"grenade","pos":[620,500],"present":false}],"kill_feed":[{"killer_team":"red","tick":4239,"victim_seat":5},{"killer_team":"blue","tick":4228,"victim_seat":14}],"schema":"play_view","self":{"aim_brads":224,"alive":false,"hp":0,"hp_frac":0.0,"pos":[120,180]},"tick":4242,"tracks":[{"aim_brads":16,"fresh_tick":4242,"hp":4,"pos":[220,180],"seat":10,"team":"green"},{"aim_brads":128,"bounty":true,"fresh_tick":4241,"hp":2,"pos":[480,210],"seat":4,"team":"black"},{"fresh_tick":4234,"hp":5,"pos":[740,380],"seat":7,"team":"pink"},{"fresh_tick":4200,"pos":[1000,700],"seat":13,"team":"silver"}],"v":1,"world":{"alive_teams":6,"zone":{"current":[40,60,1400,900],"dps":2,"next":[260,180,900,600],"phase":3,"ticks_to_shrink":96}}}"""
  EngineAbsentJson = "{}"

proc syntheticView(): PlayViewSource =
  PlayViewSource(
    tick: 803'u32,
    mode: gmBr,
    epoch: 17'u64,
    self: PlaySelf(pos: p(100, 120), hp: 4, hpFrac: 0.5,
      aimBrads: 32, alive: true),
    aliveTeams: 11,
    zone: some(PlayZone(
      phase: 2,
      current: PlayRect(x: 20, y: 30, w: 900, h: 700),
      next: some(PlayRect(x: 80, y: 90, w: 700, h: 500)),
      ticksToShrink: 144,
      dps: 2)),
    tracks: @[
      PlayTrack(seat: 1, team: Red, pos: p(250, 120), hp: some(4),
        freshTick: 803),
      PlayTrack(seat: 2, team: Blue, pos: p(400, 120), hp: some(2),
        freshTick: 802),
      PlayTrack(seat: 3, team: Green, pos: p(100, 520), hp: some(5),
        freshTick: 803)],
    killFeed: @[
      PlayKillFeedRow(eventId: 1, tick: 790, killerTeam: Red,
        victimSeat: 7),
      PlayKillFeedRow(eventId: 2, tick: 792, killerTeam: Blue,
        victimSeat: 6)])

proc checkDecoded(decoded: ViewDecodeResult; encoding: ViewEncoding) =
  check decoded.ok
  check decoded.encoding == encoding
  check decoded.view.tick == 803
  check decoded.view.epoch == 17
  check decoded.view.self.pos == StrategyPoint(x: 100, y: 120)
  check decoded.view.self.hp == 4
  check decoded.view.self.hpFrac == 0.5
  check decoded.view.self.alive
  check decoded.view.aliveTeams == 11

  check decoded.view.partner.seat == 1
  check decoded.view.partner.positionKnown
  check decoded.view.partner.pos == StrategyPoint(x: 250, y: 120)
  check decoded.view.partner.fresh
  check decoded.view.partner.aliveKnown
  check decoded.view.partner.alive
  check decoded.view.partner.distance == 150.0

  check decoded.view.visibleEnemies.len == 2
  check decoded.view.visibleEnemies[0].seat == 2
  check decoded.view.visibleEnemies[0].team == teamId("blue")
  check decoded.view.visibleEnemies[0].pos == StrategyPoint(x: 400, y: 120)
  check decoded.view.visibleEnemies[0].freshTick == 802
  check decoded.view.visibleEnemies[0].hpKnown
  check decoded.view.visibleEnemies[0].hp == 2
  check decoded.view.visibleEnemies[0].weakened
  check decoded.view.visibleEnemies[0].distance == 300.0
  check decoded.view.visibleEnemies[1].seat == 3
  check decoded.view.visibleEnemies[1].team == teamId("green")
  check decoded.view.visibleEnemies[1].pos == StrategyPoint(x: 100, y: 520)
  check decoded.view.visibleEnemies[1].freshTick == 803
  check decoded.view.visibleEnemies[1].hpKnown
  check decoded.view.visibleEnemies[1].hp == 5
  check not decoded.view.visibleEnemies[1].weakened
  check decoded.view.visibleEnemies[1].distance == 400.0

  check decoded.view.killFeed.len == 2
  check decoded.view.killFeed[0] == StrategyKill(
    tick: 792, killerTeam: teamId("blue"), victimSeat: 6)
  check decoded.view.killFeed[1] == StrategyKill(
    tick: 790, killerTeam: teamId("red"), victimSeat: 7)

  check decoded.view.zone.present
  check decoded.view.zone.phase == 2
  check decoded.view.zone.ticksToShrink == 144
  check decoded.view.zone.dps == 2
  check decoded.view.zone.current ==
    StrategyRect(x: 20, y: 30, w: 900, h: 700)
  check decoded.view.zone.nextPresent
  check decoded.view.zone.next ==
    StrategyRect(x: 80, y: 90, w: 700, h: 500)

suite "Season 2 strategy view decoder":
  test "engine binary capture exposes every strategy field":
    let payload = buildBinaryPlayView(syntheticView())
    check payload.len > 3
    check payload[0 .. 2] == "PV1"
    checkDecoded(decodeStrategyView(payload, 803, 1, teamId("red"), false,
      700.0), veBinary)

  test "engine JSON and binary views normalize identically":
    let source = syntheticView()
    let binary = decodeStrategyView(buildBinaryPlayView(source), 803, 1,
      teamId("red"), false, 700.0)
    let json = decodeStrategyView(buildPlayView(source), 803, 1,
      teamId("red"), false, 700.0)
    checkDecoded(binary, veBinary)
    checkDecoded(json, veJson)
    check binary.view == json.view

  test "current engine live JSON fixture decodes":
    let decoded = decodeStrategyView(EngineLiveJson, 4242, 10,
      teamId("green"), false, 700.0)
    check decoded.ok
    check not decoded.ignored
    check decoded.encoding == veJson
    check decoded.view.tick == 4242
    check decoded.view.epoch == 17
    check decoded.view.self == StrategySelf(
      pos: StrategyPoint(x: 120, y: 180), hp: 3, hpFrac: 0.75,
      alive: true)
    check decoded.view.partner.seat == 10
    check decoded.view.partner.pos == StrategyPoint(x: 220, y: 180)
    check decoded.view.partner.fresh
    check decoded.view.partner.alive
    check decoded.view.partner.distance == 100.0
    check decoded.view.visibleEnemies.len == 2
    check decoded.view.visibleEnemies[0].seat == 4
    check decoded.view.visibleEnemies[0].team == teamId("black")
    check decoded.view.visibleEnemies[0].hp == 2
    check decoded.view.visibleEnemies[0].weakened
    check decoded.view.visibleEnemies[1].seat == 7
    check decoded.view.visibleEnemies[1].team == teamId("pink")
    check decoded.view.killFeed == @[
      StrategyKill(tick: 4239, killerTeam: teamId("red"), victimSeat: 5),
      StrategyKill(tick: 4228, killerTeam: teamId("blue"), victimSeat: 14)]
    check decoded.view.aliveTeams == 6
    check decoded.view.zone == StrategyZone(
      present: true, phase: 3, ticksToShrink: 96, dps: 2,
      current: StrategyRect(x: 40, y: 60, w: 1400, h: 900),
      nextPresent: true,
      next: StrategyRect(x: 260, y: 180, w: 900, h: 600))

  test "current engine dead JSON fixture decodes":
    let decoded = decodeStrategyView(EngineDeadJson, 4242, 10,
      teamId("green"), false, 700.0)
    check decoded.ok
    check not decoded.ignored
    check not decoded.view.self.alive
    check decoded.view.self.hp == 0
    check decoded.view.self.hpFrac == 0.0

  test "current engine absent-seat sentinel is ignored without error":
    let decoded = decodeStrategyView(EngineAbsentJson, 4242, 10,
      teamId("green"), false, 700.0)
    check not decoded.ok
    check decoded.ignored
    check decoded.encoding == veJson
    check decoded.errorKind == vdeNone
    check decoded.detail.len == 0

  test "truncated and garbage PV1 payloads are ignored without raising":
    let truncated = decodeStrategyView("PV1", 803, 1, teamId("red"), false,
      700.0)
    check not truncated.ok
    check truncated.errorKind == vdeBinaryHeader

    let garbage = decodeStrategyView("PV1\0\x01\x00\x02\x05random bytes",
      803, 1, teamId("red"), false, 700.0)
    check not garbage.ok
    check garbage.errorKind == vdeBinaryHeader
