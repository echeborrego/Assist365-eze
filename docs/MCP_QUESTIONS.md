# Business questions answered through MCP

Each question below was answered by calling the `execute_sql` tool of the `assist365-bigquery` MCP server
over stdio (`mcp_server/ask.py`). The SQL follows the `assist365-warehouse` skill.

MCP tools exposed: `list_tables`, `describe_table`, `execute_sql`

## 1. ¿Qué país tuvo la peor siniestralidad en el último trimestre cerrado?

```sql
SELECT
    FORMAT_DATE("%Y-Q%Q", a.TrimestreEmision) AS Trimestre
    , a.NombrePais
    , ROUND(SAFE_DIVIDE(SUM(a.CostoSiniestrosUsd), SUM(a.PrimaEmitidaUsd)), 3) AS Siniestralidad
    , ROUND(SAFE_DIVIDE(SUM(a.PolizasCoberturaTerminada), SUM(a.Polizas)), 3) AS Madurez
FROM dwh.SiniestralidadMensual a
WHERE a.TrimestreEmision = "2026-04-01"
GROUP BY 1, 2
ORDER BY 3 DESC
```

| Trimestre | NombrePais | Siniestralidad | Madurez |
|---|---|---|---|
| 2026-Q2 | Chile | 0.437 | 0.985 |
| 2026-Q2 | Argentina | 0.418 | 0.986 |
| 2026-Q2 | Colombia | 0.402 | 0.985 |
| 2026-Q2 | México | 0.392 | 0.985 |
| 2026-Q2 | Perú | 0.385 | 0.985 |
| 2026-Q2 | Brasil | 0.371 | 0.986 |

_0.151 MB processed_

## 2. ¿Qué plan destruye más margen, y es por frecuencia, severidad o precio?

```sql
SELECT
    a.NombrePlan
    , ROUND(SAFE_DIVIDE(SUM(a.CostoSiniestrosUsd), SUM(a.PrimaEmitidaUsd)), 3) AS Siniestralidad
    , ROUND(SAFE_DIVIDE(SUM(a.SiniestrosPagadosConCobertura), SUM(a.Polizas)), 3) AS Frecuencia
    , ROUND(SAFE_DIVIDE(SUM(a.CostoSiniestrosUsd), SUM(a.SiniestrosPagados)), 0) AS SeveridadUsd
    , ROUND(SAFE_DIVIDE(SUM(a.PrimaEmitidaUsd), SUM(a.Polizas)), 1) AS PrimaMediaUsd
FROM dwh.SiniestralidadMensual a
GROUP BY 1
ORDER BY 2 DESC
LIMIT 3
```

| NombrePlan | Siniestralidad | Frecuencia | SeveridadUsd | PrimaMediaUsd |
|---|---|---|---|---|
| Equipaje Protegido | 1.481 | 0.136 | 342 | 31.4 |
| Estudiante Larga | 1.149 | 0.139 | 344 | 41.7 |
| Esencial 30 | 0.819 | 0.14 | 365 | 62.6 |

_0.168 MB processed_

## 3. ¿Cuánto pagaron los planes de equipaje y cancelación en siniestros de otro tipo de riesgo?

```sql
SELECT
    t.NombrePlan
    , ROUND(SUM(IF(NOT t.EsRiesgoDelPlan, t.PagadoUsd, 0)), 0) AS PagadoFueraDelRiesgoUsd
    , ROUND(SAFE_DIVIDE(SUM(IF(NOT t.EsRiesgoDelPlan, t.PagadoUsd, 0)), SUM(t.PagadoUsd)), 3) AS Share
FROM dwh.SiniestroPorTipo t
WHERE t.TipoPlan IN ("EQUIPAJE", "CANCELACION")
GROUP BY 1
```

| NombrePlan | PagadoFueraDelRiesgoUsd | Share |
|---|---|---|
| Cancelacion Plus | 2468668 | 0.879 |
| Equipaje Protegido | 1857961 | 0.909 |

_0.378 MB processed_

## 4. ¿Qué canal de venta compra con más anticipación respecto del viaje (último trimestre cerrado)?

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

| CanalOrigen | Polizas | DiasAnticipacionPromedio |
|---|---|---|
| email | 6737 | 50.4 |
| google | 18027 | 49.8 |
| organico | 12379 | 49.6 |
| agencia | 16421 | 49.6 |
| meta | 14986 | 49.4 |

_1.827 MB processed_

## 5. ¿Cuánta exposición pendiente (siniestros en análisis) hay por país, en USD?

```sql
SELECT
    a.NombrePais
    , SUM(a.SiniestrosEnAnalisis) AS SiniestrosEnAnalisis
    , ROUND(SUM(a.EnAnalisisUsd), 0) AS EnAnalisisUsd
    , ROUND(SAFE_DIVIDE(SUM(a.EnAnalisisUsd), SUM(a.CostoSiniestrosUsd)), 3) AS SobreCostoPagado
FROM dwh.SiniestralidadMensual a
GROUP BY 1
ORDER BY 3 DESC
```

| NombrePais | SiniestrosEnAnalisis | EnAnalisisUsd | SobreCostoPagado |
|---|---|---|---|
| Argentina | 2574 | 865762 | 0.086 |
| México | 2214 | 822895 | 0.091 |
| Colombia | 1562 | 558819 | 0.083 |
| Chile | 1067 | 369621 | 0.084 |
| Perú | 877 | 324739 | 0.085 |
| Brasil | 759 | 319669 | 0.102 |

_0.113 MB processed_
