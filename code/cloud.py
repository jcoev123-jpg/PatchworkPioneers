"""
Claude Code cloud sessions for the relay (`claude --cloud`), paid from the
cloud-sessions bonus credit while it lasts.

A cloud VM clones the GitHub remote at the local repo's *current branch*, so each
launch pushes a branch carrying a `.cloud/` context commit and checks that branch
out locally while launching. The session pushes its result to a `claude/...`
branch with a marker file (`.cloud/RESULT.md` or `.cloud/AUDIT.md`). The CLI has
no "wait for session" call, so the controller polls that branch with git fetch.

Every launch is appended to cloud_ledger.json.
"""
from __future__ import annotations

import datetime
import json
import re
import subprocess
import time
from pathlib import Path
from typing import Callable


ANSI_RE = re.compile(r"\x1b\[[0-9;?]*[ -/]*[@-~]|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)|\x1b[@-_]")
SESSION_RE = re.compile(r"\b((?:session|cse)_[A-Za-z0-9]{10,})")
URL_RE = re.compile(r"https://claude\.ai/code/[A-Za-z0-9_\-/]+")


LAUNCH_INSTRUCTION = ("Read the file .cloud/PROMPT.md in this repository and follow its instructions "
                      "exactly. It is your complete task.")


class CloudError(Exception):
    pass


class Cloud:
    def __init__(self, cfg: dict, claude_cmd: str, repo: Path, here: Path,
                 git: Callable[..., str], log: Callable[[str], None]):
        self.cfg = cfg
        self.claude_cmd = claude_cmd
        self.repo = repo
        self.ledger_path = here / "cloud_ledger.json"
        self.git = git
        self.log = log

    @property
    def remote(self) -> str:
        return self.cfg.get("remote", "origin")

    def available(self) -> bool:
        if not self.cfg.get("enabled"):
            return False
        if datetime.date.today().isoformat() > self.cfg.get("until", "9999-12-31"):
            return False
        r = subprocess.run(["git", "remote", "get-url", self.remote], cwd=self.repo,
                           capture_output=True, text=True)
        return r.returncode == 0

    # ---- ledger

    def ledger(self) -> list[dict]:
        try:
            return json.loads(self.ledger_path.read_text(encoding="utf-8"))
        except (FileNotFoundError, json.JSONDecodeError):
            return []

    def _record(self, entry: dict) -> None:
        rows = self.ledger()
        rows.append(entry)
        self.ledger_path.write_text(json.dumps(rows, indent=2), encoding="utf-8")

    def launches_since(self, since: str) -> int:
        return sum(1 for r in self.ledger() if r.get("at", "") >= since)

    # ---- launch / results

    def push_context(self, branch: str, files: dict[str, str], message: str) -> str:
        """Commit `files` (under .cloud/) on HEAD and push HEAD to `branch`. Returns the commit."""
        for rel, text in files.items():
            p = self.repo / rel
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(text, encoding="utf-8")
        self.git("add", "-f", ".cloud")
        self.git("commit", "--no-verify", "-m", message)
        ctx = self.git("rev-parse", "HEAD")
        self.git("push", "--force", self.remote, f"HEAD:refs/heads/{branch}")
        return ctx

    def launch(self, kind: str, label: str, prompt: str, log_path: Path) -> dict:
        """Start a cloud session on the repo's current branch (must already be pushed)."""
        log_path.parent.mkdir(parents=True, exist_ok=True)
        try:
            out = self._run_in_pty([self.claude_cmd, "--cloud", LAUNCH_INSTRUCTION],
                                   self.cfg.get("launch_timeout_s", 600))
        except CloudError:
            raise
        except Exception as e:   # pty/spawn problems must never crash the relay
            raise CloudError(f"cloud launch error: {e!r}") from e
        log_path.write_text(out, encoding="utf-8")
        sid = SESSION_RE.search(out)
        url = URL_RE.search(out)
        if not sid:
            raise CloudError(f"cloud launch failed: {out.strip()[-400:]}")
        entry = {"at": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"), "kind": kind,
                 "label": label, "session_id": sid.group(1), "url": url.group(0) if url else None}
        self._record(entry)
        self.log(f"cloud {kind} launched: {entry['session_id']} {entry['url'] or ''}")
        return entry

    def _run_in_pty(self, argv: list[str], timeout_s: int) -> str:
        """`claude --cloud` refuses to run without a TTY. Run it in a pseudo-terminal, read until
        the session id appears (or it exits/times out), then close the local CLI; the cloud
        session keeps running on its own."""
        try:
            from winpty import PtyProcess  # Windows ConPTY
        except ImportError as e:
            raise CloudError("pywinpty is required for cloud launches (pip install pywinpty)") from e
        import threading
        cmd = subprocess.list2cmdline(argv)
        proc = PtyProcess.spawn(cmd, cwd=str(self.repo), dimensions=(50, 200))
        chunks: list[str] = []
        done = threading.Event()

        def pump():
            try:
                while True:
                    data = proc.read(4096)
                    if data:
                        chunks.append(data)
            except Exception:   # EOFError when the CLI exits, or read on a closed pty
                pass
            finally:
                done.set()

        threading.Thread(target=pump, daemon=True).start()
        deadline, seen_at = time.time() + timeout_s, None
        try:
            while time.time() < deadline and not done.is_set():
                if seen_at is None and SESSION_RE.search(ANSI_RE.sub("", "".join(chunks))):
                    seen_at = time.time()
                if seen_at and time.time() - seen_at > 5:   # let the URL line finish printing
                    break
                time.sleep(0.5)
        finally:
            if proc.isalive():
                try:
                    proc.terminate(force=True)
                except Exception:
                    pass
            done.wait(5)
        return ANSI_RE.sub("", "".join(chunks))

    def check_once(self, branch: str, marker: str) -> str | None:
        r = subprocess.run(["git", "fetch", "--quiet", self.remote, f"refs/heads/{branch}"],
                           cwd=self.repo, capture_output=True, text=True)
        if r.returncode:
            return None
        head = self.git("rev-parse", "FETCH_HEAD")
        ok = subprocess.run(["git", "cat-file", "-e", f"{head}:{marker}"],
                            cwd=self.repo, capture_output=True).returncode == 0
        return head if ok else None

    def wait_for(self, branch: str, marker: str, timeout_s: int,
                 should_stop: Callable[[], bool], heartbeat: Callable[[], None]) -> str | None:
        deadline = time.time() + timeout_s
        while time.time() < deadline:
            head = self.check_once(branch, marker)
            if head:
                return head
            for _ in range(int(self.cfg.get("poll_s", 60))):
                if should_stop():
                    return None
                time.sleep(1)
            heartbeat()
        return None

    def show(self, commit: str, path: str) -> str:
        return self.git("show", f"{commit}:{path}", check=False)
