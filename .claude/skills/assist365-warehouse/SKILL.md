---
name: assist365-warehouse
description: Answer business questions about Assist-365 travel insurance (policies, claims, loss ratio, frequency, severity, premium by plan, country or quarter) by querying the BigQuery warehouse through the assist365-bigquery MCP server. Use for any question about siniestralidad, primas, siniestros, planes, países or the dashboard numbers.
---

# Assist-365 warehouse

Answer with numbers from BigQuery, through the `assist365-bigquery` MCP tools (`list_tables`, `describe_table`, `execute_sql`).

Before writing SQL:

- Read [data_model.md](data_model.md) for tables, grains and columns.
- Start from [common_queries.md](common_queries.md) for any standard metric, so every answer matches the dashboard.

## Glossary

| Term | Meaning |
|---|---|
| **Póliza** | A policy sold to one traveller for a date range. Sold in AR, BR, CL, CO, MX, PE. |
| **Prima emitida** (written premium) | What is charged for a policy, in USD. Cancelled (`ANULADA`) policies add 0. |
| **Siniestro** (claim) | A covered event during the trip (MEDICO, CANCELACION, EQUIPAJE, DEMORA), billed by a provider. Status: PAGADO, EN_ANALISIS, RECHAZADO. |
| **Costo de siniestros** (claims cost) | USD paid on claims with status **PAGADO** only. `EN_ANALISIS` is pending exposure, not cost. |
| **Anticipación de compra** | Days between the issue date and the start of the trip (`DiasAnticipacion`). |
| **Cohorte / trimestre de emisión** | The month or quarter a policy was sold. Every metric is attributed to it. |
| **Madurez** (maturity) | Share of a cohort's policies whose coverage has already ended. Below 1, the cohort will still collect claims. |

## Metrics

Always compute ratios as a ratio of sums, never as an average of ratios.

| Metric | Definition | Columns in `dwh.SiniestralidadMensual` |
|---|---|---|
| **Siniestralidad** (loss ratio) | claims cost / written premium | `SUM(CostoSiniestrosUsd) / SUM(PrimaEmitidaUsd)` |
| **Frecuencia** | paid claims / policies, on non-cancelled policies | `SUM(SiniestrosPagadosConCobertura) / SUM(Polizas)` |
| **Severidad** | average USD paid per paid claim | `SUM(CostoSiniestrosUsd) / SUM(SiniestrosPagados)` |
| **Prima media** | average written premium per policy | `SUM(PrimaEmitidaUsd) / SUM(Polizas)` |
| **Madurez** | share of policies whose coverage ended | `SUM(PolizasCoberturaTerminada) / SUM(Polizas)` |

Identity: **siniestralidad = (frecuencia × severidad) / prima media**, i.e. cost per policy over premium per policy. Use it to explain *why* a plan's loss ratio is high.

## Rules that change answers

1. **Underwriting basis.** A claim counts in its policy's issue period, not when it happened. "Q2 2026" means policies sold in Q2 2026 and all their claims.
2. **Mind maturity.** A quarter with maturity below about 0.95 looks better than it is. When comparing quarters, say which ones are immature; the last closed quarter is the latest with maturity ≥ 0.95.
3. **Official metrics exclude** claims dated in the future, claims on deleted policies and claims on policies missing from the source. `dwh.Siniestro.CuentaParaSiniestralidad` encodes this; the aggregates already apply it.
4. **USD everywhere.** Local amounts are converted at the FX rate of the issue date (premium) or the occurrence date (claims).
5. **No sales after 2026-08-30**, so the source's current quarter has no sales.
6. **What a plan covers is not in the data.** `TipoPlan` comes from the catalogue. Say "classified as" rather than "covers".

## Querying cheaply

- Prefer `dwh.SiniestralidadMensual` (issue month × country × plan) and `dwh.SiniestroPorTipo` (× claim type). Both are under 1 MB.
- Use `dwh.Poliza` or `dwh.Siniestro` only for row-level questions, and filter on `FechaEmision` / `FechaEmisionPoliza` (partition columns).
- Report `mb_processed` with the answer. The MCP server refuses queries above its bytes ceiling.

## Answer format

Give the number first, then one line of interpretation, then the SQL used. State definitions that matter, e.g. "PAGADO only" or "issue quarter".
