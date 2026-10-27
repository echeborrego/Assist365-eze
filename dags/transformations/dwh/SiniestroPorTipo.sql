-- Grain: one row per issue month (policy cohort) x issuing country x plan x claim type, paid claims only.
-- Feeds the dashboard's claim-type mix; kept apart from SiniestralidadMensual so premium is never repeated per type.
CREATE OR REPLACE TABLE dwh.SiniestroPorTipo
CLUSTER BY PaisEmision, ProductoId AS
SELECT
    DATE_TRUNC(s.FechaEmisionPoliza, MONTH) AS MesEmision
    , DATE_TRUNC(s.FechaEmisionPoliza, QUARTER) AS TrimestreEmision
    , s.PaisEmision
    , p.NombrePais
    , s.ProductoId
    , d.NombrePlan
    , d.TipoPlan
    , s.Tipo AS TipoSiniestro
    -- Single-risk plans (luggage, cancellation) are assumed to cover only their own risk (INFERRED, see ANALYSIS.md)
    , d.TipoPlan NOT IN ("EQUIPAJE", "CANCELACION") OR s.Tipo = d.TipoPlan AS EsRiesgoDelPlan
    , COUNT(*) AS SiniestrosPagados
    , ROUND(SUM(s.MontoUsd), 2) AS PagadoUsd
FROM dwh.Siniestro s
JOIN dwh.Producto d ON d.ProductoId = s.ProductoId
LEFT JOIN dwh.Pais p ON p.PaisId = s.PaisEmision
WHERE s.CuentaParaSiniestralidad
    AND s.Estado = "PAGADO"
GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9
