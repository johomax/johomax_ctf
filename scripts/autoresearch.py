#!/usr/bin/env python3
"""The auto-research loop: propose, build, measure, promote, repeat.

One iteration takes one experiment from `scripts/experiments.py`, applies it to
a copy of `bot/`, and measures it against the current tree on the LOCAL
simulator (sim/): both directions of every seed, pooled with the paired-seed
bootstrap. A candidate that survives the screen and the confirmation lands in
`bot/`, is built as a tournament image, uploaded, and submitted with
`--auto-champion always` -- the server's own qualification decides the champion
slot. Nothing here creates hosted Experience Requests; the league is only ever
told about a change after the local mirror has already decided it.

Why local, and what it cannot see. The simulator is the real engine, the real
observation path and two real policy builds in one process (sim/README.md), and
it retires the league-drift rule outright: a seed reproduces an episode to the
hash, and the two directions of a mirror run the SAME seed, so a pair differs
only in which build held which side. What it cannot measure is the standing
field, or a change that is expensive enough to drop frames hosted -- the local
game waits for the policy, the hosted server does not. That is the known blind
spot of every verdict below, accepted for the throughput: episodes here cost
seconds, not the league's eight minutes per forty.

Everything expensive about this problem is a measurement-discipline problem,
so the loop is built around the rules in README.md rather than around the
search:

- **Both directions, always**, same seeds, pooled by `local_sim.verdict` with
  the seats read out of the episode records. RED wins most episodes whatever
  build holds it; a one-direction run reads that as a build effect.
- **A promotion needs a confirmation run.** A marginal call at 80 episodes is
  not a call: a "regression" whose CI barely excluded zero at 80 came back
  level at 160. Anything that separates positive at stage 1 is re-run and
  decided on the pooled ~240.
- **K/D is necessary and not sufficient.** A change can be level on K/D and a
  decisive regression on wins and captures, and the league scores wins, so a
  promotion also requires that neither of those separates negative.
- **A silently unapplied edit is the failure mode to fear**, not a crashing
  one. Every edit must match exactly once before an episode is run, and the
  tournament image is checked for a real binary and smoked in one local
  all-slots episode before it is uploaded.

State lives in `research/state.json` and the record in `research/LEDGER.md`.
Both are committed: the ledger is the loop's memory, and an experiment whose
result nobody wrote down will be run again. Episode records land in
`episodes/` (gitignored -- a run is a record, not source); the seed range in
each filename reproduces the run exactly.

Usage:
  python scripts/autoresearch.py [--max-experiments=N] [--episodes=40]
                                 [--dry-run] [--once]
"""

from __future__ import annotations

import importlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import experiments as cat  # noqa: E402
import local_sim  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
BOT = ROOT / "bot"
RESEARCH = ROOT / "research"
STATE_PATH = RESEARCH / "state.json"
LEDGER_PATH = RESEARCH / "LEDGER.md"

BIN = os.environ.get("COWORLD_BIN", "coworld")
LEAGUE = "league_3243d905-d32d-4ec6-978b-fa94751d4a37"
POLICY_NAME = os.environ.get("CTF_POLICY_NAME", "jordan-ctf-candidate")
WORK = Path(os.environ.get(
    "CTF_WORK_DIR",
    "/tmp/claude-0/-home-user-johomax-ctf/"
    "226011ce-5737-5a27-8c92-56fcef09dedb/scratchpad/autoresearch"))

# Seeds per stage; every seed runs BOTH directions, so the screen buys
# 2*EPISODES episodes. The confirmation buys more than the screen because it
# is the decision that ships: measured on the league, the 95% half-width of a
# pooled K/D gap runs about 0.63/sqrt(episodes), so an 80-episode screen
# resolves 0.070 and the pooled ~240 resolves ~0.04 -- about the size of thing
# worth shipping. (That constant was fitted hosted; the paired-seed design
# here is tighter if anything, and rule 6 is what actually gates.) Captures
# cannot be bought at any plausible n, which is why they only ever veto.
EPISODES = int(os.environ.get("CTF_EPISODES", "40"))
CONFIRM_EPISODES = int(os.environ.get("CTF_CONFIRM_EPISODES", "80"))
EXTEND_EPISODES = int(os.environ.get("CTF_EXTEND_EPISODES", "80"))
# How far from zero a screen result must sit, in standard errors, to be worth
# a confirmation. 0.8 puts the probability that the true effect is positive at
# roughly 79% under a normal approximation -- weak on purpose, because the
# screen is triage and everything it admits still has to separate on the
# pooled sample before it ships.
ESCALATE_Z = 0.8
# A confirmation whose K/D interval misses zero by less than this, with the
# point estimate positive, buys ONE further mirror and is decided at ~400
# episodes. Optional stopping inflates the false-positive rate above the
# nominal 5% and that cost is accepted knowingly: the extension fires at most
# once per experiment and requires the estimate to have been positive at every
# earlier look.
EXTEND_MARGIN = 0.01
# Where the seed cursor starts when state.json has never recorded one. Clear
# of everything the calibration runs and the by-hand sessions used.
FIRST_SEED = 100000
# Simulator throughput knobs. One worker per core minus one keeps the box
# responsive; the driver itself is idle while episodes run.
SIM_WORKERS = int(os.environ.get(
    "CTF_SIM_WORKERS", str(max(1, (os.cpu_count() or 2) - 1))))
TICK_CAP = 20000
# How long to stand off after a generation dies of something that is about
# the moment (a network blip at upload time) rather than about the experiment.
TRANSIENT_PAUSE = 300


def log(msg: str) -> None:
    print(f"[{datetime.now().strftime('%H:%M:%S')}] {msg}", flush=True)


def run(cmd: list[str], **kw) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


def cli(*args: str, attempts: int = 6, timeout: int = 1800) -> str:
    """The coworld CLI, retried: a transient failure must not lose a run.

    Only the shipping path (smoke, upload, submit) goes through here now, but
    the backoff still runs to minutes rather than seconds because the failure
    that actually happens is a 429 from request-rate limiting.
    """
    last = None
    for i in range(attempts):
        p = run([BIN, *args], timeout=timeout)
        if p.returncode == 0:
            return p.stdout
        last = p
        rate_limited = "429" in (p.stderr or "") or "Too Many Requests" in (p.stderr or "")
        delay = min(300, (30 * 2 ** i) if rate_limited else (2 ** i))
        if rate_limited:
            log(f"  rate limited; waiting {delay}s before retrying "
                f"`{' '.join(args[:2])}`")
        time.sleep(delay)
    raise RuntimeError(
        f"coworld {' '.join(args)} failed: {last.stderr[-2000:] if last else ''}")


# --- state ------------------------------------------------------------------

def load_state() -> dict:
    if STATE_PATH.exists():
        return json.loads(STATE_PATH.read_text())
    return {"generation": 0, "baseline": None, "champion": None,
            "done": {}, "queue": [], "in_flight": None}


def save_state(st: dict) -> None:
    RESEARCH.mkdir(exist_ok=True)
    STATE_PATH.write_text(json.dumps(st, indent=2) + "\n")


# --- the candidate tree -----------------------------------------------------

def apply_edits(exp: cat.Experiment, dest: Path) -> list[dict]:
    """Copy `bot/` to `dest` and apply the experiment's edits there.

    The edits are computed against the tree as it reads now and applied to a
    copy, so the git working tree stays clean while a candidate is measured
    and a rejected experiment needs no revert at all. A `find` that does not
    match exactly once aborts: an edit that quietly does nothing is measured
    as "level", which looks like a finished experiment and is not one.
    """
    if dest.exists():
        shutil.rmtree(dest)
    shutil.copytree(BOT, dest)

    edits = list(exp.edits)
    if exp.knob is not None:
        src = (BOT / cat.TUNING).read_text()
        edits.append(cat.knob_edit(src, exp.knob, exp.value))

    for e in edits:
        path = dest / e["file"]
        text = path.read_text()
        hits = text.count(e["find"])
        if hits != 1:
            raise ValueError(
                f"{exp.name}: {e['file']} contains {hits} occurrences of "
                f"{e['find']!r}, expected exactly 1")
        path.write_text(text.replace(e["find"], e["replace"]))
    return edits


# --- local measurement ------------------------------------------------------

def build_sim(name: str, ctx: Path) -> Path:
    """One simulator binary holding the candidate tree and the current tree.

    Its own output and work dir per experiment, so a rebuild can never unlink
    a binary another run is still executing (see build.sh's guard).
    """
    out = WORK / f"{name}-simulate"
    local_sim.build(str(ctx / "baseline"), str(BOT / "baseline"),
                    out=str(out), work=str(WORK / f"{name}-simwork"))
    return out


def run_stage(st: dict, name: str, binary: Path, tag: str,
              n_seeds: int) -> tuple[list[dict], str]:
    """One mirror stage: n fresh seeds, each run in both directions.

    Seeds never repeat across stages or experiments -- the cursor in
    state.json only moves forward -- so pooling a confirmation with its screen
    adds independent seed pairs rather than re-reading the same map draws.
    """
    first = int(st.get("seed_cursor", FIRST_SEED))
    st["seed_cursor"] = first + n_seeds
    save_state(st)
    ab, ba = local_sim.mirrored_assign()
    jobs = [(str(binary), local_sim.DEFAULT_ENGINE, local_sim.LEAGUE_CONFIG,
             s, d, TICK_CAP)
            for s in range(first, first + n_seeds) for d in (ab, ba)]
    log(f"  {name} {tag}: {len(jobs)} episodes "
        f"(seeds {first}..{first + n_seeds - 1}, both directions)")
    records = local_sim.run_many(jobs, SIM_WORKERS, f"{name} {tag}")
    out = ROOT / "episodes" / f"{name}-{tag}-{first}.jsonl"
    out.parent.mkdir(exist_ok=True)
    local_sim.write_records(str(out), records)
    return records, str(out.relative_to(ROOT))


# --- shipping ---------------------------------------------------------------

def build(tag: str, context: Path) -> None:
    """Build the tournament image, and prove it contains a runnable binary.

    The output-name trap in Dockerfile.sandbox produces an image that builds
    cleanly with the SOURCE DIRECTORY copied to /bin/baseline and fails only
    when something runs it, so the check is that /bin/baseline is a regular
    file and that it executes.
    """
    ca = context / "ccr-agent-proxy.crt"
    shutil.copy("/root/.ccr/ca-bundle.crt", ca)   # the CA changes every session
    p = run(["docker", "build", "--network=host",
             "--build-arg", f"PROXY={os.environ.get('HTTPS_PROXY', '')}",
             "-f", "Dockerfile.sandbox", "-t", tag, "."],
            cwd=context, timeout=3600)
    if p.returncode != 0:
        raise RuntimeError(f"docker build failed:\n{p.stdout[-4000:]}\n{p.stderr[-4000:]}")
    chk = run(["docker", "run", "--rm", "--entrypoint", "/bin/sh", tag, "-c",
               "test -f /bin/baseline && test -x /bin/baseline && echo ok"])
    if "ok" not in chk.stdout:
        raise RuntimeError(f"{tag}: /bin/baseline is not an executable file "
                           f"(the Nim output-name trap): {chk.stdout}{chk.stderr}")


def smoke(tag: str, outdir: Path) -> None:
    """One local all-slots episode: does the CONTAINERIZED build play?

    The local simulator already proved the source plays, but the tournament
    image is a different build against a different engine pin (bot/nimby.lock),
    and a container that connects and does nothing would otherwise ride a
    measured improvement straight into the league.
    """
    manifest = next((ROOT / "cwpkg").glob("*/coworld_manifest.json"))
    if outdir.exists():
        shutil.rmtree(outdir)
    p = run([BIN, "run-episode", str(manifest), *([tag] * 16),
             "-o", str(outdir), "-n", "1", "--timeout-seconds", "400"],
            timeout=1800)
    res = outdir / "results.json"
    if not res.exists():
        raise RuntimeError(f"{tag}: local smoke produced no results.json\n"
                           f"{p.stdout[-2000:]}\n{p.stderr[-2000:]}")
    d = json.loads(res.read_text())
    kills = sum(d.get("kills") or [])
    if kills <= 0:
        raise RuntimeError(f"{tag}: local smoke episode recorded {kills} kills; "
                           "the build connected but is not playing")
    log(f"  smoke ok: {kills} kills over 16 seats")


def upload(tag: str, purpose: str) -> str:
    """Upload the image and return the policy ref the SERVER assigned.

    The server picks the next sequential version regardless of the local
    Docker tag, so the returned ref -- not the tag -- is what identifies this
    build from here on.
    """
    out = cli("upload-policy", tag, "-n", POLICY_NAME, "--tag", f"purpose={purpose}")
    m = re.search(rf"({re.escape(POLICY_NAME)}:v\d+)", out)
    if not m:
        raise RuntimeError(f"could not read a policy ref out of: {out!r}")
    return m.group(1)


def submit(ref: str) -> None:
    log(f"  submitting {ref} to the league with --auto-champion always")
    out = cli("submit", ref, "-l", LEAGUE, "--auto-champion", "always",
              "--no-open-browser")
    log(f"  {out.strip().splitlines()[-1] if out.strip() else 'submitted'}")


def ship(exp: cat.Experiment, ctx: Path) -> str:
    """Build, smoke, upload and submit the measured tree. Returns the ref.

    Built from the measured copy rather than from `bot/`, so what ships is
    byte-for-byte what played the mirror -- land() re-applies the same edits
    to the tree, and the CA bundle the sandbox build needs never touches the
    working tree.
    """
    tag = f"ctf-cand:{exp.name}"
    build(tag, ctx)
    smoke(tag, WORK / f"smoke-{exp.name}")
    ref = upload(tag, f"autoresearch-{exp.name}")
    submit(ref)
    return ref


# --- the decision ------------------------------------------------------------

def zscore(gap: dict) -> float:
    """The observed gap in standard errors, recovered from its interval.

    The bootstrap reports a 95% interval rather than a standard error, and a
    95% half-width is 1.96 standard errors, so this reads one off the other.
    It is what lets a single threshold mean the same thing on K/D and on win
    rate, whose units and noise differ by more than an order of magnitude.
    """
    half = (gap["ci_hi"] - gap["ci_lo"]) / 2.0
    return 0.0 if half <= 0 else gap["observed"] / (half / 1.96)


def decide(v: dict, stage: int) -> tuple[str, str]:
    """PROMOTE / ESCALATE / EXTEND / REJECT, and the sentence that says why.

    `v` comes from local_sim.verdict oriented so every gap reads
    (treatment - control).
    """
    kd, wr, cap = v["gaps"]["kd"], v["gaps"]["win_rate"], v["gaps"]["captures"]
    # An improvement is a positive separation on either scored quantity, with
    # neither of the others separating the other way. K/D is the sensitive
    # one -- win rate needs roughly a twelve point gap at n=40 to mean
    # anything -- so it is what usually moves first, but the league scores
    # WINS, and a change that separates on wins is an improvement whatever
    # K/D says about it.
    separates = kd["ci_lo"] > 0 or wr["ci_lo"] > 0
    # What buys a confirmation run. The screen is TRIAGE, not the verdict:
    # escalating claims nothing, and the confirmation is what stops a fake
    # result shipping. So it is tuned not to MISS a real effect, where the
    # verdict is tuned not to admit a false one -- tuning the screen like a
    # verdict is how a real 0.04 gap gets thrown away for looking like a
    # 0.00 one. The bar is scaled to what the run could resolve: each metric
    # gets a pseudo-z so the same rule means the same thing at any episode
    # count. Escalate when neither scored quantity leans against the change
    # and at least one reaches ESCALATE_Z.
    near_miss = (min(zscore(kd), zscore(wr)) >= 0.0
                 and max(zscore(kd), zscore(wr)) >= ESCALATE_Z)
    wins_ok = wr["ci_hi"] > 0
    caps_ok = cap["ci_hi"] > 0
    body = (f"K/D {kd['observed']:+.4f} CI [{kd['ci_lo']:+.4f}, {kd['ci_hi']:+.4f}], "
            f"win rate {wr['observed']:+.3f} CI [{wr['ci_lo']:+.3f}, {wr['ci_hi']:+.3f}], "
            f"captures {cap['observed']:+.0f} CI [{cap['ci_lo']:+.0f}, {cap['ci_hi']:+.0f}], "
            f"n={v['n']}")

    if not wins_ok:
        return "REJECT", f"wins separate NEGATIVE: {body}"
    if not caps_ok:
        return "REJECT", f"captures separate NEGATIVE: {body}"
    if separates:
        if stage == 1:
            return "ESCALATE", f"separates positive at n={v['n']}; confirming: {body}"
        return "PROMOTE", f"separates positive on the pooled sample: {body}"
    if stage == 1 and near_miss:
        return "ESCALATE", f"near miss, buying episodes rather than calling it: {body}"
    if stage == 2 and kd["observed"] > 0 and kd["ci_lo"] > -EXTEND_MARGIN:
        return "EXTEND", (f"confirmation misses zero by "
                          f"{-kd['ci_lo']:.4f} with the estimate positive; "
                          f"one extension: {body}")
    if kd["ci_hi"] < 0:
        return "REJECT", f"REGRESSION: {body}"
    return "REJECT", f"level: {body}"


# --- promotion ---------------------------------------------------------------

def git(*args: str) -> str:
    p = run(["git", *args], cwd=ROOT)
    if p.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)} failed: {p.stderr}")
    return p.stdout


def land(exp: cat.Experiment, edits: list[dict]) -> None:
    """Apply the measured change to `bot/`.

    Re-applied here rather than copied back from the build directory, so what
    gets committed is exactly the edit that was measured, expressed against
    the tree it was measured on.
    """
    for e in edits:
        path = BOT / e["file"]
        text = path.read_text()
        if text.count(e["find"]) != 1:
            raise RuntimeError(f"land {exp.name}: {e['file']} no longer "
                               f"contains {e['find']!r} exactly once")
        path.write_text(text.replace(e["find"], e["replace"]))


# --- the ledger --------------------------------------------------------------

def append_ledger(exp: cat.Experiment, outcome: str, why: str, ref: str,
                  control: str, runs: list[str], v: dict | None) -> None:
    RESEARCH.mkdir(exist_ok=True)
    if not LEDGER_PATH.exists():
        LEDGER_PATH.write_text(LEDGER_HEADER)
    with LEDGER_PATH.open("a") as fh:
        fh.write(f"\n## {exp.name} — {outcome}\n\n")
        fh.write(f"- when: {datetime.now(timezone.utc).isoformat(timespec='seconds')}\n")
        fh.write(f"- change: {describe(exp)}\n")
        fh.write(f"- treatment: `{ref}`  control: `{control}`\n")
        fh.write(f"- episodes: {', '.join('`%s`' % r for r in runs)} "
                 f"(local sim; the seed range in each name reruns it)\n")
        fh.write(f"- verdict: {why}\n")
        if v:
            fh.write(f"- pooled: {v['n']} episodes, "
                     f"{len(v['skipped'])} skipped; RED won "
                     f"{v['red_win_rate']:.1%} of episodes\n")
            for b, s in v["builds"].items():
                fh.write(f"  - `{b}`: K/D {s['kd']:.4f} "
                         f"({s['kills']:.0f}/{s['deaths']:.0f}), "
                         f"captures {s['captures']:.0f}, wins {s['wins']}\n")
        fh.write(f"- rationale: {exp.rationale}\n")


def describe(exp: cat.Experiment) -> str:
    if exp.knob:
        return f"`{exp.knob}` -> `{exp.value}`"
    return "; ".join(f"`{e['file']}`: `{e['find'].strip()}` -> "
                     f"`{e['replace'].strip()}`" for e in exp.edits) or "(no edit)"


LEDGER_HEADER = """# Auto-research ledger

Every experiment the loop has run, in order, with the request ids or local
episode records behind each verdict. Written by `scripts/autoresearch.py`; see
that file for the rules a verdict is reached under, and README.md for why
those are the rules.

A gap is always (treatment - control) and always pooled over both directions
of a mirror. "level" means the 95% bootstrap interval crosses zero, which is a
result: it says the change is not worth shipping, not that the run failed.
"""


# --- one generation ----------------------------------------------------------

def record(exp: cat.Experiment, st: dict, outcome: str, why: str, ref: str,
           control: str, runs: list[str], v: dict | None,
           tree_value: str | None) -> None:
    st["done"][exp.name] = {
        "outcome": outcome, "why": why, "ref": ref, "control": control,
        "records": runs, "kd_gap": (v or {}).get("gaps", {}).get("kd"),
        "when": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    }
    append_ledger(exp, outcome, why, ref, control, runs, v)
    if exp.kind == "knob" and tree_value is not None:
        observed = (v or {}).get("gaps", {}).get("kd", {}).get("observed", 0.0)
        for nxt in cat.followups(exp, outcome.startswith("PROMOTE"),
                                 tree_value, observed, tried_values(st)):
            if nxt.name not in st["done"] and not any(
                    q["name"] == nxt.name for q in st["queue"]):
                st["queue"].append(serialize(nxt))
                log(f"  queued follow-up: {nxt.name}")
    save_state(st)
    commit(exp, outcome, why)


def run_generation(exp: cat.Experiment, st: dict, dry: bool) -> None:
    """Screen one candidate against the tree, confirm it, ship it or drop it.

    One experiment per generation: the batch the hosted loop ran existed to
    keep the league's request queue full, and there is no queue here -- the
    simulator saturates the cores with one experiment's episodes. One change
    landing per generation is unchanged, and is the property that matters:
    individually-level levers stacked into a bundle cost this repository
    0.184 K/D and 37.5 points of win rate.
    """
    control = st["baseline"]
    log(f"=== generation {st['generation']}: {exp.name} ({exp.kind}) "
        f"against {control} ===")
    log(f"  {describe(exp)}")
    WORK.mkdir(parents=True, exist_ok=True)
    ctx = WORK / exp.name

    tree_value = tree_const(exp)
    try:
        edits = apply_edits(exp, ctx)
        log(f"  {len(edits)} edit(s) applied to the build copy")
        if dry:
            for e in edits:
                log(f"    {e['file']}: {e['find'].strip()!r} -> "
                    f"{e['replace'].strip()!r}")
            return
        binary = build_sim(exp.name, ctx)
    except (Exception, SystemExit) as exc:     # noqa: BLE001
        log(f"  {exp.name} ABANDONED: {exc}")
        st["generation"] += 1
        record(exp, st, "ABANDONED", str(exc)[:2000], "-", control, [],
               None, None)
        return

    records: list[dict] = []
    runs: list[str] = []

    def stage(tag: str, n_seeds: int) -> dict:
        recs, path = run_stage(st, exp.name, binary, tag, n_seeds)
        records.extend(recs)
        runs.append(path)
        return local_sim.verdict(records, name_a=exp.name, name_b=control)

    v = stage("s1", EPISODES)
    outcome, why = decide(v, 1)
    log(f"  {exp.name} screen: {outcome} — {why}")
    if outcome == "ESCALATE":
        v = stage("s2", CONFIRM_EPISODES)
        outcome, why = decide(v, 2)
        log(f"  {exp.name} confirm: {outcome} — {why}")
    if outcome == "EXTEND":
        v = stage("s3", EXTEND_EPISODES)
        outcome, why = decide(v, 3)
        log(f"  {exp.name} extend: {outcome} — {why}")

    if outcome != "PROMOTE":
        st["generation"] += 1
        record(exp, st, outcome, why, exp.name, control, runs, v, tree_value)
        return

    # Ship it. The local mirror is the whole measurement; the submission's
    # --auto-champion always leaves the champion slot to the server's own
    # qualification. A shipping failure is a league problem, not a
    # measurement one: the change still lands, the verdict still stands, and
    # re-shipping a landed tree is one command.
    land(exp, edits)
    try:
        ref = ship(exp, ctx)
        st["champion"] = ref
    except (Exception, SystemExit) as exc:     # noqa: BLE001
        ref = f"unshipped:{exp.name}"
        why += f"; SHIP FAILED (the change is landed, ship by hand): {str(exc)[:500]}"
        log(f"  SHIP FAILED: {exc}")
    st["baseline"] = ref
    st["generation"] += 1
    record(exp, st, "PROMOTE", why, ref, control, runs, v, tree_value)


def tried_values(st: dict) -> dict[str, set[float]]:
    """Every knob value already measured, by knob.

    Read from the catalogue rather than the ledger because the ledger stores
    verdicts, not the value each one moved -- and the catalogue is the thing
    that defines what a name means.
    """
    out: dict[str, set[float]] = {}
    for e in list(cat.SEED) + [deserialize(q) for q in st.get("queue", [])]:
        if e.kind == "knob" and e.value is not None and (
                e.name in st.get("done", {}) or e.name in
                [q["name"] for q in st.get("queue", [])]):
            out.setdefault(e.knob, set()).add(float(e.value))
    return out


def tree_const(exp: cat.Experiment) -> str | None:
    """The constant's current literal, read before anything lands.

    land() rewrites it, and a follow-up computed against the new value would
    step by zero and vanish.
    """
    if exp.kind != "knob":
        return None
    return cat.read_const((BOT / cat.TUNING).read_text(), exp.knob)


def serialize(e: cat.Experiment) -> dict:
    return {"name": e.name, "rationale": e.rationale, "knob": e.knob,
            "value": e.value, "edits": e.edits, "parent": e.parent}


def deserialize(d: dict) -> cat.Experiment:
    return cat.Experiment(**d)


def push() -> None:
    """Best-effort push of whatever has just been committed.

    The loop runs for hours and the container is not permanent; a verdict that
    exists only on this disk is a verdict that can be lost. A push that fails
    is not worth ending an experiment over, so this retries a little and then
    gives up quietly -- the next commit will carry it.
    """
    branch = git("rev-parse", "--abbrev-ref", "HEAD").strip()
    for i in range(3):
        if run(["git", "push", "-q", "origin", branch], cwd=ROOT).returncode == 0:
            return
        time.sleep(2 ** i)
    log("  push failed; the commit is local until the next one succeeds")


TRAILER = ("Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>\n"
           "Claude-Session: https://claude.ai/code/"
           "session_013PzLZeXcWrt1r7kztHrhd3")


def commit(exp: cat.Experiment, outcome: str, why: str) -> None:
    # Stage the ledger always and `bot/` only on a promotion. Nothing else:
    # the loop runs for hours unattended and must never sweep up an unrelated
    # edit somebody is in the middle of making.
    paths = ["research"] + (["bot"] if outcome.startswith("PROMOTE") else [])
    git("add", "-A", *paths)
    if not run(["git", "diff", "--cached", "--quiet"], cwd=ROOT).returncode:
        return                                   # nothing staged, nothing to say
    subject = {
        "PROMOTE": f"Promote {exp.name}: shipped with auto-champion",
        "REJECT": f"{exp.name} does not improve the policy",
    }.get(outcome, f"{exp.name}: {outcome}")
    body = f"{why}\n\n{exp.rationale}\n"
    run(["git", "commit", "-m", subject[:72], "-m", body, "-m", TRAILER],
        cwd=ROOT)
    push()


# --- the loop ----------------------------------------------------------------

def next_experiment(st: dict) -> cat.Experiment | None:
    while st["queue"]:
        e = deserialize(st["queue"].pop(0))
        if e.name not in st["done"]:
            return e
    for e in cat.SEED:
        if e.name not in st["done"]:
            return e
    return None


def main() -> None:
    dry = "--dry-run" in sys.argv
    once = "--once" in sys.argv
    limit = next((int(a.split("=", 1)[1]) for a in sys.argv
                  if a.startswith("--max-experiments")), 1000)
    global EPISODES, CONFIRM_EPISODES
    for a in sys.argv:
        if a.startswith("--episodes"):
            EPISODES = int(a.split("=", 1)[1])
        elif a.startswith("--confirm-episodes"):
            CONFIRM_EPISODES = int(a.split("=", 1)[1])

    st = load_state()
    if not st.get("baseline"):
        sys.exit("research/state.json has no baseline policy ref; seed it with "
                 "the build every experiment is measured against")
    if not os.path.isdir(os.path.join(local_sim.DEFAULT_ENGINE, "src", "ctf")):
        sys.exit("no engine checkout -- run sim/bootstrap.sh first, then "
                 "scripts/local_sim.py selfcheck")

    ran = 0
    while ran < limit:
        # Re-read the catalogue every generation. The loop runs for hours and
        # the most useful thing to do with a result is to queue the experiment
        # it suggests, which should not mean waiting for the queue to drain
        # first.
        importlib.reload(cat)
        exp = next_experiment(st)
        if exp is None:
            log("queue empty — nothing left to measure")
            return
        try:
            run_generation(exp, st, dry)
        except (Exception, SystemExit) as exc:     # noqa: BLE001
            # SystemExit explicitly: it is not an Exception, and a library
            # function that calls sys.exit would otherwise end the loop rather
            # than the generation. A generation can die for two very different
            # reasons: a driver fault is about the experiment, a network blip
            # at ship time is about the moment. Requeue on the second kind.
            transient = any(k in str(exc) for k in
                            ("429", "Too Many Requests", "timed out", "Timeout",
                             "Connection", "502", "503", "504"))
            log(f"  generation {'INTERRUPTED' if transient else 'ABANDONED'}: {exc}")
            if transient:
                if exp.name not in st["done"]:
                    st["queue"].insert(0, serialize(exp))
                save_state(st)
                log(f"  {exp.name} requeued; pausing {TRANSIENT_PAUSE}s")
                time.sleep(TRANSIENT_PAUSE)
                continue
            if exp.name not in st["done"]:
                st["done"][exp.name] = {
                    "outcome": "ABANDONED", "why": str(exc)[:2000],
                    "when": datetime.now(timezone.utc).isoformat(
                        timespec="seconds")}
                save_state(st)
        if dry:
            st["done"].setdefault(exp.name, {"outcome": "DRY"})
        ran += 1
        if once:
            return


if __name__ == "__main__":
    main()
