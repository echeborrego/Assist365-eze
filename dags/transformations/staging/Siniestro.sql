-- Grain: one row per claim_id from the latest successful daily snapshot.
-- Data-quality flags are kept on the row; dwh decides what counts (see docs/DECISIONS.md).
DECLARE UltimoRun STRING;
DECLARE UltimoExtract TIMESTAMP;

SET (UltimoRun, UltimoExtract) = (
    SELECT AS STRUCT
        RunId
        , StartedAt
    FROM raw.ExtractRun
    WHERE Source = "siniestros"
        AND Status = "success"
    ORDER BY StartedAt DESC
    LIMIT 1
);

IF UltimoRun IS NULL THEN
    RAISE USING MESSAGE = "No successful siniestros extract in raw.ExtractRun";
END IF;

-- The API has no creation date, so the first snapshot a claim appears in stands in for it.
-- Kept forever: a claim dated after the day we first saw it stays flagged as future-dated (D8).
CREATE TABLE IF NOT EXISTS staging.SiniestroPrimeraVez (
    SiniestroId STRING NOT NULL
    , PrimeraVezAt TIMESTAMP NOT NULL
    , PrimeraVezRunId STRING NOT NULL
);

MERGE staging.SiniestroPrimeraVez t
USING (
    SELECT DISTINCT
        JSON_VALUE(r.Payload.claim_id) AS SiniestroId
    FROM raw.Siniestro r
    WHERE r.ExtractedAt >= UltimoExtract
        AND r.RunId = UltimoRun
) s
ON t.SiniestroId = s.SiniestroId
WHEN NOT MATCHED THEN
    INSERT (SiniestroId, PrimeraVezAt, PrimeraVezRunId)
    VALUES (s.SiniestroId, UltimoExtract, UltimoRun);

CREATE OR REPLACE TABLE staging.Siniestro
CLUSTER BY PolizaId AS
WITH Snapshot AS (
    SELECT
        JSON_VALUE(r.Payload.claim_id) AS SiniestroId
        , JSON_VALUE(r.Payload.policy_id) AS PolizaId
        , COALESCE(
            SAFE.PARSE_DATE("%Y-%m-%d", JSON_VALUE(r.Payload.occurred_at))
            , SAFE.PARSE_DATE("%d/%m/%Y", JSON_VALUE(r.Payload.occurred_at))
        ) AS FechaOcurrencia
        , COALESCE(
            SAFE.PARSE_DATE("%Y-%m-%d", JSON_VALUE(r.Payload.reported_at))
            , SAFE.PARSE_DATE("%d/%m/%Y", JSON_VALUE(r.Payload.reported_at))
        ) AS FechaReporte
        , JSON_VALUE(r.Payload.type) AS Tipo
        , JSON_VALUE(r.Payload.status) AS Estado
        , SAFE_CAST(JSON_VALUE(r.Payload.amount.value) AS NUMERIC) AS MontoOrigen
        , JSON_VALUE(r.Payload.amount.currency) AS MonedaOrigen
        , JSON_VALUE(r.Payload.detail.proveedor) AS Proveedor
        , COALESCE(JSON_VALUE(r.Payload.detail.diagnostico), JSON_VALUE(r.Payload.detail.diagnosis)) AS Diagnostico
        , COALESCE(JSON_VALUE(r.Payload.detail.ciudad_atencion), JSON_VALUE(r.Payload.detail.city)) AS CiudadAtencion
        , r.Payload.detail AS DetalleOrigen
    FROM raw.Siniestro r
    WHERE r.ExtractedAt >= UltimoExtract
        AND r.RunId = UltimoRun
    QUALIFY ROW_NUMBER() OVER (PARTITION BY JSON_VALUE(r.Payload.claim_id) ORDER BY r.Page) = 1
)
SELECT
    s.SiniestroId
    , s.PolizaId
    , s.FechaOcurrencia
    , s.FechaReporte
    , s.Tipo
    , s.Estado
    , ABS(s.MontoOrigen) AS Monto
    , COALESCE(s.MonedaOrigen, p.Moneda) AS Moneda
    , s.Proveedor
    , s.Diagnostico
    , s.CiudadAtencion
    , s.DetalleOrigen
    , s.MontoOrigen < 0 AS EsMontoNegativoOrigen
    , s.MonedaOrigen IS NULL AS EsMonedaInferida
    , DATE(pv.PrimeraVezAt, "America/Argentina/Buenos_Aires") AS FechaPrimeraVez
    , s.FechaOcurrencia > DATE(pv.PrimeraVezAt, "America/Argentina/Buenos_Aires") AS EsFechaFutura
    , p.PolizaId IS NULL AS EsPolizaInexistente
    , IFNULL(p.IsDeleted, FALSE) AS EsPolizaEliminada
    , IFNULL(p.Estado = "ANULADA", FALSE) AS EsPolizaAnulada
    , s.FechaOcurrencia NOT BETWEEN p.InicioVigencia AND p.FinVigencia AS EsFueraDeVigencia
    , s.FechaReporte < s.FechaOcurrencia AS EsReporteAntesDeOcurrencia
FROM Snapshot s
JOIN staging.SiniestroPrimeraVez pv ON pv.SiniestroId = s.SiniestroId
LEFT JOIN staging.Poliza p ON p.PolizaId = s.PolizaId
