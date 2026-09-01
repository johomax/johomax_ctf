import std/unittest

include ../baseline/shell_seat

proc baseView(): StrategyView =
  StrategyView(
    tick: 900,
    self: StrategySelf(pos: StrategyPoint(x: 100, y: 100), hp: 4,
      hpFrac: 1.0, alive: true),
    partner: StrategyPartner(seat: 1,
      pos: StrategyPoint(x: 250, y: 100), positionKnown: true,
      fresh: true, alive: true, aliveKnown: true, distance: 150.0),
    visibleEnemies: @[
      StrategyEnemy(seat: 2, team: 1, pos: StrategyPoint(x: 350, y: 100),
        freshTick: 900, distance: 250.0, hp: 2, hpKnown: true,
        weakened: true)],
    zone: StrategyZone(present: true, phase: 1, ticksToShrink: 500,
      current: StrategyRect(x: 0, y: 0, w: 1000, h: 1000)),
    aliveTeams: 12)

proc strategist(): ShellSeat =
  result = newShellSeat(0)
  result.partnerSeat = 1
  result.selfTeam = 0
  result.modules[result.moduleIndex(PlaybookCrossfireName)].state = msReady
  result.modules[result.moduleIndex(PlaybookJackalName)].state = msReady

suite "Season 2 phase strategy":
  test "a favourable visible fight selects crossfire":
    let seat = strategist()
    check seat.desiredPhase(baseView()) == phaseCrossfire

  test "a recent kill and two weak enemies select jackal":
    let seat = strategist()
    var view = baseView()
    view.visibleEnemies.add(StrategyEnemy(seat: 3, team: 2,
      pos: StrategyPoint(x: 450, y: 100), freshTick: 900,
      distance: 350.0, hp: 1, hpKnown: true, weakened: true))
    view.killFeed.add(StrategyKill(tick: 890, killerTeam: 2,
      victimSeat: 8))
    check seat.desiredPhase(view) == phaseJackal

  test "fight phase recalls on every documented safety condition":
    block zoneUrgency:
      let seat = strategist()
      seat.activePhase = phaseCrossfire
      var view = baseView()
      view.zone.ticksToShrink = ZoneUrgencyTicks
      check seat.desiredPhase(view) == phaseSurvival

    block lowHp:
      let seat = strategist()
      seat.activePhase = phaseCrossfire
      var view = baseView()
      view.self.hpFrac = 0.66
      check seat.desiredPhase(view) == phaseSurvival

    block partnerDeath:
      let seat = strategist()
      seat.activePhase = phaseCrossfire
      var view = baseView()
      view.partner.alive = false
      check seat.desiredPhase(view) == phaseSurvival

    block completedKill:
      let seat = strategist()
      seat.activePhase = phaseCrossfire
      seat.phaseStartTick = 850
      var view = baseView()
      view.killFeed.add(StrategyKill(tick: 890, killerTeam: 0,
        victimSeat: 8))
      check seat.desiredPhase(view) == phaseSurvival

    block lostTrack:
      let seat = strategist()
      seat.activePhase = phaseCrossfire
      var view = baseView()
      view.visibleEnemies.setLen(0)
      check seat.desiredPhase(view) == phaseSurvival
