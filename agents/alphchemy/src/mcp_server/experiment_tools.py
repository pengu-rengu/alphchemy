from __future__ import annotations
import time
from typing import Any
from supabase import Client
from analysis.format_analysis import format_value
from analysis.path import resolve_path

VALIDATION_POLL_SEC = 1.0
VALIDATION_TIMEOUT_SEC = 60.0

def fetch_experiment_row(supabase: Client, experiment_id: int, columns: str) -> dict[str, Any]:
    table = supabase.table("experiments")
    selected = table.select(columns)
    rows = selected.eq("id", experiment_id).execute().data

    if len(rows) == 0:
        raise ValueError(f"experiment id={experiment_id} not found")

    return rows[0]

def list_experiments_tool(supabase: Client, offset: int) -> str:
    if offset < 0:
        raise ValueError("offset must be >= 0")

    table = supabase.table("experiments")
    selected = table.select("id, last_edited, title, status")
    ordered = selected.order("last_edited", desc = True)
    rows = ordered.range(offset, offset + 49).execute().data

    lines = [f"[EXPERIMENTS] {len(rows)} experiment(s)"]
    for row in rows:
        lines.append(f"id={row['id']} title={row['title']} status={row['status']}")

    return "\n".join(lines)

def queue_experiment_tool(supabase: Client, title: str, source: str) -> str:
    table = supabase.table("experiments")
    return f"queued id={table.insert({
        "title": title,
        "source": source,
        "status": "queued"
    }).execute().data[0]['id']}"

def validate_experiment_tool(supabase: Client, source: str) -> str:
    table = supabase.table("validation_jobs")
    validation_id = table.insert({
        "source": source,
        "status": "working"
    }).execute().data[0]["id"]

    waited = 0.0
    while waited < VALIDATION_TIMEOUT_SEC:
        time.sleep(VALIDATION_POLL_SEC)
        waited += VALIDATION_POLL_SEC
        table = supabase.table("validation_jobs")
        selected = table.select("status, result_message")
        row = selected.eq("id", validation_id).execute().data[0]
        status = row["status"]

        if status == "completed_valid":
            return f"valid validation_id={validation_id}"
        if status == "completed_invalid":
            return f"invalid: {row['result_message']}"
        if status == "errored":
            raise RuntimeError(f"validation job errored: {row['result_message']}")

    raise TimeoutError(f"validation job id={validation_id} did not complete within {VALIDATION_TIMEOUT_SEC}s")

def queue_validated_tool(supabase: Client, title: str, validation_id: int) -> str:
    table = supabase.table("validation_jobs")
    selected = table.select("source, status, result_message")
    rows = selected.eq("id", validation_id).execute().data

    if len(rows) == 0:
        raise ValueError(f"validation job id={validation_id} not found")

    validation_job = rows[0]
    status = validation_job["status"]
    if status != "completed_valid":
        raise ValueError(f"validation job id={validation_id} is {status}: {validation_job["result_message"]}")

    table = supabase.table("experiments")
    return f"queued id={table.insert({
        "title": title,
        "source": validation_job["source"],
        "status": "queued"
    }).execute().data[0]['id']}"


def status_tool(supabase: Client, experiment_id: int) -> str:
    return f"status for experiment id={experiment_id}: {fetch_experiment_row(supabase, experiment_id, "id, status")['status']}"

def experiment_source_tool(supabase: Client, experiment_id: int) -> str:
    return fetch_experiment_row(supabase, experiment_id, "source")["source"]

def experiment_summary_tool(supabase: Client, experiment_id: int) -> str:
    row = fetch_experiment_row(supabase, experiment_id, "id, title, status, experiment")
    experiment = row["experiment"]
    lines = [
        f"id: {row['id']}",
        f"title: {row['title']}",
        f"status: {row['status']}"
    ]

    lines.append("experiment:")
    for key in ["symbol", "cv_folds", "fold_size", "val_size", "test_size", "start_timestamp", "end_timestamp"]:
        lines.append(f"{key}: {experiment[key]}")

    strategy = experiment["strategy"]
    lines.append(f"strategy_type: {strategy["base_net"]['type']}")
    lines.append(f"feature_count: {len(strategy["feats"])}")

    return "\n".join(lines)

def results_summary_tool(supabase: Client, experiment_id: int) -> str:
    row = fetch_experiment_row(supabase, experiment_id, "id, title, status, results")
    lines = [
        f"id: {row['id']}",
        f"title: {row['title']}",
        f"status: {row['status']}"
    ]
    results = row["results"]

    if results is None:
        lines.append("results: null")
        return "\n".join(lines)

    if isinstance(results, dict):
        if "is_internal" in results:
            lines.append(f"error: internal error")
        else:
            lines.append(f"error: {results['error']}")

        return "\n".join(lines)

    lines.append(f"# of folds: {len(results)}")
    for fold_idx, fold in enumerate(results):

        lines.append(f"[FOLD {fold_idx + 1}]")
        lines.append(f"train window: {fold['train_start_timestamp']} -> {fold['train_end_timestamp']}")
        lines.append(f"val window: {fold['val_start_timestamp']} -> {fold['val_end_timestamp']}")
        lines.append(f"test window: {fold['test_start_timestamp']} -> {fold['test_end_timestamp']}")

        for split in ["train", "val", "test"]:
            split_results = fold[f"{split}_results"]
            lines.append(f"{split} is_invalid: {split_results['is_invalid']}")

            metrics = split_results["metrics"]
            for metric in sorted(metrics.keys()):
                lines.append(f"{split} metric.{metric}: {metrics[metric]}")

    return "\n".join(lines)

def experiment_paths_tool(supabase: Client, experiment_id: int, select: list[str]) -> str:
    row = fetch_experiment_row(supabase, experiment_id, "id, last_edited, title, status, experiment, results")
    lines = [f"[QUERY] {len(select)} path(s)"]

    for path in select:
        lines.append(f"[RESULTS] {path}")

        try:
            value = resolve_path(row, path)
            formatted = format_value(value)
            lines.append(f"{formatted} ({experiment_id})")
        except Exception:
            lines.append("skipped")

    return "\n".join(lines) + "\n"


def delete_experiment_tool(supabase: Client, experiment_id: int) -> str:
    table = supabase.table("experiments")
    table.delete().eq("id", experiment_id).execute()
    return f"deleted experiment id={experiment_id}"
