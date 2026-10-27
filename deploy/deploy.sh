#!/usr/bin/env bash
# Builds the image and (re)deploys the Cloud Run Job + daily Cloud Scheduler trigger. Safe to re-run.
# Usage: deploy/deploy.sh            (reads GCP_PROJECT, A365_API_BASE_URL, A365_API_TOKEN from .env)
set -euo pipefail

cd "$(dirname "$0")/.."
set -a; source .env; set +a

PROJECT="${GCP_PROJECT:?GCP_PROJECT not set}"
REGION="us-central1"
REPO="a365"
JOB="a365-pipeline"
SCHEDULE="0 5 * * *"
TIME_ZONE="America/Argentina/Buenos_Aires"
SECRET="a365-api-token"
SA_NAME="a365-pipeline"
SA="${SA_NAME}@${PROJECT}.iam.gserviceaccount.com"
# The tag names the commit; uncommitted changes to anything built into the image are marked, never hidden
TAG="$(git rev-parse --short HEAD)"
if [ -n "$(git status --porcelain -- main.py dags requirements.txt Dockerfile)" ]; then
    TAG="${TAG}-dirty-$(date -u +%Y%m%dT%H%M%S)"
fi
IMAGE="${REGION}-docker.pkg.dev/${PROJECT}/${REPO}/${JOB}:${TAG}"

gcloud config set project "$PROJECT" >/dev/null
gcloud services enable secretmanager.googleapis.com run.googleapis.com cloudscheduler.googleapis.com \
    artifactregistry.googleapis.com cloudbuild.googleapis.com

# API token: a new secret version on every deploy, read from .env, never echoed
gcloud secrets describe "$SECRET" >/dev/null 2>&1 || gcloud secrets create "$SECRET" --replication-policy=automatic
printf '%s' "$A365_API_TOKEN" | gcloud secrets versions add "$SECRET" --data-file=-

# Runtime identity: only what the pipeline needs
gcloud iam service-accounts describe "$SA" >/dev/null 2>&1 \
    || gcloud iam service-accounts create "$SA_NAME" --display-name="Assist-365 pipeline"
gcloud projects add-iam-policy-binding "$PROJECT" --member="serviceAccount:${SA}" \
    --role=roles/bigquery.jobUser --condition=None >/dev/null
for DATASET in raw staging dwh; do
    bq --project_id="$PROJECT" show "$DATASET" >/dev/null
    bq --project_id="$PROJECT" add-iam-policy-binding -d --member="serviceAccount:${SA}" \
        --role=roles/bigquery.dataEditor "${PROJECT}:${DATASET}" >/dev/null
done
gcloud secrets add-iam-policy-binding "$SECRET" --member="serviceAccount:${SA}" \
    --role=roles/secretmanager.secretAccessor >/dev/null

# Image, built remotely by Cloud Build (no local Docker needed)
gcloud artifacts repositories describe "$REPO" --location="$REGION" >/dev/null 2>&1 \
    || gcloud artifacts repositories create "$REPO" --repository-format=docker --location="$REGION"
gcloud builds submit --tag "$IMAGE" .

# One task, one execution at a time; the job itself retries once on failure
gcloud run jobs deploy "$JOB" \
    --region="$REGION" \
    --image="$IMAGE" \
    --service-account="$SA" \
    --set-secrets="A365_API_TOKEN=${SECRET}:latest" \
    --set-env-vars="GCP_PROJECT=${PROJECT},A365_API_BASE_URL=${A365_API_BASE_URL},BQ_LOCATION=US" \
    --tasks=1 --parallelism=1 --max-retries=1 \
    --task-timeout=3600 --cpu=1 --memory=2Gi

# Scheduler calls the Run Admin API as the same service account
gcloud run jobs add-iam-policy-binding "$JOB" --region="$REGION" \
    --member="serviceAccount:${SA}" --role=roles/run.invoker >/dev/null
RUN_URI="https://run.googleapis.com/v2/projects/${PROJECT}/locations/${REGION}/jobs/${JOB}:run"
if gcloud scheduler jobs describe "${JOB}-daily" --location="$REGION" >/dev/null 2>&1; then
    ACTION=update
else
    ACTION=create
fi
gcloud scheduler jobs "$ACTION" http "${JOB}-daily" \
    --location="$REGION" \
    --schedule="$SCHEDULE" \
    --time-zone="$TIME_ZONE" \
    --uri="$RUN_URI" \
    --http-method=POST \
    --oauth-service-account-email="$SA"

echo "Deployed ${IMAGE}"
echo "Run now: gcloud run jobs execute ${JOB} --region=${REGION} --wait"
