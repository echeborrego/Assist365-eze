-- Grain: one row per issuing country.
CREATE OR REPLACE TABLE dwh.Pais AS
SELECT * FROM UNNEST([
    STRUCT("AR" AS PaisId, "Argentina" AS NombrePais, "ARS" AS MonedaLocal, "America/Argentina/Buenos_Aires" AS ZonaHoraria)
    , ("BR", "Brasil", "BRL", "America/Sao_Paulo")
    , ("CL", "Chile", "CLP", "America/Santiago")
    , ("CO", "Colombia", "COP", "America/Bogota")
    , ("MX", "México", "MXN", "America/Mexico_City")
    , ("PE", "Perú", "PEN", "America/Lima")
])
