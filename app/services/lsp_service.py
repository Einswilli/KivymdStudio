from __future__ import annotations

from typing import Any

from app.services.language_service import LanguageServiceRouter


class LSPClient(LanguageServiceRouter):
    """
    Compatibility facade.

    The old implementation routed Python completions through a Python-only
    engine. The new path routes editor language features through LanguageServiceRouter:
    Ferrite first, external LSP later, Batya gateway optionally.
    """

    async def start_server(self, language: str, command: list[str]) -> None:
        return None

    async def stop_server(self, language: str) -> None:
        return None

    async def stop_all(self) -> None:
        return None

    async def get_diagnostics(self, path: str, code: str = "") -> list[dict[str, Any]]:
        return await super().get_diagnostics(path, code=code)
