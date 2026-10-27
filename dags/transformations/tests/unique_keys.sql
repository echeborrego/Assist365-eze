-- Primary keys are unique in every model.
SELECT "staging.polizas" AS Tabla, PolizaId AS Clave, COUNT(*) AS Filas FROM staging.polizas GROUP BY 1, 2 HAVING COUNT(*) > 1
UNION ALL
SELECT "staging.siniestros", SiniestroId, COUNT(*) FROM staging.siniestros GROUP BY 1, 2 HAVING COUNT(*) > 1
UNION ALL
SELECT "dwh.fct_ventas", PolizaId, COUNT(*) FROM dwh.fct_ventas GROUP BY 1, 2 HAVING COUNT(*) > 1
UNION ALL
SELECT "dwh.fct_siniestros", SiniestroId, COUNT(*) FROM dwh.fct_siniestros GROUP BY 1, 2 HAVING COUNT(*) > 1
UNION ALL
SELECT "dwh.agg_siniestralidad_mensual", FORMAT("%t|%s|%s", MesEmision, PaisEmision, ProductoId), COUNT(*)
FROM dwh.agg_siniestralidad_mensual GROUP BY 1, 2 HAVING COUNT(*) > 1
