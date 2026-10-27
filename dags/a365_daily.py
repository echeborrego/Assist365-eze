"""Composer/Airflow version of the daily job: the same pipeline functions the Cloud Run Job runs via main.py."""
from datetime import datetime, timedelta

from airflow.decorators import dag, task

from pipeline.config import Settings
from pipeline.runner import run_source
from pipeline.transform import run_models, run_tests


@dag(
    dag_id="a365_daily",
    schedule="0 6 * * *",
    start_date=datetime(2026, 10, 27),
    catchup=False,
    default_args={"retries": 2, "retry_delay": timedelta(minutes=5)},
    tags=["assist365"],
)
def a365_daily():
    @task
    def extract(source: str, run_id: str) -> dict:
        return run_source(Settings.from_env(), source, run_id)

    @task
    def transform() -> None:
        run_models(Settings.from_env())

    @task
    def data_tests() -> None:
        run_tests(Settings.from_env())

    run_id = "{{ ts_nodash }}"
    extracts = [extract.override(task_id=f"extract_{s}")(s, run_id) for s in ("catalogos", "siniestros", "polizas")]
    extracts >> transform() >> data_tests()


a365_daily()
