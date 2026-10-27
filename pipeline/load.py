import gzip
import json
import logging
import math
import tempfile
from collections.abc import Iterable
from datetime import datetime, timezone

from google.api_core.exceptions import NotFound
from google.cloud import bigquery

log = logging.getLogger(__name__)

RAW_SCHEMA = [
    bigquery.SchemaField("Payload", "JSON", mode="REQUIRED"),
    bigquery.SchemaField("RunId", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("ExtractedAt", "TIMESTAMP", mode="REQUIRED"),
    bigquery.SchemaField("Page", "INTEGER"),
]

RUNS_SCHEMA = [
    bigquery.SchemaField("RunId", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("Source", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("Status", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("StartedAt", "TIMESTAMP"),
    bigquery.SchemaField("FinishedAt", "TIMESTAMP"),
    bigquery.SchemaField("Pages", "INTEGER"),
    bigquery.SchemaField("RowsLoaded", "INTEGER"),
    bigquery.SchemaField("ApiCalls", "INTEGER"),
    bigquery.SchemaField("ApiRetries", "INTEGER"),
    bigquery.SchemaField("UpdatedSince", "STRING"),
    bigquery.SchemaField("Watermark", "STRING"),
    bigquery.SchemaField("NonFiniteNulled", "INTEGER"),
    bigquery.SchemaField("Error", "STRING"),
]


def ensure_datasets(bq: bigquery.Client, names: Iterable[str], location: str) -> None:
    for name in names:
        ds = bigquery.Dataset(f"{bq.project}.{name}")
        ds.location = location
        bq.create_dataset(ds, exists_ok=True)


def _nullify_non_finite(value, counter: list[int]):
    # The API emits bare NaN, which is not valid JSON and makes BigQuery reject the whole file
    if isinstance(value, float) and not math.isfinite(value):
        counter[0] += 1
        return None
    if isinstance(value, dict):
        return {k: _nullify_non_finite(v, counter) for k, v in value.items()}
    if isinstance(value, list):
        return [_nullify_non_finite(v, counter) for v in value]
    return value


def load_pages(bq: bigquery.Client, table_id: str, pages: Iterable[tuple[int, list[dict]]], run_id: str,
               write_disposition: str, partitioned: bool) -> tuple[int, int, int]:
    """Spools every page to a gzipped NDJSON file, then loads it in ONE job so a failed run writes nothing."""
    extracted_at = datetime.now(timezone.utc).isoformat()
    n_pages = n_rows = 0
    nulled = [0]
    with tempfile.NamedTemporaryFile(suffix=".ndjson.gz") as tmp:
        with gzip.open(tmp.name, "wt", encoding="utf-8") as f:
            for page, rows in pages:
                for row in rows:
                    record = {"Payload": _nullify_non_finite(row, nulled), "RunId": run_id,
                              "ExtractedAt": extracted_at, "Page": page}
                    f.write(json.dumps(record, allow_nan=False))
                    f.write("\n")
                n_pages += 1
                n_rows += len(rows)
                if n_pages % 100 == 0:
                    log.info("%s: %d pages, %d rows spooled", table_id, n_pages, n_rows)

        if n_rows == 0:
            log.info("%s: nothing new, skipping load", table_id)
            return n_pages, 0, nulled[0]

        job_config = bigquery.LoadJobConfig(
            source_format=bigquery.SourceFormat.NEWLINE_DELIMITED_JSON,
            schema=RAW_SCHEMA,
            write_disposition=write_disposition,
            time_partitioning=bigquery.TimePartitioning(field="ExtractedAt") if partitioned else None,
        )
        with open(tmp.name, "rb") as f:
            bq.load_table_from_file(f, table_id, job_config=job_config).result()
    if nulled[0]:
        log.warning("%s: %d NaN/Infinity values stored as null", table_id, nulled[0])
    log.info("%s: loaded %d rows from %d pages", table_id, n_rows, n_pages)
    return n_pages, n_rows, nulled[0]


def log_run(bq: bigquery.Client, table_id: str, run: dict) -> None:
    job_config = bigquery.LoadJobConfig(schema=RUNS_SCHEMA, write_disposition="WRITE_APPEND",
                                        schema_update_options=["ALLOW_FIELD_ADDITION"])
    bq.load_table_from_json([run], table_id, job_config=job_config).result()


def last_watermark(bq: bigquery.Client, runs_table_id: str, source: str) -> str | None:
    try:
        bq.get_table(runs_table_id)
    except NotFound:
        return None
    query = f"""
        SELECT MAX(Watermark) AS Watermark
        FROM `{runs_table_id}`
        WHERE Source = @source
            AND Status = "success"
    """
    params = [bigquery.ScalarQueryParameter("source", "STRING", source)]
    rows = list(bq.query(query, job_config=bigquery.QueryJobConfig(query_parameters=params)).result())
    return rows[0].Watermark if rows else None
