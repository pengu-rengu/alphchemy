"""Prefetch CoinGecko demo hourly OHLC for a fixed set of coins into this folder.

The Rust experiment runner (experiments/alphchemy/src/fetch_data.rs) reads the
resulting `{SYMBOL}.json` files instead of hitting the API at run time. Each file
is shaped { timestamps, open, high, low, close } with ISO timestamps.

Data comes from /coins/{id}/market_chart/range, paginated backward in 90-day
windows (each auto-selects hourly granularity on the demo tier) until the demo
depth limit (~365 days) returns error_code 10012. The endpoint is price-only, so
open/high/low are synthesized from consecutive closes plus small noise.

Run: pip install -r requirements.txt && python fetch_coingecko.py
Needs the COINGECKO demo api key in the environment (see repo .env).
"""

import json
import os
import random
import time
from datetime import datetime, timezone

import requests

DEMO_BASE = "https://api.coingecko.com/api/v3"
VS_CURRENCY = "usd"
DAY = 86400
WINDOW_DAYS = 90
MIN_WINDOW_DAYS = 5
SLEEP_SECONDS = 2
NOISE = 0.001
COIN_IDS = [
    "bitcoin",
    "ethereum",
    "solana",
    "binancecoin",
    "ripple",
    "cardano",
    "dogecoin",
    "avalanche-2",
    "chainlink",
    "polkadot"
]

SCRIPT_PATH = os.path.abspath(__file__)
DATA_DIR = os.path.dirname(SCRIPT_PATH)


def ms_to_iso(ms: int) -> str:
    seconds = ms / 1000
    moment = datetime.fromtimestamp(seconds, tz=timezone.utc)
    return moment.strftime("%Y-%m-%dT%H:%M:%S")


# Returns the parsed json, or None when the demo depth limit (error_code 10012)
# is hit so the pager can stop; raises on any other non-200.
def request_json(path: str, params: dict[str, str]) -> object:
    headers = {"x-cg-demo-api-key": os.environ["COINGECKO"]}
    response = requests.get(f"{DEMO_BASE}{path}", params=params, headers=headers)
    time.sleep(SLEEP_SECONDS)
    if response.status_code == 200:
        return response.json()
    if "10012" in response.text:
        return None
    raise RuntimeError(f"coingecko {path} failed {response.status_code}: {response.text}")


def resolve_symbol(coin_id: str) -> str:
    response = request_json(f"/coins/{coin_id}/tickers", {})
    tickers = response["tickers"]
    usdt_tickers = [ticker for ticker in tickers if ticker["target"] == "USDT"]
    chosen = usdt_tickers[0] if usdt_tickers else tickers[0]
    return f"{chosen['base']}_{chosen['target']}"


def fetch_prices(coin_id: str) -> list:
    now = int(time.time())
    to = now
    window_days = WINDOW_DAYS
    collected = []

    while True:
        window_seconds = window_days * DAY
        fr = to - window_seconds
        fr_param = str(fr)
        to_param = str(to)
        params = {"vs_currency": VS_CURRENCY, "from": fr_param, "to": to_param}
        response = request_json(f"/coins/{coin_id}/market_chart/range", params)

        if response is None:
            if window_days <= MIN_WINDOW_DAYS:
                break
            window_days = window_days // 2
            continue

        prices = response["prices"]
        collected = prices + collected
        to = fr
        window_days = WINDOW_DAYS

    return collected


def build_ohlc(prices: list) -> dict[str, list]:
    unique = {}
    for point in prices:
        timestamp_ms = point[0]
        unique[timestamp_ms] = point[1]
    sorted_ms = sorted(unique.keys())

    timestamps = [ms_to_iso(ms) for ms in sorted_ms]
    closes = [unique[ms] for ms in sorted_ms]

    opens = []
    highs = []
    lows = []
    for idx, close in enumerate(closes):
        if idx == 0:
            base_open = close
        else:
            base_open = closes[idx - 1]
        open_jitter = random.uniform(-NOISE, NOISE)
        open_price = base_open * (1 + open_jitter)
        opens.append(open_price)

        high_base = max(open_price, close)
        high_jitter = random.uniform(0, NOISE)
        high = high_base * (1 + high_jitter)
        highs.append(high)

        low_base = min(open_price, close)
        low_jitter = random.uniform(0, NOISE)
        low = low_base * (1 - low_jitter)
        lows.append(low)

    return {"timestamps": timestamps, "open": opens, "high": highs, "low": lows, "close": closes}


def main() -> None:
    for coin_id in COIN_IDS:
        symbol = resolve_symbol(coin_id)
        prices = fetch_prices(coin_id)
        data = build_ohlc(prices)
        path = os.path.join(DATA_DIR, f"{symbol}.json")
        with open(path, "w") as file:
            json.dump(data, file)
        row_count = len(data["timestamps"])
        print(f"wrote {path}: {row_count} rows")


if __name__ == "__main__":
    main()
