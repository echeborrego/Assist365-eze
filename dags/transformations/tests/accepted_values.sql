-- Enumerations only hold the values documented by the API.
SELECT "fct_ventas.PaisEmision" AS Campo, PaisEmision AS Valor FROM ${dwh}.fct_ventas
WHERE PaisEmision NOT IN ("AR", "MX", "CO", "CL", "PE", "BR")
UNION ALL
SELECT "fct_ventas.CanalOrigen", CanalOrigen FROM ${dwh}.fct_ventas
WHERE CanalOrigen NOT IN ("meta", "google", "organico", "agencia", "email")
UNION ALL
SELECT "fct_siniestros.Estado", Estado FROM ${dwh}.fct_siniestros
WHERE Estado NOT IN ("PAGADO", "RECHAZADO", "EN_ANALISIS")
UNION ALL
SELECT "fct_siniestros.Tipo", Tipo FROM ${dwh}.fct_siniestros
WHERE Tipo NOT IN ("MEDICO", "CANCELACION", "EQUIPAJE", "DEMORA")
