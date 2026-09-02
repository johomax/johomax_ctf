import std/os

let playDir = currentSourcePath().parentDir()

switch("define", "danger")
include "../play.nims"

switch("out", playDir.parentDir() / ".build" / "spread_out.wasm")
switch("nimcache", playDir.parentDir() / ".build" / "spread-out-nimcache")
