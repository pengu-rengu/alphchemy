import pytest
from analysis.path import resolve_path, MissingKeyError
from analysis.query import SelectQuery
from analysis.filters import matches_filters, NumericFilter


def test_resolve_path_missing_key_raises_missing_key_error():
    obj = {"experiment": {"score": 1.0}}

    assert resolve_path(obj, "experiment.score") == 1.0

    with pytest.raises(MissingKeyError):
        resolve_path(obj, "experiment.missing")


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

    query = SelectQuery(select = ["experiment.score"], filters = [])
    query.run(None)

    assert query.skipped == 1
    assert query.results is not None
    summary = query.results[0]
    assert summary.min_ == 1.0
    assert summary.max_ == 3.0
