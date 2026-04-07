from typing import Any, get_args, get_origin
from pydantic import BaseModel
from params import ParamKey


def extract_expected_types(annotation: Any) -> set[type]:
    args = get_args(annotation)
    result: set[type] = set()
    for arg in args:
        if arg is type(None) or arg is ParamKey:
            continue
        origin = get_origin(arg)
        if origin is not None:
            result.add(origin)
        else:
            result.add(arg)
    return result


def collect_param_types(model: BaseModel) -> dict[str, set[type]]:
    mapping: dict[str, set[type]] = {}
    fields = type(model).model_fields

    for name, field_info in fields.items():
        value = getattr(model, name)

        if isinstance(value, ParamKey):
            expected = extract_expected_types(field_info.annotation)
            if value.param not in mapping:
                mapping[value.param] = set()
            mapping[value.param] |= expected

        elif isinstance(value, BaseModel):
            sub = collect_param_types(value)
            for key, types in sub.items():
                if key not in mapping:
                    mapping[key] = set()
                mapping[key] |= types

        elif isinstance(value, list):
            for item in value:
                if not isinstance(item, BaseModel):
                    continue
                sub = collect_param_types(item)
                for key, types in sub.items():
                    if key not in mapping:
                        mapping[key] = set()
                    mapping[key] |= types

    return mapping


def check_type(value: Any, expected: type) -> bool:
    if expected is bool:
        return isinstance(value, bool)
    if expected is int:
        is_int = isinstance(value, int)
        is_bool = isinstance(value, bool)
        return is_int and not is_bool
    if expected is float:
        is_numeric = isinstance(value, (int, float))
        is_bool = isinstance(value, bool)
        return is_numeric and not is_bool
    return isinstance(value, expected)


def validate_schema(
    generator: BaseModel,
    search_space: dict[str, list]
) -> None:
    param_types = collect_param_types(generator)

    for key, expected_types in param_types.items():
        if key not in search_space:
            continue
        for value in search_space[key]:
            matches = any(
                check_type(value, exp) for exp in expected_types
            )
            if matches:
                continue
            type_names = ", ".join(t.__name__ for t in expected_types)
            raise ValueError(
                f"search_space['{key}'] contains {value!r} "
                f"(type {type(value).__name__}), "
                f"expected one of: {type_names}"
            )
