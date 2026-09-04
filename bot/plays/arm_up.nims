import std/os

let playDir = currentSourcePath().parentDir()

switch("define", "danger")
include "../play.nims"

switch("out", playDir.parentDir() / ".build" / "arm_up.wasm")
switch("nimcache", playDir.parentDir() / ".build" / "arm-up-nimcache")
