from __future__ import annotations

import anyio
import pytest
from mcp.shared.memory import create_connected_server_and_client_session
from mcp_server import server


class FakeResponse:
    def __init__(self, data: list[dict]):
        self.data = data


class FakeTable:
    def __init__(self, rows: list[dict]):
        self.rows = rows
        self.operation: str | None = None
        self.values: dict | None = None
        self.notebook_id: int | None = None
        self.deleted_id: int | None = None
        self.inserted_values: dict | None = None
        self.filters: dict[str, object] = {}
        self.limit_count: int | None = None
        self.range_start: int | None = None
        self.range_end: int | None = None
        self.order_column: str | None = None
        self.order_desc = False
        self.selected_columns: list[str] | None = None

    def select(self, columns: str | None = None) -> FakeTable:
        self.operation = "select"
        if columns is not None:
            self.selected_columns = [column.strip() for column in columns.split(",")]

        return self

    def insert(self, values: dict) -> FakeTable:
        self.operation = "insert"
        self.values = values
        return self

    def update(self, values: dict) -> FakeTable:
        self.operation = "update"
        self.values = values
        return self

    def delete(self) -> FakeTable:
        self.operation = "delete"
        return self

    def eq(self, column: str, value: object) -> FakeTable:
        self.filters[column] = value

        if column == "id":
            self.notebook_id = value

        return self

    def limit(self, count: int) -> FakeTable:
        self.limit_count = count
        return self

    def range(self, start: int, end: int) -> FakeTable:
        self.range_start = start
        self.range_end = end
        return self

    def order(self, column: str, desc: bool = False) -> FakeTable:
        self.order_column = column
        self.order_desc = desc
        return self

    def execute(self) -> FakeResponse:
        if self.operation == "insert":
            self.inserted_values = self.values
            row = dict(self.values)
            row["id"] = len(self.rows) + 1
            row["last_edited"] = "2026-06-26T00:00:00Z"
            self.rows.append(row)
            return FakeResponse([dict(row)])

        if self.operation == "update":
            row = self.match_row()
            row.update(self.values)
            return FakeResponse([dict(row)])

        if self.operation == "delete":
            self.deleted_id = self.notebook_id
            self.rows[:] = [row for row in self.rows if row["id"] != self.notebook_id]
            return FakeResponse([])

        if self.notebook_id is None:
            return FakeResponse(self.query_rows())

        row = self.match_row()
        projected = self.project_row(row)
        return FakeResponse([projected])

    def query_rows(self) -> list[dict]:
        rows = [dict(row) for row in self.rows if self.matches(row)]

        if self.order_column is not None:
            rows = sorted(rows, key = self.sort_value, reverse = self.order_desc)

        if self.range_start is not None:
            rows = rows[self.range_start:self.range_end + 1]
        elif self.limit_count is not None:
            rows = rows[:self.limit_count]

        return [self.project_row(row) for row in rows]

    def matches(self, row: dict) -> bool:
        for column, value in self.filters.items():
            if row[column] != value:
                return False

        return True

    def sort_value(self, row: dict) -> object:
        return row[self.order_column]

    def project_row(self, row: dict) -> dict:
        if self.selected_columns is None:
            return dict(row)

        return {column: row[column] for column in self.selected_columns}

    def match_row(self) -> dict:
        for row in self.rows:
            if self.matches(row):
                return row

        raise ValueError(f"missing notebook id={self.notebook_id}")


class FakeValidationTable:
    def __init__(self, terminal_status: str, result_message: str | None):
        self.terminal_status = terminal_status
        self.result_message = result_message
        self.operation: str | None = None
        self.inserted_values: dict | None = None

    def insert(self, values: dict) -> FakeValidationTable:
        self.operation = "insert"
        self.inserted_values = values
        return self

    def select(self, columns: str) -> FakeValidationTable:
        self.operation = "select"
        return self

    def eq(self, column: str, value: object) -> FakeValidationTable:
        return self

    def execute(self) -> FakeResponse:
        if self.operation == "insert":
            return FakeResponse([{"id": 1}])

        return FakeResponse([{"status": self.terminal_status, "result_message": self.result_message}])


class FakeSupabase:
    def __init__(self, rows: list[dict], experiment_rows: list[dict] | None = None, validation_table: FakeValidationTable | None = None):
        self.notebooks = FakeTable(rows)
        experiments = [] if experiment_rows is None else experiment_rows
        self.experiments = FakeTable(experiments)
        self.validation_table = validation_table

    def table(self, name: str) -> FakeTable | FakeValidationTable:
        if name == "notebooks":
            return self.notebooks

        if name == "experiments":
            return self.experiments

        if name == "validation_jobs":
            if self.validation_table is None:
                raise ValueError("no validation table configured")

            return self.validation_table

        raise ValueError(f"unexpected table: {name}")


def test_mcp_server_tools():
    async def run():
        async with create_connected_server_and_client_session(server.mcp) as session:
            await session.initialize()

            tools = await session.list_tools()
            tool_names = [tool.name for tool in tools.tools]
            assert "get_documentation" in tool_names
            assert "queue_experiment" in tool_names
            assert "validate_experiment" in tool_names
            assert "list_experiments" in tool_names
            assert "query_experiments" in tool_names
            assert "get_experiment" in tool_names
            assert "delete_experiment" in tool_names
            assert "list_notebooks" in tool_names
            assert "view_notebook" in tool_names
            assert "create_notebook" in tool_names
            assert "update_notebook" in tool_names
            assert "delete_notebook" in tool_names

            doc_result = await session.call_tool("get_documentation", {})
            doc_text = doc_result.content[0].text
            assert "# Alphchemy" in doc_text
            assert "# Experiment source format" in doc_text
            assert "# Notebook Description" in doc_text
            assert "\"queries\"" in doc_text
            assert "\"notes\"" in doc_text
            assert "\"results\"" in doc_text
            assert "\"error_message\"" in doc_text
            assert "\"command\": \"[CMD]\"" not in doc_text

    anyio.run(run)


def test_queue_experiment_inserts_source_not_experiment(monkeypatch: pytest.MonkeyPatch):
    experiment_rows = []
    fake_supabase = FakeSupabase([], experiment_rows)
    monkeypatch.setattr(server, "supabase", fake_supabase)

    result = server.queue_experiment(title = "Demo", source = "cv_folds: 3")

    assert result == "queued id=1 title=Demo"
    assert experiment_rows[0]["source"] == "cv_folds: 3"
    assert experiment_rows[0]["status"] == "queued"
    assert "experiment" not in experiment_rows[0]


def test_validate_experiment_returns_valid(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setattr(server.time, "sleep", lambda seconds: None)
    validation_table = FakeValidationTable("completed_valid", "Source is valid")
    fake_supabase = FakeSupabase([], validation_table = validation_table)
    monkeypatch.setattr(server, "supabase", fake_supabase)

    result = server.validate_experiment(source = "cv_folds: 3")

    assert result == "valid"
    assert validation_table.inserted_values["source"] == "cv_folds: 3"
    assert validation_table.inserted_values["status"] == "working"


def test_validate_experiment_returns_invalid(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setattr(server.time, "sleep", lambda seconds: None)
    validation_table = FakeValidationTable("completed_invalid", "val_size must be > 0.0")
    fake_supabase = FakeSupabase([], validation_table = validation_table)
    monkeypatch.setattr(server, "supabase", fake_supabase)

    result = server.validate_experiment(source = "val_size: 0")

    assert result == "invalid: val_size must be > 0.0"


def test_list_experiments_returns_50_from_offset(monkeypatch: pytest.MonkeyPatch):
    experiment_rows = [make_experiment_row(experiment_id) for experiment_id in range(1, 241)]
    fake_supabase = FakeSupabase([], experiment_rows)
    monkeypatch.setattr(server, "supabase", fake_supabase)

    result = server.list_experiments(offset = 10)

    sorted_rows = sorted(experiment_rows, key = lambda row: row["last_edited"], reverse = True)
    expected_rows = sorted_rows[10:60]
    expected_ids = [row["id"] for row in expected_rows]

    assert [row["id"] for row in result] == expected_ids
    assert len(result) == 50
    assert set(result[0].keys()) == {"id", "last_edited", "title", "status"}


def test_list_experiments_rejects_negative_offset():
    with pytest.raises(ValueError, match = "offset must be >= 0"):
        server.list_experiments(offset = -1)


def test_delete_experiment_deletes_by_id(monkeypatch: pytest.MonkeyPatch):
    experiment_rows = [make_experiment_row(1)]
    fake_supabase = FakeSupabase([], experiment_rows)
    monkeypatch.setattr(server, "supabase", fake_supabase)

    result = server.delete_experiment(1)

    assert result == "deleted experiment id=1"
    assert fake_supabase.experiments.deleted_id == 1
    assert experiment_rows == []


def test_create_notebook_with_queries_queues_work(monkeypatch: pytest.MonkeyPatch):
    rows = []
    fake_supabase = FakeSupabase(rows)
    monkeypatch.setattr(server, "supabase", fake_supabase)

    result = server.create_notebook(
        title = " New notebook ",
        queries = ["select:\n    id"],
        notes = ["note"]
    )

    assert result == "created notebook id=1"
    assert rows[0]["title"] == "New notebook"
    assert rows[0]["status"] == "working"
    assert rows[0]["error_message"] is None
    assert rows[0]["queries"] == [{"query": "select:\n    id", "results": None}]
    assert rows[0]["notes"] == ["note"]


def test_create_notebook_without_queries_is_idle(monkeypatch: pytest.MonkeyPatch):
    rows = []
    fake_supabase = FakeSupabase(rows)
    monkeypatch.setattr(server, "supabase", fake_supabase)

    result = server.create_notebook(title = "Empty", queries = [], notes = [])

    assert result == "created notebook id=1"
    assert rows[0]["title"] == "Empty"
    assert rows[0]["status"] == "idle"
    assert rows[0]["queries"] == []
    assert rows[0]["notes"] == []


def test_create_notebook_rejects_mismatched_notes(monkeypatch: pytest.MonkeyPatch):
    rows = []
    fake_supabase = FakeSupabase(rows)
    monkeypatch.setattr(server, "supabase", fake_supabase)

    with pytest.raises(ValueError, match = "same length"):
        server.create_notebook(title = "Bad", queries = ["select:\n    id"], notes = [])


def test_update_notebook_requeues_existing_queries(monkeypatch: pytest.MonkeyPatch):
    rows = [make_notebook_row()]
    fake_supabase = FakeSupabase(rows)
    monkeypatch.setattr(server, "supabase", fake_supabase)

    result = server.update_notebook(1)

    assert result == "updated notebook id=1"
    assert rows[0]["status"] == "working"
    assert rows[0]["error_message"] is None
    assert rows[0]["queries"][0]["query"] == "select:\n    id"
    assert rows[0]["queries"][0]["results"] is None


def test_update_notebook_replaces_queries_and_notes(monkeypatch: pytest.MonkeyPatch):
    rows = [make_notebook_row()]
    fake_supabase = FakeSupabase(rows)
    monkeypatch.setattr(server, "supabase", fake_supabase)

    result = server.update_notebook(
        notebook_id = 1,
        title = " New title ",
        queries = ["select:\n    title"],
        notes = ["new note"]
    )

    assert result == "updated notebook id=1"
    assert rows[0]["title"] == "New title"
    assert rows[0]["status"] == "working"
    assert rows[0]["queries"] == [{"query": "select:\n    title", "results": None}]
    assert rows[0]["notes"] == ["new note"]


def test_update_notebook_rejects_queries_without_notes(monkeypatch: pytest.MonkeyPatch):
    rows = [make_notebook_row()]
    fake_supabase = FakeSupabase(rows)
    monkeypatch.setattr(server, "supabase", fake_supabase)

    with pytest.raises(ValueError, match = "notes must be provided"):
        server.update_notebook(notebook_id = 1, queries = ["select:\n    title"])


def test_update_notebook_rejects_mismatched_notes(monkeypatch: pytest.MonkeyPatch):
    rows = [make_notebook_row()]
    fake_supabase = FakeSupabase(rows)
    monkeypatch.setattr(server, "supabase", fake_supabase)

    with pytest.raises(ValueError, match = "same length"):
        server.update_notebook(notebook_id = 1, notes = ["first", "second"])


def test_delete_notebook_deletes_by_id(monkeypatch: pytest.MonkeyPatch):
    rows = [make_notebook_row()]
    fake_supabase = FakeSupabase(rows)
    monkeypatch.setattr(server, "supabase", fake_supabase)

    result = server.delete_notebook(1)

    assert result == "deleted notebook id=1"
    assert fake_supabase.notebooks.deleted_id == 1
    assert rows == []


def make_notebook_row() -> dict:
    return {
        "id": 1,
        "last_edited": "2026-06-26T00:00:00Z",
        "title": "Notebook",
        "queries": [
            {
                "query": "select:\n    id",
                "results": [{"path": "id", "values": [1], "skipped": 0}]
            }
        ],
        "notes": ["note"],
        "status": "idle",
        "error_message": "old error"
    }


def make_experiment_row(experiment_id: int) -> dict:
    statuses = ["queued", "running", "errored", "completed"]
    status_idx = experiment_id % len(statuses)

    return {
        "id": experiment_id,
        "last_edited": f"2026-06-26T00:00:{experiment_id:03d}Z",
        "title": f"Experiment {experiment_id}",
        "status": statuses[status_idx],
        "source": "cv_folds: 3",
        "experiment": None,
        "results": {"ignored": True}
    }
