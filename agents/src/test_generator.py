from generator.load import load_generator
from generator.params import ParamSpace
import json
import redis


if __name__ == "__main__":
    redis_client = redis.Redis()

    generator, search_space = load_generator("generator.json")
    param_space = ParamSpace(search_space = search_space)

    experiments = param_space.generate_experiments(generator, 1000)

    print(f"Generated {len(experiments)} experiments\n")

    first_experiment = json.dumps(experiments[0], indent = 2)
    print(f"First experiment:\n{first_experiment}\n")

    last_experiment = json.dumps(experiments[-1], indent = 2)
    print(f"Last experiment:\n{last_experiment}")

    for experiment in experiments:
        experiment_str = json.dumps(experiment)
        redis_client.lpush("experiments", experiment_str)
