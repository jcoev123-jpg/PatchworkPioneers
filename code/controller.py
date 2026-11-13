#!/usr/bin/env python3
"""
Relay v2 controller (game-agnostic; the game is configured in relay.json "game", see game.py).

PLAN/BRIEF (ChatGPT) -> BUILD (DeepSeek via OpenCode, criterion evidence)
-> TEST (controller) -> REVIEW (optional advisory) -> FINAL (ChatGPT, independent)
-> ACCEPT (controller commits + ff-merges)   |   FIX_REQUIRED -> BUILD (max N attempts)
Prepared tasks carry scoped ownership and file fingerprints. Parallel lanes are reviewed
after a bounded batching window; repeated DeepSeek defects escalate in the same worktree.

  python controller.py start [--cycles N]   run / resume the loop (foreground)
  python controller.py status               print status
  python controller.py stop                 stop (kills the active agent)
  python controller.py ping-chatgpt         test the ChatGPT bridge
"""
from __future__ import annotations

import argparse
import traceback
import datetime
import fnmatch
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import threading
import tempfile
import time
from pathlib import Path

import psutil

import game as G
import planner_mock
import prompts as P
import throughput as TP
from cloud import Cloud, CloudError

HERE = Path(__file__).resolve().parent
SECRETS = HERE / "secrets.json"   # gitignored (.review/); never zipped for ChatGPT or logged


def is_paid_openrouter(model: str) -> bool:
    return model.startswith("openrouter/") and not model.endswith(":free")


def load_secrets(path: Path | None = None) -> list:
    """Owner 2026-10-19 gave OpenRouter keys for its free models. secrets.json {"env": {NAME: value}} is loaded into
    this process's environment, which every coder inherits; the repo opencode.json reads {env:OPENROUTER_API_KEY}
    (only under --standalone, as the relay runs OpenCode). Returns the names loaded."""
    try:
        env = json.loads((path or SECRETS).read_text(encoding="utf-8")).get("env") or {}
    except (OSError, ValueError):
        return []
    for k, v in env.items():
        os.environ.setdefault(str(k), str(v))
    return sorted(env)


load_secrets()
# Owner 2026-10-11: background threads (live board, lane checks, scans) run git status/diff on the main repo every few
# seconds; those take git's optional index lock, which made cycle 147's accept merge fail ("master moved"). Read-only
# git commands must never take that lock.
os.environ["GIT_OPTIONAL_LOCKS"] = "0"
# 2026-10-21: cycle 071 hung 60 min on "git worktree remove --force" of a lane folder with a locked file: Git for
# Windows asks "Deletion of directory ... failed. Should I try again? (y/n)" and waited for an answer that never came.
# Answer no, so the command fails at once (cleanup already falls back to rmtree and prune).
os.environ["GIT_ASK_YESNO"] = "false"
# 2026-10-26: lane worktrees have no opencode.json, so every OpenCode coder loads the OpenRouter provider block from
# here (Laguna S 2.1 free is unknown to OpenCode's own catalog and was "Model unavailable" without it).
os.environ.setdefault("OPENCODE_CONFIG", str(HERE / "opencode_coders.json"))
CFG_PATH = HERE / "relay.json"
STATE_PATH = HERE / "state.json"
STATUS_PATH = HERE / "STATUS.md"
STOP_PATH = HERE / "STOP"
HANDOFF = HERE / "handoff"   # owner 2026-10-26: main builds posted to the owner's Claude Code session
SUITE_STARTS = HERE / "suite_starts.json"   # run_tests.py notes each main-suite start here
SLOW_OWED = HERE / "slow_owed.json"         # slow-tier tests the background slow check found failing (run_tests.py)
SUITE_FAIL_RE = re.compile(r"^FAIL (\S+_test\.gd) \(", re.M)
PRE_FINAL_POLL = 10
# A re-review after a change this small (diff lines) checks only the change, from the earlier review's answer.
PRE_FINAL_DELTA_LINES = 400
PAUSE_PATH = HERE / "PAUSE"
LOCK_PATH = HERE / "relay.lock"
LOG_PATH = HERE / "logs" / "controller.log"
CYCLES = HERE / "cycles"
GUARDED = ("controller.py", "chatgpt_bridge.py", "prompts.py", "relay.json", "cloud.py", "playtest.py", "art_gen.py",
           "codex_lane.py", "lane_local.py", "health_check.py", "throughput.py")
DRIFT = 'task files or declared dependencies changed since planning'
CAPACITY_RE = re.compile(r"at capacity|try a different model|model is overloaded", re.I)
# An OpenCode provider that is briefly full (DeepSeek Go, 2026-10-25): a lane run that died on it is requeued once.
# 2026-11-06: + OpenCode's "Timed out waiting for response headers" (cycle 563 lane3 dropped as "no changes")
UPSTREAM_CAPACITY_RE = re.compile(r"ttft_admission_refused|cell is at capacity|Upstream request failed:[^\n]{0,80}?at capacity"
                                  r"|Timed out waiting for response headers", re.I)
LIMIT_RE = re.compile(
    r"usage limit|rate[ _-]?limit|\b429\b|quota|limit reached|overloaded|try again (later|in)", re.I
)
RESET_AT_RE = re.compile(r"try again at\s*(?:([a-z]{3})[a-z]*\.?\s+(\d{1,2})(?:st|nd|rd|th)?,?\s*(\d{4})?,?\s*)?"
                         r"[^\n\"]{0,40}?(\d{1,2}):(\d{2})\s*([AP]M)", re.I)
MONTHS = ("jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec")


def limit_reset(text: str, now: "datetime.datetime | None" = None) -> "datetime.datetime | None":
    """The local time a Codex usage-limit message names ("... or try again at 6:30 AM"); None when it names none.
    A time more than 10 min past is tomorrow's. Owner 2026-10-17: the weekly limit names a date too ("try again at
    Oct 22nd, 2026 6:36 PM"); it was read as 18:36 today, so cycle 381 retried Codex at once and then every 6 h."""
    found = RESET_AT_RE.findall(text or "")
    if not found:
        return None
    mon, day, year, hh, mm, ap = found[-1]
    now = now or datetime.datetime.now()
    hour = int(hh) % 12 + (12 if ap.upper() == "PM" else 0)
    if mon.lower() in MONTHS:
        try:
            at = datetime.datetime(int(year or now.year), MONTHS.index(mon.lower()) + 1, int(day), hour, int(mm))
        except ValueError:
            at = None
        if at is not None:
            return at.replace(year=at.year + 1) if not year and at < now - datetime.timedelta(days=1) else at
    at = now.replace(hour=hour, minute=int(mm), second=0, microsecond=0)
    return at + datetime.timedelta(days=1) if at < now - datetime.timedelta(minutes=10) else at


CHECK_CALL_RE = re.compile(r"\s*(?:_?(?:check|assert|expect|reject)\w*|fail\w*)\(")


def light_change(diff: str, max_code: int = 150, max_test_removed: int = 10) -> str:
    """Owner 2026-10-22 ("lighter checks"): a small change whose full suite passed merges without the 8-14 min
    ChatGPT review. Returns why it counts as small, or "" when it needs the full review: a deleted file, a relay,
    project or export file, more than max_code changed code/data lines, or more than max_test_removed removed test
    lines (a weakened test)."""
    code = removed = 0
    files = []
    for part in re.split(r"(?m)^diff --git ", diff or "")[1:]:
        head = part.split("\n", 1)[0]
        m = re.search(r" b/(\S+)$", head)
        path = m.group(1) if m else head
        if path.endswith((".uid", ".import")):
            continue
        if (re.search(r"(?m)^deleted file mode", part) or path.startswith(".review/")
                or path in ("project.godot", "export_presets.cfg")):
            return ""
        lines = [ln for ln in part.split("\n")
                 if ln[:1] in ("+", "-") and not ln.startswith(("+++ ", "--- "))]
        if path.startswith("tests/"):
            removed += sum(ln.startswith("-") for ln in lines)
            # Owner 2026-10-27 (relay improvements): a test that ends with fewer _check/_assert calls than it had
            # (a lane deleting the check its change broke) is a weakened test however few lines moved, so it gets
            # the ChatGPT review. Rewording a check removes one and adds one, which is fine.
            if sum(bool(CHECK_CALL_RE.match(ln[1:])) for ln in lines if ln[0] == "-") > \
                    sum(bool(CHECK_CALL_RE.match(ln[1:])) for ln in lines if ln[0] == "+"):
                return ""
        else:
            code += len(lines)
        files.append(path)
    if not files or code > max_code or removed > max_test_removed:
        return ""
    return f"{code} changed code/data lines in {len(files)} file(s), {removed} test lines removed"


# Owner 2026-11-04: "make sure that art isnt done with code since it looks bad". What counts as drawing visuals in code
# in a game script or scene: _draw() overrides, CanvasItem draw_* calls, flat style boxes, gradients, particles.
CODE_ART_RE = re.compile(
    r"\bfunc\s+_draw\s*\(|\bdraw_(?:rect|circle|line|dashed_line|polyline|multiline|polygon|colored_polygon|arc|"
    r"primitive|style_box)\s*\(|\bStyleBoxFlat\.new\s*\(|\bGradient(?:Texture[12]D)?\.new\s*\(|"
    r"\b[GC]PUParticles2D\b|\bParticleProcessMaterial\b|"
    r'type="(?:StyleBoxFlat|Gradient|GradientTexture[12]D|[GC]PUParticles2D|ParticleProcessMaterial)"')


def code_art_lines(diff: str, limit: int = 6) -> list:
    """Added lines that draw visuals in code, in game scripts and scenes (not tests or addons). Per file, only as many
    as it adds beyond what it removes, so reworded or moved-within-file code is not counted."""
    found = []
    for part in re.split(r"(?m)^diff --git ", diff or "")[1:]:
        m = re.search(r" b/(\S+)$", part.split("\n", 1)[0])
        path = m.group(1) if m else ""
        if not path.endswith((".gd", ".tscn", ".tres")) or path.startswith(("tests/", "addons/", ".review/")):
            continue
        lines = part.split("\n")
        added = [ln[1:] for ln in lines if ln.startswith("+") and not ln.startswith("+++")]
        removed = [ln[1:] for ln in lines if ln.startswith("-") and not ln.startswith("---")]
        net = sum(len(CODE_ART_RE.findall(ln)) for ln in added) - sum(len(CODE_ART_RE.findall(ln)) for ln in removed)
        if net > 0:
            found += [f"{path}: {ln.strip()[:100]}" for ln in added if CODE_ART_RE.search(ln)][:net]
    return found[:limit]


QUOTA_RESET_RE = re.compile(r"Resets in\s+(?:(\d+)h)?\s*(?:(\d+)m)?\s*(?:(\d+)s)?", re.I)


def quota_reset_s(output: str) -> float | None:
    """Seconds until a plan quota resets, from "Resets in 157h21m43s" (Antigravity); None if not stated.
    Capped at 8 days so a misread never parks a model for good."""
    m = None
    for m in QUOTA_RESET_RE.finditer(output or ""):
        pass
    if not m or not any(m.groups()):
        return None
    h, mi, se = (int(g or 0) for g in m.groups())
    return min(h * 3600 + mi * 60 + se + 60, 8 * 86400) or None


# OpenCode prints this when the owner's Go plan is used up (2026-10-11); stricter than LIMIT_RE so a lane's own
# output mentioning rate limits cannot trigger it. The second branch catches the free fallback models' errors.
# 2026-10-22 (owner gave the monitor full design control): by cycle 124 data/encounters held 113 Fights built from
# 9 enemies, one "Author X as a standalone M04 Fight" lane task after another, while the heroes still had only their 12
# starter cards. Lane plans with such titles are dropped (MILESTONES.md "BUILD ORDER v2": no more encounter files).
BANNED_LANE_TITLE_RE = re.compile(r"\b(?:author|publish)\b[^.]*\b(?:fights?|encounters?)\b|"
                                  r"\bstandalone\s+(?:m0\d\s+)?(?:fight|encounter|elite)\b", re.I)
DS_LIMIT_RE = re.compile(r"usage limit exceeded|(?:^|\n)(?:\[[\d:]{8}\] )?usage limit: |RESOURCE_EXHAUSTED|Error:\s*(?:\x1b\[[0-9;]*m)?\s*[^\n]{0,60}?"
                         r"(?:rate[ -]limit|quota|free usage|too many requests|model (?:is )?unavailable|endpoint is unavailable|insufficient credits)", re.I)   # rate-limited: OpenRouter
# 2026-10-26: a free model's own daily cap at its provider ("Rate limit exceeded: limit_rpd/thinkingmachines/...
# Daily limit reached for thinkingmachines/inkling:free via Thinking Machines. Credits don't affect this cap.").
MODEL_DAY_CAP_RE = re.compile(r"limit_rpd/|Daily limit reached for", re.I)
# 2026-11-06: the Codex CLI's own limit stop ({"type":"turn.failed","error":{"message":"You've hit your usage limit...").
CODEX_LANE_LIMIT_RE = re.compile(r"hit your usage limit", re.I)
# "usage limit: <site> ..." at a line start is the web coders' own limit line (deepseek_web_coder.py): signed out,
# page not loading, browser error. It was missed, so those tasks were given up as "no changes" (lane8 2026-10-24 10:31).
# RESOURCE_EXHAUSTED: Google's quota error, for the Antigravity CLI lane (owner 2026-10-21).
# "Model unavailable" (a free model withdrawn, 2026-10-15): lane4 gave its task up as "no changes" after 10 seconds;
# now the model is rested like a limited one and the task is requeued on the next model.
# "Upstream request failed: Endpoint is unavailable." (LongCat free, 2026-10-22) is the same: two lane2 tasks were given up.
MILESTONE_RE = re.compile(r"\bM\d{2}(?:\.\d+)?[A-Z]?\b")
STRAY_RE = re.compile(r"(^|/)(_[^/]+|[^/]*(?:probe|scratch)[^/]*)\.(py|gd|txt|log|ps1|tscn|cfg)(\.uid)?$", re.I)
DEFAULT_STATE = {"phase": "IDLE", "cycle": 0, "history": [], "last_good_commit": None}


class Halt(Exception):
    """Stop cleanly. State is kept so `start` resumes the same phase."""


class ScopeDeferred(Exception):
    """Preserve work needing a new decision and continue other authorized tasks."""


NET_RE = re.compile(
    r"ECONNRESET|ETIMEDOUT|ENOTFOUND|EAI_AGAIN|ECONNREFUSED|socket hang up|fetch failed|network error|"
    r"connection (reset|refused|closed|error)|getaddrinfo|Could not resolve host|\b50[234]\b|"
    r"service unavailable|temporarily unavailable|API Error: 5\d\d", re.I
)


class PatchReady(Halt):
    """A workflow-review patch is waiting: exit with PATCH_EXIT so run_relay.ps1 installs it (or rejects it) and restarts."""


PATCH_EXIT = 3


# Owner 2026-11-05: the relay Chrome hangs after ~2 h; a ChatGPT build ask (up to an hour) starts on a fresh one.
BUILD_CHROME_MAX_AGE_S = 60 * 60
# Owner 2026-11-05: builds whose tab a Chrome restart closed waited the full hour for a reply after their report was
# written (cycles 524, 526: 43-48 min lost). The ask ends once the report has stayed unchanged this long.
REPORT_QUIET_S = 60


def settled(path: Path, quiet_s: float = REPORT_QUIET_S):
    """done check for a coder ask: the report exists, is not empty and has not changed for quiet_s seconds."""
    seen = {"sig": None, "at": 0.0}

    def done() -> bool:
        try:
            st = path.stat()
        except OSError:
            seen["sig"] = None
            return False
        sig = (st.st_mtime_ns, st.st_size)
        if sig != seen["sig"]:
            seen["sig"], seen["at"] = sig, time.time()
            return False
        return st.st_size > 0 and time.time() - seen["at"] >= quiet_s
    return done


class UsageLimited(Exception):
    """Provider limit hit. Back off and retry the same phase."""


class NetworkDown(UsageLimited):
    """No internet / DNS. Wait for the network to return instead of a long backoff."""


def net_ok(hosts=("api.anthropic.com", "chatgpt.com", "github.com")) -> bool:
    import socket
    for h in hosts:
        try:
            socket.create_connection((h, 443), timeout=5).close()
        except OSError:
            return False
    return True


class AgentFailed(Exception):
    """Cycle cannot continue. Park the work on a failed branch."""


# ---------------------------------------------------------------- helpers

def ts() -> str:
    return datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def log(msg: str) -> None:
    line = f"[{ts()}] {msg}"
    print(line, flush=True)
    # 2026-10-18: the relay's own unit tests, run inside the installed relay folder, wrote "tests merge_2: FAIL ..."
    # into the live controller.log. Under unittest (never imported by the live relay) lines go to unittest.log.
    path = LOG_PATH.with_name("unittest.log") if "unittest" in sys.modules else LOG_PATH
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "a", encoding="utf-8") as f:
        f.write(line + "\n")


def read(p: Path, default: str = "") -> str:
    try:
        return p.read_text(encoding="utf-8", errors="replace")
    except FileNotFoundError:
        return default


def write(p: Path, text: str) -> None:
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text, encoding="utf-8")


def load_json(p: Path, default):
    """A file a crash left empty or zeroed (2026-10-14: state.json was 275 KB of NUL bytes) falls back to its
    .bak copy (save_json(backup=True)); with no usable copy the error is raised as before."""
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return default
    except (ValueError, UnicodeDecodeError) as e:
        bak = p.with_name(p.name + ".bak")
        if not bak.exists():
            raise
        sys.stderr.write(f"{p.name} is unreadable after a crash ({e}); loading {bak.name}\n")
        return json.loads(bak.read_text(encoding="utf-8"))


def queued_time(c: dict) -> float:
    """2026-10-18: a hand-queued carry with an ISO-string queued_at stopped every background lane (float - str)."""
    v = c.get('queued_at', 0)
    try:
        return float(v)
    except (TypeError, ValueError):
        try:
            return datetime.datetime.fromisoformat(str(v)).timestamp()
        except ValueError:
            return time.time()


def _write_synced(p: Path, text: str) -> None:
    with open(p, "w", encoding="utf-8") as f:
        f.write(text)
        f.flush()
        os.fsync(f.fileno())   # without this a power loss can leave the renamed file full of NUL bytes


def save_json(p: Path, obj, backup: bool = False) -> None:
    # A per-thread temp name, and a few retries: on Windows os.replace fails with "Access is denied" while another
    # process (a reader, an antivirus scan) has the target open. Cycle 206's lane-merge check stopped on that once.
    text = json.dumps(obj, indent=2)
    if backup:   # a second synced copy that load_json falls back to
        _write_synced(p.with_name(p.name + ".bak"), text)
    tmp = p.with_suffix(p.suffix + f".{os.getpid()}.{threading.get_ident()}.tmp")
    _write_synced(tmp, text)
    for n in range(10):
        try:
            os.replace(tmp, p)
            return
        except PermissionError:
            if n == 9:
                tmp.unlink(missing_ok=True)
                raise
            time.sleep(0.1 * (n + 1))


def tail(text: str, n: int) -> str:
    return text if len(text) <= n else "...[truncated]...\n" + text[-n:]


def extract(text: str, name: str) -> str | None:
    m = re.search(rf"@@{name}_START@@(.*?)@@{name}_END@@", text, re.S)
    return m.group(1).strip() if m else None


def validate_verdict(v: dict) -> dict:
    if not isinstance(v, dict):
        raise ValueError('verdict must be a JSON object')
    if v.get('verdict') not in ('ACCEPTED', 'FIX_REQUIRED', 'DEFERRED'):
        raise ValueError(f"bad verdict {v.get('verdict')!r}")
    defects = v.get('defects') or []
    if not isinstance(defects, list):
        raise ValueError('defects is not a list')
    v['defects'] = [str(d) for d in defects]
    if v['verdict'] == 'FIX_REQUIRED' and not v['defects']:
        raise ValueError('FIX_REQUIRED without defects')
    if v['verdict'] == 'ACCEPTED' and v['defects']:
        raise ValueError('ACCEPTED with unresolved defects')
    if v['verdict'] == 'DEFERRED' and (not isinstance(v.get('summary'), str) or not v['summary'].strip()):
        raise ValueError('DEFERRED needs a specific decision summary')
    return v


def completed_report(report: Path, since: float) -> bool:
    """True when the coder wrote this report during the run that started at `since` and marked it COMPLETED.
    Owner 2026-10-16: cycle 358's DeepSeek build finished (669/669 suite, COMPLETED report at 19:21:48), then OpenCode
    exited rc=1 with no error seven seconds later; the relay counted a failed try and rebuilt the finished work."""
    try:
        if report.stat().st_mtime < since:
            return False
        block = extract(read(report), 'CODER_STATUS')
        return bool(block) and json.loads(block).get('status') == 'COMPLETED'
    except (OSError, ValueError, AttributeError):
        return False


def coder_deferred_reason(text: str) -> str | None:
    block = extract(text, 'CODER_STATUS')
    if block is None:
        return None  # older reports remain readable
    status = json.loads(block)
    if not isinstance(status, dict) or status.get('status') not in ('COMPLETED', 'DEFERRED'):
        raise ValueError('invalid CODER_STATUS')
    if status['status'] == 'COMPLETED':
        return None
    reason = status.get('reason')
    if not isinstance(reason, str) or not reason.strip():
        raise ValueError('DEFERRED coder report needs a specific reason')
    return reason.strip()


_SUITE_WORDS = re.compile(r"full[- ]suite|run_tests\.py|suite (?:run|result|validation|pass|verdict)", re.I)
_UNFINISHED = re.compile(r"could not (?:be obtained|finish|complete)|cannot (?:finish|complete)|unverified|unavailable|"
                         r"has not finished|did not finish|not finish|timed out|time limit|deadline|disconnect", re.I)
_REAL_FAIL = re.compile(r"\bfail(?:s|ed|ing|ure|ures)?\b", re.I)


def suite_only_deferral(reason: str) -> bool:
    """A lane DEFERRED only because its own full-suite run could not finish (2026-10-18: lane7's campaign map, and
    lanes 6/7 on 2026-10-16/17 four more times: SentinelX stops a script after 600 s, the suite takes 20+ min on a busy
    PC). The lane checker runs the full suite on the committed work itself, so such work goes on to it instead of
    being parked. A real failure (a count like 245/247, a failing test) or a scope/ownership question still defers."""
    if not _SUITE_WORDS.search(reason) or not _UNFINISHED.search(reason) or _REAL_FAIL.search(reason):
        return False
    # Cycle 406 (2026-10-18): "82/83 related tests passed" where the one short was a known-slow test that "times
    # out after 180s" on a busy PC (no test failed). A shortfall explained only by a timeout is still suite-only.
    return (not any(a != b for a, b in re.findall(r"\b(\d+)/(\d+)\b", reason))
            or bool(re.search(r"\btime[sd]? out\b|\btimeouts?\b", reason, re.I)))


def parse_verdict(text: str) -> dict:
    block = extract(text, "VERDICT")
    if block is None:
        raise ValueError("no VERDICT block")
    i, j = block.find("{"), block.rfind("}")
    if i < 0 or j < i:
        raise ValueError("no JSON object in VERDICT block")
    return validate_verdict(json.loads(block[i:j + 1]))


def milestone_of(title: str | None) -> str | None:
    m = MILESTONE_RE.search(title or "")
    return m.group(0) if m else None


def similar(a: list[str], b: list[str]) -> bool:
    wa = set(re.findall(r"[a-z0-9_./]+", " ".join(a).lower()))
    wb = set(re.findall(r"[a-z0-9_./]+", " ".join(b).lower()))
    return bool(wa and wb) and len(wa & wb) / len(wa | wb) >= 0.8


def resolve(argv: list[str]) -> list[str]:
    exe = shutil.which(argv[0]) or argv[0]
    if os.name == "nt" and exe.lower().endswith((".cmd", ".bat")):
        return ["cmd", "/c", exe, *argv[1:]]
    return [exe, *argv[1:]]


def kill_tree(pid: int) -> None:
    try:
        root = psutil.Process(pid)
    except psutil.NoSuchProcess:
        return
    procs = root.children(recursive=True) + [root]
    for p in procs:
        try:
            p.terminate()
        except psutil.Error:
            pass
    _, alive = psutil.wait_procs(procs, timeout=10)
    for p in alive:
        try:
            p.kill()
        except psutil.Error:
            pass


def tree_cpu(pid: int, seen: dict | None = None) -> float:
    """CPU seconds of the process tree. With `seen`, processes that have exited keep counting, so the total never
    drops. Owner 2026-10-14: cycle 247's DeepSeek build was killed as a "stall" twice, 12 min into its final full
    suite: each finished Godot test left the live-only sum, so it stayed below the last mark while tests ran."""
    try:
        root = psutil.Process(pid)
        procs = [root, *root.children(recursive=True)]
    except psutil.Error:
        procs = []
    total = 0.0
    for p in procs:
        try:
            t = p.cpu_times()
            used = t.user + t.system
            if seen is not None:
                key = (p.pid, p.create_time())
                seen[key] = max(seen.get(key, 0.0), used)
            total += used
        except psutil.Error:
            pass
    return sum(seen.values()) if seen is not None else total


def last_json_line(raw: str) -> dict | None:
    for line in reversed(raw.splitlines()):
        line = line.strip()
        if line.startswith("{"):
            try:
                return json.loads(line)
            except json.JSONDecodeError:
                continue
    return None


def notify(title: str, message: str) -> None:
    """Best-effort Windows desktop notification (balloon toast); never blocks the relay."""
    if os.name != "nt":
        return
    t = title.replace("'", "''")[:60]
    m = message.replace("'", "''")[:200]
    ps = ("Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing; "
          "$n = New-Object System.Windows.Forms.NotifyIcon; $n.Icon = [System.Drawing.SystemIcons]::Information; "
          f"$n.Visible = $true; $n.ShowBalloonTip(8000, '{t}', '{m}', 'Info'); Start-Sleep 9; $n.Dispose()")
    try:
        subprocess.Popen(["powershell", "-NoProfile", "-WindowStyle", "Hidden", "-Command", ps],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
    except OSError:
        pass


def uptime_hours() -> float | None:
    """Hours since Windows booted (None elsewhere)."""
    try:
        import ctypes
        f = ctypes.windll.kernel32.GetTickCount64
        f.restype = ctypes.c_ulonglong
        return f() / 3_600_000
    except (AttributeError, OSError):
        return None


def keep_awake(on: bool) -> None:
    """Stop Windows sleeping while the relay runs (the display may still turn off)."""
    if os.name != "nt":
        return
    try:
        import ctypes
        ES_CONTINUOUS, ES_SYSTEM_REQUIRED = 0x80000000, 0x00000001
        ctypes.windll.kernel32.SetThreadExecutionState(
            ES_CONTINUOUS | (ES_SYSTEM_REQUIRED if on else 0))
    except Exception:
        pass


def foreign_agents(adopted=()) -> list[str]:
    """Interactive coding agents (not started by this controller) that could touch the repo. `adopted`: pids of lane
    coders a restarted controller took over from its predecessor (2026-10-18: they were reported as foreign)."""
    mine = {os.getpid()}
    for root in (os.getpid(), *(p for p in adopted if isinstance(p, int))):
        try:
            mine |= {root} | {c.pid for c in psutil.Process(root).children(recursive=True)}
        except psutil.Error:
            pass
    found = []
    for pr in psutil.process_iter(["pid", "name", "cmdline"]):
        try:
            name = (pr.info["name"] or "").lower()
            if pr.info["pid"] in mine or not name.startswith("opencode"):
                continue
            if (pr.info["cmdline"] or [])[1:3] == ["serve", "--service"]:   # OpenCode's background service edits nothing
                continue
            found.append(f"{pr.info['pid']} {' '.join(pr.info['cmdline'] or [])[:80]}")
        except psutil.Error:
            continue
    return found


def timeline_text(timeline: list) -> str:
    rows, fmt = [], "%Y-%m-%d %H:%M:%S"
    for i, (phase, at) in enumerate(timeline):
        end = timeline[i + 1][1] if i + 1 < len(timeline) else None
        mins = ((datetime.datetime.strptime(end, fmt) - datetime.datetime.strptime(at, fmt)).total_seconds() / 60
                if end else None)
        rows.append(f"| {phase} | {at} | {f'{mins:.1f}' if mins is not None else '-'} |")
    return "| Phase | Started | Minutes |\n|---|---|---:|\n" + "\n".join(rows) + "\n"


# ---- periodic design review (owner 2026-10-19: ChatGPT does it, not Claude) ----

def parse_design_review(text: str) -> dict | None:
    """The three sections of a DESIGN_REVIEW_FILE answer, or None when it is malformed."""
    text = text.replace("\r\n", "\n").replace(P.FILE_END, "")
    m = re.search(r"^@@BAL_REVIEW@@[ \t]*\n(.*?)^@@MPW@@[ \t]*\n(.*?)^@@NEXT@@[ \t]*\n(.*)\Z", text, re.S | re.M)
    if not m:
        return None
    bal, mpw, nxt = (g.strip("\n").rstrip() for g in m.groups())
    nxt = " ".join(nxt.split())
    if mpw.strip() in ("(none)", "none", ""):
        mpw = ""
    if (not bal.startswith("Review ") or not nxt.startswith("BAL NEXT MAIN STEPS") or len(bal) > 8000
            or len(nxt) > 2500 or len(mpw) > 6000 or (mpw and not re.match(r"P\d+\. ", mpw))):
        return None
    return {"bal": bal, "mpw": mpw, "next": nxt}


def insert_design_review(doc: str, bal: str, mpw: str) -> str | None:
    """MILESTONES.md with the BAL review block before the BAL gate line and the MPW step before MPW's
    "Not scheduled" paragraph; None when an anchor is missing. Keeps the file's line endings."""
    nl = "\r\n" if "\r\n" in doc else "\n"
    lines = doc.replace("\r\n", "\n").split("\n")

    def after(start: int, prefixes: tuple) -> int:
        return next((i for i in range(start + 1, len(lines)) if lines[i].startswith(prefixes)), -1)

    b = next((i for i, l in enumerate(lines) if l.startswith("## BAL")), -1)
    gate = after(b, ("Gate:", "## ")) if b >= 0 else -1
    if gate < 0 or not lines[gate].startswith("Gate:"):
        return None
    lines[gate:gate] = bal.split("\n")
    if mpw:
        m = next((i for i, l in enumerate(lines) if l.startswith("## MPW")), -1)
        end = after(m, ("Not scheduled", "Gate:", "## ")) if m >= 0 else -1
        if end < 0:
            return None
        while end > 0 and not lines[end - 1].strip():
            end -= 1
        lines[end:end] = mpw.split("\n")
    return nl.join(lines)


def guard_hash() -> str:
    h = hashlib.sha256()
    for name in GUARDED:
        h.update(name.encode())
        p = HERE / name
        h.update(p.read_bytes() if p.exists() else b"")
    return h.hexdigest()


def sleep_checked(seconds: float) -> None:
    end = time.time() + seconds
    while time.time() < end:
        if STOP_PATH.exists():
            raise Halt("STOP requested")
        time.sleep(min(5, end - time.time()))


# ---------------------------------------------------------------- relay

# Chat-website coders in opencode.fallback_models (lane_local.WEB_CODERS); the last fallback tier.
WEB_MODELS = ("deepseek-web", "gemini-web", "mistral-web", "connector-web")


UNWIRED_FORCE_MIN = 5   # unwired scripts needed before a stall makes a main wiring cycle mandatory


def note_bridge_error(msg: str) -> None:
    """Owner 2026-10-25 ("If it keeps timing out, restart the pc"): a ChatGPT page that times out loading counts as a
    hung Chrome, so repeated timeouts trigger the PC restart in Relay.pc_restart_due."""
    if "Page.goto: Timeout" in msg:
        from chatgpt_bridge import record_chrome_hang
        record_chrome_hang()


class Relay:
    def __init__(self):
        cfg = load_json(CFG_PATH, None)
        if not cfg:
            sys.exit(f"missing {CFG_PATH}")
        self.cfg = cfg
        self.repo = Path(cfg["repo"]).resolve()
        self.main = cfg["main_branch"]
        TP.set_shared(cfg.get("shared_files", []))
        self.relay_rel = HERE.relative_to(self.repo).as_posix()
        self.state = load_json(STATE_PATH, dict(DEFAULT_STATE))
        self._tls = threading.local()      # per-thread ChatGPT bridge + "background" flag
        self._save_lock = threading.RLock()
        self._shots_lock = threading.Lock()   # one screenshot clone for the visual lane's before/after check
        self._vc_threads: dict = {}
        self._plan_slot: dict = {}   # PLAN_NEXT thread's cycle -> the cycle its plan is for (see join_bg swap)
        self._started_at = time.time()   # lane coders that stopped before this are checked for a restart cut-off
        self._fin_threads: dict = {}
        self._fin_retry_at: dict = {}
        self._bg_threads: list[threading.Thread] = []
        self.guard = guard_hash()
        self.backoff_i = 0
        self._last_save = 0.0
        self.rescues_this_run = 0
        self.run_started = ts()
        self.cloud = Cloud(cfg.get("cloud", {}), cfg["claude"]["cmd"], self.repo, HERE, self.git, log)

    # ---- state / status

    @property
    def cyc(self) -> Path:
        return CYCLES / f"{self.state['cycle']:03d}"

    def save(self, **kw) -> None:
        with self._save_lock:
            prev = self.state.get("phase")
            self.state.update(kw)
            if "phase" in kw and kw["phase"] != prev:
                self.state.setdefault("timeline", []).append([kw["phase"], ts()])
            self.state["updated"] = ts()
            save_json(STATE_PATH, self.state, backup=True)
            write(STATUS_PATH, render_status(self.state))
            self._last_save = time.time()

    # ---- git

    def git(self, *args: str, check: bool = True) -> str:
        r = subprocess.run(["git", *args], cwd=self.repo, capture_output=True,
                           text=True, encoding="utf-8", errors="replace")
        if check and r.returncode:
            raise Halt(f"git {' '.join(args)} failed: {r.stderr.strip()}")
        return r.stdout.rstrip()

    def git_ok(self, *args: str) -> bool:
        return subprocess.run(["git", *args], cwd=self.repo, capture_output=True).returncode == 0

    def repo_mtime(self) -> float:
        newest = 0.0
        for line in self.git("status", "--porcelain", "-uall", check=False).splitlines():
            path = line[3:].split(" -> ")[-1].strip('"')
            try:
                newest = max(newest, (self.repo / path).stat().st_mtime)
            except OSError:
                pass
        return newest

    # ---- process runner with watchdog

    def run_proc(self, argv: list[str], log_path: Path, timeout: int,
                 stall_s: int | None = None, env: dict | None = None) -> tuple[int | None, str]:
        log_path.parent.mkdir(parents=True, exist_ok=True)
        kw = ({"creationflags": subprocess.CREATE_NEW_PROCESS_GROUP} if os.name == "nt"
              else {"start_new_session": True})
        with open(log_path, "wb") as out:
            p = subprocess.Popen(resolve(argv), cwd=self.repo, stdout=out, env=env,
                                 stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL, **kw)
            fg = not getattr(self._tls, "bg", False)   # background threads leave agent_pid to the main thread
            if fg:
                self.save(agent_pid=p.pid, heartbeat=ts())
            start = last_act = time.time()
            last_size, last_cpu, cpu_seen = 0, 0.0, {}
            last_repo = self.repo_mtime() if stall_s else 0.0
            reason = "exit"
            spawned: dict[int, psutil.Process] = {}
            while p.poll() is None:
                time.sleep(5)
                try:
                    for c in psutil.Process(p.pid).children(recursive=True):
                        spawned.setdefault(c.pid, c)
                except psutil.Error:
                    pass
                if STOP_PATH.exists():
                    kill_tree(p.pid)
                    if fg:
                        self.save(agent_pid=None)
                    raise Halt("STOP requested")
                now = time.time()
                size = log_path.stat().st_size
                cpu = tree_cpu(p.pid, cpu_seen)
                rm = self.repo_mtime() if stall_s else 0.0
                if size != last_size or cpu - last_cpu > 0.5 or rm > last_repo:
                    last_act = now
                    last_size, last_cpu, last_repo = size, cpu, rm
                if now - self._last_save > 30:
                    self.save(heartbeat=ts())
                if now - start > timeout:
                    reason = "timeout"
                elif stall_s and now - last_act > stall_s:
                    reason = "stall"
                if reason != "exit":
                    log(f"{argv[0]}: {reason}, killing pid {p.pid}")
                    kill_tree(p.pid)
                    break
        # Agents can leave helper processes running after they exit (servers, shells). Clean them up
        # so nothing keeps working on the repo between phases.
        leftovers = [c for c in spawned.values() if c.is_running()]
        for c in leftovers:
            try:
                c.kill()
            except psutil.Error:
                pass
        if leftovers:
            log(f"cleaned up {len(leftovers)} leftover process(es) from {Path(argv[0]).name}")
        if fg:
            self.save(agent_pid=None)
        if guard_hash() != self.guard:
            raise Halt("relay files were modified during an agent run; inspect before restarting")
        return (p.returncode if reason == "exit" else None), reason

    # ---- agents

    def claude(self, prompt: str, tag: str) -> str:
        if not self.claude_allowed(tag):
            raise AgentFailed(f"claude {tag}: Claude is reserved for {self.cfg.get('claude_only_for')}")
        c = self.cfg["claude"]
        pf = self.cyc / f"{tag}_PROMPT.md"
        write(pf, prompt)
        instr = (f"Read the file {pf} and follow its instructions exactly. Do not modify any files. "
                 "Your final message is captured verbatim by an automated controller.")
        argv = [c["cmd"], "-p", instr, "--output-format", "json", "--max-turns", str(c["max_turns"])]
        if c.get("model"):
            argv += ["--model", c["model"]]
        argv += ["--allowedTools", *c["allowed_tools"], "--disallowedTools", *c["disallowed_tools"]]

        before = self.git("status", "--porcelain", "-uall", check=False)
        for attempt in (1, 2):
            lp = self.cyc / "logs" / f"claude_{tag}_{int(time.time())}.log"
            log(f"claude {tag} (try {attempt})")
            rc, why = self.run_proc(argv, lp, self.cfg["timeouts"]["claude"])
            if self.git("status", "--porcelain", "-uall", check=False) != before:
                self.repo_changed_by(f"Claude {tag}")
            raw = read(lp)
            data = last_json_line(raw)
            ok = why == "exit" and data and not data.get("is_error") and data.get("subtype") == "success"
            if ok:
                return data.get("result", "")
            if LIMIT_RE.search(raw):
                # Owner (2026-10-07): when the local Claude usage is maxed out, continue on the cloud credits.
                if self.cloud_ok():
                    try:
                        return self.claude_cloud(prompt, tag)
                    except (CloudError, OSError, subprocess.SubprocessError) as e:
                        log(f"cloud fallback for {tag} failed ({str(e)[:200]})")
                raise UsageLimited(f"claude {tag}: {tail(raw, 300)}")
            if NET_RE.search(tail(raw, 3000)):
                raise NetworkDown(f"claude {tag} network problem: {tail(raw, 200)}")
            log(f"claude {tag} failed ({why}, rc={rc}): {tail(raw, 300)}")
        raise AgentFailed(f"claude {tag} failed twice")

    def claude_cloud(self, prompt: str, tag: str) -> str:
        """Run one read-only Claude step as a Claude Code cloud session (cloud credits): the prompt and every local
        file it names (cycle files, screenshots, reports under .review, which git ignores) go into .cloud/ctx/ on a
        context branch; the session writes its final message to .cloud/RESULT.md on a result branch."""
        import tempfile
        stamp = int(time.time())
        ctx_branch = f"relay/ask-{tag.lower()}-{stamp}"
        result_branch = f"claude/relay-ask-{tag.lower()}-{stamp}"
        tmp = Path(tempfile.mkdtemp(prefix=f"{G.SLUG}-cloud-"))
        shutil.rmtree(tmp, ignore_errors=True)
        self.git("worktree", "add", "-b", ctx_branch, str(tmp), "HEAD")
        try:
            text, total = prompt, 0
            seen = set()
            pat = re.compile(r"[A-Za-z]:[\\/][^\s`'\"<>|*?]+|\.review[\\/][^\s`'\"<>|*?]+")
            for m in sorted(set(pat.findall(prompt)), key=len, reverse=True):
                raw_path = m.rstrip(".,;:)]")
                src = Path(raw_path) if re.match(r"[A-Za-z]:", raw_path) else self.repo / raw_path
                try:
                    rel = src.resolve().relative_to(self.repo.resolve())
                except (ValueError, OSError):
                    continue
                if rel.parts and rel.parts[0] != ".review":
                    text = text.replace(raw_path, rel.as_posix())   # tracked files are in the clone already
                    continue
                files = [src] if src.is_file() else (sorted(q for q in src.rglob("*") if q.is_file())
                                                     if src.is_dir() else [])
                for f in files:
                    r = f.resolve().relative_to(self.repo.resolve()).as_posix()
                    if r in seen:
                        continue
                    total += f.stat().st_size
                    if total > 60_000_000:
                        break
                    seen.add(r)
                    dst = tmp / ".cloud" / "ctx" / r
                    dst.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(f, dst)
                text = text.replace(raw_path, ".cloud/ctx/" + rel.as_posix())
            text += (f"\n\n---\nYou are running as a Claude Code cloud session. The local files this task names are "
                     f"copied under .cloud/ctx/ (paths above are already rewritten). Do NOT modify any other file. "
                     f"When done, write your COMPLETE final message (exactly what you would reply) to "
                     f".cloud/RESULT.md, commit it, and push it to a new branch named exactly `{result_branch}`. "
                     "Do not open a pull request.\n")
            (tmp / ".cloud").mkdir(exist_ok=True)
            (tmp / ".cloud" / "PROMPT.md").write_text(text, encoding="utf-8")
            write(self.cyc / f"{tag}_CLOUD_PROMPT.md", text)

            def wgit(*a):
                r = subprocess.run(["git", "-c", "safe.directory=*", *a], cwd=tmp, capture_output=True, text=True)
                if r.returncode:
                    raise CloudError(f"git {' '.join(a[:2])}: {(r.stderr or r.stdout)[-300:]}")
                return r.stdout.strip()
            wgit("add", "-f", ".cloud")
            wgit("commit", "--no-verify", "-q", "-m", f"cloud context for {tag}")
            wgit("push", "--force", self.cloud.remote, f"HEAD:refs/heads/{ctx_branch}")
            cloud = Cloud(self.cfg.get("cloud", {}), self.cfg["claude"]["cmd"], tmp, HERE, self.git, log)
            entry = cloud.launch(f"ask-{tag.lower()}", f"cycle {self.state.get('cycle', 0):03d} {tag}", text,
                                 self.cyc / "logs" / f"cloud_{tag}_{stamp}.log")
            log(f"claude {tag}: local usage limit reached; running it in the cloud ({entry.get('url') or ''})")
            head = self.cloud.wait_for(result_branch, ".cloud/RESULT.md",
                                       int(self.cfg.get("cloud", {}).get("ask_timeout_s", 3600)),
                                       STOP_PATH.exists, lambda: self.save(heartbeat=ts()))
            if STOP_PATH.exists():
                raise Halt("STOP requested")
            if head is None:
                raise CloudError(f"cloud {tag} gave no result in time")
            out = self.cloud.show(head, ".cloud/RESULT.md")
            log(f"claude {tag}: cloud result received ({len(out)} chars)")
            return out
        finally:
            self.git("worktree", "remove", "--force", str(tmp), check=False)
            self.git("branch", "-D", ctx_branch, check=False)
            shutil.rmtree(tmp, ignore_errors=True)
            self.delete_remote_branches(ctx_branch, result_branch)

    # Phases that may run while the lane-merge suite is still going. CHATFIX is the ChatGPT build when DeepSeek is
    # limited (cycle 307 waited 7 min for the lane-merge suite before ChatGPT could start building); TEST blocks.
    MERGE_CHECK_NONBLOCKING = ("PLAN", "ART", "BRIEF", "BUILD", "CHATFIX")
    CRITICAL_TAGS = {"PLAN", "FINAL", "CHATFIX", "TRIAGE", "RESCUE", "BRIEF", "REVIEW"}
    _bg_slots_lock = threading.Lock()

    def _background_slots(self) -> threading.BoundedSemaphore:
        with self._bg_slots_lock:
            if getattr(self, "_bg_slots", None) is None:
                self._bg_slots = threading.BoundedSemaphore(int(self.cfg["chatgpt"].get("max_background", 6)))
            return self._bg_slots

    def _ask_chatgpt(self, prompt: str, tag: str, attempt: int, timeout: int | None = None,
                     done=None, files: list | None = None) -> str | None:
        g = self.cfg["chatgpt"]
        if getattr(self._tls, "bridge", None) is None:
            from chatgpt_bridge import ChatGPTBridge
            self._tls.bridge = ChatGPTBridge(g, log)
        from chatgpt_bridge import BridgeError
        if STOP_PATH.exists():
            raise Halt("STOP requested")
        mode = g.get("modes", {}).get(tag, "chat")
        eff = g.get("effort", {})
        effort = eff.get(tag) or eff.get(tag.split("_", 1)[0]) or eff.get("default")
        if g.get("file_tool") == "sentinelx" and not any(str(f).endswith(".zip") for f in files or []):
            host = g.get("sentinel_host", "win-julespc")
            prompt = P.use_sentinelx(prompt, host)
            # Owner 2026-11-05: "most of the information for the planners should live inside the sentinelx folders";
            # the chat gets a short message, the full prompt waits in the cycle folder for SentinelX to read.
            if g.get("sentinel_ask_file", True) and len(prompt) > int(g.get("sentinel_ask_min_chars", 1200)):
                ask = self.cyc / "asks" / f"{tag}_{attempt}.md"
                write(ask, prompt)
                prompt = P.sentinel_ask(ask, host, files)
        # Owner 2026-10-10: the critical path (main plans, final review, main fixes) never queues behind background
        # chats; lane planning/reviews/lessons/audits share chatgpt.max_background slots (next plan took 17 min with
        # 7-8 chats open at once).
        background = tag.split("_", 1)[0] not in self.CRITICAL_TAGS
        sem = self._background_slots() if background else None
        if sem is not None:
            while not sem.acquire(timeout=5):
                if STOP_PATH.exists():
                    raise Halt("STOP requested")
        if tag == "PLAN_NEXT":
            self._plan_next_try_at = time.time()   # join_bg lets a try that is still young finish
        log(f"chatgpt {tag} [{mode}] (try {attempt})")
        try:
            # Owner 2026-10-11: a hung lane-planning chat held a background slot for its full 60 min (cycle 156
            # LANESPLAN_codex, 46+ min, no reply), starving prefetches; per-tag timeouts free the slot sooner.
            limit = timeout or (g.get("tag_timeouts") or {}).get(tag.split("_", 1)[0]) or self.cfg["timeouts"]["chatgpt"]
            reply = self._tls.bridge.ask(prompt, int(limit),
                                    debug_dir=self.cyc / "logs", should_stop=STOP_PATH.exists,
                                    mode=mode, done=done, files=files, effort=effort)
        except BridgeError as e:
            log(f"chatgpt {tag} bridge error: {e}")
            note_bridge_error(str(e))
            sleep_checked(30)
            return None
        finally:
            if sem is not None:
                sem.release()
        write(self.cyc / f"{tag}_CHATGPT_REPLY_{attempt}.md", reply)
        return reply

    def chatgpt(self, prompt: str, tag: str, marker: str) -> str | None:
        """Paste mode: content in the message, result parsed from the reply."""
        if not self.cfg["chatgpt"].get("enabled"):
            return None
        write(self.cyc / f"{tag}_CHATGPT_PROMPT.md", prompt)
        for attempt in (1, 2):
            reply = self._ask_chatgpt(prompt, tag, attempt)
            if reply and extract(reply, marker) is not None:
                return reply
            log(f"chatgpt {tag}: no usable reply")
        return None

    def _zip_refs(self, text: str) -> dict[str, Path]:
        """Files a task names by absolute path that the repo snapshot lacks (owner 2026-10-19: lane4's review fell
        back to the zip upload, which held only the cycle branch, so ChatGPT never saw the lane's diff, report or
        worktree and deferred the merge). A *_TASK.md it names is read for more paths; a named git worktree adds the
        files it changed against main. Returns zip path -> file."""
        skip = re.compile(r"\.(png|jpe?g|webp|import|uid|ogg|wav|mp3|ttf|otf|zip|exe|dll|pck|wasm)$", re.I)
        pat = re.compile(r"[A-Za-z]:[\\/][^\s`'\"()<>|*?,;]+")
        texts, seen, out = [text], set(), {}

        def zname(f: Path) -> str:
            try:
                return f.resolve().relative_to(self.repo).as_posix()
            except ValueError:
                d = f.resolve()
                return f"_ext/{d.drive.rstrip(':')}/" + "/".join(d.parts[1:])

        def add(f: Path) -> None:
            if f.is_file() and not skip.search(f.name) and f.stat().st_size < 2_000_000 and len(out) < 400:
                out[zname(f)] = f

        while texts:
            for m in pat.findall(texts.pop()):
                f = Path(m.rstrip(".:)]"))
                key = str(f).lower()
                if key in seen:
                    continue
                seen.add(key)
                try:
                    if f.is_file():
                        add(f)
                        if f.name.endswith("_TASK.md") and len(seen) < 200:
                            texts.append(read(f))
                    elif f.is_dir() and f.resolve() != self.repo and (f / ".git").exists():
                        r = subprocess.run(["git", "diff", "--name-only", f"{self.main}...HEAD"], cwd=f,
                                           capture_output=True, text=True, encoding="utf-8", errors="replace")
                        u = subprocess.run(["git", "ls-files", "--others", "--exclude-standard"], cwd=f,
                                           capture_output=True, text=True, encoding="utf-8", errors="replace")
                        for rel in (r.stdout + "\n" + u.stdout).splitlines()[:300]:
                            if rel.strip():
                                add(f / rel.strip())
                except OSError:
                    continue
        return out

    def context_zip(self, tag: str, refs: str = "") -> Path:
        """Snapshot for ChatGPT's file tools: repo text files (working tree, incl. new files), design docs, this
        cycle's relay files and git info, at the same relative paths as on disk; plus the files `refs` names
        (_zip_refs), outside the repo under _ext/<drive>/..."""
        import zipfile
        z = self.cyc / f"context_{tag}.zip"
        skip = re.compile(r"\.(png|jpe?g|webp|import|uid|ogg|wav|mp3|ttf|otf|zip|exe|dll|pck|wasm)$", re.I)
        files = set(self.git("ls-files", check=False).splitlines())
        files |= set(self.git("ls-files", "--others", "--exclude-standard", check=False).splitlines())
        rev = self.repo / ".review"
        extra = [p for p in (rev / "full_game").glob("*.md")]
        extra += [rev / "relay_v2" / n for n in ("LESSONS.md", "flaky_tests.json")]
        extra += sorted((rev / "relay_v2" / "playtests").glob("PLAYTEST_*.md"))[-2:]
        extra += sorted((rev / "relay_v2" / "audits").glob("*.md"))
        extra += [p for p in self.cyc.glob("*") if p.is_file() and p.suffix in (".md", ".txt", ".json")]
        with zipfile.ZipFile(z, "w", zipfile.ZIP_DEFLATED) as zf:
            for rel in sorted(files):
                p = self.repo / rel
                if p.is_file() and not skip.search(rel) and p.stat().st_size < 2_000_000:
                    zf.write(p, rel)
            for p in extra:
                if p.is_file():
                    zf.write(p, p.relative_to(self.repo).as_posix())
            zf.writestr("_git/branch.txt", self.git("rev-parse", "--abbrev-ref", "HEAD", check=False))
            zf.writestr("_git/log.txt", self.git("log", "--oneline", "-40", check=False))
            zf.writestr("_git/status.txt", self.git("status", "--porcelain", "-uall", check=False))
            zf.writestr("_git/diff_vs_main.patch", self.git("diff", self.main, check=False))
            zf.writestr("_git/diff_staged_vs_main.patch", self.git("diff", "--cached", self.main, check=False))
            names = set(zf.namelist())
            ext = {n: f for n, f in self._zip_refs(refs).items() if n not in names} if refs else {}
            for n, f in ext.items():
                zf.write(f, n)
            if ext:
                zf.writestr("_refs/INDEX.txt", "".join(f"{f} -> {n}\n" for n, f in sorted(ext.items())))
        return z

    def chatgpt_file(self, prompt: str, tag: str, out: Path, images: list | None = None) -> str | None:
        """ChatGPT reads an uploaded context zip and returns the output file's content in its reply
        (Desktop Commander file access hit its monthly cap on 2026-10-06; attachment mode needs no connector).
        `images` (attach mode only) are uploaded next to the zip so ChatGPT sees them directly."""
        if not self.cfg["chatgpt"].get("enabled"):
            return None
        if self.cfg["chatgpt"].get("attach_mode", True):
            return self.chatgpt_attach(prompt, tag, out, images=images)
        got = self._chatgpt_tool_file(prompt, tag, out, images=images)
        if got is None and self.cfg["chatgpt"].get("file_tool") == "sentinelx":
            # Owner 2026-11-05 ("its not using sentinelx"): tries that never reached ChatGPT (relay Chrome down) are
            # not SentinelX's fault; ask through SentinelX again instead of a zip upload with no connector.
            if getattr(self._tls, "tool_file_unreached", False):
                log(f"chatgpt {tag}: the relay Chrome was unreachable, not SentinelX; asking through SentinelX again")
                got = self._chatgpt_tool_file(prompt, tag, out, images=images)
                if got is not None or getattr(self._tls, "tool_file_unreached", False):
                    return got
            log(f"chatgpt {tag}: SentinelX gave no file; falling back to the zip upload")
            return self.chatgpt_attach(prompt, tag, out, images=images)
        return got

    def _chatgpt_tool_file(self, prompt: str, tag: str, out: Path, images: list | None = None) -> str | None:
        """ChatGPT writes `out` itself through a file connector (SentinelX or Desktop Commander).
        `images` are uploaded with the message so ChatGPT sees them directly."""
        write(self.cyc / f"{tag}_CHATGPT_PROMPT.md", prompt)
        snap = (self.git("rev-parse", "HEAD"), self.git("status", "--porcelain", "-uall", check=False))
        guard = guard_hash()
        def written() -> bool:   # the output file is the real result; finished once it ends with the end mark
            try:
                st = out.stat()
            except OSError:
                return False
            age = time.time() - st.st_mtime
            if st.st_size <= 0 or age <= 20:
                return False
            # Owner 2026-10-13: ChatGPT writes long answers in parts. Cycle 211's PLAN_NEXT paused 37 s between
            # parts; the relay took the half-written file (plan, no brief) and cycle 212 spent 8 min writing one.
            return age > 300 or P.FILE_END in read(out)[-200:]

        tls = getattr(self, "_tls", None) or threading.local()
        tls.tool_file_unreached = True   # stays True while every try ends in a bridge error (no reply)
        for attempt in (1, 2):
            out.unlink(missing_ok=True)
            if self._ask_chatgpt(prompt, tag, attempt, done=written,
                                 **({"files": list(images)} if images else {})) is not None:
                tls.tool_file_unreached = False
            now = (self.git("rev-parse", "HEAD"), self.git("status", "--porcelain", "-uall", check=False))
            if guard_hash() != guard:
                raise Halt(f"ChatGPT modified relay files during {tag}; inspect before restarting")
            if now != snap:
                self.repo_changed_by(f"ChatGPT {tag}")
                snap = now
            if out.exists() and read(out).strip():
                text = read(out)
                if P.FILE_END in text:
                    text = text.replace(P.FILE_END, "").rstrip() + "\n"
                    write(out, text)
                return text
            log(f"chatgpt {tag}: {out.name} not written")
        return None

    def repo_changed_by(self, who: str) -> None:
        """Owner allows ChatGPT/Claude to edit the repo (2026-10-06): note it for the final review and playtest,
        but never let a step leave the cycle branch."""
        if getattr(self._tls, "bg", False):
            return   # background planning runs while DeepSeek edits the tree; those changes are DeepSeek's
        br = self.git("rev-parse", "--abbrev-ref", "HEAD", check=False).strip()
        if self.state.get("branch") and br != self.state["branch"]:
            raise Halt(f"{who} switched the repo to branch {br}; inspect before restarting")
        log(f"note: {who} changed files in the repo; the final review and playtest will check them")
        with open(self.cyc / "AGENT_EDITS.md", "a", encoding="utf-8") as f:
            f.write(f"- {time.strftime('%H:%M:%S')} {who} changed files:\n```\n"
                    f"{self.git('status', '--porcelain', '-uall', check=False)}\n```\n")

    def role(self, tag: str) -> str:
        """Who answers a reasoning step: "chatgpt" or "claude" (relay.json roles; tag prefix match)."""
        roles = self.cfg.get("roles", {})
        return roles.get(tag) or roles.get(tag.split("_", 1)[0]) or "claude"

    def think(self, prompt: str, tag: str) -> str:
        """Read-only reasoning step (plan, final review, audit). Routed per relay.json roles."""
        if self.role(tag) != "chatgpt":
            return self.claude(prompt, tag)
        pf = self.cyc / f"{tag}_TASK.md"
        out = self.cyc / f"{tag}_ANSWER.md"
        write(pf, prompt)
        refs = self.planner_refs(tag)
        msg = P.DELEGATE_FILE.substitute(task_path=pf, out_path=out, repo=self.repo)
        if refs:
            msg += P.refs_note(refs)
        msg += self.ref_request_note(tag)
        got = self.chatgpt_file(msg, tag, out, images=refs)
        if got and got.strip():
            return self.take_ref_requests(got, tag)
        if self.cfg.get("roles", {}).get("fallback") == "claude":
            log(f"{tag}: ChatGPT gave no answer; falling back to Claude")
            return self.claude(prompt, tag)
        raise UsageLimited(f"chatgpt {tag} gave no answer")

    # Owner 2026-11-04: "put images of darkest dungeon in the areas where the planners interact ... if they plan
    # the combat system ui, show images of what it looks like". Groups of refs/dd shots and the words that call them.
    REF_GROUPS = planner_mock.REF_GROUPS

    @staticmethod
    def planner_tag(tag: str) -> bool:
        """A planning step: the main plan, the next plan, a lane plan (LANE2PLAN, LANESPLAN_lane3+lane7)."""
        return tag in ("PLAN", "PLAN_NEXT") or tag.partition("_")[0].endswith("PLAN")

    def ref_requests_on(self, tag: str) -> bool:
        return ((self.planner_tag(tag) or tag == "DESIGNREVIEW")
                and self.cfg["chatgpt"].get("planner_ref_requests", True) is not False)

    def ref_request_note(self, tag: str) -> str:
        """Owner 2026-11-04: planners may ask for a picture (planner_mock.take_requests)."""
        return P.REF_REQUEST_NOTE if self.ref_requests_on(tag) else ""

    def take_ref_requests(self, text: str, tag: str) -> str:
        """Queue the answer's @@REF@@ picture requests and return the answer without them."""
        if not self.ref_requests_on(tag):
            return text
        try:
            planner_mock.take_requests(text, tag, HERE.parent / "full_game" / "refs" / "mock", log)
        except Exception as e:   # noqa: BLE001 - a picture is best effort
            log(f"planner picture: could not queue the request ({type(e).__name__}: {str(e)[:120]})")
        return planner_mock.strip_requests(text)

    def asked_refs(self, tag: str) -> list:
        """The pictures planners asked for, drawn and not yet shown twice."""
        if not self.ref_requests_on(tag):
            return []
        try:
            return planner_mock.requested(HERE.parent / "full_game" / "refs" / "mock", 2, log)
        except Exception:   # noqa: BLE001
            return []

    def planner_refs(self, tag: str, limit: int = 4) -> list:
        """Reference screenshots for a planning step, picked by what it plans: the lane's area for a lane plan,
        the open DESIGN_NEXT step for the main plan. Earliest-mentioned topic first, after the pictures planners
        asked for."""
        g = self.cfg["chatgpt"]
        head, _, group = tag.partition("_")
        if not g.get("planner_refs", True) or not self.planner_tag(tag):
            return []
        asked = self.asked_refs(tag)
        d = HERE.parent / "full_game" / "refs" / "dd"
        if not d.is_dir():
            return asked
        # LANE2PLAN plans lane2; LANESPLAN_lane2 (or a group such as LANESPLAN_lane3+lane7) plans the lanes it names
        keys = re.findall(r"[a-z]+\d*", group.lower()) if head == "LANESPLAN" else [head[:-4].lower()]
        lanes = [self.cfg[k] for k in keys if isinstance(self.cfg.get(k), dict) and self.cfg[k].get("area")]
        if lanes:
            focus = " ".join(f"{c['area']} {c.get('plan_focus', '')}" for c in lanes)
        else:
            try:
                focus = read(Path(P.DESIGN_NEXT))[:700]
            except OSError:
                focus = ""
        # owner 2026-11-04: a Flow mockup of OUR screen leads when the step plans a screen (planner_mock.py)
        return asked + planner_mock.pick_refs(focus, d, limit, "draw" if g.get("planner_mockups", True) else None, log)

    def coder_refs(self, text: str) -> list:
        """Owner 2026-11-04: "if the coders can understand images then give it to them aswell". Screen tasks only:
        our cached Flow mockup and the matching refs/dd shots (a build never waits for Flow)."""
        focus = text[:1500]
        if not self.cfg["chatgpt"].get("coder_refs", True) or not planner_mock.pick(focus):
            return []
        return planner_mock.pick_refs(focus, HERE.parent / "full_game" / "refs" / "dd", 3, "cached", log)

    def note_coder_refs(self, brief: Path) -> None:
        """Lists the main task's reference images in its brief (every coder reads it) and keeps them for the coders
        that take image attachments (Codex -i, ChatGPT chat)."""
        text = read(brief)
        refs = self.coder_refs(text)
        if refs and "## Reference images" not in text:
            write(brief, text + P.coder_refs_note(refs))
        self.save(coder_refs=[str(r) for r in refs])

    def chatgpt_attach(self, prompt: str, tag: str, out: Path, images: list | None = None) -> str | None:
        i = prompt.find("Rules for this task:")
        body = prompt[:i] if i >= 0 else prompt
        body = body.replace("abilities through Desktop Commander:", "abilities through the attached context zip:")
        rules = P.ATTACH_RULES.substitute(repo=self.repo.as_posix(), out_path=out)
        text = body.rstrip() + "\n\n" + rules
        write(self.cyc / f"{tag}_CHATGPT_PROMPT.md", text)
        snap = (self.git("rev-parse", "HEAD"), self.git("status", "--porcelain", "-uall", check=False))
        for attempt in (1, 2):
            z = self.context_zip(tag, text)
            reply = self._ask_chatgpt(text, tag, attempt, files=[z, *(images or [])])
            now = (self.git("rev-parse", "HEAD"), self.git("status", "--porcelain", "-uall", check=False))
            if now != snap:
                self.repo_changed_by(f"ChatGPT {tag}")
                snap = now
            content = extract(reply or "", "OUTPUT")
            if content and content.strip():
                write(out, content.strip() + "\n")
                return read(out)
            log(f"chatgpt {tag}: no @@OUTPUT@@ block in the reply")
        return None

    def run_tests(self, folder: Path, name: str, excuse_owed: bool = False) -> tuple[bool, Path]:
        """excuse_owed (lane merges, baseline): tests in slow_owed.json already fail on main and do not fail this run;
        the cycle's own TEST runs them and must fix them."""
        lp = folder / f"{name}.txt"
        env = dict(os.environ, RELAY_EXCUSE_OWED="1") if excuse_owed else None
        rc, why = self.run_proc(self.cfg["test_cmd"], lp, self.cfg["timeouts"]["tests"], env=env)
        passed = why == "exit" and rc == 0
        if not passed and excuse_owed and why == "exit" and self._only_owed_failures(lp):
            log(f"tests {name}: its only failures are slow tests the background slow check found failing on "
                f"{self.main}; counted as a pass (the next cycle must fix them)")
            passed = True
        log(f"tests {name}: {'PASS' if passed else 'FAIL'} ({why}, rc={rc})")
        return passed, lp

    # ---- background slow check
    # Owner 2026-10-18 (cycles under 30 min): main-checkout suites leave out the slow tier (run_tests.py SLOW_TIER_S,
    # 14 tests, ~39% of a 17-minute suite). It runs here on each accepted commit, in its own worktree, alongside the
    # next cycle. Failures go to slow_owed.json: the next cycle's suite runs them and must fix them, while lane-merge
    # and baseline suites do not fail on them (they already fail on main).

    def load_slow_owed(self) -> dict:
        try:
            d = json.loads(read(SLOW_OWED))
            return d if isinstance(d, dict) and d.get("tests") else {}
        except (OSError, ValueError):
            return {}

    def owed_note(self) -> str:
        """2026-10-18: cycle 408 reused a plan prepared before the owed ink-price test was known, so its brief never
        mentioned the test its suite must fix (cycle 407 deferred on it). Every main brief now names owed tests."""
        owed = self.load_slow_owed()
        if not owed:
            return ""
        tests = ", ".join(f"tests/{t}" for t in owed["tests"])
        return (f"\n\n## Owed slow tests (part of this task)\n{tests} already fail(s) on {self.main} (found by the "
                f"background slow check on {str(owed.get('commit', '?'))[:8]}, cycle {owed.get('cycle', '?')}). This "
                "cycle's full suite runs them and cannot be accepted until they pass, so fixing them is part of this "
                "task: find whether the code or the test is wrong, fix the real cause (never weaken an assertion "
                "just to pass), and you may edit those test files. They are reserved for this cycle.\n")

    def _slow_running(self) -> bool:
        box = getattr(self, "_slow_box", None)
        return bool(box and box["thread"].is_alive())

    def _only_owed_failures(self, lp) -> bool:
        """A finished suite whose only failures are owed slow tests. The slow check may still have been running when
        the suite started (so run_tests.py could not excuse them): wait for it first."""
        if self._slow_running():
            log("waiting for the background slow check before judging a suite failure")
            t, n = self._slow_box["thread"], 0
            while t.is_alive():
                t.join(5)
                n += 1
                if STOP_PATH.exists():
                    raise Halt("STOP requested")
                if n % 12 == 0 and not getattr(self._tls, "bg", False):
                    self.save(heartbeat=ts())
        try:
            text = read(Path(lp))
        except (OSError, TypeError):
            return False
        failed = set(SUITE_FAIL_RE.findall(text))
        owed = set(self.load_slow_owed().get("tests", []))
        finished = re.search(r"^\d+/\d+ passed\s*$", text, re.M) is not None
        return bool(failed) and failed <= owed and finished and "RELATED TESTS FAILED FIRST" not in text

    def begin_slow_check(self, n: int) -> None:
        if not self.cfg.get("slow_check", True):
            return
        head = self.git("rev-parse", "HEAD").strip()
        self.save(slow_check={"head": head, "cycle": n, "at": ts(), "tries": 0})
        if self._slow_running():   # the running one starts this one when it finishes (one worktree)
            log(f"slow check: queued for {head[:8]} (cycle {n:03d}) behind the one still running")
            return
        # 2026-10-19: a check started a second before a PAUSE halt outlived the controller (its parent watcher had
        # not armed yet), held all three slow slots and made the restarted check wait 30 min and time out.
        if STOP_PATH.exists() or PAUSE_PATH.exists():
            log(f"slow check: {head[:8]} (cycle {n:03d}) waits for the restart (the relay is halting)")
            return
        self.start_slow_check()

    def ensure_slow_check(self) -> None:
        """At cycle start: restart a slow check that a controller restart (or an error) interrupted."""
        sc = self.state.get("slow_check")
        if not sc or self._slow_running():
            return
        if int(sc.get("tries", 0)) >= 2:
            log(f"slow check: gave up on {sc['head'][:8]} after {sc['tries']} interrupted runs; the next accepted "
                "commit gets a new one")
            self.save(slow_check=None)
            return
        self.save(slow_check={**sc, "tries": int(sc.get("tries", 0)) + 1})
        log(f"slow check: restarting the interrupted check of {sc['head'][:8]} (cycle {int(sc['cycle']):03d})")
        self.start_slow_check()

    @staticmethod
    def _kill_stray_slow_checks() -> int:
        """Stop --slow-only runs this controller did not start (one left by an earlier controller holds the slow slots
        and the worktree). Only called when no check of ours is running."""
        n = 0
        for p in psutil.process_iter(["pid", "cmdline"]):
            try:
                cmd = p.info["cmdline"] or []
                if p.info["pid"] != os.getpid() and "--slow-only" in cmd and any("run_tests" in c for c in cmd):
                    kill_tree(p.info["pid"])
                    n += 1
            except psutil.Error:
                pass
        if n:
            log(f"slow check: stopped {n} stray slow-check run(s) left by an earlier controller")
        return n

    def start_slow_check(self) -> dict | None:
        sc = self.state.get("slow_check")
        if not sc:
            return None
        root = Path(self.cfg.get("slow_check_dir", G.tmp_dir("slowcheck")))
        try:
            if (root / ".git").exists():
                self.git("-C", str(root), "checkout", "--detach", "--force", sc["head"])
                self.git("-C", str(root), "clean", "-fdx", "-e", ".godot", check=False)   # keep the import cache
            else:
                shutil.rmtree(root, ignore_errors=True)
                self.git("worktree", "prune", check=False)
                self.git("worktree", "add", "--detach", "--force", str(root), sc["head"])
        except Exception as e:   # noqa: BLE001 - the slow check is best effort; the next cycle start retries it
            log(f"slow check: could not prepare {root} ({type(e).__name__}: {str(e)[:160]})")
            return None
        self._kill_stray_slow_checks()
        argv = [*self.cfg["test_cmd"], "--repo", root.as_posix(), "--slow-only"]
        box: dict = {"head": sc["head"]}

        def run() -> None:
            self._tls.bg = True
            lp = CYCLES / "_slowcheck" / f"slow_{int(sc['cycle']):03d}_{int(time.time())}.txt"
            try:
                # 2026-10-19: ~20 slow tests on 3 slots beside a main suite and lane suites need over 30 min.
                rc, why = self.run_proc(argv, lp, int(self.cfg.get("slow_check_timeout_s", 3600)))
                text = read(lp) if lp.exists() else ""
                m = re.search(r"^SLOW FAILED:(.*)$", text, re.M)
                if why != "exit" or m is None or rc not in (0, 1):
                    log(f"slow check: no result for {sc['head'][:8]} ({why}, rc={rc}; {lp.name}); retried at the "
                        "next cycle start")
                    return
                self._record_slow_result(sc, m.group(1).split(), lp)
                nxt = self.state.get("slow_check")
                if nxt and nxt.get("head") != sc["head"]:
                    self.start_slow_check()
            except BaseException as e:   # noqa: BLE001 - no result: the next cycle start runs it again
                log(f"slow check stopped ({type(e).__name__}: {str(e)[:160]})")

        box["thread"] = threading.Thread(target=run, name="slow-check", daemon=True)
        box["thread"].start()
        self._slow_box = box
        log(f"slow check: running the slow-tier tests on {sc['head'][:8]} (cycle {int(sc['cycle']):03d}) in "
            f"{root} alongside the next cycle")
        return box

    def _record_slow_result(self, sc: dict, failed: list[str], lp: Path) -> None:
        with self._save_lock:
            if failed:
                write(SLOW_OWED, json.dumps({"tests": sorted(failed), "commit": sc["head"], "cycle": sc["cycle"],
                                             "log": str(lp), "at": ts()}, indent=1) + "\n")
                log(f"slow check: {len(failed)} slow tests FAIL on {sc['head'][:8]} (cycle {int(sc['cycle']):03d}): "
                    f"{', '.join(failed)[:300]}; the next cycle's suite runs them and must fix them ({lp.name})")
            else:
                if SLOW_OWED.exists():
                    SLOW_OWED.unlink()
                log(f"slow check: PASS on {sc['head'][:8]} (cycle {int(sc['cycle']):03d})")
            cur = self.state.get("slow_check")
            if cur and cur.get("head") == sc["head"]:
                self.save(slow_check=None)

    # 2026-10-15: one merged tree (lane2 + lane6 on 13180424, tree c233da51) failed the full suite three times in a
    # row: the async lane-merge check, the batch retry and the one-at-a-time merge, ~37 min before cycle 289 started.
    # A lane-merge tree that already failed the suite is not run again.
    def _tree(self, rev: str = "HEAD") -> str:
        return self.git("rev-parse", f"{rev}^{{tree}}", check=False).strip()

    def _note_failed_tree(self, tree: str, lp) -> None:
        if not tree:
            return
        with self._save_lock:
            ft = [x for x in self.state.get("failed_trees") or [] if x.get("tree") != tree]
            self.save(failed_trees=(ft + [{"tree": tree, "log": str(lp or ""), "at": ts()}])[-20:])

    def merge_suite(self, folder: Path, name: str) -> tuple[bool, Path]:
        """run_tests for lane merges, skipping a tree that already failed the full suite."""
        tree = self._tree()
        hit = next((x for x in self.state.get("failed_trees") or [] if tree and x.get("tree") == tree), None)
        if hit:
            lp = folder / f"{name}.txt"
            lp.parent.mkdir(parents=True, exist_ok=True)
            old = Path(hit["log"]) if hit.get("log") else None
            write(lp, f"This exact tree ({tree[:8]}) already failed the full suite at {hit.get('at')} "
                      f"({old.name if old else 'no log'}); not running it again.\n\n"
                      + (tail(read(old), 6000) if old and old.exists() else ""))
            log(f"tests {name}: FAIL (this exact tree already failed the full suite at {str(hit.get('at'))[11:16]}; "
                "not re-running)")
            return False, lp
        passed, lp = self.run_tests(folder, name, excuse_owed=True)
        if not passed:
            self._note_failed_tree(tree, lp)
        return passed, lp

    def hard_rules(self, report_name: str) -> str:
        return P.HARD_RULES.substitute(
            relay_dir=self.relay_rel,
            test_cmd=" ".join(self.cfg["test_cmd"]),
            report_path=f"{self.relay_rel}/cycles/{self.state['cycle']:03d}/{report_name}",
            lessons=f"{self.relay_rel}/LESSONS.md",
        )

    def check_coder_report(self, path: Path) -> None:
        try:
            reason = coder_deferred_reason(read(path))
        except ValueError as e:
            raise AgentFailed(f'invalid coder status in {path.name}: {e}') from e
        if reason and suite_only_deferral(reason):
            # Cycle 406 (2026-10-18): Codex built the whole Rare batch (all B6 tests green) and deferred only because
            # its own full-suite run could not finish; the relay runs the full suite itself next, as for lanes.
            log("coder deferred only because its own full-suite run could not finish; the relay runs the suite itself")
            reason = None
        if reason:
            raise ScopeDeferred(reason)
        brief = read(self.cyc / (self.state.get('brief_file') or 'DEEPSEEK_BRIEF.md'))
        error = TP.acceptance_error(read(path), brief)
        if error:
            warning = f'{error}. Independent review must verify every original criterion directly.'
            write(path.with_name(path.stem + '_EVIDENCE_WARNING.md'), warning + '\n')
            self.save(evidence_warning=warning)
            log(f'coder report warning in {path.name}: {warning}; continuing to tests/review')

    def planning_blockers(self, key: str) -> list[dict]:
        return list(self.state.get(f'{key}_failed') or []) + [
            {**d, 'reason': 'DEFERRED decision: ' + d['reason']}
            for d in (self.state.get(f'{key}_deferred') or [])]

    # ---- phases

    # ---- Codex lane (parallel builder: Codex cloud task -> GitHub PR -> merged here when tests pass)

    def codex_cfg(self) -> dict:
        c = self.cfg.get("codex", {})
        if not c.get("enabled"):
            return {}
        if self.state.get("codex_paused_until", "") > ts():
            return {}
        return c

    def maybe_launch_codex(self) -> None:
        c = self.codex_cfg()
        if not c or not c.get("launch", True) or self.state.get("codex_task"):
            return
        from codex_lane import CodexLane, CodexError
        try:
            out = self.think(P.CODEX_PLAN.substitute(
                agent="Codex, in the cloud", avoid=self.busy_elsewhere("codex"),
                repo=self.repo, main_plan=self.cyc / "CLAUDE_PLAN.md",
                docs=HERE.parent / "full_game",
                recent="\n".join(f"- {h['title']}" for h in (self.state.get("codex_history") or [])[-8:]) or "- none",
                failed="\n".join(f"- {f['title']}: {f['reason'][:160]}"
                                  for f in self.planning_blockers('codex')[-5:]) or "- none"),
                "CODEXPLAN")
        except (AgentFailed, UsageLimited) as e:
            log(f"codex lane: no plan ({e})")
            return
        m = re.search(r"^TITLE:\s*(.+)$", out, re.M)
        title = m.group(1).strip() if m else ""
        task = extract(out, "CODEX_TASK")
        if not title or title.upper() == "NONE" or not task:
            log("codex lane: planner found no suitable parallel task")
            return
        text = (task.strip() + "\n\nFollow AGENTS.md at the repository root. Before finishing, run the full test "
                "command from AGENTS.md; every test must pass. Do not create or edit PNG/art files. Then open a pull "
                f"request titled \"Codex: {title}\".")
        text = P.coder_scope(text) + ('\nFor this cloud task, report CODER_STATUS in your final answer. '
                'If deferred, first preserve your work on its branch and open a draft pull request '
                'describing the required decision, then include its URL and DEFERRED status. '
                'Never merge your own pull request.\n')
        write(self.cyc / "CODEX_TASK.md", text)
        try:
            url = CodexLane(self.cfg["chatgpt"], log).launch(text)
        except CodexError as e:
            log(f"codex lane: launch failed ({e})")
            return
        self.save(codex_task={"title": title, "url": url, "started": ts(), "cycle": self.state["cycle"],
                              "follow_ups": 0, "match": task.strip()[:80]})
        log(f"codex lane: started \"{title}\"")
        notify(f"{G.NAME} Codex lane", title)

    def codex_boundary(self) -> None:
        """At a cycle boundary (on main, clean tree): merge a finished Codex PR if its tests pass."""
        c = self.cfg.get("codex", {})
        ct = self.state.get("codex_task")
        if not (c.get("enabled") and ct):
            return
        from codex_lane import CodexLane, CodexError
        lane = CodexLane(self.cfg["chatgpt"], log)
        try:
            st = lane.status(ct["url"], ct.get("match", ""))
            if st.get("url") and st["url"] != ct["url"]:
                ct["url"] = st["url"]
                self.save(codex_task=ct)
        except CodexError as e:
            log(f"codex lane: status unavailable ({e})")
            return
        if st["state"] == "running":
            log(f"codex lane: \"{ct['title']}\" still running")
            return
        if st["state"] == "limited":
            until = (datetime.datetime.now() + datetime.timedelta(hours=int(c.get("limit_pause_h", 6))))
            self.save(codex_paused_until=until.strftime("%Y-%m-%d %H:%M:%S"))
            log(f"codex lane: usage limit reached; paused until {until:%H:%M}")
            return
        if st["state"] != "done" or not st["pr"]:
            self.codex_give_up(ct, f"no pull request ({st['text'][-200:]!r})")
            return
        try:
            decision = coder_deferred_reason(st['text'])
        except ValueError as e:
            log(f'codex lane: invalid completion status ({e}); keeping task pending')
            return
        if decision:
            entry = {'title': ct['title'], 'pr': st['pr'], 'url': st['url'],
                     'reason': decision, 'at': ts()}
            self.save(codex_task=None,
                      codex_deferred=(self.state.get('codex_deferred') or []) + [entry])
            log(f"codex lane: preserved PR #{st['pr']} and deferred the task; continuing other work")
            return
        ok, why = self.merge_codex_pr(st["pr"], ct["title"])
        if ok:
            return
        if ct.get("follow_ups", 0) < int(c.get("max_follow_ups", 2)):
            msg = (f"Merging PR #{st['pr']} into the latest master failed: {why}\n\nPlease update the same pull "
                   "request: merge or rebase onto the latest master, resolve any conflicts, make every test in the "
                   "AGENTS.md test command pass, and push to the same branch.")
            try:
                lane.follow_up(ct["url"], msg)
                ct["follow_ups"] = ct.get("follow_ups", 0) + 1
                self.save(codex_task=ct)
                log(f"codex lane: PR #{st['pr']} sent back to Codex ({why[:80]})")
            except CodexError as e:
                self.codex_give_up(ct, f"follow-up failed: {e}")
        else:
            self.codex_give_up(ct, why, pr=st["pr"])

    def codex_give_up(self, ct: dict, reason: str, pr: int | None = None) -> None:
        if pr:
            subprocess.run(["gh", "pr", "close", str(pr), "--comment",
                            f"Closed by the {G.NAME} relay: {reason[:500]}"], cwd=self.repo, capture_output=True)
        failed = (self.state.get("codex_failed") or []) + [{"title": ct["title"], "reason": reason, "at": ts()}]
        self.save(codex_task=None, codex_failed=failed[-20:])
        log(f"codex lane: gave up on \"{ct['title']}\": {reason[:160]}")

    def merge_codex_pr(self, pr: int, title: str) -> tuple[bool, str]:
        pre = self.git("rev-parse", "HEAD")
        local = f"codex/pr-{pr}"
        if not self.git_ok("fetch", self.cloud.remote, f"+pull/{pr}/head:{local}"):
            return False, "could not fetch the PR branch"
        merge = subprocess.run(["git", "merge", "--no-ff", "--no-edit", "-m",
                                f"Codex lane: {title} (PR #{pr})\n\nMerged by relay v2 after the full test suite passed.",
                                local], cwd=self.repo, capture_output=True, text=True)
        if merge.returncode:
            self.git("merge", "--abort", check=False)
            self.git("reset", "--hard", pre, check=False)
            return False, "merge conflict: " + tail(merge.stdout + merge.stderr, 600)
        passed, lp = self.run_tests(CYCLES / "_codex", f"pr{pr}_{int(time.time())}")
        if not passed:
            self.git("reset", "--hard", pre, check=False)
            return False, "tests fail after merging: " + tail(read(lp), 1500)
        commit = self.git("rev-parse", "--short", "HEAD")
        if not self.git_ok("push", self.cloud.remote, self.main):
            log(f"warning: could not push {self.main} after the Codex merge")
        self.git("branch", "-D", local, check=False)
        hist = (self.state.get("codex_history") or []) + [{"title": title, "pr": pr, "commit": commit, "at": ts()}]
        self.save(codex_task=None, codex_history=hist[-50:], last_good_commit=commit,
                  tested_main=self.git("rev-parse", "HEAD"))
        log(f"=== codex lane PR #{pr} MERGED -> {commit} ({title}) ===")
        notify(f"{G.NAME} Codex lane merged", title)
        return True, ""

    # ---- local DeepSeek lanes (lane2, lane3): each a DeepSeek in its own git worktree

    LANE_KEYS = ("lane2", "lane3", "lane4", "lane5", "lane6", "lane7", "lane8")

    # ---- DeepSeek usage limit (owner 2026-10-11): the OpenCode Go plan ran out ("Go usage limit exceeded") and the
    # main BUILD waited in 30-min retries while three DeepSeek lanes hung. While limited, ChatGPT Chat (the owner's
    # fallback coder) builds instead; DeepSeek is tried again after opencode.limit_cooldown_s.

    def deepseek_limited(self) -> bool:
        until = float(self.state.get("deepseek_limited_until") or 0)
        known = self.cfg.get("opencode", {}).get("limited_until")   # owner-reported reset time, "YYYY-MM-DD HH:MM"
        if known:
            try:
                until = max(until, datetime.datetime.strptime(known, "%Y-%m-%d %H:%M").timestamp())
            except ValueError:
                pass
        return time.time() < until or bool(self.credit_block())

    # ---- DeepSeek on OpenCode credits (owner 2026-10-15: "you can use deepseek on the credits. just dont go over
    # $3"). With "Use balance" on in the OpenCode console, a Go plan past its limit bills the pay-as-you-go balance
    # instead of failing. opencode.credit = {since, until, base_usd, cap_usd, peak_margin_min}: from `since` to
    # `until` (the Go reset) every opencode-go DeepSeek cost counts against the cap, measured by `opencode stats`
    # (list price; base_usd is the DeepSeek cost already spent on the `since` day before it). At the cap, or in
    # DeepSeek's peak hours (2x price, which stats does not show), DeepSeek counts as limited and the free models
    # code instead. The cap sits under $3 by the cost of the runs still going when it is reached.

    PEAK_UTC = ((1, 4), (6, 10))   # Mon-Fri, opencode.ai/docs/go: DeepSeek costs double then

    def credit_window(self) -> "tuple | None":
        c = self.cfg.get("opencode", {}).get("credit") or {}
        try:
            since, until = (datetime.datetime.strptime(c[k], "%Y-%m-%d %H:%M") for k in ("since", "until"))
        except (KeyError, TypeError, ValueError):
            return None
        return (since, until, c) if since <= datetime.datetime.now() < until else None

    @classmethod
    def deepseek_peak(cls, now_utc: datetime.datetime, margin_min: float = 0) -> bool:
        """True if DeepSeek's peak price applies at any time from now_utc to margin_min minutes later."""
        t, end = now_utc, now_utc + datetime.timedelta(minutes=margin_min)
        while t <= end:
            if t.weekday() < 5 and any(a <= t.hour < b for a, b in cls.PEAK_UTC):
                return True
            t += datetime.timedelta(minutes=5)
        return False

    def credit_spent(self, since: datetime.datetime, base: float) -> "float | None":
        """opencode-go DeepSeek cost (list price) since `since`, or None if `opencode stats` fails."""
        days = (datetime.date.today() - since.date()).days + 1
        cmd = self.cfg["opencode"].get("cmd", "opencode")
        try:
            out = subprocess.run([shutil.which(cmd) or cmd, "stats", "--standalone", "--days",
                                  str(days), "--models", "--json"], cwd=self.repo, capture_output=True, text=True,
                                 encoding="utf-8", errors="replace", timeout=90).stdout
            models = json.loads(out[out.index("{"):])["models"]
        except Exception:
            return None
        return sum(float(m.get("cost") or 0) for m in models if m["model"]["providerID"] == "opencode-go"
                   and "deepseek" in m["model"]["id"]) - base

    def credit_block(self, model: str = "") -> str:
        """Why DeepSeek must not code on credits now ("" when it may, or when no credit window is open)."""
        w = self.credit_window()
        # Owner 2026-10-16: "I think deepseek v4.1 is free". The main model is now OpenCode's free
        # deepseek-v4.1-flash-free, which bills nothing, so only an opencode-go model is held to the cap and peak hours.
        # Owner 2026-10-17: Go DeepSeek is now a fallback model; it is held to the same cap (model = that fallback).
        model = model or self.cfg.get("opencode", {}).get("model", "")
        if not w or (model and not model.startswith("opencode-go/")):
            return ""
        since, _until, c = w
        cache = getattr(self, "_credit_cache", None)
        if cache and time.time() - cache[0] < 120:
            return cache[1]
        why = ""
        if self.deepseek_peak(datetime.datetime.now(datetime.timezone.utc), float(c.get("peak_margin_min", 30))):
            why = "DeepSeek peak hours (double price)"
        else:
            spent = self.credit_spent(since, float(c.get("base_usd", 0)))
            cap = float(c.get("cap_usd", 2.4))
            if spent is None:
                why = "opencode stats failed; credit spend unknown"
            elif spent >= cap:
                why = f"credit cap reached (${spent:.2f} of ${cap:.2f})"
            if spent is not None:
                self.state["credit_spent_usd"] = round(spent, 3)
        if why != (cache[1] if cache else None):
            log(f"DeepSeek on credits: {'paused: ' + why if why else 'allowed'}"
                + (f" (${self.state.get('credit_spent_usd', 0):.2f} spent)" if not why else ""))
        self._credit_cache = (time.time(), why)
        return why

    def next_fallback(self, where: str) -> str:
        """The fallback model `where` (a lane key, or anything else for main) would take next; for log lines."""
        key = where if where in self.LANE_KEYS else ""
        try:
            return self.fallback_model(key, self.task_size(key or "main"))
        except Exception:   # noqa: BLE001 - a log line only
            return self.fallback_model()

    def mark_deepseek_limited(self, where: str) -> None:
        if not self.deepseek_limited():
            nxt = self.next_fallback(where)
            log(f"DeepSeek usage limit hit ({where}); "
                + (f"{nxt} codes" if nxt else "ChatGPT Chat builds")
                + " instead for now")
        self.save(deepseek_limited_until=time.time() + float(self.cfg["opencode"].get("limit_cooldown_s", 3600)))

    # Owner 2026-10-11: free OpenCode models (opencode.fallback_models, Muse Spark and MiMo Flash) code for main and
    # the DeepSeek lanes while DeepSeek is limited, the lanes spread across them; ChatGPT Chat takes over only once
    # every one of them is limited too. Each model has its own limit time in state.fallback_limited.

    def fallback_models(self) -> list:
        lim = self.state.get("fallback_limited") or {}
        return [m for m in self.cfg.get("opencode", {}).get("fallback_models", [])
                if time.time() >= float(lim.get(m) or 0)]

    def fallback_model(self, key: str = "", size: str = "") -> str:
        ms = self.fallback_models()
        # Owner 2026-10-17: "use opencode go deepseek when the free models run out". Tiers in list order: the free
        # OpenCode models, then Go DeepSeek (only under the credit cap), then the web coders as the last resort.
        ds = [k for k in self.LANE_KEYS if self.cfg.get(k, {}).get("builder", "deepseek") == "deepseek"]
        # 2026-10-17: opencode.main_skip_models (Nemotron Lightning) wander for an hour or more on main builds
        # (cycles 370, 374, 377); the main cycle skips them and takes Go DeepSeek, the lanes may still use them.
        skip = set(self.cfg.get("opencode", {}).get("main_skip_models", [])) if key not in ds or size == "large" else set()
        free = [m for m in ms if not m.startswith("opencode-go/") and not is_paid_openrouter(m)
                and m not in WEB_MODELS and m not in skip]
        go = [m for m in ms if m.startswith("opencode-go/") and not self.credit_block(m)]
        web = [m for m in ms if m in WEB_MODELS]
        # Owner 2026-10-19: "dont use the paid api that much, only after everything else is limited" - the paid
        # OpenRouter models are the very last tier, and paced (paid_budget_ok); only checked when it comes to that.
        paid = [m for m in ms if is_paid_openrouter(m)]
        paid = paid if paid and not (free or go or web) and self.paid_budget_ok() else []
        # Owner 2026-10-20: "make the free models do easier things and let go deepseek do harder things and codex
        # even harder". Small (and unrated) tasks keep the free models first; medium and large ones take Go DeepSeek
        # first while it is under the credit cap (Codex already builds main first, main_builder). TASK_SCOPE size.
        # 2026-10-26: opencode.small_only_models (Inkling) have a small daily cap; a small task finishes inside it,
        # a medium one used 235 of its ~500 requests (2026-10-24).
        if size in ("medium", "large"):
            small_only = set(self.cfg.get("opencode", {}).get("small_only_models", []))
            free = [m for m in free if m not in small_only]
        ms = (go or free or web or paid) if size in ("medium", "large") else (free or go or web or paid)
        if not ms:
            return ""
        return ms[(ds.index(key) + 1) % len(ms)] if key in ds else ms[0]   # main takes the first, lanes the rest

    def own_model(self, key: str) -> str:
        """Owner 2026-10-14: a lane can code on its own OpenCode model (lane opencode_model, e.g. Gemini Argon on
        lane3) instead of DeepSeek. Like the free fallback models it has its own limit time in
        state.fallback_limited; while it is limited the lane codes as a DeepSeek lane."""
        lim = self.state.get("fallback_limited") or {}
        return next((m for m in self.own_models(key) if time.time() >= float(lim.get(m) or 0)), "")

    def own_models(self, key: str) -> list[str]:
        """The lane's own model, then its backup_models (owner 2026-10-22 "Antigravity also has seperate gemini
        usage": Gemini Flash keeps its own quota after Argon's is used up, so lane4 codes on Flash until Argon resets)."""
        c = self.cfg.get(key, {}) if key else {}
        return [m for m in [c.get("opencode_model", ""), *c.get("backup_models", [])] if m]

    def opencode_cfg(self, key: str = "", size: str = "") -> dict:
        o = self.cfg["opencode"]
        own = self.own_model(key) if size != "large" else ""   # a lane's own (free) model is for its smaller tasks
        m = own or (self.fallback_model(key, size) if self.deepseek_limited() else "")
        return {**o, "model": m} if m else o

    def task_size(self, key: str) -> str:
        """small/medium/large of the task the coder works on (TASK_SCOPE size, see throughput.size). Main is never
        below medium: it is the cycle's core build, where Go DeepSeek was accepted 33 times to Nemotron's 2."""
        try:
            if key in ("", "main"):
                sz = (self.state.get("main_scope") or self.task_scope("main", {})).get("size", "")
                return "large" if sz == "large" else "medium"
            task = self.state.get(f"{key}_task") or {}
            return self.task_scope(key, task).get("size", "") if task else ""
        except Exception:   # noqa: BLE001 - routing only; unknown keeps the default order
            return ""

    @staticmethod
    def _openrouter_get(path: str, key: str) -> dict:
        import urllib.request
        req = urllib.request.Request(f"https://openrouter.ai/api/v1/{path}", headers={"Authorization": f"Bearer ***
        with urllib.request.urlopen(req, timeout=10) as r:
            return json.loads(r.read().decode("utf-8")).get("data") or {}

    def paid_budget_ok(self) -> bool:
        """Owner 2026-10-19: "As many tokens per day until it expires on april 17 2027. You can choose the best cap",
        then "just use the main one". Paid OpenRouter models code only while the account's spend since base_usd stays
        under a straight line from 0 at `start` to budget_usd at `end` (unspent days roll forward), at most
        daily_max_usd a day, and while more than reserve_usd of credit is left (a negative balance blocks even the free
        models). Checked at most every 5 minutes; unknown means no."""
        c = self.cfg.get("opencode", {}).get("paid_openrouter") or {}
        key = os.environ.get(c.get("key_env", "OPENROUTER_API_KEY"), "")
        if not c.get("enabled") or not key:
            return False
        cache = getattr(self, "_paid_cache", None)
        if cache and time.time() - cache[0] < 300:
            return cache[1]
        ok, why = False, ""
        try:
            k, cr = self._openrouter_get("key", key), self._openrouter_get("credits", key)
            start = datetime.datetime.fromisoformat(c["start"]).timestamp()
            end = datetime.datetime.fromisoformat(c["end"]).timestamp()
            frac = min(1.0, max(0.0, (time.time() - start + 86400) / (end - start)))   # day one has its share
            allowed = float(c["budget_usd"]) * frac
            used = float(cr.get("total_usage") or 0)
            spent, today = used - float(c.get("base_usd", 0)), float(k.get("usage_daily") or 0)
            left = float(cr.get("total_credits") or 0) - used
            ok = (time.time() < end and spent < allowed and today < float(c.get("daily_max_usd", 2.0))
                  and left > float(c.get("reserve_usd", 0.25)))
            why = f"spent ${spent:.2f} of ${allowed:.2f} paced, ${today:.2f} today, ${left:.2f} credit left"
        except Exception as e:   # noqa: BLE001
            why = f"cannot check ({str(e)[:80]})"
        if cache is None or cache[1] != ok:
            log(f"OpenRouter paid tier {'on' if ok else 'off'}: {why}")
        self._paid_cache = (time.time(), ok)
        return ok

    @staticmethod
    def openrouter_free_left() -> int | None:
        """Free-model requests left today on the OpenRouter key (shared by every :free model); None if unknown."""
        key = os.environ.get("OPENROUTER_API_KEY", "")
        if not key:
            return None
        try:
            d = Relay._openrouter_get("key", key)
            return int((d.get("free_model_daily_requests") or {})["remaining"])
        except Exception:   # noqa: BLE001 - only decides how long the free models rest
            return None

    def mark_opencode_limited(self, where: str, model: str, output: str = "") -> None:
        own = {m for k in self.LANE_KEYS for m in self.own_models(k)}
        if model and (model in self.cfg["opencode"].get("fallback_models", []) or model in own):
            lim = dict(self.state.get("fallback_limited") or {})
            lim[model] = time.time() + float(self.cfg["opencode"].get("limit_cooldown_s", 3600))
            # 2026-10-24: 193 limit hits and 119 requeued lane tasks in a day and a half: big-pickle, longcat and
            # mimo were limited again within seconds of each hourly rest ending. A model limited again within
            # limit_repeat_window_s rests twice as long each time (1h, 2h, 4h, capped at limit_repeat_max_s).
            hits = {m: [t for t in ts if time.time() - t < float(self.cfg["opencode"].get("limit_repeat_window_s", 43200))]
                    for m, ts in dict(self.state.get("limit_hits") or {}).items()}
            # A stated reset (agy quota, a hung Chrome) is not a repeat, and neither is a second lane hitting the
            # same limit moments later (2026-10-24: lane2 and lane8 both hit Inkling at 15:34:03, which doubled its rest).
            fresh = time.time() - max(hits.get(model) or [0]) > float(self.cfg["opencode"].get("limit_repeat_gap_s", 600))
            # OpenRouter's free models keep their own rules below (a per-minute 429 rests 5 min, a spent day until
            # 00:05 UTC), so they are not counted: counting them only logged a doubled rest that never applied.
            own_rules = model.startswith("openrouter/") and model.endswith(":free")
            if not quota_reset_s(output) and fresh and not own_rules:
                hits[model] = hits.get(model, []) + [time.time()]
            hits = {m: ts for m, ts in hits.items() if ts}
            if len(hits.get(model, [])) > 1:
                rest_s = min(float(self.cfg["opencode"].get("limit_cooldown_s", 3600)) * 2 ** (len(hits[model]) - 1),
                             float(self.cfg["opencode"].get("limit_repeat_max_s", 28800)))
                lim[model] = time.time() + rest_s
                log(f"{model}: limited {len(hits[model])} times in 12 h; it rests {rest_s / 3600:.0f} h")
            self.save(limit_hits=hits)
            # 2026-10-22: Antigravity's plan quota says when it resets ("Resets in 157h21m43s"); rest until then
            # instead of failing and requeueing the lane task every hour for six days.
            rest = quota_reset_s(output)
            if rest:
                lim[model] = time.time() + rest
                log(f"{model}: quota resets {time.strftime('%b %d %H:%M', time.localtime(lim[model]))}; "
                    "it rests until then")
            # Owner 2026-10-19 ("use the best one if its combined usage"): OpenCode's free models have their own
            # limits (four answered while the rest were limited), but OpenRouter's :free models share one daily
            # request count per account. Once it is used up they all rest until it resets (00:00 UTC), instead of
            # each being tried and failing in turn.
            left = self.openrouter_free_left() if model.startswith("openrouter/") and model.endswith(":free") else None
            # Owner 2026-10-20 "only use the best model in openrouter since its shared usage": Inkling is the one
            # OpenRouter free model, so a per-minute 429 (daily requests still left) rests it briefly, not an hour.
            # 2026-10-25: Inkling answered 0 of 71 starts over two days (a 429 each time, daily requests still left),
            # and every 5-min rest cost a lane ~2 min and a requeue. Repeated 429s within limit_repeat_window_s now
            # double the rest (5 min, 10, 20 ... capped at limit_repeat_max_s); a second lane's hit moments later
            # is not a repeat.
            if left:
                base = float(self.cfg["opencode"].get("openrouter_minute_cooldown_s", 300))
                or_hits = dict(self.state.get("or_minute_hits") or {})
                gap = float(self.cfg["opencode"].get("limit_repeat_gap_s", 600))
                if own_rules and time.time() - max(or_hits.get(model) or [0]) > gap:
                    win = float(self.cfg["opencode"].get("limit_repeat_window_s", 43200))
                    ts = [t for t in or_hits.get(model, []) if time.time() - t < win] + [time.time()]
                    or_hits[model] = ts[-12:]
                    self.save(or_minute_hits=or_hits)
                n = len([t for t in (self.state.get("or_minute_hits") or {}).get(model, [])
                         if time.time() - t < float(self.cfg["opencode"].get("limit_repeat_window_s", 43200))])
                rest_s = min(base * 2 ** max(n - 1, 0), float(self.cfg["opencode"].get("limit_repeat_max_s", 28800)))
                lim[model] = time.time() + rest_s
                if n > 1:
                    log(f"{model}: rate-limited {n} times in 12 h; it rests {rest_s / 60:.0f} min")
            if left == 0:
                now = datetime.datetime.now(datetime.timezone.utc)
                reset = (now + datetime.timedelta(days=1)).replace(hour=0, minute=5, second=0, microsecond=0)
                for m in self.cfg["opencode"].get("fallback_models", []):
                    if m.startswith("openrouter/") and m.endswith(":free"):
                        lim[m] = reset.timestamp()
                log(f"OpenRouter's free daily requests are used up; its free models rest until "
                    f"{reset.astimezone().strftime('%b %d %H:%M')}")
            # 2026-10-26: Inkling's free variant has its own daily cap at Thinking Machines, about 500 requests (four
            # lane tasks on 2026-10-24), while the key's shared free count is still left. Its 5-160 min rests failed
            # every start until the cap reset at 00:00 UTC; it rests until 00:05 UTC instead.
            if MODEL_DAY_CAP_RE.search(output or ""):
                now = datetime.datetime.now(datetime.timezone.utc)
                reset = now.replace(hour=0, minute=5, second=0, microsecond=0)
                reset = reset if reset > now else reset + datetime.timedelta(days=1)
                lim[model] = reset.timestamp()
                log(f"{model}: its own daily cap is used up; it rests until {reset.astimezone().strftime('%b %d %H:%M')}")
            if is_paid_openrouter(model):
                self._paid_cache = None   # out of credit or paced out: re-check before the next pick
            self.save(fallback_limited=lim)
            # A lane's own model (Gemini Argon) hands over to DeepSeek unless DeepSeek is limited too; the log said
            # the free model took over while DeepSeek did (2026-10-15).
            fb = self.next_fallback(where)
            backup = self.own_model(where) if model in own and where in self.LANE_KEYS else ""
            nxt = (f"{backup} codes" if backup else
                   "DeepSeek codes" if model in own and not self.deepseek_limited() else
                   f"{fb} codes" if fb else "ChatGPT Chat builds")
            log(f"{model} usage limit hit ({where}); {nxt} instead for now")
        else:
            self.mark_deepseek_limited(where)

    def _first_brief(self, lt: dict) -> str:
        """The task's original brief (before any fix round), without its title line."""
        first = Path(lt["run_dir"]).parent / re.sub(r'-fix\d+$', '', Path(lt['run_dir']).name) / "BRIEF.md"
        text = read(first).split("\n\n## Lane rules\n")[0]   # the old worktree's rules are rewritten at restart
        return re.sub(r"^# .*\n+", "", text, count=1) if text.startswith("# ") else text

    # Owner 2026-10-11: accepted lane work that cannot merge (a clash in a shared catalog or main.gd, or the stacked
    # task it was built on was dropped) used to be lost: Gloam Ague and Hollow Reserves both vanished that way. Now
    # its own diff is saved and the task is requeued to re-apply that diff on the new main branch (at most twice).
    REDO_HEAD = "## Accepted earlier, redo on the new main"

    def _redo_brief(self, lt: dict, why: str, base: str = "") -> str:
        """Save the task's diff and return the requeue brief, or "" when it should not be redone again."""
        if not lt.get("run_dir"):
            return ""
        brief = self._first_brief(lt)
        n = len(re.findall(re.escape(self.REDO_HEAD), brief))
        brief = brief.split("\n\n" + self.REDO_HEAD)[0]
        base = base or self.git("merge-base", self.main, lt["branch"], check=False)
        diff = self.git("diff", f"{base}..{lt['branch']}", check=False) if base else ""
        if not brief.strip() or not diff.strip() or n >= 2:
            return ""
        patch = Path(lt["run_dir"]) / "ACCEPTED.patch"
        patch.parent.mkdir(parents=True, exist_ok=True)
        patch.write_bytes((diff + "\n").replace("\r\n", "\n").encode("utf-8"))   # LF: a CRLF patch never 3-way applies
        return (brief.rstrip() + f"\n\n{self.REDO_HEAD} ({n + 1})\nThis task was already implemented, reviewed and "
                f"ACCEPTED, but could not be merged: {why}. Its complete accepted implementation is the diff "
                f"{patch.as_posix()}. Re-apply that diff to the CURRENT code (other coders changed the same files "
                "since: where both added entries to one catalog, list or test, keep BOTH), then run the tests. Do not "
                "redesign it.\n")

    @staticmethod
    def _failed_tests(log_text: str) -> str:
        """2026-11-06: an accepted lane whose merge failed the full suite was dropped without a redo (lane3's Razor
        Ribbon Wraith broke the seed-pinned Moth witness, which its related-only lane run never ran). The redo now
        names the failing tests and their messages so the coder runs and fixes them."""
        blocks, cur = [], None
        for line in log_text.splitlines():
            if line.startswith("FAIL "):
                cur = [line[5:].split(" (")[0]]
                blocks.append(cur)
            elif cur is not None and line.startswith("    "):
                text = line.strip()
                if text and not text.startswith("Godot Engine") and len(cur) < 6:
                    cur.append(text[:200])
            else:
                cur = None
        if not blocks:
            return ""
        names = "; ".join(f"tests/{b[0]}" + (f" ({' | '.join(b[1:])})" if b[1:] else "") for b in blocks[:6])
        return (f". These tests failed with it: {names[:1500]}. Run each of them (godot --headless --path . -s "
                "tests/<name>.gd) and make them pass; a test pinned to a fixed seed whose route or draw changed with "
                "this code needs a new witness seed, not weaker checks")

    def _requeue_redo(self, key: str, lt: dict, redo: str) -> None:
        if redo:
            self._carry(key, lt["title"], redo, "redo of accepted work")
            log(f"{key}: \"{lt['title']}\" requeued to re-apply its accepted diff on the new main")

    def _codex_limited(self, lane, lt: dict) -> bool:
        return (type(lane).__name__ == "CodexLane" and str(lt.get("log", "")).endswith("codex.log")
                and bool(CODEX_LANE_LIMIT_RE.search(tail(read(Path(lt["log"])), 3000))))

    def _requeue_codex_limited(self, key: str, lt: dict, lane) -> None:
        """2026-11-06: a Codex lane task stopped by Codex's usage limit goes back to the queue, and Codex counts as
        paused until the time the message names, so lane2() restarts the task as a DeepSeek lane meanwhile."""
        at = limit_reset(tail(read(Path(lt["log"])), 3000))
        now = datetime.datetime.now()
        until = (at + datetime.timedelta(minutes=1) if at and at > now
                 else now + datetime.timedelta(hours=int(self.cfg.get("codex", {}).get("limit_pause_h", 6))))
        if until.strftime("%Y-%m-%d %H:%M:%S") > self.state.get("codex_main_paused_until", ""):
            self.save(codex_main_paused_until=until.strftime("%Y-%m-%d %H:%M:%S"))
        brief = self._first_brief(lt) if lt.get("run_dir") else ""
        for step in (lane.stop, lane.cleanup):
            try:
                step(lt)
            except Exception:   # noqa: BLE001
                pass
        with self._save_lock:
            cur = self.state.get(f"{key}_task")
            if cur and cur.get("branch") == lt.get("branch"):
                self.save(**{f"{key}_task": None})
        if brief.strip():
            self._carry(key, lt["title"], brief, "Codex usage limit")
        log(f"{key}: Codex usage limit until {until:%b %d %H:%M}; \"{lt['title']}\" "
            + ("requeued" if brief.strip() else "dropped (no brief)"))
        self.write_live_board()

    def _requeue_limited_lane(self, key: str, lt: dict, lane) -> None:
        """A DeepSeek lane task that hit the usage limit (it fails at once, before any work) goes back to the queue;
        the idle refill restarts it on the fallback model or as a ChatGPT Chat lane."""
        # The model the task ran on (lt["model"], saved at start), not the lane's current one: lane2() builds the lane
        # from today's routing, so 2026-10-17 00:00 paused deepseek-web and gemini-web for GLM's and DeepSeek's limits.
        self.mark_opencode_limited(key, lt.get("model") or (getattr(lane, "oc", None) or {}).get("model", ""),
                                   tail(read(Path(lt["log"])), 3000) if lt.get("log") else "")
        try:
            lane.stop(lt)
        except Exception:   # noqa: BLE001
            pass
        # 2026-10-19: the count was per task, so lane3's four model hops in fix round 1 left fix round 2 none and its
        # reviewed "Tear defeated paper enemies" work was dropped. It is now per fix round, and the last hop is
        # ChatGPT Chat (no usage limit) instead of dropping the task.
        hops = int(lt.get("limit_resumes", 0)) if lt.get("limit_round") == lt.get("fix_rounds") else 0
        # 2026-10-19: a first run that hit the limit after it had already edited the worktree was cleaned and requeued
        # (lane3's "Tear defeated paper enemies", 75 min of DeepSeek work lost at 11:43); it continues in place too.
        if ((lt.get("fix_rounds") or self._lane_has_work(lane, lt)) and hops < self.LIMIT_HOPS
                and self._resume_limited_fix(key, lt, hops)):
            return
        brief = self._first_brief(lt)
        try:
            lane.cleanup(lt)
        except Exception:   # noqa: BLE001
            pass
        with self._save_lock:
            cur = self.state.get(f"{key}_task")
            if cur and cur.get("branch") == lt.get("branch"):
                self.save(**{f"{key}_task": None})
        if brief.strip() and not lt.get("fix_rounds"):
            self._carry(key, lt["title"], brief, "usage limit")
            log(f"{key}: usage limit; \"{lt['title']}\" requeued")
        else:
            log(f"{key}: DeepSeek usage limit during a fix round; dropped \"{lt['title']}\" (the lane is replanned)")
        self.write_live_board()

    LIMIT_HOPS = 12   # usage-limit continuations per fix round; the last one is ChatGPT Chat (2026-10-19: was 6,
    # for 5 fallback models; now ~16)

    @staticmethod
    def _lane_has_work(lane, lt: dict) -> bool:
        try:
            return bool(lt.get("dir")) and Path(lt["dir"]).exists() and bool(lane.changed(lt))
        except Exception:   # noqa: BLE001 - unknown means "no": the old requeue path
            return False

    LIMIT_CONTINUE = ("(Continued after a usage limit: the worktree already holds the earlier partial work on this "
                      "task. Run git status and git diff first and finish it; do not start over.)")

    def _resume_limited_fix(self, key: str, lt: dict, hops: int = 0) -> bool:
        """A fix round that hit a usage limit continues in the same worktree on the next free model, or as ChatGPT
        Chat when every free model is limited. It used to drop the reviewed task (Brittle and the title-screen Ink
        rules, 2026-10-12)."""
        rd = Path(lt["run_dir"])
        text = read(rd / "BRIEF.md").split("\n\n## Lane rules\n")[0]
        if not text.strip() or not lt.get("dir") or not Path(lt["dir"]).exists():
            return False
        n = int(lt.get("fix_rounds") or 0)
        if not n and self.LIMIT_CONTINUE not in text:
            text = f"{self.LIMIT_CONTINUE}\n\n{text}"
        # A fresh run dir: a ChatGPT lane treats an old REPORT.md there as already finished. A first run's own dir
        # stays (resume writes to <run>-fix0, and _first_brief reads the original BRIEF.md from it).
        if re.search(r"-fix\d+$", rd.name):
            try:
                rd.rename(rd.with_name(f"{rd.name}-limited{time.time_ns()}"))   # two hops can share a second
            except OSError:
                return False
        to = None if self.fallback_model(key) and hops < self.LIMIT_HOPS - 1 else "chatgpt"
        lt = self._lane_update(key, lt["branch"], give_up=None, repair_builder=to or lt.get("repair_builder"),
                               limit_resumes=hops + 1, limit_round=lt.get("fix_rounds")) or lt
        try:
            info = self.lane2(key).resume(lt, text, n)
        except Exception as e:   # noqa: BLE001
            log(f"{key}: could not resume the limited fix round ({type(e).__name__}: {str(e)[:120]})")
            return False
        self._lane_update(key, lt["branch"], **{**info, "finished": False, "tests_ok": False, "review": None,
                                                "reviewing": False})
        log(f"{key}: usage limit during {f'fix round {n}' if n else 'its first run (keeping its partial work)'}; "
            f"{'ChatGPT Chat' if to else self.opencode_cfg(key, self.task_size(key)).get('model', 'the fallback model')} continues it")
        return True

    def lane2(self, key: str = "lane2", size: str = ""):
        c = self.cfg.get(key, {})
        task = self.state.get(f'{key}_task') or {}
        # 2026-11-06: a NEW task on a Codex lane while Codex is at its usage limit runs as a DeepSeek lane (cycle 562:
        # lane3 started on Codex past its limit, made no changes and its task was dropped)
        codex_out = not task and c.get("builder") == "codex" and self.state.get("codex_main_paused_until", "") > ts()
        if (not task and (c.get("builder", "deepseek") == "deepseek" or codex_out) and self.deepseek_limited()
                and not self.fallback_model() and not self.own_model(key)
                and self.cfg.get("opencode", {}).get("limit_fallback", "chatgpt") == "chatgpt"):
            from lane_local import ChatLane   # a NEW task on a DeepSeek lane while DeepSeek is limited
            return ChatLane(self.repo, self.main, self.cfg['chatgpt'], {**c, 'mode': 'chat', 'effort': 'high'}, log, key)
        if task.get('repair_builder') == 'codex':   # owner 2026-10-10: Codex is the fallback coder
            from lane_local import CodexLane
            lane = CodexLane(self.repo, self.main, self.cfg.get("codex_cli", {}), c, log, key)
            lane.root = Path(task['dir'])  # repair in the original worktree; keep its branch and partial work
            return lane
        if task.get('repair_builder') == 'chatgpt':
            from lane_local import ChatLane
            lane = ChatLane(self.repo, self.main, self.cfg['chatgpt'],
                            {**c, 'mode': 'chat', 'effort': 'high'}, log, key)
            lane.root = Path(task['dir'])  # repair in the original worktree; keep its branch and partial work
            return lane
        # A task started by DeepSeek finishes as DeepSeek even after its lane switched builder (owner 2026-10-08).
        task_log = str((self.state.get(f"{key}_task") or {}).get("log", ""))
        started_by_deepseek = task_log.endswith("opencode.log")
        started_by_chatgpt = task_log.endswith("REPLY.md")   # and a ChatGPT task finishes as ChatGPT
        started_by_codex = task_log.endswith("codex.log")
        if (c.get("builder") == "codex" and not codex_out and not (started_by_deepseek or started_by_chatgpt)
                or started_by_codex):
            from lane_local import CodexLane   # local Codex CLI with direct terminal access (owner 2026-10-10)
            return CodexLane(self.repo, self.main, self.cfg.get("codex_cli", {}), c, log, key)
        if (c.get("builder") == "chatgpt" and not started_by_deepseek) or started_by_chatgpt:
            from lane_local import ChatLane
            return ChatLane(self.repo, self.main, self.cfg["chatgpt"], c, log, key)
        from lane_local import LocalLane
        return LocalLane(self.repo, self.main, self.opencode_cfg(key, size or self.task_size(key)), c, log)

    def _lane_builder(self, key: str) -> str:
        """Who built the lane's current task, for the merge message."""
        lt = self.state.get(f"{key}_task") or {}
        if lt.get('repair_builder') == 'codex':
            return 'Codex repair'
        if lt.get('repair_builder') == 'chatgpt':
            return 'ChatGPT repair'
        if str(lt.get("log", "")).endswith("opencode.log"):
            from lane_local import builder_label
            c = self.cfg.get(key, {})
            return builder_label(c, lt["model"]) if "model" in lt else c.get("builder_name", "DeepSeek")
        if str(lt.get("log", "")).endswith("codex.log"):
            return "Codex"
        mode = self.cfg.get(key, {}).get("mode", "chat")
        return f"ChatGPT {mode.capitalize()} mode"

    def dedupe_running_lanes(self) -> None:
        """Owner 2026-10-10: cancel a lane that is still coding a feature the main cycle or an older lane is already
        building (three coders built Ragwheel's sprint at once). Finished/reviewed work is left alone."""
        active = self.active_scopes('')
        lanes = sorted((lt.get('first_started_ts') or lt.get('started_ts') or 0, k, lt)
                       for k in self.LANE_KEYS if (lt := self.state.get(f"{k}_task")) and k in active)
        for i, (_, k, lt) in enumerate(lanes):
            if lt.get('finished') or lt.get('reviewing') or lt.get('review') or lt.get('fix_rounds'):
                continue
            older = {'main': active['main']} if 'main' in active else {}
            older.update({a: sc for a, sc in active.items() if '-accepted' in a and not a.startswith(f'{k}-')})
            older.update({k2: active[k2] for _, k2, _ in lanes[:i]})
            dup = next((o for o, sc in older.items() if TP.similar_feature(active[k], sc)), None)
            if dup:
                what = older[dup].get('title') or older[dup].get('feature', '')
                log(f"{k}: \"{lt.get('title', '')}\" duplicates {dup} ({what}); cancelling it")
                try:
                    self.lane2(k).stop(lt)
                except Exception:   # noqa: BLE001
                    pass
                self.lane_give_up(k, lt, f"duplicate of {dup}: {what}")

    def close_stale_tabs(self, startup: bool = False) -> None:
        """Owner 2026-10-10: close leftover ChatGPT tabs (15 had piled up from asks cut off by halts/restarts).
        Owner 2026-11-04: also blank tabs, in the account Chromes (web_accounts cdp_urls, 9223/9224) as well."""
        try:
            from chatgpt_bridge import close_stale_tabs
            urls = [self.cfg["chatgpt"].get("cdp_url", "http://127.0.0.1:9222")]
            for accs in (self.cfg.get("web_accounts") or {}).values():
                for acc in accs if isinstance(accs, list) else []:
                    u = acc.get("cdp_url") if isinstance(acc, dict) else None
                    if u and u.rstrip("/") not in [x.rstrip("/") for x in urls]:
                        urls.append(u)
            n = sum(close_stale_tabs(u, startup=startup) for u in urls)
            if n:
                log(f"tabs: closed {n} leftover ChatGPT/blank tab(s)")
            if not startup:
                from chatgpt_bridge import refresh_idle_chrome
                refresh_idle_chrome(self.cfg["chatgpt"], log)
        except Exception as e:   # noqa: BLE001 - housekeeping only
            log(f"tabs: cleanup failed ({type(e).__name__}: {str(e)[:120]})")

    def open_account_chromes(self, quiet: bool = False) -> None:
        """Owner 2026-10-29: open the web coders' extra account Chromes (relay.json web_accounts entries with a
        user_data_dir, e.g. 9223/9224) when the relay starts, so they are back after a PC restart without waiting
        for a coder to need them. The relay's own Chrome (9222) is started as before.
        Owner 2026-11-02: after the 01:38 restart both were logged open but were gone by morning (9224 within
        seconds), so the lane checker also re-opens any that closed (quiet: logs only a re-open or a failure)."""
        try:
            import deepseek_web_coder as DW
            seen, started, failed = set(), [], []
            for accs in (self.cfg.get("web_accounts") or {}).values():
                for acc in accs if isinstance(accs, list) else []:
                    if isinstance(acc, dict) and acc.get("user_data_dir") and acc.get("cdp_url") not in seen:
                        seen.add(acc.get("cdp_url"))
                        res = DW.ensure_chrome(acc, self.cfg)
                        if res == "failed":
                            failed.append(acc["cdp_url"])
                        elif res == "started":
                            started.append(acc["cdp_url"])
            if failed:
                log(f"chrome: account window(s) did not open ({', '.join(sorted(failed))})")
            if quiet:
                if started:
                    log(f"chrome: re-opened closed account window(s) ({', '.join(sorted(started))})")
            elif seen - set(failed):
                log(f"chrome: account windows open ({', '.join(sorted(seen - set(failed)))})")
        except Exception as e:   # noqa: BLE001 - housekeeping only
            log(f"chrome: could not open the account windows ({type(e).__name__}: {str(e)[:120]})")

    # ---- live work board (owner 2026-10-10): every coder and planner sees the others working, so nobody overlaps

    def _changing(self, root) -> list[str]:
        out = subprocess.run(["git", "-c", "safe.directory=*", "-C", str(root), "status", "--porcelain", "-uall"],
                             capture_output=True, text=True, encoding="utf-8", errors="replace")
        files = []
        for line in out.stdout.splitlines():
            p = line[3:].split(" -> ")[-1].strip().strip('"')
            if p and not p.endswith((".import", ".uid")) and not p.startswith((".godot/", ".lanes/", ".review/")):
                files.append(p)
        return files

    def note_claims(self, source: str, tasks: dict) -> None:
        """Tasks a planner has just chosen show on the board at once, before they are dispatched."""
        claims = getattr(self, "_fresh_claims", None)
        if claims is None:
            claims = self._fresh_claims = {}
        for key, (title, brief) in tasks.items():
            try:
                scope = TP.scope(brief, title)
            except ValueError:
                scope = {}
            claims[key] = {"title": title, "by": source, "files": scope.get("files", []),
                           "reads": scope.get("depends_on", []), "at": time.time()}
        self.write_live_board()

    def write_live_board(self) -> None:
        try:
            lines = [f"# Live work board (updated {ts()}; refreshed about every 20 s)",
                     "Every coder is listed with its task, the files it RESERVED and the files it is CHANGING now.",
                     "Do not plan or edit anything that overlaps another entry.",
                     "Only a RUNNING coder's reserved and changing files are locked: 'reads' lists are dependencies, "
                     "and queued or claimed tasks have not started (they are re-checked at launch).",
                     f"SHARED files (any coder may edit them even when listed below; keep each edit a few small hook "
                     f"lines): {', '.join(sorted(TP.SHARED)) or '-'}", ""]
            st = self.state
            if st.get("phase") not in (None, "IDLE"):
                scope = st.get("main_scope") or {}
                lines += [f"## main cycle {st.get('cycle', 0):03d} ({st.get('phase')}): {st.get('title', '')}",
                          f"- coder: {('Codex' if (self.cfg.get('chatgpt_fixer') or {}).get('builder') == 'codex' else 'ChatGPT Chat') if st.get('phase') in ('CHATFIX', 'RESCUE') else st.get('main_coder') or 'DeepSeek'}",
                          f"- reserved: {', '.join(scope.get('files', [])) or '(planning)'}",
                          f"- reads: {', '.join(scope.get('depends_on', [])) or '-'}",
                          f"- changing now: {', '.join(self._changing(self.repo)[:40]) or '-'}", ""]
            for k in self.LANE_KEYS:
                lt = st.get(f"{k}_task")
                if not lt:
                    continue
                scope = self.task_scope(k, lt)
                status = ("ACCEPTED, merges at the next cycle start" if (lt.get("review") or {}).get("verdict") == "ACCEPTED"
                          else "reviewing" if lt.get("reviewing") else "waiting for review" if lt.get("finished")
                          else f"fix round {lt['fix_rounds']}" if lt.get("fix_rounds") else "coding")
                changing = self._changing(lt["dir"]) if lt.get("dir") and Path(lt["dir"]).exists() else []
                lines += [f"## {k} ({self._lane_builder(k)}, {status}): {lt.get('title', '')}",
                          f"- reserved: {', '.join(scope.get('files', [])) or '-'}",
                          f"- reads: {', '.join(scope.get('depends_on', [])) or '-'}",
                          f"- changing now: {', '.join(changing[:40]) or '-'}", ""]
            for k in self.LANE_KEYS:
                for p in self.parked(k):
                    files = self.git("diff", "--name-only", f"{self.main}...{p['branch']}", check=False).splitlines()
                    lines += [f"## {k} ({self._lane_builder(k)}, ACCEPTED, merges at the next cycle start): "
                              f"{p.get('title', '')}",
                              f"- changed: {', '.join(files[:40]) or '-'}", ""]
            queued = load_json(HERE / "prepared" / "lane_queue.json", {})
            claims = {k: c for k, c in (getattr(self, "_fresh_claims", None) or {}).items()
                      if time.time() - c["at"] < 3600 and not st.get(f"{k}_task")}
            for k, q in queued.items():
                sc = q.get("scope", {}) if isinstance(q, dict) else {}
                claims.setdefault(k, {"title": q.get("title", "") if isinstance(q, dict) else "", "by": "queue",
                                      "files": sc.get("files", []), "reads": sc.get("depends_on", [])})
            nm = self.next_main_scope()
            if nm:
                lines += [f"## NEXT main cycle (already planned; lanes must not touch it): {nm.get('feature', '')}",
                          f"- reserved: {', '.join(nm.get('files', []))}",
                          f"- reads: {', '.join(nm.get('depends_on', [])) or '-'}", ""]
            if claims:
                lines.append("## Claimed by planners (about to start)")
                lines += [f"- {k} ({c['by']}): {c['title']} | reserved: {', '.join(c['files']) or '-'}"
                          f" | reads: {', '.join(c['reads']) or '-'}" for k, c in claims.items()]
            path = HERE / "LIVE_WORK.md"
            # 2026-10-18: two threads shared LIVE_WORK.tmp (WinError 32/5); a per-thread name and a short retry.
            tmp = path.with_name(f"LIVE_WORK.{threading.get_ident()}.tmp")
            tmp.write_text("\n".join(lines) + "\n", encoding="utf-8")
            for n in range(5):
                try:
                    os.replace(tmp, path)
                    break
                except PermissionError:
                    if n == 4:
                        tmp.unlink(missing_ok=True)
                        raise
                    time.sleep(0.2)
        except Exception as e:   # noqa: BLE001 - the board is advisory; never stop the relay
            log(f"live board: {type(e).__name__}: {str(e)[:160]}")

    def busy_elsewhere(self, skip: str) -> str:
        """What the other parallel builders are doing right now (so a new task avoids it)."""
        parts = []
        # Owner 2026-10-10: list main's reserved paths too (cycle 112's lane2 task collided with main's battle_session.gd).
        try:
            main_files = (self.active_scopes(skip).get('main') or {}).get('files', []) if skip != 'main' else []
        except Exception:   # noqa: BLE001 - context only
            main_files = []
        if main_files:
            parts.append(f"the main cycle is working on: {self.state.get('title', '')}; reserved paths: "
                         + ", ".join(main_files))
        nm = self.next_main_scope() if skip != 'main' else {}
        if nm:
            parts.append(f"the NEXT main cycle is already planned ({nm.get('feature', '')}); reserved paths: "
                         + ", ".join(nm.get('files', [])))
        ct = self.state.get("codex_task")
        if ct and skip != "codex":
            parts.append(f"the Codex lane is working on: {ct['title']}")
        for k in self.LANE_KEYS:
            t = self.state.get(f"{k}_task")
            if t and k != skip and t.get("branch") not in self.merge_check_branches():
                paths = self.task_scope(k, t).get('files', [])
                parts.append(f"{k} ({self.cfg.get(k, {}).get('label', 'a parallel lane')}) is working on: {t['title']}"
                             + (f"; reserved paths: {', '.join(paths)}" if paths else ''))
            if k != skip:
                for p in self.parked(k):
                    parts.append(f"{k} has ACCEPTED work merging at the next cycle start: {p.get('title', '')}")
        # 2026-10-19: the Ink-price test speed-up waited in the carry queue twice while a planner gave it to lane6 a
        # third time; queued carries are planned work too.
        try:
            carried = [c["title"] for c in load_json(HERE / 'prepared' / 'carry_queue.json', []) if c.get("title")]
        except Exception:   # noqa: BLE001 - context only
            carried = []
        if carried:
            parts.append("queued to continue on the next free lane (already planned; do not plan these again): "
                         + "; ".join(carried[:8]))
        return "; ".join(parts) or "nothing else"

    def maybe_launch_lanes(self) -> None:
        for k in self.LANE_KEYS:
            try:
                self.maybe_launch_lane(k)
            except Exception as e:   # noqa: BLE001 - one lane must not stop the others
                log(f"{k}: launch error {type(e).__name__}: {str(e)[:200]}")

    def maybe_launch_lane(self, key: str) -> None:
        c = self.cfg.get(key, {})
        if not c.get("enabled") or self.state.get(f"{key}_task"):
            return
        done = (self.state.get("codex_history") or [])
        for k in self.LANE_KEYS:
            done = done + (self.state.get(f"{k}_history") or [])
        try:
            out = self.think(P.CODEX_PLAN.substitute(
                agent=c.get("label", "a DeepSeek coding agent") + " on this PC (one of several parallel lanes)"
                      + (f"; {c['plan_hint']}" if c.get("plan_hint") else ""),
                avoid=self.busy_elsewhere(key) + P.live_board_note(),
                repo=self.repo, main_plan=self.cyc / "CLAUDE_PLAN.md", docs=HERE.parent / "full_game",
                recent="\n".join(f"- {h['title']}" for h in done[-12:]) or "- none",
                failed="\n".join(f"- {f['title']}: {f['reason'][:160]}"
                                  for f in self.planning_blockers(key)[-5:]) or "- none"),
                f"{key.upper()}PLAN")
        except (AgentFailed, UsageLimited) as e:
            log(f"{key}: no plan ({e})")
            return
        m = re.search(r"^TITLE:\s*(.+)$", out, re.M)
        title = m.group(1).strip() if m else ""
        task = extract(out, "CODEX_TASK")
        if not title or title.upper() == "NONE" or not task:
            log(f"{key}: planner found no suitable parallel task")
            return
        from lane_local import LaneError
        task_id = f"{self.state['cycle']:03d}-{key}-{int(time.time())}"
        brief = f"# {title}\n\n{task.strip()}" + (P.VISUAL_SHOTS if self._visual_check_on(key) else "")
        try:
            sz = TP.scope(task, title).get("size", "")
        except ValueError:
            sz = ""
        try:
            info = self.lane2(key, sz).start(task_id, brief)
        except (LaneError, OSError) as e:
            log(f"{key}: could not start ({e})")
            return
        info.update(title=title, started=ts())
        self.save(**{f"{key}_task": info})
        log(f"{key}: started \"{title}\"")

    # ---- background lane checker: bounded batching independent of the main cycle's phase

    def _lane_update(self, key: str, current_branch: str, **changes) -> dict | None:
        # current_branch identifies the task; "branch" may appear in changes (a fix round's resume() returns it),
        # which used to crash with "got multiple values for argument 'branch'" (2026-10-07)
        with self._save_lock:
            lt = self.state.get(f"{key}_task")
            if not lt or lt.get("branch") != current_branch:
                return None
            lt = {**lt, **changes}
            self.save(**{f"{key}_task": lt})
            return lt

    def start_lane_checker(self) -> None:
        if not self.cfg.get("lane_review", {}).get("enabled", True):
            return
        t = getattr(self, "_checker", None)
        cycle = self.state["cycle"]
        if t and t.is_alive() and t.name == f"lane-checker-{cycle:03d}":
            return

        def run() -> None:
            self._tls.bg = True
            reviewed = 0
            while not STOP_PATH.exists() and self.state.get("cycle") == cycle:
                try:
                    # One checker pass at a time: at a cycle boundary the new cycle's checker started while the old
                    # one was still inside lane.finish (a 2.5-min suite run), so both finished lane3 and the second
                    # saw "nothing to commit" as a failure (2026-10-11).
                    with self.__dict__.setdefault("_check_lock", threading.Lock()):
                        if self.state.get("cycle") != cycle:
                            break
                        reviewed = self._lane_check_once(reviewed)
                    if time.time() - getattr(self, "_board_at", 0) >= 20:
                        self._board_at = time.time()
                        self.write_live_board()
                    if time.time() - getattr(self, "_dedupe_at", 0) >= 60:
                        self._dedupe_at = time.time()
                        self.dedupe_running_lanes()
                        self.refill_idle_lanes()
                    if time.time() - getattr(self, "_tabs_at", 0) >= 300:
                        self._tabs_at = time.time()
                        self.close_stale_tabs()
                        self.open_account_chromes(quiet=True)
                except Exception as e:   # noqa: BLE001 - never stop the main cycle
                    log(f"lane checker: {type(e).__name__}: {str(e)[:200]}")
                if self.state.get("phase") == "IDLE" and not getattr(self, '_plan_wait', False):
                    break
                time.sleep(max(1, int(self.cfg.get('lane_review', {}).get('poll_s', 10))))
            try:
                self._tls.bridge and self._tls.bridge.disconnect()
            except Exception:   # noqa: BLE001
                pass

        self._checker = threading.Thread(target=run, name=f"lane-checker-{cycle:03d}", daemon=True)
        self._checker.start()

    def _lane_check_once(self, reviewed: int) -> int:
        rc = self.cfg.get("lane_review", {})
        for k in self.LANE_KEYS:
            if ((self.state.get(f"{k}_task") or {}).get("review") or {}).get("verdict") == "ACCEPTED":
                try:
                    self.early_start_lane(k)
                except Exception as e:   # noqa: BLE001 - the lane simply waits for the cycle start as before
                    log(f"{k}: early start failed ({type(e).__name__}: {str(e)[:160]})")
        running = []
        for k in self.LANE_KEYS:
            lt = self.state.get(f"{k}_task")
            if lt and lt.get("give_up") and rc.get("give_up_now", True):
                # Owner 2026-10-11: a given-up task only needs its worktree cleaned (master is untouched), so free
                # the lane now for the idle refill instead of at the next cycle start (cycle 158: three DeepSeek
                # lanes hit the usage limit at once and sat "coding" for the rest of the cycle).
                lane = self.lane2(k)
                if self._codex_limited(lane, lt):
                    self._requeue_codex_limited(k, lt, lane)
                elif (type(lane).__name__ == "LocalLane" and lt.get("log")
                        and DS_LIMIT_RE.search(tail(read(Path(lt["log"])), 3000))):
                    self._requeue_limited_lane(k, lt, lane)
                else:
                    self.lane_give_up(k, lt, lt["give_up"])
                continue
            if not lt or lt.get("finished") or lt.get("give_up"):
                continue
            if lt.get("visual_checking"):
                vt = self._vc_threads.get(k)
                if vt is not None and vt.is_alive():
                    continue
                if vt is None:   # the relay restarted mid-check: merge on the normal review instead
                    log(f"{k}: visual check was interrupted by a restart; continuing without it")
                    self._lane_update(k, lt["branch"], visual_checking=False, finished=True, visual="interrupted")
                continue
            ft = self.__dict__.setdefault("_fin_threads", {}).get(k)
            if ft is not None and ft.is_alive():
                running.append(k)   # its suite runs in its own thread
                continue
            if time.time() < self.__dict__.setdefault("_fin_retry_at", {}).get(k, 0):
                continue
            lane = self.lane2(k)
            # 2026-10-19: lane3's coder was stopped at its timeout (11:30) and its finish thread (commit + suite) was
            # killed by the 11:39 install restart; the checker then took it as "cut off before it reported", reran
            # the coder, which hit the usage limit and the requeue cleaned the worktree. A run whose finish already
            # started is finished again (commit + suite), never rerun or requeued.
            finishing = bool(lt.get("run_dir")) and lt.get("finishing") == lt.get("run_dir")
            if not finishing and self._codex_limited(lane, lt):
                self._requeue_codex_limited(k, lt, lane)
                continue
            if (not finishing and type(lane).__name__ == "LocalLane" and lt.get("log")
                    and DS_LIMIT_RE.search(tail(read(Path(lt["log"])), 3000))):
                self._requeue_limited_lane(k, lt, lane)
                continue
            since = self.__dict__.get("_started_at", 0)
            if (since and not finishing and not lt.get("killed_restarted")
                    and lane.killed_by_restart(lt, since)):
                self._restart_killed_lane(k, lt, lane)
                running.append(k)
                continue
            if type(lane).__name__ == "ChatLane" and not lt.get("orphan_restarted") and lane.orphaned(lt):
                first = lane.runs / re.sub(r'-fix\d+$', '', Path(lt['run_dir']).name) / 'BRIEF.md'
                log(f"{k}: its ChatGPT conversation was cut off by a restart (no changes after 20 min); resending it")
                info = lane.resume(lt, read(first), int(lt.get('fix_rounds', 0)) + 1)
                self._lane_update(k, lt['branch'], **info, orphan_restarted=True)
                running.append(k)
                continue
            if lane.running(lt["pid"]):
                if not self._lane_timeout(k, lt, lane):
                    running.append(k)
                continue
            try:
                decision = coder_deferred_reason(read(Path(lt['run_dir']) / 'REPORT.md'))
            except ValueError as e:
                self._lane_fix(k, lt, [f'Correct the invalid CODER_STATUS report: {e}'], '')
                continue
            if decision and suite_only_deferral(decision):
                log(f"{k}: \"{lt['title']}\" was deferred only because its own full-suite run could not finish; "
                    "the lane checker runs the suite itself")
                decision = None
            if decision:
                self.defer_lane(k, lt, decision)
                continue
            evidence = TP.acceptance_error(read(Path(lt['run_dir']) / 'REPORT.md'),
                                           read(Path(lt['run_dir']) / 'BRIEF.md'))
            if evidence:
                warning = f'{evidence}. Independent review must verify every original criterion directly.'
                write(Path(lt['run_dir']) / 'REPORT_EVIDENCE_WARNING.md', warning + '\n')
                self._lane_update(k, lt['branch'], evidence_warning=warning)
                log(f'{k}: coder report warning: {warning}; continuing to tests/review')
            log(f"{k}: \"{lt['title']}\" finished; committing and testing it in its worktree")
            lt = self._lane_update(k, lt["branch"], finishing=lt.get("run_dir")) or lt
            if self.cfg.get("lane_review", {}).get("parallel_finish", True):
                # Owner 2026-10-16: lane.finish (commit + full suite, 18-45 min under load) ran inside the checker,
                # so nothing else was noticed meanwhile: lane4's free GLM run hit a rate limit at 23:34 and the lane
                # sat idle behind lane2's suite. Each lane's suite now runs in its own thread; the machine-wide test
                # slots in run_tests.py still cap how many suites run at once.
                t = threading.Thread(target=self._finish_lane_bg, args=(k, lt, lane, rc), daemon=True,
                                     name=f"lane-finish-{k}")
                self.__dict__.setdefault("_fin_threads", {})[k] = t
                t.start()
                running.append(k)
                continue
            self._finish_lane(k, lt, lane, rc)
        ready = [k for k in self.LANE_KEYS if (self.state.get(f"{k}_task") or {}).get("finished")
                 and not (self.state.get(f"{k}_task") or {}).get("review")
                 and not (self.state.get(f"{k}_task") or {}).get("reviewing")
                 and not (self.state.get(f"{k}_task") or {}).get("give_up")]
        now = time.time()
        for k in ready:
            lt = self.state[f'{k}_task']
            if not lt.get('ready_at'):
                self._lane_update(k, lt['branch'], ready_at=now)
        eligible = [k for k in ready if now >= (self.state[f'{k}_task'].get('review_retry_at') or 0)]
        wait = float(rc.get('batch_window_s', 45))
        if eligible and (not running or any(now - self.state[f'{k}_task']['ready_at'] >= wait for k in eligible)):
            self.review_lanes(eligible)
            return reviewed + 1
        return reviewed

    def _restart_killed_lane(self, k: str, lt: dict, lane) -> None:
        """Owner 2026-10-17 ("my pc was off"): the PC went off at 04:21 with lane3/lane4 mid fix round 1 (Nemotron)
        and lane7 mid ChatGPT task. At 11:40 all three were taken as finished with no report: 37-min suites, then
        fix round 2 (their last) for lanes 3/4. A coder that stopped before this controller started and left no
        report is rerun once in the same round, with the same brief, on the lane's current model."""
        n = int(lt.get("fix_rounds", 0))
        brief = read(Path(lt["run_dir"]) / "BRIEF.md").split("\n\n## Lane rules\n")[0].split("\n\n## Lessons\n")[0]
        if not brief.strip():
            brief = self._first_brief(lt)
        old_log = Path(lt.get("log") or "")
        if old_log.name and old_log.exists():
            old_log.replace(old_log.with_name(old_log.stem + ".cut-off" + old_log.suffix))
        log(f"{k}: its coder was cut off by a relay restart before it reported; restarting \"{lt['title']}\" "
            f"(round {n}) on {getattr(lane, 'oc', {}).get('model') or type(lane).__name__}")
        info = lane.resume(lt, brief, n)
        self._lane_update(k, lt["branch"], **info, killed_restarted=True)
        self.write_live_board()

    def _finish_lane_bg(self, k: str, lt: dict, lane, rc: dict) -> None:
        self._tls.bg = True
        try:
            self._finish_lane(k, lt, lane, rc)
        except Exception as e:   # noqa: BLE001 - the checker retries the lane later, as it did inline
            log(f"{k}: lane finish error {type(e).__name__}: {str(e)[:200]}; retrying in 2 min")
            self.__dict__.setdefault("_fin_retry_at", {})[k] = time.time() + 120
        finally:
            try:
                self._tls.bridge and self._tls.bridge.disconnect()
            except Exception:   # noqa: BLE001
                pass

    ERROR_REQUEUE = "(Requeued once: the first coder run failed before it changed anything.)"

    def _requeue_errored_lane(self, k: str, lt: dict, lane) -> bool:
        """Owner 2026-10-17: lane7's ChatGPT run failed opening chatgpt.com (Page.goto timeout) before it changed
        anything, and the planned task was dropped as "the lane made no changes". A coder that crashed (ERROR.txt)
        on a fresh task now goes back to the queue once instead."""
        err = Path(lt.get("run_dir") or "") / "ERROR.txt"
        # 2026-10-25: DeepSeek (OpenCode Go) stopped lane3's and lane2's fresh tasks with "[ttft_admission_refused]
        # the cell is at capacity; retry shortly" before they changed anything, and both were given up as "the lane
        # made no changes". A capacity error is transient (seconds), so it is requeued once without resting the model.
        cap = bool(lt.get("log")) and bool(UPSTREAM_CAPACITY_RE.search(tail(read(Path(lt["log"])), 3000)))
        if lt.get("fix_rounds") or not lt.get("run_dir") or not (err.exists() or cap):
            return False
        brief = self._first_brief(lt)
        if not brief.strip() or self.ERROR_REQUEUE in brief:
            return False
        if cap and not err.exists():
            err = Path(lt["log"])
        try:
            lane.cleanup(lt)
        except Exception:   # noqa: BLE001
            pass
        with self._save_lock:
            cur = self.state.get(f"{k}_task")
            if cur and cur.get("branch") == lt.get("branch"):
                self.save(**{f"{k}_task": None})
        self._carry(k, lt["title"], brief.rstrip() + "\n\n" + self.ERROR_REQUEUE + "\n", "coder error")
        log(f"{k}: coder failed before changing anything ({tail(read(err), 160).strip()}); "
            f"\"{lt['title']}\" requeued once")
        self.write_live_board()
        return True

    def _finish_lane(self, k: str, lt: dict, lane, rc: dict) -> None:
        """Commit and test a finished lane in its worktree, then queue its review, visual check or fix round."""
        self.wait_lane_art(k, lt)
        ok, out = lane.finish(lt, lt["title"])
        ahead = self.git("rev-list", "--count", f"{lt.get('base_start') or lt.get('base_commit') or self.main}..{lt['branch']}",
                         check=False).strip()
        if ahead in ("", "0") and self._requeue_errored_lane(k, lt, lane):
            pass
        elif ahead in ("", "0"):
            self._lane_update(k, lt["branch"], give_up="the lane made no changes")
        elif ok and self._lane_code_art(k, lt):
            pass
        elif ok and self._visual_check_on(k):
            self._lane_update(k, lt["branch"], tests_ok=True, test_out=str(out), visual_checking=True)
            log(f"{k}: tests pass in the lane; screenshotting before/after for the visual check")
            t = threading.Thread(target=self._visual_check, args=(k, lt["branch"]), daemon=True,
                                 name=f"visual-check-{k}")
            self._vc_threads[k] = t
            t.start()
        elif ok:
            self._lane_update(k, lt["branch"], finished=True, tests_ok=True, test_out=str(out),
                              ready_at=time.time())
            log(f"{k}: tests pass in the lane; waiting for the review")
            if rc.get("parallel"):
                # Owner 2026-10-13 (cycles under 30 min): review it now, in its own thread. The checker tests
                # finished lanes one at a time (~8 min each) and only started reviews after the whole pass: lane6
                # passed at 11:22 and was still unreviewed at 11:58, behind three other lanes' suites.
                self.review_lanes([k])
        else:
            self._lane_fix(k, lt, [f"The full test suite fails in your worktree. Output: {out}"],
                           tail(read(out), 3000))

    def review_lanes(self, keys: list[str]) -> None:
        """Owner 2026-10-10: with lane_review.parallel every lane gets its own ChatGPT review message in its own
        thread (one batched message made every lane wait for the slowest review and stalled the lane checker)."""
        keys = [k for k in keys if not self.accept_lane_light(k)]
        if not keys:
            return
        if not self.cfg.get('lane_review', {}).get('parallel'):
            return self._review_lane_group(keys)
        retry = float(self.cfg.get('lane_review', {}).get('retry_s', 120))
        for k in keys:
            lt = self.state.get(f'{k}_task')
            if not lt or not self._lane_update(k, lt['branch'], reviewing=True, review_started_at=time.time()):
                continue

            def run(k=k, branch=lt['branch']) -> None:
                self._tls.bg = True
                try:
                    self._review_lane_group([k], f'LANEREVIEW_{k}')
                except Exception as e:   # noqa: BLE001 - a review problem must never stop the relay
                    log(f'{k}: review error {type(e).__name__}: {str(e)[:200]}')
                    self._lane_update(k, branch, reviewing=False, review_retry_at=time.time() + retry)
                finally:
                    try:
                        self._tls.bridge and self._tls.bridge.disconnect()
                    except Exception:   # noqa: BLE001
                        pass

            log(f'lane review: {k} reviewed in its own ChatGPT message')
            threading.Thread(target=run, name=f'lane-review-{k}', daemon=True).start()

    def prefetch_lane_task(self, key: str, lt: dict) -> None:
        """Owner 2026-10-10: a lane used to idle 16-23 min at every cycle start while its next task was planned.
        As soon as its current task is accepted (it merges at the next cycle start), plan its next task in the
        background and queue it, so the lane restarts the moment it merges. Dispatch still revalidates ownership
        and file fingerprints; a stale task is replanned as before."""
        if not (self.queue_enabled() and self.cfg["chatgpt"].get("prefetch_lane_tasks", True)):
            return
        if load_json(HERE / "prepared" / "lane_queue.json", {}).get(key) or STOP_PATH.exists():
            return
        title = lt.get("title", "")

        def run() -> None:
            self._tls.bg = True
            try:
                note = (f"\nLane {key}'s current task \"{title}\" is ACCEPTED and merges at the next cycle start. "
                        "Plan this lane's NEXT task, to start right after that merge. Assume that work is merged; "
                        "prefer files it did not touch.\n"
                        + (f"This lane's focus area: {self.cfg[key]['plan_focus']}. Stay inside it.\n"
                           if self.cfg.get(key, {}).get("plan_focus") else ""))
                got = self._plan_lane_group([key], f"LANESPLAN_{key}", note)
                if got:
                    self.note_claims(f"{key} prefetch", got)
                    log(f"{key}: next task queued in advance: {next(iter(got.values()))[0]}")
            except Exception as e:   # noqa: BLE001 - prefetch is best effort; launch plans as before
                log(f"{key}: next-task prefetch failed ({type(e).__name__}: {str(e)[:160]})")
            finally:
                try:
                    self._tls.bridge and self._tls.bridge.disconnect()
                except Exception:   # noqa: BLE001
                    pass

        threading.Thread(target=run, name=f"prefetch-{key}", daemon=True).start()

    def _review_lane_group(self, keys: list[str], tag: str = "LANEREVIEW") -> None:
        blocks = []
        for k in keys:
            lt = self._lane_update(k, self.state[f"{k}_task"]["branch"], reviewing=True, review_started_at=time.time())
            if not lt:
                continue
            patch_path = Path(lt["run_dir"]) / "DIFF_vs_main.patch"
            base = lt.get("base_start") or lt.get("base_commit")   # early start: review only this task, not the accepted task under it
            write(patch_path, self.git("diff", f"{base}..{lt['branch']}" if base else f"{self.main}...{lt['branch']}",
                                       check=False))
            first_brief = self.lane2(k).runs / re.sub(r'-fix\d+$', '', Path(lt['run_dir']).name) / 'BRIEF.md'
            blocks.append(f"### Lane id {k} ({self.cfg.get(k, {}).get('label', k)}): {lt['title']}\n"
                          f"- task: {first_brief}\n- branch: {lt['branch']} (worktree {lt['dir']})\n"
                          + (f"- built on this lane's already ACCEPTED task \"{lt.get('base_title', '')}\" (commit "
                             f"{base[:10]}, merges first); review only the diff below\n" if base else "")
                          + f"- diff vs {base[:10] if base else self.main}: {patch_path}\n"
                          f"- test output: {lt.get('test_out')}\n"
                          f"- coder report: {Path(lt['run_dir']) / 'REPORT.md'}\n"
                          f"- prior defects: {lt.get('prev_defects', [])}\n"
                          f"- repair baseline commit: {lt.get('repair_base', 'first review')}\n"
                          f"- repair brief: {Path(lt['run_dir']) / 'BRIEF.md'}")
        if not blocks:
            return
        log(f"lane review: {len(blocks)} lane(s) in one message: {', '.join(keys)}")
        try:
            out = self.think(P.LANE_REVIEW.substitute(repo=self.repo, main=self.main, lanes="\n\n".join(blocks)),
                             tag)
        except Exception as e:   # noqa: BLE001 - retry review while the main cycle continues
            log(f"lane review unavailable ({type(e).__name__}); keeping lanes pending review")
            out = ""
        for k in keys:
            lt = self.state.get(f"{k}_task")
            if not lt:
                continue
            block = extract(out, f"LANE_REVIEW_{k}") or ""
            try:
                v = validate_verdict(json.loads(block[block.find("{"): block.rfind("}") + 1]))
            except ValueError as e:
                self._lane_update(k, lt['branch'], reviewing=False, review_error=str(e),
                                  review_retry_at=time.time() + float(self.cfg.get('lane_review', {}).get('retry_s', 120)))
                log(f'{k}: no valid review; pending independent review')
                continue
            if v['verdict'] == 'DEFERRED':
                self.defer_lane(k, lt, v['summary'])
            elif v['verdict'] == 'FIX_REQUIRED':
                # "reviewing" stays set until _lane_fix has restarted the coder: cleared earlier, the lane checker
                # saw a finished, unreviewed lane and reviewed the old diff again (lane4, cycle 202, 2026-10-13).
                self._lane_fix(k, self.state[f"{k}_task"], [str(d) for d in v["defects"]],
                               v.get("summary", "") + '\n\nRepair diagnosis:\n' + str(v.get('diagnosis', '')))
            else:
                self._lane_update(k, lt["branch"], reviewing=False, review_finished_at=time.time(),
                                  review={"verdict": "ACCEPTED",
                                                                             "summary": v.get("summary", "")})
                log(f"{k}: review ACCEPTED ({str(v.get('summary', ''))[:120]})")
                self.prefetch_lane_task(k, lt)

    def visual_lanes(self) -> list[str]:
        """Lanes that fix playtest defects instead of gameplay. An empty visual_lanes list means none (owner
        2026-10-08: gameplay first; visual work waits)."""
        v = self.cfg.get("visual_lanes")
        return list(v) if v is not None else [self.cfg.get("visual_lane", "lane3")]

    def claude_allowed(self, tag: str) -> bool:
        """Owner 2026-10-08: Claude (local or cloud) only for the 4-hourly gameplay check (PLAYTEST); milestone audits,
        workflow reviews and rescues run on ChatGPT."""
        allowed = self.cfg.get("claude_only_for")
        return allowed is None or tag.split("_", 1)[0] in allowed

    def _visual_check_on(self, key: str) -> bool:
        return (key in self.visual_lanes()
                and bool(self.cfg.get("lane_review", {}).get("visual_check", True))
                and bool((self.cfg.get("playtest") or {}).get("enabled")))

    def _visual_check(self, key: str, branch: str) -> None:
        """Owner 2026-10-08: the visual lane's fix is screenshotted before (its base) and after (its branch) in the
        scenarios it names (SHOTS: line in its report), and Claude checks the change is visible and nothing else got
        worse before the lane goes to review. Any failure of the check itself lets the lane continue without it."""
        self._tls.bg = True
        lt = self.state.get(f"{key}_task") or {}
        try:
            from playtest import Playtest
            run_dir = Path(lt["run_dir"])
            first = self.lane2(key).runs / run_dir.name.split("-fix")[0]
            names: list[str] = []
            for rep_path in (run_dir / "REPORT.md", first / "REPORT.md", run_dir / "REPLY.md"):
                m = re.search(r"(?mi)^\W*SHOTS:\s*(.+)$", read(rep_path))
                if m:
                    names = re.findall(r"[a-z][a-z0-9_]+", m.group(1))[:3]
                    break
            if not names:
                names = list(self.cfg.get("lane_review", {}).get("visual_check_default",
                                                                 ["title"]))
            head = self.git("rev-parse", branch)
            base = lt.get("base_start") or lt.get("base_commit") or self.git("merge-base", self.main, branch)
            diff = run_dir / "VISUAL_DIFF.patch"
            write(diff, self.git("diff", base, head, check=False))
            shots = HERE / "lane_shots" / run_dir.name
            pc = {**self.cfg["playtest"], "clone": self.cfg["playtest"].get("shots_clone", G.tmp_dir("shots"))}
            t0 = time.time()
            with self._shots_lock:
                before = Playtest(pc, self.repo, log).capture(base, shots / "before", names)
                after = Playtest(pc, self.repo, log).capture(head, shots / "after", names)
                old = sorted((d for d in shots.parent.iterdir() if d.is_dir()), key=lambda d: d.stat().st_mtime)
                for d in old[:-int(pc.get("keep_shot_dirs", 6))]:
                    shutil.rmtree(d, ignore_errors=True)
            pairs = []
            for n in names:
                b, a = before.get(n) or {}, after.get(n) or {}
                if not a:
                    continue
                pairs.append(f"- {n}: BEFORE {', '.join(b.get('shots', [])) or '(none)'}\n"
                             f"  AFTER {', '.join(a.get('shots', [])) or '(none)'}"
                             + (f"\n  AFTER console errors: {'; '.join(a['errors'][:5])}" if a.get("errors") else ""))
            if not pairs:
                raise RuntimeError(f"no screenshots for {names}")
            log(f"{key}: visual check screenshots of {', '.join(names)} in {time.time() - t0:.0f}s")
            verdict = self._visual_verdict_chatgpt(key, names, before, after, first / "BRIEF.md", diff, shots)
            if not verdict:
                log(f"{key}: asking Claude for the visual check")
                out = self.claude(P.VISUAL_CHECK.substitute(brief=first / "BRIEF.md", diff=diff, base=base[:8],
                                                            head=head[:8], pairs="\n".join(pairs)),
                                  f"VISUALCHECK_{key}")
                verdict = (extract(out, "VERDICT") or out).strip()
        except Exception as e:   # noqa: BLE001 - the check is a bonus; never block the lane on it
            log(f"{key}: visual check skipped ({type(e).__name__}: {str(e)[:200]}); continuing to the review")
            self._lane_update(key, branch, visual_checking=False, finished=True, visual="skipped")
            return
        first_line = verdict.splitlines()[0].strip().upper() if verdict else ""
        detail = " ".join(verdict.splitlines()[1:]).strip()
        write(Path(lt["run_dir"]) / "VISUAL_CHECK.md", verdict + "\n")
        if first_line.startswith("FAIL"):
            log(f"{key}: visual check FAILED: {detail[:200]}")
            cur = self._lane_update(key, branch, visual_checking=False, visual="FAIL")
            if cur:
                self._lane_fix(key, cur, [f"Screenshot check: {detail}"],
                               f"Before/after screenshots: {HERE / 'lane_shots' / Path(lt['run_dir']).name}")
            return
        log(f"{key}: visual check PASS: {detail[:200]}")
        self._lane_update(key, branch, visual_checking=False, finished=True, visual="PASS")

    def _visual_verdict_chatgpt(self, key: str, names: list[str], before: dict, after: dict, brief: Path,
                                diff: Path, shots: Path) -> str:
        """Owner 2026-10-08: ChatGPT (chat mode, low effort) judges the before/after screenshots, attached to the
        message, instead of Claude. Returns the verdict text, or "" to fall back to Claude."""
        g = self.cfg.get("chatgpt") or {}
        if not g.get("enabled") or self.cfg.get("lane_review", {}).get("visual_checker", "chatgpt") != "chatgpt":
            return ""
        per = max(1, int(self.cfg.get("lane_review", {}).get("visual_check_max_images", 12)) // (2 * len(names)))
        att = shots / "attach"
        shutil.rmtree(att, ignore_errors=True)
        att.mkdir(parents=True, exist_ok=True)
        files, errors = [], []
        for n in names:
            for side, res in (("BEFORE", before), ("AFTER", after)):
                r = res.get(n) or {}
                got = [Path(p) for p in r.get("shots", []) if Path(p).is_file()]
                if len(got) > per:   # spread the picks over the run (spawn ... last phase)
                    got = [got[round(i * (len(got) - 1) / (per - 1))] for i in range(per)] if per > 1 else got[-1:]
                for p in got:
                    dst = att / f"{side}_{p.name}"
                    shutil.copy2(p, dst)
                    files.append(dst)
                if side == "AFTER" and r.get("errors"):
                    errors.append(f"- {n}: " + "; ".join(r["errors"][:5]))
        if not files:
            return ""
        text = P.VISUAL_CHECK_ATTACH.substitute(
            brief=read(brief)[:6000], diff=read(diff)[:20000],
            errors=("\nConsole errors in the AFTER build:\n" + "\n".join(errors) + "\n") if errors else "")
        reply = self._ask_chatgpt(text, f"VISUALCHECK_{key}", 1, files=files)
        verdict = (extract(reply or "", "VERDICT") or "").strip()
        if not verdict:
            log(f"{key}: ChatGPT gave no visual verdict")
        return verdict

    def _lane_code_art(self, k: str, lt: dict) -> bool:
        """Owner 2026-11-04 ("make sure that art isnt done with code"): a lane change that adds code-drawn visuals
        gets a fix round asking for authored images (True). After its fix round any that remain only block the light
        and trusted acceptance, so the ChatGPT review decides."""
        if (self.cfg.get("code_art_check") or {}).get("enabled", True) is False:
            return False
        base = lt.get("base_start") or lt.get("base_commit")
        found = code_art_lines(self.git("diff", f"{base}..{lt['branch']}" if base else f"{self.main}...{lt['branch']}",
                                        check=False))
        if not found:
            return False
        if int(lt.get("fix_rounds") or 0):
            self._lane_update(k, lt["branch"], evidence_warning="it still draws visuals in code ("
                              + "; ".join(found)[:300] + "); new code-drawn visuals are a defect")
            log(f"{k}: still draws visuals in code after its fix round ({len(found)} line(s)); the review decides")
            return False
        log(f"{k}: the change draws visuals in code ({len(found)} line(s), e.g. {found[0][:90]}); "
            "fix round: use authored images")
        self._lane_fix(k, lt, [P.code_art_defect(found)], "")
        return True

    def _lane_fix(self, key: str, lt: dict, defects: list[str], notes: str) -> None:
        n = int(lt.get("fix_rounds", 0)) + 1
        repeated = similar(defects, lt.get('prev_defects') or [])
        escalate = (repeated and self.cfg.get('lane_review', {}).get('escalate_repeated', True)
                    and self._lane_builder(key) == 'DeepSeek')
        if n > int(self.cfg.get("lane_review", {}).get("max_fix_rounds", 1)):
            self._lane_update(key, lt["branch"], reviewing=False,
                              give_up="rejected after its fix round: " + "; ".join(defects)[:400])
            log(f"{key}: still failing after its fix round; giving up at the cycle break")
            return
        first_brief = self.lane2(key).runs / re.sub(r'-fix\d+$', '', Path(lt['run_dir']).name) / 'BRIEF.md'
        text = (f"# FIX ROUND {n} for your lane task: {lt['title']}\n\nYour work on this task (task: {first_brief}) "
                "was checked and must be fixed before it can be merged. Fix ONLY these defects; keep everything that "
                "already works.\n\n## Defects\n" + "\n".join(f"- {d}" for d in defects)
                + (f"\n\n## Notes\n{notes}" if notes else "")
                + "\n\n## Original task and acceptance criteria\n" + read(first_brief)
                + "\n\nRun the full test suite before finishing; every test must pass.")
        repair_base = self.git('-C', lt['dir'], 'rev-parse', 'HEAD', check=False)
        to = self.cfg.get('lane_review', {}).get('escalate_to', 'codex')
        if escalate:
            self._lane_update(key, lt['branch'], repair_builder=to)
            log(f'{key}: the same defect survived a repair; {to} takes over in the existing worktree')
        try:
            info = self.lane2(key).resume(lt, text, n)
        except Exception as e:   # noqa: BLE001
            self._lane_update(key, lt["branch"], reviewing=False, give_up=f"fix round could not start: {e}")
            return
        self._lane_update(key, lt["branch"], **{**info, "finished": False, "tests_ok": False, "review": None,
                                                "reviewing": False, "fix_rounds": n, 'prev_defects': defects,
                                                'repair_base': repair_base, 'ready_at': None,
                                                'review_retry_at': 0,
                                                'first_started_ts': lt.get('first_started_ts', lt.get('started_ts')),
                                                'repair_builder': to if escalate else lt.get('repair_builder')})
        log(f"{key}: fix round {n} started ({len(defects)} defect(s))")

    def defer_lane(self, key: str, lt: dict, reason: str) -> None:
        """Save the lane branch without merging/deleting it; free the lane for other work."""
        root = lt['dir']
        if self.git('-C', root, 'branch', '--show-current') != lt['branch']:
            raise Halt(f'{key}: cannot preserve deferred work on an unexpected branch')
        self.git('-C', root, 'add', '-A')
        if not self.git_ok('-C', root, 'diff', '--cached', '--quiet'):
            self.git('-C', root, 'commit', '--no-verify', '-m',
                     f"relay deferred {key}: {lt['title']}")
        entry = {'title': lt['title'], 'branch': lt['branch'],
                 'commit': self.git('-C', root, 'rev-parse', 'HEAD'),
                 'dir': root, 'run_dir': lt['run_dir'], 'reason': reason, 'at': ts()}
        write(Path(lt['run_dir']) / 'DEFERRED.md',
              f"# Deferred task\n\n{reason}\n\nSaved branch: {lt['branch']}\n"
              f"Saved commit: {entry['commit']}\nOther approved tasks continue.\n")
        with self._save_lock:
            cur = self.state.get(f'{key}_task')
            if not cur or cur['branch'] != lt['branch']:
                return
            history = (self.state.get(f'{key}_deferred') or []) + [entry]
            self.save(**{f'{key}_task': None, f'{key}_deferred': history[-50:]})
        log(f"{key}: saved and deferred \"{lt['title']}\": {reason[:160]}")

    def _lane_timeout(self, key: str, lt: dict, lane) -> bool:
        """Stop a running lane task past its timeout_s; True when it was over the limit and handled.
        2026-10-18: only checked at cycle boundaries, so lane4 ran 3h45m on one task while cycle 405 took 175 min;
        the lane checker now calls this every pass too."""
        if time.time() - lt.get("started_ts", time.time()) < int(self.cfg.get(key, {}).get("timeout_s", 4500)):
            return False
        lane.stop(lt)
        # A slow DeepSeek run still editing at the timeout used to lose all its work (lane3, 2026-10-08): test
        # and review what it has instead, once. ChatGPT lanes cannot be stopped, so they still give up.
        if (type(lane).__name__ in ("LocalLane", "CodexLane") and not lt.get("timed_out")
                and self.git("-C", lt["dir"], "status", "--porcelain", check=False).strip()):
            self._lane_update(key, lt["branch"], timed_out=True, finishing=lt.get("run_dir"))
            log(f"{key}: \"{lt['title']}\" timed out with changes; testing and reviewing what it has")
            return True
        self.lane_give_up(key, lt, "timed out")
        return True

    def lane_boundary(self, key: str) -> None:
        lt = self.state.get(f"{key}_task")
        if not lt:
            return
        lane = self.lane2(key)
        if lt.get("give_up"):
            self.lane_give_up(key, lt, lt["give_up"])
            return
        review_on = self.cfg.get("lane_review", {}).get("enabled", True)
        if not lt.get("finished") and lane.running(lt["pid"]):
            if not self._lane_timeout(key, lt, lane):
                log(f"{key}: \"{lt['title']}\" still running")
            return
        if review_on:
            if (lt.get("review") or {}).get("verdict") != "ACCEPTED":
                log(f"{key}: \"{lt['title']}\" " + ("waiting for its review" if lt.get("finished")
                                                     else "finished; the lane checker tests it next"))
                return
        else:
            from lane_local import LaneError
            try:
                ok, out = lane.finish(lt, lt["title"])
            except (LaneError, subprocess.SubprocessError, OSError) as e:
                self.lane_give_up(key, lt, f"finish failed: {e}")
                return
            if not ok:
                self.lane_give_up(key, lt, "no changes or tests fail in the lane: " + tail(read(out), 600))
                return
        self._merge_one(key, lt, lane)

    def _merge_one(self, key: str, lt: dict, lane, parked: bool = False, reapply_now: bool = False) -> None:
        base = lt.get("base_commit")
        pre = self.git("rev-parse", "HEAD")
        unioned = False
        if base and not self.git_ok("merge-base", "--is-ancestor", base, "HEAD"):
            why = f"the accepted task it was built on (\"{lt.get('base_title', '')}\") was not merged"
            if not self._try_reapply(key, lt, parked, lt.get("base_start") or base, why, reapply_now):
                return
        else:
            merge = subprocess.run(["git", "merge", "--no-ff", "--no-edit", "-m",
                                    f"Lane {key[4:]} ({self._lane_builder(key)}): {lt['title']}\n\nMerged by relay v2 after the full test "
                                    "suite passed.", lt["branch"]], cwd=self.repo, capture_output=True, text=True)
            if merge.returncode:
                clashed = self.git("diff", "--name-only", "--diff-filter=U", check=False).split()
                unioned = bool(clashed) and self._union_resolve(clashed)
            if unioned:
                log(f"{key}: merge clash in {', '.join(clashed[:5])} resolved by keeping both sides; the full suite checks it")
            elif merge.returncode:
                self.git("merge", "--abort", check=False)
                self.git("reset", "--hard", pre, check=False)
                why = f"merge conflict with the main branch ({', '.join(clashed[:5])})"
                if not self._try_reapply(key, lt, parked, "", why, reapply_now):
                    return
        batch = getattr(self, "_merge_batch", None)
        if batch is not None:   # owner 2026-10-10: one full test run for all of this cycle's lane merges
            batch.append((key, lt, lane, pre, self.git("rev-parse", "--short", "HEAD"), parked))
            log(f"{key}: merged; the full suite runs once for this cycle's lane merges")
            return
        passed, lp = self.merge_suite(CYCLES / f"_{key}", f"merge_{int(time.time())}")
        if not passed:
            self.git("reset", "--hard", pre, check=False)
            why = "tests fail after merging: " + tail(read(lp), 600)
            if lt.get("branch") in self._reapplied:
                self._give_up_redo(key, lt, parked, "its accepted diff, re-applied on the new main, failed the "
                                   "tests there", self._reapplied.pop(lt["branch"]), why)
                return
            redo = self._redo_brief(lt, ("its merge with the main branch clashed in a shared file and the combined "
                                     "code failed the tests" if unioned else "the full suite failed after merging it")
                                    + self._failed_tests(read(lp)))
            (self._parked_give_up if parked else self.lane_give_up)(key, lt, why)
            self._requeue_redo(key, lt, redo)
            return
        self._reapplied.pop(lt.get("branch"), None)
        self._finish_lane_merge(key, lt, lane, self.git("rev-parse", "--short", "HEAD"), parked)

    # Owner 2026-10-13: an accepted lane task that could not merge (a clash git cannot settle, or the stacked task it
    # was built on was not merged) went back to a coder: a lane slot, a full coder run and a second review, often
    # 30-60 min, although its own diff usually still applies (Frostbite Tremor applied cleanly on 2026-10-13). Now
    # the relay first re-applies just that task's own accepted diff on the current main (3-way, keeping both sides
    # of insert-only clashes) and lets the full suite decide; only when that fails is it redone by a coder. In a
    # batch these run after every normal merge, so a bad one can be dropped without re-testing lane by lane.
    _reapplied: dict = {}

    def _try_reapply(self, key: str, lt: dict, parked: bool, base: str, why: str, now: bool) -> bool:
        """True when the task's own diff is now committed on HEAD; False when it was deferred or given up."""
        base = base or self.git("merge-base", self.main, lt["branch"], check=False).strip()
        if getattr(self, "_merge_batch", None) is not None and not now:
            self._reapply_later.append((key, lt, parked))
            log(f"{key}: \"{lt['title']}\" did not merge ({why[:120]}); re-applying its own diff after the other merges")
            return False
        if base and self._reapply(key, lt, base):
            self._reapplied = {**self._reapplied, lt["branch"]: base}
            log(f"{key}: \"{lt['title']}\": {why[:120]}; re-applied its own accepted diff on the new main instead "
                "of redoing it; the full suite checks it")
            return True
        self._give_up_redo(key, lt, parked, why, base, why)
        return False

    def _give_up_redo(self, key: str, lt: dict, parked: bool, why: str, base: str, reason: str) -> None:
        redo = self._redo_brief(lt, why, base)
        (self._parked_give_up if parked else self.lane_give_up)(key, lt, reason)
        self._requeue_redo(key, lt, redo)

    def _reapply(self, key: str, lt: dict, base: str) -> bool:
        """Apply base..branch to HEAD and commit it; False (HEAD and tree restored) when it does not apply cleanly."""
        from lane_local import resolve_clashes
        pre = self.git("rev-parse", "HEAD")
        diff = self.git("diff", f"{base}..{lt['branch']}", check=False)
        if not diff.strip():
            return False
        patch = (Path(lt["run_dir"]) if lt.get("run_dir") else CYCLES / f"_{key}") / "REAPPLY.patch"
        patch.parent.mkdir(parents=True, exist_ok=True)
        patch.write_bytes((diff + "\n").replace("\r\n", "\n").encode("utf-8"))   # LF: a CRLF patch never 3-way applies
        r = subprocess.run(["git", "apply", "--3way", "--index", "--whitespace=nowarn", str(patch)], cwd=self.repo,
                           capture_output=True, text=True, encoding="utf-8", errors="replace")
        unmerged = sorted(set(self.git("diff", "--name-only", "--diff-filter=U", check=False).split()))
        ok = (not r.returncode and not unmerged) or (bool(unmerged) and resolve_clashes(self.repo, unmerged)
                                                    and not self.git("diff", "--name-only", "--diff-filter=U",
                                                                     check=False).strip())
        if ok and self.git_ok("diff", "--cached", "--quiet"):
            log(f"{key}: \"{lt['title']}\" is already on the main branch")
        elif ok:
            ok = self.git_ok("commit", "--no-verify", "-m", f"Lane {key[4:]} ({self._lane_builder(key)}): "
                             f"{lt['title']}\n\nAccepted diff re-applied on the new main by relay v2 after a merge "
                             "clash; merged after the full test suite passed.")
        if not ok:
            self.git("reset", "--hard", pre, check=False)
        return ok

    def _union_resolve(self, files: list[str]) -> bool:
        """Two lanes that both appended entries to one catalog, script or test clash in git although nothing
        conflicts (9 accepted tasks were lost that way on 2026-10-11/12). Keep both sides of every clash and finish
        the merge; the full suite then decides. False (nothing changed) when a file is not plain text code/data, was
        added or deleted on one side, or a block changed an existing line."""
        from lane_local import resolve_clashes
        if not resolve_clashes(self.repo, files):
            return False
        if self.git("diff", "--name-only", "--diff-filter=U", check=False).strip():
            return False
        return self.git_ok("commit", "--no-verify", "--no-edit")

    def wait_reviews_for_prepared_plan(self, poll_s: float = 10.0) -> None:
        """2026-10-24: cycles 193 and 194 both dropped the prepared owner-order plan (short support card text)
        because lane7 held its files while lane7's finished, passing work waited for a review that ACCEPTED it
        2-3 min later. Before the lane merges, wait a bounded time for such reviews, so the accepted work merges
        now and the prepared plan stays usable."""
        limit = float(self.cfg.get('task_queue', {}).get('review_wait_for_plan_s', 420))
        scope = self.next_main_scope() if self.queue_enabled() and limit > 0 else {}
        if not scope:
            return

        def blockers() -> list[str]:
            out = []
            for k in self.LANE_KEYS:
                lt = self.state.get(f'{k}_task') or {}
                if (lt.get('finished') and lt.get('tests_ok') and not lt.get('give_up')
                        and (lt.get('review') or {}).get('verdict') != 'ACCEPTED'
                        and TP.conflict(scope, {k: self.task_scope(k, lt)})):
                    out.append(k)
            return out + self.plan_holding_lanes(scope)

        waiting = blockers()
        if not waiting:
            return
        # 2026-10-24 (owner: "constant clashes with the lanes"): a lane still coding on the plan's files is waited
        # for too, with the lane checker running so its finish is tested and reviewed during the wait.
        coding = self.plan_holding_lanes(scope)
        if coding:
            limit = max(limit, float(self.cfg.get('task_queue', {}).get('lane_wait_for_plan_s', 720)))
            self._plan_wait = True
            self.start_lane_checker()
        what = 'lane' if coding else 'review'
        log(f"waiting up to {limit / 60:.0f} min for the {what} of {', '.join(waiting)}: it holds files of the "
            "prepared plan")
        end = time.time() + limit
        try:
            while waiting and time.time() < end and not STOP_PATH.exists():
                time.sleep(poll_s)
                waiting = blockers()
        finally:
            self._plan_wait = False
        if waiting:
            log(f"{what} of {', '.join(waiting)} still pending; the prepared plan is checked as it is")

    def plan_holding_lanes(self, scope: dict, scopes: dict | None = None) -> list[str]:
        """Lanes still coding on files of `scope` that started long enough ago to finish soon (lanes take 13-26 min).
        `scopes`: the lanes' active scopes (reserved plus actually changed files). Off with
        task_queue.hold_plan_lane_min <= 0."""
        mins = float(self.cfg.get('task_queue', {}).get('hold_plan_lane_min', 10))
        if mins <= 0 or not scope:
            return []
        out = []
        for k in self.LANE_KEYS:
            lt = self.state.get(f'{k}_task') or {}
            if not lt.get('title') or lt.get('give_up') or not self._still_coding(k):
                continue
            try:
                age = time.time() - datetime.datetime.strptime(lt.get('started') or '', "%Y-%m-%d %H:%M:%S").timestamp()
            except ValueError:
                continue
            own = (scopes or {}).get(k) or self.task_scope(k, lt)
            if age >= mins * 60 and TP.conflict(scope, {k: own}):
                out.append(k)
        return out

    def merge_parked(self, key: str) -> None:
        """Accepted work parked by an early start merges first, oldest first (the running task is built on it)."""
        for p in self.parked(key):
            self._merge_one(key, p, self.lane2(key), parked=True)

    def _parked_give_up(self, key: str, p: dict, reason: str) -> None:
        with self._save_lock:
            self.save(**{f"{key}_parked": [x for x in self.parked(key) if x.get("branch") != p.get("branch")]})
        self.git("branch", "-D", p["branch"], check=False)
        failed = (self.state.get(f"{key}_failed") or []) + [{"title": p["title"], "reason": reason, "at": ts()}]
        self.save(**{f"{key}_failed": failed[-20:]})
        log(f"{key}: gave up on accepted \"{p['title']}\": {reason[:160]}")

    def merge_lanes(self) -> None:
        """Merge every accepted lane, then run the full suite ONCE (was once per lane: ~1.7 min each at every cycle
        start). If the combined result fails, undo and fall back to merging and testing one lane at a time."""
        if not self.cfg.get("lane_review", {}).get("batch_merge_tests", True):
            for k in self.LANE_KEYS:
                self.merge_parked(k)
                self.lane_boundary(k)
            return
        self._merge_batch, self._reapply_later, self._reapplied = [], [], {}
        try:
            for k in self.LANE_KEYS:
                self.merge_parked(k)
                self.lane_boundary(k)
            plain = len(self._merge_batch)
            later, self._reapply_later = self._reapply_later, []
            for key, lt, parked in later:   # oldest first: a stacked task follows the one it was built on
                self._merge_one(key, lt, self.lane2(key), parked, reapply_now=True)
        finally:
            batch, self._merge_batch = self._merge_batch, None
        sync = bool(self.state.get("merge_sync_next"))
        if sync:
            self.save(merge_sync_next=False)
        if not batch:
            return
        if not sync and self.cfg.get("lane_review", {}).get("async_merge_check", True):
            self.begin_merge_check(batch)
            return
        self.start_early_refresh()
        passed, lp = self.merge_suite(CYCLES / "_lanes", f"merge_batch_{int(time.time())}")
        if passed:
            for key, lt, lane, _pre, commit, parked in batch:
                self._finish_lane_merge(key, lt, lane, commit, parked)
            return
        if plain and len(batch) > plain:   # drop the re-applied diffs first; one more run instead of one per lane
            log(f"the {len(batch)} merged lanes fail the full suite together; retrying without the "
                f"{len(batch) - plain} re-applied diff(s)")
            self.git("reset", "--hard", batch[plain][3], check=False)
            failed_lp = lp
            passed, lp = self.merge_suite(CYCLES / "_lanes", f"merge_batch_{int(time.time())}")
            if passed:
                for key, lt, lane, _pre, commit, parked in batch[:plain]:
                    self._finish_lane_merge(key, lt, lane, commit, parked)
                for key, lt, lane, _pre, _commit, parked in batch[plain:]:
                    self._give_up_redo(key, lt, parked, "its accepted diff, re-applied on the new main, failed the "
                                       "tests there", self._reapplied.pop(lt["branch"], ""),
                                       "re-applied diff fails the full suite: " + tail(read(failed_lp), 600))
                return
        log(f"the {len(batch)} merged lanes fail the full suite together; merging and testing them one at a time")
        self.git("reset", "--hard", batch[0][3], check=False)
        for key, lt, lane, _pre, _commit, parked in batch:
            self._merge_one(key, lt, lane, parked)

    def _finish_lane_merge(self, key: str, lt: dict, lane, commit: str, parked: bool = False,
                           tested: str | None = None) -> None:
        if not self.git_ok("push", self.cloud.remote, self.main):
            log(f"warning: could not push {self.main} after the {key} merge")
        if parked:   # its worktree now belongs to the task started on top of it; only drop the branch name
            self.git("branch", "-D", lt["branch"], check=False)
            with self._save_lock:
                self.save(**{f"{key}_parked": [x for x in self.parked(key) if x.get("branch") != lt.get("branch")]})
        else:
            lane.cleanup(lt)
        hist = (self.state.get(f"{key}_history") or []) + [{"title": lt["title"], "commit": commit, "at": ts()}]
        now = time.time()
        hist[-1].update(builder=self._lane_builder(key), fix_rounds=lt.get('fix_rounds', 0),
                        review_wait_s=max(0, (lt.get('review_started_at') or now) - (lt.get('ready_at') or now)),
                        ready_to_merge_s=max(0, now - (lt.get('ready_at') or now)),
                        elapsed_s=max(0, now - (lt.get('first_started_ts') or lt.get('started_ts') or now)))
        # Owner 2026-10-31: one fix round is routine; only a task that needed lane_lessons_min_fixes (2) teaches
        if lt.get('fix_rounds', 0) >= int(self.cfg.get("chatgpt", {}).get('lane_lessons_min_fixes', 2)):
            self.learn_lane_lessons(key, lt, f"was merged only after {lt['fix_rounds']} review fix round(s)")
        if parked:
            hist[-1]['early_start'] = True
        self.save(**({} if parked else {f"{key}_task": None}), **{f"{key}_history": hist[-50:]},
                  last_good_commit=commit, tested_main=tested or self.git("rev-parse", "HEAD"))
        log(f"=== {key} MERGED -> {commit} ({lt['title']}) ===")
        if key in self.visual_lanes():   # counts toward the next visual review (_playtest_due)
            with self._save_lock:
                self.save(visual_fixes_since_playtest=int(self.state.get("visual_fixes_since_playtest") or 0) + 1)
        notify(f"{G.NAME} {key} merged", lt["title"])

    # ---- async lane-merge check (owner 2026-10-13, cycles under 30 min): the full suite for the lane merges took
    # 7-12 min of every cycle's START. The merged main is now tested in its own worktree while the cycle plans and
    # builds on it; the cycle's own tests wait for the result. A failure moves the cycle's work back onto the old
    # main and the lanes merge one at a time (tested each) at the next cycle start.

    CLAUDE_QUEUE = HANDOFF / "claude_land.json"
    CLAUDE_STATUS = HANDOFF / "claude_land_status.json"
    CLAUDE_FINAL = ("landed", "failed")

    def land_claude_queue(self) -> None:
        """Owner 2026-11-06: the owner's Claude Code session codes beside the relay instead of pausing it for every
        landing. It queues finished side branches in handoff/claude_land.json ({"queue": [{"branch", "commit"}]});
        each cycle start merges them onto main before the lane merges, and the lane-merge check (or one of their
        own) runs the full suite alongside the cycle. A failed check takes them off main again together with the
        lanes. handoff/claude_land_status.json records each commit's result for the session to read."""
        self._claude_pre, self._claude_landed = None, []
        if (not self.cfg.get("claude_land", {}).get("enabled", True) or self.state.get("merge_sync_next")
                or not self.cfg.get("lane_review", {}).get("batch_merge_tests", True)
                or not self.cfg.get("lane_review", {}).get("async_merge_check", True)):
            return
        try:
            queue = json.loads(self.CLAUDE_QUEUE.read_text(encoding="utf-8")).get("queue") or []
        except (OSError, ValueError, AttributeError):
            return
        status = self._claude_status()
        pre = self.git("rev-parse", "HEAD")
        for ent in queue:
            if not isinstance(ent, dict):
                continue
            br, want = str(ent.get("branch") or ""), str(ent.get("commit") or "")
            commit = self.git("rev-parse", "--verify", "-q", want + "^{commit}", check=False).strip() if want else ""
            if not br or not commit or (status.get(commit) or {}).get("state") in self.CLAUDE_FINAL:
                continue
            if self.git_ok("merge-base", "--is-ancestor", commit, "HEAD"):
                self._claude_mark(commit, br, "landed", f"already on {self.main}")
                continue
            tip = self.git("rev-parse", "--verify", "-q", br + "^{commit}", check=False).strip()
            if tip != commit:
                log(f"claude: {br} moved past its queued commit {commit[:8]}; waiting for the session to queue it again")
                continue
            r = subprocess.run(["git", "merge", "--no-ff", "--no-edit", "-m", f"Claude side branch: {br}", commit],
                               cwd=self.repo, capture_output=True, text=True, encoding="utf-8", errors="replace")
            if r.returncode:
                self.git("merge", "--abort", check=False)
                self.git("reset", "--hard", "HEAD", check=False)
                self._claude_mark(commit, br, "conflict", (r.stdout + r.stderr).strip()[-400:])
                log(f"claude: {br} ({commit[:8]}) does not merge cleanly onto {self.main}; skipped")
                continue
            self._claude_pre = self._claude_pre or pre
            self._claude_landed.append({"branch": br, "commit": commit})
            self._claude_mark(commit, br, "checking", self.git("rev-parse", "HEAD"))
            log(f"claude: merged {br} ({commit[:8]}) onto {self.main}; the full suite checks it alongside the cycle")

    def check_claude_alone(self) -> None:
        """The Claude merges ride the lane-merge check; with no lanes to merge they get a check of their own."""
        landed, self._claude_landed = getattr(self, "_claude_landed", []), []
        pre, self._claude_pre = getattr(self, "_claude_pre", None), None
        if not landed or self.state.get("merge_check"):
            return
        self.save(merge_check={"pre": pre, "head": self.git("rev-parse", "HEAD"), "items": [], "claude": landed,
                               "started": ts()})
        self.start_merge_check()
        log(f"claude: {len(landed)} side branch(es) merged; their full suite runs in its own worktree alongside the cycle")

    def _claude_status(self) -> dict:
        try:
            data = json.loads(self.CLAUDE_STATUS.read_text(encoding="utf-8"))
            return data if isinstance(data, dict) else {}
        except (OSError, ValueError):
            return {}

    def _claude_mark(self, commit: str, branch: str, state: str, detail: str = "") -> None:
        status = self._claude_status()
        status[commit] = {"branch": branch, "state": state, "at": ts(), "detail": detail}
        try:
            self.CLAUDE_STATUS.parent.mkdir(parents=True, exist_ok=True)
            tmp = self.CLAUDE_STATUS.with_suffix(".tmp")
            tmp.write_text(json.dumps(status, indent=1), encoding="utf-8")
            os.replace(tmp, self.CLAUDE_STATUS)
        except OSError:
            pass

    def _claude_settled(self, mc: dict, passed: bool) -> None:
        landed = mc.get("claude") or []
        for it in landed:
            if passed:
                self._claude_mark(it["commit"], it["branch"], "landed", mc["head"])
            elif mc.get("items"):   # failed together with lanes: off main now, tried again at a later cycle start
                self._claude_mark(it["commit"], it["branch"], "retry", "failed the full suite together with lanes")
            else:
                self._claude_mark(it["commit"], it["branch"], "failed", "failed the full suite on its own")
        if landed:
            log(f"claude: {len(landed)} side branch(es) {'landed' if passed else 'failed the full suite'}: "
                + ", ".join(it["branch"] for it in landed)[:200])
        if landed and passed and not mc.get("items"):
            self.save(tested_main=mc["head"])

    def begin_merge_check(self, batch: list) -> None:
        head = self.git("rev-parse", "HEAD")
        items = [{"key": key, "branch": lt["branch"], "commit": commit, "parked": parked, "lt": lt}
                 for key, lt, _lane, _pre, commit, parked in batch]
        landed, pre = getattr(self, "_claude_landed", []), getattr(self, "_claude_pre", None)
        self._claude_landed, self._claude_pre = [], None   # Claude merges sit below the lanes: undo both on a fail
        self.save(merge_check={"pre": pre or batch[0][3], "head": head, "items": items, "claude": landed,
                               "started": ts()})
        self.start_merge_check()
        log(f"lane merges: {len(items)} merged; their full suite runs in its own worktree alongside the cycle")

    def merge_check_branches(self) -> set:
        return {it.get("branch") for it in (self.state.get("merge_check") or {}).get("items") or []}

    def start_merge_check(self) -> dict:
        mc = self.state["merge_check"]
        root = Path(self.cfg.get("lane_review", {}).get("merge_check_dir", G.tmp_dir("mergecheck")))
        if (root / ".git").exists():
            self.git("-C", str(root), "checkout", "--detach", "--force", mc["head"])
            self.git("-C", str(root), "clean", "-fdx", "-e", ".godot", check=False)   # keep the import cache
        else:
            shutil.rmtree(root, ignore_errors=True)
            self.git("worktree", "prune", check=False)
            self.git("worktree", "add", "--detach", "--force", str(root), mc["head"])
        argv = [*self.cfg["test_cmd"], "--repo", root.as_posix(), "--normal-priority"]
        box: dict = {"head": mc["head"]}

        def run() -> None:
            self._tls.bg = True
            lp = CYCLES / "_lanes" / f"merge_check_{int(time.time())}.txt"
            try:
                rc, why = self.run_proc(argv, lp, int(self.cfg["timeouts"]["tests"]) + 300)
                box["result"] = (why == "exit" and rc == 0, lp)
                log(f"tests {lp.stem}: {'PASS' if box['result'][0] else 'FAIL'} ({why}, rc={rc})")
            except BaseException as e:   # noqa: BLE001 - no result: the main thread runs it again (or halts)
                log(f"lane-merge check stopped ({type(e).__name__}: {str(e)[:160]})")

        box["thread"] = threading.Thread(target=run, name="merge-check", daemon=True)
        box["thread"].start()
        self._mc_box = box
        return box

    def settle_merge_check(self, block: bool, conflict_defers: bool = True) -> None:
        mc = self.state.get("merge_check")
        if not mc:
            return
        box = getattr(self, "_mc_box", None)
        for tries in range(3):
            if box is None or box.get("head") != mc["head"] or (not box["thread"].is_alive()
                                                                and "result" not in box):
                if STOP_PATH.exists():
                    raise Halt("STOP requested")
                if tries == 2:
                    break
                log("lane merges: their full-suite check was interrupted; running it again")
                box = self.start_merge_check()
            t = box["thread"]
            if t.is_alive():
                if not block:
                    return
                log("lane merges: waiting for their full-suite check before testing this cycle")
                n = 0
                while t.is_alive():
                    t.join(5)
                    n += 1
                    if STOP_PATH.exists():
                        raise Halt("STOP requested")
                    if n % 12 == 0:
                        self.save(heartbeat=ts())
            if "result" in box:
                break
        passed, lp = box.get("result") or (False, None)
        if not passed and lp and self._slow_running() and not block:
            return   # its failures may be slow tests the slow check is about to report: judge it later
        if not passed and lp and self._only_owed_failures(lp):
            log("lane merges: their full-suite check fails only on slow tests that already fail on "
                f"{self.main} (background slow check); merging them")
            passed = True
        self._mc_box = None
        if passed:
            for it in mc["items"]:
                key, lt, parked = it["key"], it["lt"], it["parked"]
                with self._save_lock:   # early starts are held off for these branches, but read the latest entry
                    cur = self.state.get(f"{key}_task") or {}
                    hit = [x for x in self.parked(key) if x.get("branch") == it["branch"]]
                    if cur.get("branch") == it["branch"]:
                        lt, parked = cur, False
                    elif hit:
                        lt, parked = hit[0], True
                self._reapplied.pop(lt.get("branch"), None)
                self._finish_lane_merge(key, lt, self.lane2(key), it["commit"], parked, tested=mc["head"])
            self._claude_settled(mc, True)
            self.save(merge_check=None)
            return
        self._merge_check_failed(mc, lp, conflict_defers)

    def _merge_check_failed(self, mc: dict, lp, conflict_defers: bool) -> None:
        self._claude_settled(mc, False)
        titles = ", ".join(f"{it['key']} \"{it['lt'].get('title', '')}\"" for it in mc["items"])
        log(f"the {len(mc['items'])} merged lanes fail the full suite together ({lp.name if lp else 'no result'}); "
            f"taking them off {self.main}; they merge and test one at a time at the next cycle start: {titles[:300]}")
        self._note_failed_tree(self._tree(mc["head"]), lp)
        br = self.git("branch", "--show-current", check=False).strip()
        conflict = False
        if br == self.main or self.state.get("phase") == "IDLE":
            if br == self.main:
                self.git("reset", "--hard", mc["pre"])
            else:
                self.git("branch", "-f", self.main, mc["pre"])
        else:   # move this cycle's work (commits and working tree) from the merged main onto the old one
            self.git("add", "-A")
            wip = not self.git_ok("diff", "--cached", "--quiet")
            if wip:
                self.git("commit", "--no-verify", "-m", "relay: cycle work, moved off the failed lane merges")
            r = subprocess.run(["git", "rebase", "--onto", mc["pre"], mc["head"], br], cwd=self.repo,
                               capture_output=True, text=True, encoding="utf-8", errors="replace")
            if r.returncode:
                self.git("rebase", "--abort", check=False)
                conflict = True
            if wip:
                self.git("reset", "HEAD~1")
            self.git("branch", "-f", self.main, mc["pre"])
        self.save(merge_check=None, merge_sync_next=True, tested_fp=None)
        if conflict:
            log("this cycle's work does not apply without the failed lane merges")
            if conflict_defers:
                raise ScopeDeferred("this cycle was built on lane merges that failed the full suite, and its work "
                                    "does not apply without them; saved for a retry on the new main")
        else:
            log(f"this cycle continues on the old {self.main}")

    KEPT_HEAD = "## Unfinished earlier, finish it on the new main"
    KEPT_WHY = ("timed out", "did not finish within", "still making progress", "relay's time limit")

    def _keep_given_up(self, key: str, lt: dict, reason: str) -> dict:
        """Lane 2's MoodState (2026-10-18) ran 6 h: built, related test green, then its fix round timed out on a busy
        PC and the give-up deleted the branch, so only an unreachable commit was left. A given-up lane's unmerged
        work is now kept on a relay/kept/ branch with its diff saved, and work stopped only by a time limit (not by a
        defect) is requeued once to finish from that diff instead of being planned again from scratch."""
        br, d = lt.get("branch"), lt.get("dir")
        if not br:
            return {}
        try:
            own = d and Path(d).exists() and Path(d).resolve() != Path(self.repo).resolve()
            if own and self.git("-C", d, "status", "--porcelain", check=False).strip():
                self.git("-C", d, "add", "-A", check=False)
                self.git("-C", d, "commit", "--no-verify", "-m", f"relay kept {key}: {lt['title']}", check=False)
            tip = self.git("rev-parse", "--verify", "-q", br + "^{commit}", check=False).strip()
            if not tip or self.git_ok("merge-base", "--is-ancestor", tip, self.main):
                return {}
            base = self.git("merge-base", self.main, tip, check=False).strip()
            diff = self.git("diff", f"{base}..{tip}", check=False) if base else ""
            if not diff.strip():
                return {}
            kept = f"relay/kept/{key}-{int(time.time())}"
            self.git("branch", "-f", kept, tip, check=False)
            old = sorted(b.strip() for b in self.git("branch", "--list", "relay/kept/*", "--format=%(refname:short)",
                                                         check=False).splitlines() if b.strip())
            for b in old[:-20]:
                self.git("branch", "-D", b, check=False)
        except Exception:   # noqa: BLE001
            return {}
        info = {"kept_branch": kept, "kept_commit": tip}
        brief = self._first_brief(lt) if lt.get("run_dir") else ""
        if (not brief.strip() or self.KEPT_HEAD in brief or self.REDO_HEAD in brief
                or not any(w in reason for w in self.KEPT_WHY)):
            log(f"{key}: kept the unfinished work of \"{lt['title']}\" on {kept}")
            return info
        patch = Path(lt["run_dir"]) / "KEPT.patch"
        patch.parent.mkdir(parents=True, exist_ok=True)
        patch.write_bytes((diff + "\n").replace("\r\n", "\n").encode("utf-8"))   # LF: a CRLF patch never 3-way applies
        self._carry(key, lt["title"], brief.rstrip() + f"\n\n{self.KEPT_HEAD}\nThis task was already built, but the "
                    f"relay stopped it on a time limit ({reason[:160]}), not on a defect. Its unfinished work is the "
                    f"diff {patch.as_posix()} (also branch {kept}). Apply that diff to the CURRENT code first "
                    "(git apply --3way; where other coders changed the same lines since, keep both), check it "
                    "against this brief, finish only what is missing, run the related tests, then the full suite "
                    "once. Do not redesign it.\n", "unfinished work kept after a time limit")
        log(f"{key}: \"{lt['title']}\" kept on {kept} and requeued once to finish it")
        info["requeued"] = True
        return info

    def release_owed_tests(self) -> None:
        """2026-10-18: cycle 407 had to fix the owed ink-price test, but lane3 held that file (a 2-hour task to speed
        it up), so Codex was forbidden to edit it and deferred the whole cycle. The main cycle owns owed slow tests:
        at the cycle start a lane task holding one is stopped and given up, its work kept on a relay/kept/ branch."""
        owed = {f"tests/{t}" for t in self.load_slow_owed().get("tests", [])}
        if not owed:
            return
        scopes = self.active_scopes(skip="main")
        for key in self.LANE_KEYS:
            lt = self.state.get(f"{key}_task")
            held = sorted(owed & set((scopes.get(key) or {}).get("files", [])))
            if not lt or not held:
                continue
            try:
                self.lane2(key).stop(lt)
            except Exception:   # noqa: BLE001
                pass
            self.lane_give_up(key, lt, f"the main cycle must fix the owed slow test {', '.join(held)}, "
                                       "which this task held")

    def lane_give_up(self, key: str, lt: dict, reason: str) -> None:
        kept = self._keep_given_up(key, lt, reason)
        try:
            self.lane2(key).cleanup(lt)
        except Exception:
            pass
        failed = (self.state.get(f"{key}_failed") or []) + [{"title": lt["title"], "reason": reason, "at": ts(), **kept}]
        if lt.get("fix_rounds"):
            self.learn_lane_lessons(key, lt, f"was given up after {lt['fix_rounds']} fix round(s) ({reason[:200]})")
        self.save(**{f"{key}_task": None, f"{key}_failed": failed[-20:]})
        log(f"{key}: gave up on \"{lt['title']}\": {reason[:160]}")

    def start_cycle(self) -> None:
        # Godot rewrites .import files with other line endings on every import; content is identical, so
        # refresh git's stat cache before deciding the tree is dirty.
        started = ts()   # START in the timeline: waiting for background planning, lane merges, baseline tests
        self.git("update-index", "-q", "--refresh", check=False)
        if self.git("status", "--porcelain").strip():
            raise Halt("working tree is dirty; commit or stash before starting a cycle")
        self.join_bg(wait_lanes=False, swap=True)
        # 2026-10-25: a pause set while this wait ran (05:05, the plan came at 05:09) still started cycle 224;
        # the plan is prepared now and survives the halt, so honour the pause here.
        if PAUSE_PATH.exists():
            PAUSE_PATH.unlink(missing_ok=True)
            self._halting = True
            raise Halt("paused between cycles (start resumes)")
        self.git("checkout", self.main)
        self.ensure_slow_check()
        self.settle_merge_check(block=True)   # normally settled inside the previous cycle already
        self.codex_boundary()
        self.wait_reviews_for_prepared_plan()
        self.land_claude_queue()
        self.merge_lanes()
        self.check_claude_alone()
        self.release_owed_tests()
        # 2026-11-07: merging the lanes one at a time took 80 min (00:29-01:49); a pause set at 01:24 still
        # started cycle 569. Honour it again here; main is committed and the prepared plan survives the halt.
        if PAUSE_PATH.exists():
            PAUSE_PATH.unlink(missing_ok=True)
            self._halting = True
            raise Halt("paused between cycles (start resumes)")
        if self.state.get("merge_check"):
            log("baseline: the lane-merge check running alongside the cycle is this cycle's baseline")
        elif self.git("rev-parse", "HEAD") == self.state.get("tested_main"):
            log(f"baseline: {self.main} already passed the full suite at this commit; not re-running")
        else:
            passed, lp = self.run_tests(CYCLES / "_baseline", f"baseline_{int(time.time())}", excuse_owed=True)
            if not passed:
                raise Halt(f"tests are red on {self.main} before starting; see {lp}")
            self.save(tested_main=self.git("rev-parse", "HEAD"))
        n = self.state["cycle"] + 1
        br = f"relay/cycle-{n:03d}"
        if self.git_ok("rev-parse", "--verify", "--quiet", br):
            br += f"-{int(time.time())}"
        self.git("checkout", "-b", br)
        self.save(cycle=n, branch=br, phase="PLAN", attempt=0, title=None,
                  cycle_started=ts(), prev_defects=[], prev_test_fails=[], note=None, rescued=False,
                  main_scope=None, evidence_warning=None, repeated_backup_used=False, repair_exhausted=False,
                  code_art_flagged=False, code_art_left=False,
                  last_repair_builder=None, last_coder=None, ownership_replan_used=False, ownership_replans=0, ownership_replan_reason='', timeline=[["START", started]])
        (self.cyc / "logs").mkdir(parents=True, exist_ok=True)
        log(f"=== cycle {n:03d} started on {br} ===")
        # Retained test-ready lanes must receive review even when main planning is slow/blocked.
        self.start_lane_checker()
        others = foreign_agents((self.state.get(f"{k}_task") or {}).get("pid") for k in self.LANE_KEYS)
        if others:
            log(f"warning: other OpenCode processes are running and may edit the repo: {others}")
            notify(f"{G.NAME} relay warning", "Another OpenCode is running; close it so it can't edit the repo.")

    def do_plan(self) -> None:
        hist = "\n".join(f"- {h['cycle']:03d} {h['title']} ({h['commit']})"
                         for h in self.state["history"][-10:]) or "- none"
        completed_lanes = [h for key in self.LANE_KEYS for h in (self.state.get(key + '_history') or [])]
        if completed_lanes:
            recent_lanes = sorted(completed_lanes, key=lambda h: h.get('at', ''))[-12:]
            hist += '\nRecently merged parallel work (already complete; do not repeat unchanged):\n' + '\n'.join(
                f"- {h['title']} ({h.get('commit', '?')})" for h in recent_lanes)
        if self.fast_cycles():
            timings = [h for h in self.state['history'][-5:] if 'active_minutes' in h]
            if timings:
                hist += '\nRecent active cycle times (choose smaller useful work after overruns):\n' + '\n'.join(
                    f"- {h['cycle']:03d}: {h.get('build_minutes', h['active_minutes']):.1f} minutes building, "
                    f"{h.get('fix_attempts', 0)} repairs; target {'met' if h.get('target_met') else 'missed'}"
                    for h in timings)
        if self.state.get("pending_audits"):
            self.collect_cloud_audits()
        if self.state.get("pending_workflow"):
            self.collect_workflow_reviews()
        owed = self.load_slow_owed()
        if owed:
            hist += (f"\nOWED SLOW TESTS: the relay's background slow check found {', '.join(owed['tests'])} failing "
                     f"on {self.main} ({str(owed.get('commit', '?'))[:8]}, cycle {owed.get('cycle', '?')}). This "
                     "cycle's suite runs them and cannot be accepted until they pass: plan their fix first (with a "
                     "small task, or as the whole task).")
        failed = self.state.get("failed") or []
        if failed:
            hist += ("\nRecently FAILED cycles (parked, not merged). Do not retry one unchanged: choose a "
                     "smaller slice or a different approach, and avoid what the reason describes:\n"
                     + "\n".join(f"- {f['cycle']:03d} {f['title']} -> {f['branch']}: {f['reason'][:200]}"
                                  for f in failed[-5:]))
        deferred = self.state.get('deferred') or []
        if deferred:
            # 2026-10-18: cycle 411 re-planned 407's Stress relief from scratch although 407's work was saved and
            # only a since-fixed test had blocked it; name the saved commit so a plan lands it instead.
            hist += ('\nDEFERRED tasks (saved, not accepted; choose other authorized work or a smaller slice '
                     'avoiding this decision, never retry unchanged). If you plan one again because its blocker '
                     'is gone (for example an owed or failing test since fixed on main), the brief must tell the '
                     'coder to cherry-pick its saved commit and finish it, never to rebuild it:\n' + '\n'.join(
                         f"- {d['cycle']:03d} {d['title']} (saved commit {str(d.get('commit', '?'))[:8]} on "
                         f"{d.get('branch', '?')}): {d['reason']}" for d in deferred[-5:]))
        flaky = load_json(HERE / "flaky_tests.json", {})
        recent = (datetime.datetime.now() - datetime.timedelta(days=3)).strftime("%Y-%m-%d %H:%M:%S")
        flaky = {k: v for k, v in flaky.items() if v.get("last", "") >= recent}
        if flaky:
            hist += ("\nFLAKY tests (failed, then passed unchanged on retry; nondeterminism is a bug, fixing it "
                     f"is a high-priority small task; failure output in {HERE / 'flaky_tests.json'}):\n"
                     + "\n".join(f"- {k}: {v['count']}x, last {v['last']}" for k, v in flaky.items()))
        for k in self.LANE_KEYS:
            lt = self.state.get(f"{k}_task")
            if lt:
                hist += (f"\n{k} (parallel lane, {self.cfg.get(k, {}).get('label', k)}) is currently working on: {lt.get('title')}. "
                         "Do not plan changes to the same files or feature.")
        ct = self.state.get("codex_task")
        if ct:
            hist += (f"\nCodex lane (parallel builder) is currently working on: {ct.get('title')}. "
                     "Do not plan changes to the same files or feature.")
        done_codex = self.state.get("codex_history") or []
        if done_codex:
            hist += "\nRecently merged Codex-lane work:\n" + "\n".join(
                f"- {h['title']} ({h['commit']})" for h in done_codex[-5:])
        playtests = sorted((HERE / "playtests").glob("PLAYTEST_*.md"))
        if playtests:
            hist += (f"\nLatest visual playtest report (screenshots of the exported Web build; read it and the "
                     f"screenshots it cites before choosing; its blockers rank with audit blockers): {playtests[-1]}")
        audits = sorted((HERE / "audits").glob("AUDIT_*.md"))
        if audits:
            hist += ("\nMilestone audit reports (read the newest before choosing; its release "
                     "blockers and next tasks take priority):\n" + "\n".join(f"- {a}" for a in audits))
        snapshot = self.planning_snapshot() if self.queue_enabled() else {}
        out = self.take_prepared_plan()
        prepared = out is not None
        if out is None:
            out = self.think(self.plan_template().substitute(
                repo=self.repo, branch=self.state["branch"], main=self.main, cycle=self.state["cycle"],
                last_good=self.state["last_good_commit"] or "none",
                history=hist + P.live_board_note() + self.unwired_note() + (f"\nPrevious proposal(s) were not ready: {self.state['ownership_replan_reason']}. "
                                "Those files/features are owned by running lanes: choose a different feature that "
                                "touches none of them (not a variant of the same task)."
                                if self.state.get('ownership_replan_used') else ''))
                + self.lane_plan_section(self.idle_lanes()), "PLAN")
        if self.queue_enabled():
            main_text = re.sub(r'@@LANE_[a-z0-9]+_START@@.*?@@LANE_[a-z0-9]+_END@@', '', out, flags=re.S)
            title_match = re.search(r'^TITLE:\s*(.+)$', out, re.M)
            if not title_match or title_match.group(1).strip().upper() != 'NONE':
                try:
                    contract = TP.scope(main_text, title_match.group(1).strip() if title_match else '')
                    if not contract.get('explicit'):
                        raise ValueError('main plan requires TASK_SCOPE')
                    manifest = self.ready_manifest(main_text, contract['feature'], snapshot)
                    problem = self.ready_problem(manifest, 'main')
                    if problem:
                        raise ValueError(problem)
                except ValueError as e:
                    # Owner 2026-10-10: a clash with a lane's files re-plans (up to max_ownership_replans) instead
                    # of failing the cycle (cycle 108 failed on its second clash).
                    tries = int(self.state.get('ownership_replans')
                                or (1 if self.state.get('ownership_replan_used') else 0))
                    if tries < int(self.cfg.get('task_queue', {}).get('max_ownership_replans', 3)):
                        write(self.cyc / f'PLAN_NOT_READY_{tries + 1}.md', out + f'\n\nController revalidation: {e}\n')
                        prev = self.state.get('ownership_replan_reason') if tries else ''
                        self.save(ownership_replan_used=True, ownership_replans=tries + 1,
                                  ownership_replan_reason=(f'{prev}; {e}' if prev else str(e))[-1500:],
                                  note='plan changed or conflicts with ownership; replanning before coding')
                        log(f'plan not ready ({e}); replanning ({tries + 1}) without consuming a coding attempt')
                        return
                    raise AgentFailed(f'plan ownership is not ready: {e}') from e
                self.save(main_scope=contract)
        m = re.search(r"^TITLE:\s*(.+)$", out, re.M)
        title = m.group(1).strip() if m else "untitled"
        mm = re.search(r"^MILESTONE:\s*(M\d{2}(?:\.\d+)?[A-Z]?)", out, re.M)
        milestone = mm.group(1) if mm else milestone_of(title)
        if title.upper() == "NONE":
            self.git("checkout", self.main)
            self.git("branch", "-D", self.state["branch"], check=False)
            # 2026-10-21: cycle 053's planner answered NONE only because lanes held every file it wanted, and the
            # whole relay halted. With lanes running that means "nothing free yet": wait for one to become
            # mergeable, then start the cycle again (start_cycle merges it) and replan.
            busy = self.busy_lane_titles()
            if busy:
                write(self.cyc / "PLAN_NONE_WAIT.md", out)
                self.save(cycle=self.state["cycle"] - 1, phase="IDLE",
                          note="planner found no task free of the running lanes; waiting for a lane")
                log(f"planner found no task free of the running lanes ({'; '.join(busy)[:300]}); waiting for "
                    "a lane to finish, then replanning")
                self.wait_lane_progress()
                return
            self.save(phase="IDLE", note="planner reported no further work")
            raise Halt("planner reported no further work")
        plan = extract(out, "PLAN")
        if not plan:
            raise AgentFailed("plan output missing @@PLAN@@ markers")
        write(self.cyc / "CLAUDE_PLAN.md", f"# {title}\n\n{plan}\n")
        prev_ms = self.last_milestone()
        assets = []
        if self.cfg.get("art", {}).get("enabled"):
            from art_gen import parse_assets
            assets = parse_assets(out)[: int(self.cfg["art"].get("max_per_cycle", 6))]
            if assets:
                write(self.cyc / "ASSET_REQUESTS.json", json.dumps(assets, indent=2))
        plan_brief = extract(out, "BRIEF") or ""
        pb = len(plan_brief.strip()) > 200 and self.cfg["chatgpt"].get("plan_brief", True)
        if pb:
            write(self.cyc / "DEEPSEEK_BRIEF.md", plan_brief.strip() + (self.merged_prev_note() if prepared else "")
                  + self.art_note(assets) + self.owed_note() + self.hard_rules("DEEPSEEK_REPORT_0.md"))
        bg = bool(assets) and self.cfg.get("art", {}).get("parallel", True)
        self.save(phase="ART" if assets and not bg else "BRIEF", title=title, milestone=milestone, assets=assets,
                  plan_brief=pb, art_bg=bg, art_pid=None)
        log(f"plan: {title} [{milestone or '?'}]" + (" (brief included)" if pb else ""))
        if bg:
            self.start_art_bg()
        # Owner 2026-10-10: the milestone audit ran on the critical path (cycle 113 waited 8.6 min); run it beside
        # the build. Its report is read by later plans.
        def audit_bg(prev=prev_ms, cur=milestone) -> None:
            self._tls.bg = True
            try:
                self.maybe_audit(prev, cur)
            except Exception as e:   # noqa: BLE001 - an audit must never stop the relay
                log(f"audit not finished: {type(e).__name__}: {str(e)[:200]}")
            finally:
                try:
                    self._tls.bridge and self._tls.bridge.disconnect()
                except Exception:   # noqa: BLE001
                    pass
        if prev_ms and milestone and prev_ms != milestone:
            threading.Thread(target=audit_bg, name=f"audit-{prev_ms}", daemon=True).start()
        try:
            self.maybe_workflow_review(prev_ms, milestone)
        except Exception as e:   # noqa: BLE001 - a review problem must never stop the cycle
            log(f"workflow review not started: {type(e).__name__}: {str(e)[:200]}")
        lane_tasks = self.parse_lane_tasks(out)
        self.enqueue_lanes(lane_tasks, snapshot)
        self.start_bg_planning(hist, lane_tasks)
        self.start_lane_checker()

    # ---- background planning (lanes + next cycle's plan) while this cycle builds

    def task_scope(self, key: str, task: dict) -> dict:
        if task.get('scope'):
            return task['scope']
        source = (self.cyc / 'DEEPSEEK_BRIEF.md' if key == 'main'
                  else Path(task.get('run_dir') or HERE) / 'BRIEF.md')
        try:
            return TP.scope(read(source), task.get('title', ''))
        except ValueError:
            return {'feature': task.get('title', ''), 'files': [], 'depends_on': []}

    def unwired_features(self) -> list[str]:
        """Game scripts that nothing in the game references (only tests): merged features a player cannot reach.
        Owner 2026-10-11: 33 of 88 new M08E/expansion scripts were test-only (lanes build isolated modules because
        the core files are owned by others)."""
        root = Path(self.repo)
        skip = {"tests", ".godot", ".review", ".lanes", ".git", "addons"}
        texts = {}
        for p in root.rglob("*"):
            if (p.is_file() and (p.suffix in (".gd", ".tscn", ".tres") or p.name == "project.godot")
                    and not skip.intersection(p.relative_to(root).parts)):
                try:
                    texts[p] = p.read_text(encoding="utf-8", errors="ignore")
                except OSError:
                    pass
        out = []
        for f in sorted(root.glob("scripts/**/*.gd")):
            m = re.search(r"^class_name\s+(\w+)", texts.get(f, ""), re.M)
            keys = [f.name] + ([m.group(1)] if m else [])
            if not any(p != f and any(k in tx for k in keys) for p, tx in texts.items()):
                out.append(f.relative_to(root).as_posix())
        return out

    def unwired_note(self, for_lanes: bool = False) -> str:
        try:
            un = self.unwired_features()
        except Exception as e:   # noqa: BLE001 - planning context only
            log(f"unwired check failed: {type(e).__name__}: {str(e)[:120]}")
            return ""
        if not un:
            return ""
        if for_lanes:
            # Lanes kept adding isolated modules faster than main could wire them (35 -> 39 in one cycle).
            return ("\nUNWIRED FEATURES (owner 2026-10-11): these merged scripts are used only by tests, so players "
                    f"cannot reach them ({len(un)}): " + ", ".join(un[:60]) + ". PREFER a lane task that wires one of "
                    "them (or a related group) into real play through files no other coder reserves (live board), "
                    "with a test through the real game path, over building another isolated module. Editing only "
                    "the unwired script and its own test is NOT wiring: a wiring task changes a file the real game "
                    "loads (scene, UI, session, run flow or a registry they read). If a new "
                    "feature cannot be wired from free files, keep it small and name the exact wiring step needed. "
                    "Never answer NONE just because wiring is blocked by reserved files (cycle 157 idled three lanes "
                    "that way): give the lane its best small task inside its focus area instead (a data entry, "
                    "catalog item, rule resource or test that uses only free files).\n")
        write(self.cyc / "UNWIRED_FEATURES.md", "\n".join(f"- {u}" for u in un) + "\n")
        groups = self._unwired_groups(un)
        group_txt = ("" if not groups else " Same-kind groups: " + "; ".join(f"{g} ({c})" for g, c in groups)
                     + ". For a group, prefer ONE task that adds a small data-driven dispatcher/registry in the real "
                     "game path and wires the whole group, so later lanes can wire new ones through data alone.")
        stalled = self._unwired_stalled(len(un))
        head = ("MANDATORY THIS CYCLE: the count has not dropped for 2 accepted main cycles, so this main task MUST "
                "wire some of them into real play (the plan is wrong otherwise)" if stalled
                # 2026-10-24: lanes kept adding test-only modules, so wiring them outranked the owner's playtest
                # order every cycle (166/168/169/172). The open OWNER ORDER step (OWNER_ORDER.md) goes first now;
                # the stall rule above still forces a wiring cycle when the count stops dropping.
                else "after the open OWNER ORDER step (OWNER_ORDER.md); when that step is open, plan it instead and "
                     "leave these to lanes or a later cycle")
        return (f"\nUNWIRED FEATURES (owner 2026-10-11, {head}): these merged scripts are used "
                f"only by tests, so players cannot reach them yet ({len(un)}): " + ", ".join(un[:60])
                + ". The main cycle owns the core gameplay, UI and hub files, so it should wire a "
                "few RELATED ones into real play per cycle (e.g. all hand spell casts into the live hand) with tests "
                "through the real game path, before building new isolated features." + group_txt + "\n")

    def _unwired_count(self):
        try:
            return len(self.unwired_features())
        except Exception:   # noqa: BLE001 - history detail only
            return None

    def _unwired_stalled(self, now: int) -> bool:
        """True when the last 2 accepted main cycles recorded counts and none of them went below the older one."""
        counts = [h["unwired"] for h in (self.state.get("history") or []) if isinstance(h.get("unwired"), int)][-2:]
        # 2026-10-24: 0 -> 1 -> 3 counted as a stall and forced cycle 172 off the owner order for one lane module;
        # a handful of fresh lane modules is lane work, so only a real backlog forces a main wiring cycle.
        return len(counts) == 2 and now >= counts[0] and now >= UNWIRED_FORCE_MIN

    @staticmethod
    def _unwired_groups(un: list) -> list:
        """Groups of 3+ unwired scripts sharing a dir and a name pattern (e.g. scripts/cards/m08e_*_hand_cast.gd)."""
        from collections import Counter
        keys = Counter()
        for u in un:
            d, _, name = u.rpartition("/")
            stem = name[:-3] if name.endswith(".gd") else name
            parts = stem.split("_")
            if len(parts) >= 3:
                keys[f"{d}/{parts[0]}_*_{'_'.join(parts[-2:])}.gd"] += 1
            keys[f"{d}/*_{parts[-1]}.gd"] += 1
        best, seen = [], set()
        for k, c in keys.most_common():
            if c < 3:
                break
            members = frozenset(u for u in un if fnmatch.fnmatch(u, k))
            if members and not any(members <= s for s in seen):
                best.append((k, c))
                seen.add(members)
            if len(best) >= 4:
                break
        return best

    def refresh_common_title_words(self) -> None:
        """Words that repeat across many recent task titles are templates, not features (the duplicate check
        blocked every 'Cast X from a paid locked hand' spell task as one feature, 2026-10-11)."""
        titles = [h.get('title', '') for h in (self.state.get('history') or [])[-40:]]
        for k in self.LANE_KEYS:
            titles += [h.get('title', '') for h in (self.state.get(f'{k}_history') or [])[-15:]]
            titles += [h.get('title', '') for h in (self.state.get(f'{k}_failed') or [])[-5:]]
        TP.set_common_titles(titles)

    def active_scopes(self, skip: str = '') -> dict:
        self.refresh_common_title_words()
        active = {}
        if skip != 'main' and self.state.get('phase') not in ('IDLE', 'PLAN'):
            active['main'] = self.state.get('main_scope') or self.task_scope('main', self.state)
            changed = self.git('diff', '--name-only', 'HEAD', check=False).splitlines()
            changed += self.git('ls-files', '--others', '--exclude-standard', check=False).splitlines()
            active['main'] = {**active['main'], 'files': sorted(set(active['main'].get('files', []) + changed)),
                              'title': self.state.get('title', '')}
        merged = self.merge_check_branches()   # already on main; only their suite check is pending
        for key in (*self.LANE_KEYS, 'codex'):
            task = self.state.get(f'{key}_task')
            if key != skip and task and task.get('branch') not in merged:
                active[key] = {**self.task_scope(key, task), 'title': task.get('title', '')}
                # Account for actual supporting edits not in the initial reservation.
                if task.get('dir'):
                    # Compare with this lane's actual fork point. A moving main contains unrelated
                    # accepted work absent from the older lane; a two-way diff falsely reserves it.
                    changed = self._lane_changed_files(task['dir'])
                    changed += self.git('-C', task['dir'], 'ls-files', '--others', '--exclude-standard',
                                        check=False).splitlines()
                    active[key] = {**active[key], 'files': sorted(set(active[key].get('files', []) + changed))}
        active.update(self._parked_scopes(skip))   # accepted work waiting for the cycle-start merge
        # Owner 2026-10-10: lanes yield to the prepared NEXT main plan (the critical path).
        if skip in self.LANE_KEYS and (nm := self.next_main_scope()):
            active['next-main'] = nm
        # 2026-10-18: owed slow tests belong to the main cycle (cycle 407 deferred while lane3 held one).
        if skip in self.LANE_KEYS and (owed := self.load_slow_owed()):
            active['owed'] = {'files': [f"tests/{t}" for t in owed['tests']], 'reads': [],
                              'title': 'owed slow tests (the main cycle fixes them)'}
        return active

    def _lane_changed_files(self, d: str) -> list:
        """Files the lane itself changed since its fork from main. 2026-10-19: once an early-started lane's accepted
        task merged at cycle 419's start, the lane and main had two merge bases (the accepted lane commit and the old
        master in the early-start base); plain merge-base picked the lane commit, so the lane suddenly 'held' 38
        master files (lane7's friction readout test among them) and the prepared plan was thrown away. Only files
        that differ from every merge base are the lane's own."""
        bases = self.git('-C', d, 'merge-base', '-a', self.main, 'HEAD', check=False).split() or [self.main]
        sets = [set(self.git('-C', d, 'diff', '--name-only', b, check=False).splitlines()) for b in bases]
        return sorted(set.intersection(*sets))

    def next_main_scope(self) -> dict:
        meta = load_json(HERE / 'prepared' / f"plan_{int(self.state.get('cycle', 0)) + 1:03d}.json", {})
        return meta['scope'] if isinstance(meta, dict) and (meta.get('scope') or {}).get('files') else {}

    def queue_enabled(self) -> bool:
        return bool(self.cfg.get('task_queue', {}).get('enabled', False))

    def fast_cycles(self) -> bool:
        return bool(self.cfg.get('cycle_budget', {}).get('enabled', False))

    def plan_template(self):
        return P.PLAN_FAST if self.fast_cycles() else P.PLAN

    def planning_snapshot(self) -> dict:
        # Capture BEFORE planning so an edit made while the reply is generated cannot silently become the baseline.
        paths = set(self.git('ls-files', check=False).splitlines())
        paths |= set(self.git('ls-files', '--others', '--exclude-standard', check=False).splitlines())
        paths |= {p.relative_to(self.repo).as_posix() for p in (HERE.parent / 'full_game').glob('*.md')}
        root = self.repo.resolve()
        result = {}
        for name in sorted(paths):
            p = (root / name).resolve()
            if p.is_relative_to(root) and p.is_file():
                result[name] = hashlib.sha256(p.read_bytes()).hexdigest()
        return result

    def ready_manifest(self, text: str, title: str, snapshot: dict) -> dict:
        contract = TP.scope(text, title)
        if not contract.get('explicit'):
            raise ValueError('ready tasks require an explicit TASK_SCOPE with concrete files and dependencies')
        paths = contract['files'] + contract['depends_on']
        # Owner 2026-10-16: the snapshot lists tracked and untracked files but not git-ignored ones, so a plan that
        # read tests/m09_crucible_zero_training_opening_test.gd (listed in .git/info/exclude) recorded None for it
        # and never matched the file on disk: cycle 332 spent a 6-min refresh and an 18-min replan on a plan
        # nothing had changed. Ignored files the plan names are hashed now; everything else keeps the snapshot.
        missing = [q for q in paths if q not in snapshot]
        ignored = set(self.git('check-ignore', '--', *missing, check=False).splitlines()) if missing else set()
        now = TP.fingerprints(self.repo, {'files': sorted(ignored & set(missing))}) if ignored else {}
        return {'version': 2, 'scope': contract,
                'fingerprints': {q: now[q] if q in now else snapshot.get(q) for q in paths},
                'queued_at': time.time(), 'planning_profile': 'fast-v1' if self.fast_cycles() else 'standard'}

    def ready_problem(self, manifest: dict, skip: str) -> str | None:
        if manifest.get('version') != 2 or not manifest.get('scope', {}).get('explicit'):
            return 'legacy task has no revalidatable ownership contract'
        overlap = TP.conflict(manifest['scope'], self.active_scopes(skip))
        if overlap:
            return overlap
        if manifest.get('fingerprints') != TP.fingerprints(self.repo, manifest['scope']):
            return 'task files or declared dependencies changed since planning'
        return None

    def queue_event(self, key: str, title: str, result: str, reason: str = '') -> None:
        d = HERE / 'prepared'
        d.mkdir(exist_ok=True)
        with self._save_lock:
            with (d / 'TASK_QUEUE_EVENTS.jsonl').open('a', encoding='utf-8') as f:
                f.write(json.dumps({'at': ts(), 'lane': key, 'title': title,
                                    'result': result, 'reason': reason}) + '\n')

    def enqueue_lanes(self, tasks: dict, snapshot: dict) -> None:
        if not self.queue_enabled():
            return
        path = HERE / 'prepared' / 'lane_queue.json'
        with self._save_lock:
            pending = load_json(path, {})
            for key, (title, brief) in tasks.items():
                if key not in self.LANE_KEYS:
                    continue
                try:
                    meta = self.ready_manifest(brief, title, snapshot)
                except ValueError as e:
                    self.queue_event(key, title, 'REJECTED', str(e))
                    continue
                pending[key] = {**meta, 'title': title, 'brief': brief}
                self.queue_event(key, title, 'QUEUED')
            # One queued task per enabled lane plus one prefetched main task: bounded, not an expanding backlog.
            pending = {k: v for k, v in pending.items() if k in self.LANE_KEYS and self.cfg.get(k, {}).get('enabled')}
            save_json(path, pending)

    def _carry(self, key: str, title: str, brief: str, why: str) -> None:
        """Owner 2026-10-12: requeued work (an accepted diff to redo, a task cut off by a usage limit) used to go into
        the lane's ONE queue slot, where the next requeue or lane plan overwrote it: Water Damage's accepted redo was
        replaced by Brittle's 1 s later and main rebuilt it from scratch; Gloam Ague's went stale. It now waits in
        its own list until a lane is free to take it."""
        with self._save_lock:
            items = [c for c in load_json((HERE / 'prepared' / 'carry_queue.json'), []) if c.get('title') != title]
            items.append({'lane': key, 'title': title, 'brief': brief, 'why': why, 'queued_at': time.time()})
            (HERE / 'prepared' / 'carry_queue.json').parent.mkdir(exist_ok=True)
            save_json((HERE / 'prepared' / 'carry_queue.json'), items[-12:])
        self.queue_event(key, title, 'CARRIED', why)

    def _take_carry(self, key: str) -> tuple[str, str] | None:
        """The oldest carried task this lane can start now: its own first, then any other lane's; one whose files an
        active task holds waits. Dropped after a day. 2026-10-25: never another AREA's task (lane8's usage-limited
        Tinker hero cards went to lane3, the ENEMIES lane, while lane2 owns hero cards)."""
        with self._save_lock:
            items = load_json((HERE / 'prepared' / 'carry_queue.json'), [])
            if not items:
                return None
            keep = [c for c in items if time.time() - queued_time(c) < 86400]
            for c in items:
                if c not in keep:
                    self.queue_event(c.get('lane', key), c.get('title', ''), 'STALE', 'carried for over a day')
            active, pick = self.active_scopes(key), None
            for c in sorted(keep, key=lambda c: (c.get('lane') != key, queued_time(c))):
                if self.other_area(key, c.get('lane', key)):
                    continue
                try:
                    clash = TP.conflict(TP.scope(c['brief'], c['title']), active)
                except (ValueError, KeyError):
                    clash = None
                if not clash:
                    pick = c
                    break
            if pick:
                keep.remove(pick)
            if keep != items:
                save_json((HERE / 'prepared' / 'carry_queue.json'), keep)
        if not pick:
            return None
        self.queue_event(key, pick['title'], 'DISPATCHED', f"carried ({pick.get('why', '')})")
        self.__dict__.setdefault('_dispatched_carries', {})[pick['title']] = pick
        return pick['title'], pick['brief']

    def other_area(self, key: str, owner: str) -> bool:
        """True when both lanes own an area (relay.json laneN.area) and the areas differ."""
        a, b = (self.cfg.get(k, {}).get('area') for k in (key, owner))
        return bool(a and b and a != b)

    def _return_carry(self, title: str) -> bool:
        """2026-10-19: every idle lane dequeues before any starts, so a carry can pass _take_carry's clash check and
        then hit a task started a moment earlier in the same refill. The Ragged Nerves carry was DISPATCHED to lane7,
        BLOCKED 8 s later by lane2's new task, and lost. A blocked carry goes back in the queue unchanged."""
        pick = (getattr(self, '_dispatched_carries', None) or {}).pop(title, None)
        if not pick:
            return False
        with self._save_lock:
            items = [c for c in load_json((HERE / 'prepared' / 'carry_queue.json'), []) if c.get('title') != title]
            save_json((HERE / 'prepared' / 'carry_queue.json'), [pick] + items)
        self.queue_event(pick.get('lane', ''), title, 'CARRIED', 'blocked at start; back in the queue')
        return True

    def has_carry(self) -> bool:
        return bool(load_json((HERE / 'prepared' / 'carry_queue.json'), []))

    def dequeue_lane(self, key: str) -> tuple[str, str] | None:
        # Carried work first, but never stacked on this lane's own unmerged work (it would fall with it).
        if not self.parked(key) and (carried := self._take_carry(key)):
            return carried
        path = HERE / 'prepared' / 'lane_queue.json'
        with self._save_lock:
            pending = load_json(path, {})
            task = pending.pop(key, None)
            if not task:
                return None
            save_json(path, pending)
            problem = self.ready_problem(task, key)
            if problem:
                self.queue_event(key, task['title'], 'STALE', problem)
                return None
            self.queue_event(key, task['title'], 'DISPATCHED')
            return task['title'], task['brief']

    def busy_lane_titles(self) -> list[str]:
        busy = [f"{k}: {self.state[f'{k}_task'].get('title', '?')}" for k in self.LANE_KEYS if self.state.get(f"{k}_task")]
        if self.state.get("codex_task"):
            busy.append(f"codex: {self.state['codex_task'].get('title', '?')}")
        return busy

    def wait_lane_progress(self) -> None:
        """Sleep until a lane is mergeable, given up or gone (or a pause/patch is waiting), at most
        task_queue.none_wait_max_s; the caller then starts the next cycle, which merges it."""
        def mark():
            out = []
            for k in self.LANE_KEYS + ("codex",):
                lt = self.state.get(f"{k}_task") or {}
                ready = bool(lt.get("give_up")) or (lt.get("review") or {}).get("verdict") == "ACCEPTED"
                out.append((k, lt.get("title"), ready))
            return out
        start, first = time.time(), mark()
        limit = float(self.cfg.get("task_queue", {}).get("none_wait_max_s", 2400))
        while time.time() - start < limit:
            sleep_checked(30)
            now = mark()
            if now != first or any(r for _, _, r in now) or PAUSE_PATH.exists() or self.pending_patch():
                break
        log(f"lane wait over after {int(time.time() - start) // 60} min; starting the cycle again")

    def idle_lanes(self) -> list[str]:
        return [k for k in self.LANE_KEYS
                if self.cfg.get(k, {}).get("enabled") and not self.state.get(f"{k}_task")]

    def lane_plan_section(self, keys: list[str], note: str = "", force: bool = False) -> str:
        if not keys or not (force or self.cfg["chatgpt"].get("plan_lanes_in_plan", True)):
            return ""
        done, failed = list(self.state.get("codex_history") or []), []
        for k in self.LANE_KEYS:
            done += self.state.get(f"{k}_history") or []
            failed += self.planning_blockers(k)
        failed += self.planning_blockers('codex')
        return P.LANES_SECTION.substitute(
            note=note,
            # Owner 2026-10-25 ("There were clashes because the lanes did the same thing"): five lanes shared one
            # generic focus and were planned the same features (two Peddler tasks, two event batches). Each lane now
            # owns one AREA of the game (relay.json laneN.area) and is planned only inside it.
            lanes="\n".join(f"- lane id {k}: {self.cfg[k].get('label', k)}"
                            + (f" - {self.cfg[k]['plan_hint']}" if self.cfg[k].get('plan_hint') else '')
                            + (f"\n  AREA (only this lane works here): {self.cfg[k]['area']}" if self.cfg[k].get('area') else '')
                            for k in keys) + (P.LANE_AREAS_RULE if any(self.cfg[k].get('area') for k in keys) else ''),
            busy=self.busy_elsewhere("") + P.live_board_note() + self.unwired_note(for_lanes=True),
            recent="\n".join(f"- {h['title']}" for h in done[-12:]) or "- none",
            failed="\n".join(f"- {f['title']}: {f['reason'][:160]}" for f in failed[-6:]) or "- none")

    # Owner 2026-11-07 ("speed it up"): lane8 re-coded "Add three candle-and-fray doll-house roadside bargains" for
    # 50 min, 5 h after that title merged (the planner sees only the last 12 finished titles).
    def _title_on_main(self, title: str) -> bool:
        def norm(s: str) -> str:
            return re.sub(r"[^a-z0-9]+", " ", s.lower()).strip()
        want = norm(title)
        if len(want) < 12:
            return False
        try:
            subjects = self.git("log", "-400", "--format=%s", self.main, check=False)
        except Exception:   # noqa: BLE001 - a planning filter only
            return False
        return any(norm(s).endswith(want) for s in subjects.splitlines())

    def parse_lane_tasks(self, out: str) -> dict:
        tasks = {}
        for k in self.LANE_KEYS:
            block = extract(out or "", f"LANE_{k}")
            if not block:
                continue
            m = re.search(r"^TITLE:\s*(.+)$", block, re.M)
            title = m.group(1).strip() if m else ""
            task = re.sub(r"^TITLE:.*$\n?", "", block, count=1, flags=re.M).strip()
            if title and title.upper() != "NONE" and task:
                if BANNED_LANE_TITLE_RE.search(title):
                    log(f'{k}: dropped planned task "{title}": no more encounter/Fight authoring (BUILD ORDER v2)')
                    continue
                if self._title_on_main(title):
                    log(f'{k}: dropped planned task "{title}": a commit with this title is already on {self.main}')
                    continue
                tasks[k] = (title, task)
        if tasks:
            write(self.cyc / "LANE_TASKS.md", "\n\n".join(f"## {k}: {t}\n\n{b}" for k, (t, b) in tasks.items()))
        return tasks

    def launch_lanes(self, tasks: dict) -> None:
        self._launch_lanes_once(tasks)
        # Owner 2026-10-10: lanes left idle (no task, or a parallel planner picked files another task now owns) get
        # ONE quick replan with the now-known ownership instead of idling a whole cycle (cycle 112: 3 of 6 idle).
        idle = self.idle_lanes()
        if idle and self.cfg["chatgpt"].get("replan_idle_lanes", True) and not STOP_PATH.exists():
            log(f"lanes: replanning idle lanes once ({', '.join(idle)})")
            self._launch_lanes_once({})

    def _launch_lanes_once(self, tasks: dict) -> None:
        """Start every idle lane on its task from the planning reply; lanes it left out are planned together in ONE
        extra ChatGPT message (was one message per lane, run back to back: ~6.5 min each, 2026-10-08)."""
        idle = self.idle_lanes()
        if self.queue_enabled():
            tasks = {k: task for k in idle if (task := self.dequeue_lane(k)) is not None}

        def start(keys: list[str], ready: dict) -> None:
            if getattr(self, "_halting", False) or STOP_PATH.exists():
                # The relay is pausing: keep the planned tasks queued for the restart instead of starting lanes.
                self.enqueue_lanes({k: ready[k] for k in keys if k in ready}, self.planning_snapshot())
                return
            for k in keys:
                try:
                    if k in ready:
                        self.start_lane_task(k, *ready[k])
                    else:
                        log(f"{k}: the plan had no task for this lane; idle this cycle")
                except Exception as e:   # noqa: BLE001 - one lane must not stop the others
                    log(f"{k}: launch error {type(e).__name__}: {str(e)[:200]}")

        # Owner 2026-10-10: ready (queued / prefetched) tasks start at once; planning the other lanes used to hold
        # them back for 17+ min (cycle 116). Started lanes then show on the live board for those planners.
        start([k for k in idle if k in tasks], tasks)
        missing = [k for k in idle if k not in tasks]
        if missing and self.cfg["chatgpt"].get("lane_plan_fallback", False):
            planned = self.plan_lanes(missing)
            if self.queue_enabled():
                planned = {k: q for k in missing if (q := self.dequeue_lane(k)) is not None}
            start(missing, planned)
        else:
            start(missing, {})

    def plan_lanes(self, keys: list[str]) -> dict:
        """Owner 2026-10-10: with chatgpt.parallel_lane_plans, one ChatGPT planner per builder group (DeepSeek /
        Codex / ChatGPT lanes) plans at the same time, each in its own focus area (lane plan_focus) so the groups
        do not pick overlapping work; the controller still revalidates ownership before any task starts."""
        groups: dict[str, list[str]] = {}
        for k in keys:
            groups.setdefault(self.cfg.get(k, {}).get('builder', 'deepseek'), []).append(k)
        if not (self.cfg['chatgpt'].get('parallel_lane_plans') and len(groups) > 1):
            return self._plan_lane_group(keys, 'LANESPLAN')
        snapshot = self.planning_snapshot() if self.queue_enabled() else {}
        focus = {g: next((self.cfg[k]['plan_focus'] for k in ks if self.cfg[k].get('plan_focus')), '')
                 for g, ks in groups.items()}
        results: dict = {}

        def run(g: str, ks: list[str]) -> None:
            self._tls.bg = True
            others = "; ".join(f"lanes {', '.join(o)} ({og}){': ' + focus[og] if focus[og] else ''}"
                               for og, o in groups.items() if og != g)
            note = (f"\nPARALLEL PLANNERS: other ChatGPT planners are planning, at this moment, the tasks for {others}. "
                    + (f"Your lanes' focus area: {focus[g]}. Stay inside it so your tasks cannot overlap theirs.\n"
                       if focus[g] else "Choose work clearly separate from theirs.\n"))
            try:
                got = self._plan_lane_group(ks, f'LANESPLAN_{g}', note, enqueue=False)
                results.update(got)
                self.note_claims(f'{g} planner', got)   # the other planners see these claims at once
                # Owner 2026-10-11: queue each group's tasks as soon as its planner answers; the idle-lane refill
                # starts them within a minute. Cycle 157's DeepSeek tasks waited behind a ChatGPT-lanes planner that
                # never answered and were lost at the halt.
                self.enqueue_lanes(got, snapshot)
            except Exception as e:   # noqa: BLE001 - one planner must not stop the others
                log(f'lanes ({g}): no plan ({type(e).__name__}: {str(e)[:160]})')
            finally:
                try:
                    self._tls.bridge and self._tls.bridge.disconnect()
                except Exception:   # noqa: BLE001
                    pass

        log(f"lanes: {len(groups)} planners in parallel ({', '.join(groups)})")
        threads = [threading.Thread(target=run, args=(g, ks), name=f'lanes-plan-{g}', daemon=True)
                   for g, ks in groups.items()]
        for t in threads:
            t.start()
        for t in threads:
            while t.is_alive():
                t.join(10)
                if STOP_PATH.exists():
                    raise Halt("STOP requested")
        if results:
            write(self.cyc / "LANE_TASKS.md", "\n\n".join(f"## {k}: {t}\n\n{b}" for k, (t, b) in results.items()))
        # (each planner thread already queued its own tasks; queueing them again here would re-add tasks the refill
        # has started meanwhile, and the lane would build them twice)
        return results

    def _plan_lane_group(self, keys: list[str], tag: str, extra: str = "", enqueue: bool = True) -> dict:
        snapshot = self.planning_snapshot() if (enqueue and self.queue_enabled()) else {}
        vis = [k for k in self.visual_lanes() if k in keys]   # owner 2026-10-08: playtest defects were piling up
        playtests = sorted((HERE / "playtests").glob("PLAYTEST_*.md"))
        note = "".join(P.VISUAL_LANE.substitute(lane=k, report=playtests[-1]) for k in vis) if playtests else ""
        if len(vis) > 1 and note:
            note += (f"\nThe visual-fix lanes {', '.join(vis)} work at the same time: give each DIFFERENT defects in "
                     "different scripts/scenes so their changes cannot conflict.\n")
        try:
            out = self.think(P.LANES_PLAN.substitute(repo=self.repo, main_plan=self.cyc / "CLAUDE_PLAN.md",
                                                    docs=HERE.parent / "full_game")
                             + note + extra + self.lane_plan_section(keys, force=True), tag)
        except (AgentFailed, UsageLimited) as e:
            log(f"lanes: no plan ({e})")
            return {}
        tasks = self.parse_lane_tasks(out)
        if enqueue:
            self.enqueue_lanes(tasks, snapshot)
        return tasks

    def start_lane_task(self, key: str, title: str, task: str, base: dict | None = None) -> bool:
        """base: an accepted, not yet merged task of this lane (early start); the new worktree branches from it."""
        from lane_local import LaneError
        cur = self.state.get(f"{key}_task")
        if cur:   # two launch paths (cycle start, idle refill) must never start one lane twice: that wipes its worktree
            log(f"{key}: already working on \"{cur.get('title', '')}\"; not starting \"{title}\"")
            return False
        task, assets = self.lane_assets(task)
        task_id = f"{self.state['cycle']:03d}-{key}-{int(time.time())}"
        brief = (f"# {title}\n\n{task.strip()}" + self.art_note(assets)
                 + (P.VISUAL_SHOTS if self._visual_check_on(key) else ""))
        brief += P.coder_refs_note(self.coder_refs(brief))
        contract = TP.scope(task, title)
        if self.queue_enabled():
            overlap = TP.conflict(contract, self.active_scopes(key))
            if overlap:
                self.queue_event(key, title, 'BLOCKED', overlap)
                log(f'{key}: ownership conflict; leaving lane idle: {overlap}'
                    + ('; the carried task waits in the queue again' if self._return_carry(title) else ''))
                return False
        try:
            info = self.lane2(key, contract.get("size", "")).start(
                task_id, brief, base=(base or {}).get("start") or (base or {}).get("commit"))
        except (LaneError, OSError) as e:
            log(f"{key}: could not start ({e})")
            self._return_carry(title)
            return False
        (getattr(self, '_dispatched_carries', None) or {}).pop(title, None)
        info.update(title=title, started=ts(), scope=contract)
        if assets:
            info.update(art_pid=self.start_lane_art(key, info, assets))
        if base:
            info.update(base_commit=base["commit"], base_branch=base["branch"], base_title=base.get("title", ""),
                        base_start=base.get("start") or base["commit"])
        self.save(**{f"{key}_task": info})
        (getattr(self, "_fresh_claims", None) or {}).pop(key, None)
        self.write_live_board()
        log(f"{key}: started \"{title}\"" + (f" early, on top of its accepted \"{base.get('title', '')}\" "
                                             "(that merges at the next cycle start)" if base else ""))
        return True

    # ---- early start (owner 2026-10-11): accepted lanes waited 22-29 min (57% of lane time) for the cycle-start
    # merge before their next task could begin. Park the accepted branch (it still merges at the next cycle start)
    # and start the queued next task at once in a worktree branched from it.

    def parked(self, key: str) -> list:
        return list(self.state.get(f"{key}_parked") or [])

    def early_start_lane(self, key: str) -> bool:
        rc = self.cfg.get("lane_review", {})
        if not (rc.get("early_start", True) and self.queue_enabled()):
            return False
        if getattr(self, "_halting", False) or STOP_PATH.exists() or PAUSE_PATH.exists():
            return False
        lt = self.state.get(f"{key}_task")
        if (not lt or (lt.get("review") or {}).get("verdict") != "ACCEPTED" or lt.get("give_up")
                or not self.cfg.get(key, {}).get("enabled")):
            return False
        if len(self.parked(key)) >= int(rc.get("early_start_max_parked", 2)):
            return False
        if lt.get("branch") in self.merge_check_branches():   # it is finished (and freed) when the check passes
            return False
        task = load_json(HERE / "prepared" / "lane_queue.json", {}).get(key)
        if not task or self.ready_problem(task, key):
            return False   # nothing ready yet, or it conflicts: the normal cycle-start launch handles it
        commit = self.git("rev-parse", lt["branch"], check=False).strip()
        if not commit:
            return False
        with self._save_lock:
            cur = self.state.get(f"{key}_task")
            if not cur or cur.get("branch") != lt["branch"]:
                return False
            entry = {**cur, "commit": commit, "parked_at": ts()}
            self.save(**{f"{key}_task": None, f"{key}_parked": self.parked(key) + [entry]})
        root = Path(lt.get("dir") or self.lane2(key).root)
        self.git("worktree", "remove", "--force", str(root), check=False)   # keeps the branch
        shutil.rmtree(root, ignore_errors=True)
        self.git("worktree", "prune", check=False)
        got = self.dequeue_lane(key)
        if not got or not self.start_lane_task(key, *got, base={**entry, "start": self._early_base(key, commit)}):
            log(f"{key}: accepted \"{lt['title']}\" parked; its next task starts at the cycle start instead")
            self.write_live_board()
            return False
        return True

    def _early_base(self, key: str, commit: str) -> str:
        """2026-10-17 cycle 382: lane6's early-started task branched from its accepted branch (made at 18:04), so it
        missed lane7's H1 BattleHudState merged into main at 19:06; the coder found no H1 and deferred after 32 min.
        Start from the accepted commit merged with the current main (both tested) when they merge cleanly; the
        merge commit only exists in the new lane branch. base_commit stays the accepted commit (merge/ancestry check)."""
        main = self.git("rev-parse", self.main, check=False).strip()
        if not main or self.git_ok("merge-base", "--is-ancestor", main, commit):
            return commit
        r = subprocess.run(["git", "merge-tree", "--write-tree", commit, main], cwd=self.repo, capture_output=True,
                           text=True, encoding="utf-8", errors="replace")
        tree = (r.stdout.split() or [""])[0]
        if r.returncode or not tree:
            log(f"{key}: its accepted task does not merge cleanly with {self.main} yet; the early task starts on the "
                "accepted task alone")
            return commit
        c = subprocess.run(["git", "commit-tree", tree, "-p", commit, "-p", main, "-m",
                            f"relay: early-start base for {key} (accepted task + current {self.main})"],
                           cwd=self.repo, capture_output=True, text=True, encoding="utf-8", errors="replace")
        return c.stdout.strip() if c.returncode == 0 and c.stdout.strip() else commit

    def refill_idle_lanes(self) -> None:
        """Owner 2026-10-11: a lane freed mid-cycle (deferred, given up, ownership conflict) idled until the next
        cycle start (lane3 Codex deferred at 11:48 and sat idle; lane5 waited 22 min). Start its queued task, or
        plan one in the background (at most once per lane per cooldown)."""
        rc = self.cfg.get("lane_review", {})
        if not (rc.get("refill_idle_lanes", True) and self.queue_enabled()):
            return
        if getattr(self, "_halting", False) or STOP_PATH.exists() or PAUSE_PATH.exists():
            return
        if self.state.get("phase") in (None, "IDLE", "PLAN"):
            return   # the cycle-start launch has not begun yet (cycle 156 refilled lanes it was about to start)
        lt_thread = getattr(self, "_lanes_thread", None)
        # While the cycle-start launch is still planning, only start tasks that are already queued (start_lane_task
        # refuses a busy lane, so the launch cannot start it twice); do not plan in parallel with it. Cycle 156's
        # Codex planner waited 23+ min for ChatGPT while lane3's queued task sat unused.
        launch_planning = lt_thread is not None and lt_thread.is_alive()
        planning = self.__dict__.setdefault("_refill_threads", {})
        last = self.__dict__.setdefault("_refill_at", {})
        cooldown = float(rc.get("refill_cooldown_s", 900))
        for key in self.idle_lanes():
            if (t := planning.get(key)) is not None and t.is_alive():
                continue
            queued = load_json(HERE / "prepared" / "lane_queue.json", {}).get(key)
            if queued or (self.has_carry() and not self.parked(key)):
                got = self.dequeue_lane(key)
                stale = self.__dict__.setdefault("_stale_replan", {})
                if got:   # on top of this lane's own accepted-but-unmerged work, if any
                    stale.pop(key, None)
                    self.start_lane_task(key, *got, base=(self.parked(key) or [None])[-1])
                elif queued:
                    # 2026-10-18: lane4's refill plan clashed with the next main plan (ready while it planned)
                    # and was dropped silently; the lane then idled the whole 15-min cooldown. Replan once now
                    # (once until a queued task starts, so a planner that keeps clashing cannot loop).
                    again = not stale.get(key)
                    log(f"{key}: queued \"{queued.get('title', '')}\" went stale before it started; "
                        + ("replanning now" if again else "replanning after the cooldown"))
                    if again:
                        stale[key] = True
                        last[key] = 0
                if got or queued:
                    continue
                # 2026-10-29: only other AREAs' carried tasks were waiting (lane5 Mistral idled 50+ min while lane2's
                # and lane8's carries sat in the queue); none fits this lane, so plan one for it as usual.
            if launch_planning or time.time() - last.get(key, 0) < cooldown:
                continue
            last[key] = time.time()

            def run(key=key) -> None:
                self._tls.bg = True
                try:
                    note = ((f"\nLane {key} is idle mid-cycle. Plan ONE task for it that can start now.\n")
                            + (f"This lane's focus area: {self.cfg[key]['plan_focus']}. Stay inside it.\n"
                               if self.cfg.get(key, {}).get("plan_focus") else ""))
                    got = self._plan_lane_group([key], f"LANESPLAN_{key}", note)
                    if got:
                        self.note_claims(f"{key} refill", got)
                        log(f"{key}: idle mid-cycle; next task queued: {next(iter(got.values()))[0]}")
                except Exception as e:   # noqa: BLE001 - best effort; the cycle start plans it otherwise
                    log(f"{key}: idle refill failed ({type(e).__name__}: {str(e)[:160]})")
                finally:
                    try:
                        self._tls.bridge and self._tls.bridge.disconnect()
                    except Exception:   # noqa: BLE001
                        pass

            log(f"{key}: idle mid-cycle; planning its next task now")
            planning[key] = threading.Thread(target=run, name=f"refill-{key}", daemon=True)
            planning[key].start()

    def _parked_scopes(self, skip: str) -> dict:
        out = {}
        for key in self.LANE_KEYS:
            if key == skip:
                continue
            for i, p in enumerate(self.parked(key)):
                if p.get("branch") in self.merge_check_branches():
                    continue
                files = self.git("diff", "--name-only", f"{self.main}...{p['branch']}", check=False).splitlines()
                sc = self.task_scope(key, p)
                out[f"{key}-accepted{i + 1}"] = {**sc, "title": p.get("title", ""),
                                                 "files": sorted(set(sc.get("files", []) + files))}
        return out

    def start_bg_planning(self, hist: str, lane_tasks: dict | None = None) -> None:
        cycle = self.state["cycle"]

        def run(steps) -> None:
            self._tls.bg = True
            for name, step in steps:
                try:
                    step()
                except Exception as e:   # noqa: BLE001 - a lane problem must never stop the main cycle
                    log(f"background {name}: {type(e).__name__}: {str(e)[:200]}")
            try:
                self._tls.bridge and self._tls.bridge.disconnect()
            except Exception:   # noqa: BLE001
                pass

        def next_plan() -> None:
            if self.cfg["chatgpt"].get("prefetch_plan", True) and not STOP_PATH.exists():
                self.prepare_next_plan(cycle, hist)

        # The next plan is the critical path (the next cycle waits for it), so it gets its own thread and ChatGPT tab
        # instead of queueing behind the lane planning messages (cycle 047 waited 27.6 min for it, 2026-10-08).
        carried = self.__dict__.pop("_carried_plan", None)
        if carried is not None and (carried.is_alive() or (HERE / "prepared" / f"plan_{cycle + 1:03d}.md").exists()):
            # Owner 2026-10-27: this cycle builds a queued task while the plan written for it carries on; that plan
            # is the next cycle's, so no second PLAN_NEXT is asked for.
            log(f"plan: the plan still being written becomes cycle {cycle + 1:03d}'s; no second next plan")
            self._bg_threads = [carried] if carried.is_alive() else []
            fresh = []
        else:
            plan = threading.Thread(target=run, args=([("next-plan", next_plan)],), name=f"bg-plan-{cycle:03d}",
                                    daemon=True)
            plan.plan_for = cycle + 1
            self._bg_threads = [plan]
            fresh = [plan]
        # Owner 2026-10-10: lane planning no longer holds up the next main cycle (cycle 115 waited for it). The lanes
        # thread keeps running across the cycle boundary; a new one starts only when the previous one is done.
        prev = getattr(self, "_lanes_thread", None)
        if prev is not None and prev.is_alive():
            log("lanes: previous lane planning still running; it launches its lanes when done")
        else:
            self._lanes_thread = threading.Thread(
                target=run, args=([("codex", self.maybe_launch_codex),
                                   ("lanes", lambda: self.launch_lanes(lane_tasks or {}))],),
                name=f"bg-lanes-{cycle:03d}", daemon=True)
            self._bg_threads.append(self._lanes_thread)
            fresh.append(self._lanes_thread)
        for t in fresh:
            t.start()

    def join_bg(self, wait_lanes: bool = True, swap: bool = False) -> None:
        """Pauses and halts wait for everything; a new cycle waits only for its prepared main plan (swap: or builds
        a queued task while that plan carries on)."""
        lanes = getattr(self, "_lanes_thread", None)
        alive = [t for t in self._bg_threads if t.is_alive() and (wait_lanes or t is not lanes)]
        if lanes is not None and lanes.is_alive() and wait_lanes and lanes not in alive:
            alive.append(lanes)
        if alive:
            log("waiting for background planning (" + ("lanes / " if wait_lanes else "") + "next plan) to finish")
            # 2026-10-19: cycle 429 waited 20+ min for a PLAN_NEXT whose ChatGPT tab sat idle through three 15-min
            # reloads. A fresh plan takes ~5 min, so past this wait the prefetch is dropped (its late answer is
            # discarded in prepare_next_plan) and the cycle plans normally.
            # 2026-10-19: cycle 432 dropped a PLAN_NEXT whose second try (after a bridge error) was 12.5 min in,
            # 11 s before it answered, then spent 11 min planning afresh. A try younger than next_plan_try_s
            # (a normal plan takes ~11-13 min now) is still waited for; a stuck try is dropped as before.
            # Owner 2026-10-27 (relay improvements): PLAN_NEXT takes ~20 min while Codex builds in ~12, so the main
            # coder sat idle a median 9.7 min after every accepted cycle (40% of its time). Past swap_wait_s a ready
            # queued lane task is built instead, and the plan still being written becomes the cycle after's.
            since = time.time()
            limit = int(self.cfg["chatgpt"].get("next_plan_wait_s", 600))
            try_limit = int(self.cfg["chatgpt"].get("next_plan_try_s", 960))
            swap_s = float(self.cfg.get("task_queue", {}).get("swap_wait_s", 90))
            for t in alive:
                while t.is_alive():
                    t.join(10)
                    if STOP_PATH.exists():
                        raise Halt("STOP requested")
                    now = time.time()
                    if (swap and swap_s > 0 and t.name.startswith("bg-plan-") and now - since > swap_s
                            and getattr(t, "plan_for", None) and not PAUSE_PATH.exists()):
                        queued = self.lane_task_for_main(take=False)
                        if queued:
                            self.__dict__.setdefault("_plan_slot", {})[t.plan_for] = self.state["cycle"] + 2
                            self._carried_plan, self._take_queued = t, True
                            log(f"next plan still being written after {(now - since) / 60:.1f} min; building the "
                                f"queued task {queued!r} now and keeping that plan for cycle "
                                f"{self.state['cycle'] + 2:03d}")
                            break
                    young = now - float(self.__dict__.get("_plan_next_try_at") or 0) < try_limit
                    if (t.name.startswith("bg-plan-") and now - since > limit
                            and (not young or now - since > limit + try_limit)):
                        self._abandoned_plan = self.state["cycle"] + 1
                        log(f"next plan still running after {limit // 60} min of waiting; dropping it and planning "
                            f"cycle {self._abandoned_plan:03d} normally")
                        break
        # A carried plan stays here, so a halt before the cycle's own background planning still lets it finish.
        carried = self.__dict__.get("_carried_plan")
        self._bg_threads = [carried] if carried is not None and carried.is_alive() else []

    def parallel_plan_context(self) -> dict:
        """Ownership and merged lane work that a prefetched main plan was based on."""
        with self._save_lock:
            context = {}
            for key in (*self.LANE_KEYS, 'codex'):
                task = self.state.get(f'{key}_task') or {}
                merged = self.state.get(f'{key}_history') or []
                context[key] = {
                    'task': {field: task.get(field) for field in ('branch', 'title')} if task else None,
                    'last_merged': merged[-1].get('commit') if merged else None,
                }
            return context

    def merged_prev_note(self) -> str:
        """Owner 2026-10-13: a prepared plan is written while the previous cycle is still building, so its Do NOT
        list fences that cycle's files ("the ongoing Mage Gold-rank files"). Cycle 213 then deferred after 34 min
        rather than correct a cycle-212 test fixture its required behaviour made wrong, though 212 had merged."""
        hist = self.state.get("history") or []
        prev = hist[-1] if hist else None
        if not prev or prev.get("cycle") != self.state["cycle"] - 1:
            return ""
        return (f"\n\nNote from the controller: this brief was written while cycle {prev['cycle']:03d} "
                f"(\"{prev.get('title')}\") was still being built. It is merged now, so its files are no longer "
                "reserved or ongoing: a Do NOT about that cycle's files or its ongoing work only kept the two builds "
                "apart. When this task's required behaviour makes one of that cycle's tests or fixtures wrong, make "
                "the smallest correction there (keep what its assertions protect) instead of deferring. Files that a "
                "RUNNING lane reserves or is changing stay off-limits.\n")

    def prepare_next_plan(self, cycle: int, hist: str) -> None:
        base_hist = hist
        nxt = cycle + 1
        snapshot = self.planning_snapshot() if self.queue_enabled() else {}
        with self._save_lock:
            parallel_context = self.parallel_plan_context()
            # 2026-10-24: the running main cycle's own files (scripts/app.gd in most cycles) were listed as busy and
            # banned here, so no prepared plan could take an app.gd owner order (battle layout skipped 4 times).
            # That cycle is merged before this plan runs; only lanes and Codex are really parallel.
            busy = self.busy_elsewhere('main')
        hist += (f"\nCycle {cycle:03d} is being built RIGHT NOW: {self.state.get('title')} (plan: "
                 f"{self.cyc / 'CLAUDE_PLAN.md'}; its in-progress changes are in the working tree). Assume it will be "
                 "accepted. Plan the NEXT step after it: never the same work. It is merged before your plan runs, so "
                 "its files (scripts/app.gd included) are free for your task when it needs them; do not list its "
                 "files or its ongoing work under Do NOT: if your task's behaviour makes one of its tests wrong, the "
                 "coder must be free to correct it.")
        hist += (f'\nCurrent parallel assignments: {busy}. Do not plan the same files or feature. '
                 'The controller will revalidate reserved files, dependencies and active ownership before launch.')
        hist += P.live_board_note() + self.unwired_note()
        out = self.think(self.plan_template().substitute(
            repo=self.repo, branch=f"relay/cycle-{nxt:03d} (created from {self.main} after cycle {cycle:03d} merges)",
            main=self.main, cycle=nxt, last_good=self.state["last_good_commit"] or "none", history=hist)
            + self.lane_plan_section([k for k in self.LANE_KEYS if self.cfg.get(k, {}).get("enabled")],
                                     " (tasks for lanes that are still busy when that cycle starts are dropped)"),
            "PLAN_NEXT")
        slot = self.__dict__.get("_plan_slot", {}).get(nxt, nxt)   # later if its cycle built a queued task
        if getattr(self, "_abandoned_plan", None) == slot:
            log(f"next plan: cycle {slot:03d} stopped waiting for this plan; discarding the late answer")
            return
        if not extract(out, "PLAN"):
            log("next plan: no @@PLAN@@ block; the next cycle will plan normally")
            return
        d = HERE / "prepared"
        d.mkdir(exist_ok=True)
        write(d / f"plan_{slot:03d}.md", out)
        metadata = {'parallel_context': parallel_context}
        if self.queue_enabled():
            main_text = re.sub(r'@@LANE_[a-z0-9]+_START@@.*?@@LANE_[a-z0-9]+_END@@', '', out, flags=re.S)
            try:
                tm = re.search(r'^TITLE:\s*(.+)$', out, re.M)
                metadata.update(self.ready_manifest(main_text, tm.group(1).strip() if tm else '', snapshot))
            except ValueError as e:
                log(f'next plan: missing ready-task contract ({e}); it will be replanned')
            self.enqueue_lanes(self.parse_lane_tasks(out), snapshot)
        save_json(d / f"plan_{slot:03d}.json", metadata)
        m = re.search(r"^TITLE:\s*(.+)$", out, re.M)
        log(f"next plan ready for cycle {slot:03d}: {m.group(1).strip() if m else '?'}")
        # Owner 2026-10-10: check the new plan against running lanes NOW and replan off the critical path, instead
        # of finding the clash when the next cycle starts (cycle 119's plan and lane4 both took Ragwheel's sprint).
        if self.queue_enabled() and metadata.get('scope') and not getattr(getattr(self, '_tls', None), 'next_plan_retry', False):
            lanes = {k: v for k, v in self.active_scopes('main').items() if k != 'main' and self._still_coding(k)}
            clash = TP.conflict(metadata['scope'], lanes)
            clashing = [k for k in lanes if TP.conflict(metadata['scope'], {k: lanes[k]})]
            if clash and clashing and set(clashing) <= set(self.plan_holding_lanes(metadata['scope'], lanes)):
                # 2026-10-24: 20 clashes, 14 with lane6/lane7, often dropping the owner's order. A lane that has
                # coded for a while usually finishes before the cycle start, which now waits for it.
                log(f"next plan: clashes with a running lane ({clash}); keeping the plan: {', '.join(clashing)} "
                    "should finish soon, and the cycle start waits for it")
                return
            if clash and not STOP_PATH.exists():
                log(f"next plan: clashes with a running lane ({clash}); replanning it now, off the critical path")
                (d / f"plan_{slot:03d}.md").unlink(missing_ok=True)
                (d / f"plan_{slot:03d}.json").unlink(missing_ok=True)
                self._tls.next_plan_retry = True
                # 2026-10-27: cycle 325's plan was the OWNER ORDER's first item (mount the party picker); a lane had
                # just taken scripts/app.gd, and "choose a different feature" dropped the owner's top step. The owner
                # step is now proposed again (the retry is not clash-checked; the cycle start waits for that lane).
                try:
                    self.prepare_next_plan(cycle, base_hist + f"\nYour previous proposal clashed with a running "
                                           f"lane ({clash}). If it built the first open OWNER ORDER item, propose "
                                           "that same step again (the next cycle start waits for that lane); "
                                           "otherwise choose a different feature and files.")
                finally:
                    self._tls.next_plan_retry = False

    def _still_coding(self, key: str) -> bool:
        """2026-10-19: the next-plan clash check threw away cycle 419's run-mode Gold-table plan because lane7 held
        tests/m08e_wave_gold_reward_test.gd, though lane7's tests had passed and it was only waiting for its review
        (ACCEPTED two minutes later, merged at the next cycle start). Accepted work waiting for that merge, and
        finished lanes whose tests pass, no longer count: their files are on main before the next cycle starts, and
        take_prepared_plan re-checks ownership then anyway."""
        if '-accepted' in key:
            return False
        task = self.state.get(f'{key}_task') or {}
        return not (task.get('finished') and task.get('tests_ok'))

    def prepared_slot(self, n: int) -> tuple:
        """(plan path, metadata path, metadata, usable, unaccepted previous-cycle title) for cycle n's prepared plan."""
        p = HERE / "prepared" / f"plan_{n:03d}.md"
        hist = self.state.get("history") or []
        ok = bool(p.exists() and hist and hist[-1].get("cycle") == n - 1)
        # Owner 2026-10-13: a deferred or failed previous cycle used to throw the prepared plan away (cycle 197
        # replanned for 15 min). Reuse it after the short refresh check, which is told that cycle is not on main.
        unaccepted = None
        if p.exists() and not ok:
            ends = [e for k in ('failed', 'deferred') for e in (self.state.get(k) or [])
                    if isinstance(e, dict) and e.get('cycle') == n - 1]
            if ends:
                ok, unaccepted = True, ends[-1].get('title') or self.state.get('title') or f'cycle {n - 1:03d}'
        meta_path = p.with_suffix('.json')
        try:
            meta = load_json(meta_path, None)
        except (ValueError, OSError):
            meta = None
        return p, meta_path, meta, ok, unaccepted

    def take_prepared_plan(self) -> str | None:
        """Revalidate ownership/source; read-only drift may receive a short independent readiness refresh."""
        if self.__dict__.pop("_take_queued", False):
            taken = self.lane_task_for_main()
            if taken:
                write(self.cyc / "PLAN_ANSWER.md", taken)
                log(f"plan: building the queued task {taken.splitlines()[0][7:]!r} while the next plan is still "
                    "being written")
                return taken
        p, meta_path, meta, ok, unaccepted = self.prepared_slot(self.state["cycle"])
        problem = None
        self._refresh_revised = None
        if ok:
            if self.queue_enabled() and isinstance(meta, dict):
                if self.fast_cycles() and meta.get('planning_profile') != 'fast-v1':
                    problem = 'prepared task predates the small-cycle planning target'
                else:
                    problem = self.ready_problem(meta, 'main')
                    drift = problem == DRIFT
                    if (drift or (problem is None and unaccepted)) and self.fast_cycles():
                        problem = self.refresh_prepared_plan(p, meta, unaccepted)
                    elif problem is None and unaccepted:
                        problem = f'previous cycle was not accepted ({unaccepted})'
            elif not isinstance(meta, dict) or meta.get('parallel_context') != self.parallel_plan_context():
                problem = 'parallel assignments or merged work changed'
            elif unaccepted:
                problem = f'previous cycle was not accepted ({unaccepted})'
        if ok and problem:
            ok = False
            suffix = f'.stale-{time.time_ns()}'
            p.rename(p.with_name(p.name + suffix))
            if meta_path.exists():
                meta_path.rename(meta_path.with_name(meta_path.name + suffix))
            revised, self._refresh_revised = self._refresh_revised, None
            if revised:
                write(self.cyc / "PLAN_ANSWER.md", revised)
                log(f'plan: {problem[:400]}; using the corrected task the refresh check wrote instead of '
                    'planning afresh')
                return revised
            taken = self.lane_task_for_main()
            if taken:
                write(self.cyc / "PLAN_ANSWER.md", taken)
                log(f'plan: {problem[:400]}; building the queued task {taken.splitlines()[0][7:]!r} instead of '
                    'planning afresh')
                return taken
            log(f'plan: {problem}; preserving stale plan and planning afresh')
        out = read(p) if ok else None
        # Consume only this slot; keep the bounded lane queue and any next slot intact.
        if out:
            p.unlink(missing_ok=True)
            meta_path.unlink(missing_ok=True)
        if out:
            write(self.cyc / "PLAN_ANSWER.md", out)
            log("plan: using the plan prepared during the previous cycle")
        return out

    def lane_task_for_main(self, take: bool = True) -> str | None:
        """2026-10-22 (relay speed): a stale prepared plan meant a fresh PLAN on the critical path (cycle 082: 12 min,
        cycle 087: 27 min) while a ready lane task waited in the queue. Main now builds the oldest queued lane task
        that is still free and unchanged; that lane plans a new one in the background. take=False only says whether
        there is one (its title), leaving it queued."""
        if not self.cfg.get('task_queue', {}).get('main_takes_lane_task', True):
            return None
        path = HERE / 'prepared' / 'lane_queue.json'
        with self._save_lock:
            pending = load_json(path, {})
            for key, task in sorted(pending.items(), key=lambda kv: kv[1].get('queued_at', 0)):
                if not (isinstance(task, dict) and task.get('brief') and task.get('title')):
                    continue
                if self.ready_problem(task, 'main'):
                    continue
                if not take:
                    return task['title']
                pending.pop(key)
                save_json(path, pending)
                self.queue_event(key, task['title'], 'TAKEN_BY_MAIN')
                brief = task['brief'].strip()
                ms = re.search(r'^MILESTONE:\s*(\S+)', brief, re.M)
                return (f"TITLE: {task['title']}\n" + (f"MILESTONE: {ms.group(1)}\n" if ms else '')
                        + f"@@PLAN_START@@\n{brief}\n@@PLAN_END@@\n@@BRIEF_START@@\n{brief}\n@@BRIEF_END@@\n")
        return None

    def refresh_prepared_plan(self, path: Path, manifest: dict, unaccepted: str | None = None) -> str | None:
        """Never bypass malformed manifests, ownership or a missing READY verdict. Owner 2026-10-13: changed owned
        files and an unaccepted previous cycle get the short refresh check too, instead of a fresh plan."""
        got = self.refresh_inputs(path, manifest, unaccepted)
        if got is None:
            return 'invalid fingerprints; fresh planning required'
        before, changed, prompt = got
        if not changed and not unaccepted:
            return None
        try:
            answer = self.take_early_refresh(prompt, before)
            if answer is None:
                answer = self.think(prompt, 'PLAN_REFRESH')
        except AgentFailed as e:
            return f'dependency refresh unavailable; fresh planning required: {e}'
        return self.apply_refresh(answer, manifest, before, changed)

    def refresh_inputs(self, path: Path, manifest: dict, unaccepted: str | None) -> tuple | None:
        """(current fingerprints, changed paths, PLAN_REFRESH prompt), or None for unusable fingerprints."""
        before = TP.fingerprints(self.repo, manifest['scope'])
        split = TP.changed_task_paths(manifest, before)
        if split is None:
            return None
        owned, reads = split
        notes = []
        if owned:
            notes.append('These files the task WRITES changed since planning (other accepted work was merged into '
                         'them; the coder edits their current versions):\n' + '\n'.join('- ' + p for p in owned)
                         + '\nREADY if the same steps and criteria still fit the current code; REPLAN if the task '
                         'is already done, now conflicts with that work, or its steps no longer fit.')
        if reads:
            notes.append('These declared read dependencies changed:\n' + '\n'.join('- ' + p for p in reads))
        if unaccepted:
            notes.append(f'The previous cycle ("{unaccepted}") was NOT accepted: its changes are NOT on the main '
                         'branch. REPLAN if this task needs that work; otherwise READY.')
        return before, owned + reads, P.PLAN_REFRESH.substitute(repo=self.repo, plan_path=path,
                                                                 changed='\n\n'.join(notes))

    def start_early_refresh(self, during_final: bool = False) -> None:
        """Owner 2026-10-13 (cycles under 30 min): the next cycle's PLAN_REFRESH (~2-5 min) runs while the
        lane-merge suite runs (~8-12 min) instead of after it. The answer is used only if the prepared plan, the
        changed files and their fingerprints are identical when the cycle plans (a failed batch resets main).
        during_final (owner 2026-10-13): cycle 223's lanes merged when its build ended, so cycle 224's refresh
        waited out the 9-min final review and then took 5 min more. It now starts with the final review, taking
        this cycle as accepted; a rejection or deferral changes the refresh prompt, so that answer is not used."""
        old, self._early_refresh = getattr(self, "_early_refresh", None), None
        if not (self.fast_cycles() and self.queue_enabled()):
            return
        p, _meta_path, meta, ok, unaccepted = self.prepared_slot(self.state["cycle"] + 1)
        if during_final:
            ok, unaccepted = p.exists(), None
        if not ok or not isinstance(meta, dict) or meta.get('planning_profile') != 'fast-v1':
            return
        try:
            problem = self.ready_problem(meta, 'main')
            if not (problem == DRIFT or (problem is None and unaccepted)):
                return
            got = self.refresh_inputs(p, meta, unaccepted)
        except Exception as e:   # noqa: BLE001 - the normal refresh runs later
            log(f"plan: early refresh skipped ({type(e).__name__}: {str(e)[:120]})")
            return
        if got is None or not (got[1] or unaccepted):
            return
        before, _changed, prompt = got
        box: dict = {"key": (prompt, self._early_key(before))}
        if old and old.get("key") == box["key"] and not old.get("error"):
            self._early_refresh = old   # the check started during the final review still matches; keep it
            return

        def run() -> None:
            # 2026-10-22 (cycle 096 halt): a refresh started during the final review finished after the accept had
            # switched the repo to the next cycle branch; as a foreground step it read that as ChatGPT's edit.
            self._tls.bg = True
            try:
                box["answer"] = self.think(prompt, 'PLAN_REFRESH')
            except BaseException as e:   # noqa: BLE001 - handed to the planning thread
                box["error"] = e
            finally:
                try:
                    self._tls.bridge and self._tls.bridge.disconnect()
                except Exception:   # noqa: BLE001
                    pass

        box["thread"] = threading.Thread(target=run, name="plan-refresh-early", daemon=True)
        box["thread"].start()
        self._early_refresh = box
        log(f"plan: refresh check for cycle {self.state['cycle'] + 1:03d} started while the "
            f"{'final review' if during_final else 'lane-merge tests'} run{'s' if during_final else ''}")

    def _early_key(self, before: dict) -> str:
        """The early refresh's source key: the same paths, hashed without line endings. Owner 2026-10-13: cycle
        231's check (started during cycle 230's final review) was asked again for 4.4 min only because the files
        cycle 230 created were LF in Codex's working tree and CRLF once git (core.autocrlf) checked them out."""
        out = {}
        for name in sorted(before):
            q = self.repo / TP.clean_path(name)
            out[name] = hashlib.sha256(q.read_bytes().replace(b"\r\n", b"\n")).hexdigest() if q.is_file() else None
        return json.dumps(out, sort_keys=True)

    def take_early_refresh(self, prompt: str, before) -> str | None:
        box, self._early_refresh = getattr(self, "_early_refresh", None), None
        if not box:
            return None
        if box["key"] != (prompt, self._early_key(before)):
            log("plan: the early refresh check no longer matches the prepared plan or source; asking again")
            return None
        t, n = box["thread"], 0
        if t.is_alive():
            log("plan: waiting for the refresh check started during the previous cycle")
        while t.is_alive():
            t.join(5)
            n += 1
            if STOP_PATH.exists():
                raise Halt("STOP requested")
            if n % 12 == 0:
                self.save(heartbeat=ts())
        e = box.get("error")
        if isinstance(e, Halt):
            raise e
        if e is not None:
            log(f"plan: early refresh check failed ({type(e).__name__}: {str(e)[:120]}); asking again")
            return None
        log("plan: using the refresh check answered during the previous cycle")
        return box.get("answer")

    def apply_refresh(self, answer: str, manifest: dict, before, changed: list) -> str | None:
        try:
            verdict = json.loads(extract(answer, 'REFRESH') or '')
            if not isinstance(verdict, dict) or verdict.get('decision') not in ('READY', 'REPLAN'):
                raise ValueError('missing READY/REPLAN decision')
            if not isinstance(verdict.get('reason'), str) or not verdict['reason'].strip():
                raise ValueError('missing refresh evidence')
        except ValueError as e:
            write(self.cyc / 'PLAN_REFRESH_CHECK.json', json.dumps({'decision': 'REPLAN', 'reason': str(e)}))
            return f'dependency refresh could not verify readiness: {e}'
        save_json(self.cyc / 'PLAN_REFRESH_CHECK.json', {**verdict, 'changed_dependencies': changed,
                                                       'fingerprints': before})
        if verdict['decision'] != 'READY':
            self._refresh_revised = self.revised_plan(answer)
            return 'dependency refresh requires replanning: ' + verdict['reason']
        updated = {**manifest, 'fingerprints': before}
        problem = self.ready_problem(updated, 'main')
        if problem:
            return 'task changed or acquired another owner during refresh: ' + problem
        log('plan: refresh check says the prepared plan still fits current source; keeping the original brief')
        return None

    def revised_plan(self, answer: str) -> str | None:
        """Owner 2026-10-13 (cycles under 30 min): a REPLAN refresh may write the corrected task after its verdict.
        Cycle 214's refresh found the exact gap (JSON numbers decode as floats) in 5 min, then a fresh PLAN took
        18 min. A usable correction is a complete plan with an explicit scope and brief; do_plan still re-checks
        its scope and ownership like any fresh plan."""
        text = re.sub(r'@@REFRESH_START@@.*?@@REFRESH_END@@', '', answer, flags=re.S).strip()
        title = re.search(r'^TITLE:\s*(.+)$', text, re.M)
        if not title or title.group(1).strip().upper() == 'NONE' or not extract(text, 'PLAN'):
            return None
        if len((extract(text, 'BRIEF') or '').strip()) <= 200:
            return None
        try:
            if not TP.scope(text, title.group(1).strip()).get('explicit'):
                return None
        except ValueError:
            return None
        return text + '\n'

    def art_note(self, assets: list) -> str:
        if not assets:
            return ""
        from art_gen import asset_path
        paths = "\n".join(f"- {asset_path(self.repo, a['category'], a['id']).relative_to(self.repo).as_posix()}"
                          for a in assets)
        return ("\n\n## Paper-art images for this task\n"
                "The relay generates these images in parallel with your work; they appear at these paths:\n"
                f"{paths}\n"
                "Use exactly these paths in code. Never create, copy or edit PNG files, and never add placeholder "
                "images. If one is not there yet while you work, a test that loads it may fail until it arrives; "
                "that is expected, so do not work around it. The relay runs the full suite after the images land.\n")

    def start_art_bg(self) -> None:
        """Generate this cycle's images in a separate process while the brief and build run."""
        assets = self.state.get("assets") or []
        write(self.cyc / "ASSET_REQUESTS.json", json.dumps(assets, indent=2))
        (self.cyc / "ART_RESULT.md").unlink(missing_ok=True)
        (self.cyc / "logs").mkdir(parents=True, exist_ok=True)
        out = open(self.cyc / "logs" / "art_bg.log", "a", encoding="utf-8")
        p = subprocess.Popen([sys.executable, str(HERE / "art_runner.py"), str(self.cyc)], cwd=HERE,
                             stdout=out, stderr=subprocess.STDOUT,
                             creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        self.save(art_pid=p.pid)
        log(f"art: generating {len(assets)} image(s) in the background while the code is built")

    # Owner 2026-10-17: HUD/visual steps run on side lanes, so a lane task may request images too (an assets block in
    # its LANE block). They are generated into the lane's worktree while its coder works and land before its suite.

    def lane_assets(self, task: str) -> tuple:
        m = re.search(r"\n?@@ASSETS(?:_START)?@@.*?@@ASSETS_END@@\n?", task or "", re.S)
        if not m:
            return task, []
        rest = task[:m.start()] + "\n" + task[m.end():]
        if not self.cfg.get("art", {}).get("enabled"):
            return rest, []
        from art_gen import parse_assets
        return rest, parse_assets(m.group(0))[: int(self.cfg["art"].get("max_per_lane", 4))]

    def start_lane_art(self, key: str, info: dict, assets: list):
        if not (info.get("run_dir") and info.get("dir")):
            return None
        run = Path(info["run_dir"])
        run.mkdir(parents=True, exist_ok=True)
        write(run / "ASSET_REQUESTS.json", json.dumps(assets, indent=2))
        (run / "ART_RESULT.md").unlink(missing_ok=True)
        out = open(run / "art_bg.log", "a", encoding="utf-8")
        p = subprocess.Popen([sys.executable, str(HERE / "art_runner.py"), str(run), str(info["dir"])], cwd=HERE,
                             stdout=out, stderr=subprocess.STDOUT,
                             creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        log(f"{key}: generating {len(assets)} image(s) in the background for its task")
        return p.pid

    def wait_lane_art(self, key: str, lt: dict) -> None:
        """Before a lane's suite and commit: its images must be in its worktree."""
        run = Path(lt.get("run_dir") or "")
        if not lt.get("art_pid") or not lt.get("run_dir") or not (run / "ASSET_REQUESTS.json").exists():
            return
        done, pid = run / "ART_RESULT.md", lt["art_pid"]

        def alive() -> bool:
            try:
                return "art_runner.py" in " ".join(psutil.Process(pid).cmdline())
            except psutil.Error:
                return False

        limit = int(self.cfg.get("art", {}).get("bg_timeout_s", 3600))
        deadline = time.time() + limit
        if not done.exists() and alive():
            log(f"{key}: waiting for its images before the suite")
        while not done.exists() and alive() and time.time() < deadline and not STOP_PATH.exists():
            time.sleep(10)
        if done.exists() or STOP_PATH.exists():
            return
        if alive():
            psutil.Process(pid).kill()
        log(f"{key}: background images did not finish; generating the rest now")
        try:
            subprocess.run([sys.executable, str(HERE / "art_runner.py"), str(run), str(lt["dir"])], cwd=HERE,
                           capture_output=True, timeout=limit, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        except subprocess.TimeoutExpired:
            log(f"{key}: images still missing after {limit // 60} min; the suite runs without them")

    def finish_art_bg(self) -> None:
        """Before the tests: wait for the background images (or make them now if that process is gone)."""
        if not self.state.get("art_bg"):
            return
        done, pid = self.cyc / "ART_RESULT.md", self.state.get("art_pid")

        def alive() -> bool:
            try:
                return bool(pid) and "art_runner.py" in " ".join(psutil.Process(pid).cmdline())
            except psutil.Error:
                return False

        deadline = time.time() + int(self.cfg.get("art", {}).get("bg_timeout_s", 3600))
        if not done.exists() and alive():
            log("art: waiting for the background images before testing")
        while not done.exists() and alive() and time.time() < deadline:
            sleep_checked(10)
            self.save(heartbeat=ts())
        if done.exists():
            lines = read(done).strip().splitlines()
        else:
            if alive():
                psutil.Process(pid).kill()
            log("art: background generation did not finish; generating the remaining images now")
            from art_gen import ArtError, generate_assets
            try:
                lines = generate_assets(self.cfg, self.repo, self.state.get("assets") or [], log, STOP_PATH.exists,
                                        lambda: self.save(heartbeat=ts()))
            except ArtError:
                raise Halt("STOP requested")
        plan = self.cyc / "CLAUDE_PLAN.md"
        write(plan, read(plan) + "\n## Generated paper-art assets (already in the working tree; use them, never "
                                 "create or edit PNG files)\n" + "\n".join(lines) + "\n")
        log(f"art: {sum('generated' in l for l in lines)} generated, {sum('MISSING' in l for l in lines)} missing")
        self.save(art_bg=False, art_pid=None)

    def do_art(self) -> None:
        """Generate the plan's requested paper-art images (ChatGPT image generation) before the brief."""
        from art_gen import ArtError, generate_assets
        try:
            lines = generate_assets(self.cfg, self.repo, self.state.get("assets") or [], log, STOP_PATH.exists,
                                    lambda: self.save(heartbeat=ts()))
        except ArtError:
            raise Halt("STOP requested")
        plan = self.cyc / "CLAUDE_PLAN.md"
        write(plan, read(plan) + "\n## Generated paper-art assets (already in the working tree; use them, never "
                                 "create or edit PNG files)\n" + "\n".join(lines) + "\n")
        made = sum("generated" in l for l in lines)
        log(f"art: {made} generated, {sum('MISSING' in l for l in lines)} missing")
        self.save(phase="BRIEF")

    def do_brief(self) -> None:
        if self.state.get("plan_brief") and (self.cyc / "DEEPSEEK_BRIEF.md").exists():
            self.note_coder_refs(self.cyc / "DEEPSEEK_BRIEF.md")
            self.save(phase="BUILD", brief_file="DEEPSEEK_BRIEF.md", brief_source="planner")
            return
        plan_path = self.cyc / "CLAUDE_PLAN.md"
        text_prompt = P.BRIEF.substitute(plan=read(plan_path))
        brief, source = None, "chatgpt"
        if self.cfg["chatgpt"].get("file_mode"):
            raw = self.cyc / "BRIEF_RAW.md"
            got = self.chatgpt_file(P.BRIEF_FILE.substitute(
                plan_path=plan_path, out_path=raw, repo=self.repo), "BRIEF", raw)
            if got:
                brief = extract(got, "BRIEF") or got.strip()
        else:
            reply = self.chatgpt(text_prompt, "BRIEF", "BRIEF")
            if reply:
                brief = extract(reply, "BRIEF")
        if not brief:
            if not self.cfg["chatgpt"].get("fallback_to_claude"):
                raise UsageLimited("ChatGPT brief failed and the Claude fallback is disabled")
            log("brief: falling back to Claude")
            source = "claude"
            brief = extract(self.claude(text_prompt, "BRIEF"), "BRIEF")
            if not brief:
                raise AgentFailed("brief missing @@BRIEF@@ markers")
        write(self.cyc / "DEEPSEEK_BRIEF.md", brief + self.owed_note() + self.hard_rules("DEEPSEEK_REPORT_0.md"))
        self.note_coder_refs(self.cyc / "DEEPSEEK_BRIEF.md")
        self.save(phase="BUILD", brief_file="DEEPSEEK_BRIEF.md", brief_source=source)

    def _chatgpt_builds(self) -> bool:
        return (self.cfg["opencode"].get("limit_fallback", "chatgpt") == "chatgpt" and self.deepseek_limited()
                and not self.fallback_model())

    # Owner 2026-10-12: Codex codes the main cycle (the live-wiring work that DeepSeek took 40-75 min and several
    # review rounds for); DeepSeek moved to lane 3, so there is still only one Codex coder. While a lane is still
    # finishing a Codex task, or Codex is usage-limited, DeepSeek builds as before.
    def _codex_builds_main(self) -> bool:
        if self.cfg.get("main_builder") != "codex":
            return False
        until = self.state.get("codex_main_paused_until", "")
        if until > ts():
            # Owner 2026-10-13: cycle 219 started 2 min before Codex's limit reset and DeepSeek built it for 28 min
            # (Codex ~18-20). Wait out a reset that is only minutes away (codex.pause_wait_s) instead.
            try:
                secs = (datetime.datetime.strptime(until, "%Y-%m-%d %H:%M:%S") - datetime.datetime.now()).total_seconds()
            except ValueError:
                return False
            if secs > int(self.cfg.get("codex", {}).get("pause_wait_s", 480)):
                return False
            log(f"main build: Codex's usage limit resets at {until[11:16]}; waiting {max(0.0, secs) / 60:.0f} min "
                "for it rather than a slower DeepSeek build")
            sleep_checked(max(0.0, secs))
        # Owner 2026-11-06 ("can you use codex more"): with codex.parallel_lanes a Codex lane no longer hands the main
        # build to DeepSeek; both run Codex at once.
        for key in ([] if self.cfg.get("codex", {}).get("parallel_lanes") else self.LANE_KEYS):
            lt = self.state.get(f"{key}_task") or {}
            if lt and (lt.get("repair_builder") == "codex" or str(lt.get("log", "")).endswith("codex.log")):
                log(f"main build: {key} is still running Codex; DeepSeek builds this attempt")
                return False
        return True

    # Owner 2026-10-20: Codex used a whole weekly limit in 2 days. It builds each cycle's first attempt only; fix
    # rounds go to DeepSeek / ChatGPT Chat unless codex.fix_rounds is true.
    def _codex_back_in_s(self) -> float | None:
        """Seconds until Codex's main-build usage limit resets, when Codex builds the main task; None otherwise."""
        until = self.state.get("codex_main_paused_until", "")
        if self.cfg.get("main_builder") != "codex" or not until or until <= ts():
            return None
        try:
            return max(0.0, (datetime.datetime.strptime(until, "%Y-%m-%d %H:%M:%S") - datetime.datetime.now()).total_seconds())
        except ValueError:
            return None

    def _codex_main_attempt(self, attempt: int) -> bool:
        if attempt > 0 and not self.cfg.get("codex", {}).get("fix_rounds", False):
            return False
        return self._codex_builds_main()

    # Owner 2026-10-26: "Can you do the hard coding tasks when codex is out instead of deepseek". While Codex's
    # usage limit is on, the main build is posted in HANDOFF for the owner's Claude Code session, which watches the
    # log for "handed to the Claude session". Nothing is launched: the session claims the task, codes it in the main
    # checkout and writes the report and a done marker. Unclaimed within claude_session.claim_s, or unfinished
    # within claude_session.timeout_s, DeepSeek builds as before (from any unfinished edits).
    def _claude_session_attempt(self, attempt: int) -> bool:
        cs = self.cfg.get("claude_session", {})
        if not cs.get("enabled") or self.cfg.get("main_builder") != "codex":
            return False
        if attempt > 0 and not cs.get("fix_rounds", False):
            return False
        return self.state.get("codex_main_paused_until", "") > ts()

    # Owner 2026-11-08 ("test chatgpt chat vs mistral/claude web for a coding task of similar size and use the best
    # one"): A/B on cycle 619's main task from its base d21dc475. Mistral web (MCP connector) passed all 13 tests and
    # the hidden check first time in 83 min; ChatGPT Chat took 11 min with 4 failing tests and cycle 619 then needed
    # 110 min of fix rounds; Claude web hit its free limit after 16 min with 3 failing. claude_session.builder
    # "mistral": while Codex is out Mistral web builds every attempt in the main checkout; when it cannot (all
    # accounts resting, timeout, no edits) ChatGPT Chat builds attempt 0 and DeepSeek the fix rounds, as before.
    def _mistral_main_attempt(self, attempt: int) -> bool:
        cs = self.cfg.get("claude_session", {})
        if cs.get("builder") != "mistral" or not cs.get("enabled") or self.cfg.get("main_builder") != "codex":
            return False
        if attempt > 0 and not cs.get("mistral_fix_rounds", True):
            return False
        return self.state.get("codex_main_paused_until", "") > ts()

    def _mistral_build(self, attempt: int, brief: Path, report: Path) -> bool:
        """Mistral web builds this attempt in the main checkout. False = it could not: the next builder takes over."""
        from lane_local import coder_argv
        head, before = self.git("rev-parse", "HEAD"), self.tree_fp()
        report.unlink(missing_ok=True)
        self.save(main_coder="Mistral")
        instr = P.coder_scope(f"Read {brief.as_posix()} and implement it completely, following every rule in it.")
        lp = self.cyc / "logs" / f"mistral_{attempt}.log"
        log(f"main build: Codex is out; Mistral web builds attempt {attempt}")
        started = time.time()
        rc, why = self.run_proc(coder_argv({"model": "mistral-web"}, instr), lp,
                                int(self.cfg["claude_session"].get("mistral_timeout_s", 4500)), self.cfg["stall_s"])
        if self.git("rev-parse", "--abbrev-ref", "HEAD") != self.state["branch"]:
            raise Halt("agent switched branches; inspect before restarting")
        if self.git("rev-parse", "HEAD") != head:
            log("agent committed; undoing with soft reset (changes kept)")
            self.git("reset", "--soft", head)
        if not (why == "exit" and (rc == 0 or completed_report(report, started))) or self.tree_fp() == before:
            nxt = "ChatGPT Chat" if attempt == 0 else "DeepSeek"
            log(f"main build: Mistral web could not build attempt {attempt} ({why}, rc={rc}: "
                f"{(tail(read(lp), 300).strip().splitlines() or [''])[-1][:120]}); {nxt} builds it from its edits")
            self.save(main_coder=None)
            return False
        if not report.exists():
            write(report, "(agent wrote no report)\n")
        try:
            self.check_coder_report(report)
        except AgentFailed as e:
            self.request_fix([str(e)], 'Complete the report evidence in the existing work; repair code only for unmet criteria.',
                             False, diagnosis=str(e))
            return True
        log(f"Mistral web build done (attempt {attempt}, {(time.time() - started) / 60:.0f} min)")
        self.save(phase="TEST", report_file=report.name, last_coder="Mistral")
        return True

    def _claude_session_build(self, attempt: int, brief: Path, report: Path) -> bool:
        """The Claude session builds this attempt. False = unclaimed or unfinished in time: DeepSeek builds."""
        cs = self.cfg.get("claude_session", {})
        head, br, guard = self.git("rev-parse", "HEAD"), self.state["branch"], guard_hash()
        report.unlink(missing_ok=True)
        before = self.tree_fp()
        task = self.cyc / f"CLAUDE_TASK_{attempt}.md"
        write(task, P.coder_scope(read(brief)) + (
            f"\n\nWork in {self.repo} on branch {br}. Run the full tests with exactly: "
            f"{' '.join(self.cfg['test_cmd'])} (Godot only --headless). Never commit, switch branches, reset, stash "
            f"or merge, never edit .review/ or PNG files. Write your report to {report}."
            + (" Codex began this build and stopped part-way; its unfinished edits are in the working tree: check "
               "them, keep what is right, and finish." if self._codex_partial else "") + "\n"))
        HANDOFF.mkdir(exist_ok=True)
        post, claim, done = (HANDOFF / f"claude_build.{x}" for x in ("json", "claimed", "done"))
        claim.unlink(missing_ok=True)
        done.unlink(missing_ok=True)
        save_json(post, {"cycle": self.state["cycle"], "attempt": attempt, "task": str(task), "report": str(report),
                         "repo": str(self.repo), "branch": br, "posted": ts()})
        self.save(main_coder="Claude")
        log(f"main build: Codex is out; handed to the Claude session ({task.name})")
        step, waited = 10, 0
        try:
            while not claim.exists():
                if waited >= int(cs.get("claim_s", 300)):
                    log("main build: the Claude session did not claim it; DeepSeek builds it")
                    self.save(main_coder="DeepSeek")
                    return False
                sleep_checked(step)
                waited += step
            log("main build: the Claude session claimed it")
            waited = 0
            while not done.exists():
                if waited >= int(cs.get("timeout_s", 2700)):
                    break
                sleep_checked(step)
                waited += step
        finally:
            for p in (post, claim, done):
                p.unlink(missing_ok=True)
        if self.git("rev-parse", "--abbrev-ref", "HEAD") != br:
            raise Halt("Claude session build switched branches; inspect before restarting")
        if self.git("rev-parse", "HEAD") != head:
            log("Claude session build committed; undoing with soft reset (changes kept)")
            self.git("reset", "--soft", head)
        if guard_hash() != guard:
            raise Halt("Claude session build modified relay files; inspect before restarting")
        self.sweep_strays()
        if not report.exists():
            self._codex_partial = self._codex_partial or self.tree_fp() != before
            log(f"main build: the Claude session did not finish in time; DeepSeek builds it"
                + (" from the unfinished edits" if self.tree_fp() != before else ""))
            self.save(main_coder="DeepSeek")
            return False
        try:
            self.check_coder_report(report)
        except AgentFailed as e:
            self.request_fix([str(e)], 'Complete the report evidence in the existing work; repair code only for unmet criteria.',
                             False, diagnosis=str(e))
            return True
        log(f"Claude session build done (attempt {attempt})")
        self.save(phase="TEST", report_file=report.name, last_coder="Claude")
        return True

    def _codex_build_tail(self, attempt: int) -> str:
        logs = sorted((self.cyc / "logs").glob(f"codex_BUILD_{attempt}_*.log"), key=lambda p: p.stat().st_mtime)
        return tail(read(logs[-1]), 3000) if logs else ""

    def _codex_stopped(self, attempt: int, rx: "re.Pattern") -> bool:
        """The last Codex build run ended on an error event matching rx (capacity, usage limit). Owner 2026-10-13:
        cycle 208's Codex hit its usage limit after editing three files; that half-built change looked like a
        finished build (the tree had changed), so it was tested and reviewed for 13 min before the fix round."""
        return any(rx.search(ln) for ln in self._codex_build_tail(attempt).splitlines() if '"error"' in ln)

    def _codex_resume_note(self, task: Path, before: str) -> None:
        if self.tree_fp() != before and "stopped part-way" not in read(task):
            write(task, read(task) + "\n\nNote: an earlier Codex run of this task stopped part-way (capacity or usage "
                  "limit). Its unfinished edits are in the working tree: check them, keep what is right, and finish.\n")

    def _codex_thread(self, attempt: int) -> str:
        """The Codex session id of this attempt's latest build run (its log's thread.started event), or ""."""
        logs = sorted((self.cyc / "logs").glob(f"codex_BUILD_{attempt}_*.log"), key=lambda p: p.stat().st_mtime)
        for lp in reversed(logs):
            m = re.search(r'"type":"thread\.started","thread_id":"([0-9A-Za-z-]+)"', read(lp)[:4000])
            if m:
                return m.group(1)
        return ""

    def _codex_retry(self, attempt: int, task: Path, report: Path, before: str) -> str | None:
        """Owner 2026-10-13: cycle 220's Codex hit "model at capacity" after 18 min with its tests already passing;
        a fresh run re-read the task and the half-built tree from scratch. Resume the same Codex session instead
        (it keeps everything it read and did); a fresh run with the resume note is the fallback."""
        self._codex_resume_note(task, before)
        timeout = int(self.cfg["timeouts"]["build"])
        thread = self._codex_thread(attempt) if self.cfg.get("codex", {}).get("resume_session", True) else ""
        if thread:
            reply = self.run_codex_main(task, report, f"BUILD_{attempt}", timeout, resume=thread)
            logs = sorted((self.cyc / "logs").glob(f"codex_BUILD_{attempt}_*.log"), key=lambda p: p.stat().st_mtime)
            if report.exists() or (logs and '"type":"turn.started"' in read(logs[-1])):
                return reply
            log(f"codex BUILD_{attempt}: could not resume session {thread[:8]}; starting a fresh run")
        return self.run_codex_main(task, report, f"BUILD_{attempt}", timeout)

    def _codex_build(self, attempt: int, brief: Path, report: Path, note: str = "") -> bool:
        """Codex builds this attempt in the main checkout. False = it could not (limit or no work): DeepSeek builds."""
        head, br, guard = self.git("rev-parse", "HEAD"), self.state["branch"], guard_hash()
        report.unlink(missing_ok=True)
        before = self.tree_fp()
        self._codex_partial = False
        self.save(main_coder="Codex")
        task = self.cyc / f"CODEX_TASK_{attempt}.md"
        write(task, P.coder_scope(note + read(brief)))
        reply = self.run_codex_main(task, report, f"BUILD_{attempt}", int(self.cfg["timeouts"]["build"]))
        # Owner 2026-10-13: cycle 197 lost Codex to "Selected model is at capacity" after 3 min and DeepSeek
        # built it far slower (~55-70 min against ~18). Capacity usually returns within minutes, so wait
        # 2, 4 then 8 min (codex.capacity_wait_s doubling, codex.capacity_retries tries) before DeepSeek builds.
        cx = self.cfg.get("codex", {})
        wait, tries = int(cx.get("capacity_wait_s", 120)), int(cx.get("capacity_retries", 3))
        for n in range(1, tries + 1):
            if report.exists() or not self._codex_stopped(attempt, CAPACITY_RE):
                break
            log(f"Codex model at capacity; retry {n}/{tries} of the build in {wait} s")
            sleep_checked(wait)
            reply = self._codex_retry(attempt, task, report, before)
            wait *= 2
        # Owner 2026-10-13: a Codex usage limit names its reset ("try again at 6:30 AM", cycle 202). A short wait for
        # Codex beats a DeepSeek build, so wait up to codex.limit_wait_max_s for the reset and try once more.
        lim_tail = self._codex_build_tail(attempt)
        at = limit_reset(lim_tail) if not report.exists() and self._codex_stopped(attempt, LIMIT_RE) else None
        secs = (at - datetime.datetime.now()).total_seconds() + 60 if at else None
        if secs is not None and secs <= int(cx.get("limit_wait_max_s", 1200)):
            log(f"Codex usage limit resets at {at:%H:%M}; retrying the build in {max(0, secs) / 60:.0f} min")
            sleep_checked(max(0.0, secs))
            reply = self._codex_retry(attempt, task, report, before)
        if self.git("rev-parse", "--abbrev-ref", "HEAD") != br:
            raise Halt("Codex build switched branches; inspect before restarting")
        if self.git("rev-parse", "HEAD") != head:
            log("Codex build committed; undoing with soft reset (changes kept)")
            self.git("reset", "--soft", head)
        if guard_hash() != guard:
            raise Halt("Codex build modified relay files; inspect before restarting")
        self.sweep_strays()
        log_tail = self._codex_build_tail(attempt)
        limited = not report.exists() and self._codex_stopped(attempt, LIMIT_RE)
        stopped = limited or (not report.exists() and self._codex_stopped(attempt, CAPACITY_RE))
        if stopped and self.tree_fp() != before:
            self._codex_partial = True
            log("Codex stopped part-way through the build; DeepSeek finishes it from the unfinished edits")
        if stopped or (self.tree_fp() == before and not report.exists()):
            if limited or LIMIT_RE.search(log_tail):
                at = limit_reset(log_tail)
                until = at + datetime.timedelta(minutes=1) if at and at > datetime.datetime.now() else \
                    datetime.datetime.now() + datetime.timedelta(hours=int(self.cfg.get("codex", {}).get("limit_pause_h", 6)))
                self.save(codex_main_paused_until=until.strftime("%Y-%m-%d %H:%M:%S"))
                log(f"Codex usage limit on the main build; DeepSeek builds until {until:%b %d %H:%M}")
            elif not self._codex_partial:
                log(f"Codex build changed nothing (attempt {attempt}); DeepSeek builds it")
            return False
        if not report.exists():
            write(report, (reply or "(no report)") + "\n")
        try:
            self.check_coder_report(report)
        except AgentFailed as e:
            self.request_fix([str(e)], 'Complete the report evidence in the existing work; repair code only for unmet criteria.',
                             False, diagnosis=str(e))
            return True
        log(f"Codex build done (attempt {attempt})")
        self.save(phase="TEST", report_file=report.name, last_coder="Codex")
        return True

    def do_build(self) -> None:
        stop = self.start_pre_final_watch()
        try:
            self._do_build()
        finally:
            if stop:
                stop.set()

    def start_pre_final_watch(self) -> threading.Event | None:
        """Owner 2026-10-14 (cycles under 30 min): cycle 235's final review (5.8 min) started only after the
        build, although the coder's last full-suite run (~10 min) had begun on the very tree that was accepted.
        When the coder starts a main-suite run (run_tests.py notes it in suite_starts.json) and the tree still
        matches, the final review starts on a snapshot of it. TEST uses that review only if the tree is unchanged
        when the build ends; otherwise the final review runs as before."""
        self._pre_final = None
        if not (self.parallel_final() and self.cfg.get("chatgpt", {}).get("pre_final", True)):
            return None
        t = self.cfg.get("trusted_coders") or {}
        if (t.get("enabled") and self.cfg.get("main_builder") == "codex" and not int(self.state.get("attempt") or 0)
                and {"Codex", "Claude"} & set(t.get("main") or [])):
            return None   # Codex (or the Claude session) builds attempt 0 and is accepted on its suite
        stop, since = threading.Event(), datetime.datetime.now().isoformat(timespec="seconds")
        cycle, attempt, seen = self.state["cycle"], self.state["attempt"], set()

        def loop() -> None:
            while not stop.wait(PRE_FINAL_POLL):
                try:
                    for s in load_json(SUITE_STARTS, []) or []:
                        key = (s.get("pid"), s.get("at"))
                        if (key in seen or str(s.get("at", "")) < since
                                or Path(s.get("repo", "")).resolve() != Path(self.repo).resolve()):
                            continue
                        seen.add(key)
                        box = self._pre_final
                        if (box and box["thread"].is_alive()) or stop.is_set() or self.tree_fp() != s.get("fp"):
                            continue
                        self._pre_final = self.start_pre_final(s["fp"], cycle, attempt, len(seen), box) or box
                except Exception as e:   # noqa: BLE001 - the final review then runs after the build as before
                    log(f"final review: early start skipped ({type(e).__name__}: {str(e)[:120]})")

        threading.Thread(target=loop, name=f"pre-final-{cycle:03d}-{attempt}", daemon=True).start()
        return stop

    def _snapshot_diff(self, out: Path) -> str | None:
        """Write `git diff --stat` + `git diff` of the whole working tree (new files too) against main, staged in a
        private index so the coder's own index is never touched. Returns the snapshot's git tree (None: no diff)."""
        idx = self.cyc / "logs" / f"{out.stem}.index"
        idx.parent.mkdir(parents=True, exist_ok=True)
        real = Path(self.git("rev-parse", "--path-format=absolute", "--git-path", "index", check=False))
        if real.is_file():
            shutil.copyfile(real, idx)
        env = {**os.environ, "GIT_INDEX_FILE": str(idx)}

        def git(*args: str) -> subprocess.CompletedProcess:
            return subprocess.run(["git", *args], cwd=self.repo, env=env, capture_output=True, text=True,
                                  encoding="utf-8", errors="replace")
        try:
            if git("add", "-A").returncode:
                return False
            stat, diff = git("diff", "--cached", self.main, "--stat"), git("diff", "--cached", self.main)
            if stat.returncode or diff.returncode or not diff.stdout.strip():
                return None
            write(out, stat.stdout + "\n" + diff.stdout)
            tree = git("write-tree")
            return tree.stdout.strip() if tree.returncode == 0 and tree.stdout.strip() else "?"
        finally:
            idx.unlink(missing_ok=True)

    def _pre_final_delta(self, prev: dict | None, tree: str, cycle: int, attempt: int, n: int) -> str:
        """Cycles 285/312/316 (2026-10-15): the coder fixed one test after its first suite run, and the second
        parallel review re-read the whole task (9 min) though only a few lines had changed. When the last review of
        this attempt finished and the change since its snapshot is small, the new review starts from its answer."""
        if (not prev or prev.get("error") is not None or "result" not in prev or len(tree) < 7
                or (prev.get("cycle"), prev.get("attempt")) != (cycle, attempt) or len(prev.get("tree", "")) < 7):
            return ""
        stat = self.git("diff", "--stat", prev["tree"], tree, check=False)
        diff = self.git("diff", prev["tree"], tree, check=False)
        lines = diff.count("\n") + 1
        if not diff.strip() or lines > PRE_FINAL_DELTA_LINES:
            return ""
        rel = f"{self.relay_rel}/cycles/{cycle:03d}"
        delta, earlier = f"PRE_FINAL_DELTA_{attempt}_{n}.patch", f"PRE_FINAL_EARLIER_{attempt}_{n}.md"
        write(self.cyc / delta, stat + "\n\n" + diff + "\n")
        write(self.cyc / earlier, prev["result"][0])
        log(f"final review {attempt}: only {lines} diff lines changed since the last review; checking those")
        return P.FINAL_DELTA.substitute(previous=f"{rel}/{earlier}", delta=f"{rel}/{delta}")

    def start_pre_final(self, fp: str, cycle: int, attempt: int, n: int = 1, prev: dict | None = None) -> dict | None:
        rel = f"{self.relay_rel}/cycles/{cycle:03d}"
        patch = self.cyc / f"PRE_FINAL_DIFF_{attempt}.patch"
        tree = self._snapshot_diff(patch)
        if not tree or self.tree_fp() != fp:
            return None
        if self.light_check(read(patch), attempt == 0):
            log(f"final review {attempt}: not started early; the change is small enough for the light check")
            return None
        review = f"CHATGPT_REVIEW_{attempt}.md"
        write(self.cyc / review, "Second-opinion review is disabled. Inspect the diff and tests yourself.\n")
        prompt = self.final_prompt(tests="RUNNING (see the note below)", report=f"DEEPSEEK_REPORT_{attempt}.md",
                                   review=review, test=f"TEST_OUTPUT_{attempt}.txt")
        old = f"`git diff --cached {self.main} --stat`, `git diff --cached {self.main}`"
        if old not in prompt:
            return None
        prompt = (prompt.replace(old, f"the snapshot diff `{rel}/{patch.name}` (it starts with the --stat)")
                  + P.FINAL_PARALLEL + P.FINAL_PRE.substitute(patch=f"{rel}/{patch.name}", main=self.main)
                  + self._pre_final_delta(prev, tree, cycle, attempt, n))
        box: dict = {"fp": fp, "cycle": cycle, "attempt": attempt, "tree": tree}

        def run() -> None:
            self._tls.bg = True   # the coder is still editing: its changes are not ChatGPT's
            try:
                box["result"] = self.final_verdict(prompt, f"FINAL_PRE_{attempt}_{n}")
            except BaseException as e:   # noqa: BLE001 - handed to the main thread
                box["error"] = e
            finally:
                try:
                    self._tls.bridge and self._tls.bridge.disconnect()
                except Exception:   # noqa: BLE001
                    pass

        box["thread"] = threading.Thread(target=run, name=f"final-pre-{cycle:03d}-{attempt}", daemon=True)
        box["thread"].start()
        log(f"final review {attempt} started while the coder runs the full suite on its finished tree")
        return box

    def take_pre_final(self) -> dict | None:
        box, self._pre_final = getattr(self, "_pre_final", None), None
        if not box or (box["cycle"], box["attempt"]) != (self.state["cycle"], self.state["attempt"]):
            return None
        if box.get("error") is not None:
            return None
        if self.tree_fp() != box["fp"]:
            log(f"final review {box['attempt']}: the coder changed the tree after its test run started; "
                "reviewing the final tree instead")
            return None
        return box

    def _do_build(self) -> None:
        attempt = self.state["attempt"]
        if self._chatgpt_builds():
            log(f"DeepSeek is usage-limited; ChatGPT Chat builds attempt {attempt}")
            self.save(phase="CHATFIX")
            return
        brief = self.cyc / self.state["brief_file"]
        report = self.cyc / f"DEEPSEEK_REPORT_{attempt}.md"
        self._codex_partial = False
        if self._codex_main_attempt(attempt) and self._codex_build(attempt, brief, report):
            return
        if self._mistral_main_attempt(attempt) and self._mistral_build(attempt, brief, report):
            return
        if self._claude_session_attempt(attempt):
            if self.cfg["claude_session"].get("builder") in ("chatgpt", "mistral"):
                # Owner 2026-10-28: "let chatgpt chat do your job, claude usage is low". ChatGPT Chat (a trusted
                # coder) builds it once instead of the Claude session; if it changes nothing, do_chatfix hands the
                # attempt back to BUILD and DeepSeek builds it.
                key = f"{self.state['cycle']}:{attempt}"
                if self.state.get("chat_main_build") != key:
                    log(f"main build: Codex is out; ChatGPT Chat builds attempt {attempt}")
                    self.save(phase="CHATFIX", main_coder="ChatGPT", chat_main_build=key)
                    return
            elif self._claude_session_build(attempt, brief, report):
                return
        self.save(main_coder="DeepSeek")
        instr = (f"Read {brief.as_posix()} and implement it "
                 "completely, following every rule in it.")
        if self._codex_partial:
            instr += (" Codex began this build and stopped part-way (usage limit or capacity); its unfinished edits "
                      "are already in the working tree: check them against the brief, keep what is right, and finish.")
        instr = P.coder_scope(instr)

        # A usage limit is not a failed try: it only switches the model. Cycle 178 (2026-10-12) failed because two free
        # fallback models hit their limits within seconds and each switch used up one of the two build tries.
        t, switches, suite_cut, cut_note = 0, 0, False, ""
        while t < 1 + self.cfg["build_retries"]:
            size = self.task_size("main")
            o = self.opencode_cfg("", size)   # per try: a usage limit switches the model to the fallback
            from lane_local import coder_argv   # OpenCode, or a website coder such as DeepSeek web
            argv = coder_argv(o, cut_note + instr)
            head = self.git("rev-parse", "HEAD")
            log(f"build attempt {attempt} (try {t + 1})"
                + (f" on {o['model']} ({size} task)" if o is not self.cfg["opencode"] else ""))
            # 2026-10-19: four limited models in 30 s each wrote over the one log; a switch now keeps the last one's.
            lp = self.cyc / "logs" / (f"deepseek_{attempt}_{t}" + (f"_switch{switches}" if switches else "") + ".log")
            started = time.time()
            # 2026-10-24: try 1 of cycle 177 ran the full 60 min and try 2 then finished its kept edits in 18 min
            # (the retry note says to finish them), so the first try stops sooner and hands over to try 2.
            limit = self.cfg["timeouts"].get("build_first_try", self.cfg["timeouts"]["build"]) if t == 0 \
                else self.cfg["timeouts"]["build"]
            # 2026-10-25: cycle 222's DeepSeek try ran its full 30 min although Codex's limit reset 26 min in;
            # Codex then finished the kept edits in 7 min. Stop the first try just after the reset instead.
            back = self._codex_back_in_s() if t == 0 else None
            if back is not None and back + 60 < limit:
                limit = max(int(self.cfg.get("codex", {}).get("handover_min_s", 600)), int(back) + 60)
                log(f"build: Codex is back in {back / 60:.0f} min; this try stops after {limit / 60:.0f} min "
                    "so Codex can finish its edits")
            rc, why = self.run_proc(argv, lp, limit, self.cfg["stall_s"])
            if self.git("rev-parse", "--abbrev-ref", "HEAD") != self.state["branch"]:
                raise Halt("agent switched branches; inspect before restarting")
            if self.git("rev-parse", "HEAD") != head:
                log("agent committed; undoing with soft reset (changes kept)")
                self.git("reset", "--soft", head)
            if why == "exit" and rc == 0:
                break
            if why == "exit" and completed_report(report, started):
                log(f"build attempt {attempt}: the coder exited rc={rc} after writing a COMPLETED report; "
                    "checking its work instead of rebuilding it")
                break
            # DS_LIMIT_RE too: a free model's "Model unavailable" (cycle 377, 2026-10-17) is a limit, not a failed try.
            if why == "exit" and (LIMIT_RE.search(tail(read(lp), 2000)) or DS_LIMIT_RE.search(tail(read(lp), 2000))):
                self.mark_opencode_limited("main build", o.get("model", ""), tail(read(lp), 2000))
                if self._chatgpt_builds():
                    log(f"ChatGPT Chat builds attempt {attempt} instead")
                    self.save(phase="CHATFIX")
                    return
                if self.deepseek_limited() and self.fallback_model() and switches < 24:   # 2026-10-19: ~16 models
                    switches += 1
                    continue   # retry this attempt on the fallback model, without using up a try
                raise UsageLimited("deepseek limit")
            if why == "exit" and NET_RE.search(tail(read(lp), 2000)):
                raise NetworkDown("deepseek network problem")
            if why in ("timeout", "stall") and self._coder_suite_on_tree(started):
                log(f"build attempt {attempt}: the coder hit the {why} during its own full-suite run on its finished "
                    "tree; checking its work instead of rebuilding it (the relay runs the suite itself)")
                suite_cut = True
                break
            log(f"build failed: {why}, rc={rc}")
            cut_note = self._retry_note(why, started)
            t += 1
            # Cycle 405 (2026-10-18): DeepSeek started the build 15 min before Codex's limit reset, timed out after
            # 60 min, and try 2 went to DeepSeek again. Codex (~18-20 min a build) finishes it once it is back.
            if t < 1 + self.cfg["build_retries"] and self._codex_main_attempt(attempt):
                log("build: Codex is available again; Codex finishes the stopped build from its unfinished edits")
                if self._codex_build(attempt, brief, report, cut_note):
                    return
                self.save(main_coder="DeepSeek")
        else:
            raise AgentFailed(f"build failed after {1 + self.cfg['build_retries']} tries")

        if not report.exists():
            write(report, "(agent wrote no report)\n")
        try:
            self.check_coder_report(report)
        except AgentFailed as e:
            if not suite_cut:
                self.request_fix([str(e)], 'Complete the report evidence in the existing work; repair code only for unmet criteria.',
                                 False, diagnosis=str(e))
                return
            # the final review verifies every criterion directly; a report cut off by the timeout is not a defect
            log(f"build attempt {attempt}: coder report warning ({str(e)[:160]}); continuing to tests/review")
        self.save(phase="TEST", report_file=report.name, last_coder="DeepSeek")

    def _retry_note(self, why: str, started: float) -> str:
        """Cycle 384 (2026-10-18): try 1 timed out after 60 min with 133 files edited (the bounty change touches ~130
        enemy tests) and try 2 got the same "implement it completely" instruction, so it re-read and re-planned from
        scratch over the kept edits. A retry after a timeout or stall now says the edits are there and to finish."""
        if why not in ("timeout", "stall"):
            return ""
        changed = [l for l in self.git("status", "--porcelain", check=False).splitlines() if l.strip()]
        if not changed:
            return ""
        mins = max(1, round((time.time() - started) / 60))
        return (f"RETRY NOTE: the previous try was stopped by the {why} after {mins} min with {len(changed)} changed "
                "files still in the working tree (see git status and git diff): those are its unfinished edits. Check "
                "them against the brief, keep what is right, finish only what is missing, and do not redo finished "
                "files. Run the related tests first and the full suite once at the end.\n\n")

    def _coder_suite_on_tree(self, since: float) -> bool:
        """Cycle 382 (2026-10-17): the fix attempt finished its edits at 20:45 and started the full suite (~19 min) on
        the finished tree; the 60-min build timeout killed it at 21:02 and the relay started the same fix again. A
        timeout or stall during a main-suite run the coder started on the current tree (run_tests.py notes it in
        suite_starts.json) ends the build: TEST runs the suite itself on that tree."""
        at = datetime.datetime.fromtimestamp(since).isoformat(timespec="seconds")
        try:
            fp, repo = self.tree_fp(), Path(self.repo).resolve()
            return any(str(s.get("at", "")) >= at and s.get("fp") == fp and Path(s.get("repo", "")).resolve() == repo
                       for s in load_json(SUITE_STARTS, []) or [])
        except Exception:   # noqa: BLE001 - unknown means a normal failed try
            return False

    def sweep_strays(self) -> None:
        """Move agent scratch/probe files (untracked, created this cycle) out of the repo."""
        moved = []
        for line in self.git("status", "--porcelain", "-uall", check=False).splitlines():
            if not line.startswith("?? "):
                continue
            path = line[3:].strip().strip('"')
            if (path.startswith((".review/", "addons/")) or path.endswith("_test.gd")
                    or path.endswith("_test.gd.uid")):
                continue
            if STRAY_RE.search(path):
                dest = self.cyc / "stray" / path
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.move(str(self.repo / path), str(dest))
                moved.append(path)
        if moved:
            log(f"moved {len(moved)} stray file(s) out of the repo: {', '.join(moved)}")

    def light_check(self, diff: str, first_try: bool) -> str:
        c = self.cfg.get("light_checks") or {}
        if not c.get("enabled") or not first_try:
            return ""
        return light_change(diff, int(c.get("max_code_lines", 150)), int(c.get("max_test_removed_lines", 10)))

    # Owner 2026-10-26: "Can you make it so codex, chatgpt, and you dont need a chatgpt review when you finish
    # coding". A tree last coded by a coder in trusted_coders.main (Codex, ChatGPT, the Claude session) and lane work
    # coded by a builder in trusted_coders.lanes is accepted on its passing full suite, like a light check. DeepSeek,
    # Gemini and the other lane coders are still reviewed. The suite, the coder-report check and the playtest stay.
    def trusted_main(self) -> str:
        t = self.cfg.get("trusted_coders") or {}
        who = self.state.get("last_coder")
        if t.get("enabled") and who and who in (t.get("main") or []):
            return f"coded by {who}, a trusted coder"
        return ""

    def trusted_lane(self, k: str, lt: dict) -> str:
        t = self.cfg.get("trusted_coders") or {}
        who = lt.get("repair_builder") or (self.cfg.get(k) or {}).get("builder")
        if t.get("enabled") and who and who in (t.get("lanes") or []):
            return f"coded by {'Codex' if who == 'codex' else 'ChatGPT' if who == 'chatgpt' else who}, a trusted coder"
        return ""

    def main_light(self) -> str:
        if self.state.get("code_art_left"):   # owner 2026-11-04: code-drawn visuals always get the review
            return ""
        trusted = self.trusted_main()
        if trusted:
            return trusted
        if not (self.cfg.get("light_checks") or {}).get("enabled") or int(self.state.get("attempt") or 0):
            return ""
        self.git("add", "-A", check=False)
        return self.light_check(self.git("diff", "--cached", self.main, check=False),
                                int(self.state.get("attempt") or 0) == 0)

    def accept_light(self, why: str) -> None:
        out = ("@@REVIEW_START@@\nLight check (owner 2026-10-22/26): a small first-try change, or a trusted coder's "
               f"change, whose full test suite passed is accepted without the ChatGPT review ({why}).\n@@REVIEW_END@@\n")
        log(f"light check: accepted on passing tests without a ChatGPT review ({why})")
        self.record_final(out, {"verdict": "ACCEPTED", "defects": [], "summary": f"light check: {why}"})
        self.save(phase="ACCEPT")

    def accept_lane_light(self, k: str) -> bool:
        """Owner 2026-10-22 ("lighter checks"): a lane's small first-try change whose suite passed is accepted
        without its ChatGPT lane review."""
        lt = self.state.get(f"{k}_task") or {}
        if (not lt.get("branch") or not lt.get("tests_ok") or lt.get("evidence_warning")
                or not ((self.cfg.get("light_checks") or {}).get("enabled") or self.trusted_lane(k, lt))):
            return False
        base = lt.get("base_start") or lt.get("base_commit")
        why = self.trusted_lane(k, lt)
        if not why:
            diff = self.git("diff", f"{base}..{lt['branch']}" if base else f"{self.main}...{lt['branch']}", check=False)
            why = self.light_check(diff, not lt.get("prev_defects") and not int(lt.get("fix_rounds") or 0))
        if not why or not self._lane_update(k, lt["branch"], reviewing=False, review_finished_at=time.time(),
                                            review={"verdict": "ACCEPTED", "summary": f"light check: {why}"}):
            return False
        log(f"{k}: review ACCEPTED (light check: {why}; its suite passed, no ChatGPT review)")
        self.prefetch_lane_task(k, lt)
        return True

    def parallel_final(self) -> bool:
        g = self.cfg.get("chatgpt", {})
        return (not g.get("review", True) and g.get("parallel_final") is not False
                and self.role("FINAL") == "chatgpt")

    def start_early_final(self) -> dict:
        """Owner 2026-10-13: with the second-opinion review off, the final review (~8.5 min) runs while the suite
        runs (~7.5 min) instead of after it. Its verdict counts only if the suite passes."""
        a = self.state["attempt"]
        pre = self.take_pre_final()
        self.git("add", "-A")
        name = f"CHATGPT_REVIEW_{a}.md"
        write(self.cyc / name, "Second-opinion review is disabled. Inspect the diff and tests yourself.\n")
        self.save(review_file=name, test_file=f"TEST_OUTPUT_{a}.txt")
        if pre:
            log(f"final review {a}: using the review started during the coder's test run (the tree is unchanged)")
            try:
                self.start_early_refresh(during_final=True)
            except Exception as e:   # noqa: BLE001 - the next cycle refreshes as before
                log(f"plan: early refresh skipped ({type(e).__name__}: {str(e)[:120]})")
            return pre
        prompt = self.final_prompt(tests="RUNNING (see the note below)") + P.FINAL_PARALLEL
        box: dict = {"thread": None}

        def run() -> None:
            try:
                box["result"] = self.final_verdict(prompt, f"FINAL_EARLY_{a}")
            except BaseException as e:   # noqa: BLE001 - handed to the main thread
                box["error"] = e
            finally:
                try:
                    self._tls.bridge and self._tls.bridge.disconnect()
                except Exception:   # noqa: BLE001
                    pass

        box["thread"] = threading.Thread(target=run, name=f"final-early-{self.state['cycle']:03d}-{a}", daemon=True)
        box["thread"].start()
        log(f"final review {a} started in parallel with the tests")
        try:
            self.start_early_refresh(during_final=True)
        except Exception as e:   # noqa: BLE001 - the next cycle refreshes as before
            log(f"plan: early refresh skipped ({type(e).__name__}: {str(e)[:120]})")
        return box

    def wait_early_final(self, box: dict) -> tuple[str, dict] | None:
        t, n = box["thread"], 0
        if t.is_alive():
            log("tests done; waiting for the parallel final review")
        while t.is_alive():
            t.join(5)
            n += 1
            if STOP_PATH.exists():
                raise Halt("STOP requested")
            if n % 12 == 0:
                self.save(heartbeat=ts())
        e = box.get("error")
        if isinstance(e, Halt):
            raise e
        if e is not None:
            log(f"parallel final review failed ({type(e).__name__}: {str(e)[:160]}); reviewing after the tests instead")
            return None
        return box.get("result")

    def code_art_fix(self) -> bool:
        """Owner 2026-11-04 ("make sure that art isnt done with code since it looks bad"): the first time the main
        change adds code-drawn visuals it goes back to the coder before the suite (True). Any left after that fix
        only block the light and trusted acceptance (code_art_left), so the ChatGPT review decides."""
        if (self.cfg.get("code_art_check") or {}).get("enabled", True) is False:
            return False
        self.git("add", "-A", check=False)
        found = code_art_lines(self.git("diff", "--cached", self.main, check=False))
        if found and not self.state.get("code_art_flagged"):
            self.save(code_art_flagged=True)
            log(f"the change draws visuals in code ({len(found)} line(s), e.g. {found[0][:90]}); "
                "sending it back for authored images before the tests")
            self.request_fix([P.code_art_defect(found)], "", check_progress=False)
            return True
        if bool(found) != bool(self.state.get("code_art_left")):
            self.save(code_art_left=bool(found))
        if found:
            log(f"the change still draws visuals in code ({len(found)} line(s)); the review decides")
        return False

    def do_test(self) -> None:
        self.start_lane_checker()
        self.finish_art_bg()
        self.sweep_strays()
        if self.code_art_fix():
            return
        light = self.main_light()
        early = self.start_early_final() if self.parallel_final() and not light else None
        if light:
            self._pre_final = None
        fp = self.tree_fp()
        reuse = self.coder_suite_pass(fp)
        if reuse:
            lp = self.cyc / f"TEST_OUTPUT_{self.state['attempt']}.txt"
            write(lp, f"Reused the coder's passing full-suite run from {reuse['at']} ({reuse.get('summary')}): "
                      f"the working tree is identical (fingerprint {fp}).\n\n"
                      # on its own line, as run_tests.py prints it: the cycle health check reads it
                      f"{reuse.get('summary') or ''}\n")
            passed = True
            log(f"tests {lp.stem}: PASS (reused the coder's full-suite run from {reuse['at'][11:16]}; "
                "nothing changed since)")
        else:
            passed, lp = self.run_tests(self.cyc, f"TEST_OUTPUT_{self.state['attempt']}")
        # The tree the suite ran on: a reviewer edit made during the run makes ACCEPT test again.
        self.save(tests_passed=passed, test_file=lp.name, tested_fp=fp if passed else None)
        if passed:
            self.save(prev_test_fails=[])
            got = self.wait_early_final(early) if early else None
            if got:
                self.apply_final(*got)
            elif light:
                self.accept_light(light)
            else:
                self.save(phase="REVIEW")
            return
        fails = sorted(re.findall(r"^FAIL (\S+)", read(lp), re.M))
        repeated = bool(fails and fails == self.state.get('prev_test_fails'))
        self.save(prev_test_fails=fails)
        defects = [f"Test suite fails. See {self.relay_rel}/cycles/{self.state['cycle']:03d}/{lp.name}. "
                   "Fix the failures without weakening or deleting tests."]
        notes = tail(read(lp), 6000)
        got = self.wait_early_final(early) if early else None
        if got and got[1]["verdict"] == "FIX_REQUIRED":
            # One fix round for both: the review that ran alongside the tests already found these.
            out, v = got
            self.record_final(out, v)
            defects += v["defects"]
            notes += ("\n\n## Final review (ran in parallel with the tests)\n" + (extract(out, "REVIEW") or out)
                      + "\n\n## Reviewer diagnosis\n" + (extract(out, "DIAGNOSIS") or "(none)"))
            log(f"tests failed; the parallel final review adds {len(v['defects'])} defect(s) to the same fix")
        self.request_fix(defects, notes, check_progress=False, repeated=repeated)

    def coder_suite_pass(self, fp: str) -> dict | None:
        """Owner 2026-10-13 (cycles under 30 min): the coder's last full-suite run passed on exactly this working
        tree (run_tests.py records it in suite_passes.json), so TEST reuses it instead of a third ~9 min run. Any
        later edit changes the fingerprint; the independent review still runs."""
        if not self.cfg.get("reuse_coder_suite", True):
            return None
        try:
            rec = (load_json(HERE / "suite_passes.json", {}) or {}).get(fp)
            if not isinstance(rec, dict) or Path(rec["repo"]).resolve() != Path(self.repo).resolve():
                return None
            age = (datetime.datetime.now() - datetime.datetime.fromisoformat(rec["at"])).total_seconds()
        except (OSError, ValueError, KeyError, TypeError, AttributeError):
            return None
        return rec if 0 <= age <= 3 * 3600 else None

    def do_review(self) -> None:
        self.git("add", "-A")
        name = f"CHATGPT_REVIEW_{self.state['attempt']}.md"
        out = self.cyc / name
        if not self.cfg["chatgpt"].get("review", True):
            # Owner choice 2026-10-06: no second-opinion review; the FINAL reviewer inspects the diff itself and
            # the post-accept playtest checks the visuals.
            write(out, "Second-opinion review is disabled. Inspect the diff and tests yourself.\n")
            self.save(phase="FINAL", review_file=name)
            return
        if self.cfg["chatgpt"].get("file_mode"):
            attempt = self.state["attempt"]
            prev = sorted(p for p in self.cyc.glob("CHATGPT_REVIEW_*.md")
                          if p.stem.rsplit("_", 1)[-1].isdigit() and int(p.stem.rsplit("_", 1)[-1]) < attempt)
            rejection = self.cyc / f"REJECTION_{attempt}.md"
            if self.cfg["chatgpt"].get("focused_rereview", True) and prev and rejection.exists():
                # A full review already happened this cycle: only check the fix (chat mode, faster).
                prompt, tag = P.REVIEW_FIX_FILE.substitute(
                    repo=self.repo, main=self.main, tests="PASSED", out_path=out,
                    defects_path=rejection, prev_review_path=prev[-1],
                    brief_path=self.cyc / self.state["brief_file"],
                    report_path=self.cyc / self.state["report_file"],
                    test_path=self.cyc / self.state["test_file"]), "REVIEW_FIX"
            else:
                prompt, tag = P.REVIEW_FILE.substitute(
                    repo=self.repo, main=self.main, tests="PASSED", out_path=out,
                    plan_path=self.cyc / "CLAUDE_PLAN.md", brief_path=self.cyc / self.state["brief_file"],
                    report_path=self.cyc / self.state["report_file"],
                    test_path=self.cyc / self.state["test_file"]), "REVIEW"
            got = self.chatgpt_file(prompt, tag, out)
            if got:
                try:
                    parse_verdict(got)
                except ValueError as e:
                    write(out, got + f"\n\n(controller: verdict unparseable: {e})\n")
            else:
                write(out, "Second-opinion review unavailable.\n")
            self.save(phase="FINAL", review_file=name)
            return

        stat = self.git("diff", "--cached", self.main, "--stat")
        diff = self.git("diff", "--cached", self.main)
        parts = dict(
            tests="PASSED",
            plan=read(self.cyc / "CLAUDE_PLAN.md"),
            brief=read(self.cyc / self.state["brief_file"]),
            report=tail(read(self.cyc / self.state["report_file"]), 6000),
            test_tail=tail(read(self.cyc / self.state["test_file"]), 3000),
            main=self.main, stat=stat,
        )
        base = len(P.REVIEW.substitute(**parts, diff="", truncated=""))
        budget = self.cfg["chatgpt"]["max_chars"] - base - 200
        truncated = "" if len(diff) <= budget else "(TRUNCATED: read stat for full scope) "
        prompt = P.REVIEW.substitute(**parts, diff=diff[:max(budget, 0)], truncated=truncated)
        reply = self.chatgpt(prompt, "REVIEW", "VERDICT") if budget > 2000 else None
        if reply:
            body = extract(reply, "REVIEW") or reply
            try:
                v = json.dumps(parse_verdict(reply), indent=2)
            except ValueError as e:
                v = f"(unparseable verdict: {e})"
            write(out, f"{body}\n\n## Verdict\n{v}\n")
        else:
            write(out, "Second-opinion review unavailable.\n")
        self.save(phase="FINAL", review_file=name)

    def final_prompt(self, tests: str = "PASSED", report: str = "", review: str = "", test: str = "") -> str:
        c = self.cyc
        rel = f"{self.relay_rel}/cycles/{self.state['cycle']:03d}"
        prompt = P.FINAL.substitute(
            plan_path=f"{rel}/CLAUDE_PLAN.md", brief_path=f"{rel}/{self.state['brief_file']}",
            report_path=f"{rel}/{report or self.state['report_file']}",
            review_path=f"{rel}/{review or self.state['review_file']}",
            test_path=f"{rel}/{test or self.state['test_file']}", tests=tests, main=self.main)
        a = self.state['attempt']
        previous = [n for n in range(a) if (c / f'CLAUDE_FINAL_{n}.md').exists()]
        if previous and self.cfg.get('chatgpt', {}).get('focused_final', True):
            prev = previous[-1]
            prompt += P.FINAL_REPAIR.substitute(
                original_brief=f'{rel}/DEEPSEEK_BRIEF.md', previous_review=f'{rel}/CLAUDE_FINAL_{prev}.md',
                previous_diff=f'{rel}/REVIEWED_DIFF_{prev}.patch', rejection=f'{rel}/REJECTION_{a}.md')
        return prompt

    def final_verdict(self, prompt: str, tag: str) -> tuple[str, dict]:
        v = out = None
        for _ in (1, 2):
            out = self.think(prompt, tag)
            try:
                v = parse_verdict(out)
                break
            except ValueError as e:
                log(f"final verdict unparseable: {e}")
        if v is None:
            raise AgentFailed("final verdict unparseable twice")
        return out, v

    def record_final(self, out: str, v: dict) -> None:
        c, a = self.cyc, self.state['attempt']
        write(c / f"CLAUDE_FINAL_{a}.md", out)
        write(c / f'REVIEWED_DIFF_{a}.patch', self.git('diff', '--cached', self.main, check=False))
        save_json(c / f"verdict_{a}.json", v)
        log(f"final verdict: {v['verdict']} ({len(v['defects'])} defects)")

    def do_final(self) -> None:
        self.apply_final(*self.final_verdict(self.final_prompt(), "FINAL"))

    def apply_final(self, out: str, v: dict) -> None:
        self.git("add", "-A", check=False)   # include anything written since the parallel review staged the tree
        self.record_final(out, v)
        if v["verdict"] == "ACCEPTED":
            self.save(phase="ACCEPT")
        elif v['verdict'] == 'DEFERRED':
            raise ScopeDeferred(v['summary'])
        else:
            self.request_fix(v["defects"], extract(out, "REVIEW") or out, check_progress=True,
                             diagnosis=extract(out, "DIAGNOSIS"))

    def triage(self, attempt: int, defects: list[str], notes: str, diagnosis: str | None = None) -> str | None:
        """ChatGPT (chat mode, file tools) diagnoses the rejection before DeepSeek's fix attempt.
        Best effort: any failure just means the fix brief goes out without a diagnosis."""
        g = self.cfg["chatgpt"]
        rej = self.cyc / f"REJECTION_{attempt}.md"
        out = self.cyc / f"TRIAGE_{attempt}.md"
        write(rej, "## Defects\n" + "\n".join(f"- {d}" for d in defects) + f"\n\n## Notes\n{notes}\n")
        if diagnosis and diagnosis.strip():
            # The final reviewer already diagnosed its own defects: no separate TRIAGE message (~3 min, 1 message).
            write(out, diagnosis.strip() + "\n")
            log(f"triage {attempt}: diagnosis taken from the final review")
            return diagnosis.strip()[:8000]
        if not (g.get("enabled") and g.get("file_mode") and g.get("triage", True)):
            return None
        got = self.chatgpt_file(P.TRIAGE_FILE.substitute(
            brief_path=self.cyc / "DEEPSEEK_BRIEF.md", defects_path=rej,
            report_path=self.cyc / (self.state.get("report_file") or "DEEPSEEK_REPORT_0.md"),
            repo=self.repo, out_path=out), "TRIAGE", out)
        if got:
            log(f"triage {attempt}: diagnosis written")
        return got.strip()[:8000] if got else None

    def regenerate_defective_assets(self, defects: list[str]) -> list[str]:
        """A defect about the CONTENT of a paper-art image cannot be fixed by the coding agent: the relay
        regenerates that image itself (same path, so code keeps working). Objects requested as full-canvas
        terrain/backgrounds are redrawn as transparent props."""
        if not self.cfg.get("art", {}).get("enabled"):
            return []
        pat = re.compile(r"assets/paper/([a-z_]+)/([a-z0-9_]+)\.png")
        kw = re.compile(r"regenerat|background|transparen|\btext\b|glyph|letter|redraw|re-?generate|wrong (art|image)", re.I)
        found = []
        for d in defects:
            if kw.search(d):
                for c, i in pat.findall(d):
                    if (c, i, d) not in found and (c, i) not in [(x[0], x[1]) for x in found]:
                        found.append((c, i, d))
        if not found:
            return []
        from art_gen import ArtGenerator, ArtError, CATEGORIES, asset_path, build_prompt, process, RAW_DIR
        gen = ArtGenerator(self.cfg["chatgpt"], log, STOP_PATH.exists)
        requested = {(a["category"], a["id"]): a["description"] for a in (self.state.get("assets") or [])}
        lines = []
        for c, i, d in found[:3]:
            if c not in CATEGORIES:
                continue
            shape = "props" if c in ("terrain", "backgrounds") and re.search(
                r"transparen|background|flag|sign|marker|plot|object", d, re.I) else c
            desc = requested.get((c, i), i.replace("_", " "))
            try:
                raw = gen.generate_any(build_prompt(shape, f"{desc}. Must avoid this problem: {d[:300]}"))
                RAW_DIR.mkdir(parents=True, exist_ok=True)
                (RAW_DIR / f"{c}__{i}.png").write_bytes(raw)
                process(raw, asset_path(self.repo, c, i), shape)
                lines.append(f"- assets/paper/{c}/{i}.png: regenerated by the relay"
                             + (" as a transparent object" if shape != c else ""))
                log(f"art: regenerated assets/paper/{c}/{i}.png for a review defect")
            except ArtError as e:
                lines.append(f"- assets/paper/{c}/{i}.png: regeneration failed ({str(e)[:100]}); keep a code fallback")
        return lines

    def request_fix(self, defects: list[str], notes: str, check_progress: bool,
                    diagnosis: str | None = None, repeated: bool = False) -> None:
        attempt = self.state["attempt"] + 1
        mx = self.cfg["max_fix_attempts"]
        if attempt > mx:
            raise AgentFailed(f"max fix attempts ({mx}) reached")
        repeated = repeated or (check_progress and similar(defects, self.state.get('prev_defects') or []))
        fx = self.cfg.get('chatgpt_fixer', {})
        if repeated:
            if (not fx.get('enabled') or self.state.get('repeated_backup_used')
                    or self.state.get('last_repair_builder') == 'chatgpt'):
                self.save(repair_exhausted=True)
                raise AgentFailed('no progress: same defects persisted after the backup repair or backup is unavailable')
            self.save(repeated_backup_used=True)
            log('same defect survived a repair; handing the precise repair to ChatGPT before rescue')
        regenerated = self.regenerate_defective_assets(defects)
        if regenerated:
            notes = ("### Art fixed by the relay (do not edit PNGs; just make sure the code uses them correctly)\n"
                     + "\n".join(regenerated) + "\n\n" + notes)
        diagnosis = self.triage(attempt, defects, notes, diagnosis)
        if diagnosis:
            notes = f"### Diagnosis (ChatGPT triage, read first)\n{diagnosis}\n\n### Raw notes\n{notes}"
        report = f"DEEPSEEK_REPORT_{attempt}.md"
        text = P.FIX.substitute(
            cycle=f"{self.state['cycle']:03d}", attempt=attempt, max_attempts=mx,
            defects="\n".join(f"- {d}" for d in defects), notes=notes,
            original=read(self.cyc / "DEEPSEEK_BRIEF.md").split("\n---\n## Relay rules")[0],
        ) + self.hard_rules(report)
        name = f"FIX_BRIEF_{attempt}.md"
        write(self.cyc / name, text)
        to_chat = bool(fx.get("enabled")) and (repeated or attempt >= int(fx.get("from_attempt", 2)))
        self.save(phase="CHATFIX" if to_chat else "BUILD", attempt=attempt, brief_file=name,
                  last_repair_builder='chatgpt' if to_chat else 'deepseek', last_coder=None,
                  prev_defects=defects if check_progress else self.state.get("prev_defects", []))
        log(f"fix requested: attempt {attempt}/{mx}" + (f" ({fx.get('builder', 'chatgpt')} codes this one)" if to_chat else ""))

    def run_codex_main(self, task_path: Path, report: Path, tag: str, timeout: int,
                       resume: str = "") -> str | None:
        """Codex CLI edits the main working tree (current cycle branch) for a backup fix or rescue. Returns its
        final message, or None when it failed; the caller checks branch, commits and relay files as before."""
        from lane_local import codex_argv, SUBAGENT_HINT
        cx = self.cfg.get("codex_cli", {})
        instr = (f"Read {task_path} and carry it out completely in this repository ({self.repo}, branch "
                 f"{self.state['branch']}). Follow every rule in it. Run the full tests with exactly: "
                 f"{' '.join(self.cfg['test_cmd'])} (Godot only --headless). Never commit, switch branches, reset, "
                 f"stash or merge, never edit .review/ or PNG files. "
                 + (SUBAGENT_HINT.strip("- \n") + ". " if cx.get("subagents", True) else "")
                 + f"Write your report to {report}.")
        last = self.cyc / f"{tag}_LAST_MESSAGE.md"
        argv = codex_argv(cx, {}, self.repo, instr, last, images=self.state.get("coder_refs") or [])
        if resume and "--add-dir" not in argv:
            # `codex exec resume` keeps the session's directory and takes no --cd/--sandbox flags (Codex 0.162)
            i = argv.index("--cd")
            del argv[i:i + 2]
            i = argv.index("--sandbox")
            argv[i:i + 2] = ["-c", f'sandbox_mode="{argv[i + 1]}"']
            argv[1:2] = ["exec", "resume"]
            argv[-1:] = [resume, "Your run stopped part-way (the model was at capacity or hit its usage limit). "
                         "Continue the same task from where you stopped; your unfinished edits are in the working "
                         "tree. " + instr]
        lp = self.cyc / "logs" / f"codex_{tag}_{int(time.time())}.log"
        log(f"codex {tag} (fallback coder{', resuming session ' + resume[:8] if resume else ''})")
        rc, why = self.run_proc(argv, lp, timeout, max(int(self.cfg.get("stall_s", 600)), 1200))
        if why != "exit" or rc:
            log(f"codex {tag} ended ({why}, rc={rc}): {tail(read(lp), 300)}")
        return read(last) if last.exists() else None

    def do_chatfix(self) -> None:
        """ChatGPT (chat mode, SentinelX) applies this fix attempt itself, as DeepSeek's backup coder."""
        attempt = self.state["attempt"]
        brief = self.cyc / self.state["brief_file"]
        report = self.cyc / f"DEEPSEEK_REPORT_{attempt}.md"
        head, br, guard = self.git("rev-parse", "HEAD"), self.state["branch"], guard_hash()
        report.unlink(missing_ok=True)
        fx = self.cfg.get("chatgpt_fixer", {})
        who = "Codex" if fx.get("builder") == "codex" else "ChatGPT"
        before = self.tree_fp()
        if fx.get("builder") == "codex":   # owner 2026-10-10: Codex is the fallback coder
            reply = self.run_codex_main(brief, report, f"CHATFIX_{attempt}", int(fx.get("timeout", 3600)))
        else:
            try:   # best effort: skipped while another ask holds the Chrome
                from chatgpt_bridge import refresh_idle_chrome
                refresh_idle_chrome(self.cfg["chatgpt"], log, max_age_s=BUILD_CHROME_MAX_AGE_S)
            except Exception as e:   # noqa: BLE001
                log(f"chrome: restart before the build failed ({type(e).__name__}: {str(e)[:120]})")
            prompt = P.RESCUE_CHATGPT.substitute(task_path=brief, report_path=report, repo=self.repo,
                                                 test_cmd=" ".join(self.cfg["test_cmd"]))
            write(self.cyc / f"CHATFIX_{attempt}_PROMPT.md", prompt)
            imgs = [f for f in self.state.get("coder_refs") or [] if Path(f).exists()]
            for again in (False, True):
                reply = self._ask_chatgpt(prompt, "CHATFIX", attempt, timeout=int(fx.get("timeout", 3600)),
                                          done=settled(report), **({"files": imgs} if imgs else {}))
                # Owner 2026-11-05: a build lost to a bridge error (relay Chrome hang/restart) went straight to
                # DeepSeek, which rebuilds from scratch in 30-50 min; ChatGPT gets one more ask first.
                if reply is not None or again or self.tree_fp() != before or report.exists():
                    break
                log(f"{who} build lost to a bridge error (relay Chrome hang or restart); asking {who} once more "
                    f"before DeepSeek")
        if self.git("rev-parse", "--abbrev-ref", "HEAD") != br:
            raise Halt("ChatGPT fix switched branches; inspect before restarting")
        if self.git("rev-parse", "HEAD") != head:
            log(f"{who} fix committed; undoing with soft reset (changes kept)")
            self.git("reset", "--soft", head)
        if guard_hash() != guard:
            raise Halt("ChatGPT fix modified relay files; inspect before restarting")
        self.sweep_strays()
        if self.tree_fp() == before and not report.exists():
            if self._chatgpt_builds():   # DeepSeek is limited: do not bounce between BUILD and CHATFIX
                raise UsageLimited(f"{who} build changed nothing while DeepSeek is usage-limited")
            log(f"{who} fix changed nothing; DeepSeek takes attempt {attempt}")
            self.save(phase="BUILD")
            return
        if not report.exists():
            write(report, (reply or "(no report)") + "\n")
        self.check_coder_report(report)
        if self.tree_fp() == before:
            log(f"{who} fix reported no code changes (attempt {attempt}); validating existing work")
        else:
            log(f"{who} fix applied (attempt {attempt})")
        self.save(phase="TEST", report_file=report.name, last_coder=who)

    def tree_fp(self) -> str:
        """Actual working content; staging an unchanged new file must not invalidate passing tests."""
        h = hashlib.sha256(b'working-content-v2\0' + self.git("rev-parse", "HEAD", check=False).encode())
        changed = self.git('diff', 'HEAD', '--name-only', '-z', check=False).split('\0')
        untracked = self.git('ls-files', '--others', '--exclude-standard', '-z', check=False).split('\0')
        for rel in sorted(set(changed + untracked) - {''}):
            p = self.repo / rel
            h.update(rel.encode() + b'\0')
            h.update(b'FILE\0' + p.read_bytes() if p.is_file() else b'DELETED\0')
        return h.hexdigest()

    def cycle_health_check(self, outcome: str) -> None:
        """Diagnostic only: never pause, repair, rescue or reclassify cycle work."""
        self.record_cycle_timing(outcome)
        try:
            from health_check import inspect_cycle, record
            with self._save_lock:
                snapshot = json.loads(json.dumps(self.state))
            report = inspect_cycle(HERE, snapshot, self.cfg, outcome)
            record(HERE, report)
            issues = [c['name'] for c in report['checks'] if c['status'] != 'PASS']
            log(f"health cycle {snapshot['cycle']:03d}: {report['status']}"
                + (f" ({', '.join(issues)})" if issues else ''))
        except Exception as e:
            # An unavailable diagnostic must not send accepted work back to rescue.
            log(f"health cycle {self.state.get('cycle', 0):03d}: WARN check unavailable ({type(e).__name__}: {e})")

    def record_cycle_timing(self, outcome: str) -> None:
        if not self.fast_cycles():
            return
        try:
            timing = TP.cycle_timing(self.state.get('timeline', []), ts(),
                                     float(self.cfg['cycle_budget'].get('target_minutes', 30)))
            timing['duration_within_target'] = timing['target_met']
            timing['target_met'] = outcome == 'ACCEPTED' and timing['target_met']
            report = {'cycle': self.state['cycle'], 'outcome': outcome, **timing}
            save_json(self.cyc / 'CYCLE_BUDGET.json', report)
            write(self.cyc / 'CYCLE_BUDGET.md',
                  f"# Cycle {self.state['cycle']:03d} timing\n\n{outcome}: {timing['active_minutes']:.2f} active minutes "
                  f"({timing['build_minutes']:.2f} building, {timing['wait_minutes']:.2f} waiting for the plan); "
                  f"{timing['wall_minutes']:.2f} wall minutes. Target: building under {timing['target_minutes']:g} minutes. "
                  f"Target {'met' if timing['target_met'] else 'missed'}.\n\n"
                  'Full tests and independent acceptance are required even after an overrun.\n')
            with self._save_lock:
                key = {'ACCEPTED': 'history', 'FAILED': 'failed', 'DEFERRED': 'deferred'}[outcome]
                entries = self.state.get(key) or []
                if entries and entries[-1].get('cycle') == self.state['cycle']:
                    entries[-1].update(timing)
                self.save()
            # A DEFERRED/FAILED cycle inside the time is not an overrun (cycle 280 logged "overrun" at 16.8/30).
            verdict = ('target met' if timing['target_met'] else
                       f'within time but {outcome}' if timing['duration_within_target'] else
                       'overrun; plan a smaller useful next task')
            log(f"cycle budget: {timing['build_minutes']:.1f}/{timing['target_minutes']:g} minutes building "
                f"(+{timing['wait_minutes']:.1f} waiting for the plan); {verdict}")
        except Exception as e:
            log(f'cycle timing unavailable: {type(e).__name__}: {e}')

    def do_accept(self) -> None:
        if self.state.get("tested_fp") and self.state["tested_fp"] == self.tree_fp():
            log("tests: nothing changed since the passing test run; not re-running them")
        else:
            passed, lp = self.run_tests(self.cyc, "TEST_OUTPUT_final")
            if not passed:
                self.request_fix([f"Tests fail at acceptance. See {lp.name}."], tail(read(lp), 6000), False)
                return
        n, br = self.state["cycle"], self.state["branch"]
        self.git("add", "-A")
        if self.git_ok("diff", "--cached", "--quiet"):
            log("accepted cycle has no changes; nothing to commit")
        else:
            self.git("commit", "-m", f"{G.NAME} cycle {n:03d}: {self.state['title']}\n\n"
                                     "Accepted by relay v2 (Claude final review, tests green).")
        self.git("checkout", self.main)
        for tries in range(6):   # a transient index lock from another git process must not halt the relay
            r = subprocess.run(["git", "merge", "--ff-only", br], cwd=self.repo, capture_output=True, text=True)
            if r.returncode == 0:
                break
            log(f"accept merge attempt {tries + 1} failed: {(r.stderr or r.stdout).strip()[-200:]}")
            if "index.lock" not in (r.stderr + r.stdout) and "lock" not in (r.stderr + r.stdout).lower():
                break
            time.sleep(3)
        if r.returncode:
            raise Halt(f"{self.main} moved; cannot fast-forward {br}. Merge manually, then set phase IDLE.")
        commit = self.git("rev-parse", "--short", "HEAD")
        self.save(tested_main=self.git("rev-parse", "HEAD"), tested_fp=None)
        self.git("branch", "-d", br, check=False)
        if self.git_ok("remote", "get-url", self.cloud.remote):
            if not self.git_ok("push", self.cloud.remote, self.main):
                log(f"warning: could not push {self.main} to {self.cloud.remote}")
        self.state["history"].append({"cycle": n, "title": self.state["title"], "commit": commit, "at": ts(),
                                      "milestone": self.state.get("milestone"),
                                      "fix_attempts": self.state.get("attempt", 0),
                                      "rescued": bool(self.state.get("rescued")),
                                      "unwired": self._unwired_count()})
        self.save(phase="IDLE", last_good_commit=commit, note=f"cycle {n:03d} accepted", consecutive_failures=0)
        write(self.cyc / "TIMELINE.md", timeline_text(self.state.get("timeline", [])))
        log(f"=== cycle {n:03d} ACCEPTED -> {commit} ===")
        self.begin_slow_check(n)
        self.cycle_health_check('ACCEPTED')
        notify(f"{G.NAME} cycle {n:03d} accepted", self.state["title"] or "")
        # Owner 2026-10-31: per-cycle lessons are off by default (chatgpt.cycle_lessons); lanes still teach
        if (self.state.get("attempt", 0) > 0 or self.state.get("rescued")) and self.cfg["chatgpt"].get("cycle_lessons", False):
            self.learn_lessons()
        self.maybe_design_review(n)
        self.maybe_playtest(n, commit)

    def maybe_playtest(self, n: int, commit: str) -> None:
        """Best effort: export the accepted build for the Web, screenshot fixed scenarios in headless
        Chrome, and have Claude review the screenshots. The planner reads the newest report."""
        pc = self.cfg.get("playtest") or {}
        if not pc.get("enabled"):
            return
        why = self._playtest_due(n, pc)
        if not why:
            return
        self.save(last_playtest_cycle=n, last_playtest_ts=time.time(), visual_fixes_since_playtest=0)
        log(f"playtest: due ({why})")
        title = self.state.get("title") or ""
        if pc.get("background", True):
            prev = getattr(self, "_pt_thread", None)
            if prev and prev.is_alive():
                log("playtest: the previous playtest is still running; waiting for it")
                prev.join()

            def run() -> None:
                self._tls.bg = True
                try:
                    self.run_playtest(n, commit, title)
                except Exception as e:   # noqa: BLE001
                    log(f"playtest skipped: {e!r}")

            self._pt_thread = threading.Thread(target=run, name=f"playtest-{n:03d}", daemon=True)
            self._pt_thread.start()
            return
        try:
            self.run_playtest(n, commit, title)
        except Halt:
            raise
        except Exception as e:
            log(f"playtest skipped: {e!r}")

    SMOKE_SCENES = ["title"]  # the game's own list goes in relay.json playtest.smoke_scenes

    def run_smoke_check(self, n: int, commit: str, pc: dict, root: Path, shots: Path) -> Path:
        """Owner 2026-10-08: no big review. Play through a few screens, screenshot them, and have ChatGPT (chat mode,
        images attached) report only what is clearly broken. Crashes and console errors are reported even without
        an answer. Claude is not used."""
        from playtest import Playtest
        names = list(pc.get("smoke_scenes") or self.SMOKE_SCENES)
        log(f"smoke check: exporting {commit} and screenshotting {len(names)} screens")
        t0 = time.time()
        res = Playtest(pc, self.repo, log).capture(commit, shots, names)
        files, problems = [], []
        for name in names:
            r = res.get(name)
            if r:   # the harness's own showcase scene warns about a stale UID on every screen: not a game problem
                r = {**r, "errors": [e for e in r.get("errors", []) if "showcase" not in e and not e.startswith("WARNING:")
                                    and not e.strip().startswith("at:")]}   # Godot prints a warning's location as its own line
            if not r:
                problems.append(f"- {name}: scenario did not run")
                continue
            got = [Path(p) for p in r.get("shots", []) if Path(p).is_file()]
            pick = [p for p in got if p.stem.endswith("_wave")] or got[-1:]
            files += pick
            if not r.get("ok"):
                problems.append(f"- {name}: did not load ({'; '.join(r.get('errors', [])[-3:])[:300]})")
            elif r.get("errors"):
                problems.append(f"- {name}: console errors: {'; '.join(r['errors'][:3])[:300]}")
        log(f"smoke check: {len(files)} screenshots in {time.time() - t0:.0f}s")
        verdict = ""
        if files:
            text = P.SMOKE_CHECK.substitute(cycle=f"{n:03d}", commit=commit, errors=(
                "\nThe harness also reported:\n" + "\n".join(problems) + "\n") if problems else "")
            for attempt in (1, 2):
                verdict = extract(self._ask_chatgpt(text, "SMOKE", attempt, files=files) or "", "REPORT") or ""
                if verdict.strip():
                    break
        if not verdict.strip():
            # Never report "none" when nobody looked at the screenshots (cycle 111's upload failure read as all clear).
            verdict = (f"# Smoke check after cycle {n:03d} ({commit})\n"
                       "## Visual review NOT DONE: ChatGPT gave no answer; the screenshots were not checked\n"
                       "## Blockers\n" + ("\n".join(problems) if problems else "unknown (only harness errors were checked: none)"))
        elif problems and "harness also reported" not in verdict:
            verdict += "\n\nHarness problems:\n" + "\n".join(problems)
        path = root / f"PLAYTEST_{n:03d}.md"
        write(path, verdict.strip() + "\n")
        log(f"smoke check report: {path.name}")
        keep = int(pc.get("keep_shot_dirs", 6))
        dirs = sorted(x for x in root.iterdir() if x.is_dir() and x.name.isdigit())
        for x in dirs[:-keep]:
            shutil.rmtree(x, ignore_errors=True)
        return path

    def _playtest_due(self, n: int, pc: dict) -> str:
        """Why a visual review is due after cycle n, or "" (owner 2026-10-08: review again once most defects of the
        last report have been worked on, not every cycle). Work done is counted as visual-lane merges since the last
        review; each tends to cover a couple of defects (defects_per_fix). max_gap_cycles keeps it from going blind
        when the visual lane stalls; min_gap_cycles keeps reviews apart."""
        reports = sorted((HERE / "playtests").glob("PLAYTEST_*.md"))
        last = self.state.get("last_playtest_cycle")
        if last is None and reports:
            m = re.search(r"(\d+)", reports[-1].stem)
            last = int(m.group(1)) if m else None
        if last is None:
            return "no review yet"
        hours = float(pc.get("every_hours") or 0)
        if hours:   # owner 2026-10-08: a big gameplay check about every N hours, whatever the cycle pace
            last_ts = float(self.state.get("last_playtest_ts") or 0) or (reports[-1].stat().st_mtime if reports else 0)
            gone = (time.time() - last_ts) / 3600
            return f"{gone:.1f} h since the last check" if gone >= hours else ""
        since = n - int(last)
        if since < int(pc.get("min_gap_cycles", 2)):
            return ""
        defects = len(re.findall(r"(?m)^\s*P\d+\.", read(reports[-1]))) if reports else 0
        fixes = int(self.state.get("visual_fixes_since_playtest") or 0)
        covered = fixes * float(pc.get("defects_per_fix", 2))
        if defects and covered >= float(pc.get("fixed_fraction", 0.6)) * defects:
            return (f"{fixes} visual fixes merged since cycle {int(last):03d}, covering about {covered:.0f} of its "
                    f"{defects} defects")
        if since >= int(pc.get("max_gap_cycles", 12)):
            return f"{since} cycles since the last review"
        return ""

    def run_playtest(self, n: int, commit: str, title: str | None = None) -> Path | None:
        from playtest import Playtest, facts_text
        pc = self.cfg["playtest"]
        root = HERE / "playtests"
        shots = root / f"{n:03d}"
        if pc.get("smoke"):
            return self.run_smoke_check(n, commit, pc, root, shots)
        log(f"playtest: exporting {commit} for the Web and capturing screenshots")
        res = Playtest(pc, self.repo, log).run(commit, shots)
        facts = facts_text(res)
        write(shots / "FACTS.md", facts)
        log(f"playtest: captured in {res.get('seconds')}s"
            + ("; EXPORT CONTENT BUG present" if res.get("export_catalog_broken") else ""))
        prev = sorted(root.glob("PLAYTEST_*.md"))
        out = self.claude(P.PLAYTEST.substitute(
            cycle=f"{n:03d}", commit=commit, title=title if title is not None else (self.state.get("title") or ""),
            facts=facts, docs=HERE.parent / "full_game", milestone=self.state.get("milestone") or "see MILESTONES.md",
            prev_report=prev[-1] if prev else "none"), "PLAYTEST")
        report = extract(out, "REPORT") or out.strip()
        path = root / f"PLAYTEST_{n:03d}.md"
        write(path, report + "\n")
        log(f"playtest report: {path.name}")
        keep = int(pc.get("keep_shot_dirs", 6))
        dirs = sorted(d for d in root.iterdir() if d.is_dir() and d.name.isdigit())
        for d in dirs[:-keep]:
            shutil.rmtree(d, ignore_errors=True)
        return path

    def learn_lessons(self) -> None:
        """Best effort: ChatGPT (chat mode) turns this cycle's rejections into general lessons."""
        g = self.cfg["chatgpt"]
        if not (g.get("enabled") and g.get("file_mode") and g.get("lessons", True)):
            return
        lessons = HERE / "LESSONS.md"
        out = self.cyc / "LESSONS_NEW.md"
        got = self.chatgpt_file(P.LESSONS_FILE.substitute(
            cycle_dir=self.cyc, lessons_path=lessons, out_path=out, repo=self.repo), "LESSONS", out)
        self._add_lessons(got, f"cycle {self.state['cycle']:03d}")

    _lessons_lock = threading.Lock()

    def _add_lessons(self, got: str | None, source: str) -> None:
        """Owner 2026-10-31 (most of 40 rolling lessons were one-task details that rolled off in ~2 days): the
        "## Always" section is kept as written; new lessons go to "## Recent", which keeps only lessons_keep."""
        lessons = HERE / "LESSONS.md"
        bullets = [l.rstrip() for l in (got or "").splitlines() if l.strip().startswith(("- ", "* "))]
        if not bullets:
            return
        with self._lessons_lock:
            always, old, sect = [], [], ""
            for l in read(lessons).splitlines():
                if l.startswith("## "):
                    sect = l[3:].strip().lower()
                elif l.strip().startswith(("- ", "* ")):
                    (always if sect.startswith("always") else old).append(l.rstrip())
            keep = (old + [f"{b} ({source})" for b in bullets])[-int(self.cfg.get('lessons_keep', 10)):]
            head = "# Lessons for coding agents (auto-collected by the relay)\n\n"
            if always:
                head += "## Always\n\n" + "\n".join(always) + "\n\n## Recent\n\n"
            write(lessons, head + "\n".join(keep) + "\n")
        log(f"lessons: +{len(bullets)} from {source} (LESSONS.md now {len(always)} always + {len(keep)} recent)")

    def learn_lane_lessons(self, key: str, lt: dict, outcome: str) -> None:
        """Owner 2026-10-10: a lane that needed review fixes (or was given up) teaches every coder too. Runs in the
        background; best effort."""
        g = self.cfg["chatgpt"]
        if not (g.get("enabled") and g.get("file_mode") and g.get("lessons", True) and g.get("lane_lessons", True)):
            return
        base = re.sub(r'-fix\d+$', '', Path(lt.get('run_dir', '')).name)
        if not base:
            return
        runs = self.lane2(key).runs
        dirs = sorted(str(d) for d in runs.glob(base + '*') if d.is_dir())
        builder = self._lane_builder(key)

        def run() -> None:
            self._tls.bg = True
            try:
                out = runs / base / "LESSONS_NEW.md"
                got = self.chatgpt_file(P.LANE_LESSONS_FILE.substitute(
                    builder=builder, outcome=outcome, title=lt.get('title', ''), run_dirs=", ".join(dirs),
                    lessons_path=HERE / "LESSONS.md", out_path=out, repo=self.repo), f"LESSONS_{key}", out)
                self._add_lessons(got, f"{key} {builder}")
            except Exception as e:   # noqa: BLE001 - lessons are best effort
                log(f"{key}: lessons unavailable ({type(e).__name__}: {str(e)[:160]})")
            finally:
                try:
                    self._tls.bridge and self._tls.bridge.disconnect()
                except Exception:   # noqa: BLE001
                    pass

        threading.Thread(target=run, name=f"lessons-{key}", daemon=True).start()

    # Owner 2026-10-19: the periodic design review (balance order + one patchwork feature) runs in ChatGPT chat mode
    # every design_review.every accepted cycles, in the background after the accept. It replaced Claude's manual
    # reviews (cycles 382-425) to save Claude usage.
    DESIGN_DIR = HERE / "design_reviews"
    _design_busy = threading.Lock()

    PC_RESTART_FILE = HERE / "pc_restart.json"

    def pc_restart_due(self) -> str:
        """Owner 2026-10-19: "can you restart the pc when this starts to happen. Maybe its because its on for too
        long" (the relay Chrome hung 3 times that day after 55 h of uptime). Due when the bridge restarted a hung
        Chrome `hangs` times within `window_h`, the PC has been up `min_uptime_h`, and the relay has not restarted it
        within `min_gap_h` (no restart loop). Returns the reason, or ""."""
        pc = self.cfg.get("pc_restart") or {}
        if not pc.get("enabled") or os.name != "nt":
            return ""
        from chatgpt_bridge import CHROME_HANGS
        now = time.time()
        hangs = [t for t in (load_json(CHROME_HANGS, []) or []) if isinstance(t, (int, float))]
        window_h = float(pc.get("window_h", 2))
        recent = [t for t in hangs if now - t < window_h * 3600]
        if len(recent) < int(pc.get("hangs", 2)):
            return ""
        up = uptime_hours()
        if up is None or up < float(pc.get("min_uptime_h", 12)):
            return ""
        last = (load_json(self.PC_RESTART_FILE, {}) or {}).get("at", 0)
        if isinstance(last, (int, float)) and now - last < float(pc.get("min_gap_h", 20)) * 3600:
            return ""
        return f"the relay Chrome hung {len(recent)} times (ChatGPT page timeouts count) in {window_h:g} h after {up:.0f} h of uptime"

    def restart_pc(self, why: str) -> None:
        """Restart Windows after a short warning; the watchdog task resumes the relay once the owner's session is
        back. If shutdown fails the relay carries on.
        Owner 2026-10-25 ("make it auto continue incase it happens when im asleep"): /g instead of /r. With Windows'
        "Use my sign-in info to automatically finish setting up" on (Automatic Restart Sign-On), Windows signs the
        owner back in and LOCKS the session after the reboot, so the logon watchdog resumes the relay unattended. The
        password stays; with the setting off it behaves like /r (waits for the owner's sign-in).
        Never /sg: that is a full SHUTDOWN (ARSO only on the next manual power-on); on 2026-10-27 it powered the PC
        off overnight ("it shutdown pc not restart")."""
        pc = self.cfg.get("pc_restart") or {}
        delay = int(pc.get("delay_s", 120))
        save_json(self.PC_RESTART_FILE, {"at": time.time(), "started": ts(), "why": why})
        r = subprocess.run(["shutdown", "/g", "/t", str(delay), "/c",
                            f"{G.NAME} relay: restarting the PC after repeated relay Chrome hangs or ChatGPT timeouts. "
                            "Run 'shutdown /a' to cancel."], capture_output=True, text=True)
        if r.returncode != 0:
            log(f"PC restart: shutdown failed (rc={r.returncode}: {(r.stderr or r.stdout).strip()[:160]}); "
                "carrying on")
            self._halting = False
            return
        from chatgpt_bridge import CHROME_HANGS
        CHROME_HANGS.unlink(missing_ok=True)
        log(f"PC restart: {why}; Windows restarts in {delay} s, signs back in (locked) and the watchdog resumes the relay")
        raise Halt(f"restarting the PC ({why})")

    def design_shots(self, limit: int = 8) -> list:
        """Owner 2026-10-24 ("the design review can also check all the visual things"): the newest playtest's
        screenshots (one per screen), attached to the design review so ChatGPT sees every screen. Owner 2026-11-05
        ("the design review showing the wrong images"): playtests before playtest.shots_since_cycle show card screens.
        Owner 2026-11-09 ("the images are wrong for chatgpt planners"): the playtest only captures the title and the old
        battle preview, so the current screens in refs/now (refresh_now_refs.sh) come first."""
        now = planner_mock.now_shots()
        if now:
            return now[:limit]
        since = int(((getattr(self, "cfg", None) or {}).get("playtest") or {}).get("shots_since_cycle", 0))
        dirs = sorted((d for d in (HERE / "playtests").glob("*")
                       if d.is_dir() and d.name.isdigit() and int(d.name) >= since), key=lambda d: int(d.name))
        for d in reversed(dirs):
            shots = sorted(d.glob("*.png"))
            if shots:
                return shots[:limit]
        return []

    def refresh_now_refs(self) -> None:
        """Owner 2026-11-09: screenshot master's current screens into refs/now before the planners see them (best
        effort; its own worktree, about 2 min)."""
        script = HERE / "refresh_now_refs.sh"
        if not script.exists() or not (self.cfg.get("chatgpt") or {}).get("refresh_now_refs", True):
            return
        try:
            r = subprocess.run(["bash", str(script)], capture_output=True, text=True, encoding="utf-8",
                               errors="replace", timeout=1500)
            log("current screens: " + ((r.stdout + r.stderr).strip().splitlines() or ["no output"])[-1][:200])
        except Exception as e:   # noqa: BLE001 - the review still runs with the shots it has
            log(f"current screens: refresh failed ({type(e).__name__}: {str(e)[:120]})")

    def maybe_design_review(self, n: int) -> None:
        dc = self.cfg.get("design_review") or {}
        g = self.cfg["chatgpt"]
        if not (dc.get("enabled", True) and g.get("enabled") and g.get("file_mode")):
            return
        last = int((load_json(self.DESIGN_DIR / "LAST.json", {}) or {}).get("cycle", 0))
        if n - last < int(dc.get("every", 12)) or not self._design_busy.acquire(blocking=False):
            return
        self.DESIGN_DIR.mkdir(parents=True, exist_ok=True)
        # 2026-10-20: the cycle 449 review died with its daemon thread when the relay halted for an install, and
        # LAST.json already said 449, so nothing retried it for 12 cycles. Record the retry point now; only a
        # finished review moves it to n.
        retry = n - int(dc.get("every", 12)) + 3
        save_json(self.DESIGN_DIR / "LAST.json", {"cycle": retry, "started": ts(), "for_cycle": n})
        history = "\n".join(f"  - {h['cycle']:03d} {h['title']}" for h in (self.state.get("history") or [])[-15:]
                            if isinstance(h.get("cycle"), int)) or "  - none"
        merged = [h for k in self.LANE_KEYS for h in (self.state.get(f"{k}_history") or [])]
        lanes = "\n".join(f"  - {h.get('title', '')}" for h in merged[-15:]) or "  - none"
        playtests = ", ".join(str(p) for p in sorted((HERE / "playtests").glob("PLAYTEST_*.md"))[-2:]) or "(none)"

        def run() -> None:
            self._tls.bg = True
            ok = False
            try:
                self.refresh_now_refs()
                images = [*self.design_shots(), *self.asked_refs("DESIGNREVIEW")]
                shots = (", ".join(p.name for p in images) + " (attached)") if images else "none attached"
                out = self.DESIGN_DIR / f"REVIEW_{n:03d}.md"
                got = self.chatgpt_file(P.DESIGN_REVIEW_FILE.substitute(
                    docs=HERE.parent / "full_game", design_next_path=P.DESIGN_NEXT, playtests=playtests,
                    owner_order_path=P.OWNER_ORDER,
                    history=history, lanes=lanes, repo=self.repo, out_path=out, shots=shots,
                    date=datetime.date.today().isoformat(), cycle=n) + self.ref_request_note("DESIGNREVIEW"),
                    "DESIGNREVIEW", out, images=images)
                ok = self.apply_design_review(n, self.take_ref_requests(got or "", "DESIGNREVIEW"))
                if ok:
                    save_json(self.DESIGN_DIR / "LAST.json", {"cycle": n, "done": ts()})
            except Exception as e:   # noqa: BLE001 - the review is best effort
                log(f"design review: unavailable ({type(e).__name__}: {str(e)[:160]})")
            finally:
                if not ok:   # try again three cycles later
                    save_json(self.DESIGN_DIR / "LAST.json", {"cycle": retry, "failed": ts()})
                self._design_busy.release()
                try:
                    self._tls.bridge and self._tls.bridge.disconnect()
                except Exception:   # noqa: BLE001
                    pass

        log(f"design review: ChatGPT reviews the Stitched stages and features after cycle {n:03d} (background)")
        threading.Thread(target=run, name="design-review", daemon=True).start()

    def apply_design_review(self, n: int, text: str) -> bool:
        parts = parse_design_review(text)
        if not parts:
            log(f"design review: cycle {n:03d} answer was empty or malformed; MILESTONES.md unchanged")
            return False
        ms = HERE.parent / "full_game" / "MILESTONES.md"
        old = ms.read_bytes().decode("utf-8")
        new = insert_design_review(old, parts["bal"], parts["mpw"])
        if new is None:
            log("design review: MILESTONES.md has no BAL gate / MPW anchor; only DESIGN_NEXT.md updated")
        else:
            (self.DESIGN_DIR / f"MILESTONES.pre-review{n:03d}.md").write_bytes(old.encode("utf-8"))
            ms.write_bytes(new.encode("utf-8"))
        write(P.DESIGN_NEXT, parts["next"] + "\n")
        steps = re.findall(r"^P\d+(?=\. )", parts["mpw"], re.M)
        feature = f", new MPW {', '.join(steps)}" if steps else ""
        log(f"design review: cycle {n:03d} applied (BAL review{feature}; planner order in DESIGN_NEXT.md)")
        return True

    # ---- local Claude rescue builder / milestone audit

    def try_rescue(self, reason: str) -> bool:
        """A failed build cycle gets one rescue attempt by Claude Code with edit rights."""
        r = self.cfg.get("rescue", {})
        if (not r.get("enabled") or self.state.get("rescued")
                or self.state.get('repair_exhausted')
                or self.state.get("phase") not in ("BUILD", "CHATFIX", "TEST", "REVIEW", "FINAL")
                or self.rescues_this_run >= r.get("max_per_run", 2)
                or self.git("rev-parse", "--abbrev-ref", "HEAD") != self.state.get("branch")):
            return False
        defects = self.state.get("prev_defects") or []
        write(self.cyc / "RESCUE_DEFECTS.md",
              "\n".join(f"- {d}" for d in defects) + f"\n\nController reason: {reason}\n")
        self.rescues_this_run += 1
        self.save(rescued=True, rescue_reason=reason)
        if self.claude_allowed("RESCUE") and self.cloud_ok() and self.start_cloud_rescue(reason):
            return True
        # 2026-10-26: the log said "local Claude rescue" while ChatGPT or Codex did it (do_rescue picks).
        who = ("Codex" if self.cfg.get("rescue", {}).get("builder") == "codex" or self._codex_builds_main() else
               "ChatGPT" if self.role("RESCUE") == "chatgpt" else "local Claude")
        self.save(phase="RESCUE", note=f"{who} rescue: {reason}")
        log(f"cycle {self.state['cycle']:03d} failed ({reason}); handing to the {who} rescue")
        return True

    def cloud_ok(self) -> bool:
        c = self.cfg.get("cloud", {})
        return (self.cloud.available()
                and self.cloud.launches_since(self.run_started) < c.get("max_sessions_per_run", 3))

    def cloud_godot(self) -> str:
        return P.CLOUD_GODOT.substitute(godot_url=self.cfg.get("cloud", {}).get("godot_url", ""))

    def _clear_cloud_dir(self) -> None:
        shutil.rmtree(self.repo / ".cloud", ignore_errors=True)

    def start_cloud_rescue(self, reason: str) -> bool:
        n, br = self.state["cycle"], self.state["branch"]
        base = self.git("rev-parse", "HEAD")
        stamp = int(time.time())
        ctx_branch = f"relay/rescue-{n:03d}-{stamp}"
        result_branch = f"claude/relay-rescue-{n:03d}-{stamp}"
        test_file = self.state.get("test_file")
        files = {
            ".cloud/TASK_BRIEF.md": read(self.cyc / "DEEPSEEK_BRIEF.md").split("\n---\n## Relay rules")[0],
            ".cloud/LAST_DEFECTS.md": read(self.cyc / "RESCUE_DEFECTS.md"),
            ".cloud/LAST_TEST_OUTPUT.txt": tail(read(self.cyc / test_file), 20000) if test_file else "(none)",
        }
        prompt = P.CLOUD_RESCUE.substitute(reason=reason, godot=self.cloud_godot(),
                                           result_branch=result_branch)
        files[".cloud/PROMPT.md"] = prompt
        write(self.cyc / "CLOUD_RESCUE_PROMPT.md", prompt)
        try:
            self.git("add", "-A")
            if not self.git_ok("diff", "--cached", "--quiet"):
                self.git("commit", "--no-verify", "-m", f"relay WIP cycle {n:03d} (pre-rescue)")
            self.git("checkout", "-B", ctx_branch)      # the cloud clones the current branch name
            ctx = self.cloud.push_context(ctx_branch, files, f"cloud context for cycle {n:03d}")
            entry = self.cloud.launch("rescue", f"cycle {n:03d}", prompt,
                                      self.cyc / "logs" / f"cloud_rescue_{stamp}.log")
        except (CloudError, Halt, OSError, subprocess.SubprocessError) as e:
            log(f"cloud rescue not started ({e}); using local rescue")
            self.git("checkout", "-f", br, check=False)
            self.git("reset", "--mixed", base, check=False)
            self.git("branch", "-D", ctx_branch, check=False)
            self._clear_cloud_dir()
            return False
        self.git("checkout", br)
        self.git("reset", "--hard", ctx)                # br now = WIP + context commit
        self.git("branch", "-D", ctx_branch, check=False)
        self.save(phase="RESCUE_CLOUD", note=f"cloud rescue running: {entry.get('url')}",
                  rescue={"base": base, "ctx": ctx, "branch": result_branch, "ctx_branch": ctx_branch,
                          "url": entry.get("url"), "started": ts()})
        log(f"cycle {n:03d} failed ({reason}); cloud rescue running")
        notify(f"{G.NAME} cycle {n:03d}: cloud rescue", reason)
        return True

    def do_rescue_cloud(self) -> None:
        r = self.state["rescue"]
        log(f"waiting for cloud rescue on {r['branch']}")
        head = self.cloud.wait_for(r["branch"], ".cloud/RESULT.md",
                                   self.cfg.get("cloud", {}).get("rescue_timeout_s", 7200),
                                   STOP_PATH.exists, lambda: self.save(heartbeat=ts()))
        if STOP_PATH.exists():
            raise Halt("STOP requested")
        if head is None:
            log("cloud rescue gave no result in time; falling back to local rescue")
            self.git("reset", "--mixed", r["base"])
            self._clear_cloud_dir()
            self.save(phase="RESCUE", note="cloud rescue timed out; local rescue")
            return
        self.git("reset", "--hard", head)
        write(self.cyc / "RESCUE_REPORT.md", self.cloud.show(head, ".cloud/RESULT.md"))
        self.git("rm", "-r", "-q", "--cached", "--ignore-unmatch", ".cloud")
        self._clear_cloud_dir()
        self.git("reset", "--soft", r["base"])
        log(f"cloud rescue result applied ({head[:9]})")
        self.delete_remote_branches(r["branch"], r.get("ctx_branch"))
        self.check_coder_report(self.cyc / 'RESCUE_REPORT.md')
        self.save(phase="TEST", attempt=self.state["attempt"] + 1, report_file="RESCUE_REPORT.md",
                  note="cloud rescue applied; final chance", last_coder="Claude cloud")

    def do_rescue(self) -> None:
        # 2026-10-18 (cycle 405): a 34-file DeepSeek build timed out twice while Codex was free again; Codex, the
        # main-cycle coder, rescues it then instead of ChatGPT work mode.
        if self.cfg.get("rescue", {}).get("builder") == "codex" or self._codex_builds_main():
            return self.do_rescue_codex()
        if self.role("RESCUE") == "chatgpt":
            return self.do_rescue_chatgpt()
        r, c = self.cfg.get("rescue", {}), self.cfg["claude"]
        n = self.state["cycle"]
        rel = f"{self.relay_rel}/cycles/{n:03d}"
        report = "RESCUE_REPORT.md"
        test_file = self.state.get("test_file")
        prompt = P.RESCUE.substitute(
            repo=self.repo, branch=self.state["branch"], reason=self.state.get("rescue_reason", "failed"),
            brief_path=f"{rel}/DEEPSEEK_BRIEF.md", defects_path=f"{rel}/RESCUE_DEFECTS.md",
            test_path=f"{rel}/{test_file}" if test_file else "(no test output yet)",
            rules=self.hard_rules(report))
        pf = self.cyc / "RESCUE_PROMPT.md"
        write(pf, prompt)
        instr = (f"Read the file {pf} and follow its instructions exactly. "
                 "Your final message is captured by an automated controller.")
        argv = [c["cmd"], "-p", instr, "--output-format", "json",
                "--max-turns", str(r.get("max_turns", 200))]
        if r.get("model") or c.get("model"):
            argv += ["--model", r.get("model") or c["model"]]
        argv += ["--allowedTools", *r["allowed_tools"], "--disallowedTools", *r["disallowed_tools"]]
        head = self.git("rev-parse", "HEAD")
        lp = self.cyc / "logs" / f"claude_RESCUE_{int(time.time())}.log"
        log("claude RESCUE")
        rc, why = self.run_proc(argv, lp, r.get("timeout", 3600), self.cfg["stall_s"])
        if self.git("rev-parse", "--abbrev-ref", "HEAD") != self.state["branch"]:
            raise Halt("rescue switched branches; inspect before restarting")
        if self.git("rev-parse", "HEAD") != head:
            log("rescue committed; undoing with soft reset (changes kept)")
            self.git("reset", "--soft", head)
        raw = read(lp)
        data = last_json_line(raw)
        if why == "exit" and data and not data.get("is_error"):
            if not (self.cyc / report).exists():
                write(self.cyc / report, data.get("result", "(no report)") + "\n")
            self.check_coder_report(self.cyc / report)
            self.save(phase="TEST", attempt=self.state["attempt"] + 1, report_file=report,
                      note="Claude rescue applied; final chance", last_coder="Claude CLI")
            return
        if LIMIT_RE.search(raw):
            raise UsageLimited("claude rescue limit")
        raise AgentFailed(f"Claude rescue failed ({why}, rc={rc})")

    def do_rescue_codex(self) -> None:
        """Rescue builder (owner 2026-10-10): the local Codex CLI edits the working tree and runs the tests."""
        r = self.cfg.get("rescue", {})
        n = self.state["cycle"]
        rel = f"{self.relay_rel}/cycles/{n:03d}"
        report = self.cyc / "RESCUE_REPORT.md"
        test_file = self.state.get("test_file")
        pf = self.cyc / "RESCUE_TASK.md"
        write(pf, P.RESCUE.substitute(
            repo=self.repo, branch=self.state["branch"], reason=self.state.get("rescue_reason", "failed"),
            brief_path=f"{rel}/DEEPSEEK_BRIEF.md", defects_path=f"{rel}/RESCUE_DEFECTS.md",
            test_path=f"{rel}/{test_file}" if test_file else "(no test output yet)",
            rules=self.hard_rules(report.name)))
        head, br, guard = self.git("rev-parse", "HEAD"), self.state["branch"], guard_hash()
        report.unlink(missing_ok=True)
        reply = self.run_codex_main(pf, report, "RESCUE", int(r.get("timeout", 3600)))
        if self.git("rev-parse", "--abbrev-ref", "HEAD") != br:
            raise Halt("rescue switched branches; inspect before restarting")
        if self.git("rev-parse", "HEAD") != head:
            log("rescue committed; undoing with soft reset (changes kept)")
            self.git("reset", "--soft", head)
        if guard_hash() != guard:
            raise Halt("rescue modified relay files; inspect before restarting")
        self.sweep_strays()
        if reply is None and not report.exists():
            raise AgentFailed("Codex rescue gave no result")
        if not report.exists():
            write(report, (reply or "(no report)") + "\n")
        self.check_coder_report(report)
        self.save(phase="TEST", attempt=self.state["attempt"] + 1, report_file=report.name,
                  note="Codex rescue applied; final chance", last_coder="Codex")

    def do_rescue_chatgpt(self) -> None:
        """Rescue builder: ChatGPT (work mode) edits the working tree with Desktop Commander and runs tests."""
        r = self.cfg.get("rescue", {})
        n = self.state["cycle"]
        rel = f"{self.relay_rel}/cycles/{n:03d}"
        report = self.cyc / "RESCUE_REPORT.md"
        test_file = self.state.get("test_file")
        task = P.RESCUE.substitute(
            repo=self.repo, branch=self.state["branch"], reason=self.state.get("rescue_reason", "failed"),
            brief_path=f"{rel}/DEEPSEEK_BRIEF.md", defects_path=f"{rel}/RESCUE_DEFECTS.md",
            test_path=f"{rel}/{test_file}" if test_file else "(no test output yet)",
            rules=self.hard_rules(report.name))
        pf = self.cyc / "RESCUE_TASK.md"
        write(pf, task)
        head, br, guard = self.git("rev-parse", "HEAD"), self.state["branch"], guard_hash()
        report.unlink(missing_ok=True)
        prompt = P.RESCUE_CHATGPT.substitute(task_path=pf, report_path=report, repo=self.repo,
                                             test_cmd=" ".join(self.cfg["test_cmd"]))
        write(self.cyc / "RESCUE_CHATGPT_PROMPT.md", prompt)
        reply = self._ask_chatgpt(prompt, "RESCUE", 1, timeout=int(r.get("timeout", 3600)))
        if self.git("rev-parse", "--abbrev-ref", "HEAD") != br:
            raise Halt("rescue switched branches; inspect before restarting")
        if self.git("rev-parse", "HEAD") != head:
            log("rescue committed; undoing with soft reset (changes kept)")
            self.git("reset", "--soft", head)
        if guard_hash() != guard:
            raise Halt("rescue modified relay files; inspect before restarting")
        self.sweep_strays()
        if reply is None and not report.exists():
            raise AgentFailed("ChatGPT rescue gave no result")
        if not report.exists():
            write(report, (reply or "(no report)") + "\n")
        self.check_coder_report(report)
        self.save(phase="TEST", attempt=self.state["attempt"] + 1, report_file=report.name,
                  note="ChatGPT rescue applied; final chance", last_coder="ChatGPT")

    @staticmethod
    def _ms(h: dict) -> str | None:
        return h.get("milestone") or milestone_of(h.get("title"))

    def last_milestone(self) -> str | None:
        return next((m for m in (self._ms(h) for h in reversed(self.state["history"])) if m), None)

    # ---- workflow review at the end of each milestone (cloud Claude, else ChatGPT)

    OWNER_PRIORITIES = """# Owner priorities for the relay (fixed constraints)
- Speed (cycle time and total throughput) is the top priority; the owner accepts more risk for more speed.
  Quality gates that stay: the full test suite, the ChatGPT final review, the Claude visual playtest.
- Owner 2026-10-10: use MORE ChatGPT Chat messages in parallel for speed (parallel lane planners per builder group,
  one review message per lane, two ChatGPT Chat coding lanes), capped by chatgpt.max_concurrent open chats. ChatGPT Work mode and
  Codex have usage limits. ChatGPT reaches this PC's files through the SentinelX connector.
- Claude usage is limited: local Claude only orchestrates and reviews playtest screenshots; cloud Claude only does
  milestone audits, these workflow reviews and rescues.
- DeepSeek (OpenCode, deepseek-v4.1-flash) is cheap: the main builder and two lanes, for small tasks. The local Codex
  CLI (owner's ChatGPT plan, full terminal access, subagents) codes two lanes with the bigger features and is the
  fallback coder (backup fixes, lane repairs, rescues). ChatGPT plans and reviews.
- Owner 2026-10-10: FEATURES FIRST. Complete the gameplay in MILESTONES.md order and add new features, not
  stability/proof work.
- Images: the relay's ART phase (art_gen.py; providers in relay.json "art").
- Windows 11 PC, 16 cores, 31 GB RAM; the owner uses it while the relay runs (no pop-up windows).
"""

    def maybe_workflow_review(self, prev: str | None, cur: str | None) -> None:
        wc = self.cfg.get("workflow_review", {})
        done = self.state.get("workflow_reviewed") or []
        if not (wc.get("enabled", True) and prev and cur and prev != cur and prev not in done and cur > prev):
            return
        self.save(workflow_reviewed=done + [prev])
        cycles = [h for h in self.state["history"] if self._ms(h) == prev]
        d = HERE / "workflow"
        d.mkdir(exist_ok=True)
        write(d / f"METRICS_{prev}.md", self.workflow_metrics(prev, cycles))
        write(d / "OWNER_PRIORITIES.md", self.OWNER_PRIORITIES)
        if self.claude_allowed("WORKFLOW") and self.cloud_ok() and self.start_cloud_workflow(prev):
            return

        def run() -> None:   # ChatGPT fallback, off the main thread
            self._tls.bg = True
            try:
                out = self.think(P.WORKFLOW_REVIEW.substitute(
                    milestone=prev, relay=HERE, metrics=d / f"METRICS_{prev}.md", log=LOG_PATH,
                    priorities=d / "OWNER_PRIORITIES.md", out=f"your answer (Markdown)",
                    patch_rule="Do not write a patch; describe each change precisely (file, function, what to change)."),
                    f"WORKFLOW_{prev}")
                write(d / f"REVIEW_{prev}.md", f"# Workflow review (ChatGPT): {prev}\n\n{out}\n")
                log(f"workflow review for {prev} written to workflow/REVIEW_{prev}.md")
                notify(f"{G.NAME} workflow review ready", f"{prev}: see workflow/REVIEW_{prev}.md")
            except Exception as e:   # noqa: BLE001
                log(f"workflow review for {prev} failed: {type(e).__name__}: {str(e)[:200]}")

        threading.Thread(target=run, name=f"workflow-{prev}", daemon=True).start()

    def workflow_metrics(self, ms: str, cycles: list[dict]) -> str:
        nums = [h["cycle"] for h in cycles] or [self.state["cycle"]]
        lo, hi = min(nums), max(nums)
        rows, totals = [], {}
        for n in range(lo, hi + 1):
            phases = {}
            for m in re.finditer(r"\| (\w+) \| [\d\- :]+ \| ([\d.]+) \|", read(CYCLES / f"{n:03d}" / "TIMELINE.md")):
                phases[m.group(1)] = phases.get(m.group(1), 0) + float(m.group(2))
            if not phases:
                continue
            for k, v in phases.items():
                totals.setdefault(k, []).append(v)
            h = next((x for x in cycles if x["cycle"] == n), None)
            busy = sum(v for k, v in phases.items() if k != "HALTED")
            rows.append(f"| {n:03d} | {'accepted' if h else 'failed/other'} | {busy:.0f} | "
                        f"{h.get('fix_attempts', 0) if h else '-'} | "
                        + ", ".join(f"{k} {v:.1f}" for k, v in phases.items()) + " |")
        avg = "\n".join(f"- {k}: avg {sum(v) / len(v):.1f} min over {len(v)} cycles (total {sum(v):.0f})"
                        for k, v in sorted(totals.items(), key=lambda kv: -sum(kv[1])))
        lanes = []
        for k in ("codex",) + self.LANE_KEYS:
            hist, fail = self.state.get(f"{k}_history") or [], self.state.get(f"{k}_failed") or []
            lanes.append(f"- {k} ({self.cfg.get(k, {}).get('label', k)}): {len(hist)} merged, {len(fail)} given up"
                         + "".join(f"\n  - gave up: {f['title']}: {f['reason'][:150]}" for f in fail[-4:]))
        text = read(LOG_PATH)
        i = text.find(f"=== cycle {lo:03d} started")
        seg = text[i:] if i >= 0 else text[-400_000:]
        pats = {"ChatGPT tab reloads (looked stuck)": r"looks stuck", "ChatGPT bridge errors": r"bridge error",
                "SentinelX failures -> zip upload": r"falling back to the zip", "fix requests": r"fix requested",
                "backup fixes (Codex/ChatGPT)": r"(?:Codex|ChatGPT) fix applied", "rescues": r"rescue",
                "images missing": r"MISSING", "flaky tests": r"FLAKY", "lane merges": r"MERGED ->",
                "lane tasks given up": r"gave up on", "lanes idle (no task in plan)": r"idle this cycle",
                "test runs skipped (unchanged tree)": r"not re-running", "prepared plans used": r"plan prepared during",
                "waits for background work": r"waiting for", "halts": r"halted:",
                "controller errors": r"Traceback|controller error|launch error"}
        counts = "\n".join(f"- {k}: {len(re.findall(p, seg))}" for k, p in pats.items())
        return (f"# Workflow metrics for {ms} (cycles {lo:03d}-{hi:03d})\n\n## Cycles\n"
                "| cycle | result | minutes | fix attempts | phases (minutes) |\n|---|---|---:|---:|---|\n"
                + "\n".join(rows) + f"\n\n## Step averages\n{avg}\n\n## Parallel lanes (all time)\n"
                + "\n".join(lanes) + f"\n\n## Log events during {ms}\n{counts}\n")

    def start_cloud_workflow(self, ms: str) -> bool:
        import tempfile
        from cloud import Cloud
        stamp = int(time.time())
        ctx_branch, result_branch = f"relay/workflow-{ms}-{stamp}", f"claude/relay-workflow-{ms}-{stamp}"
        d = HERE / "workflow"
        files = {f".cloud/relay/{n}": read(HERE / n) for n in
                 ("controller.py", "prompts.py", "chatgpt_bridge.py", "art_gen.py", "art_runner.py", "lane_local.py",
                  "run_tests.py", "playtest.py", "relay.json", "run_relay.ps1", "LESSONS.md") if (HERE / n).exists()}
        files[".cloud/WORKFLOW_METRICS.md"] = read(d / f"METRICS_{ms}.md")
        files[".cloud/OWNER_PRIORITIES.md"] = self.OWNER_PRIORITIES
        files[".cloud/CONTROLLER_LOG_TAIL.txt"] = tail(read(LOG_PATH), 200_000)
        prompt = P.WORKFLOW_REVIEW.substitute(
            milestone=ms, relay="`.cloud/relay/`", metrics="`.cloud/WORKFLOW_METRICS.md`",
            log="`.cloud/CONTROLLER_LOG_TAIL.txt`", priorities="`.cloud/OWNER_PRIORITIES.md`",
            out="`.cloud/WORKFLOW_REVIEW.md`",
            patch_rule=("If some recommendations are safe and clear, also write `.cloud/WORKFLOW_PATCH.diff`: a unified "
                        "diff (git apply format, paths like a/controller.py b/controller.py relative to .cloud/relay/) "
                        "implementing the top ones. Keep it minimal and in the code's style, and do not break "
                        "resume-after-restart (state.json) or the background threads.\n"
                        f"Commit only those files and push them to a new branch named exactly `{result_branch}`. "
                        "Do not open a pull request. Do not push to any other branch."))
        files[".cloud/PROMPT.md"] = prompt
        tmp = Path(tempfile.mkdtemp(prefix="ivwf_"))
        wt = tmp / "ctx"

        def git_in(*args, check=True):
            r = subprocess.run(["git", *args], cwd=wt, capture_output=True, text=True, encoding="utf-8",
                               errors="replace")
            if check and r.returncode:
                raise CloudError(f"git {' '.join(args[:3])} failed: {(r.stdout + r.stderr)[-300:]}")
            return r.stdout.strip()

        ok = False
        try:
            self.git("worktree", "add", "-B", ctx_branch, str(wt), self.main)
            cloud = Cloud(self.cfg.get("cloud", {}), self.cfg["claude"]["cmd"], wt, HERE, git_in, log)
            cloud.push_context(ctx_branch, files, f"cloud workflow review context for {ms}")
            cloud.launch("workflow", ms, prompt, d / f"cloud_launch_{ms}_{stamp}.log")
            self.save(pending_workflow=(self.state.get("pending_workflow") or [])
                      + [{"milestone": ms, "branch": result_branch, "ctx_branch": ctx_branch}])
            log(f"workflow review for {ms} started in the cloud")
            ok = True
        except (CloudError, Halt, OSError, subprocess.SubprocessError) as e:
            log(f"cloud workflow review for {ms} not started ({e}); using ChatGPT")
        finally:
            self.git("worktree", "remove", "--force", str(wt), check=False)
            self.git("worktree", "prune", check=False)
            self.git("branch", "-D", ctx_branch, check=False)
            shutil.rmtree(tmp, ignore_errors=True)
        return ok

    def collect_workflow_reviews(self) -> None:
        pending = self.state.get("pending_workflow") or []
        still = []
        for a in pending:
            head = self.cloud.check_once(a["branch"], ".cloud/WORKFLOW_REVIEW.md")
            if not head:
                still.append(a)
                continue
            ms, d = a["milestone"], HERE / "workflow"
            write(d / f"REVIEW_{ms}.md", f"# Workflow review (cloud Claude): {ms}\n\n"
                  + self.cloud.show(head, ".cloud/WORKFLOW_REVIEW.md"))
            try:
                diff = self.cloud.show(head, ".cloud/WORKFLOW_PATCH.diff")
                if diff.strip():
                    write(d / f"PATCH_{ms}.diff", diff)
            except Exception:   # noqa: BLE001 - the patch is optional
                pass
            log(f"workflow review for {ms} received (workflow/REVIEW_{ms}.md)")
            notify(f"{G.NAME} workflow review ready", f"{ms}: see workflow/REVIEW_{ms}.md")
            self.delete_remote_branches(a["branch"], a.get("ctx_branch"))
        if still != pending:
            self.save(pending_workflow=still)

    def maybe_audit(self, prev: str | None, cur: str | None) -> None:
        """When the planner moves on to a later milestone, audit the one just finished (read-only)."""
        if not self.cfg.get("rescue", {}).get("audit"):
            return
        hist = self.state["history"]
        done = self.state.get("audited") or []
        if not (prev and cur and prev != cur and prev not in done):
            return
        if cur < prev:   # planner went back to fix an older milestone; that is not completion
            return
        cycles = [h for h in hist if self._ms(h) == prev]
        lines = "\n".join(f"- {h['cycle']:03d} {h['title']} ({h['commit']})" for h in cycles) or "- none"
        if self.claude_allowed("AUDIT") and self.cloud_ok() and self.start_cloud_audit(prev, cur, cycles):
            self.save(audited=done + [prev])
            return
        try:
            out = self.think(P.AUDIT.substitute(
                repo=self.repo, milestone=prev, next_milestone=cur, cycles=lines,
                docs=f"{self.relay_rel.rsplit('/', 1)[0]}/full_game",
                cycles_dir=f"{self.relay_rel}/cycles"), f"AUDIT_{prev}")
        except AgentFailed as e:
            log(f"audit for {prev} failed: {e}; continuing")
            self.save(audited=done + [prev])
            return
        body = extract(out, "AUDIT") or out
        write(HERE / "audits" / f"AUDIT_{prev}.md", f"# Milestone audit: {prev}\n\n{body}\n")
        self.save(audited=done + [prev])
        log(f"audit for {prev} written to audits/AUDIT_{prev}.md")

    def start_cloud_audit(self, prev: str, cur: str, cycles: list[dict]) -> bool:
        stamp = int(time.time())
        ctx_branch = f"relay/audit-{prev}-{stamp}"
        result_branch = f"claude/relay-audit-{prev}-{stamp}"
        docs = self.repo / ".review" / "full_game"
        files = {f".cloud/{n}": read(docs / n) for n in
                 G.DOCS
                 if (docs / n).exists()}
        files[".cloud/ACCEPTED_CYCLES.md"] = "\n\n".join(
            f"## Cycle {h['cycle']:03d}: {h['title']} ({h['commit']})\n\n"
            + read(CYCLES / f"{h['cycle']:03d}" / "CLAUDE_PLAN.md") for h in cycles) or "(none)"
        br = self.state["branch"]
        ok = False
        files[".cloud/PROMPT.md"] = P.CLOUD_AUDIT.substitute(
            milestone=prev, next_milestone=cur, godot=self.cloud_godot(), result_branch=result_branch)
        prompt = files[".cloud/PROMPT.md"]
        try:
            self.git("checkout", "-B", ctx_branch, self.main)
            self.cloud.push_context(ctx_branch, files, f"cloud audit context for {prev}")
            self.cloud.launch("audit", prev, prompt, self.cyc / "logs" / f"cloud_audit_{stamp}.log")
            pending = (self.state.get("pending_audits") or []) + [
                {"milestone": prev, "branch": result_branch, "ctx_branch": ctx_branch}]
            self.save(pending_audits=pending)
            ok = True
        except (CloudError, Halt, OSError, subprocess.SubprocessError) as e:
            log(f"cloud audit for {prev} not started ({e}); using local audit")
        finally:
            self.git("checkout", "-f", br, check=False)
            self.git("branch", "-D", ctx_branch, check=False)
            self._clear_cloud_dir()
        return ok

    def delete_remote_branches(self, *branches: str | None) -> None:
        """Best effort: remove cloud context/result branches from GitHub once used."""
        names = [b for b in branches if b]
        if names and not self.git_ok("push", self.cloud.remote, "--delete", *names):
            log(f"note: could not delete remote branches {names}")

    def collect_cloud_audits(self) -> None:
        pending = self.state.get("pending_audits") or []
        still = []
        for a in pending:
            head = self.cloud.check_once(a["branch"], ".cloud/AUDIT.md")
            if head:
                write(HERE / "audits" / f"AUDIT_{a['milestone']}.md",
                      f"# Milestone audit (cloud): {a['milestone']}\n\n" + self.cloud.show(head, ".cloud/AUDIT.md"))
                log(f"cloud audit for {a['milestone']} received")
                self.delete_remote_branches(a["branch"], a.get("ctx_branch"))
            else:
                still.append(a)
        if still != pending:
            self.save(pending_audits=still)

    def defer_cycle(self, reason: str) -> None:
        """Park work requiring a new decision without a repair, rescue or failure-count halt."""
        n, branch = self.state['cycle'], self.state['branch']
        if self.git('branch', '--show-current') != branch:
            raise Halt('Cannot save deferred cycle on an unexpected branch')
        self.settle_merge_check(block=True, conflict_defers=False)
        self.git('add', '-A')
        if not self.git_ok('diff', '--cached', '--quiet'):
            self.git('commit', '--no-verify', '-m', f'relay WIP deferred cycle {n:03d}: {reason[:120]}')
        commit = self.git('rev-parse', 'HEAD')
        parked = f'relay/deferred-{n:03d}-{int(time.time())}'
        self.git('branch', '-m', branch, parked)
        self.git('checkout', self.main)
        entry = {'cycle': n, 'title': self.state.get('title') or '?',
                 'branch': parked, 'commit': commit, 'reason': reason, 'at': ts()}
        write(self.cyc / 'DEFERRED.md',
              f'# Deferred cycle {n:03d}\n\n{reason}\n\nSaved branch: {parked}\n'
              f'Saved commit: {commit}\nOther approved tasks continue.\n')
        self.save(phase='IDLE', branch=parked, tested_fp=None,
                  deferred=(self.state.get('deferred') or []) + [entry],
                  note=f'cycle {n:03d} saved and deferred: {reason}')
        log(f'=== cycle {n:03d} DEFERRED; saved at {parked}; continuing approved work ===')
        self.cycle_health_check('DEFERRED')

    def fail_cycle(self, reason: str) -> None:
        n, br = self.state["cycle"], self.state.get("branch")
        try:
            self.settle_merge_check(block=True, conflict_defers=False)
        except Exception as e:   # noqa: BLE001 - failing the cycle must still work
            log(f"lane-merge check could not settle ({type(e).__name__}: {str(e)[:160]})")
        log(f"=== cycle {n:03d} FAILED: {reason} ===")
        notify(f"{G.NAME} cycle {n:03d} failed", reason)
        write(self.cyc / "TIMELINE.md", timeline_text(self.state.get("timeline", [])))
        try:
            self.git("add", "-A", check=False)
            self.git("commit", "--no-verify", "-m", f"relay WIP cycle {n:03d} (failed: {reason[:120]})", check=False)
            self.git("checkout", self.main, check=False)
            parked = f"relay/failed-{n:03d}-{int(time.time())}"
            if br:
                self.git("branch", "-m", br, parked, check=False)
            self.state.setdefault("failed", []).append(
                {"cycle": n, "title": self.state.get("title") or "?", "branch": parked, "reason": reason, "at": ts()})
            self.state["consecutive_failures"] = self.state.get("consecutive_failures", 0) + 1
        finally:
            self.save(phase="IDLE", note=f"cycle {n:03d} failed: {reason}")
        self.cycle_health_check('FAILED')

    # ---- main loop

    def preflight(self) -> None:
        if not (self.repo / ".git").exists():
            raise Halt(f"{self.repo} is not a git repo")
        excl = self.repo / ".git" / "info" / "exclude"
        for line in (f"/{self.relay_rel}/", "/.cloud/"):
            if line not in read(excl):
                with open(excl, "a", encoding="utf-8") as f:
                    f.write(f"\n{line}\n")
        if self.state["phase"] != "IDLE":
            cur = self.git("rev-parse", "--abbrev-ref", "HEAD")
            if cur != self.state["branch"]:
                if self.git("status", "--porcelain").strip():
                    raise Halt(f"resuming {self.state['branch']} but tree is dirty on {cur}")
                self.git("checkout", self.state["branch"])
            log(f"resuming cycle {self.state['cycle']:03d} at {self.state['phase']}")
            # Close the HALTED gap in the timeline, so time spent stopped is not counted as this phase's time.
            self.save(timeline=self.state.get("timeline", []) + [[self.state["phase"], ts()]])
        # No lane review can be running at startup: clear "reviewing" left by a crash or a restart, or that lane is
        # skipped by the checker forever (lane5 sat at "waiting for its review" for hours, 2026-10-07).
        for k in self.LANE_KEYS:
            lt = self.state.get(f"{k}_task")
            if lt and lt.get("reviewing"):
                self.save(**{f"{k}_task": {**lt, "reviewing": False}})
                log(f"{k}: cleared a stale 'reviewing' mark; it is reviewed again")

    def pending_patch(self) -> Path | None:
        """Newest workflow-review patch not yet handled (run_relay.ps1 renames it to .applied/.rejected)."""
        if not self.cfg.get("workflow_review", {}).get("auto_apply", True):
            return None
        found = sorted((HERE / "workflow").glob("PATCH_*.diff"), key=lambda p: p.stat().st_mtime)
        return found[0] if found else None

    def run(self, max_cycles: int) -> None:
        self.preflight()
        # A resumed in-progress cycle counts toward the cap.
        done = 0 if self.state["phase"] == "IDLE" else 1
        handlers = {"PLAN": self.do_plan, "ART": self.do_art, "BRIEF": self.do_brief, "BUILD": self.do_build,
                    "TEST": self.do_test, "REVIEW": self.do_review, "FINAL": self.do_final,
                    "ACCEPT": self.do_accept, "RESCUE": self.do_rescue, "CHATFIX": self.do_chatfix,
                    "RESCUE_CLOUD": self.do_rescue_cloud}
        self.save(running_pid=os.getpid(), note=None)
        keep_awake(True)
        if self.state['phase'] != 'IDLE' and any(self.state.get(k + '_task') for k in self.LANE_KEYS):
            self.start_lane_checker()  # an interrupted BUILD also needs its retained lanes reviewed
        while True:
            if STOP_PATH.exists():
                raise Halt("STOP requested")
            ph = self.state["phase"]
            try:
                if ph == "IDLE":
                    if PAUSE_PATH.exists():
                        PAUSE_PATH.unlink(missing_ok=True)
                        # A halt kills the background threads; the next plan written to prepared/ survives it, so
                        # let it finish (cycles 037, 041, 045 re-planned from scratch after a pause: 16-38 min).
                        # Owner 2026-10-10: but not the lane planners (a pause waited 31 min for them); their tasks
                        # are queued instead of started (see _launch_lanes_once) and survive the halt.
                        self._halting = True
                        self.join_bg(wait_lanes=False)
                        raise Halt("paused between cycles (start resumes)")
                    why = self.pc_restart_due()
                    if why:
                        self._halting = True
                        self.join_bg(wait_lanes=False)   # same safe point as a pause: keep the prepared next plan
                        self.restart_pc(why)
                    patch = self.pending_patch()
                    if patch:
                        self._halting = True
                        self.join_bg(wait_lanes=False)   # same safe point as a pause: keep the prepared next plan
                        raise PatchReady(f"workflow patch {patch.name} is ready; the supervisor installs it and restarts")
                    if done >= max_cycles:
                        raise Halt(f"cycle cap reached ({max_cycles})")
                    self.start_cycle()
                    done += 1
                else:
                    if self.state.get("merge_check"):
                        self.settle_merge_check(block=ph not in self.MERGE_CHECK_NONBLOCKING)
                    handlers[self.state["phase"]]()
                self.backoff_i = 0
            except NetworkDown as e:
                log(f"network problem ({tail(str(e), 160)}); waiting for the connection")
                self.save(note=f"waiting for network to retry {ph}")
                waited = 0
                while not net_ok() and waited < 6 * 3600:
                    sleep_checked(30)
                    waited += 30
                    if waited % 600 == 0:
                        self.save(note=f"waiting for network to retry {ph} ({waited // 60} min)")
                log(f"network back after ~{waited}s; retrying {ph}")
                sleep_checked(15)
            except UsageLimited as e:
                waits = self.cfg["backoff_s"]
                wait = waits[min(self.backoff_i, len(waits) - 1)]
                self.backoff_i += 1
                log(f"usage limited ({e}); retrying {ph} in {wait}s")
                self.save(note=f"usage limited, retry {ph} at "
                               f"{(datetime.datetime.now() + datetime.timedelta(seconds=wait)):%H:%M}")
                sleep_checked(wait)
            except ScopeDeferred as e:
                self.defer_cycle(str(e))
                self.backoff_i = 0
            except AgentFailed as e:
                if self.try_rescue(str(e)):
                    continue
                self.fail_cycle(str(e))
                cap = self.cfg.get("max_consecutive_failures", 2)
                if self.cfg["on_cycle_fail"] == "halt" or self.state.get("consecutive_failures", 0) >= cap:
                    raise Halt(f"cycle failed: {e}" if self.cfg["on_cycle_fail"] == "halt"
                               else f"{cap} cycles failed in a row; last: {e}")
            except (Halt, KeyboardInterrupt):
                raise
            except Exception as e:
                # A bug or unexpected error inside a phase must not kill the relay: log it, retry the
                # phase twice, then treat it like an agent failure (rescue or park the cycle).
                key = f"crashes_{self.state.get('cycle', 0)}_{ph}"
                n_crash = self.state.get(key, 0) + 1
                crash_log = (self.cyc if ph != "IDLE" else HERE / "logs") / "logs" / f"crash_{int(time.time())}.txt"
                write(crash_log, traceback.format_exc())
                log(f"unexpected error in {ph} ({type(e).__name__}: {e}); see {crash_log.name} "
                    f"[{n_crash}/3]")
                self.save(**{key: n_crash})
                if ph == "IDLE" or n_crash >= 3:
                    if ph == "IDLE":
                        raise Halt(f"unexpected error starting a cycle: {e}")
                    if self.try_rescue(f"controller error in {ph}: {e}"):
                        continue
                    self.fail_cycle(f"controller error in {ph}: {e}")
                    raise Halt(f"repeated controller error in {ph}: {e}")
                sleep_checked(30)


# ---------------------------------------------------------------- status / cli

def render_status(s: dict) -> str:
    pid = s.get("running_pid")
    running = bool(pid and psutil.pid_exists(pid) and LOCK_PATH.exists())
    hist = "\n".join(f"- {h['cycle']:03d} {h['title']} -> {h['commit']}" for h in s.get("history", [])[-5:])
    return (
        f"# {G.NAME} Relay v2\n\n"
        f"Updated: {s.get('updated')}\n"
        f"Controller: {'RUNNING' if running else 'STOPPED'}{' (STOP pending)' if STOP_PATH.exists() else ''}"
        f"{' (PAUSE pending)' if PAUSE_PATH.exists() else ''}\n"
        f"Cycle: {s.get('cycle', 0):03d} | {s.get('title') or '-'}\n"
        f"Phase: {s.get('phase')} (fix attempt {s.get('attempt', 0)})\n"
        f"Branch: {s.get('branch') or '-'}\n"
        f"Agent PID: {s.get('agent_pid') or '-'} | heartbeat {s.get('heartbeat') or '-'}\n"
        f"Last tests: {s.get('tests_passed', '-')}\n"
        f"Last accepted: {s.get('last_good_commit') or '-'}\n"
        f"Note: {s.get('note') or '-'}\n"
        f"Cloud sessions launched: {len(load_json(HERE / 'cloud_ledger.json', []))} (cloud_ledger.json)\n\n"
        f"## Recent accepted\n{hist or '- none'}\n"
    )


def acquire_lock() -> None:
    if LOCK_PATH.exists():
        try:
            pid = int(LOCK_PATH.read_text())
        except ValueError:
            pid = -1
        if pid > 0 and pid != os.getpid() and psutil.pid_exists(pid):
            sys.exit(f"relay already running (pid {pid})")
    LOCK_PATH.write_text(str(os.getpid()))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["start", "status", "stop", "pause", "ping-chatgpt", "playtest"])
    ap.add_argument("--cycles", type=int, default=None)
    a = ap.parse_args()

    if a.cmd == "status":
        print(render_status(load_json(STATE_PATH, dict(DEFAULT_STATE))))
        return
    if a.cmd == "pause":
        PAUSE_PATH.touch()
        print("PAUSE set. The relay finishes the current cycle, then halts; `start` resumes.")
        return
    if a.cmd == "stop":
        STOP_PATH.touch()
        print("STOP set. Active agent will be killed and the loop will halt; `start` resumes.")
        return
    if a.cmd == "playtest":   # one-off playtest of the main branch head (safe while the relay is idle)
        relay = Relay()
        last = (relay.state.get("history") or [{}])[-1]
        n = int(last.get("cycle", 0))
        commit = relay.git("rev-parse", "--short", relay.main)
        print(relay.run_playtest(n, commit))
        return
    if a.cmd == "ping-chatgpt":
        from chatgpt_bridge import ChatGPTBridge
        cfg = load_json(CFG_PATH, None)
        b = ChatGPTBridge(cfg["chatgpt"], log)
        reply = b.ask(P.PING, 120)
        print("chat: OK" if extract(reply, "PING") == "ok" else f"chat: unexpected reply:\n{reply}")
        if cfg["chatgpt"].get("file_mode"):
            modes = sorted({"chat", *cfg["chatgpt"].get("modes", {}).values()})
            for mode in modes:
                probe = HERE / "logs" / f"ping_file_{mode}.txt"
                probe.parent.mkdir(parents=True, exist_ok=True)
                probe.unlink(missing_ok=True)
                b.ask(f"Using your file tools, write the text ok to {probe} and nothing else. "
                      "Then reply with exactly: @@DONE_START@@ok@@DONE_END@@", 300, mode=mode)
                print(f"file [{mode}]: OK" if probe.exists() and read(probe).strip() == "ok"
                      else f"file [{mode}]: FAILED ({probe} not written)")
        return

    STOP_PATH.unlink(missing_ok=True)
    acquire_lock()
    # 2026-10-20: the controller died at 15:01 with nothing in controller.log (a traceback only reaches the supervisor
    # console). Native crashes now land in logs/faults.log and Python ones in controller.log (below).
    import faulthandler
    faulthandler.enable(open(LOG_PATH.with_name("faults.log"), "a", encoding="utf-8"))   # noqa: SIM115 - process-long
    relay = Relay()
    log(f"controller started (pid {os.getpid()}, cycle {relay.state.get('cycle', 0):03d}, "
        f"phase {relay.state.get('phase')})")
    relay.close_stale_tabs(startup=True)
    relay.open_account_chromes()
    exit_code = 0
    try:
        relay.run(a.cycles or relay.cfg["max_cycles_per_run"])
    except Halt as e:
        log(f"halted: {e}")
        t = getattr(relay, "_pt_thread", None)
        if t and t.is_alive() and not STOP_PATH.exists():
            log("waiting for the background playtest to finish (max 5 min)")
            t.join(300)
        if isinstance(e, PatchReady):
            exit_code = PATCH_EXIT
        else:
            notify(f"{G.NAME} relay stopped", str(e))
        relay.save(note=f"halted: {e}")
        if relay.state.get("phase") != "IDLE":   # cycle 038's overnight STOP counted as 1435 min of FINAL
            relay.save(timeline=relay.state.get("timeline", []) + [["HALTED", ts()]])
    except KeyboardInterrupt:
        if relay.state.get("agent_pid"):
            kill_tree(relay.state["agent_pid"])
        log("interrupted (Ctrl+C)")
        relay.save(note="interrupted", agent_pid=None)
    except Exception as e:
        import traceback
        log(f"crashed: {type(e).__name__}: {str(e)[:300]}")
        for line in traceback.format_exc().splitlines()[-14:]:
            log(f"  {line}")
        raise
    finally:
        keep_awake(False)
        relay.save(running_pid=None)
        LOCK_PATH.unlink(missing_ok=True)
    if exit_code:
        sys.exit(exit_code)


if __name__ == "__main__":
    main()
