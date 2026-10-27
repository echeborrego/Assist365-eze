import logging
from pathlib import Path

from google.cloud import bigquery

from modules import load
from modules.config import Settings

log = logging.getLogger(__name__)

SQL_DIR = Path(__file__).resolve().parent.parent / "transformations"
LAYERS = ("staging", "dwh")


class DataTestError(Exception):
    pass


def _run(bq: bigquery.Client, path: Path) -> bigquery.QueryJob:
    # SQL names datasets without a project, so they resolve in settings.gcp_project (the environment switch)
    job = bq.query(path.read_text())
    job.result()
    log.info("%s: %.1f MB processed", path.relative_to(SQL_DIR), (job.total_bytes_processed or 0) / 1e6)
    return job


def run_models(settings: Settings) -> None:
    """Runs transformations/staging then transformations/dwh in filename order.

    Each file is a single statement or a BigQuery script that (re)builds one table.
    """
    bq = bigquery.Client(project=settings.gcp_project, location=settings.bq_location)
    load.ensure_datasets(bq, ["staging", "dwh"], settings.bq_location)
    for layer in LAYERS:
        for path in sorted((SQL_DIR / layer).glob("*.sql")):
            _run(bq, path)


def run_tests(settings: Settings) -> None:
    """Each transformations/tests file returns the rows that break a rule; any row fails the run."""
    bq = bigquery.Client(project=settings.gcp_project, location=settings.bq_location)
    failures = []
    for path in sorted((SQL_DIR / "tests").glob("*.sql")):
        rows = list(_run(bq, path).result(max_results=5))
        if rows:
            failures.append(f"{path.stem}: {[dict(r) for r in rows]}")
    if failures:
        raise DataTestError("Data tests failed:\n" + "\n".join(failures))
    log.info("All data tests passed")
