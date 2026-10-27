"""Runs every data test in parallel, one task each: a red task names the broken rule."""
from datetime import timedelta

import pendulum
from airflow import DAG
from airflow.operators.python import PythonOperator

from modules import dependencies
from modules.config import Settings
from modules.transform import run_test


def check(name: str) -> None:
    run_test(Settings.from_env(), name)


with DAG(
    dag_id="a365_tests",
    description="Data tests on staging and dwh",
    schedule=None,
    start_date=pendulum.datetime(2026, 10, 27, tz="America/Argentina/Buenos_Aires"),
    catchup=False,
    max_active_runs=1,
    default_args={"retries": 0},
    tags=["assist365"],
) as dag:
    for name in dependencies.tests():
        PythonOperator(task_id=name, python_callable=check, op_kwargs={"name": name})
