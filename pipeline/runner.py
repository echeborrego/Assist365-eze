import logging
import uuid
from collections.abc import Iterable, Iterator
from datetime import datetime, timezone

from google.cloud import bigquery

from pipeline import extract, load
from pipeline.api_client import ApiClient
from pipeline.config import Settings

log = logging.getLogger(__name__)

SOURCES = ("catalogos", "siniestros", "polizas")


def new_run_id() -> str:
    return f"{datetime.now(timezone.utc):%Y%m%dT%H%M%SZ}-{uuid.uuid4().hex[:6]}"


def _track_max(pages: Iterable[tuple[int, list[dict]]], key: str, ceiling: str,
               state: dict) -> Iterator[tuple[int, list[dict]]]:
    # The source has future-dated changes; counting them would push the watermark past real new data
    for page, rows in pages:
        for row in rows:
            value = row.get(key)
            if value and value <= ceiling and (state.get("max") is None or value > state["max"]):
                state["max"] = value
        yield page, rows


def run_source(settings: Settings, source: str, run_id: str | None = None, full_refresh: bool = False) -> dict:
    """Extracts one source into raw.* and logs the outcome to raw.extract_runs. Callable from CLI or Airflow."""
    run_id = run_id or new_run_id()
    bq = bigquery.Client(project=settings.gcp_project, location=settings.bq_location)
    api = ApiClient(settings.api_base_url, settings.api_token)
    raw = f"{settings.gcp_project}.{settings.raw_dataset}"
    runs_table = f"{raw}.extract_runs"
    load.ensure_datasets(bq, [settings.raw_dataset], settings.bq_location)

    run = {"RunId": run_id, "Source": source, "Status": "failed",
           "StartedAt": datetime.now(timezone.utc).isoformat(), "Pages": 0, "RowsLoaded": 0, "NonFiniteNulled": 0}
    try:
        if source == "polizas":
            # Incremental: resume from the last successful watermark; the API returns the whole page containing it
            since = None if full_refresh else load.last_watermark(bq, runs_table, "polizas")
            run["UpdatedSince"] = since
            state = {"max": since}
            ceiling = f"{datetime.now(timezone.utc):%Y-%m-%dT%H:%M:%SZ}"
            pages = _track_max(extract.polizas(api, since), "updated_at", ceiling, state)
            run["Pages"], run["RowsLoaded"], run["NonFiniteNulled"] = load.load_pages(
                bq, f"{raw}.polizas", pages, run_id, "WRITE_APPEND", partitioned=True)
            run["Watermark"] = state["max"]
        elif source == "siniestros":
            # No incremental filter in the API: append a full daily snapshot, staging reads the latest one
            run["Pages"], run["RowsLoaded"], run["NonFiniteNulled"] = load.load_pages(
                bq, f"{raw}.siniestros", extract.siniestros(api), run_id, "WRITE_APPEND", partitioned=True)
        elif source == "catalogos":
            for tipo in extract.CATALOGOS:
                pages = [(0, extract.catalogo(api, tipo))]
                n_pages, n_rows, n_nulled = load.load_pages(
                    bq, f"{raw}.catalogo_{tipo}", pages, run_id, "WRITE_TRUNCATE", partitioned=False)
                run["Pages"] += n_pages
                run["RowsLoaded"] += n_rows
                run["NonFiniteNulled"] += n_nulled
        else:
            raise ValueError(f"Unknown source {source!r}, expected one of {SOURCES}")
        run["Status"] = "success"
    except Exception as e:
        run["Error"] = f"{type(e).__name__}: {e}"[:1000]
        raise
    finally:
        run["FinishedAt"] = datetime.now(timezone.utc).isoformat()
        run["ApiCalls"], run["ApiRetries"] = api.calls, api.retries
        load.log_run(bq, runs_table, run)
        log.info("Run %s %s: %s", run_id, source, {k: v for k, v in run.items() if k != "RunId"})
    return run
