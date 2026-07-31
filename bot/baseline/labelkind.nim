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

    # Per-team, per-facing sprites.
    lkPlayerRedRight
    lkPlayerRedLeft
    lkPlayerBlueRight
    lkPlayerBlueLeft
    lkSelfRedRight
    lkSelfRedLeft
    lkSelfBlueRight
    lkSelfBlueLeft

    # The two flags, carried and on their pedestal.
    lkFlagRed
    lkFlagBlue
    lkFlagPlantedRed
    lkFlagPlantedBlue

    # The overhead health bar, one kind per lit-segment count.
    lkHp1
    lkHp2
    lkHp3

    # Families whose TAIL carries data, so the label itself is still read —
    # but only for the few objects in the group, never to find them.
    lkIdentityRed
    lkIdentityBlue
    lkLives
    lkScoreRed
    lkScoreBlue
    lkShoutRed
    lkShoutBlue

const
  LabelScoreRedPrefix* = "team score RED "
    ## The map-wide kill totals, `team score <TEAM> <k>/<d>`. Spectator chrome
    ## rather than contract vocabulary, so it is not in `labels.nim` — but the
    ## scoreboard is drawn with no fog test at all, which makes it the one
    ## count of the fighting that is true across the whole map.
  LabelScoreBluePrefix* = "team score BLUE "

const
  # `case` needs compile-time constants, and these are the interpolated labels
  # spelled out. Built from labels.nim's own procs, so a rename there reaches
  # here.
  LblPlayerRedRight = labelPlayer("red", LabelSideRight)
  LblPlayerRedLeft = labelPlayer("red", LabelSideLeft)
  LblPlayerBlueRight = labelPlayer("blue", LabelSideRight)
  LblPlayerBlueLeft = labelPlayer("blue", LabelSideLeft)
  LblSelfRedRight = labelSelf("red", LabelSideRight)
  LblSelfRedLeft = labelSelf("red", LabelSideLeft)
  LblSelfBlueRight = labelSelf("blue", LabelSideRight)
  LblSelfBlueLeft = labelSelf("blue", LabelSideLeft)
  LblFlagRed = labelFlag("red")
  LblFlagBlue = labelFlag("blue")
  LblFlagPlantedRed = labelFlagPlanted("red")
  LblFlagPlantedBlue = labelFlagPlanted("blue")
  LblHp1 = labelHp(1)
  LblHp2 = labelHp(2)
  LblHp3 = labelHp(3)
  LblIdentityRed = LabelPrefixIdentity & "red "
  LblIdentityBlue = LabelPrefixIdentity & "blue "
  LblShoutRed = labelShoutPrefix("red")
  LblShoutBlue = labelShoutPrefix("blue")

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
  of LblSelfRedRight: lkSelfRedRight
  of LblSelfRedLeft: lkSelfRedLeft
  of LblSelfBlueRight: lkSelfBlueRight
  of LblSelfBlueLeft: lkSelfBlueLeft
  of LblFlagRed: lkFlagRed
  of LblFlagBlue: lkFlagBlue
  of LblFlagPlantedRed: lkFlagPlantedRed
  of LblFlagPlantedBlue: lkFlagPlantedBlue
  of LblHp1: lkHp1
  of LblHp2: lkHp2
  of LblHp3: lkHp3
  else:
    # The interpolating families, whose tail changes every time the wearer
    # picks something up or the score moves.
    if label.startsWith(LblIdentityRed): lkIdentityRed
    elif label.startsWith(LblIdentityBlue): lkIdentityBlue
    elif label.startsWith(LabelPrefixLives): lkLives
    elif label.startsWith(LabelScoreRedPrefix): lkScoreRed
    elif label.startsWith(LabelScoreBluePrefix): lkScoreBlue
    elif label.startsWith(LblShoutRed): lkShoutRed
    elif label.startsWith(LblShoutBlue): lkShoutBlue
    else: lkOther
