from typing import Any

import main as worker_main


class FakeResponse:

    def __init__(self, data: list[dict[str, Any]]) -> None:
        self.data = data


class FakeTable:

    def __init__(self, rows: list[dict[str, Any]]) -> None:
        self.rows = rows
        self.filters: list[dict[str, Any]] = []
        self.order_column = ""
        self.limit_count = 0
        self.selected_columns = ""
        self.pending_update: dict[str, Any] | None = None
        self.updates: list[dict[str, Any]] = []

    def select(self, columns: str) -> "FakeTable":
        self.selected_columns = columns
        return self

    def eq(self, column: str, value: Any) -> "FakeTable":
        self.filters.append({
            "column": column,
            "value": value
        })
        return self

    def order(self, column: str) -> "FakeTable":
        self.order_column = column
        return self

    def limit(self, count: int) -> "FakeTable":
        self.limit_count = count
        return self

    def update(self, payload: dict[str, Any]) -> "FakeTable":
        self.pending_update = payload
        return self

    def execute(self) -> FakeResponse:
        if self.pending_update is not None:
            self.updates.append(self.pending_update)
            self.pending_update = None
            return FakeResponse([])

        return FakeResponse(self.rows)


class FakeSupabase:

    def __init__(self, rows: list[dict[str, Any]]) -> None:
        self.table_name = ""
        self.table_query = FakeTable(rows)

    def table(self, name: str) -> FakeTable:
        self.table_name = name
        return self.table_query


class FakeAgent:
    id: str = "Main"


class FakeAgentSystem:
    last_prompt: str | None = None

    def __init__(self, agents: list[FakeAgent] | None = None) -> None:
        self.agents = agents or [FakeAgent()]

    @classmethod
    def model_validate(cls, schema: dict[str, Any]) -> "FakeAgentSystem":
        return cls()

    def build_graph(self, open_router: Any, supabase: Any) -> None:
        pass

    def run(
        self,
        start_state: dict[str, Any] | None,
        user_prompt: str,
        supabase: Any,
        row_id: int | None = None
    ) -> dict[str, Any]:
        FakeAgentSystem.last_prompt = user_prompt
        return {
            "proposal_state": {
                "state": "submission",
                "type": "report",
                "submission": {
                    "report": "done"
                }
            }
        }


class FailingAgentSystem(FakeAgentSystem):

    def run(
        self,
        start_state: dict[str, Any] | None,
        user_prompt: str,
        supabase: Any,
        row_id: int | None = None
    ) -> dict[str, Any]:
        raise RuntimeError("boom")


class FailingCreatedAgentSystem(FakeAgentSystem):

    @classmethod
    def model_validate(cls, schema: dict[str, Any]) -> "FakeAgentSystem":
        raise RuntimeError("bad schema")


def working_row(user_prompt: str | None) -> dict[str, Any]:
    return {
        "id": 7,
        "schema": {},
        "state": {},
        "user_prompt": user_prompt,
        "submissions": []
    }


def test_fetch_next_working_prompt_selects_working_status() -> None:
    supabase = FakeSupabase([working_row("go")])

    row = worker_main.fetch_next_working_prompt(supabase)

    assert row is not None
    assert supabase.table_name == "agent_systems"
    assert supabase.table_query.selected_columns == "*"
    assert supabase.table_query.filters == [
        {
            "column": "status",
            "value": "working"
        }
    ]
    assert supabase.table_query.order_column == "last_edited"
    assert supabase.table_query.limit_count == 1


def test_process_working_prompt_uses_empty_prompt_for_null(monkeypatch: Any) -> None:
    supabase = FakeSupabase([working_row(None)])
    monkeypatch.setattr(worker_main, "AgentSystem", FakeAgentSystem)

    handled = worker_main.process_working_prompt(supabase, object())

    assert handled
    assert FakeAgentSystem.last_prompt == ""
    assert {"submissions": [{"type": "report", "submission": {"report": "done"}}]} in supabase.table_query.updates
    assert {
        "state": {
            "proposal_state": {
                "state": "submission",
                "type": "report",
                "submission": {
                    "report": "done"
                }
            }
        },
        "status": "idle"
    } in supabase.table_query.updates


def test_process_working_prompt_sets_errored_on_run_error(monkeypatch: Any) -> None:
    supabase = FakeSupabase([working_row("go")])
    monkeypatch.setattr(worker_main, "AgentSystem", FailingAgentSystem)

    handled = worker_main.process_working_prompt(supabase, object())

    assert handled
    assert {"status": "errored"} in supabase.table_query.updates


def test_process_created_sets_errored_on_init_error(monkeypatch: Any) -> None:
    row = {
        "id": 9,
        "schema": {}
    }
    supabase = FakeSupabase([row])
    monkeypatch.setattr(worker_main, "AgentSystem", FailingCreatedAgentSystem)

    handled = worker_main.process_created(supabase)

    assert handled
    assert {"status": "errored"} in supabase.table_query.updates
