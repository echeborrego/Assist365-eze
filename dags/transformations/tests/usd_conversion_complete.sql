-- Every sale and every counted claim has a USD amount (FX calendar covers all dates).
SELECT "fct_ventas" AS Tabla, PolizaId AS Clave FROM ${dwh}.fct_ventas WHERE PrimaUsd IS NULL
UNION ALL
SELECT "fct_siniestros", SiniestroId FROM ${dwh}.fct_siniestros WHERE CuentaParaSiniestralidad AND MontoUsd IS NULL
