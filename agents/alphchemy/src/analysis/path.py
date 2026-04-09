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


def parse_path(path: str) -> list[PathSegment]:
    tokens = path.split(".")
    segments: list[PathSegment] = []

    for token in tokens:
        if token not in AGGREGATE_FUNCS:
            key_segment = KeySegment(key=token)
            segments.append(key_segment)
            continue

        if len(segments) == 0:
            raise ValueError(f"Aggregate `{token}` cannot be the first segment")

        prev = segments[-1]

        if not isinstance(prev, KeySegment):
            raise ValueError(f"Aggregate `{token}` must follow a key segment")

        segments[-1] = AggregateSegment(key = prev.key, func=token)

    return segments


def apply_aggregate(func: str, values: list[float]) -> float:
    if func == "mean":
        return statistics.mean(values)

    if func == "std":
        return statistics.pstdev(values)

    if func == "min":
        return min(values)

    return max(values)


def resolve_value(value: object) -> str | bool | float:
    if isinstance(value, (str, bool, float)):
        return value
    
    if isinstance(value, int):
        return float(value)

    raise Exception("Resolved value must be a string, bool, or number")

def resolve_aggregate(array: list[object], segments: list[PathSegment]) -> list[float]:
    values: list[float] = []

    for element in array:
        resolved = resolve_segments(element, segments)
        
        if isinstance(resolved, (bool, str)):
            continue

        values.append(resolved)

    return values

def resolve_segments(obj: object, segments: list[PathSegment]) -> str | bool | float:
    current = obj

    for i, segment in enumerate(segments):
        if not isinstance(current, dict):
            raise Exception("Path traversal requires dictionaries")

        if isinstance(segment, KeySegment):
            if segment.key not in current:
                raise Exception(f"Missing key `{segment.key}`")

            current = current[segment.key]

        if isinstance(segment, AggregateSegment):
            if segment.key not in current:
                raise Exception(f"Missing key `{segment.key}`")

            array = current[segment.key]

            if not isinstance(array, list):
                raise Exception(f"Aggregate `{segment.func}` requires a list target")

            if segment.func == "len":
                array_len = len(array)
                return float(array_len)

            values = resolve_aggregate(array, segments[i + 1:])

            if len(values) == 0:
                raise Exception(f"Aggregate `{segment.func}` found no numeric values")

            result = apply_aggregate(segment.func, values)
            return result

    return resolve_value(current)


def resolve_path(obj: dict, path: str) -> str | bool | float:
    segments = parse_path(path)
    return resolve_segments(obj, segments)
