from typing import Any

from analysis.notebook_worker import run_queries


class FakeResponse:

    def __init__(self, data: list[dict[str, Any]]) -> None:
        self.data = data


class FakeTable:

    def __init__(self, rows: list[dict[str, Any]]) -> None:
        self.rows = rows

    def select(self, columns: str) -> "FakeTable":
        return self

    def eq(self, column: str, value: Any) -> "FakeTable":
        return self

    def execute(self) -> FakeResponse:
        return FakeResponse(self.rows)


class FakeSupabase:

    def __init__(self, rows: list[dict[str, Any]]) -> None:
        self.rows = rows

    def table(self, name: str) -> FakeTable:
        return FakeTable(self.rows)


def fold_result(value: float) -> dict[str, Any]:
    return {
        "test_results": {
            "excess_sharpe": value
        }
    }


def experiment_row(row_id: int, value: float) -> dict[str, Any]:
    return {
        "id": row_id,
        "experiment": {},
        "results": [fold_result(value)],
        "status": "completed"
    }


def test_run_queries_ignores_stored_results() -> None:
    rows = [
        experiment_row(1, 2.0),
        experiment_row(2, 6.0)
    ]
    supabase = FakeSupabase(rows)
    queries = [
        {
            "id": "query-1",
            "select": ["results.mean.test_results.excess_sharpe"],
            "filters": [],
            "results": [
                {
                    "min": 0.0,
                    "q1": 0.0,
                    "median": 0.0,
                    "q3": 0.0,
                    "max": 0.0
                }
            ]
        }
    ]

    output = run_queries(queries, supabase)

    assert output[0]["id"] == "query-1"
    assert output[0]["results"][0]["min"] == 2.0
    assert output[0]["results"][0]["max"] == 6.0
