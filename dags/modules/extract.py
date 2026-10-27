from collections.abc import Iterator

from modules.api_client import ApiClient

SINIESTROS_PAGE_SIZE = 500
CATALOGOS = ("productos", "agencias", "tipo_cambio")


def polizas(client: ApiClient, updated_since: str | None = None) -> Iterator[tuple[int, list[dict]]]:
    """Yields (page, rows) along the CDC cursor; with updated_since the first page overlaps the watermark."""
    params = {"updated_since": updated_since} if updated_since else {}
    page, seen_cursors = 0, set()
    while True:
        body = client.get("/polizas", params)
        yield page, body["data"]
        pagination = body["pagination"]
        cursor = pagination.get("next_cursor")
        if not pagination.get("has_more") or not cursor:
            return
        if cursor in seen_cursors:
            raise RuntimeError(f"Cursor {cursor} repeated at page {page}, aborting to avoid a loop")
        seen_cursors.add(cursor)
        params = {"cursor": cursor}
        page += 1


def siniestros(client: ApiClient, meta: dict) -> Iterator[tuple[int, list[dict]]]:
    """Yields (page, rows) by offset until the reported total; past the end the API returns an empty page.

    Fills meta["total"] with the API's own row count, for the completeness check.
    """
    offset = 0
    while True:
        body = client.get("/siniestros", {"offset": offset})
        rows, total = body["data"], body["meta"]["total"]
        meta["total"] = total
        if not rows:
            return
        yield offset // SINIESTROS_PAGE_SIZE, rows
        offset += SINIESTROS_PAGE_SIZE
        if offset >= total:
            return


def catalogo(client: ApiClient, tipo: str) -> tuple[list[dict], int]:
    body = client.get("/catalogos", {"tipo": tipo})
    return body["data"], body["meta"]["total"]
