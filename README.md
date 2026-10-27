# Assist-365: API → BigQuery → model → Looker Studio

A daily pipeline that pulls policies, claims and catalogues from the Assist-365 API into BigQuery, models them into a tested star schema, and feeds a one-page Looker Studio dashboard.

It answers which country is doing worst, which plan destroys margin, and whether the problem is claim frequency or average amount.

- **Runs in:** GCP project `a365-de-ezequiel`, every day at 05:00 America/Argentina/Buenos_Aires.
- **Dashboard:** https://lookerstudio.google.com/reporting/ded37257-936c-44e6-a150-cc957803ff07 · opens on the last five issue quarters; definitions are on the page.
- **Analysis:** [`docs/ANALYSIS.md`](docs/ANALYSIS.md).
- **Every decision, with its evidence:** [`docs/DECISIONS.md`](docs/DECISIONS.md).

## Architecture

```
Cloud Scheduler 05:00 AR
        │  POST jobs:run
        ▼
Cloud Run Job a365-pipeline (python main.py)
        │
        ├─ extract ── /catalogos (3 tipos)   full replace     ─┐
        │            /siniestros (offset)    daily snapshot    ├─► raw.*      record kept as JSON + RunId, ExtractedAt
        │            /polizas (cursor, CDC)  incremental       ─┘   raw.ExtractRun   one audit row per source per run
        │
        ├─ transform ─ staging.*   typed, deduplicated, flagged; staging.Poliza merged incrementally
        │              dwh.*       Producto, Agencia, Pais, Poliza (sales), Siniestro (claims),
        │                          SiniestralidadMensual + SiniestroPorTipo (dashboard aggregates)
        │
        └─ tests ──── 6 SQL data tests; any failing row fails the run
                                                   │
                                                   ▼
                                     Looker Studio (native BigQuery connector)
```

The same code also runs as **three Airflow DAGs** (`a365_extract` → `a365_transform` → `a365_tests`), with one task per table and per test. Locally: `docker compose up`, then http://localhost:8080 (admin/admin).

Production uses Cloud Run because the project grants Run, Scheduler, Build and BigQuery roles but not Composer (P13). Moving to Composer is a sync of `dags/`.

## Running it

```bash
cp .env.example .env                     # add the API token
uv venv && uv pip install -r requirements.txt
uv pip install -r mcp_server/requirements.txt   # only for the MCP server; .mcp.json expects the venv in .venv/
gcloud auth application-default login

python main.py                           # extract + transform + tests
python main.py --step transform          # models and tests only
python main.py --source polizas --full-refresh

docker compose up                        # Airflow UI on :8080
deploy/deploy.sh                         # build + deploy the Cloud Run Job and Scheduler
```

## Decisions

### Extraction

- **Retries:** 429, 5xx, timeouts and unreadable bodies are retried with exponential backoff and jitter, honouring `Retry-After`. Other 4xx fail fast. The first full load needed 48 retries; all recovered.
- **Load method (P1):** each source is spooled to gzipped NDJSON and loaded in **one BigQuery load job**.
  - Load jobs are free; streaming inserts are billed.
  - A failed run writes nothing.
  - The raw record lands in a `JSON` column, so provider schema drift cannot break a load.
- **Completeness (P7):** the rows received (before any cleaning) must match the API's own `meta.total` (± a configurable tolerance) before loading. Received and expected counts are logged even on failure.

### What happens on the second run

| Source | Second run |
|---|---|
| `polizas` | **Incremental.** `updated_since` = the last successful watermark, so a run with no new data reads 2 pages instead of 1,004. The API returns the whole page containing the watermark, so overlap is expected and deduplicated. The watermark ignores future-dated changes until their time comes (P2, P3). |
| `siniestros` | **Full snapshot every day.** The API ignores every filter parameter (tested). Staging reads the latest successful snapshot (P4). |
| `catalogos` | **Full replace.** |

### Modelling

| Table | Grain |
|---|---|
| `dwh.Poliza` | one row per policy sold |
| `dwh.Siniestro` | one row per claim, carrying its policy's issue date, country and plan |
| `dwh.SiniestralidadMensual` | issue month × country × plan |
| `dwh.SiniestroPorTipo` | issue month × country × plan × claim type |

Every table, column, source JSON path and rule is in `docs/TABLES.md`.

**Metric definitions** (the glossary left these open on purpose):

| # | Definition |
|---|---|
| M1 | Claims cost is `PAGADO` only. `EN_ANALISIS` is shown as pending exposure. |
| M2 | Cancelled (`ANULADA`) policies add no written premium. |
| M3 | USD at the FX rate of the issue date (premium) or the occurrence date (claims). The rate is carried over weekends and holidays. |
| M4 | **Underwriting basis:** a claim counts in its policy's issue period, so a bad cohort shows up where it was sold. Recent cohorts are immature, so the model exposes the share of policies whose coverage has ended. |
| M5 | Frequency = paid claims / policies on the same (non-cancelled) set. Severity = cost / paid claims. |

### Dashboard budget (measured)

BigQuery bills **at least 10 MB per query**, and Looker Studio runs one query per chart and per dropdown control. So the page runs on two small aggregates (≈2k and ≈9k rows), has no dropdowns, and filters by clicking the charts (cross-filtering).

Measured in `INFORMATION_SCHEMA.JOBS_BY_USER` with Looker Studio's own job labels, on "Actualizar datos":

| Per load | Cold (no cache) | Normal (cached) |
|---|---|---|
| Queries | 5: heatmap, plan bars, table (Looker sends it twice), claim-type bars | 5, served from cache |
| **MB processed** | **≈ 1 MB** (0.13–0.45 MB per query) | 0 |
| MB billed | ≈ 52 MB (5 × the 10 MB minimum) | 0 |

The claim-type chart was rebuilt with four metrics instead of a breakdown dimension, which cut its queries from 3 to 1. The remaining duplicate is Looker Studio's own behaviour for tables.

## What was odd in the data

All of these are handled and flagged; counts and rules are in `docs/DECISIONS.md`.

**Claims**
- 829 exact duplicates.
- 27,710 dates in `dd/mm/yyyy` next to ISO dates. Proven day-first: the first part goes above 12; the second never does.
- 414 bare `NaN` currencies. Invalid JSON that made BigQuery reject the load.
- 824 negative amounts. Treated as sign errors.
- 2,138 claims dated after the day they were first seen. The API has no creation date, so the pipeline records first sighting.
- 3,473 claims on deleted policies. Excluded, together with their policy.
- 438 on cancelled policies and 1,242 outside coverage dates. Kept, as paid leakage.
- 552 on policies that do not exist.
- The provider's `detail` comes in Spanish or English keys.

**Policies**
- 20,000 deletes, 956 of them stamped up to 2027-02-10.
- `estado` does not track the lifecycle: policies stay `EMITIDA` after their trip, and some are `VENCIDA` before it starts.
- ~7 % are priced in USD in every country. Verified genuine.
- The last sale is 2026-08-30.

**FX**
- Business days only.
- Quotes up to three days in the future.
- 38 local-time sales on 2023-12-31, before the first quote.

## Semantic layer and MCP (bonus 1)

- **Skill:** `.claude/skills/assist365-warehouse/`. `SKILL.md` holds the glossary, metric definitions and the rules that change answers. `data_model.md` describes every table; `common_queries.md` has the canonical SQL for each metric.
- **MCP server:** `mcp_server/bigquery_server.py`, registered in `.mcp.json`. Every query is dry-run first: BigQuery's own parse must say it is a `SELECT` that only reads `dwh` or `staging`, and a hard bytes ceiling (`maximum_bytes_billed`) applies. It runs locally over stdio with your gcloud credentials; open Claude Code in the repo and approve the `assist365-bigquery` server.
- **Five business questions in natural language**, answered by Claude Code with the skill and the MCP server: [`docs/MCP_SESSION.md`](docs/MCP_SESSION.md), the exported session with each question, the SQL it wrote and the result.
- **Regression check:** `python mcp_server/ask.py` runs the same five questions as fixed SQL through the server and writes [`docs/MCP_CHECK.md`](docs/MCP_CHECK.md).

## Data tests

Six SQL tests run after every transform: unique keys, relationships, accepted values, complete USD conversion, row counts reconciled across raw → staging → dwh, and aggregates reconciled with the facts.

`dependencies.check()` fails the DAG import if a SQL file reads a table it does not declare in `UPSTREAM`.

Refactors were proven with before/after equivalence (`EXCEPT DISTINCT` both ways), and one headline number was recomputed straight from raw JSON (Chile premium, to the cent).

## With more time

- **Alerting (N5):** a Cloud Monitoring alert on failed executions, plus a "data as of" date on the dashboard.
- **Credentials (N6):** a dedicated least-privilege service account, and the token in Secret Manager. Both need permissions this project does not grant.
- **Incremental scans:** a weekly full refresh for policies (N1). Claims snapshot retention plus a status-history table (N2).
- **Model style (N7):** `SELECT`-only models with destination and partitioning from config; `staging/Poliza.sql` split up.
- **CI:** DAG import, `dependencies.check()` and lint on every PR.

## How AI was used

Built with Claude Code as a pair programmer over one working day. I set the direction and made every business decision; Claude wrote most of the code and SQL, and I reviewed it.

- **Context files:** a personal `CLAUDE.md` (working rules: evidence before theory, PROVEN vs INFERRED, branch → PR, SQL style) and a memory of lessons from previous data-engineering work.
- **Review:** a harsh self-review skill (`/bastard-review`) before every PR. It caught, among others, a future-claim flag that would have expired, an incremental watermark race, two schedulers that would have run the pipeline twice, and a deploy script that failed on a successful build.
- **Verification:** every claim is backed by a query, a test or a real run. The PR descriptions include real examples from the warehouse.
- **Transcript:** _shared separately_.
