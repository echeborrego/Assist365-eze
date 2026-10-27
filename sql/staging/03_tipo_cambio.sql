-- Grain: one row per currency per calendar day, from a week before the first quote up to today.
-- The source only quotes business days, so weekends/holidays carry the last known rate forward;
-- days before the first quote (local-time sales on 2023-12-31) take the first one.
CREATE OR REPLACE TABLE staging.tipo_cambio
CLUSTER BY Moneda AS
WITH Fx AS (
    SELECT
        SAFE.PARSE_DATE("%Y-%m-%d", JSON_VALUE(r.Payload.fecha)) AS Fecha
        , JSON_VALUE(r.Payload.moneda) AS Moneda
        , SAFE_CAST(JSON_VALUE(r.Payload.unidades_por_usd) AS NUMERIC) AS UnidadesPorUsd
        , SAFE_CAST(JSON_VALUE(r.Payload.factor_usd) AS NUMERIC) AS FactorUsd
    FROM raw.catalogo_tipo_cambio r
)
, Calendario AS (
    SELECT
        m.Moneda
        , d AS Fecha
    FROM (
        SELECT
            Moneda
            , DATE_SUB(MIN(Fecha), INTERVAL 7 DAY) AS Desde
        FROM Fx
        GROUP BY 1
    ) m
    , UNNEST(GENERATE_DATE_ARRAY(m.Desde, CURRENT_DATE("America/Argentina/Buenos_Aires"))) AS d
)
SELECT
    c.Fecha
    , c.Moneda
    , COALESCE(LAST_VALUE(f.UnidadesPorUsd IGNORE NULLS) OVER w, FIRST_VALUE(f.UnidadesPorUsd IGNORE NULLS) OVER s) AS UnidadesPorUsd
    , COALESCE(LAST_VALUE(f.FactorUsd IGNORE NULLS) OVER w, FIRST_VALUE(f.FactorUsd IGNORE NULLS) OVER s) AS FactorUsd
    , COALESCE(LAST_VALUE(f.Fecha IGNORE NULLS) OVER w, FIRST_VALUE(f.Fecha IGNORE NULLS) OVER s) AS FechaCotizacion
    , f.Fecha IS NULL AS EsArrastrado
FROM Calendario c
LEFT JOIN Fx f ON f.Moneda = c.Moneda AND f.Fecha = c.Fecha
WINDOW
    w AS (PARTITION BY c.Moneda ORDER BY c.Fecha ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
    , s AS (PARTITION BY c.Moneda ORDER BY c.Fecha ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING)
