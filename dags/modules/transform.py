import logging
from pathlib import Path

from google.cloud import bigquery

from modules import dependencies, load
from modules.config import Settings

log = logging.getLogger(__name__)


class DataTestError(Exception):
    pass


def _client(settings: Settings) -> bigquery.Client:
    return bigquery.Client(project=settings.gcp_project, location=settings.bq_location)


def _run(bq: bigquery.Client, path: Path) -> bigquery.QueryJob:
    # SQL names datasets without a project, so they resolve in settings.gcp_project (the environment switch)
    job = bq.query(path.read_text())
    job.result()
    log.info("%s: %.1f MB processed", path.relative_to(dependencies.SQL_DIR), (job.total_bytes_processed or 0) / 1e6)
    return job


def run_model(settings: Settings, model: str) -> None:
    """Builds one table; each SQL file is a single statement or a BigQuery script."""
    bq = _client(settings)
    load.ensure_datasets(bq, dependencies.LAYERS, settings.bq_location)
    _run(bq, dependencies.models()[model])


def run_test(settings: Settings, name: str) -> None:
    """A test returns the rows that break its rule; any row fails it."""
    rows = list(_run(_client(settings), dependencies.tests()[name]).result(max_results=5))
    if rows:
        raise DataTestError(f"{name}: {[dict(r) for r in rows]}")


def run_models(settings: Settings) -> None:
    dependencies.check()
    for model in dependencies.run_order():
        run_model(settings, model)


def run_tests(settings: Settings) -> None:
    """Runs every test before failing, so one run reports all broken rules."""
    failures = []
    for name in dependencies.tests():
        try:
            run_test(settings, name)
        except DataTestError as e:
            failures.append(str(e))
    if failures:
        raise DataTestError("Data tests failed:\n" + "\n".join(failures))
    log.info("All data tests passed")
