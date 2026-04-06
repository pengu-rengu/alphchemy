from dataclasses import dataclass
from analysis.path import resolve_path


@dataclass
class NumericFilter:
    path: str
    gte: float | None = None
    lte: float | None = None
    eq: float | None = None


@dataclass
class StringFilter:
    path: str
    eq: str


@dataclass
class BoolFilter:
    path: str
    eq: bool


ExperimentFilter = NumericFilter | StringFilter | BoolFilter


def _check_numeric(value: object, filt: NumericFilter) -> bool:
    if isinstance(value, bool):
        return False

    if not isinstance(value, float):
        return False

    if filt.eq is not None:
        return value == filt.eq

    if filt.gte is not None and value < filt.gte:
        return False

    if filt.lte is not None and value > filt.lte:
        return False

    return True


def _check_string(value: object, filt: StringFilter) -> bool:
    if not isinstance(value, str):
        return False

    return value == filt.eq


def _check_bool(value: object, filt: BoolFilter) -> bool:
    if not isinstance(value, bool):
        return False

    return value == filt.eq


def _check_filter(value: object, filt: ExperimentFilter) -> bool:
    if isinstance(filt, NumericFilter):
        return _check_numeric(value, filt)

    if isinstance(filt, StringFilter):
        return _check_string(value, filt)

    return _check_bool(value, filt)


def _matches_group(obj: dict, filters: list[ExperimentFilter]) -> bool:
    for filt in filters:
        resolved = resolve_path(obj, filt.path)

        if not _check_filter(resolved, filt):
            return False

    return True


def matches_filters(obj: dict, filter_groups: list[list[ExperimentFilter]]) -> bool:
    if len(filter_groups) == 0:
        return True

    for group in filter_groups:
        if _matches_group(obj, group):
            return True

    return False
