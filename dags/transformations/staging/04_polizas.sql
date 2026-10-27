-- Grain: one row per poliza_id, its latest state in the CDC stream (deletes kept with IsDeleted).
-- Incremental: only raw partitions loaded since the last run are read and merged in.
-- Reads one day back from the watermark: a slower run can commit rows stamped before it (ExtractedAt is
-- set when spooling starts), and the MERGE only applies newer changes, so reprocessing is harmless.
-- Rebuild: drop staging.polizas; an empty table reprocesses all of raw.
DECLARE Desde TIMESTAMP;
DECLARE Hasta TIMESTAMP;

CREATE TABLE IF NOT EXISTS staging.watermarks (
    Modelo STRING NOT NULL
    , ProcesadoHasta TIMESTAMP NOT NULL
    , ActualizadoAt TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS staging.polizas (
    PolizaId STRING NOT NULL
    , ClienteId STRING
    , ProductoId STRING
    , AgenciaId STRING
    , PaisEmision STRING
    , CanalOrigen STRING
    , FechaEmisionUtc TIMESTAMP
    , FechaEmision DATE
    , InicioVigencia DATE
    , FinVigencia DATE
    , Prima NUMERIC
    , Moneda STRING
    , Estado STRING
    , IsDeleted BOOL
    , UltimaOp STRING
    , UpdatedAt TIMESTAMP
    , ExtractedAt TIMESTAMP
)
CLUSTER BY PaisEmision, ProductoId;

SET Desde = IF(
    (SELECT COUNT(*) FROM staging.polizas) = 0
    , TIMESTAMP "1970-01-01"
    , (SELECT MAX(ProcesadoHasta) FROM staging.watermarks WHERE Modelo = "polizas")
);
SET Desde = TIMESTAMP_SUB(IFNULL(Desde, TIMESTAMP "1970-01-02"), INTERVAL 1 DAY);
SET Hasta = (SELECT MAX(r.ExtractedAt) FROM raw.polizas r WHERE r.ExtractedAt > Desde);

IF Hasta IS NOT NULL THEN
    BEGIN TRANSACTION;

    MERGE staging.polizas t
    USING (
        WITH Cambios AS (
            SELECT
                JSON_VALUE(r.Payload.poliza_id) AS PolizaId
                , JSON_VALUE(r.Payload.cliente_id) AS ClienteId
                , JSON_VALUE(r.Payload.producto_id) AS ProductoId
                , JSON_VALUE(r.Payload.agencia_id) AS AgenciaId
                , JSON_VALUE(r.Payload.pais_emision) AS PaisEmision
                , JSON_VALUE(r.Payload.canal_origen) AS CanalOrigen
                , SAFE.PARSE_TIMESTAMP("%Y-%m-%dT%H:%M:%SZ", JSON_VALUE(r.Payload.fecha_emision_utc)) AS FechaEmisionUtc
                , DATE(SAFE.PARSE_TIMESTAMP("%Y-%m-%dT%H:%M:%SZ", JSON_VALUE(r.Payload.inicio_vigencia))) AS InicioVigencia
                , DATE(SAFE.PARSE_TIMESTAMP("%Y-%m-%dT%H:%M:%SZ", JSON_VALUE(r.Payload.fin_vigencia))) AS FinVigencia
                , SAFE_CAST(JSON_VALUE(r.Payload.prima) AS NUMERIC) AS Prima
                , JSON_VALUE(r.Payload.moneda) AS Moneda
                , JSON_VALUE(r.Payload.estado) AS Estado
                , JSON_VALUE(r.Payload.op) AS Op
                , SAFE.PARSE_TIMESTAMP("%Y-%m-%dT%H:%M:%SZ", JSON_VALUE(r.Payload.updated_at)) AS UpdatedAt
                , r.ExtractedAt
            FROM raw.polizas r
            WHERE r.ExtractedAt > Desde
                AND r.ExtractedAt <= Hasta
        )
        , ZonaHoraria AS (
            SELECT * FROM UNNEST([
                STRUCT("AR" AS Pais, "America/Argentina/Buenos_Aires" AS Zona)
                , ("BR", "America/Sao_Paulo")
                , ("CL", "America/Santiago")
                , ("CO", "America/Bogota")
                , ("MX", "America/Mexico_City")
                , ("PE", "America/Lima")
            ])
        )
        SELECT
            c.PolizaId
            , c.ClienteId
            , c.ProductoId
            , c.AgenciaId
            , c.PaisEmision
            , c.CanalOrigen
            , c.FechaEmisionUtc
            , DATE(c.FechaEmisionUtc, IFNULL(z.Zona, "America/Argentina/Buenos_Aires")) AS FechaEmision
            , c.InicioVigencia
            , c.FinVigencia
            , c.Prima
            , c.Moneda
            , c.Estado
            , c.Op = "D" AS IsDeleted
            , c.Op AS UltimaOp
            , CASE c.Op WHEN "D" THEN 3 WHEN "U" THEN 2 ELSE 1 END AS OpRank
            , c.UpdatedAt
            , c.ExtractedAt
        FROM Cambios c
        LEFT JOIN ZonaHoraria z ON z.Pais = c.PaisEmision
        QUALIFY ROW_NUMBER() OVER (
            PARTITION BY c.PolizaId
            ORDER BY c.UpdatedAt DESC, OpRank DESC, c.ExtractedAt DESC
        ) = 1
    ) s
    ON t.PolizaId = s.PolizaId
    -- Only a newer change replaces the stored state; on a timestamp tie a delete beats an update beats an insert
    WHEN MATCHED AND (
        s.UpdatedAt > t.UpdatedAt
        OR (s.UpdatedAt = t.UpdatedAt AND s.OpRank > CASE t.UltimaOp WHEN "D" THEN 3 WHEN "U" THEN 2 ELSE 1 END)
    ) THEN UPDATE SET
        ClienteId = s.ClienteId
        , ProductoId = s.ProductoId
        , AgenciaId = s.AgenciaId
        , PaisEmision = s.PaisEmision
        , CanalOrigen = s.CanalOrigen
        , FechaEmisionUtc = s.FechaEmisionUtc
        , FechaEmision = s.FechaEmision
        , InicioVigencia = s.InicioVigencia
        , FinVigencia = s.FinVigencia
        , Prima = s.Prima
        , Moneda = s.Moneda
        , Estado = s.Estado
        , IsDeleted = s.IsDeleted
        , UltimaOp = s.UltimaOp
        , UpdatedAt = s.UpdatedAt
        , ExtractedAt = s.ExtractedAt
    WHEN NOT MATCHED THEN INSERT (
        PolizaId, ClienteId, ProductoId, AgenciaId, PaisEmision, CanalOrigen, FechaEmisionUtc, FechaEmision
        , InicioVigencia, FinVigencia, Prima, Moneda, Estado, IsDeleted, UltimaOp, UpdatedAt, ExtractedAt
    ) VALUES (
        s.PolizaId, s.ClienteId, s.ProductoId, s.AgenciaId, s.PaisEmision, s.CanalOrigen, s.FechaEmisionUtc, s.FechaEmision
        , s.InicioVigencia, s.FinVigencia, s.Prima, s.Moneda, s.Estado, s.IsDeleted, s.UltimaOp, s.UpdatedAt, s.ExtractedAt
    );

    DELETE FROM staging.watermarks WHERE Modelo = "polizas";
    INSERT INTO staging.watermarks (Modelo, ProcesadoHasta, ActualizadoAt)
    VALUES ("polizas", Hasta, CURRENT_TIMESTAMP());

    COMMIT TRANSACTION;
END IF;
