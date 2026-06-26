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

    def select(self, columns: str | None = None) -> FakeTable:
        self.operation = "select"
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

    def eq(self, column: str, value: int) -> FakeTable:
        self.notebook_id = value
        return self

    def limit(self, count: int) -> FakeTable:
        return self

    def order(self, column: str, desc: bool = False) -> FakeTable:
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

        row = self.match_row()
        return FakeResponse([dict(row)])

    def match_row(self) -> dict:
        for row in self.rows:
            if row["id"] == self.notebook_id:
                return row

        raise ValueError(f"missing notebook id={self.notebook_id}")


class FakeSupabase:
    def __init__(self, rows: list[dict]):
        self.notebooks = FakeTable(rows)

    def table(self, name: str) -> FakeTable:
        if name != "notebooks":
            raise ValueError(f"unexpected table: {name}")

        return self.notebooks


def test_mcp_server_tools():
    async def run():
        async with create_connected_server_and_client_session(server.mcp) as session:
            await session.initialize()

            tools = await session.list_tools()
            tool_names = [tool.name for tool in tools.tools]
            assert "get_documentation" in tool_names
            assert "queue_experiment" in tool_names
            assert "query_experiments" in tool_names
            assert "get_experiment" in tool_names
            assert "list_notebooks" in tool_names
            assert "view_notebook" in tool_names
            assert "create_notebook" in tool_names
            assert "update_notebook" in tool_names
            assert "delete_notebook" in tool_names

            doc_result = await session.call_tool("get_documentation", {})
            doc_text = doc_result.content[0].text
            assert "# Alphchemy" in doc_text
            assert "Experiment JSON schema" in doc_text
            assert "# Notebook Description" in doc_text
            assert "\"queries\"" in doc_text
            assert "\"notes\"" in doc_text

    anyio.run(run)


def test_create_notebook_with_queries_queues_work(monkeypatch: pytest.MonkeyPatch):
    rows = []
    fake_supabase = FakeSupabase(rows)
    monkeypatch.setattr(server, "supabase", fake_supabase)

    result = server.create_notebook(
        title = " New notebook ",
        queries = ["select:\n    id"],
        notes = ["note"]
    )

    assert result["id"] == 1
    assert result["title"] == "New notebook"
    assert result["status"] == "working"
    assert result["error_message"] is None
    assert result["queries"] == [{"query": "select:\n    id", "results": None}]
    assert result["notes"] == ["note"]


def test_create_notebook_without_queries_is_idle(monkeypatch: pytest.MonkeyPatch):
    rows = []
    fake_supabase = FakeSupabase(rows)
    monkeypatch.setattr(server, "supabase", fake_supabase)

    result = server.create_notebook(title = "Empty", queries = [], notes = [])

    assert result["title"] == "Empty"
    assert result["status"] == "idle"
    assert result["queries"] == []
    assert result["notes"] == []


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

    assert result["status"] == "working"
    assert result["error_message"] is None
    assert result["queries"][0]["query"] == "select:\n    id"
    assert result["queries"][0]["results"] is None


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

    assert result["title"] == "New title"
    assert result["status"] == "working"
    assert result["queries"] == [{"query": "select:\n    title", "results": None}]
    assert result["notes"] == ["new note"]


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
