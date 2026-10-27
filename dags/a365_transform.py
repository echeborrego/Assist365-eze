"""Builds staging and dwh, one task per table, wired by modules.dependencies.UPSTREAM; then triggers a365_tests."""
from datetime import timedelta

import pendulum
from airflow import DAG
from airflow.operators.empty import EmptyOperator
from airflow.operators.python import PythonOperator
from airflow.operators.trigger_dagrun import TriggerDagRunOperator

from modules import dependencies
from modules.config import Settings
from modules.transform import run_model

dependencies.check()  # a SQL file reading an undeclared table fails the DAG import, before anything runs


def build(model: str) -> None:
    run_model(Settings.from_env(), model)


with DAG(
    dag_id="a365_transform",
    description="raw -> staging -> dwh",
    schedule=None,
    start_date=pendulum.datetime(2026, 10, 27, tz="America/Argentina/Buenos_Aires"),
    catchup=False,
    max_active_runs=1,
    default_args={"retries": 1, "retry_delay": timedelta(minutes=2)},
    tags=["assist365"],
) as dag:
    tasks = {"start": EmptyOperator(task_id="start")}
    for model in dependencies.models():
        tasks[model] = PythonOperator(task_id=model, python_callable=build, op_kwargs={"model": model})
    dependencies.set_flow(tasks, dependencies.UPSTREAM, "start")

    checkpoint = EmptyOperator(task_id="checkpoint")
    leaves = [t for name, t in tasks.items() if name != "start" and not t.downstream_list]
    leaves >> checkpoint >> TriggerDagRunOperator(task_id="trigger_a365_tests", trigger_dag_id="a365_tests")
