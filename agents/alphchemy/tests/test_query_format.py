import pytest
from analysis.query import Query, QueryResults, Selection
from analysis.filters import TimestampFilter, parse_timestamp_value
from analysis.format_analysis import format_value, format_query_results
from datetime import datetime


def test_select_id_rejected():
    query = Query(query = "select:\n    id")

    with pytest.raises(ValueError):
        query.parse()


def test_filter_id_rejected():
    query = Query(query = "select:\n    title\nfilters:\n    id >= 1")

    with pytest.raises(ValueError):
        query.parse()


def test_plain_selection_defaults_to_limit_25_offset_zero() -> None:
    query = Query(query = "select:\n    title")

    query.parse()

    assert query.select == [Selection(text = "title", path = "title")]


def test_window_selection_parses_limit() -> None:
    query = Query(query = "select:\n    10(title)")

    query.parse()

    assert query.select == [Selection(text = "10(title)", path = "title", limit = 10)]


def test_window_selection_parses_limit_and_offset() -> None:
    query = Query(query = "select:\n    15+50(title)")

    query.parse()

    expected = Selection(text = "15+50(title)", path = "title", limit = 15, offset = 50)
    assert query.select == [expected]


@pytest.mark.parametrize("limit", [0, 26])
def test_window_selection_rejects_limit_outside_range(limit: int) -> None:
    query = Query(query = f"select:\n    {limit}(title)")

    with pytest.raises(ValueError, match = "limit must be between 1 and 25"):
        query.parse()


@pytest.mark.parametrize("aggregate", ["mean", "max", "min", "std"])
def test_aggregate_selection_parses(aggregate: str) -> None:
    text = f"{aggregate}(results.mean:test_results.metrics.sharpe)"
    query = Query(query = f"select:\n    {text}")

    query.parse()

    selection = query.select[0]
    assert selection.text == text
    assert selection.path == "results.mean:test_results.metrics.sharpe"
    assert selection.aggregate == aggregate
    assert selection.limit is None


@pytest.mark.parametrize("selection", ["mean(10(title))", "10(mean(title))"])
def test_selection_rejects_nested_wrappers(selection: str) -> None:
    query = Query(query = f"select:\n    {selection}")

    with pytest.raises(ValueError, match = "cannot be nested"):
        query.parse()


def test_visibility_defaults_to_all() -> None:
    query = Query(query = "select:\n    title")

    query.parse()

    assert query.visibility == "all"


@pytest.mark.parametrize("visibility", ["all", "public", "private"])
def test_visibility_parses(visibility: str) -> None:
    query = Query(query = f"select:\n    title\nvisibility: {visibility}")

    query.parse()

    assert query.visibility == visibility


def test_visibility_parses_before_select() -> None:
    query = Query(query = "visibility: private\nselect:\n    title")

    query.parse()

    assert query.visibility == "private"
    assert query.select == [Selection(text = "title", path = "title")]


@pytest.mark.parametrize("visibility", ["", "shared"])
def test_visibility_rejects_invalid_value(visibility: str) -> None:
    query = Query(query = f"select:\n    title\nvisibility: {visibility}")

    with pytest.raises(ValueError, match = "visibility must be all, public, or private"):
        query.parse()


@pytest.mark.parametrize("operator, field", [
    (">=", "gte"),
    (">", "gt"),
    ("<=", "lte"),
    ("<", "lt"),
    ("==", "eq")
])
def test_timestamp_comparison_filters_parse(operator: str, field: str) -> None:
    query = Query(query = f"select:\n    title\nfilters:\n    experiment.start_timestamp {operator} 2024-06-01T00:00:00")
    expected = datetime(2024, 6, 1, 0, 0, 0)

    query.parse()

    timestamp_filter = query.filters[0]
    assert isinstance(timestamp_filter, TimestampFilter)
    assert getattr(timestamp_filter, field) == expected


def test_quoted_timestamp_comparison_filter_parses() -> None:
    query = Query(query = "select:\n    title\nfilters:\n    experiment.start_timestamp >= \"2024-06-01T00:00:00\"")
    expected = datetime(2024, 6, 1, 0, 0, 0)

    query.parse()

    timestamp_filter = query.filters[0]
    assert isinstance(timestamp_filter, TimestampFilter)
    assert timestamp_filter.gte == expected


def test_z_timestamp_comparison_filter_parses() -> None:
    query = Query(query = "select:\n    title\nfilters:\n    experiment.start_timestamp >= 2024-06-01T00:00:00Z")
    expected = datetime(2024, 6, 1, 0, 0, 0)

    query.parse()

    timestamp_filter = query.filters[0]
    assert isinstance(timestamp_filter, TimestampFilter)
    assert timestamp_filter.gte == expected


def test_offset_timestamp_normalizes_to_utc() -> None:
    parsed = parse_timestamp_value("2024-06-01T03:30:00.123456+03:30")
    expected = datetime(2024, 6, 1, 0, 0, 0, 123456)

    assert parsed == expected


def test_non_timestamp_string_filter_rejects_comparison() -> None:
    query = Query(query = "select:\n    title\nfilters:\n    title >= \"alpha\"")

    with pytest.raises(ValueError, match = "String filter only supports =="):
        query.parse()


def test_format_value_formats_timestamp():
    assert format_value("2026-01-02T12:00:00") == "Jan 2 2026 12:00"


def test_format_value_leaves_title_untouched():
    assert format_value("Copy of asdfasdf") == "Copy of asdfasdf"


def test_format_query_results_pairs_values_with_ids():
    query = Query(query = "select:\n    title")
    result = QueryResults(path = "title", values = ["alpha", "beta"], ids = [12, 13], skipped = 1)
    query.results = [result]

    output = format_query_results(query)

    assert "alpha (12), beta (13)" in output
    assert "[RESULTS] title" in output
    assert "skipped: 1" in output


def test_format_query_results_renders_aggregate_without_id() -> None:
    query = Query(query = "select:\n    mean(experiment.score)")
    result = QueryResults(path = "mean(experiment.score)", values = [2.0], ids = [], skipped = 0)
    query.results = [result]

    output = format_query_results(query)

    assert "[RESULTS] mean(experiment.score)" in output
    assert "2.0" in output
    assert "2.0 (" not in output
