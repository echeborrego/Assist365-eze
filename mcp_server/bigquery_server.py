"""Read-only BigQuery MCP server for the Assist-365 warehouse (stdio; registered in .mcp.json).

Guards: SELECT/WITH only, a single statement, datasets limited to staging and dwh, a dry run before every query,
and a hard bytes ceiling enforced by BigQuery itself (maximum_bytes_billed).
"""
import os
import re

from google.cloud import bigquery
from mcp.server.fastmcp import FastMCP

PROJECT = os.environ.get("GCP_PROJECT", "a365-de-ezequiel")
LOCATION = os.environ.get("BQ_LOCATION", "US")
DATASETS = ("dwh", "staging")
MAX_BYTES = int(os.environ.get("MCP_MAX_BYTES", 100 * 1024 * 1024))
MAX_ROWS = 200

_LEADING_COMMENTS = re.compile(r"^\s*(--[^\n]*\n|/\*.*?\*/\s*)+", re.DOTALL)
_IDENTIFIER = re.compile(r"^[A-Za-z0-9_]+$")

mcp = FastMCP("assist365-bigquery")
_client: bigquery.Client | None = None


def _bq() -> bigquery.Client:
    global _client
    if _client is None:
        _client = bigquery.Client(project=PROJECT, location=LOCATION)
    return _client


def _read_only_error(sql: str) -> str | None:
    body = _LEADING_COMMENTS.sub("", sql).strip().rstrip(";").strip()
    if not body.upper().startswith(("SELECT", "WITH")):
        return "Only SELECT or WITH queries are allowed."
    if ";" in body:
        return "Only a single statement is allowed."
    if re.search(r"\braw\.", body, re.IGNORECASE):
        return "Query the modelled datasets (dwh, staging), not raw."
    return None


@mcp.tool()
def list_tables(dataset: str) -> dict:
    """Lists the tables in a dataset (dwh or staging) with row counts."""
    if dataset not in DATASETS:
        return {"error": f"Dataset must be one of {DATASETS}"}
    tables = []
    for t in _bq().list_tables(f"{PROJECT}.{dataset}"):
        tables.append({"table": t.table_id, "rows": _bq().get_table(t.reference).num_rows})
    return {"dataset": dataset, "tables": tables}


@mcp.tool()
def describe_table(dataset: str, table: str) -> dict:
    """Returns a table's columns, types, partitioning and clustering."""
    if dataset not in DATASETS or not _IDENTIFIER.match(table):
        return {"error": "Invalid dataset or table name."}
    t = _bq().get_table(f"{PROJECT}.{dataset}.{table}")
    return {
        "table": f"{dataset}.{table}",
        "rows": t.num_rows,
        "partitioned_by": t.time_partitioning.field if t.time_partitioning else None,
        "clustered_by": t.clustering_fields,
        "columns": [{"name": f.name, "type": f.field_type} for f in t.schema],
    }


@mcp.tool()
def execute_sql(sql: str) -> dict:
    """Runs a read-only query on the warehouse and returns up to 200 rows plus the bytes it processed.

    A dry run rejects queries above the bytes ceiling before they run; BigQuery enforces the same ceiling.
    """
    error = _read_only_error(sql)
    if error:
        return {"error": error}
    dry = _bq().query(sql, job_config=bigquery.QueryJobConfig(dry_run=True, use_query_cache=False))
    if dry.total_bytes_processed > MAX_BYTES:
        return {"error": f"Query would process {dry.total_bytes_processed / 1e6:.1f} MB, above the "
                         f"{MAX_BYTES / 1e6:.0f} MB ceiling. Use the dwh aggregates or filter on the partition column."}
    job = _bq().query(sql, job_config=bigquery.QueryJobConfig(maximum_bytes_billed=MAX_BYTES))
    rows = [dict(r) for r in job.result(max_results=MAX_ROWS)]
    return {
        "rows": [{k: (v if isinstance(v, (int, float, str, bool)) or v is None else str(v)) for k, v in r.items()}
                 for r in rows],
        "row_count": len(rows),
        "mb_processed": round((job.total_bytes_processed or 0) / 1e6, 3),
    }


if __name__ == "__main__":
    mcp.run()
