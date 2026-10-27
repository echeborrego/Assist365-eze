-- Grain: one row per claim (claims on deleted policies excluded, D11).
-- Carries its policy's issue date, country and plan so loss ratio is on an underwriting basis (M4).
CREATE OR REPLACE TABLE dwh.Siniestro
PARTITION BY DATE_TRUNC(FechaEmisionPoliza, MONTH)
CLUSTER BY PaisEmision, ProductoId AS
SELECT
    s.SiniestroId
    , s.PolizaId
    , v.FechaEmision AS FechaEmisionPoliza
    , v.PaisEmision
    , v.ProductoId
    , v.CanalOrigen
    , v.AgenciaId
    , s.FechaOcurrencia
    , s.FechaReporte
    , DATE_DIFF(s.FechaReporte, s.FechaOcurrencia, DAY) AS DiasHastaReporte
    , s.Tipo
    , s.Estado
    , s.Proveedor
    , s.Diagnostico
    , s.CiudadAtencion
    , s.Moneda
    , s.Monto AS MontoOrigen
    , fx.FactorUsd
    , ROUND(s.Monto * fx.FactorUsd, 2) AS MontoUsd
    , s.EsMontoNegativoOrigen
    , s.EsMonedaInferida
    , s.EsFechaFutura
    , s.EsPolizaInexistente
    , s.EsPolizaAnulada
    , IFNULL(s.EsFueraDeVigencia, FALSE) AS EsFueraDeVigencia
    -- Official metrics: real date and a policy to attribute it to (D8, D13)
    , NOT s.EsFechaFutura AND NOT s.EsPolizaInexistente AS CuentaParaSiniestralidad
FROM staging.Siniestro s
LEFT JOIN dwh.Poliza v ON v.PolizaId = s.PolizaId
LEFT JOIN staging.TipoCambio fx ON fx.Moneda = s.Moneda AND fx.Fecha = s.FechaOcurrencia
WHERE NOT s.EsPolizaEliminada
