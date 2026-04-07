import sys
import types
import json
import pathlib

_src_path = pathlib.Path(__file__).parent
_generator_dir = str(_src_path / "generator")
_generator_pkg = types.ModuleType("generator")
_generator_pkg.__path__ = [_generator_dir]
_generator_pkg.__package__ = "generator"
sys.modules["generator"] = _generator_pkg

from generator.generators import ExperimentGen
from generator.params import ParamSpace


class GeneratorRunner:
    PATH = pathlib.Path(__file__).parent / "generator.json"

    @staticmethod
    def load() -> tuple[ExperimentGen, dict[str, list]]:
        with open(GeneratorRunner.PATH, "r") as file:
            data = json.load(file)
        generator = ExperimentGen.model_validate(data["generator"])
        search_space = data["search_space"]
        return generator, search_space

    @staticmethod
    def run() -> None:
        generator, search_space = GeneratorRunner.load()
        param_space = ParamSpace(search_space=search_space)
        experiments = param_space.generate_experiments(generator, 1000)
        count = len(experiments)
        print(f"Generated {count} experiments")
        for experiment in experiments:
            output = json.dumps(experiment, indent=4)
            print(output)


if __name__ == "__main__":
    GeneratorRunner.run()
