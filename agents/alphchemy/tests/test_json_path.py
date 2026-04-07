import pytest
import statistics
from analysis.path import parse_path, resolve_path, KeySegment, AggregateSegment


FOLD_OBJ = {
    "results": {
        "fold_results": [
            {"test_results": {"excess_sharpe": 0.3}},
            {"test_results": {"excess_sharpe": 0.5}},
            {"test_results": {"excess_sharpe": 0.4}}
        ]
    }
}


def test_parse_simple_path() -> None:
    segments = parse_path("experiment.val_size")

    assert segments == [KeySegment(key="experiment"), KeySegment(key="val_size")]


def test_parse_aggregate_path() -> None:
    segments = parse_path("results.fold_results.mean.test_results.excess_sharpe")

    assert segments == [
        KeySegment(key="results"),
        AggregateSegment(key="fold_results", func="mean"),
        KeySegment(key="test_results"),
        KeySegment(key="excess_sharpe")
    ]


def test_parse_len_path() -> None:
    segments = parse_path("results.fold_results.len")

    assert segments == [
        KeySegment(key="results"),
        AggregateSegment(key="fold_results", func="len")
    ]


def test_parse_rejects_leading_aggregate() -> None:
    with pytest.raises(ValueError, match="cannot be the first segment"):
        parse_path("mean.test_results")


def test_parse_rejects_consecutive_aggregates() -> None:
    with pytest.raises(ValueError, match="must follow a key segment"):
        parse_path("results.fold_results.mean.min")


def test_resolve_simple_key() -> None:
    obj = {"experiment": {"val_size": 0.15}}
    result = resolve_path(obj, "experiment.val_size")

    assert result == 0.15


def test_resolve_nested_key() -> None:
    obj = {"experiment": {"strategy": {"opt": {"pop_size": 100}}}}
    result = resolve_path(obj, "experiment.strategy.opt.pop_size")

    assert result == 100.0


def test_resolve_aggregate_mean() -> None:
    result = resolve_path(FOLD_OBJ, "results.fold_results.mean.test_results.excess_sharpe")
    expected = statistics.mean([0.3, 0.5, 0.4])

    assert abs(result - expected) < 1e-10


def test_resolve_aggregate_std() -> None:
    result = resolve_path(FOLD_OBJ, "results.fold_results.std.test_results.excess_sharpe")
    expected = statistics.pstdev([0.3, 0.5, 0.4])

    assert abs(result - expected) < 1e-10


def test_resolve_aggregate_min() -> None:
    result = resolve_path(FOLD_OBJ, "results.fold_results.min.test_results.excess_sharpe")

    assert result == 0.3


def test_resolve_aggregate_max() -> None:
    result = resolve_path(FOLD_OBJ, "results.fold_results.max.test_results.excess_sharpe")

    assert result == 0.5


def test_resolve_aggregate_len() -> None:
    result = resolve_path(FOLD_OBJ, "results.fold_results.len")

    assert result == 3.0


def test_resolve_aggregate_on_non_list_raises() -> None:
    obj = {"results": {"fold_results": "not_a_list"}}

    with pytest.raises(Exception, match="requires a list target"):
        resolve_path(obj, "results.fold_results.mean.score")


def test_resolve_aggregate_on_missing_key_raises() -> None:
    obj = {"results": {}}

    with pytest.raises(Exception, match="Missing key"):
        resolve_path(obj, "results.fold_results.mean.score")


def test_resolve_aggregate_skips_non_numeric() -> None:
    obj = {
        "items": [
            {"value": 10},
            {"value": "bad"},
            {"value": 30}
        ]
    }
    result = resolve_path(obj, "items.mean.value")
    expected = statistics.mean([10, 30])

    assert abs(result - expected) < 1e-10


def test_resolve_aggregate_skips_missing_subpath() -> None:
    obj = {
        "results": {
            "fold_results": [
                {"test_results": {"excess_sharpe": 0.3}},
                {"test_results": {}},
                {"test_results": {"excess_sharpe": 0.4}}
            ]
        }
    }
    result = resolve_path(obj, "results.fold_results.mean.test_results.excess_sharpe")
    expected = statistics.mean([0.3, 0.4])

    assert abs(result - expected) < 1e-10


def test_resolve_aggregate_all_missing_raises() -> None:
    obj = {
        "items": [
            {"other": 1},
            {"other": 2}
        ]
    }

    with pytest.raises(Exception, match="found no numeric values"):
        resolve_path(obj, "items.mean.value")


def test_resolve_missing_key_raises() -> None:
    obj = {"experiment": {"val_size": 0.15}}

    with pytest.raises(Exception, match="Missing key"):
        resolve_path(obj, "experiment.missing_key")


def test_resolve_missing_nested_key_raises() -> None:
    obj = {"experiment": {"val_size": 0.15}}

    with pytest.raises(Exception, match="Missing key"):
        resolve_path(obj, "experiment.strategy.opt.pop_size")


def test_resolve_top_level_key() -> None:
    obj = {"val_size": 0.15}
    result = resolve_path(obj, "val_size")

    assert result == 0.15


def test_resolve_string_value() -> None:
    obj = {"experiment": {"name": "alpha"}}
    result = resolve_path(obj, "experiment.name")

    assert result == "alpha"


def test_resolve_bool_value() -> None:
    obj = {"actions": {"allow_recurrence": True}}
    result = resolve_path(obj, "actions.allow_recurrence")

    assert result is True


def test_resolve_list_value_raises() -> None:
    obj = {"actions": {"allowed_gates": ["and", "or", "xor"]}}

    with pytest.raises(Exception, match="must be a string, bool, or number"):
        resolve_path(obj, "actions.allowed_gates")
