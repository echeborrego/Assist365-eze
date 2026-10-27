-- Enumerations only hold the values documented by the API.
SELECT "fct_ventas.PaisEmision" AS Campo, PaisEmision AS Valor FROM dwh.Poliza
WHERE PaisEmision NOT IN ("AR", "MX", "CO", "CL", "PE", "BR")
UNION ALL
SELECT "fct_ventas.CanalOrigen", CanalOrigen FROM dwh.Poliza
WHERE CanalOrigen NOT IN ("meta", "google", "organico", "agencia", "email")
UNION ALL
SELECT "fct_siniestros.Estado", Estado FROM dwh.Siniestro
WHERE Estado NOT IN ("PAGADO", "RECHAZADO", "EN_ANALISIS")
UNION ALL
SELECT "fct_siniestros.Tipo", Tipo FROM dwh.Siniestro
WHERE Tipo NOT IN ("MEDICO", "CANCELACION", "EQUIPAJE", "DEMORA")
