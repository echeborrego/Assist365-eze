# Common queries

Canonical SQL for the standard metrics. Start from these so answers match the dashboard and `docs/ANALYSIS.md`.

## Loss ratio, frequency, severity, average premium and maturity by a dimension

Swap `NombrePais` for `NombrePlan`, `TipoPlan` or `TrimestreEmision`, and add a `WHERE MesEmision BETWEEN …` filter for a period.

```sql
SELECT
    a.NombrePais
    , SUM(a.Polizas) AS Polizas
    , ROUND(SUM(a.PrimaEmitidaUsd), 0) AS PrimaUsd
    , ROUND(SUM(a.CostoSiniestrosUsd), 0) AS CostoUsd
    , ROUND(SAFE_DIVIDE(SUM(a.CostoSiniestrosUsd), SUM(a.PrimaEmitidaUsd)), 3) AS Siniestralidad
    , ROUND(SAFE_DIVIDE(SUM(a.SiniestrosPagadosConCobertura), SUM(a.Polizas)), 3) AS Frecuencia
    , ROUND(SAFE_DIVIDE(SUM(a.CostoSiniestrosUsd), SUM(a.SiniestrosPagados)), 0) AS SeveridadUsd
    , ROUND(SAFE_DIVIDE(SUM(a.PrimaEmitidaUsd), SUM(a.Polizas)), 1) AS PrimaMediaUsd
    , ROUND(SAFE_DIVIDE(SUM(a.PolizasCoberturaTerminada), SUM(a.Polizas)), 3) AS Madurez
FROM dwh.SiniestralidadMensual a
GROUP BY 1
ORDER BY 5 DESC
```

## Loss ratio by issue quarter and country (which country is worst)

```sql
SELECT
    FORMAT_DATE("%Y-Q%Q", a.TrimestreEmision) AS Trimestre
    , a.NombrePais
    , ROUND(SAFE_DIVIDE(SUM(a.CostoSiniestrosUsd), SUM(a.PrimaEmitidaUsd)), 3) AS Siniestralidad
    , ROUND(SAFE_DIVIDE(SUM(a.PolizasCoberturaTerminada), SUM(a.Polizas)), 3) AS Madurez
FROM dwh.SiniestralidadMensual a
GROUP BY 1, 2
ORDER BY 1, 3 DESC
```

## Claim-type mix of what each plan pays

```sql
SELECT
    t.NombrePlan
    , t.TipoPlan
    , t.TipoSiniestro
    , ROUND(SUM(t.PagadoUsd), 0) AS PagadoUsd
    , ROUND(SAFE_DIVIDE(SUM(t.PagadoUsd), SUM(SUM(t.PagadoUsd)) OVER (PARTITION BY t.NombrePlan)), 3) AS ShareUsd
FROM dwh.SiniestroPorTipo t
GROUP BY 1, 2, 3
ORDER BY 1, 4 DESC
```

## Paid outside a single-risk plan's own risk

```sql
SELECT
    t.NombrePlan
    , ROUND(SUM(IF(NOT t.EsRiesgoDelPlan, t.PagadoUsd, 0)), 0) AS PagadoFueraDelRiesgoUsd
    , ROUND(SAFE_DIVIDE(SUM(IF(NOT t.EsRiesgoDelPlan, t.PagadoUsd, 0)), SUM(t.PagadoUsd)), 3) AS Share
FROM dwh.SiniestroPorTipo t
WHERE t.TipoPlan IN ("EQUIPAJE", "CANCELACION")
GROUP BY 1
```

## Leakage: paid without cover

```sql
SELECT
    a.NombrePlan
    , SUM(a.PagadosSinCobertura) AS PagadosSinCobertura
    , ROUND(SUM(a.PagadoSinCoberturaUsd), 0) AS PagadoSinCoberturaUsd
FROM dwh.SiniestralidadMensual a
GROUP BY 1
ORDER BY 3 DESC
```

## Row-level example: purchase lead time by channel (fact table; filter the partition)

```sql
SELECT
    v.CanalOrigen
    , COUNT(*) AS Polizas
    , ROUND(AVG(v.DiasAnticipacion), 1) AS DiasAnticipacionPromedio
FROM dwh.Poliza v
WHERE v.FechaEmision BETWEEN "2026-04-01" AND "2026-06-30"
    AND NOT v.EsAnulada
GROUP BY 1
ORDER BY 3 DESC
```
