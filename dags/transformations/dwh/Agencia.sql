-- Grain: one row per agency.
CREATE OR REPLACE TABLE dwh.Agencia AS
SELECT
    a.AgenciaId
    , a.NombreAgencia
    , a.PaisAgencia
    , a.CanalAgencia
FROM staging.Agencia a
