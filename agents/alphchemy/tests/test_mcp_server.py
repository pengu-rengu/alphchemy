from __future__ import annotations

import anyio
import pytest
from mcp.shared.memory import create_connected_server_and_client_session
from mcp_server import experiment_tools, server


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
            row["last_updated"] = "2026-06-26T00:00:00Z"
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
    def __init__(self, terminal_status: str, result_message: str | None, source: str | None = None):
        self.terminal_status = terminal_status
        self.result_message = result_message
        self.source = source
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

        row = {
            "source": self.source,
            "status": self.terminal_status,
            "result_message": self.result_message
        }
        return FakeResponse([row])


class FakePinescriptTable:
    def __init__(self, terminal_status: str, pinescript: str | None, error_message: str | None = None):
        self.terminal_status = terminal_status
        self.pinescript = pinescript
        self.error_message = error_message
        self.operation: str | None = None
        self.inserted_values: dict | None = None

    def insert(self, values: dict) -> FakePinescriptTable:
        self.operation = "insert"
        self.inserted_values = values
        return self

    def select(self, columns: str) -> FakePinescriptTable:
        self.operation = "select"
        return self

    def eq(self, column: str, value: object) -> FakePinescriptTable:
        return self

    def execute(self) -> FakeResponse:
        if self.operation == "insert":
            return FakeResponse([{"id": 1}])

        row = {
            "status": self.terminal_status,
            "pinescript": self.pinescript,
            "error_message": self.error_message
        }
        return FakeResponse([row])


class FakeSupabase:
    def __init__(self, rows: list[dict], experiment_rows: list[dict] | None = None, validation_table: FakeValidationTable | None = None, pinescript_table: FakePinescriptTable | None = None):
        self.notebooks = FakeTable(rows)
        experiments = [] if experiment_rows is None else experiment_rows
        self.experiments = FakeTable(experiments)
        self.validation_table = validation_table
        self.pinescript_table = pinescript_table

    def table(self, name: str) -> FakeTable | FakeValidationTable | FakePinescriptTable:
        if name == "notebooks":
            return self.notebooks

        if name == "experiments":
            return self.experiments

        if name == "validation_jobs":
            if self.validation_table is None:
                raise ValueError("no validation table configured")

            return self.validation_table

        if name == "convert_jobs":
            if self.pinescript_table is None:
                raise ValueError("no pinescript table configured")

            return self.pinescript_table

        raise ValueError(f"unexpected table: {name}")


def test_mcp_server_tools() -> None:
    async def run() -> None:
        async with create_connected_server_and_client_session(server.mcp) as session:
            await session.initialize()

            tools = await session.list_tools()
            tool_names = {tool.name for tool in tools.tools}
            assert "overview" in tool_names
            assert "documentation" in tool_names
            assert "queue_experiment" in tool_names
            assert "validate_experiment" in tool_names
            assert "queue_validated" in tool_names
            assert "list_experiments" in tool_names
            assert "query_experiments" in tool_names
            assert "status" in tool_names
            assert "experiment_source" in tool_names
            assert "experiment_summary" in tool_names
            assert "results_summary" in tool_names
            assert "experiment_paths" in tool_names
            assert "convert" in tool_names
            assert "delete_experiment" in tool_names
            assert "list_notebooks" in tool_names
            assert "view_notebook" in tool_names
            assert "create_notebook" in tool_names
            assert "update_notebook" in tool_names
            assert "delete_notebook" in tool_names
            assert not any(tool_name.startswith("get_") for tool_name in tool_names)

    anyio.run(run)


def test_overview_lists_local_docs_directory() -> None:
    result = server.overview()

    assert "# Alphchemy" in result
    assert "`experiment/backtest`" in result
    assert "`source/source_format`" in result
    assert "`notebooks`" in result
    assert "`experiment/backtest.md`" not in result
    assert "# Experiment source format" not in result
    assert "# Notebooks" not in result


def test_documentation_reads_local_doc_without_extension() -> None:
    result = server.documentation("experiment/backtest")

    assert "# Backtest" in result


def test_documentation_does_not_accept_markdown_extension() -> None:
    with pytest.raises(FileNotFoundError):
        server.documentation("experiment/backtest.md")


def test_queue_experiment_inserts_source_not_experiment(monkeypatch: pytest.MonkeyPatch):
    experiment_rows = []
    fake_supabase = FakeSupabase([], experiment_rows)
    monkeypatch.setattr(server, "supabase", fake_supabase)

    result = server.queue_experiment(title = "Demo", source = "cv_folds: 3")

    assert result == "queued id=1"
    assert experiment_rows[0]["source"] == "cv_folds: 3"
    assert experiment_rows[0]["status"] == "queued"
    assert "experiment" not in experiment_rows[0]


def test_validate_experiment_returns_valid(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setattr(experiment_tools.time, "sleep", lambda seconds: None)
    validation_table = FakeValidationTable("completed_valid", "Source is valid")
    fake_supabase = FakeSupabase([], validation_table = validation_table)
    monkeypatch.setattr(server, "supabase", fake_supabase)

    result = server.validate_experiment(source = "cv_folds: 3")

    assert result == "valid validation_id=1"
    assert validation_table.inserted_values["source"] == "cv_folds: 3"
    assert validation_table.inserted_values["status"] == "working"


def test_validate_experiment_returns_invalid(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setattr(experiment_tools.time, "sleep", lambda seconds: None)
    validation_table = FakeValidationTable("completed_invalid", "val_size must be > 0.0")
    fake_supabase = FakeSupabase([], validation_table = validation_table)
    monkeypatch.setattr(server, "supabase", fake_supabase)

    result = server.validate_experiment(source = "val_size: 0")

    assert result == "invalid: val_size must be > 0.0"


def test_queue_validated_queues_validated_source(monkeypatch: pytest.MonkeyPatch) -> None:
    experiment_rows = []
    validation_table = FakeValidationTable("completed_valid", None, source = "cv_folds: 3")
    fake_supabase = FakeSupabase([], experiment_rows, validation_table)
    monkeypatch.setattr(server, "supabase", fake_supabase)

    result = server.queue_validated(title = "Demo", validation_id = 1)

    assert result == "queued id=1"
    assert experiment_rows[0]["source"] == "cv_folds: 3"
    assert experiment_rows[0]["status"] == "queued"


def test_queue_validated_rejects_invalid_job(monkeypatch: pytest.MonkeyPatch) -> None:
    validation_table = FakeValidationTable("completed_invalid", "val_size must be > 0.0", source = "val_size: 0")
    fake_supabase = FakeSupabase([], validation_table = validation_table)
    monkeypatch.setattr(server, "supabase", fake_supabase)

    with pytest.raises(ValueError, match = "completed_invalid"):
        server.queue_validated(title = "Demo", validation_id = 1)


def test_convert_returns_pinescript(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(experiment_tools.time, "sleep", lambda seconds: None)
    pinescript_table = FakePinescriptTable("completed", "//@version=6")
    fake_supabase = FakeSupabase([], [make_experiment_row(3)], pinescript_table = pinescript_table)
    monkeypatch.setattr(server, "supabase", fake_supabase)

    result = server.convert(experiment_id = 3, fold_idx = 0, platform = "pinescript")

    assert result == "//@version=6"
    assert pinescript_table.inserted_values["experiment_id"] == 3
    assert pinescript_table.inserted_values["fold_idx"] == 0
    assert pinescript_table.inserted_values["status"] == "working"


def test_convert_rejects_unsupported_platform(monkeypatch: pytest.MonkeyPatch) -> None:
    fake_supabase = FakeSupabase([], [make_experiment_row(3)])
    monkeypatch.setattr(server, "supabase", fake_supabase)

    with pytest.raises(ValueError, match = "unsupported platform"):
        server.convert(experiment_id = 3, fold_idx = 0, platform = "mql")


def test_convert_rejects_uncompleted_experiment(monkeypatch: pytest.MonkeyPatch) -> None:
    fake_supabase = FakeSupabase([], [make_experiment_row(1)])
    monkeypatch.setattr(server, "supabase", fake_supabase)

    with pytest.raises(ValueError, match = "not completed"):
        server.convert(experiment_id = 1, fold_idx = 0, platform = "pinescript")


def test_convert_raises_on_errored_job(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(experiment_tools.time, "sleep", lambda seconds: None)
    pinescript_table = FakePinescriptTable("errored", None, "codegen failed")
    fake_supabase = FakeSupabase([], [make_experiment_row(3)], pinescript_table = pinescript_table)
    monkeypatch.setattr(server, "supabase", fake_supabase)

    with pytest.raises(RuntimeError, match = "codegen failed"):
        server.convert(experiment_id = 3, fold_idx = 0, platform = "pinescript")


def test_list_experiments_returns_50_from_offset(monkeypatch: pytest.MonkeyPatch):
    experiment_rows = [make_experiment_row(experiment_id) for experiment_id in range(1, 241)]
    fake_supabase = FakeSupabase([], experiment_rows)
    monkeypatch.setattr(server, "supabase", fake_supabase)

    result = server.list_experiments(offset = 10)

    sorted_rows = sorted(experiment_rows, key = lambda row: row["last_updated"], reverse = True)
    expected_rows = sorted_rows[10:60]
    expected_ids = [row["id"] for row in expected_rows]
    result_lines = result.splitlines()[1:]
    result_ids = []
    for line in result_lines:
        id_column = line.split(" ")[0]
        id_text = id_column.removeprefix("id=")
        result_ids.append(int(id_text))

    assert result.startswith("[EXPERIMENTS] 50 experiment(s)")
    assert result_ids == expected_ids
    assert "title: " not in result


def test_list_experiments_rejects_negative_offset():
    with pytest.raises(ValueError, match = "offset must be >= 0"):
        server.list_experiments(offset = -1)


def test_experiment_source_returns_only_source(monkeypatch: pytest.MonkeyPatch) -> None:
    experiment_rows = [make_experiment_row(1)]
    fake_supabase = FakeSupabase([], experiment_rows)
    monkeypatch.setattr(server, "supabase", fake_supabase)

    result = server.experiment_source(1)

    assert result == "cv_folds: 3"


def test_experiment_summary_excludes_source(monkeypatch: pytest.MonkeyPatch) -> None:
    experiment_rows = [make_experiment_row(1)]
    fake_supabase = FakeSupabase([], experiment_rows)
    monkeypatch.setattr(server, "supabase", fake_supabase)

    result = server.experiment_summary(1)

    assert "source" not in result
    assert "results" not in result
    assert "strategy_type: logic" in result
    assert "feature_count: 2" in result


def test_results_summary_omits_bulky_fields(monkeypatch: pytest.MonkeyPatch) -> None:
    experiment_rows = [make_experiment_row(1)]
    fake_supabase = FakeSupabase([], experiment_rows)
    monkeypatch.setattr(server, "supabase", fake_supabase)

    result = server.results_summary(1)

    assert "# of folds: 2" in result
    assert "start_timestamp" not in result
    assert "end_timestamp" not in result
    assert "test metric.excess_sharpe: 1.0" in result
    assert "test # of bars backtested: 3" in result
    assert "equity_curve" not in result
    assert "best_val_seq" not in result
    assert "best_val_net" not in result


def test_experiment_paths_formats_values_and_skips(monkeypatch: pytest.MonkeyPatch) -> None:
    experiment_rows = [make_experiment_row(1)]
    fake_supabase = FakeSupabase([], experiment_rows)
    monkeypatch.setattr(server, "supabase", fake_supabase)

    result = server.experiment_paths(
        experiment_id = 1,
        select = [
            "title",
            "experiment.strategy.base_net.type",
            "results.mean:test_results.metrics.excess_sharpe",
            "results.mean:test_results.metrics.missing"
        ]
    )

    assert "[QUERY] 4 path(s)" in result
    assert "[RESULTS] title" in result
    assert "Experiment 1 (1)" in result
    assert "[RESULTS] experiment.strategy.base_net.type" in result
    assert "logic (1)" in result
    assert "[RESULTS] results.mean:test_results.metrics.excess_sharpe" in result
    assert "2.0 (1)" in result
    assert "[RESULTS] results.mean:test_results.metrics.missing" in result
    assert "skipped" in result
    assert "reason: Missing aggregate values" not in result


def test_experiment_paths_rejects_source(monkeypatch: pytest.MonkeyPatch) -> None:
    experiment_rows = [make_experiment_row(1)]
    fake_supabase = FakeSupabase([], experiment_rows)
    monkeypatch.setattr(server, "supabase", fake_supabase)

    result = server.experiment_paths(experiment_id = 1, select = ["source"])

    assert "cv_folds: 3" not in result
    assert "[RESULTS] source" in result
    assert "skipped" in result
    assert "use experiment_source" not in result


def test_delete_experiment_deletes_by_id(monkeypatch: pytest.MonkeyPatch):
    experiment_rows = [make_experiment_row(1)]
    fake_supabase = FakeSupabase([], experiment_rows)
    monkeypatch.setattr(server, "supabase", fake_supabase)

    result = server.delete_experiment(1)

    assert result == "deleted experiment id=1"
    assert fake_supabase.experiments.deleted_id == 1
    assert experiment_rows == []


def test_list_notebooks_returns_text(monkeypatch: pytest.MonkeyPatch) -> None:
    rows = [make_notebook_row()]
    fake_supabase = FakeSupabase(rows)
    monkeypatch.setattr(server, "supabase", fake_supabase)

    result = server.list_notebooks()

    assert result.startswith("[NOTEBOOKS] 1 notebook(s)")
    assert "id=1 title=Notebook" in result
    assert "status=idle" not in result


def test_view_notebook_returns_text(monkeypatch: pytest.MonkeyPatch) -> None:
    rows = [make_notebook_row()]
    fake_supabase = FakeSupabase(rows)
    monkeypatch.setattr(server, "supabase", fake_supabase)

    result = server.view_notebook(1)

    assert "title: Notebook" in result
    assert "tile_count: 1" in result
    assert "[TILE 0]" in result
    assert "select:\n    id" in result
    assert "path: id" in result
    assert "values: 1" in result
    assert "skipped: 0" in result


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
        "last_updated": "2026-06-26T00:00:00Z",
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
        "last_updated": f"2026-06-26T00:00:{experiment_id:03d}Z",
        "title": f"Experiment {experiment_id}",
        "status": statuses[status_idx],
        "source": "cv_folds: 3",
        "experiment": {
            "symbol": "BTC_USDT",
            "cv_folds": 2,
            "fold_size": 0.7,
            "val_size": 0.2,
            "test_size": 0.2,
            "start_timestamp": "2024-01-01T00:00:00Z",
            "end_timestamp": "2024-07-01T00:00:00Z",
            "strategy": {
                "base_net": {
                    "type": "logic"
                },
                "feats": {
                    "close_log_ret": {},
                    "rsi_14": {}
                }
            }
        },
        "results": [
            make_fold_result(1.0),
            make_fold_result(3.0)
        ]
    }


def make_fold_result(excess_sharpe: float) -> dict:
    return {
        "train_start_timestamp": "2024-01-01T00:00:00Z",
        "train_end_timestamp": "2024-01-20T00:00:00Z",
        "val_start_timestamp": "2024-01-21T00:00:00Z",
        "val_end_timestamp": "2024-01-25T00:00:00Z",
        "test_start_timestamp": "2024-01-26T00:00:00Z",
        "test_end_timestamp": "2024-02-01T00:00:00Z",
        "opt_results": {
            "iters": 4,
            "best_train_seq": ["large train seq"],
            "best_train_net": {"nodes": [1, 2, 3]},
            "best_val_seq": ["large val seq"],
            "best_val_net": {"nodes": [4, 5, 6]},
            "train_improvements": [{"iter": 1, "score": 0.1}],
            "val_improvements": [{"iter": 1, "score": 0.2}]
        },
        "train_results": make_backtest_result(0.5),
        "val_results": make_backtest_result(0.75),
        "test_results": make_backtest_result(excess_sharpe)
    }


def make_backtest_result(excess_sharpe: float) -> dict:
    return {
        "is_invalid": False,
        "n_bars": 3,
        "metrics": {
            "excess_sharpe": excess_sharpe,
            "sharpe": excess_sharpe + 1.0
        },
        "equity_curve": [100.0, 101.0, 102.0]
    }
