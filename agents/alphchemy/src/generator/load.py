import json
import pathlib
from generator.generators import ExperimentGen

SRC_DIR = pathlib.Path(__file__).resolve().parent.parent


def load_generator(path: str) -> tuple[ExperimentGen, dict[str, list]]:
    resolved = SRC_DIR / path

    with open(resolved, "r") as file:
        data = json.load(file)

    generator = ExperimentGen.model_validate(data["generator"])
    search_space = load_search_space(data)

    return generator, search_space
