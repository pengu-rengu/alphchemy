from analysis.path import resolve_path
from pydantic import BaseModel, Field
from typing import Annotated, Any, Literal


class NumericFilter(BaseModel):
    type: Literal["numeric"] = "numeric"
    path: Annotated[str, Field(min_length = 1)]
    gte: float | None = None
    lte: float | None = None
    eq: float | None = None


class StrFilter(BaseModel):
    type: Literal["string"] = "string"
    path: Annotated[str, Field(min_length = 1)]
    eq: str


class BoolFilter(BaseModel):
    type: Literal["bool"] = "bool"
    path: Annotated[str, Field(min_length = 1)]
    eq: bool

FilterModel = NumericFilter | StrFilter | BoolFilter
Filter = Annotated[FilterModel, Field(discriminator = "type")]


def check_numeric(value: Any, numeric_filter: NumericFilter) -> bool:
    if isinstance(value, bool):
        return False

    if not isinstance(value, float):
        return False

    if numeric_filter.eq is not None:
        return value == numeric_filter.eq

    if numeric_filter.gte is not None and value < numeric_filter.gte:
        return False

    if numeric_filter.lte is not None and value > numeric_filter.lte:
        return False

    return True


def check_str(value: Any, str_filter: StrFilter) -> bool:
    if not isinstance(value, str):
        return False

    return value == str_filter.eq


def check_bool(value: Any, bool_filter: BoolFilter) -> bool:
    if not isinstance(value, bool):
        return False

    return value == bool_filter.eq


def check_filter(value: Any, filt: FilterModel) -> bool:
    if isinstance(filt, NumericFilter):
        return check_numeric(value, filt)

    if isinstance(filt, StrFilter):
        return check_str(value, filt)

    return check_bool(value, filt)


def matches_group(obj: dict, filters: list[FilterModel]) -> bool:
    for filt in filters:
        resolved = resolve_path(obj, filt.path)

        if not check_filter(resolved, filt):
            return False

    return True


def matches_filters(obj: dict, filter_groups: list[list[FilterModel]]) -> bool:
    if len(filter_groups) == 0:
        return True

    for group in filter_groups:
        if matches_group(obj, group):
            return True

    return False
