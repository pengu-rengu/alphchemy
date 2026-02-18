import redis
import dotenv
import time
import json
from openai import OpenAI

dotenv.load_dotenv(".env", override = True)

redis_client = redis.Redis()
openai_client = OpenAI()

with open("agents/prompt.md", "r") as file:
    prompt = file.read()

while True:

    if redis_client.llen("experiments"):
        print("Waiting")
        time.sleep(900)
        continue
    
    print("Prompting model")

    try:
        response = openai_client.responses.create(
            model = "gpt-5.2",
            input = prompt
        )
        res_text = response.output_text
        
        print("Response:")
        print(res_text)

        res_text = res_text[res_text.index("```python") + 10:]
        res_text = res_text[:res_text.index("```")]

        with open("data/script.py", "w") as file:
            file.write(res_text)

        funcs = {}

        exec(res_text, {}, funcs)

        experiments = funcs["generate_experiments"]()
        
        for experiment in experiments:
            experiment_data = json.dumps(experiment)
            redis_client.lpush("experiments", experiment_data)
        
    except Exception as e:
        print(e)
        print("Waiting")
        time.sleep(900)


