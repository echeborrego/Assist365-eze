import logging
import uuid
from collections.abc import Iterable, Iterator
from datetime import datetime, timezone

from google.cloud import bigquery

from modules import extract, load
from modules.api_client import ApiClient
from modules.config import Settings

log = logging.getLogger(__name__)

SOURCES = ("catalogos", "siniestros", "polizas")
CATALOG_TABLES = {"productos": "CatalogoProducto", "agencias": "CatalogoAgencia", "tipo_cambio": "CatalogoTipoCambio"}


def new_run_id() -> str:
    return f"{datetime.now(timezone.utc):%Y%m%dT%H%M%SZ}-{uuid.uuid4().hex[:6]}"


def _parse_ts(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        ts = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    return ts if ts.tzinfo else ts.replace(tzinfo=timezone.utc)


def _track_max(pages: Iterable[tuple[int, list[dict]]], key: str, ceiling: datetime,
               state: dict) -> Iterator[tuple[int, list[dict]]]:
    # The source has future-dated changes; counting them would push the watermark past real new data
    for page, rows in pages:
        for row in rows:
            value = _parse_ts(row.get(key))
            if value and value <= ceiling and (state.get("max") is None or value > state["max"]):
                state["max"] = value
        yield page, rows


def run_source(settings: Settings, source: str, run_id: str | None = None, full_refresh: bool = False) -> dict:
    """Extracts one source into raw.* and logs the outcome to raw.ExtractRun. Callable from CLI or Airflow."""
    run_id = run_id or new_run_id()
    bq = bigquery.Client(project=settings.gcp_project, location=settings.bq_location)
    api = ApiClient(settings.api_base_url, settings.api_token)
    raw = f"{settings.gcp_project}.raw"
    runs_table = f"{raw}.ExtractRun"
    load.ensure_datasets(bq, ["raw"], settings.bq_location)

    run = {"RunId": run_id, "Source": source, "Status": "failed",
           "StartedAt": datetime.now(timezone.utc).isoformat(), "Pages": 0, "RowsLoaded": 0, "NonFiniteNulled": 0}
    progress, meta = {"received": 0}, {}
    try:
        if source == "polizas":
            # Incremental: resume from the last successful watermark; the API returns the whole page containing it
            since = None if full_refresh else load.last_watermark(bq, runs_table, "polizas")
            run["UpdatedSince"] = since
            state = {"max": _parse_ts(since)}
            pages = _track_max(extract.polizas(api, since), "updated_at", datetime.now(timezone.utc), state)
            run["Pages"], run["RowsLoaded"], run["NonFiniteNulled"] = load.load_pages(
                bq, f"{raw}.Poliza", pages, run_id, "WRITE_APPEND", partitioned=True, progress=progress)
            run["Watermark"] = f"{state['max'].astimezone(timezone.utc):%Y-%m-%dT%H:%M:%SZ}" if state["max"] else None
        elif source == "siniestros":
            # No incremental filter in the API: append a full daily snapshot, staging reads the latest one
            run["Pages"], run["RowsLoaded"], run["NonFiniteNulled"] = load.load_pages(
                bq, f"{raw}.Siniestro", extract.siniestros(api, meta), run_id, "WRITE_APPEND", partitioned=True,
                expected_range=lambda: (meta["first_total"], meta["last_total"]) if meta else None,
                tolerance=settings.row_count_tolerance, progress=progress)
        elif source == "catalogos":
            run["RowsExpected"] = 0
            for tipo in extract.CATALOGOS:
                rows, total = extract.catalogo(api, tipo)
                run["RowsExpected"] += total
                n_pages, n_rows, n_nulled = load.load_pages(
                    bq, f"{raw}.{CATALOG_TABLES[tipo]}", [(0, rows)], run_id, "WRITE_TRUNCATE", partitioned=False,
                    expected_range=lambda total=total: (total, total), tolerance=settings.row_count_tolerance,
                    progress=progress)
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
        # Filled even when the run fails, so the audit row shows "received X, the API said Y"
        run["RowsReceived"] = progress["received"]
        if meta:
            run["RowsExpected"] = meta["last_total"]
        try:
            load.log_run(bq, runs_table, run)
        except Exception:
            # Never let the audit write mask the extraction's own error
            log.exception("Could not write run log for %s %s", run_id, source)
        log.info("Run %s %s: %s", run_id, source, {k: v for k, v in run.items() if k != "RunId"})
    return run
