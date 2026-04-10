import json
import pathlib
from typing import Any

from agents.data_paths import ensure_parent_dir, generated_path
from generator.generators import ExperimentGen
from generator.load import load_generator
from generator.params import ParamSpace


class GeneratorRunner:
    PATH = pathlib.Path("generator.json")

    @staticmethod
    def load() -> tuple[ExperimentGen, dict[str, list]]:
        return load_generator(str(GeneratorRunner.PATH))

    @staticmethod
    def write_experiments(path: pathlib.Path, experiments: list[dict[str, Any]]) -> None:
        ensure_parent_dir(path)

        with open(path, "w") as file:
            for experiment in experiments:
                serialized = json.dumps(experiment)
                file.write(serialized)
                file.write("\n")

    @staticmethod
    def run() -> None:
        generator, search_space = GeneratorRunner.load()
        param_space = ParamSpace(search_space = search_space)
        experiments = param_space.generate_experiments(generator, 2000)
        output_path = generated_path()

        GeneratorRunner.write_experiments(output_path, experiments)

        count = len(experiments)
        print(f"Wrote {count} experiments to {output_path}")


if __name__ == "__main__":
    GeneratorRunner.run()
