# Analysis

Figures from the warehouse on 2026-10-27, all in USD. Definitions are in [DECISIONS.md](DECISIONS.md):

- **Written premium** excludes cancelled policies (M2).
- **Claims cost** is `PAGADO` only (M1).
- **Underwriting basis:** each claim counts in its policy's issue period (M4).
- **Excluded from official metrics:** claims dated in the future (D8), on deleted policies (D11) and on policies missing from the source (D13).

Metric formulas:

| Metric | Formula |
|---|---|
| **Loss ratio** | `claims cost / written premium` |
| **Frequency** | `paid claims / policies` |
| **Severity** | `claims cost / paid claims` |
| **Maturity** | Share of policies whose coverage has already ended. Below 1, the cohort will still collect claims. |

## 1. Loss ratio by plan and by country

**Overall:** 733,169 policies, $94.2M written premium, $37.2M claims cost, **loss ratio 0.395**. Frequency is 0.140, severity $362, and $3.3M is still `EN_ANALISIS`. Maturity is 0.978.

### By country

| Country | Policies | Premium | Claims cost | Loss ratio | Frequency | Severity |
|---|---|---|---|---|---|---|
| Chile | 88,284 | $11.02M | $4.40M | **0.400** | 0.139 | $358 |
| Colombia | 131,887 | $16.92M | $6.74M | 0.398 | 0.140 | $366 |
| Argentina | 205,521 | $25.57M | $10.11M | 0.396 | 0.142 | $346 |
| México | 175,567 | $22.87M | $9.03M | 0.395 | 0.139 | $370 |
| Brasil | 58,884 | $8.02M | $3.12M | 0.390 | 0.142 | $375 |
| Perú | 73,026 | $9.83M | $3.81M | 0.387 | 0.140 | $373 |

Over the whole period the countries are within 1.3 points of each other. **By quarter they diverge:**

| Issue quarter | Maturity | AR | BR | CL | CO | MX | PE |
|---|---|---|---|---|---|---|---|
| 2025-Q3 | 1.000 | 0.387 | 0.426 | 0.367 | 0.403 | 0.407 | 0.360 |
| 2025-Q4 | 1.000 | 0.413 | 0.411 | 0.412 | 0.381 | 0.400 | 0.420 |
| 2026-Q1 | 1.000 | 0.421 | 0.382 | **0.450** | 0.376 | 0.407 | 0.354 |
| 2026-Q2 | 0.985 | 0.418 | 0.371 | **0.437** | 0.402 | 0.392 | 0.385 |
| 2026-Q3 | **0.670** | 0.307 | 0.266 | 0.317 | 0.356 | 0.328 | 0.297 |

- **"Which country is doing worst this quarter?" → Chile:** worst in the latest mature quarter (2026-Q2, 0.437) and the one before (2026-Q1, 0.450).
- **2026-Q3 looks cheap because it is immature:** only 67 % of those policies have finished their trip, so their claims are still to come. That quarter is not a good quarter.
- **2026-Q4 has no sales:** the source's last sale is 2026-08-30.

### By plan

| Plan | Policies | Avg premium | Premium | Claims cost | Loss ratio | Frequency | Severity |
|---|---|---|---|---|---|---|---|
| PRD-11 Equipaje Protegido | 43,888 | $31 | $1.38M | $2.04M | **1.481** | 0.136 | $342 |
| PRD-09 Estudiante Larga | 51,390 | $42 | $2.15M | $2.46M | **1.149** | 0.139 | $344 |
| PRD-01 Esencial 30 | 117,595 | $63 | $7.36M | $6.03M | 0.819 | 0.140 | $365 |
| PRD-10 Cancelacion Plus | 58,404 | $76 | $4.46M | $2.81M | 0.630 | 0.135 | $356 |
| PRD-02 Esencial 60 | 95,558 | $83 | $7.94M | $4.82M | 0.607 | 0.139 | $364 |
| PRD-07 Senior 100 | 43,861 | $108 | $4.72M | $2.25M | 0.476 | 0.138 | $371 |
| PRD-04 Clasico Plus 150 | 66,341 | $135 | $8.97M | $3.33M | 0.372 | 0.139 | $363 |
| PRD-12 Corporativo Anual | 29,399 | $159 | $4.66M | $1.52M | 0.325 | 0.146 | $353 |
| PRD-05 Premium 250 | 58,351 | $188 | $10.94M | $3.12M | 0.285 | 0.149 | $359 |
| PRD-03 Clasico 100 | 102,462 | $215 | $22.04M | $5.37M | 0.244 | 0.139 | $378 |
| PRD-06 Premium Total 500 | 36,534 | $276 | $10.08M | $1.93M | 0.192 | 0.146 | $363 |
| PRD-08 Senior Premium 200 | 29,386 | $324 | $9.53M | $1.52M | 0.160 | 0.146 | $355 |

- **"Which plan destroys margin?" → Equipaje Protegido and Estudiante Larga** pay out more than they collect (loss ratio > 1). Esencial 30 (0.82) leaves little margin once costs are added.
- **"Frequency or average amount?" → neither.**
  - Frequency is 0.135–0.149 on every plan, and severity $342–$378.
  - What separates the plans is the **price**: $31 against $324 per policy.
  - Equipaje Protegido collects $31 per policy and pays $342 per claim at a 13.6 % claim rate: it loses money by construction.

## 2. The insight nobody asked for: single-risk plans pay mostly medical claims

Every plan type pays the **same mix of claim types**, whatever the catalogue says it is.

| Plan type | Medical share of USD paid |
|---|---|
| MEDICO | 77.3 % |
| CANCELACION | 77.4 % |
| CORPORATIVO | 77.2 % |
| LARGA | 75.2 % |
| EQUIPAJE | 75.1 % |

By claim count:

| Plan type | Paid claims | Medical | Luggage | Cancellation | Delay |
|---|---|---|---|---|---|
| EQUIPAJE (luggage only) | 5,980 | **54.9 %** | 20.1 % | 15.7 % | 9.3 % |
| CANCELACION (cancellation only) | 7,896 | **55.7 %** | 19.7 % | 14.1 % | 10.6 % |
| MEDICO | 77,556 | 54.8 % | 20.0 % | 15.0 % | 10.2 % |
| LARGA | 7,162 | 53.6 % | 19.9 % | 16.4 % | 10.1 % |
| CORPORATIVO | 4,297 | 54.3 % | 20.8 % | 14.6 % | 10.3 % |

The two single-risk plans paid **$4.33M for claims outside their own risk**, or 11.6 % of all claims cost:

| Plan | Paid outside its risk | Share of the plan's cost |
|---|---|---|
| Equipaje Protegido | $1.86M | 91 % |
| Cancelacion Plus | $2.47M | 88 % |

**What the plans cover is an assumption (INFERRED).** The API does not list each plan's coverage. The catalogue's `tipo` field classifies PRD-11 as `EQUIPAJE` (cap $3,000) and PRD-10 as `CANCELACION` (cap $10,000), separately from the seven `MEDICO` plans. A cancellation "Plus" plan could include some assistance.

**The amount cap holds per claim, not always per policy (PROVEN):**

- **Per claim:** no claim in any status exceeds its plan's `cobertura_max_usd`. On low-cap plans the largest claim sits just under the cap: Equipaje Protegido $2,918 of $3,000, Esencial 30 $28,759 of $30,000, Cancelacion Plus $9,267 of $10,000.
- **Per policy:** adding up each policy's paid claims, **12 policies exceed the cap**. That is 11 on Equipaje Protegido (up to $3,517) and one on Cancelacion Plus ($12,171). Whether the cap is per event or per policy is not in the data.

If the plan type were enforced (assuming a single-risk plan should only pay its own risk):

| Plan | Loss ratio today | Loss ratio enforced |
|---|---|---|
| Equipaje Protegido | 1.481 | **0.134** |
| Cancelacion Plus | 0.630 | **0.076** |
| Company | 0.395 | **0.349** |

Either way the business has a problem to fix. If these plans do not cover medical events, the most "margin-destroying" plan is a claims-adjudication problem; if they do, it is a pricing problem.

**What the business should check first:** whether the provider validates the plan's coverage before paying. If plan types are only commercial labels with full coverage behind them, the luggage plan is underpriced: it would need about 3.7x its current premium to reach the company's 0.395 loss ratio.

### Smaller leaks, same theme

| Leak | Paid claims | USD |
|---|---|---|
| On cancelled policies | 333 | $148,885 |
| With the event outside the policy's coverage dates | 906 | $320,108 |
| On policies that do not exist in the source (not in any metric) | 447 | $145,582 |

### Pricing oddity

**Clasico 100** (US$100k cover) averages **$215** per policy, while **Clasico Plus 150** (US$150k cover) averages **$135**. The plan with less cover is sold at a higher price.

## 3. Queries

Every figure above comes from these queries. They run in under 1 MB on `dwh.SiniestralidadMensual`, or about 26 MB on `dwh.Siniestro`.

```sql
-- Loss ratio, frequency, severity and maturity by country (swap NombrePais for NombrePlan by plan)
SELECT
    a.NombrePais
    , SUM(a.Polizas) AS Polizas
    , ROUND(SUM(a.PrimaEmitidaUsd), 0) AS PrimaUsd
    , ROUND(SUM(a.CostoSiniestrosUsd), 0) AS CostoUsd
    , ROUND(SAFE_DIVIDE(SUM(a.CostoSiniestrosUsd), SUM(a.PrimaEmitidaUsd)), 3) AS Siniestralidad
    , ROUND(SAFE_DIVIDE(SUM(a.SiniestrosPagados), SUM(a.Polizas)), 3) AS Frecuencia
    , ROUND(SAFE_DIVIDE(SUM(a.CostoSiniestrosUsd), SUM(a.SiniestrosPagados)), 0) AS SeveridadUsd
    , ROUND(SAFE_DIVIDE(SUM(a.PolizasCoberturaTerminada), SUM(a.Polizas)), 3) AS Madurez
FROM dwh.SiniestralidadMensual a
GROUP BY 1
ORDER BY 5 DESC
```

```sql
-- Loss ratio by issue quarter and country, with cohort maturity
SELECT
    FORMAT_DATE("%Y-Q%Q", a.TrimestreEmision) AS Trimestre
    , a.PaisEmision
    , ROUND(SAFE_DIVIDE(SUM(a.CostoSiniestrosUsd), SUM(a.PrimaEmitidaUsd)), 3) AS Siniestralidad
    , ROUND(SAFE_DIVIDE(SUM(a.PolizasCoberturaTerminada), SUM(a.Polizas)), 3) AS Madurez
FROM dwh.SiniestralidadMensual a
GROUP BY 1, 2
ORDER BY 1, 3 DESC
```

```sql
-- Paid claim type mix by plan type, spend outside a single-risk plan's own risk, and the coverage cap check
WITH Pagados AS (
    SELECT
        d.TipoPlan
        , d.CoberturaMaxUsd
        , s.Tipo
        , s.MontoUsd
    FROM dwh.Siniestro s
    JOIN dwh.Producto d ON d.ProductoId = s.ProductoId
    WHERE s.CuentaParaSiniestralidad
        AND s.Estado = "PAGADO"
)
SELECT
    TipoPlan
    , COUNT(*) AS Pagados
    , ROUND(AVG(IF(Tipo = "MEDICO", 1, 0)), 3) AS PctMedico
    , ROUND(AVG(IF(Tipo = "EQUIPAJE", 1, 0)), 3) AS PctEquipaje
    , ROUND(AVG(IF(Tipo = "CANCELACION", 1, 0)), 3) AS PctCancelacion
    , ROUND(AVG(IF(Tipo = "DEMORA", 1, 0)), 3) AS PctDemora
    , ROUND(SUM(IF(TipoPlan IN ("EQUIPAJE", "CANCELACION") AND Tipo != TipoPlan, MontoUsd, 0)), 0) AS PagadoFueraDelTipoUsd
    , COUNTIF(MontoUsd > CoberturaMaxUsd) AS SobreTopeCobertura
FROM Pagados
GROUP BY 1
ORDER BY 1
```

```sql
-- Leakage: paid on cancelled policies, outside coverage dates, and on unknown policies
SELECT
    COUNTIF(EsPolizaAnulada) AS PagadosPolizaAnulada
    , ROUND(SUM(IF(EsPolizaAnulada, MontoUsd, 0)), 0) AS UsdPolizaAnulada
    , COUNTIF(EsFueraDeVigencia AND NOT EsPolizaAnulada) AS PagadosFueraVigencia
    , ROUND(SUM(IF(EsFueraDeVigencia AND NOT EsPolizaAnulada, MontoUsd, 0)), 0) AS UsdFueraVigencia
FROM dwh.Siniestro
WHERE CuentaParaSiniestralidad
    AND Estado = "PAGADO"
```
