-- Every sale and every counted claim has a USD amount (FX calendar covers all dates).
SELECT "fct_ventas" AS Tabla, PolizaId AS Clave FROM dwh.Poliza WHERE PrimaUsd IS NULL
UNION ALL
SELECT "fct_siniestros", SiniestroId FROM dwh.Siniestro WHERE CuentaParaSiniestralidad AND MontoUsd IS NULL
