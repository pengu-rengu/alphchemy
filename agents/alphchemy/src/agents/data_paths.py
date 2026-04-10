from os import PathLike
from pathlib import Path


LOCAL_DATA_DIR = Path(__file__).resolve().parents[1] / "data"
SHARED_DATA_DIR = Path(__file__).resolve().parents[4] / "data"


def shared_data_dir() -> Path:
    return SHARED_DATA_DIR


def state_path() -> Path:
    return LOCAL_DATA_DIR / "state.json"


def generated_path() -> Path:
    return SHARED_DATA_DIR / "generated.jsonl"


def experiments_path() -> Path:
    return SHARED_DATA_DIR / "experiments.jsonl"


def agent_context_path(agent_id: str) -> Path:
    return LOCAL_DATA_DIR / f"{agent_id}_context.txt"


def ensure_parent_dir(path: Path | str | PathLike[str]) -> None:
    resolved_path = Path(path)
    resolved_path.parent.mkdir(parents = True, exist_ok = True)
