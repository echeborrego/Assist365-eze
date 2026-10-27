-- Grain: one row per poliza_id, its latest state in the CDC stream (deletes kept with IsDeleted).
-- Rebuilt from all raw change events; incremental overlap duplicates collapse here.
CREATE OR REPLACE TABLE staging.polizas
CLUSTER BY PaisEmision, ProductoId AS
WITH Cambios AS (
    SELECT
        JSON_VALUE(r.Payload.poliza_id) AS PolizaId
        , JSON_VALUE(r.Payload.cliente_id) AS ClienteId
        , JSON_VALUE(r.Payload.producto_id) AS ProductoId
        , JSON_VALUE(r.Payload.agencia_id) AS AgenciaId
        , JSON_VALUE(r.Payload.pais_emision) AS PaisEmision
        , JSON_VALUE(r.Payload.canal_origen) AS CanalOrigen
        , SAFE.PARSE_TIMESTAMP("%Y-%m-%dT%H:%M:%SZ", JSON_VALUE(r.Payload.fecha_emision_utc)) AS FechaEmisionUtc
        , DATE(SAFE.PARSE_TIMESTAMP("%Y-%m-%dT%H:%M:%SZ", JSON_VALUE(r.Payload.inicio_vigencia))) AS InicioVigencia
        , DATE(SAFE.PARSE_TIMESTAMP("%Y-%m-%dT%H:%M:%SZ", JSON_VALUE(r.Payload.fin_vigencia))) AS FinVigencia
        , SAFE_CAST(JSON_VALUE(r.Payload.prima) AS NUMERIC) AS Prima
        , JSON_VALUE(r.Payload.moneda) AS Moneda
        , JSON_VALUE(r.Payload.estado) AS Estado
        , JSON_VALUE(r.Payload.op) AS Op
        , SAFE.PARSE_TIMESTAMP("%Y-%m-%dT%H:%M:%SZ", JSON_VALUE(r.Payload.updated_at)) AS UpdatedAt
        , r.ExtractedAt
    FROM raw.polizas r
)
, ZonaHoraria AS (
    SELECT * FROM UNNEST([
        STRUCT("AR" AS Pais, "America/Argentina/Buenos_Aires" AS Zona)
        , ("BR", "America/Sao_Paulo")
        , ("CL", "America/Santiago")
        , ("CO", "America/Bogota")
        , ("MX", "America/Mexico_City")
        , ("PE", "America/Lima")
    ])
)
SELECT
    c.PolizaId
    , c.ClienteId
    , c.ProductoId
    , c.AgenciaId
    , c.PaisEmision
    , c.CanalOrigen
    , c.FechaEmisionUtc
    , DATE(c.FechaEmisionUtc, IFNULL(z.Zona, "America/Argentina/Buenos_Aires")) AS FechaEmision
    , c.InicioVigencia
    , c.FinVigencia
    , c.Prima
    , c.Moneda
    , c.Estado
    , c.Op = "D" AS IsDeleted
    , c.UpdatedAt
FROM Cambios c
LEFT JOIN ZonaHoraria z ON z.Pais = c.PaisEmision
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY c.PolizaId
    ORDER BY c.UpdatedAt DESC, CASE c.Op WHEN "D" THEN 3 WHEN "U" THEN 2 ELSE 1 END DESC, c.ExtractedAt DESC
) = 1
