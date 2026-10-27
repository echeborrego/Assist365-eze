import os
from dataclasses import dataclass

from dotenv import load_dotenv


@dataclass(frozen=True)
class Settings:
    api_base_url: str
    api_token: str
    gcp_project: str
    bq_location: str
    raw_dataset: str = "raw"
    staging_dataset: str = "staging"
    dwh_dataset: str = "dwh"

    @classmethod
    def from_env(cls) -> "Settings":
        # Locally from .env; on Cloud Run from env vars + Secret Manager
        load_dotenv()
        return cls(
            api_base_url=os.environ["A365_API_BASE_URL"].rstrip("/"),
            api_token=os.environ["A365_API_TOKEN"],
            gcp_project=os.environ.get("GCP_PROJECT", "a365-de-ezequiel"),
            bq_location=os.environ.get("BQ_LOCATION", "US"),
        )
