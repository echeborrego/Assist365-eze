-- Row counts only change between layers through documented rules (dedupe, D9, D11).
WITH UltimoRun AS (
    SELECT
        RunId
        , StartedAt
    FROM raw.extract_runs
    WHERE Source = "siniestros"
        AND Status = "success"
    ORDER BY StartedAt DESC
    LIMIT 1
)
, Conteos AS (
    SELECT
        (
            SELECT COUNT(DISTINCT JSON_VALUE(r.Payload.claim_id))
            FROM raw.siniestros r, UltimoRun u
            WHERE r.ExtractedAt >= u.StartedAt
                AND r.RunId = u.RunId
        ) AS RawClaimIds
        , (SELECT COUNT(*) FROM staging.siniestros) AS StgSiniestros
        , (SELECT COUNTIF(NOT EsPolizaEliminada) FROM staging.siniestros) AS StgSiniestrosVivos
        , (SELECT COUNT(*) FROM dwh.fct_siniestros) AS FctSiniestros
        , (SELECT COUNT(DISTINCT JSON_VALUE(r.Payload.poliza_id)) FROM raw.polizas r) AS RawPolizaIds
        , (SELECT COUNT(*) FROM staging.polizas) AS StgPolizas
        , (SELECT COUNTIF(NOT IsDeleted) FROM staging.polizas) AS StgPolizasVivas
        , (SELECT COUNT(*) FROM dwh.fct_ventas) AS FctVentas
)
SELECT *
FROM Conteos
WHERE RawClaimIds != StgSiniestros
    OR StgSiniestrosVivos != FctSiniestros
    OR RawPolizaIds != StgPolizas
    OR StgPolizasVivas != FctVentas
