from typing import Any

from agents.nodes import CommandNode
from analysis.filters import StrFilter
from analysis.query import query_experiments


class FakeResponse:

    def __init__(self, data: list[dict[str, Any]]) -> None:
        self.data = data


class FakeTable:

    def __init__(self, rows: list[dict[str, Any]]) -> None:
        self.rows = rows
        self.selected_columns = ""
        self.status_filter = None
        self.non_null_column = None

    @property
    def not_(self) -> "FakeTable":
        return self

    def select(self, columns: str) -> "FakeTable":
        self.selected_columns = columns
        return self

    def eq(self, column: str, value: Any) -> "FakeTable":
        self.status_filter = {
            "column": column,
            "value": value
        }
        return self

    def is_(self, column: str, value: Any) -> "FakeTable":
        self.non_null_column = column
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
    status: str,
    results: Any,
    group: str = "keep"
) -> dict[str, Any]:
    return {
        "id": row_id,
        "status": status,
        "experiment": {
            "group": group
        },
        "results": results
    }


def test_query_experiments_reads_completed_supabase_rows() -> None:
    rows = [
        experiment_row(7, "completed", [fold_result(1.0), fold_result(3.0)]),
        experiment_row(8, "running", [fold_result(9.0)]),
        experiment_row(9, "completed", None),
        experiment_row(10, "completed", {"error": "invalid"})
    ]
    supabase = FakeSupabase(rows)

    output = query_experiments(
        supabase = supabase,
        select = ["results.mean.test_results.excess_sharpe"]
    )

    assert supabase.table_name == "experiments"
    assert supabase.table_query.selected_columns == "id, experiment, results, status"
    assert supabase.table_query.status_filter == {"column": "status", "value": "completed"}
    assert supabase.table_query.non_null_column == "results"
    assert "[QUERY] 1 matched, showing 1" in output
    assert "--- Experiment 7 ---" in output
    assert "--- Experiment 8 ---" not in output
    assert "results.mean.test_results.excess_sharpe: 2.0" in output
    assert "experiments_matched: 1" in output


def test_query_experiments_applies_existing_filters() -> None:
    rows = [
        experiment_row(11, "completed", [fold_result(5.0)], "keep"),
        experiment_row(12, "completed", [fold_result(1.0)], "skip")
    ]
    supabase = FakeSupabase(rows)
    filters = [[StrFilter(path = "experiment.group", eq = "keep")]]

    output = query_experiments(
        supabase = supabase,
        select = ["results.mean.test_results.excess_sharpe"],
        filter_groups = filters
    )

    assert "[QUERY] 1 matched, showing 1" in output
    assert "--- Experiment 11 ---" in output
    assert "--- Experiment 12 ---" not in output
    assert "results.mean.test_results.excess_sharpe: 5.0" in output


def test_command_node_routes_supabase_to_analyze_data() -> None:
    rows = [
        experiment_row(21, "completed", [fold_result(4.0)])
    ]
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

    assert "--- Experiment 21 ---" in output
    assert "results.mean.test_results.excess_sharpe: 4.0" in output
