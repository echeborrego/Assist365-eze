-- Grain: one row per plan.
CREATE OR REPLACE TABLE dwh.Producto AS
SELECT
    p.ProductoId
    , p.NombrePlan
    , p.TipoPlan
    , p.CoberturaMaxUsd
    , p.EsPremium
FROM staging.Producto p
