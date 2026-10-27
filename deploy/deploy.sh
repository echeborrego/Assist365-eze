#!/usr/bin/env bash
# Builds the image and (re)deploys the Cloud Run Job + daily Cloud Scheduler trigger. Safe to re-run.
# Usage: deploy/deploy.sh            (reads GCP_PROJECT, A365_API_BASE_URL, A365_API_TOKEN from .env)
#
# Scoped to the roles granted on the exercise project (Run, Scheduler, Build, Artifact Registry, BigQuery):
# no Secret Manager and no project-level IAM grants, so the job runs as the default compute service account
# and receives the API token as an environment variable (see docs/DECISIONS.md, N6).
set -euo pipefail

cd "$(dirname "$0")/.."
set -a; source .env; set +a

PROJECT="${GCP_PROJECT:?GCP_PROJECT not set}"
REGION="us-central1"
REPO="a365"
JOB="a365-pipeline"
SCHEDULE="0 5 * * *"
TIME_ZONE="America/Argentina/Buenos_Aires"
PROJECT_NUMBER="$(gcloud projects describe "$PROJECT" --format='value(projectNumber)')"
SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

# The tag names the commit; uncommitted changes to anything built into the image are marked, never hidden
TAG="$(git rev-parse --short HEAD)"
if [ -n "$(git status --porcelain -- main.py dags requirements.txt Dockerfile)" ]; then
    TAG="${TAG}-dirty-$(date -u +%Y%m%dT%H%M%S)"
fi
IMAGE="${REGION}-docker.pkg.dev/${PROJECT}/${REPO}/${JOB}:${TAG}"

gcloud config set project "$PROJECT" >/dev/null

# Image, built remotely by Cloud Build (no local Docker needed)
gcloud artifacts repositories describe "$REPO" --location="$REGION" >/dev/null 2>&1 \
    || gcloud artifacts repositories create "$REPO" --repository-format=docker --location="$REGION"
# The granted roles cannot read the Cloud Build log bucket, and gcloud fails a good build when it tries to
# follow it (even with --suppress-logs), so submit async and wait on the build status instead
BUILD_ID="$(gcloud builds submit --tag "$IMAGE" --async --format='value(id)' .)"
echo "Build ${BUILD_ID} started"
while true; do
    STATUS="$(gcloud builds describe "$BUILD_ID" --format='value(status)')"
    case "$STATUS" in
        SUCCESS) echo "Build ${BUILD_ID}: SUCCESS"; break ;;
        QUEUED|WORKING|PENDING) sleep 10 ;;
        *) echo "Build ${BUILD_ID} ended with status ${STATUS}" >&2; exit 1 ;;
    esac
done

# Env vars go through a private temp file so the token never appears on a command line
ENV_FILE="$(mktemp)"
trap 'rm -f "$ENV_FILE"' EXIT
chmod 600 "$ENV_FILE"
cat > "$ENV_FILE" <<EOF
GCP_PROJECT: "${PROJECT}"
BQ_LOCATION: "US"
A365_API_BASE_URL: "${A365_API_BASE_URL}"
A365_API_TOKEN: "${A365_API_TOKEN}"
EOF

# One task, one execution at a time; the job itself retries once on failure
gcloud run jobs deploy "$JOB" \
    --region="$REGION" \
    --image="$IMAGE" \
    --service-account="$SA" \
    --env-vars-file="$ENV_FILE" \
    --tasks=1 --parallelism=1 --max-retries=1 \
    --task-timeout=3600 --cpu=1 --memory=2Gi

# Cloud Scheduler calls the Run Admin API as the same service account
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
