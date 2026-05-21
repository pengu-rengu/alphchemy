from typing import Any

from analysis.notebook_worker import process_working_notebook, run_queries, write_idle_notebook


class FakeResponse:

    def __init__(self, data: list[dict[str, Any]]) -> None:
        self.data = data


class FakeTable:

    def __init__(self, rows: list[dict[str, Any]]) -> None:
        self.rows = rows
        self.values: dict[str, Any] | None = None
        self.filters: dict[str, Any] = {}

    def select(self, columns: str) -> "FakeTable":
        return self

    def update(self, values: dict[str, Any]) -> "FakeTable":
        self.values = values
        return self

    def eq(self, column: str, value: Any) -> "FakeTable":
        self.filters[column] = value
        return self

    def order(self, column: str) -> "FakeTable":
        return self

    def limit(self, count: int) -> "FakeTable":
        return self

    def execute(self) -> FakeResponse:
        if self.values is not None:
            for row in self.rows:
                row_id = self.filters.get("id")
                if row_id is None or row["id"] == row_id:
                    row.update(self.values)

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


def test_write_idle_notebook_clears_error_message() -> None:
    rows = [
        {
            "id": 4,
            "queries": [],
            "status": "errored",
            "error_message": "bad query"
        }
    ]
    supabase = FakeSupabase(rows)
    queries: list[dict[str, Any]] = []

    write_idle_notebook(supabase, 4, queries)

    assert rows[0]["status"] == "idle"
    assert rows[0]["error_message"] is None


def test_process_working_notebook_writes_error_message() -> None:
    rows = [
        {
            "id": 5,
            "queries": [
                {
                    "id": "query-1",
                    "filters": []
                }
            ],
            "status": "working",
            "error_message": None
        }
    ]
    supabase = FakeSupabase(rows)

    processed = process_working_notebook(supabase)

    assert processed
    assert rows[0]["status"] == "errored"
    assert isinstance(rows[0]["error_message"], str)
