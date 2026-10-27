-- Grain: one row per issue month (policy cohort) x issuing country x plan. Feeds the dashboard.
-- Claims are attributed to their policy's issue month (underwriting basis, M4).
CREATE OR REPLACE TABLE dwh.agg_siniestralidad_mensual
CLUSTER BY PaisEmision, ProductoId AS
WITH Ventas AS (
    SELECT
        DATE_TRUNC(v.FechaEmision, MONTH) AS MesEmision
        , v.PaisEmision
        , v.ProductoId
        , COUNTIF(NOT v.EsAnulada) AS Polizas
        , COUNTIF(v.EsAnulada) AS PolizasAnuladas
        , COUNTIF(NOT v.EsAnulada AND v.EsCoberturaTerminada) AS PolizasCoberturaTerminada
        , SUM(v.PrimaEmitidaUsd) AS PrimaEmitidaUsd
    FROM dwh.fct_ventas v
    GROUP BY 1, 2, 3
)
, Siniestros AS (
    SELECT
        DATE_TRUNC(s.FechaEmisionPoliza, MONTH) AS MesEmision
        , s.PaisEmision
        , s.ProductoId
        , COUNTIF(s.Estado = "PAGADO") AS SiniestrosPagados
        , SUM(IF(s.Estado = "PAGADO", s.MontoUsd, 0)) AS CostoSiniestrosUsd
        , COUNTIF(s.Estado = "EN_ANALISIS") AS SiniestrosEnAnalisis
        , SUM(IF(s.Estado = "EN_ANALISIS", s.MontoUsd, 0)) AS EnAnalisisUsd
        , COUNTIF(s.Estado = "RECHAZADO") AS SiniestrosRechazados
        , SUM(IF(s.Estado = "PAGADO" AND (s.EsPolizaAnulada OR s.EsFueraDeVigencia), s.MontoUsd, 0)) AS PagadoSinCoberturaUsd
        , COUNTIF(s.Estado = "PAGADO" AND (s.EsPolizaAnulada OR s.EsFueraDeVigencia)) AS PagadosSinCobertura
    FROM dwh.fct_siniestros s
    WHERE s.CuentaParaSiniestralidad
    GROUP BY 1, 2, 3
)
SELECT
    v.MesEmision
    , DATE_TRUNC(v.MesEmision, QUARTER) AS TrimestreEmision
    , v.PaisEmision
    , p.NombrePais
    , v.ProductoId
    , d.NombrePlan
    , d.TipoPlan
    , d.EsPremium
    , v.Polizas
    , v.PolizasAnuladas
    , v.PolizasCoberturaTerminada
    , ROUND(v.PrimaEmitidaUsd, 2) AS PrimaEmitidaUsd
    , IFNULL(s.SiniestrosPagados, 0) AS SiniestrosPagados
    , ROUND(IFNULL(s.CostoSiniestrosUsd, 0), 2) AS CostoSiniestrosUsd
    , IFNULL(s.SiniestrosEnAnalisis, 0) AS SiniestrosEnAnalisis
    , ROUND(IFNULL(s.EnAnalisisUsd, 0), 2) AS EnAnalisisUsd
    , IFNULL(s.SiniestrosRechazados, 0) AS SiniestrosRechazados
    , IFNULL(s.PagadosSinCobertura, 0) AS PagadosSinCobertura
    , ROUND(IFNULL(s.PagadoSinCoberturaUsd, 0), 2) AS PagadoSinCoberturaUsd
FROM Ventas v
LEFT JOIN Siniestros s USING (MesEmision, PaisEmision, ProductoId)
LEFT JOIN dwh.dim_pais p ON p.PaisId = v.PaisEmision
LEFT JOIN dwh.dim_producto d ON d.ProductoId = v.ProductoId
