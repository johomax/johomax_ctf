import std/unittest

include ../baseline/shell_seat

proc clearRecipeEnvironment() =
  if existsEnv("S2_OPENING_CALL"):
    delEnv("S2_OPENING_CALL")
  if existsEnv("S2_RECALLS"):
    delEnv("S2_RECALLS")

clearRecipeEnvironment()

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
  test "unset recipe keeps the six-module built-in policy":
    let seat = newShellSeat(0)
    var names: seq[string]
    for module in seat.modules:
      names.add(module.name)
    check names == @["edge_ride", "target_law", "supply_run", "bodyguard",
      "crossfire", "jackal"]
    check not seat.openingOverride
    check not seat.recallsOverride

  test "configured opening is verbatim after refs and gates its modules":
    let opening =
      "{ \"plays\": [ {\"play\":\"pact\",\"params\":{\"partners\":[\"$PARTNER\",\"$SELF\"]}}, {\"play\":\"bodyguard\",\"params\":{\"ward\":\"$PARTNER\"}} ] }"
    putEnv("S2_OPENING_CALL", opening)
    putEnv("S2_RECALLS",
      "[{\"at_tick\":120,\"call\":{\"plays\":[{\"play\":\"crossfire\"}]}}]")
    defer: clearRecipeEnvironment()

    let seat = newShellSeat(3)
    seat.partnerSeat = 11
    var names: seq[string]
    for module in seat.modules:
      names.add(module.name)
    check names == @["edge_ride", "target_law", "bodyguard", "crossfire",
      "pact"]
    check not seat.startupCallDecision(900).send
    seat.modules[seat.moduleIndex(PlaybookPactName)].state = msReady
    check not seat.startupCallDecision(900).send
    seat.modules[seat.moduleIndex(PlaybookBodyguardName)].state = msReady
    let decision = seat.startupCallDecision(900)
    check decision.send
    check decision.reason == "configured_opening"
    check decision.callJson == opening
      .replace("$PARTNER", "seat:11")
      .replace("$SELF", "seat:3")

  test "configured recalls wait for both tick and referenced modules":
    putEnv("S2_OPENING_CALL",
      "{\"plays\":[{\"play\":\"edge_ride\"}]}")
    putEnv("S2_RECALLS",
      "[{\"at_tick\":100,\"call\":{\"plays\":[{\"play\":\"pact\",\"params\":{\"partners\":[\"$PARTNER\"]}}]}},{\"at_tick\":150,\"call\":{\"plays\":[{\"play\":\"target_law\",\"params\":{\"never\":[\"$SELF\"]}}]}}]")
    defer: clearRecipeEnvironment()

    let seat = newShellSeat(1)
    seat.partnerSeat = 9
    check not seat.takeDueRecall(99).send
    check not seat.takeDueRecall(100).send
    check seat.nextRecall == 0
    seat.modules[seat.moduleIndex(PlaybookPactName)].state = msReady
    let first = seat.takeDueRecall(106)
    check first.send
    check first.atTick == 100
    check first.callJson ==
    "{\"plays\":[{\"params\":{\"partners\":[\"seat:9\"]},\"play\":\"pact\"}]}"
    check not seat.takeDueRecall(149).send
    seat.modules[seat.moduleIndex(PlaybookTargetLawName)].state = msReady
    let second = seat.takeDueRecall(155)
    check second.send
    check second.atTick == 150
    check second.callJson ==
    "{\"plays\":[{\"params\":{\"never\":[\"seat:1\"]},\"play\":\"target_law\"}]}"

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
