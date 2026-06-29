import pytest
from analysis.query import Query, QueryResults
from analysis.format_analysis import format_timestamp, format_query_results


def test_select_id_rejected():
    query = Query(query = "select:\n    id")

    with pytest.raises(ValueError):
        query.parse()


def test_filter_id_rejected():
    query = Query(query = "select:\n    title\nfilters:\n    id >= 1")

    with pytest.raises(ValueError):
        query.parse()


def test_format_timestamp_formats_timestamp():
    assert format_timestamp("2026-01-02T12:00:00") == "Jan 2 2026 12:00"


def test_format_timestamp_leaves_title_untouched():
    assert format_timestamp("Copy of asdfasdf") == "Copy of asdfasdf"


def test_format_query_results_pairs_values_with_ids():
    query = Query(query = "select:\n    title")
    result = QueryResults(path = "title", values = ["alpha", "beta"], ids = [12, 13], skipped = 1)
    query.results = [result]

    output = format_query_results(query)

    assert "alpha (12), beta (13)" in output
    assert "[RESULTS] title" in output
    assert "skipped: 1" in output
