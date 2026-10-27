"""Regression check for the MCP server: runs five fixed queries through it over stdio and writes docs/MCP_CHECK.md.

The natural-language answers (skill + MCP in Claude Code) are in docs/MCP_SESSION.md; this script only proves the
server still answers the same questions with the same numbers.
"""
import asyncio
import json
import sys
from pathlib import Path

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

ROOT = Path(__file__).resolve().parent.parent

QUESTIONS = [
    (
        "¿Qué país tuvo la peor siniestralidad en el último trimestre cerrado?",
        """SELECT
    FORMAT_DATE("%Y-Q%Q", a.TrimestreEmision) AS Trimestre
    , a.NombrePais
    , ROUND(SAFE_DIVIDE(SUM(a.CostoSiniestrosUsd), SUM(a.PrimaEmitidaUsd)), 3) AS Siniestralidad
    , ROUND(SAFE_DIVIDE(SUM(a.PolizasCoberturaTerminada), SUM(a.Polizas)), 3) AS Madurez
FROM dwh.SiniestralidadMensual a
WHERE a.TrimestreEmision = "2026-04-01"
GROUP BY 1, 2
ORDER BY 3 DESC""",
    ),
    (
        "¿Qué plan destruye más margen, y es por frecuencia, severidad o precio?",
        """SELECT
    a.NombrePlan
    , ROUND(SAFE_DIVIDE(SUM(a.CostoSiniestrosUsd), SUM(a.PrimaEmitidaUsd)), 3) AS Siniestralidad
    , ROUND(SAFE_DIVIDE(SUM(a.SiniestrosPagadosConCobertura), SUM(a.Polizas)), 3) AS Frecuencia
    , ROUND(SAFE_DIVIDE(SUM(a.CostoSiniestrosUsd), SUM(a.SiniestrosPagados)), 0) AS SeveridadUsd
    , ROUND(SAFE_DIVIDE(SUM(a.PrimaEmitidaUsd), SUM(a.Polizas)), 1) AS PrimaMediaUsd
FROM dwh.SiniestralidadMensual a
GROUP BY 1
ORDER BY 2 DESC
LIMIT 3""",
    ),
    (
        "¿Cuánto pagaron los planes de equipaje y cancelación en siniestros de otro tipo de riesgo?",
        """SELECT
    t.NombrePlan
    , ROUND(SUM(IF(NOT t.EsRiesgoDelPlan, t.PagadoUsd, 0)), 0) AS PagadoFueraDelRiesgoUsd
    , ROUND(SAFE_DIVIDE(SUM(IF(NOT t.EsRiesgoDelPlan, t.PagadoUsd, 0)), SUM(t.PagadoUsd)), 3) AS Share
FROM dwh.SiniestroPorTipo t
WHERE t.TipoPlan IN ("EQUIPAJE", "CANCELACION")
GROUP BY 1""",
    ),
    (
        "¿Qué canal de venta compra con más anticipación respecto del viaje (último trimestre cerrado)?",
        """SELECT
    v.CanalOrigen
    , COUNT(*) AS Polizas
    , ROUND(AVG(v.DiasAnticipacion), 1) AS DiasAnticipacionPromedio
FROM dwh.Poliza v
WHERE v.FechaEmision BETWEEN "2026-04-01" AND "2026-06-30"
    AND NOT v.EsAnulada
GROUP BY 1
ORDER BY 3 DESC""",
    ),
    (
        "¿Cuánta exposición pendiente (siniestros en análisis) hay por país, en USD?",
        """SELECT
    a.NombrePais
    , SUM(a.SiniestrosEnAnalisis) AS SiniestrosEnAnalisis
    , ROUND(SUM(a.EnAnalisisUsd), 0) AS EnAnalisisUsd
    , ROUND(SAFE_DIVIDE(SUM(a.EnAnalisisUsd), SUM(a.CostoSiniestrosUsd)), 3) AS SobreCostoPagado
FROM dwh.SiniestralidadMensual a
GROUP BY 1
ORDER BY 3 DESC""",
    ),
]


def _table(rows: list[dict]) -> str:
    if not rows:
        return "_no rows_"
    cols = list(rows[0])
    lines = ["| " + " | ".join(cols) + " |", "|" + "---|" * len(cols)]
    lines += ["| " + " | ".join(str(r[c]) for c in cols) + " |" for r in rows]
    return "\n".join(lines)


async def main() -> None:
    server = StdioServerParameters(command=sys.executable, args=[str(ROOT / "mcp_server" / "bigquery_server.py")])
    out = ["# MCP server check", "",
           "Fixed SQL for the five business questions, run through the `execute_sql` tool of the `assist365-bigquery`",
           "MCP server over stdio (`mcp_server/ask.py`). The natural-language answers are in `MCP_SESSION.md`.", ""]
    async with stdio_client(server) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            tools = [t.name for t in (await session.list_tools()).tools]
            out += [f"MCP tools exposed: `{'`, `'.join(tools)}`", ""]
            for i, (question, sql) in enumerate(QUESTIONS, 1):
                result = await session.call_tool("execute_sql", {"sql": sql})
                payload = json.loads(result.content[0].text)
                out += [f"## {i}. {question}", "", "```sql", sql, "```", ""]
                if "error" in payload:
                    out += [f"**Error:** {payload['error']}", ""]
                else:
                    out += [_table(payload["rows"]), "", f"_{payload['mb_processed']} MB processed_", ""]
    (ROOT / "docs" / "MCP_CHECK.md").write_text("\n".join(out))


if __name__ == "__main__":
    asyncio.run(main())
