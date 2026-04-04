from pathlib import Path
from os import PathLike


DATA_DIR = Path(__file__).resolve().parents[1] / "data"


def state_path() -> Path:
    return DATA_DIR / "state.json"


def experiments_path() -> Path:
    return DATA_DIR / "experiments.jsonl"


def agent_context_path(agent_id: str) -> Path:
    return DATA_DIR / f"{agent_id}_context.txt"


def ensure_parent_dir(path: Path | str | PathLike[str]) -> None:
    resolved_path = Path(path)
    resolved_path.parent.mkdir(parents = True, exist_ok = True)
