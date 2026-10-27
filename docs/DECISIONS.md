# Decision log

Business and technical decisions taken during the build, with the evidence behind each one.
Status: **Decided** or **Pending** (an open question for the business).

## Data handling

| # | Topic | Decision | Evidence | Status |
|---|---|---|---|---|
| D1 | Duplicate claims | Keep one row per `claim_id`. | 138,962 rows, 138,133 distinct `claim_id`s; the 829 extra rows are byte-identical copies. | Decided |
| D2 | Claim date format | Parse `occurred_at` / `reported_at` as ISO (`yyyy-mm-dd`) or `dd/mm/yyyy`; the year is kept. | 27,710 claims use `dd/mm/yyyy`. In 16,715 the first part is > 12 and the second part never is. Read as dd/mm, all 27,710 have a 0–60 day reporting lag; read as mm/dd, only 1,930 do. | Decided |
| D3 | Claims without currency | Use the currency of the policy the claim belongs to, and flag the row. | 414 claims arrive with `"currency": NaN` (invalid JSON; stored as null on load). | Decided |
| D4 | Provider `detail` field | Coalesce `diagnostico`/`diagnosis` into `Diagnostico` and `ciudad_atencion`/`city` into `CiudadAtencion`. | Three shapes: Spanish keys (83,505), English keys (41,538), provider only (13,919). | Decided |
| D5 | Non-business-day FX | Use the last known rate on or before the date (carried over weekends and holidays); dates before the first quote use the first one. | Rates exist Monday–Friday only; a few weekdays are missing too (gaps of 4 days before 2026-05-04 and 2026-07-21). Quotes start 2024-01-01, but 38 sales fall on 2023-12-31 in local time (D10); the `usd_conversion_complete` test caught them. | Decided |
| D6 | Future-dated FX quotes | Ignore rates after today. | The catalogue has quotes up to 2026-10-30. | Decided |
| D7 | Negative claim amounts (`raw.siniestros`) | Treat as an input error: use the absolute value and flag `EsMontoNegativoOrigen`. A provider never pays the company, so a negative paid claim cannot be right. | 828 claims (0.6 %). Their size distribution matches the positive amounts in every currency, and they come from all 5 providers and all 3 statuses. Each `claim_id` appears once, so they do not reverse another claim. Example: SIN-00070784, `PAGADO`, -1669.27 MXN. | Decided |
| D8 | Claims dated in the future (`raw.siniestros`) | Keep them, flagged `EsFechaFutura`, and exclude them from every official metric. The flag is stored because in six months the date alone will no longer reveal the problem. | 2,151 claims have `occurred_at` after the extraction date (up to 2027-03-05), some already `PAGADO`, e.g. SIN-00071837 occurred 2026-12-05, `PAGADO`. | Decided |
| D9 | Policy deletes (`op = D`) | `staging.polizas` keeps every policy with `IsDeleted` (the replica layer); `dwh` excludes deleted policies. | 20,000 deletes, all on policies in state `EMITIDA`. | Decided |
| D10 | Issue date timezone | `FechaEmision` is the sale date in the issuing country's local time (AR Buenos Aires, BR São Paulo, CL Santiago, CO Bogotá, MX Mexico City, PE Lima). | The source stamps sales in UTC; a sale at 22:00 in Mexico is the next day in UTC. Side effect: the earliest sale is 2023-12-31 local (2024-01-01 UTC). | Decided |
| D11 | Claims on deleted policies | Excluded from the model, flagged `EsPolizaEliminada`. The policy's premium is excluded (D9), so keeping its claims would inflate loss ratio. | 3,473 claims. Deleted policies have a complete history and claims at the same rate as the rest (~17 %), so it is unclear why the core deletes them: a question for the business. | Decided |
| D12 | Claims on cancelled policies or outside coverage dates | Kept: if `PAGADO`, the money left the company. Flagged `EsPolizaAnulada` / `EsFueraDeVigencia` and reported as leakage. | 438 claims on `ANULADA` policies; 1,242 with `occurred_at` outside `inicio_vigencia`..`fin_vigencia`. | Decided |
| D13 | Orphan claims (policy not in the source) | Excluded from loss ratio (the underwriting basis needs the policy), reported as a separate total. Possibly policies from before the extract window. | 552 claims. | Decided |
| D14 | Policies priced in USD | Genuine USD prices, converted with `factor_usd = 1`. | ~7 % of policies in every country, channel, product and year. Median premium is ~$90 both for USD-priced and local-priced policies (converted), so they are not mislabelled local amounts. | Decided |
| D15 | Policy `estado` | Only `ANULADA` is used. The other states do not track the lifecycle. | 607,512 policies still `EMITIDA` after their coverage ended; 1,966 `VENCIDA` before it ended. | Decided |

## Metric definitions

| # | Topic | Decision | Status |
|---|---|---|---|
| M1 | Claims cost | Only `PAGADO` claims count as cost ("lo que efectivamente se pagó"). `EN_ANALISIS` is shown separately as pending exposure, since it may still be rejected. | Decided |
| M2 | Cancelled policies (`ANULADA`) | Their premium does not count as written premium. | Decided |
| M3 | USD conversion | `amount * factor_usd` at the rate of the issue date (premium) and the occurrence date (claims). The API has no payment/confirmation date for claims. | Decided |
| M4 | Period attribution for loss ratio | Underwriting (per policy) basis: a claim is attributed to the issue date of its policy, so each cohort of policies carries the claims it generated. Calendar basis would show a problematic Q3 plan as a Q4 problem. Recent cohorts are immature (trips not yet taken), so the model exposes the share of policies whose coverage has already ended. | Decided |

## Pipeline

| # | Topic | Decision | Evidence |
|---|---|---|---|
| P1 | Load method | Batch load jobs of gzipped NDJSON, raw record kept in a `JSON` column. Free (streaming inserts are billed), atomic per source (a failed run writes nothing), and schema drift in the provider's free-form fields cannot break the load. | — |
| P2 | Policies second run | Incremental: `updated_since` = last successful watermark. The API returns the whole page containing that timestamp, so overlap is expected and staging dedupes it. | Pages are sorted by `updated_at` and contiguous; `updated_since=2025-06-01` returned 306 rows from before that date. Second run on 2026-10-27: 2 pages, 1,461 rows in ~11 s, against 1,004 pages in ~7.5 min for the full load. |
| P3 | Policies watermark ceiling | The watermark only counts `updated_at` values up to the run's start time. | 956 deletes carry `updated_at` up to 2027-02-10; the first run's watermark landed in 2027, which would have skipped every real change until then. Fixed in code; the first run's log row was corrected by hand. |
| P4 | Claims second run | Full snapshot every day, appended to a date-partitioned raw table; staging reads the latest snapshot. | The API has no change filter for claims; a full pull is 278 pages (~2 min). Keeping snapshots preserves status history (`EN_ANALISIS` → `PAGADO`). |
| P5 | Invalid JSON values | `NaN`/`Infinity` are stored as null and counted per run in `raw.extract_runs.NonFiniteNulled`. | BigQuery rejected the first claims load because of a bare `NaN`. |
| P6 | Retries | 429, 5xx, timeouts and unparseable bodies are retried with exponential backoff and jitter (1 s doubling to a 60 s cap, 8 attempts), honouring `Retry-After`. Other 4xx fail immediately. | First full load: 48 retries (23 × 429, 25 × 500), all recovered. |
