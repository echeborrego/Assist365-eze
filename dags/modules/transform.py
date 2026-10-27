import logging
from pathlib import Path
from string import Template

from google.cloud import bigquery

from modules import load
from modules.config import Settings

log = logging.getLogger(__name__)

SQL_DIR = Path(__file__).resolve().parent.parent / "transformations"
LAYERS = ("staging", "dwh")


class DataTestError(Exception):
    pass


def _render(settings: Settings, path: Path) -> str:
    # ${raw}/${staging}/${dwh} in the SQL resolve to the configured datasets; unknown placeholders fail loudly
    return Template(path.read_text()).substitute(
        raw=settings.raw_dataset, staging=settings.staging_dataset, dwh=settings.dwh_dataset)


def _run(bq: bigquery.Client, settings: Settings, path: Path) -> bigquery.QueryJob:
    job = bq.query(_render(settings, path))
    job.result()
    log.info("%s: %.1f MB processed", path.relative_to(SQL_DIR), (job.total_bytes_processed or 0) / 1e6)
    return job


def run_models(settings: Settings) -> None:
    """Runs transformations/staging then transformations/dwh in filename order.

    Each file is a single statement or a BigQuery script that (re)builds one table.
    """
    bq = bigquery.Client(project=settings.gcp_project, location=settings.bq_location)
    load.ensure_datasets(bq, [settings.staging_dataset, settings.dwh_dataset], settings.bq_location)
    for layer in LAYERS:
        for path in sorted((SQL_DIR / layer).glob("*.sql")):
            _run(bq, settings, path)


def run_tests(settings: Settings) -> None:
    """Each transformations/tests file returns the rows that break a rule; any row fails the run."""
    bq = bigquery.Client(project=settings.gcp_project, location=settings.bq_location)
    failures = []
    for path in sorted((SQL_DIR / "tests").glob("*.sql")):
        rows = list(_run(bq, settings, path).result(max_results=5))
        if rows:
            failures.append(f"{path.stem}: {[dict(r) for r in rows]}")
    if failures:
        raise DataTestError("Data tests failed:\n" + "\n".join(failures))
    log.info("All data tests passed")
