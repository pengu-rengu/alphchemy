import json
import pathlib
from generator.generators import ExperimentGen
from generator.params import ParamSpace

SRC_DIR = pathlib.Path(__file__).resolve().parent.parent


def load_generator(path: str) -> tuple[ExperimentGen, dict[str, list]]:
    resolved = SRC_DIR / path

    with open(resolved, "r") as file:
        data = json.load(file)

    generator = ExperimentGen.model_validate(data["generator"])
    search_space = data["search_space"]

    return generator, search_space
