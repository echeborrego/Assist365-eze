-- The dashboard aggregates add up to the facts they are built from (to the dollar).
WITH Agg AS (
    SELECT
        SUM(PrimaEmitidaUsd) AS Prima
        , SUM(CostoSiniestrosUsd) AS Costo
        , SUM(SiniestrosPagados) AS Pagados
    FROM dwh.SiniestralidadMensual
)
, PorTipo AS (
    SELECT
        SUM(PagadoUsd) AS Costo
        , SUM(SiniestrosPagados) AS Pagados
    FROM dwh.SiniestroPorTipo
)
, Hechos AS (
    SELECT
        (SELECT SUM(PrimaEmitidaUsd) FROM dwh.Poliza) AS Prima
        , (SELECT SUM(MontoUsd) FROM dwh.Siniestro WHERE CuentaParaSiniestralidad AND Estado = "PAGADO") AS Costo
        , (SELECT COUNT(*) FROM dwh.Siniestro WHERE CuentaParaSiniestralidad AND Estado = "PAGADO") AS Pagados
)
SELECT
    a.Prima AS PrimaAgg
    , h.Prima AS PrimaHechos
    , a.Costo AS CostoAgg
    , t.Costo AS CostoPorTipo
    , h.Costo AS CostoHechos
    , a.Pagados AS PagadosAgg
    , t.Pagados AS PagadosPorTipo
    , h.Pagados AS PagadosHechos
FROM Agg a, PorTipo t, Hechos h
WHERE ABS(a.Prima - h.Prima) > 1
    OR ABS(a.Costo - h.Costo) > 1
    OR ABS(t.Costo - h.Costo) > 1
    OR a.Pagados != h.Pagados
    OR t.Pagados != h.Pagados
