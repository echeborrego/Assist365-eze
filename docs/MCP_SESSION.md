 ▐▛███▛█   Claude Code v2.1.312
▝▜██████▀  Opus 5.5 · Claude Pro
 ▝▝   ▝▝   ~/Documents/Eche/Assist365-eze/.claude/skills/assist365-warehouse


❯ ¿Qué país tuvo la peor siniestralidad en el último trimestre cerrado?         

⏺ Skill(assist365-warehouse)
  ⎿  Successfully loaded skill

  Called assist365-bigquery, ran 1 shell command (ctrl+o to expand)

⏺ Chile, with a loss ratio of 0.437 in 2026-Q2. That is the last closed quarter,
  with maturity at 0.985.

  ┌───────────┬────────────────┬────────────┬──────────────┬────────────────┐
  │   País    │ Siniestralidad │ Frecuencia │  Severidad   │  Prima media   │
  │           │                │            │     USD      │      USD       │
  ├───────────┼────────────────┼────────────┼──────────────┼────────────────┤
  │ Chile     │ 0.437          │ 0.140      │ 375          │ 119.8          │
  ├───────────┼────────────────┼────────────┼──────────────┼────────────────┤
  │ Argentina │ 0.418          │ 0.150      │ 329          │ 118.1          │
  ├───────────┼────────────────┼────────────┼──────────────┼────────────────┤
  │ Colombia  │ 0.402          │ 0.140      │ 344          │ 120.1          │
  ├───────────┼────────────────┼────────────┼──────────────┼────────────────┤
  │ México    │ 0.392          │ 0.142      │ 361          │ 130.9          │
  ├───────────┼────────────────┼────────────┼──────────────┼────────────────┤
  │ Perú      │ 0.385          │ 0.140      │ 379          │ 138.2          │
  ├───────────┼────────────────┼────────────┼──────────────┼────────────────┤
  │ Brasil    │ 0.371          │ 0.151      │ 348          │ 141.9          │
  └───────────┴────────────────┴────────────┴──────────────┴────────────────┘

  Why Chile: Chile's frequency is about the same as everyone else's (0.140), so
  the problem isn't more claims. It's the combination of the third-highest
  severity (USD 375 per claim) and the second-lowest average premium (USD
  119.8). Perú and Brasil also pay out a lot per claim, but they charge USD
  138–142 per policy, which absorbs it. Chile was also the worst country in
  2026-Q1 (0.450), so this isn't a one-quarter blip.

  Notes:
  - 2026-Q3 isn't closed yet: maturity is only 0.67, so its loss ratios
    (0.27–0.36) look better than they will end up.
  - The cost counts PAGADO claims only. Claims are attributed to the quarter the
    policy was sold in, not when they happened. Ratios are a ratio of sums.
  - The query scanned 0.188 MB.

  SELECT
      FORMAT_DATE("%Y-Q%Q", a.TrimestreEmision) AS Trimestre
      , a.NombrePais
      , ROUND(SAFE_DIVIDE(SUM(a.CostoSiniestrosUsd), SUM(a.PrimaEmitidaUsd)), 3)
  AS Siniestralidad
      , ROUND(SAFE_DIVIDE(SUM(a.SiniestrosPagadosConCobertura), SUM(a.Polizas)),
  3) AS Frecuencia
      , ROUND(SAFE_DIVIDE(SUM(a.CostoSiniestrosUsd), SUM(a.SiniestrosPagados)),
  0) AS SeveridadUsd
      , ROUND(SAFE_DIVIDE(SUM(a.PrimaEmitidaUsd), SUM(a.Polizas)), 1) AS
  PrimaMediaUsd
      , ROUND(SAFE_DIVIDE(SUM(a.PolizasCoberturaTerminada), SUM(a.Polizas)), 3)
  AS Madurez
  FROM dwh.SiniestralidadMensual a
  WHERE a.TrimestreEmision >= "2025-10-01"
  GROUP BY 1, 2
  ORDER BY 1, 3 DESC

  Rolling, mate. If you want to know which Chilean plans are dragging the number
  up, the next step is splitting Chile Q2 by NombrePlan.

✻ Cogitated for 34s · done 6:44 p. m.

❯ ¿Qué plan destruye más margen? ¿Es por frecuencia, por severidad o por        
  precio?                                                                       

  Called assist365-bigquery 2 times (ctrl+o to expand)

⏺ Equipaje Protegido destroys the most margin: loss ratio 1.50, a technical 
  margin of −USD 649k. Estudiante Larga comes second at 1.16 (−USD 325k). They
  are the only two plans paying out more in claims than they collect in premium.
  The cause is price, not frequency or severity.

  I used every cohort that's mature (issue quarter ≤ 2026-Q2, maturity ≥ 0.998).
  Technical margin here is premium minus PAGADO cost. There's no expense or
  commission data, so it isn't the full P&L.

  Plan: Equipaje Protegido
  Siniestralidad: 1.500
  Margen técnico USD: −649k
  Frecuencia: 0.138
  Severidad USD: 342
  Costo/póliza USD: 47.3
  Prima media USD: 31.5
  ────────────────────────────────────────
  Plan: Estudiante Larga
  Siniestralidad: 1.161
  Margen técnico USD: −325k
  Frecuencia: 0.141
  Severidad USD: 344
  Costo/póliza USD: 48.6
  Prima media USD: 41.8
  ────────────────────────────────────────
  Plan: Esencial 30
  Siniestralidad: 0.832
  Margen técnico USD: +1.16M
  Frecuencia: 0.142
  Severidad USD: 366
  Costo/póliza USD: 52.2
  Prima media USD: 62.7
  ────────────────────────────────────────
  Plan: Cancelacion Plus
  Siniestralidad: 0.641
  Margen técnico USD: +1.50M
  Frecuencia: 0.137
  Severidad USD: 356
  Costo/póliza USD: 48.9
  Prima media USD: 76.4
  ────────────────────────────────────────
  Plan: …
  Siniestralidad:
  Margen técnico USD:
  Frecuencia:
  Severidad USD:
  Costo/póliza USD:
  Prima media USD:
  ────────────────────────────────────────
  Plan: Senior Premium 200
  Siniestralidad: 0.161
  Margen técnico USD: +7.52M
  Frecuencia: 0.147
  Severidad USD: 353
  Costo/póliza USD: 52.1
  Prima media USD: 324.5
  ────────────────────────────────────────
  Plan: Portfolio
  Siniestralidad: 0.400
  Margen técnico USD: +53.1M
  Frecuencia: 0.142
  Severidad USD: 362
  Costo/póliza USD: 51.5
  Prima media USD: 128.8

  Why it's price: frequency (0.137–0.151) and severity (USD 342–379) are almost
  flat across all 12 plans. So cost per policy lands around USD 47–55 for every
  plan. The loss ratio is simply that ~USD 51 cost divided by the premium, and
  Equipaje charges USD 31.5. As a check, the identity holds: 0.138 × 342 / 31.5
  = 1.50.

  The real story is why the cost is the same: a baggage-only plan costs the same
  per policy as Premium Total 500 or Senior. That shouldn't happen. Breaking
  down what each plan pays:
  - Of what Equipaje Protegido pays out, 75.5% is MEDICO and only 8.9% is
    EQUIPAJE.
  - Estudiante Larga (75.3% medical) and Premium Total 500 (77.4%) have
    essentially the same mix.

  So "it's the price" is the diagnosis, but the root cause is one of two things
  (INFERRED, not proven):
  1. Leakage: a plan classified as baggage is paying medical claims it shouldn't
     cover. Then the fix is claims control, not raising the price.
  2. The source doesn't assign claims by plan risk (it looks synthetic or
     loosely joined), so the comparison by plan isn't reliable.

  Remember that what a plan covers isn't in the data; TipoPlan comes from the
  catalogue. Before anyone touches Equipaje's price, someone with the policy
  terms needs to confirm whether it covers medical. If it doesn't, the ~USD
  1.47M in medical payouts is the leak to chase.

  The queries scanned 0.264 MB and 0.448 MB.

  -- Plan metrics, mature cohorts
  SELECT
      a.NombrePlan
      , a.TipoPlan
      , ROUND(SUM(a.PrimaEmitidaUsd) - SUM(a.CostoSiniestrosUsd), 0) AS
  MargenTecnicoUsd
      , ROUND(SAFE_DIVIDE(SUM(a.CostoSiniestrosUsd), SUM(a.PrimaEmitidaUsd)), 3)
  AS Siniestralidad
      , ROUND(SAFE_DIVIDE(SUM(a.SiniestrosPagadosConCobertura), SUM(a.Polizas)),
  3) AS Frecuencia
      , ROUND(SAFE_DIVIDE(SUM(a.CostoSiniestrosUsd), SUM(a.SiniestrosPagados)),
  0) AS SeveridadUsd
      , ROUND(SAFE_DIVIDE(SUM(a.PrimaEmitidaUsd), SUM(a.Polizas)), 1) AS
  PrimaMediaUsd
  FROM dwh.SiniestralidadMensual a
  WHERE a.TrimestreEmision <= "2026-04-01"
  GROUP BY 1, 2
  ORDER BY 4 DESC;

  -- Claim-type mix
  SELECT
      t.NombrePlan
      , t.TipoSiniestro
      , ROUND(SUM(t.PagadoUsd), 0) AS PagadoUsd
      , ROUND(SAFE_DIVIDE(SUM(t.PagadoUsd), SUM(SUM(t.PagadoUsd)) OVER
  (PARTITION BY t.NombrePlan)), 3) AS ShareUsd
  FROM dwh.SiniestroPorTipo t
  WHERE t.TrimestreEmision <= "2026-04-01"
  GROUP BY 1, 2
  ORDER BY 1, 3 DESC;

  Rolling on the numbers, lad, but there's a stink on the source: a baggage plan
  that's three-quarters medical claims is either leaking cash or the data is
  lying about which plan pays for what.

✻ Crunched for 40s · done 6:45 p. m.

❯ ¿Cuánto pagaron los planes de equipaje y de cancelación en siniestros de otro 
  tipo de riesgo?                                                               

  Called assist365-bigquery (ctrl+o to expand)

⏺ USD 4.33M across both plans, which is 89% of everything they paid. On paper
  they cover a single risk each, but nearly all their payouts went to other
  kinds of claims.

  ┌────────────────┬─────────────────┬──────────┬───────┬──────────────────┐
  │      Plan      │ Pagado fuera de │  Total   │ Share │ Siniestros fuera │
  │                │    su riesgo    │  pagado  │       │      / total     │
  ├────────────────┼─────────────────┼──────────┼───────┼──────────────────┤
  │ Cancelacion    │ USD 2.47M       │ 2.81M    │ 0.879 │ 6,786 / 7,896    │
  │ Plus           │                 │          │       │                  │
  ├────────────────┼─────────────────┼──────────┼───────┼──────────────────┤
  │ Equipaje       │ USD 1.86M       │ 2.04M    │ 0.909 │ 4,777 / 5,980    │
  │ Protegido      │                 │          │       │                  │
  ├────────────────┼─────────────────┼──────────┼───────┼──────────────────┤
  │ Total          │ USD 4.33M       │ 4.85M    │ 0.892 │ 11,563 / 13,876  │
  └────────────────┴─────────────────┴──────────┴───────┴──────────────────┘

  Breakdown by claim type paid outside the plan's own risk:
  - Cancelacion Plus: MEDICO USD 2.17M (77.4% of what it pays), EQUIPAJE USD
    230k, DEMORA USD 65k. It only paid USD 341k (12.1%) on actual cancellations.
  - Equipaje Protegido: MEDICO USD 1.54M (75.1%), CANCELACION USD 283k, DEMORA
    USD 39k. It only paid USD 185k (9.1%) on actual baggage claims.

  What it means: the mix in both plans (~75% medical, ~13% cancellation, ~9%
  baggage, ~2% delay) is the same as in the comprehensive medical plans. The
  pattern is identical whatever the plan is. That looks more like claims 
  assigned to plans without regard to risk (synthetic or badly joined source)
  than real leakage. Real leakage wouldn't reproduce the portfolio's exact mix
  in every plan. This is INFERRED, not proven.

  To get to the bottom of it:
  1. Get the terms for both plans and confirm whether they really exclude
     medical. TipoPlan comes from the catalogue, so the data only says they're
     classified as single-risk.
  2. Look at the PAGADO MEDICO claims on Equipaje Protegido row by row in
     dwh.Siniestro (provider, diagnosis, whether the claim's plan matches the
     policy's). If the source reliably links claims to policies, it's leakage.
     If not, it's the data.

  To put a size on it: if Equipaje only paid baggage claims, its USD 1.30M of
  mature premium against ~USD 0.17M of own-risk cost would make it one of the
  most profitable plans in the portfolio, not the worst.

  Caveats:
  - EsRiesgoDelPlan is an assumption in the model, not a field from the source.
    It counts DEMORA as outside the baggage plan's risk, but baggage delay could
    well be covered. That's USD 39k, so it doesn't move the conclusion.
  - These figures include every cohort, the immature Q3 2026 included, so
    they're a bit higher than last answer's table (Equipaje MEDICO was 1.47M on
    mature cohorts only, 1.54M here).
  - The query scanned 0.537 MB.

  SELECT
      t.NombrePlan
      , t.TipoSiniestro
      , t.EsRiesgoDelPlan
      , SUM(t.SiniestrosPagados) AS SiniestrosPagados
      , ROUND(SUM(t.PagadoUsd), 0) AS PagadoUsd
      , ROUND(SAFE_DIVIDE(SUM(t.PagadoUsd), SUM(SUM(t.PagadoUsd)) OVER
  (PARTITION BY t.NombrePlan)), 3) AS ShareUsd
  FROM dwh.SiniestroPorTipo t
  WHERE t.TipoPlan IN ("EQUIPAJE", "CANCELACION")
  GROUP BY 1, 2, 3
  ORDER BY 1, 5 DESC

  Busted, mate. It's not your query, it's the source. Single-risk plans paying
  the same claim mix as a full medical plan smells of rubbish data, so I'd sort
  that out before anyone uses these numbers to reprice.

✻ Crunched for 25s · done 6:47 p. m.

❯ ¿Qué canal de venta compra con más anticipación respecto del viaje?           

  Called assist365-bigquery (ctrl+o to expand)

⏺ None of them, really. All five channels buy about 49.5–49.8 days before the 
  trip, with a median of 47–48 days. meta and google come out on top at 49.8
  days on average, but that's a 0.3-day spread, which is noise with 73k–190k
  policies per channel.

  ┌──────────┬─────────┬───────────────┬─────┬─────────┬─────┐
  │  Canal   │ Pólizas │ Días promedio │ P25 │ Mediana │ P75 │
  ├──────────┼─────────┼───────────────┼─────┼─────────┼─────┤
  │ meta     │ 161,172 │ 49.8          │ 11  │ 47      │ 83  │
  ├──────────┼─────────┼───────────────┼─────┼─────────┼─────┤
  │ google   │ 190,550 │ 49.8          │ 11  │ 48      │ 83  │
  ├──────────┼─────────┼───────────────┼─────┼─────────┼─────┤
  │ organico │ 131,740 │ 49.7          │ 12  │ 48      │ 83  │
  ├──────────┼─────────┼───────────────┼─────┼─────────┼─────┤
  │ agencia  │ 176,386 │ 49.6          │ 12  │ 48      │ 84  │
  ├──────────┼─────────┼───────────────┼─────┼─────────┼─────┤
  │ email    │ 73,321  │ 49.5          │ 11  │ 47      │ 83  │
  └──────────┴─────────┴───────────────┴─────┴─────────┴─────┘

  What it means: the whole distribution is the same for every channel, not just
  the average. In the real world you'd expect agencies (people planning trips
  ahead) to buy well in advance and paid search to catch the last-minute buyer.
  Here they're all the same.

  This is the same pattern as the last two questions: plan, claim type and now
  channel make no difference. That's more evidence (still INFERRED) that the 
  source is generated with independent, uniform distributions. Any question like
  "which segment does X more" will return a near tie. I'd stop slicing by
  segment until we've confirmed whether this is real data.

  Notes:
  - I counted non-cancelled policies issued from 2023-12-31 (the first issue
    date) through 2026-08-30. No policies have negative or null
    DiasAnticipacion.
  - This query hit the dwh.Poliza fact table, so it scanned 19.5 MB, more than
    the aggregates.

  SELECT
      v.CanalOrigen
      , COUNT(*) AS Polizas
      , ROUND(AVG(v.DiasAnticipacion), 1) AS DiasPromedio
      , APPROX_QUANTILES(v.DiasAnticipacion, 4)[OFFSET(1)] AS P25
      , APPROX_QUANTILES(v.DiasAnticipacion, 4)[OFFSET(2)] AS Mediana
      , APPROX_QUANTILES(v.DiasAnticipacion, 4)[OFFSET(3)] AS P75
  FROM dwh.Poliza v
  WHERE v.FechaEmision BETWEEN "2020-01-01" AND "2026-08-30"
      AND NOT v.EsAnulada
  GROUP BY 1
  ORDER BY 3 DESC

  Busted, brah: five channels, one number. Either Assist-365's customers are
  freakishly disciplined or someone generated this dataset with random.randint.
  I'd put my money on the second.

✻ Baked for 19s · done 6:50 p. m.

❯ ¿Cuánta exposición pendiente hay por país, en dólares?                        

  Called assist365-bigquery (ctrl+o to expand)

⏺ USD 3.26M pending across 9,053 claims in EN_ANALISIS. Argentina (USD 866k) and
  México (USD 823k) account for more than half.

  ┌───────────┬─────────────┬───────────┬───────────────┬─────────┬───────┐
  │           │ Siniestros  │  USD en   │               │ Sobre   │ Sobre │
  │   País    │ en análisis │ análisis  │ USD/siniestro │ costo   │       │
  │           │             │           │               │ pagado  │ prima │
  ├───────────┼─────────────┼───────────┼───────────────┼─────────┼───────┤
  │ Argentina │ 2,574       │ 865,762   │ 336           │ 0.086   │ 0.034 │
  ├───────────┼─────────────┼───────────┼───────────────┼─────────┼───────┤
  │ México    │ 2,214       │ 822,895   │ 372           │ 0.091   │ 0.036 │
  ├───────────┼─────────────┼───────────┼───────────────┼─────────┼───────┤
  │ Colombia  │ 1,562       │ 558,819   │ 358           │ 0.083   │ 0.033 │
  ├───────────┼─────────────┼───────────┼───────────────┼─────────┼───────┤
  │ Chile     │ 1,067       │ 369,621   │ 346           │ 0.084   │ 0.034 │
  ├───────────┼─────────────┼───────────┼───────────────┼─────────┼───────┤
  │ Perú      │ 877         │ 324,739   │ 370           │ 0.085   │ 0.033 │
  ├───────────┼─────────────┼───────────┼───────────────┼─────────┼───────┤
  │ Brasil    │ 759         │ 319,669   │ 421           │ 0.102   │ 0.040 │
  ├───────────┼─────────────┼───────────┼───────────────┼─────────┼───────┤
  │ Total     │ 9,053       │ 3,261,505 │ 360           │         │       │
  └───────────┴─────────────┴───────────┴───────────────┴─────────┴───────┘

  What it means: if all of it ended up paid, each country's loss ratio would
  rise by about 3.3–4.0 points. Brasil is the most exposed relative to its size:
  0.040 on premium, the most expensive pending claims at USD 421 each, and
  pending equal to 10.2% of what it has already paid. In absolute dollars, the
  big ones are Argentina and México because of volume.

  Red flag on how old it is: there are pending claims on cohorts going back to
  January 2024. Only USD 143k (4.4%) is on the Q3 2026 cohort, which is the one
  that should hold most of it. A claim under review for more than two and a half
  years is either a real backlog that needs cleaning up or, again, flat
  synthetic data. I'd look at the age of these claims in dwh.Siniestro before
  booking this as a reserve.

  Definitions:
  - This is the USD amount on claims with status EN_ANALISIS. It's exposure, not
    cost: rejected claims and a chunk of these will never be paid.
  - Countries are by issuing country and include every cohort. Conversion uses
    the FX rate on the occurrence date.
  - The query scanned 0.188 MB.

  SELECT
      a.NombrePais
      , SUM(a.SiniestrosEnAnalisis) AS SiniestrosEnAnalisis
      , ROUND(SUM(a.EnAnalisisUsd), 0) AS EnAnalisisUsd
      , ROUND(SAFE_DIVIDE(SUM(a.EnAnalisisUsd), SUM(a.SiniestrosEnAnalisis)), 0)
  AS UsdPorSiniestro
      , ROUND(SUM(IF(a.TrimestreEmision >= "2026-07-01", a.EnAnalisisUsd, 0)),
  0) AS EnAnalisisQ3Usd
      , ROUND(SAFE_DIVIDE(SUM(a.EnAnalisisUsd), SUM(a.CostoSiniestrosUsd)), 3)
  AS SobreCostoPagado
      , ROUND(SAFE_DIVIDE(SUM(a.EnAnalisisUsd), SUM(a.PrimaEmitidaUsd)), 3) AS
  SobrePrima
      , MIN(IF(a.SiniestrosEnAnalisis > 0, a.MesEmision, NULL)) AS
  CohorteMasVieja
  FROM dwh.SiniestralidadMensual a
  GROUP BY 1
  ORDER BY 3 DESC

  Rolling on the number, mate: USD 3.26M, clean query. But claims "under review"
  since 2024 aren't exposure, they're a skeleton in the cupboard.

✻ Churned for 24s · done 6:52 p. m.
---

## Appendix: SQL run by Claude Code during this session

The export above collapses tool calls. These are the queries the `assist365-bigquery` MCP server ran for this session,
taken from BigQuery job history (`INFORMATION_SCHEMA.JOBS_BY_USER`), in order. Question 2 used two queries.

### Query 1 · 18:43:04 · 0.188 MB processed

```sql
SELECT
    FORMAT_DATE("%Y-Q%Q", a.TrimestreEmision) AS Trimestre
    , a.NombrePais
    , SUM(a.Polizas) AS Polizas
    , ROUND(SUM(a.PrimaEmitidaUsd), 0) AS PrimaUsd
    , ROUND(SUM(a.CostoSiniestrosUsd), 0) AS CostoUsd
    , ROUND(SAFE_DIVIDE(SUM(a.CostoSiniestrosUsd), SUM(a.PrimaEmitidaUsd)), 3) AS Siniestralidad
    , ROUND(SAFE_DIVIDE(SUM(a.SiniestrosPagadosConCobertura), SUM(a.Polizas)), 3) AS Frecuencia
    , ROUND(SAFE_DIVIDE(SUM(a.CostoSiniestrosUsd), SUM(a.SiniestrosPagados)), 0) AS SeveridadUsd
    , ROUND(SAFE_DIVIDE(SUM(a.PrimaEmitidaUsd), SUM(a.Polizas)), 1) AS PrimaMediaUsd
    , ROUND(SAFE_DIVIDE(SUM(a.PolizasCoberturaTerminada), SUM(a.Polizas)), 3) AS Madurez
FROM dwh.SiniestralidadMensual a
WHERE a.TrimestreEmision >= "2025-07-01"
GROUP BY 1, 2
ORDER BY 1, 6 DESC
```

### Query 2 · 18:44:06 · 0.188 MB processed

```sql
SELECT
    FORMAT_DATE("%Y-Q%Q", a.TrimestreEmision) AS Trimestre
    , a.NombrePais
    , SUM(a.Polizas) AS Polizas
    , ROUND(SUM(a.PrimaEmitidaUsd), 0) AS PrimaUsd
    , ROUND(SUM(a.CostoSiniestrosUsd), 0) AS CostoUsd
    , ROUND(SAFE_DIVIDE(SUM(a.CostoSiniestrosUsd), SUM(a.PrimaEmitidaUsd)), 3) AS Siniestralidad
    , ROUND(SAFE_DIVIDE(SUM(a.SiniestrosPagadosConCobertura), SUM(a.Polizas)), 3) AS Frecuencia
    , ROUND(SAFE_DIVIDE(SUM(a.CostoSiniestrosUsd), SUM(a.SiniestrosPagados)), 0) AS SeveridadUsd
    , ROUND(SAFE_DIVIDE(SUM(a.PrimaEmitidaUsd), SUM(a.Polizas)), 1) AS PrimaMediaUsd
    , ROUND(SAFE_DIVIDE(SUM(a.PolizasCoberturaTerminada), SUM(a.Polizas)), 3) AS Madurez
FROM dwh.SiniestralidadMensual a
WHERE a.TrimestreEmision >= "2025-10-01"
GROUP BY 1, 2
ORDER BY 1, 6 DESC
```

### Query 3 · 18:44:43 · 0.264 MB processed

```sql
WITH Plan AS (
    SELECT
        a.NombrePlan
        , a.TipoPlan
        , SUM(a.Polizas) AS Polizas
        , SUM(a.PrimaEmitidaUsd) AS PrimaUsd
        , SUM(a.CostoSiniestrosUsd) AS CostoUsd
        , SUM(a.SiniestrosPagadosConCobertura) AS PagadosConCob
        , SUM(a.SiniestrosPagados) AS Pagados
        , SUM(a.PolizasCoberturaTerminada) AS Terminadas
        , SUM(a.PagadoSinCoberturaUsd) AS SinCobUsd
    FROM dwh.SiniestralidadMensual a
    WHERE a.TrimestreEmision <= "2026-04-01"
    GROUP BY 1, 2
)
SELECT
    p.NombrePlan
    , p.TipoPlan
    , p.Polizas
    , ROUND(p.PrimaUsd, 0) AS PrimaUsd
    , ROUND(p.CostoUsd, 0) AS CostoUsd
    , ROUND(p.PrimaUsd - p.CostoUsd, 0) AS MargenTecnicoUsd
    , ROUND(SAFE_DIVIDE(p.CostoUsd, p.PrimaUsd), 3) AS Siniestralidad
    , ROUND(SAFE_DIVIDE(p.PagadosConCob, p.Polizas), 3) AS Frecuencia
    , ROUND(SAFE_DIVIDE(p.CostoUsd, p.Pagados), 0) AS SeveridadUsd
    , ROUND(SAFE_DIVIDE(p.PrimaUsd, p.Polizas), 1) AS PrimaMediaUsd
    , ROUND(SAFE_DIVIDE(p.CostoUsd, p.Polizas), 1) AS CostoPorPolizaUsd
    , ROUND(SAFE_DIVIDE(p.Terminadas, p.Polizas), 3) AS Madurez
    , ROUND(p.SinCobUsd, 0) AS PagadoSinCoberturaUsd
FROM Plan p
UNION ALL
SELECT
    "TOTAL", NULL
    , SUM(p.Polizas)
    , ROUND(SUM(p.PrimaUsd), 0)
    , ROUND(SUM(p.CostoUsd), 0)
    , ROUND(SUM(p.PrimaUsd) - SUM(p.CostoUsd), 0)
    , ROUND(SAFE_DIVIDE(SUM(p.CostoUsd), SUM(p.PrimaUsd)), 3)
    , ROUND(SAFE_DIVIDE(SUM(p.PagadosConCob), SUM(p.Polizas)), 3)
    , ROUND(SAFE_DIVIDE(SUM(p.CostoUsd), SUM(p.Pagados)), 0)
    , ROUND(SAFE_DIVIDE(SUM(p.PrimaUsd), SUM(p.Polizas)), 1)
    , ROUND(SAFE_DIVIDE(SUM(p.CostoUsd), SUM(p.Polizas)), 1)
    , ROUND(SAFE_DIVIDE(SUM(p.Terminadas), SUM(p.Polizas)), 3)
    , ROUND(SUM(p.SinCobUsd), 0)
FROM Plan p
ORDER BY 7 DESC
```

### Query 4 · 18:44:51 · 0.448 MB processed

```sql
SELECT
    t.NombrePlan
    , t.TipoSiniestro
    , ROUND(SUM(t.PagadoUsd), 0) AS PagadoUsd
    , ROUND(SAFE_DIVIDE(SUM(t.PagadoUsd), SUM(SUM(t.PagadoUsd)) OVER (PARTITION BY t.NombrePlan)), 3) AS ShareUsd
FROM dwh.SiniestroPorTipo t
WHERE t.TrimestreEmision <= "2026-04-01"
    AND t.NombrePlan IN ("Equipaje Protegido", "Estudiante Larga", "Premium Total 500")
GROUP BY 1, 2
ORDER BY 1, 3 DESC
```

### Query 5 · 18:47:34 · 0.537 MB processed

```sql
SELECT
    t.NombrePlan
    , t.TipoSiniestro
    , t.EsRiesgoDelPlan
    , SUM(t.SiniestrosPagados) AS SiniestrosPagados
    , ROUND(SUM(t.PagadoUsd), 0) AS PagadoUsd
    , ROUND(SAFE_DIVIDE(SUM(t.PagadoUsd), SUM(SUM(t.PagadoUsd)) OVER (PARTITION BY t.NombrePlan)), 3) AS ShareUsd
FROM dwh.SiniestroPorTipo t
WHERE t.TipoPlan IN ("EQUIPAJE", "CANCELACION")
GROUP BY 1, 2, 3
ORDER BY 1, 5 DESC
```

### Query 6 · 18:50:05 · 19.547 MB processed

```sql
SELECT
    v.CanalOrigen
    , COUNT(*) AS Polizas
    , MIN(v.FechaEmision) AS PrimeraEmision
    , ROUND(AVG(v.DiasAnticipacion), 1) AS DiasPromedio
    , APPROX_QUANTILES(v.DiasAnticipacion, 4)[OFFSET(1)] AS P25
    , APPROX_QUANTILES(v.DiasAnticipacion, 4)[OFFSET(2)] AS Mediana
    , APPROX_QUANTILES(v.DiasAnticipacion, 4)[OFFSET(3)] AS P75
    , ROUND(COUNTIF(v.DiasAnticipacion < 0) / COUNT(*), 3) AS ShareNegativo
    , ROUND(COUNTIF(v.DiasAnticipacion IS NULL) / COUNT(*), 3) AS ShareNulo
FROM dwh.Poliza v
WHERE v.FechaEmision BETWEEN "2020-01-01" AND "2026-08-30"
    AND NOT v.EsAnulada
GROUP BY 1
ORDER BY 4 DESC
```

### Query 7 · 18:52:09 · 0.188 MB processed

```sql
SELECT
    a.NombrePais
    , SUM(a.SiniestrosEnAnalisis) AS SiniestrosEnAnalisis
    , ROUND(SUM(a.EnAnalisisUsd), 0) AS EnAnalisisUsd
    , ROUND(SAFE_DIVIDE(SUM(a.EnAnalisisUsd), SUM(a.SiniestrosEnAnalisis)), 0) AS UsdPorSiniestro
    , ROUND(SUM(IF(a.TrimestreEmision >= "2026-07-01", a.EnAnalisisUsd, 0)), 0) AS EnAnalisisQ3Usd
    , ROUND(SAFE_DIVIDE(SUM(a.EnAnalisisUsd), SUM(a.CostoSiniestrosUsd)), 3) AS SobreCostoPagado
    , ROUND(SAFE_DIVIDE(SUM(a.EnAnalisisUsd), SUM(a.PrimaEmitidaUsd)), 3) AS SobrePrima
    , MIN(IF(a.SiniestrosEnAnalisis > 0, a.MesEmision, NULL)) AS CohorteMasVieja
FROM dwh.SiniestralidadMensual a
GROUP BY 1
ORDER BY 3 DESC
```
