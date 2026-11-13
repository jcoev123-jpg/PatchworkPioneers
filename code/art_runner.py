"""Background image generation for one relay cycle (started by the controller right after PLAN, so images are
made while DeepSeek builds). Writes <cycle>/ART_RESULT.md when finished; on STOP it exits without a result and the
controller generates whatever is left before testing.
Usage: python art_runner.py <cycle_dir> [repo]   (repo: a lane's worktree; default relay.json repo)"""
import json
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from art_gen import ArtError, generate_assets  # noqa: E402

LOG_PATH = HERE / "logs" / "controller.log"
STOP_PATH = HERE / "STOP"


def log(msg: str) -> None:
    line = f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] {msg}"
    print(line, flush=True)
    with open(LOG_PATH, "a", encoding="utf-8") as f:
        f.write(line + "\n")


def main() -> int:
    cyc = Path(sys.argv[1])
    cfg = json.loads((HERE / "relay.json").read_text(encoding="utf-8"))
    assets = json.loads((cyc / "ASSET_REQUESTS.json").read_text(encoding="utf-8"))
    try:
        repo = Path(sys.argv[2]) if len(sys.argv) > 2 else Path(cfg["repo"])
        lines = generate_assets(cfg, repo, assets, log, STOP_PATH.exists)
    except ArtError:
        log("art (background): stopped")
        return 1
    tmp = cyc / "ART_RESULT.tmp"
    tmp.write_text("\n".join(lines) + "\n", encoding="utf-8")
    tmp.replace(cyc / "ART_RESULT.md")
    return 0


if __name__ == "__main__":
    sys.exit(main())
