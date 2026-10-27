-- The dashboard aggregate adds up to the facts it is built from (to the cent).
WITH Agg AS (
    SELECT
        SUM(PrimaEmitidaUsd) AS Prima
        , SUM(CostoSiniestrosUsd) AS Costo
        , SUM(SiniestrosPagados) AS Pagados
    FROM dwh.SiniestralidadMensual
)
, Hechos AS (
    SELECT
        (SELECT SUM(PrimaEmitidaUsd) FROM dwh.Venta) AS Prima
        , (SELECT SUM(MontoUsd) FROM dwh.Siniestro WHERE CuentaParaSiniestralidad AND Estado = "PAGADO") AS Costo
        , (SELECT COUNT(*) FROM dwh.Siniestro WHERE CuentaParaSiniestralidad AND Estado = "PAGADO") AS Pagados
)
SELECT
    a.Prima AS PrimaAgg
    , h.Prima AS PrimaHechos
    , a.Costo AS CostoAgg
    , h.Costo AS CostoHechos
    , a.Pagados AS PagadosAgg
    , h.Pagados AS PagadosHechos
FROM Agg a, Hechos h
WHERE ABS(a.Prima - h.Prima) > 1
    OR ABS(a.Costo - h.Costo) > 1
    OR a.Pagados != h.Pagados
