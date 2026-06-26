import pytest
from analysis.path import resolve_path, MissingKeyError
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


def test_resolve_path_rejects_old_aggregate_syntax():
    obj = {"results": []}

    with pytest.raises(ValueError, match = "colon syntax"):
        resolve_path(obj, "results.mean.test_results.metrics.sharpe")

    with pytest.raises(ValueError, match = "colon syntax"):
        resolve_path(obj, "results.len")


def test_resolve_path_error_includes_non_dictionary_key_context():
    obj = {"results": [{"test_results": 1.0}]}

    with pytest.raises(Exception, match = "results.test_results"):
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
