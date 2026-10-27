import argparse
import logging
import sys
from pathlib import Path

# Same import root Airflow uses, so modules/ resolves identically on Cloud Run and Composer
sys.path.insert(0, str(Path(__file__).resolve().parent / "dags"))

from modules.config import Settings
from modules.runner import SOURCES, new_run_id, run_source
from modules.transform import run_models, run_tests


def main() -> int:
    parser = argparse.ArgumentParser(description="Assist-365 API -> BigQuery pipeline")
    parser.add_argument("--step", choices=("extract", "transform", "all"), default="all")
    parser.add_argument("--source", choices=(*SOURCES, "all"), default="all")
    parser.add_argument("--full-refresh", action="store_true", help="Ignore the polizas watermark and pull everything")
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    settings = Settings.from_env()
    run_id = new_run_id()
    sources = SOURCES if args.source == "all" else (args.source,)

    failed = []
    if args.step in ("extract", "all"):
        for source in sources:
            try:
                run_source(settings, source, run_id, args.full_refresh)
            except Exception:
                logging.exception("Source %s failed", source)
                failed.append(source)
    if failed:
        # Transforming on top of a partial extract would publish a mix of old and new data
        logging.error("Failed sources: %s, skipping transform", failed)
        return 1
    if args.step in ("transform", "all"):
        run_models(settings)
        run_tests(settings)
    return 0


if __name__ == "__main__":
    sys.exit(main())
