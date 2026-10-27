-- Grain: one row per producto_id. The API sends every field as a string.
CREATE OR REPLACE TABLE staging.Producto AS
SELECT
    JSON_VALUE(r.Payload.producto_id) AS ProductoId
    , JSON_VALUE(r.Payload.nombre_plan) AS NombrePlan
    , JSON_VALUE(r.Payload.tipo) AS TipoPlan
    , SAFE_CAST(JSON_VALUE(r.Payload.cobertura_max_usd) AS INT64) AS CoberturaMaxUsd
    , JSON_VALUE(r.Payload.es_premium) = "1" AS EsPremium
FROM raw.CatalogoProducto r
QUALIFY ROW_NUMBER() OVER (PARTITION BY JSON_VALUE(r.Payload.producto_id)) = 1
