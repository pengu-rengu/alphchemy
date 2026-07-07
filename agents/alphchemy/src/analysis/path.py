from __future__ import annotations

from dataclasses import dataclass
import statistics

@dataclass
class KeySegment:
    key: str


@dataclass
class AggregateSegment:
    func: str
    inner_segments: list["PathSegment"]


@dataclass
class SelfSegment:
    pass


PathSegment = KeySegment | AggregateSegment | SelfSegment

AGGREGATE_FUNCS = {"len", "mean", "std", "min", "max"}


class MissingKeyError(Exception):
    pass


def parse_path(tokens: list[str]) -> list[PathSegment]:
    segments: list[PathSegment] = []

    n_tokens = len(tokens)
    for i in range(n_tokens):
        token = tokens[i]
        if token in AGGREGATE_FUNCS:
            raise ValueError(f"Aggregate `{token}` must use colon syntax, e.g. `results.{token}:path.to.value`")

        if token == "self":
            if i != n_tokens - 1:
                raise ValueError("`self` must be the final segment")

            segments.append(SelfSegment())
            continue

        if ":" not in token:
            key_segment = KeySegment(key = token)
            segments.append(key_segment)
            continue

        parts = token.split(":", 1)
        func = parts[0]
        first_inner_key = parts[1]

        if func not in AGGREGATE_FUNCS:
            raise ValueError(f"Unknown aggregate `{func}`")

        if len(first_inner_key) == 0:
            raise ValueError(f"Aggregate `{func}` requires an inner path")

        inner_tokens = [first_inner_key] + tokens[i + 1:]
        inner_segments = parse_path(inner_tokens)
        aggregate = AggregateSegment(
            func = func,
            inner_segments = inner_segments
        )
        segments.append(aggregate)
        return segments

    return segments


def segment_path_text(segments: list[PathSegment]) -> str:
    text = ""

    for segment in segments:
        if isinstance(segment, KeySegment):
            if len(text) == 0:
                text = segment.key
            elif text.endswith(":"):
                text = f"{text}{segment.key}"
            else:
                text = f"{text}.{segment.key}"
        elif isinstance(segment, SelfSegment):
            if len(text) == 0:
                text = "self"
            else:
                text = f"{text}.self"
        elif isinstance(segment, AggregateSegment):
            inner_text = segment_path_text(segment.inner_segments)
            if len(text) == 0:
                text = f"{segment.func}:{inner_text}"
            else:
                text = f"{text}.{segment.func}:{inner_text}"

    if len(text) == 0:
        return "<root>"

    return text


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


def resolve_aggregate(array: list[object], segments: list[PathSegment], full_path: str) -> list[object]:
    values: list[object] = []

    for item in array:
        try:
            resolved = resolve_segments(item, segments, full_path)
            values.append(resolved)
        except MissingKeyError:
            continue

    return values


def numeric_values(values: list[object]) -> list[float]:
    nums: list[float] = []

    for value in values:
        if isinstance(value, bool):
            num = float(value)
            nums.append(num)
        elif isinstance(value, float):
            nums.append(value)
        elif isinstance(value, int):
            float_value = float(value)
            nums.append(float_value)

    return nums


def resolve_segments(obj: object, segments: list[PathSegment], full_path: str) -> object:
    current = obj

    for i, segment in enumerate(segments):
        prefix = segment_path_text(segments[:i + 1])
        if isinstance(segment, SelfSegment):
            continue
        elif isinstance(segment, KeySegment):
            if not isinstance(current, dict):
                raise Exception(f"Encountered a non-dictionary at {prefix} while resolving {full_path}")

            if segment.key not in current:
                raise MissingKeyError(f"Missing key {segment.key} at {prefix} while resolving {full_path}")

            current = current[segment.key]
        elif isinstance(segment, AggregateSegment):
            inner = segment.inner_segments
            if len(inner) > 0 and isinstance(inner[-1], SelfSegment):
                values = resolve_segments(current, inner[:-1], full_path)
                if not isinstance(values, list):
                    raise Exception(f"Aggregate `{segment.func}` with .self requires a list target while resolving `{full_path}`")

            else:
                if not isinstance(current, list):
                    raise Exception(f"Aggregate `{segment.func}` requires a list target while resolving `{full_path}`")

                values = resolve_aggregate(current, inner, full_path)

            if segment.func == "len":
                array_len = len(values)
                return float(array_len)

            nums = numeric_values(values)
            if len(nums) == 0:
                remaining_path = segment_path_text(segment.inner_segments)
                if len(values) == 0:
                    raise MissingKeyError(f"Missing aggregate values for {remaining_path} while resolving {full_path}")

                raise Exception(f"Aggregate {segment.func} at {prefix} found no numeric values for {remaining_path} while resolving {full_path}")

            return apply_aggregate(segment.func, nums)

    return current


def resolve_path(obj: dict, path: str) -> str | bool | float:
    tokens = path.split(".")
    segments = parse_path(tokens)
    result = resolve_segments(obj, segments, path)
    return resolve_value(result)

if __name__ == "__main__":
    obj = [[1,2,3],[4,5,6]]

    path = "mean:std:self"
    tokens = path.split(".")
    segments = parse_path(tokens)
    print(segments)
    result = resolve_segments(obj, segments, path)
    print(result)
