from typing import Any

from analysis import notebook_worker


class FakeQuery:
    user_ids: list[str] = []

    def __init__(self, values: dict[str, Any]):
        self.values = values

    @classmethod
    def model_validate(cls, values: dict[str, Any]) -> "FakeQuery":
        return cls(values)

    def run(self, supabase: object, user_id: str) -> None:
        self.user_ids.append(user_id)

    def model_dump(self) -> dict[str, Any]:
        return self.values


def test_run_queries_passes_required_user_id(monkeypatch) -> None:
    FakeQuery.user_ids = []
    monkeypatch.setattr(notebook_worker, "Query", FakeQuery)

    queries = [{"query": "select:\n    title", "results": None}]
    results = notebook_worker.run_queries(queries, object(), "owner")

    assert FakeQuery.user_ids == ["owner"]
    assert results == [{"query": "select:\n    title"}]


def test_process_working_notebook_uses_row_owner(monkeypatch) -> None:
    row = {
        "id": 7,
        "queries": [{"query": "select:\n    title", "results": None}],
        "user_id": "owner"
    }
    received_user_ids: list[str] = []

    monkeypatch.setattr(notebook_worker, "fetch_next_working_notebook", lambda supabase: row)
    monkeypatch.setattr(
        notebook_worker,
        "run_queries",
        lambda queries, supabase, user_id: received_user_ids.append(user_id) or queries
    )
    monkeypatch.setattr(notebook_worker, "write_idle_notebook", lambda supabase, notebook_id, queries: None)

    handled = notebook_worker.process_working_notebook(object())

    assert handled
    assert received_user_ids == ["owner"]
