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
## engine's four team colours in its own seat-deal order. The policy's own
## two-sided `world.Team` is a different thing and stays there; what belongs
## here is the colour a label is spelled with, and there are four of them.
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
    ## The wire's four team colours, IN THE ENGINE'S OWN SEAT-DEAL ORDER.
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

    # Per-colour, per-facing sprites. All FOUR colours have arms, not just
    # the classic pair: on a four-team board a missing arm classifies a real
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
    lkSelfRedRight
    lkSelfRedLeft
    lkSelfBlueRight
    lkSelfBlueLeft
    lkSelfGreenRight
    lkSelfGreenLeft
    lkSelfYellowRight
    lkSelfYellowLeft

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

    # The episode's stated setup, invisible 1x1 markers in the init snapshot
    # that persist all match (they are never listed in the server's per-frame
    # object diff, so nothing ever reaps them).
    lkGameParams
    lkEndzone

    # Families whose TAIL carries data, so the label itself is still read —
    # but only for the few objects in the group, never to find them.
    lkIdentityRed
    lkIdentityBlue
    lkIdentityGreen
    lkIdentityYellow
    lkLives
    lkScoreRed
    lkScoreBlue
    lkScoreGreen
    lkScoreYellow
    lkShoutRed
    lkShoutBlue
    lkShoutGreen
    lkShoutYellow

const LabelHpBarSegments* = 3
  ## The overhead bar's lit-segment count this policy still scans by exact
  ## match (`hp 1/3` .. `hp 3/3`). Upstream retired its own constant when the
  ## label grew a live denominator and a ` shield <s>` tail; a proper prefix
  ## parse of `hp <hp>/<max>[ shield <s>]` is pending (see perception.nim).

const ColourNames* = [
  cRed: "red", cBlue: "blue", cGreen: "green", cYellow: "yellow"]
  ## The wire token for each colour — the engine's `teamText`. Every label
  ## spelled per colour below goes through this, so the four families cannot
  ## disagree with each other about how a colour is written.

const
  LabelScorePrefixes* = [
    cRed: "team score " & ColourNames[cRed].toUpperAscii() & " ",
    cBlue: "team score " & ColourNames[cBlue].toUpperAscii() & " ",
    cGreen: "team score " & ColourNames[cGreen].toUpperAscii() & " ",
    cYellow: "team score " & ColourNames[cYellow].toUpperAscii() & " "]
    ## The map-wide kill totals, `team score <TEAM> <k>/<d>`, one chip per
    ## ACTIVE team. Spectator chrome rather than contract vocabulary, so it is
    ## not in `labels.nim` — but the scoreboard is drawn with no fog test at
    ## all, which makes it the one count of the fighting that is true across
    ## the whole map.

const
  # `case` needs compile-time constants, and these are the interpolated labels
  # spelled out. Built from labels.nim's own procs, so a rename there reaches
  # here.
  LblPlayerRedRight = labelPlayer(ColourNames[cRed], LabelSideRight)
  LblPlayerRedLeft = labelPlayer(ColourNames[cRed], LabelSideLeft)
  LblPlayerBlueRight = labelPlayer(ColourNames[cBlue], LabelSideRight)
  LblPlayerBlueLeft = labelPlayer(ColourNames[cBlue], LabelSideLeft)
  LblPlayerGreenRight = labelPlayer(ColourNames[cGreen], LabelSideRight)
  LblPlayerGreenLeft = labelPlayer(ColourNames[cGreen], LabelSideLeft)
  LblPlayerYellowRight = labelPlayer(ColourNames[cYellow], LabelSideRight)
  LblPlayerYellowLeft = labelPlayer(ColourNames[cYellow], LabelSideLeft)
  LblSelfRedRight = labelSelf(ColourNames[cRed], LabelSideRight)
  LblSelfRedLeft = labelSelf(ColourNames[cRed], LabelSideLeft)
  LblSelfBlueRight = labelSelf(ColourNames[cBlue], LabelSideRight)
  LblSelfBlueLeft = labelSelf(ColourNames[cBlue], LabelSideLeft)
  LblSelfGreenRight = labelSelf(ColourNames[cGreen], LabelSideRight)
  LblSelfGreenLeft = labelSelf(ColourNames[cGreen], LabelSideLeft)
  LblSelfYellowRight = labelSelf(ColourNames[cYellow], LabelSideRight)
  LblSelfYellowLeft = labelSelf(ColourNames[cYellow], LabelSideLeft)
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
  LblIdentityRed = LabelPrefixIdentity & ColourNames[cRed] & " "
  LblIdentityBlue = LabelPrefixIdentity & ColourNames[cBlue] & " "
  LblIdentityGreen = LabelPrefixIdentity & ColourNames[cGreen] & " "
  LblIdentityYellow = LabelPrefixIdentity & ColourNames[cYellow] & " "
  LblShoutRed = labelShoutPrefix(ColourNames[cRed])
  LblShoutBlue = labelShoutPrefix(ColourNames[cBlue])
  LblShoutGreen = labelShoutPrefix(ColourNames[cGreen])
  LblShoutYellow = labelShoutPrefix(ColourNames[cYellow])

proc classify*(label: string): LabelKind =
  ## The family one sprite label belongs to.
  ##
  ## Runs once per sprite definition — never per object, never per query — so
  ## it is free to be a plain string match.
  case label
  of LabelMedKit: lkMedKit
  of LabelShield: lkShield
  of LabelShieldCarried: lkShieldCarried
  of LabelSprayCan: lkSprayCan
  of LabelSprayCanCarried: lkSprayCanCarried
  of LabelGrenade: lkGrenade
  of LabelGrenadeAir: lkGrenadeAir
  of LabelGrenadeCarried: lkGrenadeCarried
  of LabelThrowTarget: lkThrowTarget
  of LabelShotImpact: lkShotImpact
  of LabelFireIcon: lkFireIcon
  of LabelWalkabilityMap: lkWalkabilityMap
  of LblPlayerRedRight: lkPlayerRedRight
  of LblPlayerRedLeft: lkPlayerRedLeft
  of LblPlayerBlueRight: lkPlayerBlueRight
  of LblPlayerBlueLeft: lkPlayerBlueLeft
  of LblPlayerGreenRight: lkPlayerGreenRight
  of LblPlayerGreenLeft: lkPlayerGreenLeft
  of LblPlayerYellowRight: lkPlayerYellowRight
  of LblPlayerYellowLeft: lkPlayerYellowLeft
  of LblSelfRedRight: lkSelfRedRight
  of LblSelfRedLeft: lkSelfRedLeft
  of LblSelfBlueRight: lkSelfBlueRight
  of LblSelfBlueLeft: lkSelfBlueLeft
  of LblSelfGreenRight: lkSelfGreenRight
  of LblSelfGreenLeft: lkSelfGreenLeft
  of LblSelfYellowRight: lkSelfYellowRight
  of LblSelfYellowLeft: lkSelfYellowLeft
  of LblFlagRed: lkFlagRed
  of LblFlagBlue: lkFlagBlue
  of LblFlagGreen: lkFlagGreen
  of LblFlagYellow: lkFlagYellow
  of LblFlagPlantedRed: lkFlagPlantedRed
  of LblFlagPlantedBlue: lkFlagPlantedBlue
  of LblFlagPlantedGreen: lkFlagPlantedGreen
  of LblFlagPlantedYellow: lkFlagPlantedYellow
  of LblHp1: lkHp1
  of LblHp2: lkHp2
  of LblHp3: lkHp3
  else:
    # The interpolating families, whose tail changes every time the wearer
    # picks something up or the score moves.
    if label.startsWith(LblIdentityRed): lkIdentityRed
    elif label.startsWith(LblIdentityBlue): lkIdentityBlue
    elif label.startsWith(LblIdentityGreen): lkIdentityGreen
    elif label.startsWith(LblIdentityYellow): lkIdentityYellow
    elif label.startsWith(LabelPrefixLives): lkLives
    elif label.startsWith(LabelScorePrefixes[cRed]): lkScoreRed
    elif label.startsWith(LabelScorePrefixes[cBlue]): lkScoreBlue
    elif label.startsWith(LabelScorePrefixes[cGreen]): lkScoreGreen
    elif label.startsWith(LabelScorePrefixes[cYellow]): lkScoreYellow
    elif label.startsWith(LblShoutRed): lkShoutRed
    elif label.startsWith(LblShoutBlue): lkShoutBlue
    elif label.startsWith(LblShoutGreen): lkShoutGreen
    elif label.startsWith(LblShoutYellow): lkShoutYellow
    elif label.startsWith(LabelPrefixGameParams): lkGameParams
    # `endzone ` also carries the spectator glow overlays
    # (`endzone <color> power <n> band <n>`), which reach no player stream but
    # share the prefix exactly. The kind is the prefix; the SHAPE token is
    # what tells a zone statement from a glow, and perception validates it
    # against labels.nim's closed vocabulary before parsing corners.
    elif label.startsWith(LabelPrefixEndzone): lkEndzone
    else: lkOther
