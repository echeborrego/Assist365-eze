-- Grain: one row per agencia_id.
CREATE OR REPLACE TABLE ${staging}.agencias AS
SELECT
    JSON_VALUE(r.Payload.agencia_id) AS AgenciaId
    , JSON_VALUE(r.Payload.nombre) AS NombreAgencia
    , JSON_VALUE(r.Payload.pais) AS PaisAgencia
    , JSON_VALUE(r.Payload.canal) AS CanalAgencia
FROM ${raw}.catalogo_agencias r
QUALIFY ROW_NUMBER() OVER (PARTITION BY JSON_VALUE(r.Payload.agencia_id)) = 1
