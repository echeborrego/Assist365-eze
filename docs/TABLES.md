# Table review sheet

Every table the pipeline builds, layer by layer: grain, where each column comes from, the rule applied, and real rows.
Figures are from 2026-10-27. Tables were renamed to PascalCase on 2026-10-27: the **Proposed name** column is now the current name, and the first name shown is the former one.

Flow: `API JSON → raw (record kept as-is) → staging (typed, cleaned, flagged) → dwh (star schema + dashboard aggregate)`.

---

## 1. raw: the API record, untouched

All five data tables share one shape, so a provider schema change can never break a load:

| Column | Type | Meaning |
|---|---|---|
| `Payload` | JSON | The API record exactly as received (only `NaN` → `null`, see P5) |
| `RunId` | STRING | Extraction run that loaded it (joins `raw.extract_runs`) |
| `ExtractedAt` | TIMESTAMP | When the run started spooling; partition column where partitioned |
| `Page` | INTEGER | API page the record came from |

| Table | Proposed name | Rows | Load | Partition | Notes |
|---|---|---|---|---|---|
| `raw.polizas` | `raw.Poliza` | 1,012,227 | Append (CDC log) | `ExtractedAt` day | 1,003,461 from the first full pull plus incremental overlap pages. One row per change event, not per policy. |
| `raw.siniestros` | `raw.Siniestro` | 694,810 | Append (daily snapshot) | `ExtractedAt` day | **5 full snapshots of 138,962** from today's test runs. In production that's one per day (growth: N2). |
| `raw.catalogo_productos` | `raw.CatalogoProducto` | 12 | Truncate | — | |
| `raw.catalogo_agencias` | `raw.CatalogoAgencia` | 300 | Truncate | — | |
| `raw.catalogo_tipo_cambio` | `raw.CatalogoTipoCambio` | 5,124 | Truncate | — | |
| `raw.extract_runs` | `raw.ExtractRun` | 21 | Append | — | Audit: one row per source per run (status, pages, rows received/expected/loaded, retries, watermark, error). |

---

## 2. staging: typed, cleaned, flagged

### `staging.productos` → `staging.Producto`. Grain: one row per plan. 12 rows.

| Column | From | Type | Rule |
|---|---|---|---|
| ProductoId | `producto_id` | STRING | |
| NombrePlan | `nombre_plan` | STRING | |
| TipoPlan | `tipo` | STRING | MEDICO, LARGA, CANCELACION, EQUIPAJE, CORPORATIVO |
| CoberturaMaxUsd | `cobertura_max_usd` | INT64 | The API sends it as a string |
| EsPremium | `es_premium` | BOOL | `"1"` → true |

### `staging.agencias` → `staging.Agencia`. Grain: one row per agency. 300 rows.

| Column | From | Type | Rule |
|---|---|---|---|
| AgenciaId | `agencia_id` | STRING | |
| NombreAgencia | `nombre` | STRING | |
| PaisAgencia | `pais` | STRING | |
| CanalAgencia | `canal` | STRING | ONLINE / PARTNER / CALL_CENTER. **A different concept from the policy's `canal_origen`.** |

### `staging.tipo_cambio` → `staging.TipoCambio`. Grain: one row per currency per **calendar** day. 7,266 rows (5,124 quotes).

| Column | From | Type | Rule |
|---|---|---|---|
| Fecha | generated calendar | DATE | From a week before the first quote up to today (D5, D6) |
| Moneda | `moneda` | STRING | ARS, BRL, CLP, COP, MXN, PEN, USD |
| UnidadesPorUsd | `unidades_por_usd` | NUMERIC | Last quote on or before `Fecha`; before the first quote, the first one |
| FactorUsd | `factor_usd` | NUMERIC | Same carry rule; `amount × FactorUsd` = USD |
| FechaCotizacion | quote date | DATE | The date of the quote actually used |
| EsArrastrado | — | BOOL | True on weekends and holidays (rate carried from an earlier day) |

### `staging.polizas` → `staging.Poliza`. Grain: one row per `poliza_id`, latest state in the CDC stream. 800,000 rows (20,000 deleted).

Incremental MERGE (P8). Deletes are kept, flagged (D9).

| Column | From | Type | Rule |
|---|---|---|---|
| PolizaId | `poliza_id` | STRING | Key |
| ClienteId, ProductoId, AgenciaId | `cliente_id`, `producto_id`, `agencia_id` | STRING | |
| PaisEmision | `pais_emision` | STRING | |
| CanalOrigen | `canal_origen` | STRING | meta, google, organico, agencia, email |
| FechaEmisionUtc | `fecha_emision_utc` | TIMESTAMP | |
| FechaEmision | `fecha_emision_utc` | DATE | **Local date of the issuing country** (D10) |
| InicioVigencia, FinVigencia | `inicio_vigencia`, `fin_vigencia` | DATE | Midnight UTC timestamps → date |
| Prima | `prima` | NUMERIC | In `Moneda` |
| Moneda | `moneda` | STRING | Local currency, or USD on ~7 % of policies (D14) |
| Estado | `estado` | STRING | Only `ANULADA` is trusted (D15) |
| IsDeleted | `op = "D"` | BOOL | |
| UltimaOp | `op` | STRING | Tie-break: D > U > I |
| UpdatedAt | `updated_at` | TIMESTAMP | Picks the latest change |
| ExtractedAt | raw `ExtractedAt` | TIMESTAMP | Which load delivered the winning change |

Real CDC history → staging row:

```
POL-00000016  I  2026-02-23  EMITIDA   prima 229896.94 CLP
              U  2026-03-15  ANULADA
  staging → Estado ANULADA, IsDeleted false, UltimaOp U

POL-00000043  I  2024-12-28  EMITIDA   coverage 2025-02-02 .. 2025-02-05
              U  2025-01-24  VENCIDA   ← "expired" 9 days BEFORE coverage starts (D15)
              D  2025-05-13  EMITIDA   ← the delete event carries the original insert's estado
  staging → IsDeleted true, Estado EMITIDA, UltimaOp D
```

### `staging.siniestros` → `staging.Siniestro`. Grain: one row per `claim_id` from the latest successful snapshot. 138,133 rows.

| Column | From | Type | Rule |
|---|---|---|---|
| SiniestroId | `claim_id` | STRING | 829 exact duplicates collapsed (D1) |
| PolizaId | `policy_id` | STRING | |
| FechaOcurrencia | `occurred_at` | DATE | ISO or `dd/mm/yyyy` (D2) |
| FechaReporte | `reported_at` | DATE | Same |
| Tipo | `type` | STRING | MEDICO, CANCELACION, EQUIPAJE, DEMORA |
| Estado | `status` | STRING | PAGADO, RECHAZADO, EN_ANALISIS |
| Monto | `amount.value` | NUMERIC | String → number, **absolute value** (D7) |
| Moneda | `amount.currency` | STRING | If `NaN`/null → the policy's currency (D3) |
| Proveedor | `detail.proveedor` | STRING | |
| Diagnostico | `detail.diagnostico` or `detail.diagnosis` | STRING | Spanish and English keys coalesced (D4) |
| CiudadAtencion | `detail.ciudad_atencion` or `detail.city` | STRING | Same |
| DetalleOrigen | `detail` | JSON | Kept for audit |
| FechaPrimeraVez | `siniestros_primera_vez` | DATE | First snapshot that contained the claim |
| EsMontoNegativoOrigen | `amount.value < 0` | BOOL | 824 |
| EsMonedaInferida | `currency` null | BOOL | 411 |
| EsFechaFutura | `FechaOcurrencia > FechaPrimeraVez` | BOOL | 2,138; never expires (D8) |
| EsPolizaInexistente | no policy | BOOL | 552 (D13) |
| EsPolizaEliminada | policy `IsDeleted` | BOOL | 3,473 (D11) |
| EsPolizaAnulada | policy `ANULADA` | BOOL | 438 (D12) |
| EsFueraDeVigencia | occurred outside coverage | BOOL | 1,242 (D12) |
| EsReporteAntesDeOcurrencia | reported < occurred | BOOL | 0 |

Real raw JSON → staging, one per rule:

| Case | Raw (relevant fields) | Staging |
|---|---|---|
| Negative amount | SIN-00000395 `"value":"-3588.74"`, MXN, `PAGADO` | Monto 3588.74, EsMontoNegativoOrigen true |
| Currency `NaN` | SIN-00000198 `"currency":null`, policy POL-00230728 in ARS | Moneda ARS, EsMonedaInferida true |
| dd/mm date + future | SIN-00000033 `"occurred_at":"05/12/2026"`, `PAGADO` | FechaOcurrencia 2026-12-05, EsFechaFutura true |
| Outside coverage | SIN-00000017 occurred 2026-08-01, `"reported_at":"02/08/2026"` | FechaReporte 2026-08-02, EsFueraDeVigencia true |
| English detail | SIN-00000001 `{"city":"Bogota","diagnosis":"fever"}` | CiudadAtencion Bogota, Diagnostico fever |

### Helper tables

| Table | Proposed name | Grain | Purpose |
|---|---|---|---|
| `staging.siniestros_primera_vez` | `staging.SiniestroPrimeraVez` | one row per claim | First snapshot each claim appeared in: the creation date the API lacks (D8). Insert-only. |
| `staging.watermarks` | `staging.Watermark` | one row per incremental model | How far into raw each incremental model has processed (`polizas` today). |

---

## 3. dwh: star schema

### Dimensions

| Table | Proposed name | Grain | Rows | Columns |
|---|---|---|---|---|
| `dwh.dim_producto` | `dwh.Producto` | plan | 12 | ProductoId, NombrePlan, TipoPlan, CoberturaMaxUsd, EsPremium |
| `dwh.dim_agencia` | `dwh.Agencia` | agency | 300 | AgenciaId, NombreAgencia, PaisAgencia, CanalAgencia |
| `dwh.dim_pais` | `dwh.Pais` | issuing country | 6 | PaisId, NombrePais, MonedaLocal, ZonaHoraria (hand-written list) |

### `dwh.fct_ventas` → `dwh.Poliza`. Grain: one row per policy sold. 780,000 rows.

Partitioned by `FechaEmision` (month), clustered by `PaisEmision, ProductoId`.
800,000 staging policies − 20,000 deleted (D9) = 780,000 (`layer_counts_reconcile` checks this).

| Column | Derivation |
|---|---|
| PolizaId … FinVigencia | From `staging.polizas` |
| DiasAnticipacion | `InicioVigencia − FechaEmision` (the glossary's "anticipación de compra") |
| DiasViaje | `FinVigencia − InicioVigencia + 1` (inclusive) |
| EsAnulada | `Estado = ANULADA` |
| EsCoberturaTerminada | `FinVigencia < today`; drives cohort maturity (M4) |
| Moneda, PrimaOrigen, FactorUsd | Original premium and the FX factor of the issue date |
| PrimaUsd | `PrimaOrigen × FactorUsd` |
| PrimaEmitidaUsd | `PrimaUsd`, or 0 when cancelled (M2) |

Real row: POL-00000016, CL, issued 2026-02-23, coverage 06-15 → 07-07 (112 days ahead, 23-day trip), 229,896.94 CLP × 0.00094886 = **PrimaUsd 218.14**, cancelled → **PrimaEmitidaUsd 0**.

### `dwh.fct_siniestros` → `dwh.Siniestro`. Grain: one row per claim. 134,660 rows.

Partitioned by `FechaEmisionPoliza` (month), clustered by `PaisEmision, ProductoId`.
138,133 staging claims − 3,473 on deleted policies (D11) = 134,660.

| Column | Derivation |
|---|---|
| FechaEmisionPoliza, PaisEmision, ProductoId, CanalOrigen, AgenciaId | **From the claim's policy**: underwriting basis (M4) |
| FechaOcurrencia, FechaReporte, Tipo, Estado, Proveedor, Diagnostico, CiudadAtencion | From staging |
| DiasHastaReporte | `FechaReporte − FechaOcurrencia` |
| Moneda, MontoOrigen, FactorUsd, MontoUsd | FX at the occurrence date (M3) |
| Es… flags | Carried from staging |
| CuentaParaSiniestralidad | Not future-dated and the policy exists: the official-metrics filter |

### `dwh.agg_siniestralidad_mensual` → `dwh.SiniestralidadMensual`. Grain: issue month × country × plan. 2,328 rows.

A second aggregate, `dwh.SiniestroPorTipo` (the same grain × claim type, paid claims only, 8,961 rows), feeds the dashboard's claim-type chart. Column-level detail for both is in `.claude/skills/assist365-warehouse/data_model.md`.

Parked for the dashboard phase. Feeds the dashboard; `agg_reconciles_with_facts` checks that it adds up to the facts.

---

## 4. Things noticed while building this sheet

1. **A policy can be `VENCIDA` before its coverage starts:** POL-00000043 expired 2025-01-24, but its coverage begins 2025-02-02. More evidence for D15: only `ANULADA` is trusted.
2. **A delete event carries the original insert's `estado`** (`EMITIDA`), not the latest one, so a deleted policy's `Estado` in staging is not meaningful.
3. **Diagnosis does not match the claim type:** luggage claims with diagnosis "fever" (SIN-00000017, `EQUIPAJE`). Combined with the identical claim-type mix across plan types, the provider's `detail` looks unreliable as a description of the event.
4. **Mixed language in names:** business columns are in Spanish (`FechaEmision`), while the pipeline metadata is in English (`RunId`, `ExtractedAt`, `IsDeleted`). Worth settling with the rename.
