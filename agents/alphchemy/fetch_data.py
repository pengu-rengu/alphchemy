import requests
import json
import pandas as pd
import multiprocessing
import os
from datetime import datetime, timedelta, timezone
from typing import NamedTuple
from dataclasses import dataclass, field
from dotenv import load_dotenv

load_dotenv(".env")

BTC_COIN = "KRAKEN_SPOT_BTC_USDT"
BTC_DAILY = "btc-up-or-down-daily"
BTC_15M = "btc-up-or-down-15m"

class MarketMetadata(NamedTuple):
    column_name: str
    up_token: str
    down_token: str
    start_date: datetime
    end_date: datetime

@dataclass
class MarketData:
    column_name: str
    up_prices: list[float] = field(default_factory = list)
    up_timestamps: list[datetime] = field(default_factory = list)
    down_prices: list[float] = field(default_factory = list)
    down_timestamps: list[datetime] = field(default_factory = list)
    time_left: list[int] = field(default_factory = list)

    def update(self, more_data: MarketData):
        self.up_prices.extend(more_data.up_prices)
        self.up_timestamps.extend(more_data.up_timestamps)
        self.down_prices.extend(more_data.down_prices)
        self.down_timestamps.extend(more_data.down_timestamps)
        self.time_left.extend(more_data.time_left)

class SeriesMarketData(NamedTuple):
    fifteen_minute: MarketData
    daily: MarketData

def get_timedelta(series_slug: str) -> timedelta:
    if series_slug == BTC_DAILY:
        return timedelta(days = 1)
    elif series_slug == BTC_15M:
        return timedelta(minutes = 15)

def get_column_name(series_slug: str) -> str:
    if series_slug == BTC_15M:
        return "15m"
    elif series_slug == BTC_DAILY:
        return "daily"

def get_initial_df(from_date: datetime, to_date: datetime) -> pd.DataFrame:
    date_range = pd.date_range(start = from_date, end = to_date, freq = timedelta(minutes = 1))

    return pd.DataFrame(
        index = date_range,
        columns = ["up_15m", "down_15m", "time_left_15m", "up_daily", "down_daily", "time_left_daily", "open", "high", "low", "close"],
        dtype = float
    )

def clean_df(df: pd.DataFrame) -> pd.DataFrame:
    clean_rows = df.dropna()

    if clean_rows.empty:
        cleaned_df = df
    else:
        index = clean_rows.index

        cleaned_df = df[index[0] : index[-1]]
    
    return cleaned_df.interpolate()

def get_event_ids(series_slug: str, from_date: datetime, to_date: datetime) -> list[str]:
    events = requests.get(f"https://gamma-api.polymarket.com/series?slug={series_slug}&limit=1").json()[0]["events"]
    
    event_ids = []

    for event in events:
        end_date = datetime.fromisoformat(event["endDate"])
        if from_date <= end_date and end_date - get_timedelta(series_slug) <= to_date:
            event_ids.append(event["id"])

    return event_ids

def get_market(event_id: str) -> MarketMetadata | None:
    try:
        event_json = requests.get(f"https://gamma-api.polymarket.com/events/{event_id}").json()

        market_json = event_json["markets"][0]
        series_slug = event_json["series"][0]["slug"]

        clob_tokens = json.loads(market_json["clobTokenIds"])
        end_date = datetime.fromisoformat(market_json["endDate"])
        
        return MarketMetadata(
            column_name = get_column_name(series_slug),
            up_token = clob_tokens[0],
            down_token = clob_tokens[1],
            start_date = end_date - get_timedelta(series_slug),
            end_date = end_date
        )
    except:
        return None

def get_markets(event_ids: list[str]) -> list[MarketMetadata]:
    with multiprocessing.Pool() as pool:
        markets = pool.map(get_market, event_ids)

    return sorted([m for m in markets if m], key = lambda market: market.end_date)

def get_datetime(timestamp: int) -> datetime:
    return datetime.fromtimestamp(timestamp, timezone.utc).replace(second = 0, microsecond = 0)

def request_price_history(token: str, start_timestamp: int, end_timestamp: int) -> list[dict]:
    return requests.get(f"https://clob.polymarket.com/prices-history?market={token}&startTs={start_timestamp}&endTs={end_timestamp}&fidelity=1").json()["history"]

def get_market_data(market: MarketMetadata) -> MarketData:
    start_timestamp = int(market.start_date.timestamp())
    end_timestamp = int(market.end_date.timestamp())
    
    market_data = MarketData(market.column_name)

    for data_point in request_price_history(market.up_token, start_timestamp, end_timestamp):

        up_timestamp = get_datetime(data_point["t"])

        market_data.up_timestamps.append(up_timestamp)
        market_data.up_prices.append(data_point["p"])
        market_data.time_left.append((market.end_date - up_timestamp).total_seconds() // 60)

    for data_point in request_price_history(market.down_token, start_timestamp, end_timestamp):

        market_data.down_timestamps.append(get_datetime(data_point["t"]))
        market_data.down_prices.append(data_point["p"])

    return market_data
    
def sort_markets_data(markets_data: list[MarketData]) -> tuple[MarketData]:
    sorted_markets_data = (MarketData(column_name = "15m"), MarketData(column_name = "daily"))

    for market_data in markets_data:
        if market_data.column_name == "15m":
            sorted_markets_data[0].update(market_data)
        elif market_data.column_name == "daily":
            sorted_markets_data[1].update(market_data)
    
    return sorted_markets_data

def merge(df: pd.DataFrame, other: pd.Series | pd.DataFrame):
    df.update(other[~other.index.duplicated()])

def populate_df_with_market_data(df: pd.DataFrame, market_data: MarketData):
    column_name = market_data.column_name
    
    merge(df, pd.Series(
        data = market_data.up_prices,
        index = market_data.up_timestamps,
        name = f"up_{column_name}"
    ))
    
    merge(df, pd.Series(
        data = market_data.down_prices,
        index = market_data.down_timestamps,
        name = f"down_{column_name}"
    ))

    merge(df, pd.Series(
        data = market_data.time_left,
        index = market_data.up_timestamps,
        name = f"time_left_{column_name}"
    ))

def populate_df_with_series_data(df: pd.DataFrame, from_date: datetime, to_date: datetime):
    event_ids = []

    for series_slug in [BTC_15M, BTC_DAILY]:
        event_ids.extend(get_event_ids(series_slug, from_date, to_date))
    
    markets = get_markets(event_ids)
    
    with multiprocessing.Pool() as pool:
        markets_data = pool.map(get_market_data, markets)

    sorted_markets_data = sort_markets_data(markets_data)

    for market_data in sorted_markets_data:
        populate_df_with_market_data(df, market_data)

def populate_df_with_coin_data(df: pd.DataFrame, count: int):
    bars = requests.get(f"https://rest.coinapi.io/v1/ohlcv/BINANCE_SPOT_BTC_USDT/latest?period_id=1MIN&limit={count + 1}", headers = {
        "Accept": "text/plain",
        "Authorization": os.getenv("COINAPI_KEY")
    }).json()

    data = {
        "open": [],
        "high": [],
        "low": [],
        "close": []
    }
    timestamps = []

    for bar in bars:
        data["open"].append(bar["price_open"])
        data["high"].append(bar["price_close"])
        data["low"].append(bar["price_low"])
        data["close"].append(bar["price_close"])
        timestamps.append(datetime.fromisoformat(bar["time_period_start"]))
    
    merge(df, pd.DataFrame(data, index = timestamps))

def fetch_data(count: int) -> pd.DataFrame:
    to_date = datetime.now(timezone.utc).replace(second = 0, microsecond = 0)
    from_date = to_date - timedelta(minutes = count)

    df = get_initial_df(from_date, to_date)

    populate_df_with_series_data(df, from_date, to_date)
    populate_df_with_coin_data(df, count)

    return clean_df(df)

if __name__ == "__main__":
    fetch_data(6000).to_csv("data/btc_data.csv", index_label = "timestamp")

