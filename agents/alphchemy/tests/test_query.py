import json
import statistics
import pytest
from analysis.query import (
    query_experiments,
    load_experiments,
    compute_quantile
)
from analysis.filters import NumericFilter, StrFilter, BoolFilter


def make_experiment(
    val_size: float,
    net_type: str,
    pop_size: int,
    overall_sharpe: float,
    fold_sharpes: list[float]
) -> dict:
    fold_results = []

    for sharpe in fold_sharpes:
        fold_results.append({
            "test_results": {
                "is_invalid": False,
                "excess_sharpe": sharpe,
                "mean_hold_time": 5.0,
                "std_hold_time": 1.0,
                "entries": 10,
                "total_exits": 10,
                "signal_exits": 8,
                "stop_loss_exits": 1,
                "take_profit_exits": 1,
                "max_hold_exits": 0
            }
        })

    return {
        "experiment": {
            "val_size": val_size,
            "strategy": {
                "base_net": {"type": net_type},
                "opt": {"pop_size": pop_size},
                "actions": {"allow_recurrence": net_type == "logic"}
            }
        },
        "results": {
            "overall_excess_sharpe": overall_sharpe,
            "fold_results": fold_results
        }
    }


ERROR_EXPERIMENT = {
    "experiment": {"val_size": 0.1},
    "results": {"error": "validation failed", "is_internal": False}
}


@pytest.fixture()
def experiments_file(tmp_path, monkeypatch):
    file_path = tmp_path / "experiments.jsonl"
    experiments = [
        make_experiment(0.15, "logic", 100, 0.42, [0.38, 0.45, 0.43]),
        make_experiment(0.20, "decision", 200, 0.31, [0.28, 0.33, 0.32]),
        make_experiment(0.10, "logic", 150, 0.55, [0.50, 0.60]),
        ERROR_EXPERIMENT
    ]

    lines = [json.dumps(exp) for exp in experiments]
    file_path.write_text("\n".join(lines) + "\n")

    monkeypatch.setattr("analysis.query.experiments_path", lambda: file_path)

    return file_path


def test_load_experiments_skips_errors(experiments_file) -> None:
    experiments = load_experiments(skip_errors=True)

    assert len(experiments) == 3


def test_load_experiments_includes_errors(experiments_file) -> None:
    experiments = load_experiments(skip_errors=False)

    assert len(experiments) == 4


def test_load_experiments_injects_line_index(experiments_file) -> None:
    experiments = load_experiments()

    indices = [exp["_line_index"] for exp in experiments]
    assert indices == [0, 1, 2]


def test_query_experiments_basic_select(experiments_file) -> None:
    result = query_experiments(
        select=[
            "experiment.val_size",
            "results.overall_excess_sharpe"
        ]
    )

    assert "[QUERY] 3 matched, showing 3" in result
    assert "experiment.val_size: 0.15" in result
    assert "results.overall_excess_sharpe: 0.42" in result
    assert result.count("[SUMMARY]") == 2
    assert "path: experiment.val_size" in result
    assert "path: results.overall_excess_sharpe" in result


def test_query_experiments_with_filters(experiments_file) -> None:
    filt = NumericFilter(path="results.overall_excess_sharpe", gte=0.4)
    result = query_experiments(
        select=["experiment.val_size", "results.overall_excess_sharpe"],
        filter_groups=[[filt]]
    )

    assert "[QUERY] 2 matched, showing 2" in result
    assert "experiment.val_size: 0.15" in result
    assert "experiment.val_size: 0.1" in result
    assert "experiment.val_size: 0.2" not in result
    assert "experiments_matched: 2" in result
    assert "max: 0.55" in result


def test_query_experiments_sort(experiments_file) -> None:
    result = query_experiments(
        select=["results.overall_excess_sharpe"],
        sort_by="results.overall_excess_sharpe",
        sort_desc=True
    )
    query_part = result.split("[SUMMARY]")[0]

    sharpe_55_pos = query_part.index("results.overall_excess_sharpe: 0.55")
    sharpe_42_pos = query_part.index("results.overall_excess_sharpe: 0.42")
    sharpe_31_pos = query_part.index("results.overall_excess_sharpe: 0.31")

    assert sharpe_55_pos < sharpe_42_pos < sharpe_31_pos


def test_query_experiments_limit(experiments_file) -> None:
    result = query_experiments(
        select=["experiment.val_size"],
        limit=2
    )

    assert "[QUERY] 3 matched, showing 2" in result
    assert result.count("--- Experiment") == 2


def test_query_experiments_no_matches(experiments_file) -> None:
    filt = NumericFilter(path="results.overall_excess_sharpe", gte=10.0)
    result = query_experiments(
        select=["experiment.val_size"],
        filter_groups=[[filt]]
    )

    assert "[QUERY] 0 matched" in result
    assert "[SUMMARY]" not in result


def test_query_experiments_aggregate_path(experiments_file) -> None:
    result = query_experiments(
        select=["results.fold_results.mean.test_results.excess_sharpe"],
        limit=1
    )

    expected = statistics.mean([0.38, 0.45, 0.43])
    assert str(round(expected, 6)) in result


def test_query_experiments_len_path(experiments_file) -> None:
    result = query_experiments(
        select=["results.fold_results.len"],
        limit=1
    )

    assert "results.fold_results.len: 3" in result
    assert "min: 2.0" in result
    assert "max: 3.0" in result


def test_query_experiments_missing_path_raises(experiments_file) -> None:
    with pytest.raises(Exception, match="Missing key"):
        query_experiments(
            select=["experiment.nonexistent"],
            limit=1
        )


def test_query_experiments_string_filter(experiments_file) -> None:
    filt = StrFilter(path="experiment.strategy.base_net.type", eq="decision")
    result = query_experiments(
        select=["experiment.val_size"],
        filter_groups=[[filt]]
    )

    assert "[QUERY] 1 matched, showing 1" in result
    assert "experiment.val_size: 0.2" in result


def test_query_experiments_bool_filter(experiments_file) -> None:
    filt = BoolFilter(path="experiment.strategy.actions.allow_recurrence", eq=True)
    result = query_experiments(
        select=["experiment.val_size"],
        filter_groups=[[filt]]
    )

    assert "[QUERY] 2 matched, showing 2" in result
    assert "experiment.val_size: 0.15" in result
    assert "experiment.val_size: 0.1" in result


def test_query_experiments_or_filter_groups(experiments_file) -> None:
    group_a = [NumericFilter(path="experiment.strategy.opt.pop_size", eq=100)]
    group_b = [NumericFilter(path="experiment.strategy.opt.pop_size", eq=200)]

    result = query_experiments(
        select=["experiment.val_size"],
        filter_groups=[group_a, group_b]
    )

    assert "[QUERY] 2 matched, showing 2" in result
    assert "experiment.val_size: 0.15" in result
    assert "experiment.val_size: 0.2" in result


def test_query_experiments_summary_uses_all_matches(experiments_file) -> None:
    result = query_experiments(
        select=["results.overall_excess_sharpe"],
        limit=1
    )

    assert "[SUMMARY]" in result
    assert "experiments_matched: 3" in result
    assert "values_used: 3" in result
    assert "min: 0.31" in result
    assert "max: 0.55" in result


def test_query_experiments_summary_uses_aggregate_path(experiments_file) -> None:
    result = query_experiments(
        select=["results.fold_results.mean.test_results.excess_sharpe"]
    )

    assert "[SUMMARY]" in result
    assert "experiments_matched: 3" in result
    assert "values_used: 3" in result


def test_query_experiments_non_numeric_sort_raises(experiments_file) -> None:
    with pytest.raises(Exception, match="must resolve to a numeric value"):
        query_experiments(
            select=["experiment.val_size"],
            sort_by="experiment.strategy.base_net.type"
        )


def test_query_experiments_non_numeric_select_raises(experiments_file) -> None:
    with pytest.raises(Exception, match="must resolve to a numeric value"):
        query_experiments(select=["experiment.strategy.base_net.type"])


def test_query_experiments_population_std(experiments_file) -> None:
    result = query_experiments(select=["results.overall_excess_sharpe"])

    assert "std:" in result

    for line in result.splitlines():
        if line.startswith("std:"):
            std_value = float(line.split(":")[1].strip())
            break

    values = [0.31, 0.42, 0.55]
    expected_std = statistics.pstdev(values)

    assert abs(std_value - expected_std) < 1e-6


def test_compute_quantile_single_value() -> None:
    result = compute_quantile([5.0], 0.5)

    assert result == 5.0


def test_compute_quantile_two_values() -> None:
    result = compute_quantile([2.0, 8.0], 0.25)

    assert result == 3.5


def test_compute_quantile_median_even() -> None:
    result = compute_quantile([1.0, 2.0, 3.0, 4.0], 0.5)

    assert result == 2.5


def test_compute_quantile_boundaries() -> None:
    values = [1.0, 2.0, 3.0, 4.0, 5.0]

    assert compute_quantile(values, 0.0) == 1.0
    assert compute_quantile(values, 1.0) == 5.0
