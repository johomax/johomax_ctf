import std/unittest

include ../baseline/shell_seat

proc recipeSeat(slot: int; names: seq[string]): ShellSeat =
  ShellSeat(slot: slot, rosterNames: names)

suite "Season 2 recipe roster references":
  test "matches names case-insensitively and excludes self":
    let seat = recipeSeat(2,
      @["Alpha BETA One", "beta Two", "alpha Self", "Unmatched"])
    let call =
      "{\"plays\":[{\"play\":\"pact\",\"params\":{\"partners\":[" &
      "\"seat:31\",\"$NAMES: alpha | beta \"]}}]}"

    check seat.substituteRecipeRefs(call) ==
      "{\"plays\":[{\"params\":{\"partners\":[" &
      "\"seat:31\",\"seat:0\",\"seat:1\"]},\"play\":\"pact\"}]}"

  test "caps matching seats at eight in seat order":
    let seat = recipeSeat(15, @[
      "match 0", "match 1", "match 2", "match 3", "match 4",
      "match 5", "match 6", "match 7", "match 8", "match 9"])
    let call =
      "{\"plays\":[{\"play\":\"pact\",\"params\":{\"partners\":[\"$NAMES:MATCH\"]}}]}"

    check seat.substituteRecipeRefs(call) ==
      "{\"plays\":[{\"params\":{\"partners\":[" &
      "\"seat:0\",\"seat:1\",\"seat:2\",\"seat:3\",\"seat:4\",\"seat:5\"," &
      "\"seat:6\",\"seat:7\"]},\"play\":\"pact\"}]}"

  test "empty matches drop pact plays and target law never keys":
    let seat = recipeSeat(0, @["Self", "Someone Else"])
    let call =
      "{\"plays\":[{\"play\":\"pact\",\"params\":{\"partners\":[" &
      "\"$NAMES:missing\"]}},{\"play\":\"target_law\",\"params\":{\"never\":[" &
      "\"$NAMES:missing\"],\"prefer\":[\"weakened\"]}}]}"

    check seat.substituteRecipeRefs(call) ==
      "{\"plays\":[{\"params\":{\"prefer\":[\"weakened\"]},\"play\":\"target_law\"}]}"
