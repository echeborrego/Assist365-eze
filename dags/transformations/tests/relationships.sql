-- Fact foreign keys exist in their dimensions.
SELECT "producto" AS Dimension, v.ProductoId AS Clave FROM dwh.Poliza v
LEFT JOIN dwh.Producto d ON d.ProductoId = v.ProductoId WHERE d.ProductoId IS NULL
UNION ALL
SELECT "agencia", v.AgenciaId FROM dwh.Poliza v
LEFT JOIN dwh.Agencia d ON d.AgenciaId = v.AgenciaId WHERE d.AgenciaId IS NULL
UNION ALL
SELECT "pais", v.PaisEmision FROM dwh.Poliza v
LEFT JOIN dwh.Pais d ON d.PaisId = v.PaisEmision WHERE d.PaisId IS NULL
UNION ALL
SELECT "poliza", s.PolizaId FROM dwh.Siniestro s
WHERE s.CuentaParaSiniestralidad AND s.FechaEmisionPoliza IS NULL
