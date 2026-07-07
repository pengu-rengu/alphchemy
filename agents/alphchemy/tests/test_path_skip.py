import pytest
from analysis.path import resolve_path, MissingKeyError, parse_path, KeySegment, AggregateSegment, SelfSegment
from analysis.query import Query
from analysis.filters import matches_filters, NumericFilter


def test_resolve_path_missing_key_raises_missing_key_error():
    obj = {"experiment": {"score": 1.0}}

    assert resolve_path(obj, "experiment.score") == 1.0

    with pytest.raises(MissingKeyError):
        resolve_path(obj, "experiment.missing")


def test_resolve_path_supports_colon_aggregate_syntax():
    obj = {
        "results": [
            {"test_results": {"metrics": {"sharpe": 1.0}}},
            {"test_results": {"metrics": {"sharpe": 3.0}}},
            {"test_results": {"metrics": {"sharpe": "bad"}}},
            {"train_results": {"metrics": {"sharpe": 100.0}}}
        ]
    }

    mean = resolve_path(obj, "results.mean:test_results.metrics.sharpe")
    count = resolve_path(obj, "results.len:test_results.metrics.sharpe")

    assert mean == 2.0
    assert count == 3.0


def test_parse_path_supports_nested_colon_aggregate_syntax():
    segments = parse_path("results.mean:test_results.std:equity_curve.self".split("."))

    assert segments == [
        KeySegment(key = "results"),
        AggregateSegment(
            func = "mean",
            inner_segments = [
                KeySegment(key = "test_results"),
                AggregateSegment(
                    func = "std",
                    inner_segments = [
                        KeySegment(key = "equity_curve"),
                        SelfSegment()
                    ]
                )
            ]
        )
    ]


def test_resolve_path_supports_nested_colon_aggregate_syntax():
    obj = {
        "results": [
            {"test_results": {"equity_curve": [1.0, 3.0]}},
            {"test_results": {"equity_curve": [10.0, 14.0]}},
            {"train_results": {"equity_curve": [100.0]}}
        ]
    }

    value = resolve_path(obj, "results.mean:test_results.std:equity_curve.self")

    assert value == 1.5


def test_self_aggregate_funcs_over_flat_list():
    obj = {"curve": [2.0, 4.0, 6.0]}

    assert resolve_path(obj, "curve.mean:self") == 4.0
    assert resolve_path(obj, "curve.min:self") == 2.0
    assert resolve_path(obj, "curve.max:self") == 6.0
    assert resolve_path(obj, "curve.len:self") == 3.0


def test_resolve_path_aggregates_bool_values() -> None:
    obj = {
        "results": [
            {"test_results": {"is_invalid": False}},
            {"test_results": {"is_invalid": True}},
            {"test_results": {"is_invalid": True}},
            {"train_results": {"is_invalid": True}}
        ]
    }

    mean = resolve_path(obj, "results.mean:test_results.is_invalid")
    minimum = resolve_path(obj, "results.min:test_results.is_invalid")
    maximum = resolve_path(obj, "results.max:test_results.is_invalid")
    std = resolve_path(obj, "results.std:test_results.is_invalid")

    assert mean == pytest.approx(2.0 / 3.0)
    assert minimum == 0.0
    assert maximum == 1.0
    assert std == pytest.approx(0.4714045207910317)


def test_resolve_path_self_aggregates_bool_values() -> None:
    obj = {"signals": [False, True]}

    assert resolve_path(obj, "signals.mean:self") == 0.5
    assert resolve_path(obj, "signals.min:self") == 0.0
    assert resolve_path(obj, "signals.max:self") == 1.0


def test_self_must_be_final_segment():
    obj = {"curve": [1.0]}

    with pytest.raises(ValueError, match = "final segment"):
        resolve_path(obj, "curve.mean:self.extra")


def test_self_requires_list_target():
    obj = {"metrics": {"sharpe": 1.0}}

    with pytest.raises(Exception, match = ".self requires a list target"):
        resolve_path(obj, "metrics.std:sharpe.self")


def test_resolve_path_len_counts_list_valued_paths():
    obj = {
        "results": [
            {"test_results": {"equity_curve": [1.0, 2.0]}},
            {"test_results": {"equity_curve": [3.0, 4.0]}},
            {"train_results": {"equity_curve": [5.0, 6.0]}}
        ]
    }

    value = resolve_path(obj, "results.len:test_results.equity_curve")

    assert value == 2.0


def test_resolve_path_rejects_old_aggregate_syntax():
    obj = {"results": []}

    with pytest.raises(ValueError, match = "colon syntax"):
        resolve_path(obj, "results.mean.test_results.metrics.sharpe")

    with pytest.raises(ValueError, match = "colon syntax"):
        resolve_path(obj, "results.len")


def test_resolve_path_error_includes_non_dictionary_key_context():
    obj = {"results": [{"test_results": 1.0}]}

    with pytest.raises(Exception, match = "test_results.metrics"):
        resolve_path(obj, "results.mean:test_results.metrics.sharpe")


def test_resolve_path_error_includes_aggregate_target_context():
    obj = {"results": {"test_results": {"metrics": {"sharpe": 1.0}}}}

    with pytest.raises(Exception, match = "results"):
        resolve_path(obj, "results.mean:test_results.metrics.sharpe")


def test_resolve_path_error_includes_empty_numeric_aggregate_context():
    obj = {
        "results": [
            {"test_results": {"metrics": {"sharpe": "bad"}}}
        ]
    }

    with pytest.raises(Exception, match = "test_results.metrics.sharpe"):
        resolve_path(obj, "results.mean:test_results.metrics.sharpe")


def test_matches_filters_propagates_missing_key_error():
    obj = {"experiment": {}}
    filt = NumericFilter(path = "experiment.score", gte = 0.0)

    with pytest.raises(MissingKeyError):
        matches_filters(obj, [[filt]])


def test_select_query_skips_missing_and_counts(monkeypatch):
    experiments = [
        {"id": 1, "experiment": {"score": 1.0}, "results": None},
        {"id": 2, "experiment": {}, "results": None},
        {"id": 3, "experiment": {"score": 3.0}, "results": None}
    ]

    monkeypatch.setattr("analysis.query.load_experiments", lambda supabase: experiments)

    query = Query(query = "select:\n    experiment.score")
    query.run(None)

    assert query.results is not None
    summary = query.results[0]
    assert summary.skipped == 1
    assert summary.values == [1.0, 3.0]


def test_select_query_skips_missing_aggregate_values(monkeypatch):
    experiments = [
        {
            "id": 1,
            "results": [
                {"test_results": {"metrics": {}}}
            ]
        },
        {
            "id": 2,
            "results": [
                {"test_results": {"metrics": {"excess_sharpe": 1.0}}},
                {"test_results": {"metrics": {"excess_sharpe": 3.0}}}
            ]
        }
    ]

    monkeypatch.setattr("analysis.query.load_experiments", lambda supabase: experiments)

    query = Query(query = "select:\n    results.mean:test_results.metrics.excess_sharpe")
    query.run(None)

    assert query.results is not None
    summary = query.results[0]
    assert summary.skipped == 1
    assert summary.values == [2.0]


def test_query_filters_timestamp_range(monkeypatch) -> None:
    experiments = [
        {"id": 1, "title": "before", "experiment": {"start_timestamp": "2024-05-31T23:00:00"}},
        {"id": 2, "title": "inside", "experiment": {"start_timestamp": "2024-06-01T00:00:00"}},
        {"id": 3, "title": "after", "experiment": {"start_timestamp": "2024-07-01T00:00:00"}},
        {"id": 4, "title": "invalid", "experiment": {"start_timestamp": "Copy of asdfasdf"}}
    ]

    monkeypatch.setattr("analysis.query.load_experiments", lambda supabase: experiments)

    query_text = "\n".join([
        "select:",
        "    title",
        "filters:",
        "    experiment.start_timestamp >= 2024-06-01T00:00:00",
        "    experiment.start_timestamp < 2024-07-01T00:00:00"
    ])
    query = Query(query = query_text)
    query.run(None)

    assert query.results is not None
    summary = query.results[0]
    assert summary.values == ["inside"]


def test_query_filters_last_edited_timestamp_range(monkeypatch) -> None:
    experiments = [
        {"id": 1, "last_edited": "2024-05-31T23:00:00", "title": "before"},
        {"id": 2, "last_edited": "2024-06-01T00:00:00.123456+00:00", "title": "inside"},
        {"id": 3, "last_edited": "2024-07-01T00:00:00", "title": "after"}
    ]

    monkeypatch.setattr("analysis.query.load_experiments", lambda supabase: experiments)

    query_text = "\n".join([
        "select:",
        "    last_edited",
        "filters:",
        "    last_edited >= 2024-06-01T00:00:00",
        "    last_edited < 2024-07-01T00:00:00Z"
    ])
    query = Query(query = query_text)
    query.run(None)

    assert query.results is not None
    summary = query.results[0]
    assert summary.values == ["2024-06-01T00:00:00.123456+00:00"]


def test_query_applies_offset_after_filters_before_limit(monkeypatch) -> None:
    experiments = [
        {"id": 1, "title": "newest", "experiment": {"score": 3.0}},
        {"id": 2, "title": "filtered out", "experiment": {"score": 0.0}},
        {"id": 3, "title": "middle", "experiment": {"score": 2.0}},
        {"id": 4, "title": "oldest", "experiment": {"score": 1.0}}
    ]

    monkeypatch.setattr("analysis.query.load_experiments", lambda supabase: experiments)

    query_text = "\n".join([
        "select:",
        "    title",
        "filters:",
        "    experiment.score >= 1.0",
        "limit: 2",
        "offset: 1"
    ])
    query = Query(query = query_text)
    query.run(None)

    assert query.results is not None
    summary = query.results[0]
    assert summary.ids == [3, 4]
    assert summary.values == ["middle", "oldest"]
