-- Row counts only change between layers through documented rules (dedupe, D9, D11).
WITH UltimoRun AS (
    SELECT
        RunId
        , StartedAt
    FROM raw.ExtractRun
    WHERE Source = "siniestros"
        AND Status = "success"
    ORDER BY StartedAt DESC
    LIMIT 1
)
, Conteos AS (
    SELECT
        (
            SELECT COUNT(DISTINCT JSON_VALUE(r.Payload.claim_id))
            FROM raw.Siniestro r, UltimoRun u
            WHERE r.ExtractedAt >= u.StartedAt
                AND r.RunId = u.RunId
        ) AS RawClaimIds
        , (SELECT COUNT(*) FROM staging.Siniestro) AS StgSiniestros
        , (SELECT COUNTIF(NOT EsPolizaEliminada) FROM staging.Siniestro) AS StgSiniestrosVivos
        , (SELECT COUNT(*) FROM dwh.Siniestro) AS FctSiniestros
        , (SELECT COUNT(DISTINCT JSON_VALUE(r.Payload.poliza_id)) FROM raw.Poliza r) AS RawPolizaIds
        , (SELECT COUNT(*) FROM staging.Poliza) AS StgPolizas
        , (SELECT COUNTIF(NOT IsDeleted) FROM staging.Poliza) AS StgPolizasVivas
        , (SELECT COUNT(*) FROM dwh.Venta) AS FctVentas
)
SELECT *
FROM Conteos
WHERE RawClaimIds != StgSiniestros
    OR StgSiniestrosVivos != FctSiniestros
    OR RawPolizaIds != StgPolizas
    OR StgPolizasVivas != FctVentas
