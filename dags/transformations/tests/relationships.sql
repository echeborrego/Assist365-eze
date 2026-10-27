-- Fact foreign keys exist in their dimensions.
SELECT "producto" AS Dimension, v.ProductoId AS Clave FROM dwh.fct_ventas v
LEFT JOIN dwh.dim_producto d ON d.ProductoId = v.ProductoId WHERE d.ProductoId IS NULL
UNION ALL
SELECT "agencia", v.AgenciaId FROM dwh.fct_ventas v
LEFT JOIN dwh.dim_agencia d ON d.AgenciaId = v.AgenciaId WHERE d.AgenciaId IS NULL
UNION ALL
SELECT "pais", v.PaisEmision FROM dwh.fct_ventas v
LEFT JOIN dwh.dim_pais d ON d.PaisId = v.PaisEmision WHERE d.PaisId IS NULL
UNION ALL
SELECT "poliza", s.PolizaId FROM dwh.fct_siniestros s
WHERE s.CuentaParaSiniestralidad AND s.FechaEmisionPoliza IS NULL
