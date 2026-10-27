-- Grain: one row per plan.
CREATE OR REPLACE TABLE dwh.dim_producto AS
SELECT
    p.ProductoId
    , p.NombrePlan
    , p.TipoPlan
    , p.CoberturaMaxUsd
    , p.EsPremium
FROM staging.productos p
