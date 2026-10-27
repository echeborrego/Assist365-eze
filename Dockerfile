# Cloud Run Job image: runs the same code as the Airflow DAG (dags/ is the import root)
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app
COPY requirements.txt .
RUN pip install --requirement requirements.txt

COPY main.py .
COPY dags/ dags/

RUN useradd --create-home pipeline
USER pipeline

ENTRYPOINT ["python", "main.py"]
