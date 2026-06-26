from dataclasses import dataclass
import statistics

@dataclass
class KeySegment:
    key: str


@dataclass
class AggregateSegment:
    key: str
    func: str


PathSegment = KeySegment | AggregateSegment

AGGREGATE_FUNCS = {"len", "mean", "std", "min", "max"}


class MissingKeyError(Exception):
    pass


def parse_path(path: str) -> list[PathSegment]:
    tokens = path.split(".")
    segments: list[PathSegment] = []
    idx = 0

    while idx < len(tokens):
        token = tokens[idx]

        if token in AGGREGATE_FUNCS:
            raise ValueError(f"Aggregate `{token}` must use colon syntax, e.g. `results.{token}:path.to.value`")

        if ":" not in token:
            key_segment = KeySegment(key = token)
            segments.append(key_segment)
            idx += 1
            continue

        parts = token.split(":", 1)
        func = parts[0]
        first_inner_key = parts[1]

        if func not in AGGREGATE_FUNCS:
            raise ValueError(f"Unknown aggregate `{func}`")

        if len(segments) == 0:
            raise ValueError(f"Aggregate `{func}` cannot be the first segment")

        prev = segments[-1]

        if not isinstance(prev, KeySegment):
            raise ValueError(f"Aggregate `{func}` must follow a key segment")

        if len(first_inner_key) == 0:
            raise ValueError(f"Aggregate `{func}` requires an inner path")

        inner_tokens = [first_inner_key] + tokens[idx + 1:]
        segments[-1] = AggregateSegment(key = prev.key, func = func)

        for inner_token in inner_tokens:
            key_segment = KeySegment(key = inner_token)
            segments.append(key_segment)

        return segments

    return segments


def path_text(parts: list[str]) -> str:
    if len(parts) == 0:
        return "<root>"

    return ".".join(parts)


def segment_path_text(segments: list[PathSegment]) -> str:
    parts: list[str] = []

    for segment in segments:
        if isinstance(segment, KeySegment):
            parts.append(segment.key)
        elif isinstance(segment, AggregateSegment):
            parts.append(segment.func)

    return path_text(parts)


def apply_aggregate(func: str, values: list[float]) -> float:
    if func == "mean":
        return statistics.mean(values)
    elif func == "std":
        return statistics.pstdev(values)
    elif func == "min":
        return min(values)
    elif func == "max":
        return max(values)

    raise Exception(f"Unrecognized aggregate: {func}")


def resolve_value(value: object) -> str | bool | float:
    if isinstance(value, (str, bool, float)):
        return value

    if isinstance(value, int):
        return float(value)

    raise Exception("Resolved value must be a string, bool, or number")


def resolve_aggregate(array: list[object], segments: list[PathSegment], full_path: str, prefix: list[str]) -> list[str | bool | float]:
    values: list[str | bool | float] = []

    for element in array:
        try:
            resolved = resolve_segments(element, segments, full_path, prefix)
        except MissingKeyError:
            continue

        values.append(resolved)

    return values


def numeric_values(values: list[str | bool | float]) -> list[float]:
    nums: list[float] = []

    for value in values:
        if isinstance(value, (bool, str)):
            continue

        nums.append(value)

    return nums


def resolve_segments(obj: object, segments: list[PathSegment], full_path: str, prefix: list[str]) -> str | bool | float:
    current = obj

    for i, segment in enumerate(segments):
        if not isinstance(current, dict):
            current_path = path_text(prefix)
            raise Exception(f"Encountered a non-dictionary at `{current_path}` while resolving `{full_path}`")
        elif isinstance(segment, KeySegment):
            if segment.key not in current:
                raise MissingKeyError(f"Missing key `{segment.key}`")

            current = current[segment.key]
            prefix = prefix + [segment.key]

        elif isinstance(segment, AggregateSegment):
            if segment.key not in current:
                raise MissingKeyError(f"Missing key `{segment.key}`")

            array = current[segment.key]
            aggregate_path = path_text(prefix + [segment.key])

            if not isinstance(array, list):
                raise Exception(f"Aggregate `{segment.func}` at `{aggregate_path}` requires key `{segment.key}` to be a list while resolving `{full_path}`")

            aggregate_prefix = prefix + [segment.key]
            remaining_segments = segments[i + 1:]
            values = resolve_aggregate(array, remaining_segments, full_path, aggregate_prefix)
            if segment.func == "len":
                array_len = len(values)
                return float(array_len)

            nums = numeric_values(values)
            if len(nums) == 0:
                remaining_path = segment_path_text(remaining_segments)
                raise Exception(f"Aggregate `{segment.func}` at `{aggregate_path}` found no numeric values for `{remaining_path}` while resolving `{full_path}`")

            return apply_aggregate(segment.func, nums)

    return resolve_value(current)


def resolve_path(obj: dict, path: str) -> str | bool | float:
    segments = parse_path(path)
    return resolve_segments(obj, segments, path, [])
