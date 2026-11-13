"""
Local parallel lane: a second DeepSeek (OpenCode) working in its own git worktree on its own branch, at the
same time as the main relay cycle. The relay merges the branch into the main branch at a cycle boundary,
only after the full test suite passes on the merged result.

    LocalLane.start(task_id, brief_text) -> {"branch", "dir", "pid", "log"}
    LocalLane.running(pid)               -> bool
    LocalLane.finish(info)               -> (tests_passed, test_output_path)   commits the work on the branch
    LocalLane.cleanup(info)                                                    removes the worktree
"""
from __future__ import annotations

import datetime
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Callable

import game as G
import prompts as P

HERE = Path(__file__).resolve().parent
PASSES_PATH = HERE / "suite_passes.json"
REUSE_MAX_AGE_S = 3 * 3600


def coder_pass(wt: Path) -> dict | None:
    """The coder's own passing full-suite run on exactly this worktree content (run_tests.py records lane runs in
    suite_passes.json too), or None. Owner 2026-10-14: the lane checker re-ran each finished lane's ~17 min suite one
    lane at a time, so lane6 finished at 10:08 and was first tested at 11:33. The merge check still runs the full
    suite on the merged result."""
    try:
        import run_tests as RT
        rec = json.loads(PASSES_PATH.read_text(encoding="utf-8")).get(RT.tree_fp(wt))
        if not isinstance(rec, dict) or Path(rec["repo"]).resolve() != Path(wt).resolve():
            return None
        age = time.time() - datetime.datetime.fromisoformat(rec["at"]).timestamp()
    except Exception:   # noqa: BLE001 - reuse is an optimisation only
        return None
    return rec if 0 <= age <= REUSE_MAX_AGE_S else None


# Owner 2026-10-15 ("could deepseek web help"): coders that work through a chat website in the relay's Chrome
# instead of OpenCode. They are listed in opencode.fallback_models like a free model and launched with the same
# instruction; the script reads the brief, does the edits and tests, and writes the report.
WEB_CODERS = {"deepseek-web": ("deepseek_web_coder.py", "DeepSeek web"),
              "gemini-web": ("gemini_web_coder.py", "Gemini web"),
              "mistral-web": ("mistral_web_coder.py", "Mistral web"),
              # Owner 2026-10-29: lane5 takes turns between Gemini and Mistral through the MCP connector.
              "connector-web": ("connector_web_coder.py", "Claude/Mistral web")}


# Owner 2026-10-21: the Google AI Pro plan may code through Google's own Antigravity CLI (never through OpenCode).
# A model named "agy/<model>" runs `agy -p` headless; it reads the brief and writes the report in the relay folder.
AGY_EXE = os.path.join(os.environ.get("LOCALAPPDATA", ""), "agy", "bin", "agy.exe")


# cmd.exe refuses a command line over 8191 characters, and npm's opencode is a .cmd shim. Cycles 248, 255 and 265
# (2026-10-26): the timeout retry added its RETRY NOTE to the ~7.7k instruction and try 2 died at once with "The
# command line is too long."
ARGV_INSTR_MAX = 6000


def short_instr(instr: str) -> str:
    """A long instruction goes to a file under logs/coder_instructions and the coder is told to read it."""
    if len(instr) <= ARGV_INSTR_MAX:
        return instr
    import hashlib
    d = HERE / "logs" / "coder_instructions"
    d.mkdir(parents=True, exist_ok=True)
    p = d / (hashlib.sha1(instr.encode("utf-8")).hexdigest()[:16] + ".md")
    p.write_text(instr, encoding="utf-8")
    return (f"Your full task instruction is in {p.as_posix()}. Read that whole file first and follow every rule in "
            "it exactly, as if it were written here.")


def coder_argv(oc: dict, instr: str) -> list:
    """The command that runs one coder: OpenCode on oc["model"], Antigravity on "agy/...", or a website coder script."""
    web = WEB_CODERS.get(oc.get("model") or "")
    if web:
        return [sys.executable, str(HERE / web[0]), instr]
    if (oc.get("model") or "").startswith("agy/"):
        return [AGY_EXE, "-p", instr, "--model", oc["model"][4:], "--dangerously-skip-permissions",
                "--add-dir", HERE.as_posix()]
    return [oc["cmd"], "run", *oc.get("args", [])] + (["-m", oc["model"]] if oc.get("model") else []) + [short_instr(instr)]


def builder_label(cfg: dict, model: str | None) -> str:
    """Who codes on an OpenCode lane, by the model it actually runs. lane3 logged "Gemini Argon started" while Gemini
    was limited and a free fallback model ran it (2026-10-15)."""
    if model in WEB_CODERS:
        return WEB_CODERS[model][1]
    if model and model == cfg.get("opencode_model"):
        return cfg.get("builder_name", "DeepSeek")
    if model and "deepseek" not in model.lower():
        return model.split("/")[-1]
    return "DeepSeek"


# 2026-10-18: lane coders ran their own focused Godot tests at normal priority while the main cycle's full suite (the
# critical path, ~21 min) ran; 22 Godot processes on 16 threads. A lane coder now starts below normal priority, which
# its shell tools and their Godot runs inherit on Windows, so the main suite gets the CPU first.
LANE_FLAGS = (subprocess.CREATE_NEW_PROCESS_GROUP | 0x4000) if os.name == "nt" else 0   # | BELOW_NORMAL_PRIORITY_CLASS


class LaneError(Exception):
    pass


class LocalLane:
    def __init__(self, repo: Path, main: str, opencode_cfg: dict, lane_cfg: dict, log: Callable[[str], None]):
        self.repo = Path(repo)
        self.main = main
        self.oc = opencode_cfg
        self.cfg = lane_cfg
        self.log = log
        self.root = Path(lane_cfg.get("worktree", G.tmp_dir("lane2")))
        self.runs = HERE / "lanes"

    def _git(self, *args, cwd=None, check=True) -> str:
        # stdin closed and a time limit: a git waiting for input hung cycle 071 for an hour (2026-10-21)
        try:
            r = subprocess.run(["git", *args], cwd=cwd or self.repo, capture_output=True, text=True,
                               stdin=subprocess.DEVNULL, timeout=600)
        except subprocess.TimeoutExpired:
            if check:
                raise LaneError(f"git {' '.join(args[:3])} timed out")
            self.log(f"git {' '.join(args[:3])} timed out; continuing")
            return ""
        if check and r.returncode:
            raise LaneError(f"git {' '.join(args[:3])} failed: {(r.stdout + r.stderr)[-400:]}")
        return r.stdout.strip()

    def start(self, task_id: str, brief: str, base: str | None = None) -> dict:
        branch = f"lane/deepseek-{task_id}"
        self.cleanup({"dir": str(self.root), "branch": None})
        self._git("worktree", "prune", check=False)
        self._git("branch", "-D", branch, check=False)
        self._git("worktree", "add", "-b", branch, str(self.root), base or self.main)
        brief += preapply_redo(self.root, brief)
        # opencode.json is gitignored: give the lane the same sandbox, with its test command on this worktree.
        oc_json = json.loads((self.repo / "opencode.json").read_text(encoding="utf-8"))
        test_cmd = f"python {(HERE / 'run_tests.py').as_posix()} --repo {self.root.as_posix()}"
        oc_json["permissions"] = [p for p in oc_json.get("permissions", []) if "run_tests.py" not in p.get("resource", "")]
        oc_json["permissions"].append({"action": "shell", "resource": test_cmd, "effect": "allow"})
        oc_json["permissions"].append({"action": "edit", "resource": ".review/*", "effect": "deny"})
        (self.root / "opencode.json").write_text(json.dumps(oc_json, indent=2), encoding="utf-8")
        run_dir = self.runs / task_id
        run_dir.mkdir(parents=True, exist_ok=True)
        brief_path = run_dir / "BRIEF.md"
        brief_path.write_text(P.coder_scope(brief) + f"\n\n## Lane rules\n- You are working in {self.root.as_posix()} (your own copy of "
                              f"the repository on branch {branch}). Edit files only there.\n- Run the tests with exactly: "
                              f"{test_cmd}\n  (the shell tool stops a command after 2 minutes unless you pass a timeout: "
                              f"give this one 1800000 ms)\n- Read {(HERE / 'LESSONS.md').as_posix()} first and follow it.\n- Do not "
                              "commit, switch branches, or create/edit PNG art files. Write a short report of what you "
                              f"changed to {(run_dir / 'REPORT.md').as_posix()}.\n" + P.REPORT_TOOL_RULE, encoding="utf-8")
        log_path = run_dir / "opencode.log"
        instr = (f"Read {brief_path.as_posix()} and implement it in this repository. Follow every rule in it.")
        argv = coder_argv(self.oc, instr)
        flags = LANE_FLAGS
        with open(log_path, "wb") as lf:
            proc = subprocess.Popen(argv, cwd=self.root, stdout=lf, stderr=subprocess.STDOUT, creationflags=flags,
                                    shell=(os.name == "nt"))
        model = self.oc.get('model')
        self.log(f"{builder_label(self.cfg, model)} started on {branch} (pid {proc.pid}, {model or 'default model'})")
        return {"branch": branch, "dir": str(self.root), "pid": proc.pid, "log": str(log_path),
                "run_dir": str(run_dir), "started_ts": time.time(), "model": model}

    @staticmethod
    def running(pid: int) -> bool:
        try:
            import psutil
            p = psutil.Process(pid)
            return p.is_running() and p.status() != psutil.STATUS_ZOMBIE
        except Exception:
            return False

    def stop(self, info: dict) -> None:
        try:
            import psutil
            p = psutil.Process(info["pid"])
            for c in p.children(recursive=True):
                c.kill()
            p.kill()
        except Exception:
            pass

    RUN_OUTPUTS = ("REPORT.md", "REPLY.md", "ERROR.txt")

    def killed_by_restart(self, info: dict, since: float) -> bool:
        """The coder process is gone, wrote no report, and its log stopped before `since` (this controller's start):
        it was killed by the restart (PC off, crash), not finished."""
        if not info.get("pid") or self.running(info["pid"]):
            return False
        rd = Path(info.get("run_dir") or "")
        if not info.get("run_dir") or not rd.is_dir() or any((rd / n).exists() for n in self.RUN_OUTPUTS):
            return False
        try:
            last = Path(info["log"]).stat().st_mtime
        except (KeyError, OSError, TypeError):
            last = float(info.get("started_ts") or 0)
        return 0 < last < since

    def fix_run_dir(self, info: dict, n: int) -> Path:
        base = re.sub(r'-fix\d+$', '', Path(info['run_dir']).name)
        d = self.runs / f"{base}-fix{n}"
        d.mkdir(parents=True, exist_ok=True)
        return d

    def resume(self, info: dict, fix_text: str, n: int) -> dict:
        """Fix round: run DeepSeek again in the lane's existing worktree with the defects to fix."""
        run_dir = self.fix_run_dir(info, n)
        test_cmd = f"python {(HERE / 'run_tests.py').as_posix()} --repo {self.root.as_posix()}"
        oc_json = json.loads((self.repo / "opencode.json").read_text(encoding="utf-8"))
        oc_json["permissions"] = [p for p in oc_json.get("permissions", []) if "run_tests.py" not in p.get("resource", "")]
        oc_json["permissions"].append({"action": "shell", "resource": test_cmd, "effect": "allow"})
        oc_json["permissions"].append({"action": "edit", "resource": ".review/*", "effect": "deny"})
        (self.root / "opencode.json").write_text(json.dumps(oc_json, indent=2), encoding="utf-8")
        brief_path = run_dir / "BRIEF.md"
        brief_path.write_text(P.coder_scope(fix_text) + f"\n\n## Lane rules\n- You are working in {self.root.as_posix()} (your own copy "
                              f"of the repository on branch {info['branch']}). Edit files only there.\n- Run the tests "
                              f"with exactly: {test_cmd}\n  (the shell tool stops a command after 2 minutes unless you "
                              f"pass a timeout: give this one 1800000 ms)\n"
                              # 2026-10-19: fix rounds and usage-limit continuations had no lessons line
                              f"- Read {(HERE / 'LESSONS.md').as_posix()} first and follow it.\n"
                              f"- Do not commit, switch branches, or create/edit PNG art files. "
                              f"Write a short report of what you changed to {(run_dir / 'REPORT.md').as_posix()}.\n" + P.REPORT_TOOL_RULE,
                              encoding="utf-8")
        log_path = run_dir / "opencode.log"
        instr = f"Read {brief_path.as_posix()} and fix the work in this repository. Follow every rule in it."
        argv = coder_argv(self.oc, instr)
        flags = LANE_FLAGS
        with open(log_path, "wb") as lf:
            proc = subprocess.Popen(argv, cwd=self.root, stdout=lf, stderr=subprocess.STDOUT, creationflags=flags,
                                    shell=(os.name == "nt"))
        return {**info, "pid": proc.pid, "log": str(log_path), "run_dir": str(run_dir), "started_ts": time.time(),
                "model": self.oc.get("model")}

    def finish(self, info: dict, title: str) -> tuple[bool, Path]:
        """Run the suite on the lane's worktree and commit the work on its branch."""
        wt = Path(info["dir"])
        out = Path(info["run_dir"]) / f"TESTS_{int(time.time())}.txt"
        if not self.changed(info):
            # No edits and no commits: the controller gives the task up ("the lane made no changes"), so skip the
            # suite. lane3 ran an 18-minute suite on an empty result from a free fallback model (2026-10-15).
            out.write_text("The lane made no changes; the suite was not run.\n", encoding="utf-8")
            return False, out
        # A suite that overruns is a FAILED run the coder fixes, not an exception: the exception left the lane
        # "finished" so the checker re-ran the same hung suite every 20 minutes, blocking every other lane and
        # leaking the hung Godot each time (lane4, 2026-10-11). Kill the whole tree on the way out.
        reuse = coder_pass(wt) if self.cfg.get("reuse_coder_suite", True) else None
        if reuse:
            r = subprocess.CompletedProcess([], 0, f"Reused the coder's passing full-suite run from {reuse['at']}: "
                                                   f"nothing in this worktree changed since.\n\n{reuse.get('summary')}\n", "")
        else:
            r = self._suite(wt)
        out.write_text(r.stdout or "", encoding="utf-8")
        (wt / "opencode.json").unlink(missing_ok=True)
        self._drop_stray_reports(wt, info.get("base_start") or info.get("base_commit") or getattr(self, "main", "HEAD"))
        self._git("add", "-A", cwd=wt)
        if subprocess.run(["git", "diff", "--cached", "--quiet"], cwd=wt).returncode == 0:
            # Nothing new to commit (a fix round that correctly changed nothing, or work already committed) is not
            # a test failure: report the suite result. The controller still gives up a lane with no commits at all
            # ("the lane made no changes"). Returning False here made lane3 Codex fail two fix rounds on a
            # 361/361-passing suite and lose its work (2026-10-11).
            return r.returncode == 0, out
        self._git("commit", "--no-verify", "-m", f"{self.cfg.get('label', 'DeepSeek lane')}: {title}", cwd=wt)
        return r.returncode == 0, out

    STRAY_REPORTS = ("REPORT.md",)

    def _drop_stray_reports(self, wt: Path, base: str) -> None:
        """Owner 2026-10-17: free-model coders wrote their report as REPORT.md at the worktree root and committed it;
        the review rejects it as an out-of-scope file and lane3's Unfolders task (and lane4's Cat Curio, 2026-10-12)
        was given up after its fix round. A root report the base never had is removed before the lane's commit."""
        for name in self.STRAY_REPORTS:
            if subprocess.run(["git", "cat-file", "-e", f"{base}:{name}"], cwd=wt,
                              capture_output=True).returncode == 0:
                continue   # the project tracks it: a real file
            self._git("rm", "-q", "--cached", "--ignore-unmatch", name, cwd=wt, check=False)
            (wt / name).unlink(missing_ok=True)

    def changed(self, info: dict) -> bool:
        """Has the lane edited anything (ignoring its gitignored opencode.json) or committed past its base?"""
        wt = Path(info["dir"])
        if self._git("status", "--porcelain", cwd=wt, check=False):
            return True
        base = info.get("base_start") or info.get("base_commit") or self.main
        return self._git("rev-list", "--count", f"{base}..HEAD", cwd=wt, check=False) not in ("", "0")

    @staticmethod
    def _progress(path: Path):
        """(mtime, "done last-test") of run_tests' progress file, or None before the first test ends."""
        try:
            return path.stat().st_mtime_ns, path.read_text(encoding="utf-8").strip()
        except OSError:
            return None

    def _suite(self, wt: Path) -> subprocess.CompletedProcess:
        """Lane 2's MoodState (2026-10-18) was given up after a 45-min suite limit called "a test hangs" while the
        lane suites were only queued behind the cycle's and the merge check's suites (every test already has its own
        cap in run_tests). The suite is now stopped when no test has finished or waited for a slot for test_stall_s,
        a real hang; a suite still making progress gets test_busy_factor x test_timeout_s, and its message says the
        limit is the relay's, so a fix round does not hunt a hang that is not there."""
        limit = int(self.cfg.get("test_timeout_s", 1200))
        stall = int(self.cfg.get("test_stall_s", 1200))
        hard = int(limit * float(self.cfg.get("test_busy_factor", 2.5)))
        prog = Path(tempfile.gettempdir()) / f"relay_suite_progress_{os.getpid()}_{wt.name}.txt"
        prog.unlink(missing_ok=True)
        p = subprocess.Popen(["python", str(HERE / "run_tests.py"), "--repo", str(wt)], cwd=wt, stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace",
                             env=dict(os.environ, RELAY_PROGRESS_FILE=str(prog)))
        start = last = time.monotonic()
        seen, why = None, ""
        while True:
            try:
                text, _ = p.communicate(timeout=max(0, min(60, stall)))
                rc = p.returncode
                break
            except subprocess.TimeoutExpired:
                now, cur = time.monotonic(), self._progress(prog)
                if cur != seen:
                    seen, last = cur, now
                if now - last >= stall:
                    why = "stall"
                elif now - start >= hard:
                    why = "busy"
                else:
                    continue
            subprocess.run(["taskkill", "/F", "/T", "/PID", str(p.pid)], capture_output=True)
            try:
                text, _ = p.communicate(timeout=30)
            except subprocess.TimeoutExpired:
                text = ""
            done = (seen[1].split(" ", 1)[0] if seen else "0")
            if why == "stall":
                text = (text or "") + (f"\nFAIL: no test finished for {stall}s ({done} tests had finished): a test or "
                                       "the test runner hangs. Look for a loop that never ends, an await that never "
                                       "resolves, or a missing quit().\n")
            else:
                text = (text or "") + (f"\nFAIL: the suite was still making progress ({done} tests finished) but did "
                                       f"not finish within {hard}s because the PC was busy with other suites. This is "
                                       "the relay's time limit, not a hang or a defect in your code: change nothing "
                                       "for it; the relay runs the suite again.\n")
            rc = 1
            break
        prog.unlink(missing_ok=True)
        return subprocess.CompletedProcess(p.args, rc, text, "")

    def cleanup(self, info: dict) -> None:
        d = Path(info.get("dir") or self.root)
        if d.exists():
            self._git("worktree", "remove", "--force", str(d), check=False)
            shutil.rmtree(d, ignore_errors=True)
        self._git("worktree", "prune", check=False)
        if info.get("branch"):
            self._git("branch", "-D", info["branch"], check=False)


# ---------------------------------------------------------------- ChatGPT lanes

_THREADS: dict = {}

CHAT_LANE_PROMPT = """\
You are a coding agent in an automated Godot 4.7.2 game-development relay ({game}). Other agents work on
other tasks at the same time, each in its own copy of the repository.
Use the SentinelX connector on host {host} (this Windows PC) for every file read, file write and command.

Your own copy of the repository (a git worktree on branch {branch}) is:
{root}
Read the task at {brief} and implement it completely in that folder.

Rules:
- Edit files ONLY inside {root}. Never touch {repo} itself, and never anything under .review/ except the report.
- Run the tests with: {test_cmd}
  SentinelX may refuse python or Godot as direct commands; then run them inside a PowerShell script (script_run)
  that first does Set-Location '{root}'. Run Godot only with --headless. Iterate until every test passes; never
  delete, skip or weaken tests.
- SentinelX stops a script after 600 s and the full suite takes 20+ minutes on this busy PC, so run your focused and
  related tests (each file alone: the Godot console exe named by GODOT in run_tests.py with
  --headless --path '{root}' -s res://tests/<name>.gd). If the full suite
  cannot finish within SentinelX's limit, say so in the report and finish as COMPLETED: the relay runs the full suite
  on your committed work itself and sends you any failure. Never DEFER only because the full suite did not finish.
- git is read-only, as `git -c safe.directory=* -C {root} ...`. Never commit, checkout, reset, stash, merge or switch
  branches: the relay commits your work.
- Never create or edit PNG/art files. Leave no scratch or debug files in the folder.
When finished, write a short report (what you changed, the final test result) to:
{report}
and then reply with exactly: @@DONE_START@@ok@@DONE_END@@
"""
CHAT_LANE_PROMPT = CHAT_LANE_PROMPT.replace("({game})", f"({G.NAME})")


UNION_EXT = (".gd", ".tres", ".md")


def keep_both_inserts(text: bytes) -> bytes | None:
    """Resolve diff3 conflict blocks in which both sides only ADDED lines: lines shared by all three versions
    (a closing "}])") stay once, then the lines both sides added alike, then ours' extra lines, then theirs'.
    Covers two lanes appending catalog entries, and a lane branch that already holds main's entry plus its own
    (Gloam Ague, 2026-10-11). None when any block changed or removed an existing line (a real conflict)."""
    out, part, ours, base, theirs = [], None, [], [], []
    for line in text.splitlines(keepends=True):
        if part is None and line.startswith(b"<<<<<<< "):
            part, ours, base, theirs = "ours", [], [], []
        elif part == "ours" and line.startswith(b"||||||| "):
            part = "base"
        elif part in ("ours", "base") and line.rstrip(b"\r\n") == b"=======":
            part = "theirs"
        elif part == "theirs" and line.startswith(b">>>>>>> "):
            tail_lines = []
            while ours and base and theirs and ours[-1] == base[-1] == theirs[-1]:
                tail_lines.insert(0, ours.pop())
                base.pop()
                theirs.pop()
            head = []
            while ours and base and theirs and ours[0] == base[0] == theirs[0]:
                head.append(ours.pop(0))
                base.pop(0)
                theirs.pop(0)
            if any(l.strip() for l in base):
                return None
            # one side may already hold the other's lines (a branch rebuilt on top of main's new entry)
            if theirs[:len(ours)] == ours:
                middle = theirs
            elif ours[:len(theirs)] == theirs:
                middle = ours
            else:
                middle = ours + theirs
            out += head + middle + tail_lines
            part = None
        elif part is None:
            out.append(line)
        else:
            {"ours": ours, "base": base, "theirs": theirs}[part].append(line)
    return None if part is not None else b"".join(out)


GD_DECL = re.compile(rb"^(?:@\w+(?:\([^)\n]*\))?\s+)*(?:static\s+)?(func|var|const|signal|enum|class)\s+(\w+)",
                     re.M)


def gd_duplicates(data: bytes) -> set:
    """Top-level GDScript names declared more than once (a parse error that stops the whole game loading)."""
    seen, dup = set(), set()
    for kind, name in GD_DECL.findall(data):
        key = (b"func" if kind == b"func" else b"member", name)
        (dup if key in seen else seen).add(key)
    return dup


def resolve_clashes(cwd: Path, files: list[str]) -> bool:
    """Keep both sides of every insert-only clash in the unmerged FILES of the repository or worktree at CWD and
    stage them. False (nothing written) when a file is not plain .gd/.tres/.md, was added or deleted on one side,
    or any block changed an existing line."""
    import tempfile
    # 2026-11-06: Godot's own .import/.uid sidecars clash when both sides imported the same new art (only the random
    # uid differs); keep the main branch's side ("ours") of those and resolve the rest as usual
    gen = [f for f in files if f.endswith((".import", ".uid"))]
    if gen and not any(subprocess.run(a, cwd=cwd, capture_output=True).returncode
                       for a in (["git", "checkout", "--ours", "--", *gen], ["git", "add", "--", *gen])):
        files = [f for f in files if f not in gen]
        if not files:
            return True
    if not files or not all(f.endswith(UNION_EXT) for f in files):
        return False
    merged = {}
    for f in files:
        stages = []
        for n in (1, 2, 3):
            r = subprocess.run(["git", "show", f":{n}:{f}"], cwd=cwd, capture_output=True)
            if r.returncode:
                return False
            stages.append(r.stdout)
        with tempfile.TemporaryDirectory() as td:
            paths = []
            for name, data in zip(("base", "ours", "theirs"), stages):
                (Path(td) / name).write_bytes(data)
                paths.append(str(Path(td) / name))
            # diff3 style keeps a line both sides added (the "}, {" before a new catalog entry) inside each side
            # of the clash; plain --union shared it and broke the .tres file.
            r = subprocess.run(["git", "merge-file", "-p", "--diff3", paths[1], paths[0], paths[2]],
                               capture_output=True, cwd=td)
        # merge-file returns the number of conflicts (capped at 127); anything else is an error with empty output,
        # which was once taken as "resolved" and wrote the file empty (owner 2026-10-13)
        if r.returncode < 0 or r.returncode > 127 or (not r.stdout and any(stages)):
            return False
        out = keep_both_inserts(r.stdout)
        if out is None:
            return False
        # 2026-10-26: two lanes each added a `func _input` to live_campfire_panel.gd; keeping both sides declared it
        # twice, the app failed to parse and every mounted test broke (cycles 283 and 286). Refuse that union.
        if f.endswith(".gd") and gd_duplicates(out) - gd_duplicates(stages[1]) - gd_duplicates(stages[2]):
            return False
        merged[f] = out
    for f, data in merged.items():
        (Path(cwd) / f).write_bytes(data)
        subprocess.run(["git", "add", "--", f], cwd=cwd, capture_output=True)
    return True


REDO_PATCH = re.compile(r"the diff (\S+ACCEPTED\.patch)")


def preapply_redo(root: Path, brief: str) -> str:
    """A redo task (its accepted diff could not merge) used to make the coder re-type the whole diff by hand. Apply
    that diff to the fresh worktree first (3-way), keep both sides of insert-only clashes, and return a note for
    the brief saying what is left. "" for a normal task."""
    found = REDO_PATCH.findall(brief)
    if not found or not Path(found[-1]).is_file():
        return ""
    patch = found[-1]
    git = lambda *a: subprocess.run(["git", *a], cwd=root, capture_output=True, text=True, encoding="utf-8",
                                    errors="replace")
    data = Path(patch).read_bytes()
    if b"\r\n" in data:   # written in Windows text mode: git apply --3way refuses CRLF patches
        patch = str(Path(patch).with_name("ACCEPTED.lf.patch"))
        Path(patch).write_bytes(data.replace(b"\r\n", b"\n"))
    r = git("apply", "--3way", "--whitespace=nowarn", patch)
    unmerged = sorted(set(git("diff", "--name-only", "--diff-filter=U").stdout.split()))
    if r.returncode and not unmerged:
        return ("\n## Relay pre-apply\nThe relay could NOT apply the accepted diff automatically "
                f"({(r.stderr or r.stdout).strip()[-300:]}). Re-apply it by hand as described above.\n")
    left = []
    for f in unmerged:
        if not resolve_clashes(root, [f]):
            left.append(f)
    git("reset", "-q")   # plain working-tree changes for the coder; finish() stages everything again
    note = ("\n## Relay pre-apply\nThe relay ALREADY applied the accepted diff to your worktree (3-way)"
            + (f"; it kept both sides of the clashes in {', '.join(f for f in unmerged if f not in left)}"
               if len(left) < len(unmerged) else "") + ".\n")
    if left:
        note += ("These files still contain <<<<<<< / ======= / >>>>>>> conflict markers that you MUST resolve: "
                 f"{', '.join(left)}. Keep the current main code AND the task's additions; where a test asserts an "
                 "exact count of catalog entries, assert that this task's own entries exist instead.\n")
    note += ("Do not apply the diff again. Check the result against the task, make it work with the current code, "
             "and run the tests.\n")
    return note


def lessons_rule() -> str:
    """ChatGPT lanes get the shared lessons too (owner 2026-10-10); they read files through SentinelX."""
    return (f"\n\n## Lessons\nRead {(HERE / 'LESSONS.md').as_posix()} first: lessons from earlier work on this "
            "codebase (all coders). Follow them.\n")


class ChatLane(LocalLane):
    """A ChatGPT lane (Work or Chat mode) that edits its own worktree through the SentinelX connector."""

    def __init__(self, repo: Path, main: str, chatgpt_cfg: dict, lane_cfg: dict, log: Callable[[str], None],
                 key: str):
        super().__init__(repo, main, {}, lane_cfg, log)
        self.gcfg = chatgpt_cfg
        self.key = key
        self.root = Path(repo) / ".lanes" / key

    def _prepare(self) -> None:
        lanes = self.repo / ".lanes"
        lanes.mkdir(exist_ok=True)
        (lanes / ".gdignore").write_text("", encoding="utf-8")
        excl = self.repo / ".git" / "info" / "exclude"
        text = excl.read_text(encoding="utf-8") if excl.exists() else ""
        if "/.lanes/" not in text.split():
            excl.write_text(text.rstrip("\n") + "\n/.lanes/\n", encoding="utf-8")

    def start(self, task_id: str, brief: str, base: str | None = None) -> dict:
        import sys
        import threading
        self._prepare()
        branch = f"lane/{self.key}-{task_id}"
        self.cleanup({"dir": str(self.root), "branch": None})
        self._git("worktree", "prune", check=False)
        self._git("branch", "-D", branch, check=False)
        self._git("worktree", "add", "-b", branch, str(self.root), base or self.main)
        brief += preapply_redo(self.root, brief)
        run_dir = self.runs / task_id
        run_dir.mkdir(parents=True, exist_ok=True)
        (run_dir / "STARTED").write_text(str(time.time()), encoding="utf-8")
        report = run_dir / "REPORT.md"
        brief_path = run_dir / "BRIEF.md"
        brief_path.write_text(P.coder_scope(brief) + lessons_rule(), encoding="utf-8")
        test_cmd = f'"{sys.executable}" "{HERE / "run_tests.py"}" --repo "{self.root}"'
        prompt = CHAT_LANE_PROMPT.format(host=self.gcfg.get("sentinel_host", "win-julespc"), branch=branch,
                                         root=self.root, brief=brief_path, repo=self.repo, test_cmd=test_cmd,
                                         report=report)
        (run_dir / "PROMPT.md").write_text(prompt, encoding="utf-8")
        mode, timeout = self.cfg.get("mode", "chat"), int(self.cfg.get("timeout_s", 4500))

        def run() -> None:
            from chatgpt_bridge import ChatGPTBridge
            b = ChatGPTBridge(self.gcfg, self.log)
            done = lambda: report.exists() and time.time() - report.stat().st_mtime > 20   # noqa: E731
            try:
                reply = b.ask(prompt, timeout, mode=mode, effort=self.cfg.get("effort", "high"), done=done)
                (run_dir / "REPLY.md").write_text(reply or "", encoding="utf-8")
            except Exception as e:   # noqa: BLE001
                (run_dir / "ERROR.txt").write_text(repr(e), encoding="utf-8")
                self.log(f"{self.key}: ChatGPT run failed: {str(e)[:200]}")
            finally:
                try:
                    b.disconnect()
                except Exception:   # noqa: BLE001
                    pass

        t = threading.Thread(target=run, name=f"{self.key}-{task_id}", daemon=True)
        t.start()
        _THREADS[task_id] = t
        self.log(f"{self.key}: ChatGPT ({mode} mode) started on {branch}")
        return {"branch": branch, "dir": str(self.root), "pid": task_id, "log": str(run_dir / "REPLY.md"),
                "run_dir": str(run_dir), "started_ts": time.time()}

    def running(self, pid) -> bool:
        """pid is the task id. After a relay restart the ChatGPT conversation keeps working server-side, so the
        lane counts as running until it writes its report/reply or times out."""
        t = _THREADS.get(str(pid))
        if t is not None:
            return t.is_alive()
        rd = self.runs / str(pid)
        if any((rd / n).exists() for n in ("REPORT.md", "REPLY.md", "ERROR.txt")):
            return False
        try:
            started = float((rd / "STARTED").read_text(encoding="utf-8"))
        except (OSError, ValueError):
            return False
        return time.time() - started < int(self.cfg.get("timeout_s", 4500))

    def stop(self, info: dict) -> None:
        pass   # a ChatGPT conversation cannot be stopped from here; cleanup removes its worktree

    def killed_by_restart(self, info: dict, since: float) -> bool:
        """No thread for the conversation in this process, no report or reply, and it started before `since`: the
        relay that was reading ChatGPT's work died (lane7, PC off 2026-10-17), so nothing will apply it."""
        if _THREADS.get(str(info.get("pid"))) is not None:
            return False
        rd = Path(info.get("run_dir") or "")
        if not info.get("run_dir") or not rd.is_dir() or any((rd / n).exists() for n in self.RUN_OUTPUTS):
            return False
        try:
            started = float((rd / "STARTED").read_text(encoding="utf-8"))
        except (OSError, ValueError):
            started = float(info.get("started_ts") or 0)
        return 0 < started < since

    def orphaned(self, info: dict, grace_s: int = 1200) -> bool:
        """After a relay restart (no thread for it in this process), a conversation that has changed nothing in its
        worktree for grace_s since it started was most likely cut off before ChatGPT began working (lane7 idled the
        full 75-minute timeout, 2026-10-10)."""
        pid = str(info.get("pid"))
        if _THREADS.get(pid) is not None:
            return False
        rd = self.runs / pid
        if any((rd / n).exists() for n in ("REPORT.md", "REPLY.md", "ERROR.txt")):
            return False
        try:
            started = float((rd / "STARTED").read_text(encoding="utf-8"))
        except (OSError, ValueError):
            return False
        if time.time() - started < grace_s:
            return False
        r = subprocess.run(["git", "-c", "safe.directory=*", "-C", str(info.get("dir")), "status", "--porcelain"],
                           capture_output=True, text=True)
        return r.returncode == 0 and not r.stdout.strip()


def _chat_lane_resume(self, info: dict, fix_text: str, n: int) -> dict:
    """Fix round for a ChatGPT lane: a new conversation in the same worktree with the defects to fix."""
    import sys
    import threading
    run_dir = self.fix_run_dir(info, n)
    tid = run_dir.name
    (run_dir / "STARTED").write_text(str(time.time()), encoding="utf-8")
    report = run_dir / "REPORT.md"
    brief_path = run_dir / "BRIEF.md"
    brief_path.write_text(P.coder_scope(fix_text) + lessons_rule(), encoding="utf-8")
    test_cmd = f'"{sys.executable}" "{HERE / "run_tests.py"}" --repo "{self.root}"'
    prompt = CHAT_LANE_PROMPT.format(host=self.gcfg.get("sentinel_host", "win-julespc"), branch=info["branch"],
                                     root=self.root, brief=brief_path, repo=self.repo, test_cmd=test_cmd, report=report)
    (run_dir / "PROMPT.md").write_text(prompt, encoding="utf-8")
    mode, timeout = self.cfg.get("mode", "chat"), int(self.cfg.get("timeout_s", 4500))

    def run() -> None:
        from chatgpt_bridge import ChatGPTBridge
        b = ChatGPTBridge(self.gcfg, self.log)
        done = lambda: report.exists() and time.time() - report.stat().st_mtime > 20   # noqa: E731
        try:
            reply = b.ask(prompt, timeout, mode=mode, effort=self.cfg.get("effort", "high"), done=done)
            (run_dir / "REPLY.md").write_text(reply or "", encoding="utf-8")
        except Exception as e:   # noqa: BLE001
            (run_dir / "ERROR.txt").write_text(repr(e), encoding="utf-8")
        finally:
            try:
                b.disconnect()
            except Exception:   # noqa: BLE001
                pass

    t = threading.Thread(target=run, name=f"{self.key}-{tid}", daemon=True)
    t.start()
    _THREADS[tid] = t
    return {**info, "pid": tid, "log": str(run_dir / "REPLY.md"), "run_dir": str(run_dir), "started_ts": time.time()}


ChatLane.resume = _chat_lane_resume


# ---------------------------------------------------------------- Codex lanes (owner 2026-10-10)

def codex_exe(cfg: dict) -> str:
    """The Codex CLI bundled with the Codex desktop app. Its WindowsApps folder changes with every app update,
    so it is looked up through the package unless relay.json names a path that exists."""
    cmd = cfg.get("cmd") or ""
    if cmd and (Path(cmd).exists() or shutil.which(cmd)):
        return cmd
    r = subprocess.run(["powershell", "-NoProfile", "-Command", "(Get-AppxPackage OpenAI.Codex).InstallLocation"],
                       capture_output=True, text=True)
    exe = Path(r.stdout.strip()) / "app" / "resources" / "codex.exe"
    if not r.stdout.strip() or not exe.exists():
        raise LaneError("Codex CLI not found (install the Codex app or set codex_cli.cmd in relay.json)")
    return str(exe)


# Codex only spawns subagents when told to directly (owner 2026-10-10: use them), so this is an instruction, not a hint.
# Owner 2026-10-10: subagents only for SMALL pieces inside the task (they used a lot of ChatGPT usage).
SUBAGENT_HINT = ("- Subagents: use them ONLY for small, self-contained pieces inside this task, e.g. a quick look-up "
                 "(where something is defined or used) or one small helper/test in a file nobody else edits; at most "
                 "2 per task. Never hand the whole task or a major part of it to a subagent: you design, implement "
                 "and integrate the change yourself, and you run the full test suite yourself before finishing.\n")


def codex_argv(cx: dict, run_cfg: dict, cwd: Path, instr: str, last_msg: Path, add_dirs=(), images=()) -> list[str]:
    """`codex exec` with the owner's ChatGPT sign-in, full terminal access (owner 2026-10-10) and subagents.
    `images` ride along with -i (right after exec: -i takes several values, so a later flag must end them)."""
    sandbox = run_cfg.get("sandbox", cx.get("sandbox", "danger-full-access"))
    argv = [codex_exe(cx), "exec", *[a for im in images if Path(im).exists() for a in ("-i", str(im))], "--cd", str(cwd), "--sandbox", sandbox, "--json",
            "-c", 'approval_policy="never"', "-o", str(last_msg)]
    if cx.get("subagents", True):
        argv += ["--enable", "multi_agent"]
    if sandbox != "danger-full-access":
        for d in [*add_dirs, *cx.get("writable_dirs", [])]:
            argv += ["--add-dir", os.path.expandvars(str(d))]
    model, effort = run_cfg.get("model") or cx.get("model"), run_cfg.get("effort") or cx.get("effort")
    if model:
        argv += ["-m", model]
    if effort:
        argv += ["-c", f'model_reasoning_effort="{effort}"']
    return argv + [instr]


class CodexLane(LocalLane):
    """A Codex CLI lane: `codex exec` (signed in with the owner's ChatGPT account) edits its own git worktree and
    runs commands and tests directly in a terminal. Fix rounds run Codex again in the same worktree."""

    def __init__(self, repo: Path, main: str, codex_cfg: dict, lane_cfg: dict, log: Callable[[str], None], key: str):
        super().__init__(repo, main, {}, lane_cfg, log)
        self.cx = codex_cfg
        self.key = key
        self.root = Path(lane_cfg.get("worktree", G.tmp_dir(key)))

    def _launch(self, run_dir: Path, branch: str, text: str, verb: str) -> dict:
        import sys
        test_cmd = f'"{sys.executable}" "{HERE / "run_tests.py"}" --repo "{self.root}"'
        brief_path = run_dir / "BRIEF.md"
        brief_path.write_text(P.coder_scope(text) + f"\n\n## Lane rules\n- You are working in {self.root.as_posix()} "
                              f"(your own copy of the repository on branch {branch}). Edit files only there.\n"
                              f"- Run the tests with exactly: {test_cmd}\n  Run Godot only with --headless. Iterate "
                              "until every test passes; never delete, skip or weaken tests.\n"
                              f"- Read {(HERE / 'LESSONS.md').as_posix()} first and follow it.\n- Do not commit, "
                              "switch branches, reset, stash or merge (the relay commits your work), and do not "
                              "create/edit PNG art files or anything under .review/. Leave no scratch files.\n"
                              + (SUBAGENT_HINT if self.cx.get("subagents", True) else "") +
                              f"- When finished, write a short report (what you changed, acceptance-criteria "
                              f"evidence, the final test result) to {(run_dir / 'REPORT.md').as_posix()}.\n" + P.REPORT_TOOL_RULE,
                              encoding="utf-8")
        instr = f"Read {brief_path.as_posix()} and {verb} in this repository. Follow every rule in it."
        argv = codex_argv(self.cx, self.cfg, self.root, instr, run_dir / "LAST_MESSAGE.md", [run_dir])
        log_path = run_dir / "codex.log"
        flags = LANE_FLAGS
        with open(log_path, "wb") as lf:
            proc = subprocess.Popen(argv, cwd=self.root, stdin=subprocess.DEVNULL, stdout=lf,
                                    stderr=subprocess.STDOUT, creationflags=flags)
        return {"pid": proc.pid, "log": str(log_path), "run_dir": str(run_dir), "started_ts": time.time()}

    def start(self, task_id: str, brief: str, base: str | None = None) -> dict:
        branch = f"lane/codex-{task_id}"
        self.cleanup({"dir": str(self.root), "branch": None})
        self._git("worktree", "prune", check=False)
        self._git("branch", "-D", branch, check=False)
        self._git("worktree", "add", "-b", branch, str(self.root), base or self.main)
        brief += preapply_redo(self.root, brief)
        run_dir = self.runs / task_id
        run_dir.mkdir(parents=True, exist_ok=True)
        info = self._launch(run_dir, branch, brief, "implement it")
        self.log(f"{self.key}: Codex started on {branch} (pid {info['pid']})")
        return {"branch": branch, "dir": str(self.root), **info}

    def resume(self, info: dict, fix_text: str, n: int) -> dict:
        run_dir = self.fix_run_dir(info, n)
        self.root = Path(info["dir"])
        return {**info, **self._launch(run_dir, info["branch"], fix_text, "fix the work")}
