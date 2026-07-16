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

    monkeypatch.setattr("analysis.query.load_experiments", lambda supabase: public_experiments(experiments))

    query = Query(query = "select:\n    experiment.score")
    query.run(None, "owner")

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

    monkeypatch.setattr("analysis.query.load_experiments", lambda supabase: public_experiments(experiments))

    query = Query(query = "select:\n    results.mean:test_results.metrics.excess_sharpe")
    query.run(None, "owner")

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

    monkeypatch.setattr("analysis.query.load_experiments", lambda supabase: public_experiments(experiments))

    query_text = "\n".join([
        "select:",
        "    title",
        "filters:",
        "    experiment.start_timestamp >= Jun 1 2024 00:00",
        "    experiment.start_timestamp < Jul 1 2024 00:00"
    ])
    query = Query(query = query_text)
    query.run(None, "owner")

    assert query.results is not None
    summary = query.results[0]
    assert summary.values == ["inside"]


def test_query_filters_last_updated_timestamp_range(monkeypatch) -> None:
    experiments = [
        {"id": 1, "last_updated": "2024-05-31T23:00:00", "title": "before"},
        {"id": 2, "last_updated": "2024-06-01T00:00:00.123456+00:00", "title": "inside"},
        {"id": 3, "last_updated": "2024-07-01T00:00:00", "title": "after"}
    ]

    monkeypatch.setattr("analysis.query.load_experiments", lambda supabase: public_experiments(experiments))

    query_text = "\n".join([
        "select:",
        "    last_updated",
        "filters:",
        "    last_updated >= 2024-06-01T00:00:00",
        "    last_updated < 2024-07-01T00:00:00Z"
    ])
    query = Query(query = query_text)
    query.run(None, "owner")

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

    monkeypatch.setattr("analysis.query.load_experiments", lambda supabase: public_experiments(experiments))

    query_text = "\n".join([
        "select:",
        "    2+1(title)",
        "filters:",
        "    experiment.score >= 1.0"
    ])
    query = Query(query = query_text)
    query.run(None, "owner")

    assert query.results is not None
    summary = query.results[0]
    assert summary.ids == [3, 4]
    assert summary.values == ["middle", "oldest"]


@pytest.mark.parametrize(
    "visibility, expected_titles",
    [
        ("all", ["public", "owned private"]),
        ("public", ["public"]),
        ("private", ["owned private"])
    ]
)
def test_owned_query_visibility(monkeypatch, visibility: str, expected_titles: list[str]) -> None:
    experiments = [
        {"id": 1, "title": "public", "is_public": True, "user_id": None},
        {"id": 2, "title": "owned private", "is_public": False, "user_id": "owner"},
        {"id": 3, "title": "other private", "is_public": False, "user_id": "other"}
    ]

    monkeypatch.setattr("analysis.query.load_experiments", lambda supabase: experiments)

    query = Query(query = f"select:\n    title\nvisibility: {visibility}")
    query.run(None, "owner")

    assert query.results is not None
    assert query.results[0].values == expected_titles


def test_visibility_applies_before_offset(monkeypatch) -> None:
    experiments = [
        {"id": 1, "title": "private", "is_public": False, "user_id": "other"},
        {"id": 2, "title": "first public", "is_public": True, "user_id": None},
        {"id": 3, "title": "second public", "is_public": True, "user_id": None}
    ]

    monkeypatch.setattr("analysis.query.load_experiments", lambda supabase: experiments)

    query = Query(query = "select:\n    25+1(title)\nvisibility: public")
    query.run(None, "owner")

    assert query.results is not None
    assert query.results[0].values == ["second public"]


def test_query_applies_independent_windows_per_selection(monkeypatch: pytest.MonkeyPatch) -> None:
    experiments = [
        {"id": 1, "title": "newest", "experiment": {"score": 4.0}},
        {"id": 2, "title": "second", "experiment": {"score": 3.0}},
        {"id": 3, "title": "third", "experiment": {"score": 2.0}}
    ]

    monkeypatch.setattr("analysis.query.load_experiments", lambda supabase: public_experiments(experiments))

    query = Query(query = "select:\n    1(title)\n    2+1(experiment.score)")
    query.run(None, "owner")

    assert query.results is not None
    assert query.results[0].values == ["newest"]
    assert query.results[0].ids == [1]
    assert query.results[1].values == [3.0, 2.0]
    assert query.results[1].ids == [2, 3]


@pytest.mark.parametrize(
    "aggregate, expected, expected_ids",
    [
        ("mean", 2.0, []),
        ("min", 1.0, [0]),
        ("max", 3.0, [2]),
        ("std", pytest.approx(0.816496580927726), [])
    ]
)
def test_query_aggregates_all_matching_experiments(
    monkeypatch: pytest.MonkeyPatch,
    aggregate: str,
    expected: object,
    expected_ids: list[int]
) -> None:
    experiments = [
        {"id": i, "experiment": {"score": float(i % 3 + 1)}}
        for i in range(30)
    ]

    monkeypatch.setattr("analysis.query.load_experiments", lambda supabase: public_experiments(experiments))

    query = Query(query = f"select:\n    {aggregate}(experiment.score)")
    query.run(None, "owner")

    assert query.results is not None
    summary = query.results[0]
    assert summary.values == [expected]
    assert summary.ids == expected_ids


def test_query_aggregate_coerces_bools_and_skips_unresolved_values(monkeypatch: pytest.MonkeyPatch) -> None:
    experiments = [
        {"id": 1, "experiment": {"enabled": False}},
        {"id": 2, "experiment": {"enabled": True}},
        {"id": 3, "experiment": {}},
        {"id": 4, "experiment": {"enabled": float("nan")}}
    ]

    monkeypatch.setattr("analysis.query.load_experiments", lambda supabase: public_experiments(experiments))

    query = Query(query = "select:\n    mean(experiment.enabled)")
    query.run(None, "owner")

    assert query.results is not None
    summary = query.results[0]
    assert summary.values == [0.5]
    assert summary.ids == []
    assert summary.skipped == 2


@pytest.mark.parametrize(
    "direction, expected_ids",
    [
        ("asc", [1, 3, 2]),
        ("desc", [1, 3, 4])
    ]
)
def test_query_sorts_before_selection_offset(monkeypatch: pytest.MonkeyPatch, direction: str, expected_ids: list[int]) -> None:
    experiments = [
        {"id": 1, "title": "newest tie", "experiment": {"score": 2.0}},
        {"id": 2, "title": "highest", "experiment": {"score": 3.0}},
        {"id": 3, "title": "oldest tie", "experiment": {"score": 2.0}},
        {"id": 4, "title": "lowest", "experiment": {"score": 1.0}}
    ]

    monkeypatch.setattr("analysis.query.load_experiments", lambda supabase: public_experiments(experiments))

    query = Query(query = f"select:\n    25+1(title)\nsort_{direction}: experiment.score")
    query.run(None, "owner")

    assert query.results is not None
    assert query.results[0].ids == expected_ids


def test_query_without_sort_preserves_loaded_order(monkeypatch: pytest.MonkeyPatch) -> None:
    experiments = [
        {"id": 1, "last_updated": "2024-06-02T00:00:00Z"},
        {"id": 2, "last_updated": "2024-06-01T00:00:00Z"}
    ]

    monkeypatch.setattr("analysis.query.load_experiments", lambda supabase: public_experiments(experiments))

    query = Query(query = "select:\n    last_updated")
    query.run(None, "owner")

    assert query.results is not None
    assert query.results[0].ids == [1, 2]


def test_query_filters_before_sorting(monkeypatch: pytest.MonkeyPatch) -> None:
    experiments = [
        {"id": 1, "experiment": {"enabled": True, "score": 2.0}},
        {"id": 2, "experiment": {"enabled": False, "score": "unsupported"}}
    ]

    monkeypatch.setattr("analysis.query.load_experiments", lambda supabase: public_experiments(experiments))

    query_text = "select:\n    experiment.score\nfilters:\n    experiment.enabled == true\nsort_desc: experiment.score"
    query = Query(query = query_text)
    query.run(None, "owner")

    assert query.results is not None
    assert query.results[0].ids == [1]


@pytest.mark.parametrize(
    "direction, expected_ids, expected_values",
    [
        ("asc", [2, 3, 1], [1.0, 2.0, 3.0]),
        ("desc", [1, 3, 2], [3.0, 2.0, 1.0])
    ]
)
def test_query_sorts_integer_values(
    monkeypatch: pytest.MonkeyPatch,
    direction: str,
    expected_ids: list[int],
    expected_values: list[float]
) -> None:
    experiments = [
        {"id": 1, "experiment": {"test_size": 3}},
        {"id": 2, "experiment": {"test_size": 1}},
        {"id": 3, "experiment": {"test_size": 2}}
    ]

    monkeypatch.setattr("analysis.query.load_experiments", lambda supabase: public_experiments(experiments))

    query = Query(query = f"select:\n    experiment.test_size\nsort_{direction}: experiment.test_size")
    query.run(None, "owner")

    assert query.results is not None
    assert query.results[0].ids == expected_ids
    assert query.results[0].values == expected_values


def test_query_sorts_by_aggregate_path(monkeypatch: pytest.MonkeyPatch) -> None:
    experiments = [
        {"id": 1, "results": [{"test_results": {"metrics": {"excess_sharpe": 1.0}}}]},
        {"id": 2, "results": [{"test_results": {"metrics": {"excess_sharpe": 3.0}}}]},
        {"id": 3, "results": [{"test_results": {"metrics": {"excess_sharpe": 2.0}}}]}
    ]

    monkeypatch.setattr("analysis.query.load_experiments", lambda supabase: public_experiments(experiments))

    path = "results.mean:test_results.metrics.excess_sharpe"
    query = Query(query = f"select:\n    {path}\nsort_desc: {path}")
    query.run(None, "owner")

    assert query.results is not None
    assert query.results[0].values == [3.0, 2.0, 1.0]
    assert query.results[0].ids == [2, 3, 1]


def test_query_sorts_timestamps_chronologically(monkeypatch: pytest.MonkeyPatch) -> None:
    experiments = [
        {"id": 1, "last_updated": "2024-06-01T00:00:00Z"},
        {"id": 2, "last_updated": "2024-06-01T02:00:00+03:00"},
        {"id": 3, "last_updated": "May 31 2024 22:00"}
    ]

    monkeypatch.setattr("analysis.query.load_experiments", lambda supabase: public_experiments(experiments))

    query = Query(query = "select:\n    last_updated\nsort_asc: last_updated")
    query.run(None, "owner")

    assert query.results is not None
    assert query.results[0].ids == [3, 2, 1]


def test_query_sort_skips_missing_and_non_finite_values(monkeypatch: pytest.MonkeyPatch) -> None:
    experiments = [
        {"id": 1, "experiment": {"score": 2.0}},
        {"id": 2, "experiment": {}},
        {"id": 3, "experiment": {"score": float("nan")}},
        {"id": 4, "experiment": {"score": 1.0}}
    ]

    monkeypatch.setattr("analysis.query.load_experiments", lambda supabase: public_experiments(experiments))

    query = Query(query = "select:\n    experiment.score\nsort_asc: experiment.score")
    query.run(None, "owner")

    assert query.results is not None
    summary = query.results[0]
    assert summary.values == [1.0, 2.0]
    assert summary.ids == [4, 1]
    assert summary.skipped == 2


@pytest.mark.parametrize("value", ["alpha", True])
def test_query_sort_rejects_unsupported_values(monkeypatch: pytest.MonkeyPatch, value: str | bool) -> None:
    experiments = [{"id": 1, "experiment": {"value": value}}]

    monkeypatch.setattr("analysis.query.load_experiments", lambda supabase: public_experiments(experiments))

    query = Query(query = "select:\n    experiment.value\nsort_asc: experiment.value")

    with pytest.raises(ValueError, match = "must resolve to numbers or timestamps"):
        query.run(None, "owner")


def test_query_sort_rejects_mixed_numbers_and_timestamps(monkeypatch: pytest.MonkeyPatch) -> None:
    experiments = [
        {"id": 1, "experiment": {"value": 1.0}},
        {"id": 2, "experiment": {"value": "2024-06-01T00:00:00Z"}}
    ]

    monkeypatch.setattr("analysis.query.load_experiments", lambda supabase: public_experiments(experiments))

    query = Query(query = "select:\n    experiment.value\nsort_asc: experiment.value")

    with pytest.raises(ValueError, match = "cannot mix numbers and timestamps"):
        query.run(None, "owner")


def public_experiments(experiments: list[dict]) -> list[dict]:
    return [experiment | {"is_public": True, "user_id": None} for experiment in experiments]
