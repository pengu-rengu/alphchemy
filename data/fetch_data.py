"""Prefetch CoinAPI hourly OHLC for a fixed set of coins into this folder.

The Rust experiment runner (experiments/alphchemy/src/fetch_data.rs) reads the
resulting `{SYMBOL}.json` files instead of hitting the API at run time. Each file
is shaped { timestamps, open, high, low, close } with ISO timestamps.

Data comes from CoinAPI's /ohlcv/{symbol_id}/history endpoint at 1-hour resolution,
paginated backward from now in fixed windows until it reaches six years back or the
API stops returning bars. CoinAPI returns real OHLC, so open/high/low/close are used
directly (no synthesis).

Run: pip install -r requirements.txt && python fetch_data.py
Needs the COINAPI_KEY api key in the environment (see repo .env).
"""

import json
import os
import time
from datetime import datetime, timedelta, timezone

import requests

BASE = "https://rest.coinapi.io/v1"
PERIOD = "1HRS"
LIMIT = 10000
YEARS_BACK = 6
DAYS_BACK = 365 * YEARS_BACK
WINDOW = timedelta(hours=LIMIT)
SLEEP_SECONDS = 2
SYMBOLS = [
    "BTC_USDT",
    "ETH_USDT",
    "SOL_USDT",
    "BNB_USDT",
    "XRP_USDT",
    "ADA_USDT",
    "DOGE_USDT",
    "AVAX_USDT",
    "LINK_USDT",
    "DOT_USDT"
]

SCRIPT_PATH = os.path.abspath(__file__)
DATA_DIR = os.path.dirname(SCRIPT_PATH)


def to_iso(moment: datetime) -> str:
    return moment.strftime("%Y-%m-%dT%H:%M:%S")


def request_bars(symbol_id: str, time_start: datetime, time_end: datetime) -> list:
    start_iso = to_iso(time_start)
    end_iso = to_iso(time_end)
    headers = {"Authorization": os.environ["COINAPI_KEY"]}
    params = {"period_id": PERIOD, "time_start": start_iso, "time_end": end_iso, "limit": LIMIT}
    response = requests.get(f"{BASE}/ohlcv/{symbol_id}/history", params=params, headers=headers)
    time.sleep(SLEEP_SECONDS)
    if response.status_code == 200:
        return response.json()
    raise RuntimeError(f"coinapi history failed {response.status_code}: {response.text}")


# Reformats CoinAPI bars into the columnar { timestamps, open, high, low, close }
# schema the Rust runner reads. Dedups by hour and sorts chronologically. The
# time_period_start is sliced to seconds (drops subseconds/Z) so timestamps match
# the format experiment start/end use, keeping Rust's lexicographic range filter valid.
def build_columns(bars: list) -> dict:
    unique = {}
    for bar in bars:
        timestamp = bar["time_period_start"]
        unique[timestamp] = bar
    sorted_keys = sorted(unique.keys())

    timestamps = []
    opens = []
    highs = []
    lows = []
    closes = []
    for key in sorted_keys:
        bar = unique[key]
        timestamps.append(key[:19])
        opens.append(bar["price_open"])
        highs.append(bar["price_high"])
        lows.append(bar["price_low"])
        closes.append(bar["price_close"])

    return {"timestamps": timestamps, "open": opens, "high": highs, "low": lows, "close": closes}


def fetch_ohlc(symbol: str) -> dict:
    symbol_id = f"BINANCE_SPOT_{symbol}"
    now = datetime.now(timezone.utc)
    span = timedelta(days=DAYS_BACK)
    start_limit = now - span
    end_cursor = now
    collected = []

    while end_cursor > start_limit:
        window_start = end_cursor - WINDOW
        if window_start < start_limit:
            window_start = start_limit
        page = request_bars(symbol_id, window_start, end_cursor)
        if not page:
            break
        collected = page + collected
        end_cursor = window_start

    return build_columns(collected)


def main() -> None:
    for symbol in SYMBOLS:
        data = fetch_ohlc(symbol)
        path = os.path.join(DATA_DIR, f"{symbol}.json")
        with open(path, "w") as file:
            json.dump(data, file)
        row_count = len(data["timestamps"])
        print(f"wrote {path}: {row_count} rows")


if __name__ == "__main__":
    main()
