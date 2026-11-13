"""
Codex lane: a second, parallel builder for the relay. Codex (chatgpt.com/codex, cloud environment
relay.json game.codex_env, signed in inside the relay Chrome) works on its own task in the cloud and opens a
GitHub pull request. The relay merges that PR locally at a cycle boundary, runs the full test suite,
and pushes only when everything passes.

    CodexLane.launch(task_text) -> task URL     (returns as soon as the task is running)
    CodexLane.status(url)       -> {"state": "running"|"done"|"failed"|"limited", "pr": int|None, "text": ...}
    CodexLane.follow_up(url, message)            (e.g. "tests fail after merging with master: ...")
"""
from __future__ import annotations

import re
import time
from typing import Callable

import game as G

CLOUD_URL = "https://chatgpt.com/codex/cloud"
ENV_NAME = G.CODEX_ENV
LIMIT_RE = re.compile(r"usage limit|rate limit|reached your .*limit|try again (later|in)|out of codex", re.I)
FAIL_RE = re.compile(r"\b(could not|couldn't|unable to|failed to) (complete|create|open|push)", re.I)
PR_RE = re.compile(r"\bPR\s*#(\d+)|pull request\s*#(\d+)|/pull/(\d+)", re.I)


class CodexError(Exception):
    pass


class CodexLane:
    def __init__(self, chatgpt_cfg: dict, log: Callable[[str], None] = print):
        self.cfg = chatgpt_cfg
        self.log = log

    def _page(self):
        from chatgpt_bridge import ChatGPTBridge
        bridge = ChatGPTBridge(self.cfg, self.log)
        return bridge, bridge._context().new_page()

    def launch(self, task: str) -> str:
        from playwright.sync_api import Error as PWError
        bridge, page = self._page()
        try:
            page.goto(CLOUD_URL, wait_until="domcontentloaded", timeout=60_000)
            page.get_by_role("button", name=re.compile("environment", re.I)).first.wait_for(timeout=60_000)
            env_button = page.get_by_role("button", name=re.compile("environment|" + ENV_NAME, re.I)).first
            if ENV_NAME not in (env_button.inner_text() or ""):
                env_button.click()
                time.sleep(2)
                page.get_by_text(ENV_NAME, exact=True).last.click()
                time.sleep(2)
            editor = page.locator('[contenteditable="true"]:visible').first
            editor.click()
            page.keyboard.insert_text(task)
            time.sleep(1)
            before = set(self._recent_links(page))
            page.locator('button[aria-label="Send"]').first.click()
            # The page may stay on the start screen: the new task then shows up as a new entry in Recents.
            deadline, url = time.time() + 120, None
            while not url:
                if ("/local/" in page.url or "/codex/tasks/" in page.url) and "client-new-thread" not in page.url:
                    url = page.url
                    break
                fresh = [h for h in self._recent_links(page) if h not in before and "client-new-thread" not in h]
                if fresh:
                    url = "https://chatgpt.com" + fresh[0] if fresh[0].startswith("/") else fresh[0]
                    break
                if time.time() > deadline:
                    raise CodexError("Codex task did not start (no task URL and no new Recents entry)")
                time.sleep(3)
            self.log(f"codex: task started {url}")
            return url
        except PWError as e:
            raise CodexError(f"codex launch failed: {e}") from e
        finally:
            try:
                bridge.ensure_chatgpt_product(page)   # leave the app in ChatGPT mode for the relay's chat steps
            except Exception:
                pass
            try:
                page.close()
            except PWError:
                pass
            bridge.disconnect()

    @staticmethod
    def _recent_links(page) -> list[str]:
        try:
            return page.locator('nav a[href*="/local/"], nav a[href*="/codex/tasks/"]').evaluate_all(
                "els => els.map(e => e.getAttribute('href'))")
        except Exception:
            return []

    def resolve(self, page, url: str, match: str = "") -> str:
        """Temporary client URLs are replaced by real task URLs; find the task in Recents by its opening words."""
        if "client-new-thread" not in url:
            return url
        page.goto(CLOUD_URL, wait_until="domcontentloaded", timeout=60_000)
        time.sleep(8)
        norm = lambda t: re.sub(r"[^a-z0-9]+", "", (t or "").lower())[:30]
        key = norm(match)
        links = page.locator('nav a[href*="/local/"], nav a[href*="/codex/tasks/"]').evaluate_all(
            "els => els.map(e => [e.getAttribute('href'), (e.innerText || '').trim()])")
        for href, text in links:
            if "client-new-thread" in href or not key:
                continue
            if norm(text)[:len(key)] == key[:len(norm(text))]:
                return "https://chatgpt.com" + href if href.startswith("/") else href
        return url

    def status(self, url: str, match: str = "") -> dict:
        from playwright.sync_api import Error as PWError
        bridge, page = self._page()
        try:
            url = self.resolve(page, url, match)
            page.goto(url, wait_until="domcontentloaded", timeout=60_000)
            time.sleep(8)
            busy = page.locator('button[aria-label="Stop"]').count() > 0
            text = page.locator("main").first.inner_text(timeout=10_000)
            last = text[-2500:]
            m = None
            for m in PR_RE.finditer(last):
                pass
            pr = next((int(g) for g in m.groups() if g), None) if m else None
            if busy:
                state = "running"
            elif LIMIT_RE.search(last):
                state = "limited"
            elif pr:
                state = "done"
            elif FAIL_RE.search(last):
                state = "failed"
            else:
                state = "failed"
            return {"state": state, "pr": pr, "text": last[-1200:], "url": url}
        except PWError as e:
            raise CodexError(f"codex status failed: {e}") from e
        finally:
            try:
                bridge.ensure_chatgpt_product(page)   # leave the app in ChatGPT mode for the relay's chat steps
            except Exception:
                pass
            try:
                page.close()
            except PWError:
                pass
            bridge.disconnect()

    def follow_up(self, url: str, message: str) -> None:
        from playwright.sync_api import Error as PWError
        bridge, page = self._page()
        try:
            page.goto(url, wait_until="domcontentloaded", timeout=60_000)
            time.sleep(8)
            editor = page.locator('[contenteditable="true"]:visible').first
            editor.click()
            page.keyboard.insert_text(message)
            time.sleep(1)
            page.locator('button[aria-label="Send"]').first.click()
            time.sleep(5)
            self.log("codex: follow-up sent")
        except PWError as e:
            raise CodexError(f"codex follow-up failed: {e}") from e
        finally:
            try:
                bridge.ensure_chatgpt_product(page)   # leave the app in ChatGPT mode for the relay's chat steps
            except Exception:
                pass
            try:
                page.close()
            except PWError:
                pass
            bridge.disconnect()
