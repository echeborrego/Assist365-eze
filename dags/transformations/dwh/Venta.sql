-- Grain: one row per policy sold (deleted policies excluded, D9).
-- Cancelled policies stay as rows but add no written premium (M2).
CREATE OR REPLACE TABLE dwh.Venta
PARTITION BY DATE_TRUNC(FechaEmision, MONTH)
CLUSTER BY PaisEmision, ProductoId AS
SELECT
    p.PolizaId
    , p.ClienteId
    , p.ProductoId
    , p.AgenciaId
    , p.PaisEmision
    , p.CanalOrigen
    , p.FechaEmision
    , p.InicioVigencia
    , p.FinVigencia
    , DATE_DIFF(p.InicioVigencia, p.FechaEmision, DAY) AS DiasAnticipacion
    , DATE_DIFF(p.FinVigencia, p.InicioVigencia, DAY) + 1 AS DiasViaje
    , p.Estado = "ANULADA" AS EsAnulada
    , p.FinVigencia < CURRENT_DATE("America/Argentina/Buenos_Aires") AS EsCoberturaTerminada
    , p.Moneda
    , p.Prima AS PrimaOrigen
    , fx.FactorUsd
    , ROUND(p.Prima * fx.FactorUsd, 2) AS PrimaUsd
    , IF(p.Estado = "ANULADA", 0, ROUND(p.Prima * fx.FactorUsd, 2)) AS PrimaEmitidaUsd
FROM staging.Poliza p
LEFT JOIN staging.TipoCambio fx ON fx.Moneda = p.Moneda AND fx.Fecha = p.FechaEmision
WHERE NOT p.IsDeleted
