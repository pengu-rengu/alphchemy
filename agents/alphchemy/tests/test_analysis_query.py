from typing import Any

from agents.nodes import CommandNode
from analysis.filters import StrFilter
from analysis.query import SelectQuery


class FakeResponse:

    def __init__(self, data: list[dict[str, Any]]) -> None:
        self.data = data


class FakeTable:

    def __init__(self, rows: list[dict[str, Any]]) -> None:
        self.rows = rows
        self.selected_columns = ""
        self.status_filter = None

    def select(self, columns: str) -> "FakeTable":
        self.selected_columns = columns
        return self

    def eq(self, column: str, value: Any) -> "FakeTable":
        self.status_filter = {
            "column": column,
            "value": value
        }
        return self

    def execute(self) -> FakeResponse:
        return FakeResponse(self.rows)


class FakeSupabase:

    def __init__(self, rows: list[dict[str, Any]]) -> None:
        self.rows = rows
        self.table_name = ""
        self.table_query = FakeTable(rows)

    def table(self, name: str) -> FakeTable:
        self.table_name = name
        return self.table_query


def fold_result(value: float) -> dict[str, Any]:
    return {
        "test_results": {
            "excess_sharpe": value
        }
    }


def experiment_row(
    row_id: int,
    results: Any,
    group: str = "keep"
) -> dict[str, Any]:
    return {
        "id": row_id,
        "status": "completed",
        "experiment": {
            "group": group
        },
        "results": results
    }


def test_select_query_run_populates_five_number_summary() -> None:
    rows = [
        experiment_row(7, [fold_result(1.0), fold_result(3.0)]),
        experiment_row(8, [fold_result(5.0)])
    ]
    supabase = FakeSupabase(rows)
    query = SelectQuery(
        select = ["results.mean.test_results.excess_sharpe"],
        filters = []
    )

    assert query.id is None

    query.run(supabase)

    assert supabase.table_name == "experiments"
    assert supabase.table_query.selected_columns == "id, experiment, results, status"
    assert supabase.table_query.status_filter == {"column": "status", "value": "completed"}
    assert query.results is not None
    assert len(query.results) == 1
    assert query.results[0].min_ == 2.0
    assert query.results[0].max_ == 5.0
    assert query.results[0].median == 3.5


def test_select_query_run_applies_filters() -> None:
    rows = [
        experiment_row(11, [fold_result(5.0)], "keep"),
        experiment_row(12, [fold_result(1.0)], "skip")
    ]
    supabase = FakeSupabase(rows)
    query = SelectQuery(
        select = ["results.mean.test_results.excess_sharpe"],
        filters = [StrFilter(path = "experiment.group", eq = "keep")]
    )

    query.run(supabase)

    assert query.results is not None
    assert query.results[0].min_ == 5.0
    assert query.results[0].max_ == 5.0


def test_select_query_run_keeps_results_null_when_no_experiments_match() -> None:
    rows = [experiment_row(11, [fold_result(5.0)], "skip")]
    supabase = FakeSupabase(rows)
    query = SelectQuery(
        select = ["results.mean.test_results.excess_sharpe"],
        filters = [StrFilter(path = "experiment.group", eq = "keep")]
    )

    query.run(supabase)

    assert query.results is None


def test_command_node_routes_supabase_to_analyze_data() -> None:
    rows = [experiment_row(21, [fold_result(4.0)])]
    supabase = FakeSupabase(rows)
    command_node = CommandNode(
        open_router = object(),
        subagent_pool = [],
        supabase = supabase
    )
    state = {
        "is_subagent": False,
        "agent_order": ["Main"],
        "turn": 0,
        "proposal_state": {
            "state": "idle"
        },
        "commands": ["analyze_data"],
        "params": [
            {
                "select": ["results.mean.test_results.excess_sharpe"]
            }
        ]
    }

    new_state = command_node(state)
    output = new_state["agent_contexts"]["updates"]["Main"]["personal_output"]

    assert "[QUERY] 1 path(s) summarized" in output
    assert "[SUMMARY] results.mean.test_results.excess_sharpe" in output
    assert "min: 4.0" in output
