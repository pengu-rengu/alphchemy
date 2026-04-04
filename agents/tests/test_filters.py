from analysis.filters import (
    NumericFilter,
    StringFilter,
    BoolFilter,
    ContainsFilter,
    matches_filters
)


SAMPLE_OBJ = {
    "experiment": {
        "val_size": 0.15,
        "strategy": {
            "base_net": {"type": "logic"},
            "actions": {
                "allow_recurrence": True,
                "allowed_gates": ["and", "or", "xor"]
            },
            "opt": {"pop_size": 100}
        }
    },
    "results": {
        "overall_excess_sharpe": 0.42
    }
}


def test_numeric_gte_matches() -> None:
    filt = NumericFilter(path="results.overall_excess_sharpe", gte=0.4)
    assert matches_filters(SAMPLE_OBJ, [[filt]]) is True


def test_numeric_gte_rejects() -> None:
    filt = NumericFilter(path="results.overall_excess_sharpe", gte=0.5)
    assert matches_filters(SAMPLE_OBJ, [[filt]]) is False


def test_numeric_lte_matches() -> None:
    filt = NumericFilter(path="results.overall_excess_sharpe", lte=0.5)
    assert matches_filters(SAMPLE_OBJ, [[filt]]) is True


def test_numeric_lte_rejects() -> None:
    filt = NumericFilter(path="results.overall_excess_sharpe", lte=0.3)
    assert matches_filters(SAMPLE_OBJ, [[filt]]) is False


def test_numeric_eq_matches() -> None:
    filt = NumericFilter(path="experiment.strategy.opt.pop_size", eq=100)
    assert matches_filters(SAMPLE_OBJ, [[filt]]) is True


def test_numeric_eq_rejects() -> None:
    filt = NumericFilter(path="experiment.strategy.opt.pop_size", eq=200)
    assert matches_filters(SAMPLE_OBJ, [[filt]]) is False


def test_numeric_range_matches() -> None:
    filt = NumericFilter(path="results.overall_excess_sharpe", gte=0.4, lte=0.5)
    assert matches_filters(SAMPLE_OBJ, [[filt]]) is True


def test_numeric_range_rejects() -> None:
    filt = NumericFilter(path="results.overall_excess_sharpe", gte=0.5, lte=0.6)
    assert matches_filters(SAMPLE_OBJ, [[filt]]) is False


def test_string_eq_matches() -> None:
    filt = StringFilter(path="experiment.strategy.base_net.type", eq="logic")
    assert matches_filters(SAMPLE_OBJ, [[filt]]) is True


def test_string_eq_rejects() -> None:
    filt = StringFilter(path="experiment.strategy.base_net.type", eq="decision")
    assert matches_filters(SAMPLE_OBJ, [[filt]]) is False


def test_bool_eq_matches() -> None:
    filt = BoolFilter(path="experiment.strategy.actions.allow_recurrence", eq=True)
    assert matches_filters(SAMPLE_OBJ, [[filt]]) is True


def test_bool_eq_rejects() -> None:
    filt = BoolFilter(path="experiment.strategy.actions.allow_recurrence", eq=False)
    assert matches_filters(SAMPLE_OBJ, [[filt]]) is False


def test_contains_matches() -> None:
    filt = ContainsFilter(path="experiment.strategy.actions.allowed_gates", contains="xor")
    assert matches_filters(SAMPLE_OBJ, [[filt]]) is True


def test_contains_rejects() -> None:
    filt = ContainsFilter(path="experiment.strategy.actions.allowed_gates", contains="nand")
    assert matches_filters(SAMPLE_OBJ, [[filt]]) is False


def test_missing_path_rejects() -> None:
    filt = NumericFilter(path="experiment.nonexistent", gte=0.0)
    assert matches_filters(SAMPLE_OBJ, [[filt]]) is False


def test_and_within_group() -> None:
    passing = NumericFilter(path="results.overall_excess_sharpe", gte=0.4)
    failing = NumericFilter(path="experiment.strategy.opt.pop_size", eq=200)

    assert matches_filters(SAMPLE_OBJ, [[passing, failing]]) is False


def test_and_within_group_all_pass() -> None:
    filt_a = NumericFilter(path="results.overall_excess_sharpe", gte=0.4)
    filt_b = StringFilter(path="experiment.strategy.base_net.type", eq="logic")

    assert matches_filters(SAMPLE_OBJ, [[filt_a, filt_b]]) is True


def test_or_across_groups() -> None:
    failing_group = [NumericFilter(path="experiment.strategy.opt.pop_size", eq=200)]
    passing_group = [NumericFilter(path="results.overall_excess_sharpe", gte=0.4)]

    assert matches_filters(SAMPLE_OBJ, [failing_group, passing_group]) is True


def test_or_across_groups_all_fail() -> None:
    group_a = [NumericFilter(path="experiment.strategy.opt.pop_size", eq=200)]
    group_b = [NumericFilter(path="results.overall_excess_sharpe", gte=0.9)]

    assert matches_filters(SAMPLE_OBJ, [group_a, group_b]) is False


def test_mixed_or_and() -> None:
    group_a = [
        NumericFilter(path="results.overall_excess_sharpe", gte=0.4),
        NumericFilter(path="experiment.strategy.opt.pop_size", eq=200)
    ]
    group_b = [
        StringFilter(path="experiment.strategy.base_net.type", eq="logic")
    ]

    assert matches_filters(SAMPLE_OBJ, [group_a, group_b]) is True


def test_empty_filter_groups_matches_all() -> None:
    assert matches_filters(SAMPLE_OBJ, []) is True
