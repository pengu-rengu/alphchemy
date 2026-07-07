from analysis.path import resolve_path
from datetime import datetime, timezone
from pydantic import BaseModel, Field
from typing import Annotated, Any, Literal


class NumericFilter(BaseModel):
    type: Literal["numeric"] = "numeric"
    path: Annotated[str, Field(min_length = 1)]
    gte: float | None = None
    gt: float | None = None
    lte: float | None = None
    lt: float | None = None
    eq: float | None = None


class StrFilter(BaseModel):
    type: Literal["string"] = "string"
    path: Annotated[str, Field(min_length = 1)]
    eq: str


class BoolFilter(BaseModel):
    type: Literal["bool"] = "bool"
    path: Annotated[str, Field(min_length = 1)]
    eq: bool


class TimestampFilter(BaseModel):
    type: Literal["timestamp"] = "timestamp"
    path: Annotated[str, Field(min_length = 1)]
    gte: datetime | None = None
    gt: datetime | None = None
    lte: datetime | None = None
    lt: datetime | None = None
    eq: datetime | None = None


Filter = NumericFilter | StrFilter | BoolFilter | TimestampFilter


def parse_timestamp_value(value: str) -> datetime:
    if value.endswith("Z"):
        value = f"{value[:-1]}+00:00"

    parsed = datetime.fromisoformat(value)

    if parsed.tzinfo is not None:
        parsed = parsed.astimezone(timezone.utc)
        parsed = parsed.replace(tzinfo = None)

    return parsed


def check_filter(value: Any, filt: Filter) -> bool:
    if isinstance(filt, NumericFilter):
        if isinstance(value, bool):
            return False

        if not isinstance(value, float):
            return False

        if filt.eq is not None:
            return value == filt.eq

        if filt.gte is not None and value < filt.gte:
            return False

        if filt.gt is not None and value <= filt.gt:
            return False

        if filt.lte is not None and value > filt.lte:
            return False

        if filt.lt is not None and value >= filt.lt:
            return False

        return True

    if isinstance(filt, StrFilter):
        if not isinstance(value, str):
            return False

        return value == filt.eq

    if isinstance(filt, TimestampFilter):
        if not isinstance(value, str):
            return False

        try:
            timestamp = parse_timestamp_value(value)
        except ValueError:
            return False

        if filt.eq is not None:
            return timestamp == filt.eq

        if filt.gte is not None and timestamp < filt.gte:
            return False

        if filt.gt is not None and timestamp <= filt.gt:
            return False

        if filt.lte is not None and timestamp > filt.lte:
            return False

        if filt.lt is not None and timestamp >= filt.lt:
            return False

        return True

    if not isinstance(value, bool):
        return False

    return value == filt.eq


def matches_group(obj: dict, filters: list[Filter]) -> bool:
    for filt in filters:
        resolved = resolve_path(obj, filt.path)

        if not check_filter(resolved, filt):
            return False

    return True


def matches_filters(obj: dict, filter_groups: list[list[Filter]]) -> bool:
    if len(filter_groups) == 0:
        return True

    for group in filter_groups:
        if matches_group(obj, group):
            return True

    return False
