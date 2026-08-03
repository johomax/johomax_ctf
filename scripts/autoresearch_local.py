#!/usr/bin/env python3
"""The auto-research loop, measured on the local simulator.

Same catalogue, same state, same ledger, same decision rules as
`autoresearch.py` -- what changes is where the episodes come from. A mirror is
no longer a pair of hosted Experience Requests but a seed-paired local run:
one binary holding both trees, every seed played in both directions, pooled
with a bootstrap over seed pairs. The local sim is ~3 orders of magnitude
cheaper per episode than the league, which buys bigger samples, not looser
rules: a CI that crosses zero is still no result.

Validated against the one hosted result that could be replayed: the v66 -> v71
step (NadeFarmReach 420 -> 500) measured +0.0682 [+0.0349, +0.1005] hosted at
n=240 and +0.0945 [+0.0489, +0.1400] here at n=120 -- same sign, overlapping
intervals (episodes/cal-500-vs-420.jsonl).

Promotion ships without a hosted A/B, per the operator's instruction: the
change lands in bot/, the tree is cross-compiled to a static linux/amd64
binary (scripts/build_amd64.sh), smoke-tested under qemu, uploaded without a
Docker daemon (scripts/upload_amd64_policy.py), and submitted with
--auto-champion always. The champion gate of the hosted loop is retired with
it: every promotion is submitted, so the tree and the submitted lineage never
diverge, and the control for the next experiment is always the reigning build.

Usage:
  python scripts/autoresearch_local.py [--max-experiments=N] [--once]
                                       [--dry-run] [--no-submit]
"""

from __future__ import annotations

import importlib
import json
import os
import random
import shutil
import subprocess
import sys
import time
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import experiments as cat            # noqa: E402
import local_sim                     # noqa: E402
from autoresearch import (           # noqa: E402
    apply_edits, describe, deserialize, load_state, log, save_state,
    serialize, tree_const, tried_values, LEAGUE, POLICY_NAME,
)

ROOT = Path(__file__).resolve().parent.parent
BOT = ROOT / "bot"
RESEARCH = ROOT / "research"
LEDGER_PATH = RESEARCH / "LEDGER.md"
EPISODE_DIR = ROOT / "episodes"

# Seeds per stage, one seed = two episodes (both directions). Fitted locally:
# the seed-paired bootstrap half-width runs about 0.50/sqrt(episodes) for K/D,
# so the screen resolves ~0.046 and a screen+confirm pool ~0.025 -- the size
# of thing that has been worth shipping here. Stages draw from disjoint seed
# ranges: pooling a stage with a re-run of itself would count the same
# episodes twice.
SCREEN_SEEDS = int(os.environ.get("CTF_SCREEN_SEEDS", "60"))
CONFIRM_SEEDS = int(os.environ.get("CTF_CONFIRM_SEEDS", "140"))
EXTEND_SEEDS = int(os.environ.get("CTF_EXTEND_SEEDS", "100"))
WORKERS = int(os.environ.get("CTF_SIM_WORKERS", str(local_sim.DEFAULT_WORKERS)))
TICK_CAP = 20000
WORK = Path(os.environ.get("CTF_LOCAL_WORK", "/tmp/ctf-autoresearch-local"))
ENGINE = os.environ.get("CTF_ENGINE_DIR", str(ROOT / ".engine"))
CONFIG = str(ROOT / "sim" / "league_config.json")
UPLOAD_CLI_VERSION = "coworld==0.1.34"

# A candidate whose episodes fail is a driver fault, not a null result: the
# hosted loop's smoke test asked "does this build actually play", and here the
# equivalent evidence is that its episodes finish. Skips above this fraction
# abandon the experiment instead of measuring the survivors.
MAX_SKIP_FRACTION = 0.1

# Practical-significance floors, and why the hosted rules need them here. The
# local mirror is seed-paired: a change the game rarely exercises leaves most
# pairs IDENTICAL, the paired standard error collapses toward zero, and a K/D
# gap of +0.0008 "separates" -- statistically real, competitively nothing,
# and the hosted economics said ~0.03 was the size worth shipping. So a
# separation only escalates or promotes if the point estimate also clears
# these. They are floors on ATTENTION, not on truth: an effect genuinely
# under them is an effect this loop is happy to leave unshipped.
MIN_KD_EFFECT = 0.01
MIN_WR_EFFECT = 0.02

# How far the QUIETER of the two metrics may lean negative, in standard
# errors, without vetoing a near-miss escalation.
#
# The gate used to demand both z-scores be >= 0, and that discarded
# `peek-friendly-corridor`: K/D +0.0413 at z = 1.67 -- twice ESCALATE_Z, an
# interval missing zero by 0.006 -- with captures separating positive at +19
# [+6, +32], killed at the screen because win rate read -0.008 at z = -0.099.
# That win-rate estimate is a twentieth of its own noise (CI +-0.16); calling
# it "leaning the wrong way" reads noise as signal, and it contradicts
# README.md, which says a positive estimate whose interval only just includes
# zero buys the second mirror rather than being called either way.
#
# Half a standard error is the tolerance: it still refuses anything genuinely
# pulling the other way, and a metric that separates negative was already
# REJECTED outright by the two veto tests above, which this does not touch.
# The screen stays triage -- everything it admits must still separate on the
# pooled confirmation, so a looser screen costs episodes, never a promotion.
NEAR_MISS_TOLERANCE = 0.5


def decide(v: dict, stage: int) -> tuple[str, str]:
    """The hosted rules (autoresearch.decide), adjusted for a paired
    instrument. Two changes:

    - A metric only VETOES when its upper bound is strictly negative. The
      hosted `ci_hi > 0` test reads a degenerate zero-width CI at exactly 0
      -- which identical mirrored pairs produce whenever a change rarely
      fires -- as a negative separation, labelling a non-effect a regression.
    - A positive separation must also clear the practical floors before it
      buys episodes or ships, because the collapsed paired standard error can
      make +0.0008 K/D "separate".
    - The near-miss gate lets the QUIETER metric sit slightly negative (see
      NEAR_MISS_TOLERANCE) instead of demanding both be non-negative.
    """
    from autoresearch import ESCALATE_Z, EXTEND_MARGIN, zscore
    kd, wr, cap = v["gaps"]["kd"], v["gaps"]["win_rate"], v["gaps"]["captures"]
    material = (kd["observed"] >= MIN_KD_EFFECT
                or wr["observed"] >= MIN_WR_EFFECT)
    separates = material and (kd["ci_lo"] > 0 or wr["ci_lo"] > 0)
    near_miss = (material
                 and min(zscore(kd), zscore(wr)) >= -NEAR_MISS_TOLERANCE
                 and max(zscore(kd), zscore(wr)) >= ESCALATE_Z)
    body = gap_line(v)

    if wr["ci_hi"] < 0:
        return "REJECT", f"wins separate NEGATIVE: {body}"
    if cap["ci_hi"] < 0:
        return "REJECT", f"captures separate NEGATIVE: {body}"
    if separates:
        if stage == 1:
            return "ESCALATE", f"separates positive at n={v['n']}; confirming: {body}"
        return "PROMOTE", f"separates positive on the pooled sample: {body}"
    if stage == 1 and near_miss:
        return "ESCALATE", f"near miss, buying episodes rather than calling it: {body}"
    if (stage == 2 and kd["observed"] >= MIN_KD_EFFECT
            and kd["ci_lo"] > -EXTEND_MARGIN):
        return "EXTEND", (f"confirmation misses zero by {-kd['ci_lo']:.4f} "
                          f"with a material estimate; one extension: {body}")
    if kd["ci_hi"] < 0:
        return "REJECT", f"REGRESSION: {body}"
    return "REJECT", f"level: {body}"


def run(cmd: list[str], **kw) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


def git(*args: str) -> str:
    p = run(["git", *args], cwd=ROOT)
    if p.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)} failed: {p.stderr}")
    return p.stdout


# --- measurement -------------------------------------------------------------

def build_pair(treatment_tree: Path, control_tree: Path, workdir: Path) -> Path:
    """One simulator binary holding both trees: a = treatment, b = control."""
    binary = workdir / "simulate"
    p = run([str(ROOT / "sim" / "build.sh"), str(treatment_tree),
             str(control_tree), str(binary), str(workdir / "build")],
            timeout=1800)
    if p.returncode != 0:
        raise RuntimeError(f"sim build failed:\n{p.stdout[-3000:]}\n{p.stderr[-3000:]}")
    return binary

def run_mirror(binary: Path, seeds: range, label: str, out: Path) -> list[dict]:
    """Every seed in both directions, appended to `out` as JSONL."""
    ab, ba = local_sim.mirrored_assign()
    jobs = [(str(binary), ENGINE, CONFIG, s, a, TICK_CAP)
            for s in seeds for a in (ab, ba)]
    records = local_sim.run_many(jobs, WORKERS, label)
    out.parent.mkdir(exist_ok=True)
    with out.open("a") as fh:
        for r in records:
            fh.write(json.dumps(r) + "\n")
    return records


def verdict_from_records(records: list[dict]) -> dict:
    """pool_h2h-shaped verdict: gaps read (treatment - control) = (a - b).

    Bootstraps over seed PAIRS -- the two directions of one seed share a
    terrain draw and a spawn layout and are not independent samples.
    """
    ok = [r for r in records if "error" not in r]
    skipped = [r for r in records if "error" in r]
    pairs = defaultdict(list)
    for r in ok:
        pairs[r["seed"]].append(r)
    units = [[local_sim.episode_totals(r) for r in unit]
             for unit in pairs.values()]

    def pool(sample_units):
        eps = [ep for unit in sample_units for ep in unit]
        tot, wins = local_sim.sum_totals(eps)
        return tot, wins, len(eps)

    def gaps(sample_units):
        tot, wins, n = pool(sample_units)
        kd = {b: (tot[b]["kills"] / tot[b]["deaths"] if tot[b]["deaths"] else 0.0)
              for b in ("a", "b")}
        return (kd["a"] - kd["b"],
                (wins["a"] - wins["b"]) / n if n else 0.0,
                tot["a"]["captures"] - tot["b"]["captures"])

    obs = gaps(units)
    rng = random.Random(20260731)
    draws = [gaps([rng.choice(units) for _ in units]) for _ in range(10000)]

    def interval(observed, xs):
        s = sorted(xs)
        lo, hi = s[int(0.025 * len(s))], s[int(0.975 * len(s))]
        return {"observed": observed, "ci_lo": lo, "ci_hi": hi,
                "crosses_zero": lo <= 0 <= hi}

    tot, wins, n = pool(units)
    red_wins = sum(1 for r in ok
                   if not r.get("draw") and r.get("winner") == "red")
    # How the episodes ENDED, which no gap can see. Both builds share one
    # episode and therefore one ending, so the league's timeout penalty
    # cancels exactly in a difference -- and a change that converts a decisive
    # LOSS into a standoff removes a win from the control, reads as a
    # promotion here, and pays nothing hosted (a timeout scores -1, the same
    # as a loss). This records the mix so that a stall-bought promotion is
    # visible in the ledger afterwards instead of indistinguishable from a
    # real one. It feeds no decision: `decide()` never reads it.
    endings: dict[str, int] = defaultdict(int)
    for r in ok:
        endings[r.get("ending", "unknown")] += 1
    return {
        "n": n,
        "endings": dict(endings),
        "skipped": [{"seed": r["seed"], "error": r["error"]} for r in skipped],
        "builds": {
            b: {"kd": (tot[b]["kills"] / tot[b]["deaths"]
                       if tot[b]["deaths"] else 0.0),
                "kills": tot[b]["kills"], "deaths": tot[b]["deaths"],
                "captures": tot[b]["captures"], "wins": wins[b]}
            for b in ("a", "b")
        },
        "red_win_rate": red_wins / n if n else 0.0,
        "gaps": {
            "kd": interval(obs[0], [d[0] for d in draws]),
            "win_rate": interval(obs[1], [d[1] for d in draws]),
            "captures": interval(obs[2], [d[2] for d in draws]),
        },
    }


# --- promotion ---------------------------------------------------------------

def land(exp: cat.Experiment, edits: list[dict]) -> None:
    for e in edits:
        path = BOT / e["file"]
        text = path.read_text()
        if text.count(e["find"]) != 1:
            raise RuntimeError(f"land {exp.name}: {e['file']} no longer "
                               f"contains {e['find']!r} exactly once")
        path.write_text(text.replace(e["find"], e["replace"]))


def smoke_amd64(binary: Path) -> None:
    """The cross-compiled binary must execute on amd64 and reach its socket.

    Run with no websocket URL: the bot's own first act is to demand
    COWORLD_PLAYER_WS_URL, so seeing that error IS the proof that the static
    binary loads and runs its startup path on the target architecture. On an
    arm64 box that needs qemu; on an amd64 box the binary is native.
    """
    cmd = ([str(binary)] if HOST_IS_AMD64
           else ["nix", "shell", "nixpkgs#qemu", "-c", "qemu-x86_64", str(binary)])
    p = run(cmd, timeout=300)
    if "COWORLD_PLAYER_WS_URL" not in (p.stdout + p.stderr):
        raise RuntimeError(
            f"amd64 smoke failed -- expected the WS-URL demand, got:\n"
            f"{p.stdout[-1000:]}\n{p.stderr[-1000:]}")


# The two shipping routes. The BINARY route is the one to want: build the tree
# into a static linux/amd64 executable (scripts/build_amd64.sh, zig cc against
# musl either way), smoke it -- natively on an amd64 box, under qemu on arm64
# -- and push the layer with no daemon at all. The DOCKER route is the
# fallback: build bot/Dockerfile.sandbox, which is the recipe the tournament
# build already uses, and hand the image to the CLI's own `upload-policy`.
# They produce the same policy by different routes; what is installed decides.
#
# The binary route needs the bot's dependency set on disk and a nim + zig from
# somewhere. `nix` supplies both on the sandbox box; a plain Ubuntu box has
# them on PATH instead (nimby installs nim, zig comes from its own tarball),
# which is why this asks what is REACHABLE rather than whether nix exists.
HOST_IS_AMD64 = os.uname().machine in ("x86_64", "amd64")
HAVE_NIX = shutil.which("nix") is not None
BOT_DEPS = Path(os.environ.get("CTF_BOT_DEPS", "/workspace/.bot-deps"))
CAN_BUILD_AMD64 = (BOT_DEPS / "paths.cfg").exists() and (
    HAVE_NIX or (shutil.which("nim") and shutil.which("zig")))


def _cli(*args: str) -> list[str]:
    """Run a uv-provided CLI, through nix when that is how uv is reachable."""
    return (["nix", "shell", "nixpkgs#uv", "-c", *args] if HAVE_NIX
            else list(args))


def ship_docker(name: str) -> str:
    """Build bot/ as a linux/amd64 image and upload it through the CLI.

    Docker's own build is hermetic with respect to this box's Nim toolchain,
    which matters: bot/nimby.lock and sim/engine.pin name DIFFERENT bitworld
    commits, and syncing the bot's lock into the shared package directory
    would silently re-point the simulator's engine mid-experiment.
    """
    # The proxy CA is regenerated every session, so the copy in bot/ is stale
    # by construction and gitignored; refresh it before every build.
    ca = Path("/root/.ccr/ca-bundle.crt")
    if ca.exists():
        shutil.copyfile(ca, BOT / "ccr-agent-proxy.crt")
    else:
        (BOT / "ccr-agent-proxy.crt").write_text("")
    tag = f"ctf-candidate-{name}"
    p = run(["docker", "build", "--network=host",
             "--build-arg", f"PROXY={os.environ.get('HTTPS_PROXY', '')}",
             "-f", "Dockerfile.sandbox", "-t", tag, "."],
            cwd=BOT, timeout=3600)
    if p.returncode != 0:
        raise RuntimeError(f"docker build failed:\n{p.stdout[-3000:]}\n{p.stderr[-3000:]}")

    # The output-name trap (see bot/Dockerfile.sandbox): a build that links to
    # the wrong name leaves the SOURCE DIRECTORY at /bin/baseline and still
    # exits 0. `test -f` is the whole guard.
    p = run(["docker", "run", "--rm", "--entrypoint", "/bin/sh", tag,
             "-c", "test -x /bin/baseline && test -f /bin/baseline && echo OK"],
            timeout=300)
    if "OK" not in p.stdout:
        raise RuntimeError(f"/bin/baseline is not an executable regular file "
                           f"in {tag}: {p.stdout!r} {p.stderr!r}")
    p = run(["docker", "run", "--rm", tag], timeout=300)
    if "COWORLD_PLAYER_WS_URL" not in (p.stdout + p.stderr):
        raise RuntimeError(f"image smoke failed -- expected the WS-URL demand, "
                           f"got:\n{p.stdout[-1000:]}\n{p.stderr[-1000:]}")

    p = run(_cli("uvx", UPLOAD_CLI_VERSION.replace("==", "@"), "upload-policy",
                 tag, "-n", POLICY_NAME,
                 "--tag", f"purpose=autoresearch-local-{name}"), timeout=1800)
    if p.returncode != 0:
        raise RuntimeError(f"upload failed:\n{p.stdout[-2000:]}\n{p.stderr[-2000:]}")
    for line in reversed(p.stdout.strip().splitlines()):
        if f"{POLICY_NAME}:v" in line:
            return line[line.index(POLICY_NAME):].split()[0].strip()
    raise RuntimeError(f"could not read a policy ref out of {p.stdout!r}")


def ship(name: str) -> str:
    """Build bot/ for amd64, smoke it, upload it, return the assigned ref."""
    if not CAN_BUILD_AMD64:
        return ship_docker(name)
    binary = WORK / f"ship-{name}.bin"
    p = run([str(ROOT / "scripts" / "build_amd64.sh"), str(BOT), str(binary)],
            timeout=1800)
    if p.returncode != 0:
        raise RuntimeError(f"amd64 build failed:\n{p.stdout[-3000:]}\n{p.stderr[-3000:]}")
    smoke_amd64(binary)
    p = run(_cli("uv", "run", "--no-project",
                 "--with", UPLOAD_CLI_VERSION, "python",
                 str(ROOT / "scripts" / "upload_amd64_policy.py"), str(binary),
                 "-n", POLICY_NAME, "--tag", f"purpose=autoresearch-local-{name}"),
            timeout=1800)
    if p.returncode != 0:
        raise RuntimeError(f"upload failed:\n{p.stdout[-2000:]}\n{p.stderr[-2000:]}")
    ref = p.stdout.strip().splitlines()[-1].strip()
    if not ref.startswith(f"{POLICY_NAME}:v"):
        raise RuntimeError(f"could not read a policy ref out of {p.stdout!r}")
    return ref


def submit(ref: str) -> bool:
    log(f"  submitting {ref} with --auto-champion always")
    p = run(_cli("uvx", UPLOAD_CLI_VERSION.replace("==", "@"),
                 "submit", ref, "-l", LEAGUE, "--auto-champion", "always",
                 "--no-open-browser"), timeout=900)
    if p.returncode != 0:
        # A failed submission is a league problem, not a measurement one: the
        # result stands, the ref is uploaded, re-submitting is one command.
        log(f"  SUBMIT FAILED (result stands, ref uploaded): {p.stderr[-500:]}")
        return False
    tail = p.stdout.strip().splitlines()
    log(f"  {tail[-1] if tail else 'submitted'}")
    return True


# --- the record --------------------------------------------------------------

def gap_line(v: dict) -> str:
    kd, wr, cap = v["gaps"]["kd"], v["gaps"]["win_rate"], v["gaps"]["captures"]
    return (f"K/D {kd['observed']:+.4f} CI [{kd['ci_lo']:+.4f}, {kd['ci_hi']:+.4f}], "
            f"win rate {wr['observed']:+.3f} CI [{wr['ci_lo']:+.3f}, {wr['ci_hi']:+.3f}], "
            f"captures {cap['observed']:+.0f} CI [{cap['ci_lo']:+.0f}, {cap['ci_hi']:+.0f}], "
            f"n={v['n']}{endings_line(v)}")


def endings_line(v: dict) -> str:
    """The ending mix, as a suffix. A timeout scores -1 to BOTH sides in the
    league, so a rise in the timeout share is a cost the gap cannot show."""
    e = v.get("endings") or {}
    if not e:
        return ""
    total = max(1, sum(e.values()))
    parts = ", ".join(f"{k} {100.0 * n / total:.0f}%"
                      for k, n in sorted(e.items(), key=lambda kv: -kv[1]))
    return f" | endings: {parts}"


def append_ledger(exp: cat.Experiment, outcome: str, why: str, ref: str,
                  control: str, evidence: list[str], v: dict | None) -> None:
    with LEDGER_PATH.open("a") as fh:
        fh.write(f"\n## {exp.name} — {outcome} (local A/B)\n\n")
        fh.write(f"- when: {datetime.now(timezone.utc).isoformat(timespec='seconds')}\n")
        fh.write(f"- change: {describe(exp)}\n")
        fh.write(f"- treatment: local build  control: `{control}` (the tree)\n")
        if ref != "-":
            fh.write(f"- shipped as: `{ref}`\n")
        fh.write(f"- measured on: the local simulator, seed-paired mirrors "
                 f"({', '.join(evidence)})\n")
        fh.write(f"- verdict: {why}\n")
        if v and v.get("endings"):
            fh.write(f"- endings:{endings_line(v).split(':', 1)[1]}\n")
        if v:
            fh.write(f"- pooled: {v['n']} episodes, {len(v['skipped'])} "
                     f"skipped; RED won {v['red_win_rate']:.1%} of episodes\n")
            for b, label in (("a", "treatment"), ("b", "control")):
                s = v["builds"][b]
                fh.write(f"  - {label}: K/D {s['kd']:.4f} "
                         f"({s['kills']:.0f}/{s['deaths']:.0f}), "
                         f"captures {s['captures']:.0f}, wins {s['wins']}\n")
        fh.write(f"- rationale: {exp.rationale}\n")


def commit(exp: cat.Experiment, outcome: str, why: str) -> None:
    paths = ["research"] + (["bot"] if outcome.startswith("PROMOTE") else [])
    git("add", "-A", *paths)
    if not run(["git", "diff", "--cached", "--quiet"], cwd=ROOT).returncode:
        return
    subject = {
        "PROMOTE": f"Promote {exp.name}: local A/B separates positive",
        "REJECT": f"{exp.name} does not improve the policy",
    }.get(outcome, f"{exp.name}: {outcome}")
    run(["git", "commit", "-m", subject[:72], "-m", f"{why}\n\n{exp.rationale}\n",
         "-m", "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"], cwd=ROOT)
    branch = git("rev-parse", "--abbrev-ref", "HEAD").strip()
    for i in range(3):
        if run(["git", "push", "-q", "origin", branch], cwd=ROOT).returncode == 0:
            return
        time.sleep(2 ** i)
    log("  push failed; the commit is local until the next one succeeds")


def commit_state(st: dict, subject: str) -> None:
    """Commit a state change no experiment commit will carry.

    record() commits research/ BEFORE the generation counter advances, so
    each experiment's commit carries the PREVIOUS bump and the final one of
    an invocation dangles uncommitted -- the same gap the hosted loop's
    commit_state closes for batches that land nothing.
    """
    save_state(st)
    git("add", "-A", "research")
    if not run(["git", "diff", "--cached", "--quiet"], cwd=ROOT).returncode:
        return
    run(["git", "commit", "-m", subject[:72],
         "-m", "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"],
        cwd=ROOT)
    branch = git("rev-parse", "--abbrev-ref", "HEAD").strip()
    for i in range(3):
        if run(["git", "push", "-q", "origin", branch], cwd=ROOT).returncode == 0:
            return
        time.sleep(2 ** i)
    log("  push failed; the commit is local until the next one succeeds")


def record(exp: cat.Experiment, st: dict, outcome: str, why: str, ref: str,
           control: str, evidence: list[str], v: dict | None,
           tree_value: str | None) -> None:
    st["done"][exp.name] = {
        "outcome": outcome, "why": why, "ref": ref,
        "control": control, "measured": "local-sim",
        "knob": exp.knob, "value": exp.value,
        "records": evidence, "kd_gap": (v or {}).get("gaps", {}).get("kd"),
        "when": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    }
    append_ledger(exp, outcome, why, ref, control, evidence, v)
    if exp.kind == "knob" and tree_value is not None:
        observed = (v or {}).get("gaps", {}).get("kd", {}).get("observed", 0.0)
        # tried_values reads the catalogue and the queue, but a DERIVED
        # experiment's value lives in neither once it is decided -- it was
        # invented by followups() and recorded only here. Without this,
        # walking a knob from both ends re-proposed a value already measured
        # (MedKitDetour bought 160 twice).
        tried = tried_values(st)
        for d in st["done"].values():
            if d.get("knob") and d.get("value") is not None:
                tried.setdefault(d["knob"], set()).add(float(d["value"]))
        for nxt in cat.followups(exp, outcome.startswith("PROMOTE"),
                                 tree_value, observed, tried):
            if nxt.name not in st["done"] and not any(
                    q["name"] == nxt.name for q in st["queue"]):
                st["queue"].append(serialize(nxt))
                log(f"  queued follow-up: {nxt.name}")
    save_state(st)
    commit(exp, outcome, why)


# --- one experiment ----------------------------------------------------------

def run_experiment(exp: cat.Experiment, st: dict, gen_base: int,
                   dry: bool, no_submit: bool) -> None:
    log(f"--- {exp.name} ({exp.kind}) vs {st['baseline']} ---")
    log(f"  {describe(exp)}")
    WORK.mkdir(parents=True, exist_ok=True)
    ctx = WORK / exp.name
    edits = apply_edits(exp, ctx)          # full bot/ copy with edits applied
    log(f"  {len(edits)} edit(s) applied to the build copy")
    if dry:
        for e in edits:
            log(f"    {e['file']}: {e['find'].strip()!r} -> "
                f"{e['replace'].strip()!r}")
        return
    tree_value = tree_const(exp)
    control = st["baseline"]

    binary = build_pair(ctx / "baseline", BOT / "baseline", ctx)
    out = EPISODE_DIR / f"exp-{exp.name}.jsonl"
    if out.exists():
        out.unlink()
    records: list[dict] = []

    stages = (("screen", SCREEN_SEEDS, 1), ("confirm", CONFIRM_SEEDS, 2),
              ("extend", EXTEND_SEEDS, 3))
    evidence = [str(out.relative_to(ROOT))]
    v = None
    for i, (stage, n_seeds, stage_no) in enumerate(stages):
        first = gen_base + i * 200
        records += run_mirror(binary, range(first, first + n_seeds),
                              f"{exp.name} {stage}", out)
        v = verdict_from_records(records)
        if len(v["skipped"]) > MAX_SKIP_FRACTION * max(1, len(records)):
            raise RuntimeError(f"{len(v['skipped'])} of {len(records)} episodes "
                               f"failed; first: {v['skipped'][0]}")
        outcome, why = decide(v, stage_no)
        evidence_note = f"seeds {first}-{first + n_seeds - 1} both ways"
        evidence.append(evidence_note)
        log(f"  {exp.name} {stage}: {outcome} — {why}")
        if outcome == "ESCALATE" or outcome == "EXTEND":
            continue
        if outcome == "PROMOTE":
            promote(exp, edits, st, why, v, control, evidence, tree_value,
                    no_submit)
        else:
            record(exp, st, outcome, why, "-", control, evidence, v,
                   tree_value)
        return
    # Ran out of stages while still escalating: the last verdict decides.
    outcome, why = decide(v, 3)
    if outcome == "PROMOTE":
        promote(exp, edits, st, why, v, control, evidence, tree_value,
                no_submit)
    else:
        record(exp, st, outcome, why, "-", control, evidence, v, tree_value)


def promote(exp: cat.Experiment, edits: list[dict], st: dict, why: str,
            v: dict, control: str, evidence: list[str],
            tree_value: str | None, no_submit: bool) -> None:
    land(exp, edits)
    ref = "-"
    outcome = "PROMOTE"
    if no_submit:
        outcome = "PROMOTE-LOCAL"
        why += "; --no-submit held it from the league"
    else:
        try:
            ref = ship(exp.name)
            log(f"  shipped as {ref}")
            submit(ref)
            st["champion"] = ref
            st["baseline"] = ref
        except Exception as exc:                   # noqa: BLE001
            # The measurement stands and the change belongs in the tree; a
            # ship failure is logged loudly and the ref stays at the old
            # baseline so the next promotion re-ships the whole tree.
            outcome = "PROMOTE-LOCAL"
            why += f"; SHIP FAILED: {str(exc)[:500]}"
            log(f"  SHIP FAILED: {exc}")
    record(exp, st, outcome, why, ref, control, evidence, v, tree_value)


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
    global cat
    dry = "--dry-run" in sys.argv
    once = "--once" in sys.argv
    no_submit = "--no-submit" in sys.argv
    limit = next((int(a.split("=", 1)[1]) for a in sys.argv
                  if a.startswith("--max-experiments")), 1000)

    st = load_state()
    if not st.get("baseline"):
        sys.exit("research/state.json has no baseline policy ref")

    ran = 0
    try:
        while ran < limit:
            importlib.reload(cat)
            exp = next_experiment(st)
            if exp is None:
                log("queue empty — nothing left to measure")
                return
            gen_base = 200_000 + st["generation"] * 1000
            try:
                run_experiment(exp, st, gen_base, dry, no_submit)
            except (Exception, SystemExit) as exc:     # noqa: BLE001
                log(f"  {exp.name} ABANDONED: {exc}")
                if not dry:
                    st["done"][exp.name] = {
                        "outcome": "ABANDONED", "why": str(exc)[:2000],
                        "when": datetime.now(timezone.utc).isoformat(
                            timespec="seconds")}
                    save_state(st)
            if dry:
                st["done"].setdefault(exp.name, {"outcome": "DRY"})
            else:
                st["generation"] += 1
                save_state(st)
            ran += 1
            if once:
                return
    finally:
        # Dry runs mutate st in memory only and must never write it back.
        if not dry:
            commit_state(st, "Auto-research: advance the generation counter")


if __name__ == "__main__":
    main()
