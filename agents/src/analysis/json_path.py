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
            segments.append(KeySegment(key=token))
            continue

        if len(segments) == 0:
            raise ValueError(f"Aggregate `{token}` cannot be the first segment")

        prev = segments[-1]

        if not isinstance(prev, KeySegment):
            raise ValueError(f"Aggregate `{token}` must follow a key segment")

        segments[-1] = AggregateSegment(key=prev.key, func=token)

    return segments


def _apply_aggregate(func: str, values: list[float]) -> float:
    if func == "mean":
        return statistics.mean(values)

    if func == "std":
        return statistics.pstdev(values)

    if func == "min":
        return min(values)

    return max(values)


def _resolve_segments(obj: object, segments: list[PathSegment]) -> list:
    current = obj

    for idx, segment in enumerate(segments):
        if not isinstance(current, dict):
            return []

        if isinstance(segment, KeySegment):
            if segment.key not in current:
                return []

            current = current[segment.key]

        elif isinstance(segment, AggregateSegment):
            if segment.key not in current:
                return []

            array = current[segment.key]

            if not isinstance(array, list):
                return []

            if segment.func == "len":
                return [len(array)]

            remaining = segments[idx + 1:]
            values: list[float] = []

            for element in array:
                resolved = _resolve_segments(element, remaining)

                if len(resolved) == 0:
                    continue

                value = resolved[0]

                if isinstance(value, (int, float)):
                    values.append(float(value))

            if len(values) == 0:
                return []

            result = _apply_aggregate(segment.func, values)
            return [result]

    return [current]


def resolve_path(obj: dict, path: str) -> list:
    segments = parse_path(path)
    return _resolve_segments(obj, segments)
