## Sprite labels, resolved to an enum once per sprite DEFINITION.
##
## A label arrives as a string and the policy asks "which objects carry this
## one" about thirty times per decision. Left as strings that is thirty string
## compares against every visible object, every frame, on every seat — and
## each compare first chases a per-sprite ref to reach the string at all.
##
## A label only changes when its sprite is (re)defined, which happens a
## handful of times a match, so the comparison belongs there rather than in
## the frame loop. `classify` runs once per definition and every query after
## it is an integer compare on the result. `protocols.nim` goes one further
## and groups a frame's objects by kind, so a query reads only the objects
## that can match it.
##
## Every arm below is spelled with a `labels.nim` constant, so that module's
## rename guard still holds: a rename upstream is a compile error here rather
## than a group that silently stays empty forever.
##
## This module is also where the WIRE's idea of a side lives — `Colour`, the
## engine's team colours in its own seat-deal order. The policy's own
## two-sided `world.Team` is a different thing and stays there; what belongs
## here is the colour a label is spelled with, and there are sixteen of them.
##
## The enum is also stricter than the strings were. A query names a
## `LabelKind`, so a label the vocabulary does not have cannot be asked for at
## all — where a mistyped string used to return an empty seq and no error.
##
## ## Reading `labels.nim` alongside this
##
## `labels.nim` is vendored verbatim and still describes the consumer side in
## terms of `spriteObjectsWithLabel`, the exact-match query this module
## replaced. That prose is upstream's and stays byte-identical on purpose —
## re-syncing it must remain a plain diff. Translate as you read:
##
## - "passes to `spriteObjectsWithLabel`" is now "has an arm in `classify`".
##   `classify` IS the consumer-side guard `labels.nim` describes: an upstream
##   rename breaks its `of` arm at compile time.
## - `PolicyScannedLabels` is upstream's REFERENCE policy's list, not this
##   one's. This policy scans a subset: it never reads the corpse or
##   own-weapon families, so they classify as `lkOther` and are absent below.
##   That gap predates the enum — the bot had no scan for either — but the
##   enum makes it legible, which is the point. Adding one back means adding
##   an arm here, and nothing else.
## - `labels.nim`'s "KNOWN GAP" note says nothing forces a new scan to be
##   registered. Here something does: a query takes a `LabelKind`, so a scan
##   the enum has no arm for cannot be written at all.

import
  std/[strutils],
  labels

type
  Colour* = enum
    ## The wire's team colours, IN THE ENGINE'S OWN SEAT-DEAL ORDER.
    ##
    ## A game's active teams are always a prefix of the engine's `Team` enum
    ## and seats go round them by join order, so `Colour(slot mod teams)` IS
    ## the deal the server made — which is the whole of the four-team seating
    ## bug: two-team parity (`slot mod 2`) names green as blue and yellow as
    ## red, and a wrong colour makes every scan below blind.
    ##
    ## Deliberately NOT `world.Team`. This is the WIRE VOCABULARY: it indexes
    ## label kinds and says who is on the board. `Team` is the two-sided
    ## STRATEGY frame the tuned constants are written against — us and the one
    ## side we raid — and on a four-team board those are different questions:
    ## three colours are enemies, one of them is the raid target.
    cRed
    cBlue
    cGreen
    cYellow
    cBlack
    cSilver
    cIvory
    cPink
    cUmber
    cRust
    cOrange
    cPlum
    cLime
    cNavy
    cAzure
    cPeach

  LabelKind* = enum
    ## Every label family the policy scans for. Everything else — chrome,
    ## tracers, splatters, the cooldown twin of the fire icon — is `lkOther`,
    ## which is most of a frame and is dropped from the frame index entirely.
    lkOther

    # Flat labels, matched exactly.
    lkMedKit
    lkShield
    lkShieldCarried
    lkSprayCan
    lkSprayCanCarried
    lkGrenade
    lkGrenadeAir
    lkGrenadeCarried
    lkThrowTarget
    lkShotImpact
    lkFireIcon
    lkWalkabilityMap

    # Per-colour, per-facing sprites. All active colours have arms: on a
    # multi-team board a missing arm classifies a real
    # soldier as `lkOther`, which drops it from the frame index — a green
    # seat then never finds its own self marker, reads itself as dead and
    # stands at spawn all game, and every seat is blind to half the enemies.
    lkPlayerRedRight
    lkPlayerRedLeft
    lkPlayerBlueRight
    lkPlayerBlueLeft
    lkPlayerGreenRight
    lkPlayerGreenLeft
    lkPlayerYellowRight
    lkPlayerYellowLeft
    lkPlayerBlackRight
    lkPlayerBlackLeft
    lkPlayerSilverRight
    lkPlayerSilverLeft
    lkPlayerIvoryRight
    lkPlayerIvoryLeft
    lkPlayerPinkRight
    lkPlayerPinkLeft
    lkPlayerUmberRight
    lkPlayerUmberLeft
    lkPlayerRustRight
    lkPlayerRustLeft
    lkPlayerOrangeRight
    lkPlayerOrangeLeft
    lkPlayerPlumRight
    lkPlayerPlumLeft
    lkPlayerLimeRight
    lkPlayerLimeLeft
    lkPlayerNavyRight
    lkPlayerNavyLeft
    lkPlayerAzureRight
    lkPlayerAzureLeft
    lkPlayerPeachRight
    lkPlayerPeachLeft
    lkSelfRedRight
    lkSelfRedLeft
    lkSelfBlueRight
    lkSelfBlueLeft
    lkSelfGreenRight
    lkSelfGreenLeft
    lkSelfYellowRight
    lkSelfYellowLeft
    lkSelfBlackRight
    lkSelfBlackLeft
    lkSelfSilverRight
    lkSelfSilverLeft
    lkSelfIvoryRight
    lkSelfIvoryLeft
    lkSelfPinkRight
    lkSelfPinkLeft
    lkSelfUmberRight
    lkSelfUmberLeft
    lkSelfRustRight
    lkSelfRustLeft
    lkSelfOrangeRight
    lkSelfOrangeLeft
    lkSelfPlumRight
    lkSelfPlumLeft
    lkSelfLimeRight
    lkSelfLimeLeft
    lkSelfNavyRight
    lkSelfNavyLeft
    lkSelfAzureRight
    lkSelfAzureLeft
    lkSelfPeachRight
    lkSelfPeachLeft

    # The flags, carried and on their pedestal — one pair per active team.
    lkFlagRed
    lkFlagBlue
    lkFlagGreen
    lkFlagYellow
    lkFlagPlantedRed
    lkFlagPlantedBlue
    lkFlagPlantedGreen
    lkFlagPlantedYellow

    # The overhead health bar, one kind per lit-segment count.
    lkHp1
    lkHp2
    lkHp3
    lkHpDynamic

    # The episode's stated setup, invisible 1x1 markers in the init snapshot
    # that persist all match (they are never listed in the server's per-frame
    # object diff, so nothing ever reaps them).
    lkGameParams
    lkEndzone
    lkZone
    lkZoneNext

    # Families whose TAIL carries data, so the label itself is still read —
    # but only for the few objects in the group, never to find them.
    lkIdentityRed
    lkIdentityBlue
    lkIdentityGreen
    lkIdentityYellow
    lkIdentityBlack
    lkIdentitySilver
    lkIdentityIvory
    lkIdentityPink
    lkIdentityUmber
    lkIdentityRust
    lkIdentityOrange
    lkIdentityPlum
    lkIdentityLime
    lkIdentityNavy
    lkIdentityAzure
    lkIdentityPeach
    lkLives
    lkScoreRed
    lkScoreBlue
    lkScoreGreen
    lkScoreYellow
    lkScoreBlack
    lkScoreSilver
    lkScoreIvory
    lkScorePink
    lkScoreUmber
    lkScoreRust
    lkScoreOrange
    lkScorePlum
    lkScoreLime
    lkScoreNavy
    lkScoreAzure
    lkScorePeach
    lkShoutRed
    lkShoutBlue
    lkShoutGreen
    lkShoutYellow
    lkShoutBlack
    lkShoutSilver
    lkShoutIvory
    lkShoutPink
    lkShoutUmber
    lkShoutRust
    lkShoutOrange
    lkShoutPlum
    lkShoutLime
    lkShoutNavy
    lkShoutAzure
    lkShoutPeach

const LabelHpBarSegments* = 3
  ## The three legacy exact kinds remain so classic frames keep their old
  ## grouping and iteration order. Every other `hp ` spelling is grouped as
  ## lkHpDynamic and prefix-parsed by perception.

const ColourNames* = [
  cRed: "red", cBlue: "blue", cGreen: "green", cYellow: "yellow",
  cBlack: "black", cSilver: "silver", cIvory: "ivory", cPink: "pink",
  cUmber: "umber", cRust: "rust", cOrange: "orange", cPlum: "plum",
  cLime: "lime", cNavy: "navy", cAzure: "azure", cPeach: "peach"]
  ## The wire token for each colour — the engine's `teamText`. Every label
  ## spelled per colour below goes through this, so the four families cannot
  ## disagree with each other about how a colour is written.

const
  PlayerKinds* = [
    cRed: [lkPlayerRedRight, lkPlayerRedLeft],
    cBlue: [lkPlayerBlueRight, lkPlayerBlueLeft],
    cGreen: [lkPlayerGreenRight, lkPlayerGreenLeft],
    cYellow: [lkPlayerYellowRight, lkPlayerYellowLeft],
    cBlack: [lkPlayerBlackRight, lkPlayerBlackLeft],
    cSilver: [lkPlayerSilverRight, lkPlayerSilverLeft],
    cIvory: [lkPlayerIvoryRight, lkPlayerIvoryLeft],
    cPink: [lkPlayerPinkRight, lkPlayerPinkLeft],
    cUmber: [lkPlayerUmberRight, lkPlayerUmberLeft],
    cRust: [lkPlayerRustRight, lkPlayerRustLeft],
    cOrange: [lkPlayerOrangeRight, lkPlayerOrangeLeft],
    cPlum: [lkPlayerPlumRight, lkPlayerPlumLeft],
    cLime: [lkPlayerLimeRight, lkPlayerLimeLeft],
    cNavy: [lkPlayerNavyRight, lkPlayerNavyLeft],
    cAzure: [lkPlayerAzureRight, lkPlayerAzureLeft],
    cPeach: [lkPlayerPeachRight, lkPlayerPeachLeft]]
  SelfKinds* = [
    cRed: [lkSelfRedRight, lkSelfRedLeft],
    cBlue: [lkSelfBlueRight, lkSelfBlueLeft],
    cGreen: [lkSelfGreenRight, lkSelfGreenLeft],
    cYellow: [lkSelfYellowRight, lkSelfYellowLeft],
    cBlack: [lkSelfBlackRight, lkSelfBlackLeft],
    cSilver: [lkSelfSilverRight, lkSelfSilverLeft],
    cIvory: [lkSelfIvoryRight, lkSelfIvoryLeft],
    cPink: [lkSelfPinkRight, lkSelfPinkLeft],
    cUmber: [lkSelfUmberRight, lkSelfUmberLeft],
    cRust: [lkSelfRustRight, lkSelfRustLeft],
    cOrange: [lkSelfOrangeRight, lkSelfOrangeLeft],
    cPlum: [lkSelfPlumRight, lkSelfPlumLeft],
    cLime: [lkSelfLimeRight, lkSelfLimeLeft],
    cNavy: [lkSelfNavyRight, lkSelfNavyLeft],
    cAzure: [lkSelfAzureRight, lkSelfAzureLeft],
    cPeach: [lkSelfPeachRight, lkSelfPeachLeft]]
  IdentityKinds* = [
    cRed: lkIdentityRed, cBlue: lkIdentityBlue,
    cGreen: lkIdentityGreen, cYellow: lkIdentityYellow,
    cBlack: lkIdentityBlack, cSilver: lkIdentitySilver,
    cIvory: lkIdentityIvory, cPink: lkIdentityPink,
    cUmber: lkIdentityUmber, cRust: lkIdentityRust,
    cOrange: lkIdentityOrange, cPlum: lkIdentityPlum,
    cLime: lkIdentityLime, cNavy: lkIdentityNavy,
    cAzure: lkIdentityAzure, cPeach: lkIdentityPeach]
  ScoreKinds* = [
    cRed: lkScoreRed, cBlue: lkScoreBlue,
    cGreen: lkScoreGreen, cYellow: lkScoreYellow,
    cBlack: lkScoreBlack, cSilver: lkScoreSilver,
    cIvory: lkScoreIvory, cPink: lkScorePink,
    cUmber: lkScoreUmber, cRust: lkScoreRust,
    cOrange: lkScoreOrange, cPlum: lkScorePlum,
    cLime: lkScoreLime, cNavy: lkScoreNavy,
    cAzure: lkScoreAzure, cPeach: lkScorePeach]
  ShoutKinds* = [
    cRed: lkShoutRed, cBlue: lkShoutBlue,
    cGreen: lkShoutGreen, cYellow: lkShoutYellow,
    cBlack: lkShoutBlack, cSilver: lkShoutSilver,
    cIvory: lkShoutIvory, cPink: lkShoutPink,
    cUmber: lkShoutUmber, cRust: lkShoutRust,
    cOrange: lkShoutOrange, cPlum: lkShoutPlum,
    cLime: lkShoutLime, cNavy: lkShoutNavy,
    cAzure: lkShoutAzure, cPeach: lkShoutPeach]
  FlagKinds* = [
    cRed: lkFlagRed, cBlue: lkFlagBlue,
    cGreen: lkFlagGreen, cYellow: lkFlagYellow,
    cBlack: lkOther, cSilver: lkOther, cIvory: lkOther, cPink: lkOther,
    cUmber: lkOther, cRust: lkOther, cOrange: lkOther, cPlum: lkOther,
    cLime: lkOther, cNavy: lkOther, cAzure: lkOther, cPeach: lkOther]
  FlagPlantedKinds* = [
    cRed: lkFlagPlantedRed, cBlue: lkFlagPlantedBlue,
    cGreen: lkFlagPlantedGreen, cYellow: lkFlagPlantedYellow,
    cBlack: lkOther, cSilver: lkOther, cIvory: lkOther, cPink: lkOther,
    cUmber: lkOther, cRust: lkOther, cOrange: lkOther, cPlum: lkOther,
    cLime: lkOther, cNavy: lkOther, cAzure: lkOther, cPeach: lkOther]

  LabelScorePrefixes* = [
    cRed: "team score " & ColourNames[cRed].toUpperAscii() & " ",
    cBlue: "team score " & ColourNames[cBlue].toUpperAscii() & " ",
    cGreen: "team score " & ColourNames[cGreen].toUpperAscii() & " ",
    cYellow: "team score " & ColourNames[cYellow].toUpperAscii() & " ",
    cBlack: "team score " & ColourNames[cBlack].toUpperAscii() & " ",
    cSilver: "team score " & ColourNames[cSilver].toUpperAscii() & " ",
    cIvory: "team score " & ColourNames[cIvory].toUpperAscii() & " ",
    cPink: "team score " & ColourNames[cPink].toUpperAscii() & " ",
    cUmber: "team score " & ColourNames[cUmber].toUpperAscii() & " ",
    cRust: "team score " & ColourNames[cRust].toUpperAscii() & " ",
    cOrange: "team score " & ColourNames[cOrange].toUpperAscii() & " ",
    cPlum: "team score " & ColourNames[cPlum].toUpperAscii() & " ",
    cLime: "team score " & ColourNames[cLime].toUpperAscii() & " ",
    cNavy: "team score " & ColourNames[cNavy].toUpperAscii() & " ",
    cAzure: "team score " & ColourNames[cAzure].toUpperAscii() & " ",
    cPeach: "team score " & ColourNames[cPeach].toUpperAscii() & " "]
    ## The map-wide kill totals, `team score <TEAM> <k>/<d>`, one chip per
    ## ACTIVE team. Spectator chrome rather than contract vocabulary, so it is
    ## not in `labels.nim` — but the scoreboard is drawn with no fog test at
    ## all, which makes it the one count of the fighting that is true across
    ## the whole map.

const
  # `case` needs compile-time constants, and these are the interpolated labels
  # spelled out. Built from labels.nim's own procs, so a rename there reaches
  # here.
  PlayerLabelsRight = [
    cRed: labelPlayer(ColourNames[cRed], LabelSideRight),
    cBlue: labelPlayer(ColourNames[cBlue], LabelSideRight),
    cGreen: labelPlayer(ColourNames[cGreen], LabelSideRight),
    cYellow: labelPlayer(ColourNames[cYellow], LabelSideRight),
    cBlack: labelPlayer(ColourNames[cBlack], LabelSideRight),
    cSilver: labelPlayer(ColourNames[cSilver], LabelSideRight),
    cIvory: labelPlayer(ColourNames[cIvory], LabelSideRight),
    cPink: labelPlayer(ColourNames[cPink], LabelSideRight),
    cUmber: labelPlayer(ColourNames[cUmber], LabelSideRight),
    cRust: labelPlayer(ColourNames[cRust], LabelSideRight),
    cOrange: labelPlayer(ColourNames[cOrange], LabelSideRight),
    cPlum: labelPlayer(ColourNames[cPlum], LabelSideRight),
    cLime: labelPlayer(ColourNames[cLime], LabelSideRight),
    cNavy: labelPlayer(ColourNames[cNavy], LabelSideRight),
    cAzure: labelPlayer(ColourNames[cAzure], LabelSideRight),
    cPeach: labelPlayer(ColourNames[cPeach], LabelSideRight)]
  PlayerLabelsLeft = [
    cRed: labelPlayer(ColourNames[cRed], LabelSideLeft),
    cBlue: labelPlayer(ColourNames[cBlue], LabelSideLeft),
    cGreen: labelPlayer(ColourNames[cGreen], LabelSideLeft),
    cYellow: labelPlayer(ColourNames[cYellow], LabelSideLeft),
    cBlack: labelPlayer(ColourNames[cBlack], LabelSideLeft),
    cSilver: labelPlayer(ColourNames[cSilver], LabelSideLeft),
    cIvory: labelPlayer(ColourNames[cIvory], LabelSideLeft),
    cPink: labelPlayer(ColourNames[cPink], LabelSideLeft),
    cUmber: labelPlayer(ColourNames[cUmber], LabelSideLeft),
    cRust: labelPlayer(ColourNames[cRust], LabelSideLeft),
    cOrange: labelPlayer(ColourNames[cOrange], LabelSideLeft),
    cPlum: labelPlayer(ColourNames[cPlum], LabelSideLeft),
    cLime: labelPlayer(ColourNames[cLime], LabelSideLeft),
    cNavy: labelPlayer(ColourNames[cNavy], LabelSideLeft),
    cAzure: labelPlayer(ColourNames[cAzure], LabelSideLeft),
    cPeach: labelPlayer(ColourNames[cPeach], LabelSideLeft)]
  SelfLabelsRight = [
    cRed: labelSelf(ColourNames[cRed], LabelSideRight),
    cBlue: labelSelf(ColourNames[cBlue], LabelSideRight),
    cGreen: labelSelf(ColourNames[cGreen], LabelSideRight),
    cYellow: labelSelf(ColourNames[cYellow], LabelSideRight),
    cBlack: labelSelf(ColourNames[cBlack], LabelSideRight),
    cSilver: labelSelf(ColourNames[cSilver], LabelSideRight),
    cIvory: labelSelf(ColourNames[cIvory], LabelSideRight),
    cPink: labelSelf(ColourNames[cPink], LabelSideRight),
    cUmber: labelSelf(ColourNames[cUmber], LabelSideRight),
    cRust: labelSelf(ColourNames[cRust], LabelSideRight),
    cOrange: labelSelf(ColourNames[cOrange], LabelSideRight),
    cPlum: labelSelf(ColourNames[cPlum], LabelSideRight),
    cLime: labelSelf(ColourNames[cLime], LabelSideRight),
    cNavy: labelSelf(ColourNames[cNavy], LabelSideRight),
    cAzure: labelSelf(ColourNames[cAzure], LabelSideRight),
    cPeach: labelSelf(ColourNames[cPeach], LabelSideRight)]
  SelfLabelsLeft = [
    cRed: labelSelf(ColourNames[cRed], LabelSideLeft),
    cBlue: labelSelf(ColourNames[cBlue], LabelSideLeft),
    cGreen: labelSelf(ColourNames[cGreen], LabelSideLeft),
    cYellow: labelSelf(ColourNames[cYellow], LabelSideLeft),
    cBlack: labelSelf(ColourNames[cBlack], LabelSideLeft),
    cSilver: labelSelf(ColourNames[cSilver], LabelSideLeft),
    cIvory: labelSelf(ColourNames[cIvory], LabelSideLeft),
    cPink: labelSelf(ColourNames[cPink], LabelSideLeft),
    cUmber: labelSelf(ColourNames[cUmber], LabelSideLeft),
    cRust: labelSelf(ColourNames[cRust], LabelSideLeft),
    cOrange: labelSelf(ColourNames[cOrange], LabelSideLeft),
    cPlum: labelSelf(ColourNames[cPlum], LabelSideLeft),
    cLime: labelSelf(ColourNames[cLime], LabelSideLeft),
    cNavy: labelSelf(ColourNames[cNavy], LabelSideLeft),
    cAzure: labelSelf(ColourNames[cAzure], LabelSideLeft),
    cPeach: labelSelf(ColourNames[cPeach], LabelSideLeft)]
  LblFlagRed = labelFlag(ColourNames[cRed])
  LblFlagBlue = labelFlag(ColourNames[cBlue])
  LblFlagGreen = labelFlag(ColourNames[cGreen])
  LblFlagYellow = labelFlag(ColourNames[cYellow])
  LblFlagPlantedRed = labelFlagPlanted(ColourNames[cRed])
  LblFlagPlantedBlue = labelFlagPlanted(ColourNames[cBlue])
  LblFlagPlantedGreen = labelFlagPlanted(ColourNames[cGreen])
  LblFlagPlantedYellow = labelFlagPlanted(ColourNames[cYellow])
  LblHp1 = labelHp(1, 3)
  LblHp2 = labelHp(2, 3)
  LblHp3 = labelHp(3, 3)
  IdentityLabelPrefixes = [
    cRed: LabelPrefixIdentity & ColourNames[cRed] & " ",
    cBlue: LabelPrefixIdentity & ColourNames[cBlue] & " ",
    cGreen: LabelPrefixIdentity & ColourNames[cGreen] & " ",
    cYellow: LabelPrefixIdentity & ColourNames[cYellow] & " ",
    cBlack: LabelPrefixIdentity & ColourNames[cBlack] & " ",
    cSilver: LabelPrefixIdentity & ColourNames[cSilver] & " ",
    cIvory: LabelPrefixIdentity & ColourNames[cIvory] & " ",
    cPink: LabelPrefixIdentity & ColourNames[cPink] & " ",
    cUmber: LabelPrefixIdentity & ColourNames[cUmber] & " ",
    cRust: LabelPrefixIdentity & ColourNames[cRust] & " ",
    cOrange: LabelPrefixIdentity & ColourNames[cOrange] & " ",
    cPlum: LabelPrefixIdentity & ColourNames[cPlum] & " ",
    cLime: LabelPrefixIdentity & ColourNames[cLime] & " ",
    cNavy: LabelPrefixIdentity & ColourNames[cNavy] & " ",
    cAzure: LabelPrefixIdentity & ColourNames[cAzure] & " ",
    cPeach: LabelPrefixIdentity & ColourNames[cPeach] & " "]
  ShoutLabelPrefixes = [
    cRed: labelShoutPrefix(ColourNames[cRed]),
    cBlue: labelShoutPrefix(ColourNames[cBlue]),
    cGreen: labelShoutPrefix(ColourNames[cGreen]),
    cYellow: labelShoutPrefix(ColourNames[cYellow]),
    cBlack: labelShoutPrefix(ColourNames[cBlack]),
    cSilver: labelShoutPrefix(ColourNames[cSilver]),
    cIvory: labelShoutPrefix(ColourNames[cIvory]),
    cPink: labelShoutPrefix(ColourNames[cPink]),
    cUmber: labelShoutPrefix(ColourNames[cUmber]),
    cRust: labelShoutPrefix(ColourNames[cRust]),
    cOrange: labelShoutPrefix(ColourNames[cOrange]),
    cPlum: labelShoutPrefix(ColourNames[cPlum]),
    cLime: labelShoutPrefix(ColourNames[cLime]),
    cNavy: labelShoutPrefix(ColourNames[cNavy]),
    cAzure: labelShoutPrefix(ColourNames[cAzure]),
    cPeach: labelShoutPrefix(ColourNames[cPeach])]

proc classify*(label: string): LabelKind =
  ## The family one sprite label belongs to.
  ##
  ## Runs once per sprite definition — never per object, never per query — so
  ## it is free to be a plain string match.
  for c in Colour:
    if label == PlayerLabelsRight[c]:
      return PlayerKinds[c][0]
    if label == PlayerLabelsLeft[c]:
      return PlayerKinds[c][1]
    if label == SelfLabelsRight[c]: return SelfKinds[c][0]
    if label == SelfLabelsLeft[c]: return SelfKinds[c][1]
  case label
  of LabelMedKit: return lkMedKit
  of LabelShield: return lkShield
  of LabelShieldCarried: return lkShieldCarried
  of LabelSprayCan: return lkSprayCan
  of LabelSprayCanCarried: return lkSprayCanCarried
  of LabelGrenade: return lkGrenade
  of LabelGrenadeAir: return lkGrenadeAir
  of LabelGrenadeCarried: return lkGrenadeCarried
  of LabelThrowTarget: return lkThrowTarget
  of LabelShotImpact: return lkShotImpact
  of LabelFireIcon: return lkFireIcon
  of LabelWalkabilityMap: return lkWalkabilityMap
  of LblFlagRed: return lkFlagRed
  of LblFlagBlue: return lkFlagBlue
  of LblFlagGreen: return lkFlagGreen
  of LblFlagYellow: return lkFlagYellow
  of LblFlagPlantedRed: return lkFlagPlantedRed
  of LblFlagPlantedBlue: return lkFlagPlantedBlue
  of LblFlagPlantedGreen: return lkFlagPlantedGreen
  of LblFlagPlantedYellow: return lkFlagPlantedYellow
  of LblHp1: return lkHp1
  of LblHp2: return lkHp2
  of LblHp3: return lkHp3
  else: discard
  # The interpolating families, whose tail changes every time the wearer
  # picks something up or the score moves.
  for c in Colour:
    if label.startsWith(IdentityLabelPrefixes[c]): return IdentityKinds[c]
    if label.startsWith(LabelScorePrefixes[c]): return ScoreKinds[c]
    if label.startsWith(ShoutLabelPrefixes[c]): return ShoutKinds[c]
  if label.startsWith(LabelPrefixHp): return lkHpDynamic
  if label.startsWith(LabelPrefixLives): return lkLives
  if label.startsWith(LabelPrefixGameParams): return lkGameParams
  # `endzone ` also carries the spectator glow overlays
  # (`endzone <color> power <n> band <n>`), which reach no player stream but
  # share the prefix exactly. The kind is the prefix; the SHAPE token is
  # what tells a zone statement from a glow, and perception validates it
  # against labels.nim's closed vocabulary before parsing corners.
  if label.startsWith(LabelPrefixEndzone): return lkEndzone
  if label.startsWith(LabelPrefixZoneNext): return lkZoneNext
  if label.startsWith(LabelPrefixZone): return lkZone
  lkOther
