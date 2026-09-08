#!/usr/bin/env python3
"""Decode the per-tick position stream produced by the engine replay miner.

First re-simulate a format-2 replay with the matching engine checkout:

    tools/extract_events REPLAY --out EVENTS.jsonl --frames POSITIONS.frames

Then export all seats, or one seat, as JSON lines:

    analysis/s2_replay_positions.py POSITIONS.frames [--seat N] [--every N]

The first output row is stream metadata. Remaining rows contain tick, phase,
and seat position/HP/state. Dead or not-yet-joined zero records are retained.
"""

import argparse
import json
import struct
from pathlib import Path


MAGIC = b"CTFFRM01"
HEADER = struct.Struct("<8sHHHH")
FRAME_HEAD = struct.Struct("<IBB")
SEAT = struct.Struct("<hhBBBBBB")
TEAM = struct.Struct("<hhb")


def read_frames(path):
    """Yield metadata, followed by decoded frame dictionaries."""
    data = Path(path).read_bytes()
    if len(data) < HEADER.size:
        raise ValueError(f"{path}: truncated frame header")
    magic, slots, width, height, teams = HEADER.unpack_from(data)
    if magic != MAGIC:
        raise ValueError(f"{path}: expected {MAGIC!r}, found {magic!r}")
    record_size = FRAME_HEAD.size + slots * SEAT.size + teams * TEAM.size
    payload = len(data) - HEADER.size
    if payload % record_size:
        raise ValueError(f"{path}: partial final frame record")
    meta = {
        "type": "metadata",
        "slots": slots,
        "map_width": width,
        "map_height": height,
        "teams": teams,
        "frames": payload // record_size,
    }
    yield meta
    offset = HEADER.size
    while offset < len(data):
        tick, phase, _ = FRAME_HEAD.unpack_from(data, offset)
        cursor = offset + FRAME_HEAD.size
        seats = []
        for seat in range(slots):
            x, y, aim, hp, lives, flags, windup, windup_aim = SEAT.unpack_from(
                data, cursor
            )
            seats.append({
                "seat": seat,
                "x": x,
                "y": y,
                "aim_brads": aim,
                "hp": hp,
                "lives": lives,
                "alive": bool(flags & 1),
                "carrying_flag": bool(flags & 2),
                "has_shield": bool(flags & 4),
                "has_grenade": bool(flags & 8),
                "has_spray": bool(flags & 16),
                "shield_hp_positive": bool(flags & 32),
                "spraying": bool(flags & 64),
                "fire_windup": windup,
                "windup_brads": windup_aim,
            })
            cursor += SEAT.size
        team_flags = []
        for team in range(teams):
            x, y, carrier = TEAM.unpack_from(data, cursor)
            team_flags.append({
                "team": team, "x": x, "y": y, "carrier_seat": carrier
            })
            cursor += TEAM.size
        yield {
            "type": "frame",
            "tick": tick,
            "phase": phase,
            "seats": seats,
            "team_flags": team_flags,
        }
        offset += record_size


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("frames", type=Path)
    parser.add_argument("--seat", type=int, help="emit only this seat")
    parser.add_argument("--every", type=int, default=1,
                        help="emit every Nth matching frame (default: 1)")
    parser.add_argument("--from-tick", type=int, default=0)
    parser.add_argument("--to-tick", type=int)
    args = parser.parse_args()
    if args.every < 1:
        parser.error("--every must be positive")

    for index, row in enumerate(read_frames(args.frames)):
        if row["type"] == "metadata":
            if args.seat is not None and not 0 <= args.seat < row["slots"]:
                parser.error(f"--seat must be between 0 and {row['slots'] - 1}")
            print(json.dumps(row, separators=(",", ":")))
            continue
        if row["tick"] < args.from_tick:
            continue
        if args.to_tick is not None and row["tick"] > args.to_tick:
            continue
        if (index - 1) % args.every:
            continue
        if args.seat is not None:
            row["seat"] = row.pop("seats")[args.seat]
            row.pop("team_flags")
        print(json.dumps(row, separators=(",", ":")))


if __name__ == "__main__":
    main()
