-- Grain: one row per agency.
CREATE OR REPLACE TABLE dwh.dim_agencia AS
SELECT
    a.AgenciaId
    , a.NombreAgencia
    , a.PaisAgencia
    , a.CanalAgencia
FROM staging.agencias a
