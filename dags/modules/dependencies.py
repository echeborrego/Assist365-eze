"""Model dependencies, declared by hand: the single source of truth for the Airflow DAGs and main.py."""
import re
from graphlib import TopologicalSorter
from pathlib import Path

SQL_DIR = Path(__file__).resolve().parent.parent / "transformations"
LAYERS = ("staging", "dwh")

UPSTREAM = {  # model: requires_this_model or [requires_these_models]
    "staging_siniestros": "staging_polizas",
    "dwh_dim_producto": "staging_productos",
    "dwh_dim_agencia": "staging_agencias",
    "dwh_fct_ventas": ["staging_polizas", "staging_tipo_cambio"],
    "dwh_fct_siniestros": ["staging_siniestros", "staging_tipo_cambio", "dwh_fct_ventas"],
    "dwh_agg_siniestralidad_mensual": ["dwh_fct_ventas", "dwh_fct_siniestros", "dwh_dim_producto", "dwh_dim_pais"],
}

_BUILDS = re.compile(r"(?:CREATE OR REPLACE TABLE|CREATE TABLE IF NOT EXISTS|MERGE)\s+((?:staging|dwh)\.\w+)")
_READS = re.compile(r"\b((?:staging|dwh)\.\w+)")


def upstream_of(model: str) -> list[str]:
    deps = UPSTREAM.get(model, [])
    return [deps] if isinstance(deps, str) else list(deps)


def models() -> dict[str, Path]:
    """{model: sql path}; a model is <layer>_<file name>, e.g. dwh_fct_ventas."""
    return {f"{layer}_{p.stem}": p for layer in LAYERS for p in sorted((SQL_DIR / layer).glob("*.sql"))}


def tests() -> dict[str, Path]:
    return {p.stem: p for p in sorted((SQL_DIR / "tests").glob("*.sql"))}


def set_flow(tasks: dict, upstreams: dict, starting_task: str | None = None) -> None:
    """Wires Airflow tasks from an upstream dict; tasks without upstreams hang off starting_task."""
    for task in tasks:
        if task in upstreams:
            for upstream in upstream_of(task):
                tasks[upstream] >> tasks[task]
        elif starting_task is not None and task != starting_task:
            tasks[starting_task] >> tasks[task]


def run_order() -> list[str]:
    graph = {m: set(upstream_of(m)) for m in models()}
    return list(TopologicalSorter(graph).static_order())


def check() -> None:
    """Fails if UPSTREAM names an unknown model, has a cycle, or a model reads a table it does not declare."""
    found = models()
    unknown = {m for m in UPSTREAM if m not in found} | {d for m in UPSTREAM for d in upstream_of(m) if d not in found}
    if unknown:
        raise ValueError(f"UPSTREAM names models with no SQL file: {sorted(unknown)}")
    run_order()  # raises graphlib.CycleError on a cycle

    producer = {}
    for model, path in found.items():
        for table in _BUILDS.findall(path.read_text()):
            producer[table] = model
    problems = []
    for model, path in found.items():
        for table in sorted(set(_READS.findall(path.read_text()))):
            builder = producer.get(table)
            if builder is None:
                problems.append(f"{model} reads {table}, which no model builds")
            elif builder != model and builder not in upstream_of(model):
                problems.append(f"{model} reads {table} (built by {builder}) but does not declare it in UPSTREAM")
    if problems:
        raise ValueError("Model dependencies out of date:\n" + "\n".join(problems))
