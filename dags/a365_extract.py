"""Pulls the three API sources into raw.*, then triggers a365_transform. Same code the Cloud Run Job runs."""
import os
from datetime import timedelta

import pendulum
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.trigger_dagrun import TriggerDagRunOperator

from modules.config import Settings
from modules.runner import SOURCES, run_source


# Production is scheduled by Cloud Scheduler -> Cloud Run. Set this only where Airflow is the orchestrator,
# never both: two schedulers would run the pipeline twice against the same tables.
SCHEDULE = os.environ.get("A365_EXTRACT_SCHEDULE") or None


def extract(source: str, pipeline_run_id: str) -> dict:
    # "run_id" is reserved in the Airflow task context, hence the longer name
    return run_source(Settings.from_env(), source, pipeline_run_id)


with DAG(
    dag_id="a365_extract",
    description="API -> raw",
    schedule=SCHEDULE,
    start_date=pendulum.datetime(2026, 10, 27, tz="America/Argentina/Buenos_Aires"),
    catchup=False,
    max_active_runs=1,
    default_args={"retries": 2, "retry_delay": timedelta(minutes=5)},
    tags=["assist365"],
) as dag:
    trigger = TriggerDagRunOperator(task_id="trigger_a365_transform", trigger_dag_id="a365_transform")
    for source in SOURCES:
        PythonOperator(
            task_id=f"extract_{source}",
            python_callable=extract,
            op_kwargs={"source": source, "pipeline_run_id": "{{ ts_nodash }}"},
        ) >> trigger
