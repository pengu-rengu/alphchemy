from analysis.path import resolve_path
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

Filter = NumericFilter | StrFilter | BoolFilter

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
