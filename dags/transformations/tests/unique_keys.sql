-- Primary keys are unique in every model.
SELECT "staging.Poliza" AS Tabla, PolizaId AS Clave, COUNT(*) AS Filas FROM staging.Poliza GROUP BY 1, 2 HAVING COUNT(*) > 1
UNION ALL
SELECT "staging.Siniestro", SiniestroId, COUNT(*) FROM staging.Siniestro GROUP BY 1, 2 HAVING COUNT(*) > 1
UNION ALL
SELECT "dwh.Venta", PolizaId, COUNT(*) FROM dwh.Venta GROUP BY 1, 2 HAVING COUNT(*) > 1
UNION ALL
SELECT "dwh.Siniestro", SiniestroId, COUNT(*) FROM dwh.Siniestro GROUP BY 1, 2 HAVING COUNT(*) > 1
UNION ALL
SELECT "dwh.SiniestralidadMensual", FORMAT("%t|%s|%s", MesEmision, PaisEmision, ProductoId), COUNT(*)
FROM dwh.SiniestralidadMensual GROUP BY 1, 2 HAVING COUNT(*) > 1
