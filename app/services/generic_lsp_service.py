from __future__ import annotations

from typing import Any

from app.services.hover_renderer import render_hover
from app.services.lsp_process import ExternalLSPProcess


class GenericLSPProviderRuntime:
    def __init__(self, root_path: str | None = None) -> None:
        self._root_path = root_path
        self._providers_by_language: dict[str, list[dict[str, Any]]] = {}
        self._processes: dict[str, ExternalLSPProcess] = {}

    def configure(self, language: str, providers: list[dict[str, Any]]) -> None:
        language_key = language.strip().lower()
        if not language_key:
            return
        self._providers_by_language[language_key] = [
            provider for provider in providers if self._is_generic_provider(provider)
        ]

    async def set_workspace(self, root_path: str) -> None:
        self._root_path = root_path
        for process in self._processes.values():
            await process.set_root_path(root_path)

    def status(self, language: str) -> dict[str, Any]:
        providers = self._providers_by_language.get(language, [])
        servers = [self._process_for(provider).status() for provider in providers]
        available = [server["name"] for server in servers if server["available"]]
        running = [server["name"] for server in servers if server["running"]]
        missing = [server["name"] for server in servers if not server["available"]]
        errors = [
            f"{server['name']}: {server.get('commandError')}"
            for server in servers
            if server.get("commandError")
        ]
        return {
            "language": language,
            "servers": servers,
            "available": available,
            "running": running,
            "missing": missing,
            "errors": errors,
            "label": self._status_label(language, available, running, missing),
            "healthy": (bool(running) or bool(available) or not providers) and not errors,
        }

    async def start(self, language: str) -> dict[str, Any]:
        for provider in self._providers_by_language.get(language, []):
            await self._process_for(provider).start()
        return self.status(language)

    async def stop(self, language: str) -> dict[str, Any]:
        for provider in self._providers_by_language.get(language, []):
            await self._process_for(provider).stop()
        return self.status(language)

    async def restart(self, language: str) -> dict[str, Any]:
        for provider in self._providers_by_language.get(language, []):
            await self._process_for(provider).restart()
        return self.status(language)

    async def sync_document(self, path: str, code: str, language: str) -> None:
        for provider in self._providers_by_language.get(language, []):
            await self._process_for(provider).sync_document(path, code, language)

    async def close_document(self, path: str, language: str) -> None:
        for provider in self._providers_by_language.get(language, []):
            await self._process_for(provider).close_document(path)

    async def save_document(self, path: str, code: str, language: str) -> None:
        for provider in self._providers_by_language.get(language, []):
            await self._process_for(provider).save_document(path, code)

    async def completions(self, code: str, position: Any, path: str, language: str) -> list[dict]:
        for provider in self._capable_providers(language, "completion"):
            raw = await self._process_for(provider).completion(
                path, code, position.line - 1, position.character
            )
            items = [self._completion_item(item) for item in raw[:80]]
            if items:
                return items
        return []

    async def diagnostics(self, path: str, language: str, code: str) -> list[dict]:
        diagnostics: list[dict] = []
        for provider in self._capable_providers(language, "diagnostics"):
            diagnostics.extend(await self._process_for(provider).diagnostics(path, code))
        return diagnostics

    async def hover(self, code: str, position: Any, path: str, language: str) -> dict | None:
        for provider in self._capable_providers(language, "hover"):
            raw = await self._process_for(provider).hover(
                path, code, position.line - 1, position.character
            )
            contents = self._hover_text(raw.get("contents") if raw else None)
            if not contents:
                continue
            rendered = render_hover(
                signature="",
                documentation=contents,
                description=contents,
                language=language,
            )
            return {
                "contents": contents,
                "kind": "lsp",
                "language": language,
                "signature": "",
                "documentation": contents,
                "bodyHtml": rendered.get("body_html", ""),
                "sections": rendered.get("sections", []),
                "range": raw.get("range") if raw else None,
            }
        return None

    async def document_symbols(self, code: str, path: str, language: str) -> list[dict]:
        for provider in self._capable_providers(language, "symbols"):
            symbols = await self._process_for(provider).document_symbols(path, code)
            if symbols:
                return symbols[:200]
        return []

    async def definition(self, code: str, position: Any, path: str, language: str) -> list[dict]:
        for provider in self._capable_providers(language, "definition"):
            locations = await self._process_for(provider).definition(
                path, code, position.line - 1, position.character
            )
            if locations:
                return [self._location_item(item) for item in locations[:50]]
        return []

    async def references(self, code: str, position: Any, path: str, language: str) -> list[dict]:
        for provider in self._capable_providers(language, "references"):
            locations = await self._process_for(provider).references(
                path, code, position.line - 1, position.character
            )
            if locations:
                return [self._location_item(item) for item in locations[:200]]
        return []

    async def code_actions(
        self,
        code: str,
        position: Any,
        path: str,
        language: str,
        diagnostics: list[dict] | None = None,
    ) -> list[dict]:
        for provider in self._capable_providers(language, "codeActions"):
            actions = await self._process_for(provider).code_actions(
                path,
                code,
                position.line - 1,
                position.character,
                diagnostics,
            )
            if actions:
                return actions[:80]
        return []

    def has_providers(self, language: str) -> bool:
        return bool(self._providers_by_language.get(language, []))

    def _capable_providers(self, language: str, capability: str) -> list[dict[str, Any]]:
        providers = self._providers_by_language.get(language, [])
        return [
            provider
            for provider in providers
            if not provider.get("capabilities") or capability in provider.get("capabilities", [])
        ]

    def _process_for(self, provider: dict[str, Any]) -> ExternalLSPProcess:
        provider_id = str(provider.get("id") or provider.get("name") or "").strip()
        if provider_id not in self._processes:
            command = [str(provider.get("command") or ""), *list(provider.get("args") or [])]
            defaults = provider.get("defaults") if isinstance(provider.get("defaults"), dict) else {}
            timeout = float(defaults.get("timeout", 1.8) or 1.8)
            self._processes[provider_id] = ExternalLSPProcess(
                provider_id,
                command,
                self._root_path,
                timeout=timeout,
            )
        return self._processes[provider_id]

    @staticmethod
    def _is_generic_provider(provider: dict[str, Any]) -> bool:
        provider_id = str(provider.get("id") or provider.get("name") or "")
        command = str(provider.get("command") or "")
        return bool(provider_id and command and not provider_id.startswith("python."))

    @staticmethod
    def _completion_item(item: dict[str, Any]) -> dict[str, str]:
        label = str(item.get("label") or "")
        return {
            "name": label,
            "text": str(item.get("insertText") or label),
            "type": "word",
            "description": str(item.get("detail") or item.get("documentation") or ""),
            "color": "#ABB2BF",
        }

    @staticmethod
    def _location_item(item: dict[str, Any]) -> dict[str, Any]:
        target = item.get("targetUri") or item.get("uri") or ""
        range_info = item.get("targetSelectionRange") or item.get("targetRange") or item.get("range") or {}
        start = range_info.get("start") or {}
        end = range_info.get("end") or start
        return {
            "path": target,
            "uri": target,
            "line": int(start.get("line") or 0) + 1,
            "col": int(start.get("character") or 0),
            "endLine": int(end.get("line") or start.get("line") or 0) + 1,
            "endCol": int(end.get("character") or start.get("character") or 0),
        }

    @classmethod
    def _hover_text(cls, contents: Any) -> str:
        if isinstance(contents, str):
            return contents
        if isinstance(contents, dict):
            return str(contents.get("value") or "")
        if isinstance(contents, list):
            return "\n".join(filter(None, (cls._hover_text(item) for item in contents)))
        return ""

    @staticmethod
    def _status_label(
        language: str,
        available: list[str],
        running: list[str],
        missing: list[str],
    ) -> str:
        if running:
            return f"{language} LSP " + "+".join(running)
        if available:
            return f"{language} LSP " + "+".join(available) + " idle"
        if missing:
            return f"{language} LSP missing: " + ", ".join(missing)
        return f"{language} · Ferrite"
