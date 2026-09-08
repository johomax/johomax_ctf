#!/usr/bin/env python3
"""Run and pool local Season-2 play-seat episodes over real WebSockets.

The sandbox that develops this file cannot open sockets.  This driver is for
the human orchestrator: it starts the runtime-enabled engine, gives every duo
(seats k and k+SEATS/2) one bot executable, preserves all process logs, and reduces
the server/bot text into a small JSON record.

Bot specs are executables or ``starter:{aggressive,cautious,collaborative}``.
An optional final ``:N`` is a round-robin weight.  The duo assignment is
rotated by the episode seed so a bot does not permanently own one colour.
``--bot-env-file LABEL=PATH`` adds environment variables only to that bot.
"""

from __future__ import annotations

import argparse
import json
import os
import random
import re
import shutil
import signal
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import quote


REPO = Path(__file__).resolve().parent.parent
DEFAULT_SERVER = Path("/tmp/johomax-ctf-server-runtime2")
DEFAULT_ENGINE = Path("/private/tmp/engine-main-v40")
DEFAULT_CONFIG = Path("/tmp/johomax-s2-config.json")
DEFAULT_PLAYBOOK = REPO / "episodes" / "s2-playbook"
DEFAULT_STARTER_VENV = REPO / "episodes" / "s2-starter-venv" / "bin" / "python"
STARTER_NAMES = {"aggressive", "cautious", "collaborative"}
SEATS = 32  # derived from the config in prepare_config (16 or 32)
DUOS = 16
MIXED = False  # --mixed: deal bots per seat so duos mix policies (hosted distinct_teammates)

WIN_RE = re.compile(r"^\s*([a-z][a-z ]*) win\s*$", re.IGNORECASE | re.MULTILINE)
DEATH_RE = re.compile(
    r"FIRST_LIGHT_ANNOTATION tick=(\d+) seat=(\d+) kind=clear_on_death")
DRAW_RE = re.compile(r"^draw\s*$", re.MULTILINE)
KILL_RE = re.compile(
    r"^\s*([a-z][a-z ]*) killed by ([a-z][a-z ]*)\s*$",
    re.IGNORECASE | re.MULTILINE,
)
MODULE_READY_RE = re.compile(
    r"(?im)^(?:\[s2\] module ready\b|.*\bupload\s+\S+\s+READY:)")
CALL_ACCEPTED_RE = re.compile(r"(?i)\bcall(?:_| )accepted\b")
MODULE_REJECTED_RE = re.compile(
    r"(?i)(?:\bmodule_rejected\b|\bmodule(?:\s+\S+){0,3}\s+"
    r"(?:rejected|refused)\b|\b(?:rejected|refused)\b[^\n]{0,80}\bmodule\b)")
RECONNECT_RE = re.compile(r"(?im)^.*\breconnect(?:ed|ing)?\b.*$")
CONNECTED_RE = re.compile(r"(?im)^connected\s+(?:ws|wss)://")
ENV_KEY_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


class HarnessError(RuntimeError):
    """A user-actionable harness setup or record error."""


@dataclass(frozen=True)
class BotSpec:
    raw: str
    label: str
    kind: str
    target: str
    weight: int


def _normal(value: str) -> str:
    return " ".join(value.strip().lower().split())


def _write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n",
                    encoding="utf-8")


def _read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except FileNotFoundError:
        return ""


def _split_weight(raw: str) -> tuple[str, int]:
    base, separator, suffix = raw.rpartition(":")
    if separator and suffix.isdecimal():
        weight = int(suffix)
        if weight < 1:
            raise HarnessError(f"bot weight must be positive: {raw}")
        if not base:
            raise HarnessError(f"bot spec has no executable before :{suffix}")
        return base, weight
    return raw, 1


def parse_bot_specs(raw_specs: list[str]) -> list[BotSpec]:
    if not raw_specs:
        raise HarnessError("at least one --bot is required")
    parsed: list[BotSpec] = []
    labels: dict[str, str] = {}
    for raw in raw_specs:
        base, weight = _split_weight(raw)
        if base.startswith("starter:"):
            persona = base.split(":", 1)[1]
            if persona not in STARTER_NAMES:
                choices = ", ".join(sorted(STARTER_NAMES))
                raise HarnessError(
                    f"unknown starter {persona!r}; choose {choices}")
            label = f"starter:{persona}"
            spec = BotSpec(raw, label, "starter", persona, weight)
        else:
            executable = shutil.which(base)
            if executable is None:
                candidate = Path(base).expanduser()
                if not candidate.is_absolute():
                    candidate = Path.cwd() / candidate
                if not candidate.is_file() or not os.access(candidate, os.X_OK):
                    raise HarnessError(f"bot is not executable: {base}")
                executable = str(candidate.resolve())
            label = Path(executable).name
            spec = BotSpec(raw, label, "executable", executable, weight)
        previous = labels.get(label)
        identity = f"{spec.kind}:{spec.target}"
        if previous is not None and previous != identity:
            raise HarnessError(
                f"two bots collapse to label {label!r}; give them distinct filenames")
        labels[label] = identity
        parsed.append(spec)
    return parsed


def parse_bot_env_files(raw_files: list[str] | None,
                        specs: list[BotSpec]) -> dict[str, dict[str, str]]:
    labels = {spec.label for spec in specs}
    parsed: dict[str, dict[str, str]] = {}
    for raw in raw_files or []:
        label, separator, raw_path = raw.partition("=")
        if not separator or not label or not raw_path:
            raise HarnessError(
                f"bot env file must be LABEL=PATH: {raw}")
        if label not in labels:
            raise HarnessError(f"bot env file names unknown label: {label}")
        if label in parsed:
            raise HarnessError(f"duplicate bot env file for label: {label}")
        path = Path(raw_path).expanduser()
        if not path.is_absolute():
            path = Path.cwd() / path
        try:
            lines = path.read_text(encoding="utf-8").splitlines()
        except FileNotFoundError as error:
            raise HarnessError(f"bot env file does not exist: {path}") from error
        values: dict[str, str] = {}
        for line_number, line in enumerate(lines, 1):
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            key, equals, value = line.partition("=")
            key = key.strip()
            if not equals or not ENV_KEY_RE.fullmatch(key):
                raise HarnessError(
                    f"invalid environment assignment {path}:{line_number}")
            if key in values:
                raise HarnessError(
                    f"duplicate environment key {key} in {path}")
            if "\x00" in value:
                raise HarnessError(
                    f"environment value contains NUL {path}:{line_number}")
            values[key] = value
        parsed[label] = values
    return parsed


def assignment_for_seed(specs: list[BotSpec], seed: int) -> dict[str, str]:
    """Deal a weighted round-robin cycle, then rotate it through colours."""
    weighted: list[BotSpec] = []
    for layer in range(max(spec.weight for spec in specs)):
        weighted.extend(spec for spec in specs if layer < spec.weight)
    if MIXED:
        # Weights count seats; deal over all seats, rotate by seed, then keep
        # duo partners distinct where the field allows it.
        base = [weighted[index % len(weighted)].label for index in range(SEATS)]
        rotation = seed % SEATS
        labels = [base[(seat + rotation) % SEATS] for seat in range(SEATS)]
        if len({spec.label for spec in specs}) > 1:
            for duo in range(DUOS):
                if labels[duo] == labels[duo + DUOS]:
                    for other in range(DUOS):
                        upper = other + DUOS
                        if (labels[upper] != labels[duo]
                                and labels[duo + DUOS] != labels[other]):
                            labels[duo + DUOS], labels[upper] = labels[upper], labels[duo + DUOS]
                            break
        return {str(seat): labels[seat] for seat in range(SEATS)}
    base = [weighted[index % len(weighted)].label for index in range(DUOS)]
    rotation = seed % DUOS
    duo_labels = [base[(duo + rotation) % DUOS] for duo in range(DUOS)]
    return {
        str(seat): duo_labels[seat % DUOS]
        for seat in range(SEATS)
    }


def prepare_config(source: Path, destination: Path,
                   seed: int | None) -> tuple[dict, int, list[str], list[str]]:
    try:
        config = json.loads(source.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise HarnessError(f"config does not exist: {source}") from error
    except json.JSONDecodeError as error:
        raise HarnessError(f"invalid config JSON {source}: {error}") from error

    slots = config.get("slots")
    tokens = config.get("tokens")
    global SEATS, DUOS
    if not isinstance(slots, list) or len(slots) not in (16, 32):
        raise HarnessError("Season 2 config needs 16 or 32 slots")
    SEATS = len(slots)
    DUOS = SEATS // 2
    if len({s.get("team") for s in slots if isinstance(s, dict)}) == SEATS:
        DUOS = SEATS  # solo seats: every seat is its own team
    if not isinstance(tokens, list) or len(tokens) != SEATS:
        raise HarnessError(f"Season 2 config needs exactly {SEATS} tokens")

    teams: list[str] = []
    for index, slot in enumerate(slots):
        if not isinstance(slot, dict) or not isinstance(slot.get("team"), str):
            raise HarnessError(f"config slot {index} has no team")
        if slot.get("control") != "play":
            raise HarnessError(f"config slot {index} is not control=play")
        teams.append(_normal(slot["team"]))
    for duo in range(DUOS):
        if DUOS < SEATS and teams[duo] != teams[duo + DUOS]:
            raise HarnessError(
                f"seats {duo} and {duo + DUOS} are not the same-team duo")

    if seed is not None:
        config["seed"] = seed
    effective_seed = config.get("seed", 0)
    if not isinstance(effective_seed, int):
        raise HarnessError("config seed must be an integer")
    destination.write_text(
        json.dumps(config, separators=(",", ":")) + "\n", encoding="utf-8")
    return config, effective_seed, teams, [str(token) for token in tokens]


def parse_summary(server_text: str, bot_texts: dict[int, str],
                  assign: dict[str, str], teams: list[str], *,
                  seed: int | None = None, stop_reason: str = "parsed",
                  elapsed_seconds: float | None = None) -> dict:
    """Reduce one server log and its 32 client logs to a stable record."""
    if len(teams) != SEATS:
        raise HarnessError(f"parser expected {SEATS} seat teams")
    if set(assign) != {str(seat) for seat in range(SEATS)}:
        raise HarnessError(f"assignment must contain seats 0..{SEATS - 1}")
    for duo in range(DUOS):
        if DUOS < SEATS and not MIXED and assign[str(duo)] != assign[str(duo + DUOS)]:
            raise HarnessError(f"assignment split duo {duo}/{duo + DUOS}")

    labels = list(dict.fromkeys(assign[str(seat)] for seat in range(SEATS)))
    per_bot = {
        label: {
            "duos": 0,
            "wins": 0,
            "kills": 0,
            "team_kills": 0,
            "deaths": 0,
            "survived": 0,
            "accepted_call_seats": [],
            "module_rejection_seats": [],
            "reconnected_seats": [],
        }
        for label in labels
    }
    team_to_bot: dict[str, str] = {}
    for duo in range(DUOS):
        label = assign[str(duo)]
        per_bot[label]["duos"] += 1
        team_to_bot[_normal(teams[duo])] = label

    # Survival: a seat with no clear-on-death annotation before the final
    # tick was alive when the game ended (zone deaths never print "killed by").
    death_ticks: dict[int, int] = {}
    for tick_text, seat_text in DEATH_RE.findall(server_text):
        seat_index = int(seat_text)
        if seat_index not in death_ticks:
            death_ticks[seat_index] = int(tick_text)
    final_tick = max(death_ticks.values(), default=0)
    draw = bool(DRAW_RE.search(server_text))
    for seat in range(SEATS):
        label = assign[str(seat)]
        died_early = seat in death_ticks and death_ticks[seat] < final_tick
        if not died_early:
            per_bot[label]["survived"] += 1
    winner_matches = WIN_RE.findall(server_text)
    winner_colour = _normal(winner_matches[-1]) if winner_matches else None
    winner_bot = team_to_bot.get(winner_colour) if winner_colour else None
    if winner_bot is not None:
        per_bot[winner_bot]["wins"] = 1

    unknown_colours: set[str] = set()
    kill_lines = 0
    team_kill_lines = 0
    for victim, killer in KILL_RE.findall(server_text):
        kill_lines += 1
        victim_colour = _normal(victim)
        killer_colour = _normal(killer)
        victim_bot = team_to_bot.get(victim_colour)
        killer_bot = team_to_bot.get(killer_colour)
        if victim_bot is None:
            unknown_colours.add(_normal(victim))
        else:
            per_bot[victim_bot]["deaths"] += 1
        if killer_bot is None:
            unknown_colours.add(killer_colour)
        else:
            per_bot[killer_bot]["kills"] += 1
            if killer_colour == victim_colour:
                team_kill_lines += 1
                per_bot[killer_bot]["team_kills"] += 1

    module_ready_lines = 0
    reconnect_events = 0
    accepted_seats: list[int] = []
    rejected_seats: list[int] = []
    reconnected_seats: list[int] = []
    for seat in range(SEATS):
        text = bot_texts.get(seat, "")
        label = assign[str(seat)]
        module_ready_lines += len(MODULE_READY_RE.findall(text))
        if CALL_ACCEPTED_RE.search(text):
            accepted_seats.append(seat)
            per_bot[label]["accepted_call_seats"].append(seat)
        if MODULE_REJECTED_RE.search(text):
            rejected_seats.append(seat)
            per_bot[label]["module_rejection_seats"].append(seat)
        explicit_reconnects = len(RECONNECT_RE.findall(text))
        inferred_reconnects = max(0, len(CONNECTED_RE.findall(text)) - 1)
        seat_reconnects = max(explicit_reconnects, inferred_reconnects)
        reconnect_events += seat_reconnects
        if seat_reconnects:
            reconnected_seats.append(seat)
            per_bot[label]["reconnected_seats"].append(seat)

    game_ticks = None
    tick_patterns = (
        r"Frame pacing:\s*(\d+) playing frames",
        r"game (?:length|ended)[^\n]*?\b(\d+) ticks\b",
        r"\bfinalTick\b[\"':= ]+(\d+)",
    )
    for pattern in tick_patterns:
        matches = re.findall(pattern, server_text, flags=re.IGNORECASE)
        if matches:
            game_ticks = int(matches[-1])
            break
    if game_ticks is None and winner_matches:
        # The hardening server prints its absolute shell tick every playing
        # frame.  Bound the movement lines between start and win so lobby
        # ticks are not mislabeled as match length.
        start_at = server_text.lower().find("game started")
        win_at = list(WIN_RE.finditer(server_text))[-1].start()
        playing_text = server_text[start_at:win_at] if start_at >= 0 else ""
        movement_ticks = [
            int(value) for value in re.findall(
                r"FIRST_LIGHT_MOVEMENT tick=(\d+)", playing_text)
        ]
        if movement_ticks:
            game_ticks = movement_ticks[-1] - movement_ticks[0] + 1

    parse_warnings = []
    if winner_colour is not None and winner_bot is None:
        parse_warnings.append(f"winner colour {winner_colour!r} is not in config")
    if unknown_colours:
        parse_warnings.append(
            "kill colours not in config: " + ", ".join(sorted(unknown_colours)))

    return {
        "schema": 1,
        "seed": seed,
        "stop_reason": stop_reason,
        "completed": winner_colour is not None and winner_bot is not None,
        "game_started": "game started" in server_text.lower(),
        "winner_colour": winner_colour,
        "winner_bot": winner_bot,
        "game_ticks": game_ticks,
        "elapsed_seconds": (
            round(elapsed_seconds, 3) if elapsed_seconds is not None else None),
        "kill_lines": kill_lines,
        "draw": draw,
        "final_death_tick": final_tick,
        "team_kill_lines": team_kill_lines,
        "module_ready_lines": module_ready_lines,
        "call_accepted_seats": accepted_seats,
        "module_rejection_seats": rejected_seats,
        "reconnected_seats": reconnected_seats,
        "reconnect_events": reconnect_events,
        "parse_warnings": parse_warnings,
        "per_bot": per_bot,
    }


def _starter_python(engine: Path) -> Path:
    override = os.environ.get("S2_STARTER_PYTHON")
    candidates = [
        Path(override).expanduser() if override else None,
        DEFAULT_STARTER_VENV,
        engine / "policies" / "poc_llm_policy" / ".venv" / "bin" / "python",
        Path(sys.executable),
    ]
    for candidate in candidates:
        if candidate is None or not candidate.is_file():
            continue
        probe = subprocess.run(
            [str(candidate), "-c", "import websockets"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if probe.returncode == 0:
            return candidate
    raise HarnessError(
        "starters need Python with websockets>=13; run scripts/s2_build_starters.sh")


def _starter_command(spec: BotSpec, engine: Path, python: Path, seat: int,
                     token: str, port: int, playbook: Path) -> list[str]:
    policy = engine / "policies" / "starters" / spec.target / "policy.py"
    if not policy.is_file():
        raise HarnessError(f"starter policy is missing: {policy}")
    if not playbook.is_dir() or not any(playbook.glob("*.wasm")):
        raise HarnessError(
            f"starter playbook is missing in {playbook}; "
            "run scripts/s2_build_starters.sh")
    return [
        str(python), str(policy), "--canned",
        "--host", "127.0.0.1", "--port", str(port),
        "--slot", str(seat), "--token", token,
        "--playbook", str(playbook),
    ]


def _signal_processes(processes: list[subprocess.Popen], sig: signal.Signals) -> None:
    for process in processes:
        if process.poll() is not None:
            continue
        try:
            os.killpg(process.pid, sig)
        except (ProcessLookupError, PermissionError):
            # Not a group leader we may signal (seen when the harness itself
            # runs in a background job): fall back to the process alone.
            try:
                process.send_signal(sig)
            except (ProcessLookupError, PermissionError):
                pass


def _stop_processes(processes: list[subprocess.Popen]) -> None:
    _signal_processes(processes, signal.SIGTERM)
    deadline = time.monotonic() + 3.0
    while time.monotonic() < deadline and any(
            process.poll() is None for process in processes):
        time.sleep(0.05)
    _signal_processes(processes, signal.SIGKILL)
    for process in processes:
        try:
            process.wait(timeout=1)
        except subprocess.TimeoutExpired:
            pass


def _wait_for_server(server: subprocess.Popen, log_path: Path,
                     deadline: float) -> bool:
    ready_deadline = min(deadline, time.monotonic() + 60.0)
    while time.monotonic() < ready_deadline:
        text = _read_text(log_path)
        if "board render caches baked in" in text or "waiting for players:" in text:
            time.sleep(0.2)
            return server.poll() is None
        if server.poll() is not None:
            return False
        time.sleep(0.1)
    return False


def _assert_clean_output(out: Path) -> None:
    if out.exists():
        if not out.is_dir():
            raise HarnessError(f"output path is not a directory: {out}")
        if any(out.iterdir()):
            raise HarnessError(f"output directory is not empty: {out}")
    out.mkdir(parents=True, exist_ok=True)


def run_episode(*, raw_bots: list[str], port: int, seconds: float, out: Path,
                seed: int | None, server_path: Path, engine: Path,
                config_path: Path, playbook: Path = DEFAULT_PLAYBOOK,
                bot_env_files: list[str] | None = None) -> dict:
    if not 1 <= port <= 65535:
        raise HarnessError("port must be in 1..65535")
    if seconds <= 0:
        raise HarnessError("--seconds must be positive")
    if not server_path.is_file() or not os.access(server_path, os.X_OK):
        raise HarnessError(f"server is not executable: {server_path}")
    if not engine.is_dir():
        raise HarnessError(f"engine directory does not exist: {engine}")

    specs = parse_bot_specs(raw_bots)
    bot_env = parse_bot_env_files(bot_env_files, specs)
    by_label = {spec.label: spec for spec in specs}
    starter_specs = [spec for spec in specs if spec.kind == "starter"]
    starter_python = _starter_python(engine) if starter_specs else None
    if starter_specs:
        if not playbook.is_dir() or not any(playbook.glob("*.wasm")):
            raise HarnessError(
                f"starter playbook is missing in {playbook}; "
                "run scripts/s2_build_starters.sh")
        for spec in starter_specs:
            policy = engine / "policies" / "starters" / spec.target / "policy.py"
            if not policy.is_file():
                raise HarnessError(f"starter policy is missing: {policy}")

    out = out.resolve()
    _assert_clean_output(out)
    prepared_config = out / "config.json"
    _, effective_seed, teams, tokens = prepare_config(
        config_path, prepared_config, seed)
    assign = assignment_for_seed(specs, effective_seed)
    _write_json(out / "assign.json", assign)

    server_log_path = out / "server.log"
    server_handle = server_log_path.open("w", encoding="utf-8", buffering=1)
    bot_handles = [
        (out / f"bot_{seat}.log").open("w", encoding="utf-8", buffering=1)
        for seat in range(SEATS)
    ]
    server_env = os.environ.copy()
    server_env.update({
        "COGAME_HOST": "127.0.0.1",
        "COGAME_PORT": str(port),
        "COGAME_CONFIG_URI": prepared_config.as_uri(),
        "COGAME_RESULTS_URI": (out / "results.json").as_uri(),
        "COGAME_SAVE_REPLAY_URI": (out / "replay.bitreplay").as_uri(),
        "COGAME_EVENTS_URI": (out / "events.jsonl").as_uri(),
        "COGAME_METRICS_URI": (out / "metrics.json").as_uri(),
    })
    server_env.pop("COGAME_LOAD_REPLAY_URI", None)

    print(f"seed {effective_seed}: starting server on 127.0.0.1:{port}",
          flush=True)
    started = time.monotonic()
    deadline = started + seconds
    clients: list[subprocess.Popen] = []
    try:
        server = subprocess.Popen(
            [str(server_path)], cwd=engine, env=server_env,
            stdout=server_handle, stderr=subprocess.STDOUT,
            start_new_session=True)
    except OSError as error:
        server_handle.close()
        for handle in bot_handles:
            handle.close()
        raise HarnessError(f"could not start server: {error}") from error
    stop_reason = "server_not_ready"
    try:
        if _wait_for_server(server, server_log_path, deadline):
            for seat in range(SEATS):
                label = assign[str(seat)]
                spec = by_label[label]
                url = (f"ws://127.0.0.1:{port}/player?slot={seat}&token="
                       f"{quote(tokens[seat], safe='')}")
                client_env = os.environ.copy()
                client_env.update(bot_env.get(label, {}))
                client_env["COWORLD_PLAYER_WS_URL"] = url
                if spec.kind == "starter":
                    assert starter_python is not None
                    command = _starter_command(
                        spec, engine, starter_python, seat, tokens[seat], port,
                        playbook.resolve())
                    poc = engine / "policies" / "poc_llm_policy"
                    common = engine / "policies" / "starters" / "common"
                    old_pythonpath = client_env.get("PYTHONPATH")
                    paths = [str(poc), str(common)]
                    if old_pythonpath:
                        paths.append(old_pythonpath)
                    client_env.update({
                        "PYTHONPATH": os.pathsep.join(paths),
                        "POC_CANNED": "1",
                        "POC_HOST": "127.0.0.1",
                        "POC_PORT": str(port),
                        "POC_SLOT": str(seat),
                        "POC_TOKEN": tokens[seat],
                        "POC_PLAYBOOK": str(playbook.resolve()),
                        "PYTHONUNBUFFERED": "1",
                    })
                    cwd = engine
                else:
                    command = [spec.target]
                    cwd = REPO
                clients.append(subprocess.Popen(
                    command, cwd=cwd, env=client_env,
                    stdout=bot_handles[seat], stderr=subprocess.STDOUT,
                    start_new_session=True))
                time.sleep(0.03)

            print(f"seed {effective_seed}: launched {SEATS} clients", flush=True)
            stop_reason = "timeout"
            while time.monotonic() < deadline:
                server_text = _read_text(server_log_path)
                if WIN_RE.search(server_text):
                    stop_reason = "winner"
                    break
                if server.poll() is not None:
                    stop_reason = "server_exited"
                    break
                time.sleep(0.1)
    except KeyboardInterrupt:
        stop_reason = "interrupted"
        raise
    finally:
        early_client_exits = {
            str(seat): process.poll()
            for seat, process in enumerate(clients)
            if process.poll() is not None
        }
        _stop_processes(clients + [server])
        server_handle.close()
        for handle in bot_handles:
            handle.close()

    elapsed = time.monotonic() - started
    bot_texts = {
        seat: _read_text(out / f"bot_{seat}.log") for seat in range(SEATS)
    }
    summary = parse_summary(
        _read_text(server_log_path), bot_texts, assign, teams,
        seed=effective_seed, stop_reason=stop_reason,
        elapsed_seconds=elapsed)
    summary["server_exit_code"] = server.returncode
    summary["client_exit_codes"] = {
        str(seat): process.returncode for seat, process in enumerate(clients)
    }
    summary["clients_exited_before_cleanup"] = early_client_exits
    _write_json(out / "summary.json", summary)
    winner = summary["winner_bot"] or "none"
    print(f"seed {effective_seed}: {stop_reason}; winner {winner}; "
          f"logs {out}", flush=True)
    return summary


def find_summaries(directories: list[Path]) -> list[tuple[Path, dict]]:
    found: dict[Path, dict] = {}
    for directory in directories:
        path = directory.expanduser().resolve()
        if not path.is_dir():
            raise HarnessError(f"pool input is not a directory: {directory}")
        candidates = [path / "summary.json"]
        candidates.extend(sorted(path.glob("*/summary.json")))
        for candidate in candidates:
            if not candidate.is_file():
                continue
            try:
                summary = json.loads(candidate.read_text(encoding="utf-8"))
            except json.JSONDecodeError as error:
                raise HarnessError(f"invalid summary {candidate}: {error}") from error
            if "per_bot" not in summary:
                raise HarnessError(f"not an S2 episode summary: {candidate}")
            found[candidate.resolve()] = summary
    if not found:
        raise HarnessError("no summary.json files found")
    return sorted(found.items(), key=lambda item: str(item[0]))


def _bootstrap_ci(values: list[float], rng: random.Random,
                  draws: int = 10000) -> tuple[float, float]:
    if not values:
        raise HarnessError("cannot bootstrap an empty sample")
    samples = sorted(
        sum(rng.choice(values) for _ in values) / len(values)
        for _ in range(draws)
    )
    return samples[int(0.025 * (draws - 1))], samples[int(0.975 * (draws - 1))]


def pool_summaries(records: list[tuple[Path, dict]]) -> dict:
    usable: list[tuple[Path, dict]] = []
    skipped: list[dict] = []
    for path, summary in records:
        if not summary.get("completed"):
            skipped.append({
                "path": str(path.parent),
                "seed": summary.get("seed"),
                "reason": summary.get("stop_reason", "no winner"),
            })
        else:
            usable.append((path, summary))

    bot_labels = sorted({
        label for _, summary in usable for label in summary["per_bot"]
    })
    metrics = {}
    rng = random.Random(20260901)
    for label in bot_labels:
        rows = [summary["per_bot"][label] for _, summary in usable
                if label in summary["per_bot"]]
        wins = [float(row["wins"]) for row in rows]
        lo, hi = _bootstrap_ci(wins, rng)
        total_duos = sum(row["duos"] for row in rows)
        total_seats = 2 * total_duos
        metrics[label] = {
            "episodes": len(rows),
            "duos_per_episode": total_duos / len(rows),
            "win_share": sum(wins) / len(wins),
            "win_share_ci95": [lo, hi],
            "mean_kills_per_duo": sum(
                row["kills"] / row["duos"] for row in rows) / len(rows),
            "mean_team_kills_per_episode": sum(
                row.get("team_kills", 0) for row in rows) / len(rows),
            "survival_per_seat": sum(
                row.get("survived", 0) / (2 * row["duos"]) for row in rows) / len(rows),
            "accepted_call_rate": sum(
                len(row["accepted_call_seats"]) for row in rows) / total_seats,
            "reconnect_rate": sum(
                len(row["reconnected_seats"]) for row in rows) / total_seats,
        }
    return {
        "schema": 1,
        "episodes_pooled": len(usable),
        "episodes_lost": len(skipped),
        "skipped": skipped,
        "per_bot": metrics,
    }


def print_pool(report: dict, source: str) -> None:
    for skipped in report["skipped"]:
        print(f"SKIPPED seed {skipped['seed']} ({skipped['path']}): "
              f"{skipped['reason']}")
    if report["skipped"]:
        print()
    print(f"source          : {source}")
    print(f"episodes pooled : {report['episodes_pooled']}")
    print(f"episodes lost   : {report['episodes_lost']}")
    if not report["per_bot"]:
        raise HarnessError("no completed episodes survived; nothing to pool")
    print()
    print("bot                         n  duos/ep   win share [95% CI]"
          "       kills/duo  team-kills/ep  survive/seat  accepted  reconnect")
    print("-" * 130)
    for label, row in report["per_bot"].items():
        lo, hi = row["win_share_ci95"]
        print(f"{label:<27} {row['episodes']:>3}  "
              f"{row['duos_per_episode']:>7.2f}   "
              f"{row['win_share']:.4f} [{lo:.4f}, {hi:.4f}]   "
              f"{row['mean_kills_per_duo']:>9.3f}  "
              f"{row['mean_team_kills_per_episode']:>13.3f}  "
              f"{row.get('survival_per_seat', 0.0):>12.3f}  "
              f"{row['accepted_call_rate']:>8.3f}  "
              f"{row['reconnect_rate']:>9.3f}")


def _runtime_options(parser: argparse.ArgumentParser, *,
                     required_timing: bool) -> None:
    parser.add_argument("--port", type=int, required=required_timing,
                        default=None if required_timing else 2015)
    parser.add_argument("--seconds", type=float, required=required_timing,
                        default=None if required_timing else 900.0)
    parser.add_argument("--server", type=Path, default=DEFAULT_SERVER)
    parser.add_argument("--engine", type=Path, default=DEFAULT_ENGINE)
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    parser.add_argument("--playbook", type=Path, default=DEFAULT_PLAYBOOK,
                        help=argparse.SUPPRESS)


def cmd_run(args: argparse.Namespace) -> None:
    run_episode(
        raw_bots=args.bot, port=args.port, seconds=args.seconds, out=args.out,
        seed=args.seed, server_path=args.server.expanduser().resolve(),
        engine=args.engine.expanduser().resolve(),
        config_path=args.config.expanduser().resolve(),
        playbook=args.playbook.expanduser().resolve(),
        bot_env_files=args.bot_env_file)


def cmd_batch(args: argparse.Namespace) -> None:
    if args.episodes < 1:
        raise HarnessError("-n/--episodes must be positive")
    out = args.out.expanduser().resolve()
    _assert_clean_output(out)
    records: list[tuple[Path, dict]] = []
    for index in range(args.episodes):
        seed = args.first_seed + index
        episode_out = out / f"seed_{seed:08d}"
        summary = run_episode(
            raw_bots=args.bot, port=args.port, seconds=args.seconds,
            out=episode_out, seed=seed,
            server_path=args.server.expanduser().resolve(),
            engine=args.engine.expanduser().resolve(),
            config_path=args.config.expanduser().resolve(),
            playbook=args.playbook.expanduser().resolve(),
            bot_env_files=args.bot_env_file)
        records.append((episode_out / "summary.json", summary))
        if index + 1 < args.episodes:
            time.sleep(0.3)
    report = pool_summaries(records)
    _write_json(out / "pool.json", report)
    print()
    print_pool(report, str(out))


def cmd_pool(args: argparse.Namespace) -> None:
    records = find_summaries(args.directories)
    report = pool_summaries(records)
    print_pool(report, ", ".join(str(path) for path in args.directories))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    run = subparsers.add_parser("run", help="run one 32-seat S2 episode")
    run.add_argument("--bot", action="append", required=True,
                     help="executable or starter:NAME, optionally with :WEIGHT")
    run.add_argument("--bot-env-file", action="append", default=[],
                     help="LABEL=PATH assignments applied only to that bot")
    run.add_argument("--mixed", action="store_true", help="deal bots per seat so duo partners differ")
    run.add_argument("--out", type=Path, required=True)
    run.add_argument("--seed", type=int)
    _runtime_options(run, required_timing=True)
    run.set_defaults(func=cmd_run)

    batch = subparsers.add_parser("batch", help="run sequential episodes and pool")
    batch.add_argument("--bot", action="append", required=True,
                       help="executable or starter:NAME, optionally with :WEIGHT")
    batch.add_argument("--bot-env-file", action="append", default=[],
                       help="LABEL=PATH assignments applied only to that bot")
    batch.add_argument("-n", "--episodes", type=int, required=True)
    batch.add_argument("--first-seed", type=int, required=True)
    batch.add_argument("--mixed", action="store_true", help="deal bots per seat so duo partners differ")
    batch.add_argument("--out", type=Path, required=True)
    _runtime_options(batch, required_timing=False)
    batch.set_defaults(func=cmd_batch)

    pool = subparsers.add_parser("pool", help="re-pool saved episode directories")
    pool.add_argument("directories", type=Path, nargs="+")
    pool.set_defaults(func=cmd_pool)

    args = parser.parse_args(argv)
    global MIXED
    MIXED = bool(getattr(args, "mixed", False))
    try:
        args.func(args)
    except HarnessError as error:
        print(f"s2_local: {error}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
