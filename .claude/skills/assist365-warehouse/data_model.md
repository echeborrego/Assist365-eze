# Data model

GCP project `a365-de-ezequiel`, BigQuery location US. Query `dwh` by default; `staging` only for flags not carried to `dwh`.

## dwh: aggregates (use these first)

### `dwh.SiniestralidadMensual`

**Grain:** issue month × issuing country × plan. About 2.3k rows.

| Column | Meaning |
|---|---|
| MesEmision, TrimestreEmision | Issue month / quarter (DATE, first day) |
| PaisEmision, NombrePais | Country code (AR, BR, CL, CO, MX, PE) and name |
| ProductoId, NombrePlan, TipoPlan, EsPremium | Plan (12 plans; TipoPlan: MEDICO, LARGA, CANCELACION, EQUIPAJE, CORPORATIVO) |
| Polizas | Non-cancelled policies sold |
| PolizasAnuladas | Cancelled policies |
| PolizasCoberturaTerminada | Non-cancelled policies whose coverage has ended (maturity numerator) |
| PrimaEmitidaUsd | Written premium, USD |
| SiniestrosPagados, CostoSiniestrosUsd | Paid claims and their USD (cost) |
| SiniestrosPagadosConCobertura | Paid claims on non-cancelled policies (frequency numerator) |
| SiniestrosEnAnalisis, EnAnalisisUsd | Pending claims and USD |
| SiniestrosRechazados | Rejected claims |
| PagadosSinCobertura, PagadoSinCoberturaUsd | Paid claims on cancelled policies or outside coverage dates (leakage) |

### `dwh.SiniestroPorTipo`

**Grain:** issue month × country × plan × claim type. Paid claims only. About 9k rows.

| Column | Meaning |
|---|---|
| MesEmision, TrimestreEmision, PaisEmision, NombrePais, ProductoId, NombrePlan, TipoPlan | As above |
| TipoSiniestro | MEDICO, CANCELACION, EQUIPAJE, DEMORA |
| EsRiesgoDelPlan | FALSE when a single-risk plan (EQUIPAJE, CANCELACION) paid another risk type (assumption) |
| SiniestrosPagados, PagadoUsd | Paid claims and USD |

## dwh: facts and dimensions

### `dwh.Poliza`

**Grain:** one row per policy sold; deleted policies excluded. Partitioned by `FechaEmision` (month), clustered by `PaisEmision, ProductoId`.

| Column | Meaning |
|---|---|
| PolizaId, ClienteId, ProductoId, AgenciaId | Keys |
| PaisEmision, CanalOrigen | Country; sales channel: meta, google, organico, agencia, email |
| FechaEmision | Local date of sale |
| InicioVigencia, FinVigencia | Coverage dates |
| DiasAnticipacion | Days bought ahead of the trip |
| DiasViaje | Trip length |
| EsAnulada | Cancelled |
| EsCoberturaTerminada | Coverage already ended |
| Moneda, PrimaOrigen, FactorUsd | Original currency, original premium, FX factor |
| PrimaUsd | Premium in USD |
| PrimaEmitidaUsd | Premium in USD, 0 if cancelled |

### `dwh.Siniestro`

**Grain:** one row per claim; claims on deleted policies excluded. Partitioned by `FechaEmisionPoliza` (month), clustered by `PaisEmision, ProductoId`.

| Column | Meaning |
|---|---|
| SiniestroId, PolizaId | Keys |
| FechaEmisionPoliza, PaisEmision, ProductoId, CanalOrigen, AgenciaId | From the claim's policy (underwriting basis) |
| FechaOcurrencia, FechaReporte, DiasHastaReporte | Event date, report date, reporting lag |
| Tipo, Estado, Proveedor, Diagnostico, CiudadAtencion | Claim type, status and provider details |
| Moneda, MontoOrigen, FactorUsd, MontoUsd | Amount in original currency and USD |
| EsMontoNegativoOrigen, EsMonedaInferida, EsFechaFutura, EsPolizaInexistente, EsPolizaAnulada, EsFueraDeVigencia | Data-quality flags |
| CuentaParaSiniestralidad | TRUE when the claim counts in official metrics |

### Dimensions

| Table | Key | Columns |
|---|---|---|
| `dwh.Producto` | ProductoId | NombrePlan, TipoPlan, CoberturaMaxUsd, EsPremium |
| `dwh.Agencia` | AgenciaId | NombreAgencia, PaisAgencia, CanalAgencia |
| `dwh.Pais` | PaisId | NombrePais, MonedaLocal, ZonaHoraria |

## Joins

- `dwh.Siniestro.PolizaId = dwh.Poliza.PolizaId`
- `ProductoId → dwh.Producto`
- `AgenciaId → dwh.Agencia`
- `PaisEmision → dwh.Pais.PaisId`
