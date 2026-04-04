import json
import pathlib
from generators import ExperimentGen

SRC_DIR = pathlib.Path(__file__).resolve().parent.parent


def load_search_space(data: dict) -> dict[str, list]:
    if "search_space" in data:
        return data["search_space"]

    param_space = data.get("param_space")

    if not isinstance(param_space, dict):
        raise KeyError("missing `search_space` or `param_space.search_space`")

    if "search_space" not in param_space:
        raise KeyError("missing `param_space.search_space`")

    return param_space["search_space"]


def load_generator(path: str) -> tuple[ExperimentGen, dict[str, list]]:
    resolved = SRC_DIR / path

    with open(resolved, "r") as file:
        data = json.load(file)

    generator = ExperimentGen.model_validate(data["generator"])
    search_space = load_search_space(data)

    return generator, search_space
