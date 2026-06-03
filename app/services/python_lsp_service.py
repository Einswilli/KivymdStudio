from __future__ import annotations

import os
from typing import Any

from app.services.lsp_process import ExternalLSPProcess
from app.services.hover_renderer import render_hover


LSP_COMPLETION_KINDS = {
    1: "text",
    2: "method",
    3: "function",
    4: "constructor",
    5: "field",
    6: "variable",
    7: "class",
    8: "interface",
    9: "module",
    10: "property",
    13: "enum",
    14: "keyword",
    15: "snippet",
    17: "file",
    19: "folder",
    20: "enum_member",
    21: "constant",
    22: "struct",
    25: "type_parameter",
}

LSP_SYMBOL_KINDS = {
    1: "file",
    2: "module",
    3: "namespace",
    4: "package",
    5: "class",
    6: "method",
    7: "property",
    8: "field",
    9: "constructor",
    10: "enum",
    11: "interface",
    12: "function",
    13: "variable",
    14: "constant",
    23: "struct",
    26: "type_parameter",
}


class PythonLSPService:
    def __init__(self, root_path: str | None = None) -> None:
        root = root_path or os.getcwd()
        self._ty = ExternalLSPProcess("ty", ["ty", "server"], root)
        self._ruff = ExternalLSPProcess("ruff", ["ruff", "server"], root)
        self._servers = {
            "ty": self._ty,
            "ruff": self._ruff,
        }
        self._active_names = ["ty", "ruff"]

    def set_active_providers(self, provider_ids: list[str]) -> None:
        names = []
        for provider_id in provider_ids or []:
            name = provider_id.split(".", 1)[1] if provider_id.startswith("python.") else provider_id
            if name in self._servers and name not in names:
                names.append(name)
        self._active_names = names or ["ty", "ruff"]

    def status(self) -> dict[str, Any]:
        servers = [server.status() for server in self._active_servers()]
        available = [server["name"] for server in servers if server["available"]]
        running = [server["name"] for server in servers if server["running"]]
        missing = [server["name"] for server in servers if not server["available"]]
        return {
            "language": "python",
            "servers": servers,
            "available": available,
            "running": running,
            "missing": missing,
            "label": self._status_label(available, running, missing),
            "healthy": bool(running) or bool(available),
        }

    async def set_workspace(self, root_path: str) -> dict[str, Any]:
        for server in self._active_servers():
            await server.set_root_path(root_path)
        return self.status()

    async def sync_document(self, path: str, code: str, language: str = "python") -> None:
        if language != "python" or not path:
            return
        for server in self._active_servers():
            await server.sync_document(path, code, language)

    async def close_document(self, path: str) -> None:
        if not path:
            return
        for server in self._active_servers():
            await server.close_document(path)

    async def save_document(self, path: str, code: str, language: str = "python") -> None:
        if language != "python" or not path:
            return
        for server in self._active_servers():
            await server.save_document(path, code)

    async def completions(
        self,
        code: str,
        position: Any,
        path: str = "",
        language: str = "python",
    ) -> list[dict[str, str]]:
        if language != "python":
            return []
        if "ty" not in self._active_names:
            return []
        items = await self._ty.completion(path, code, position.line - 1, position.character)
        return [self._completion_item(item) for item in items[:80]]

    async def diagnostics(
        self,
        path: str,
        language: str = "python",
        code: str = "",
    ) -> list[dict[str, Any]]:
        if language != "python":
            return []
        diagnostics = []
        if code:
            if "ty" in self._active_names:
                diagnostics.extend(await self._ty.diagnostics(path, code))
            if "ruff" in self._active_names:
                diagnostics.extend(await self._ruff.diagnostics(path, code))
        return diagnostics

    async def code_actions(
        self,
        code: str,
        position: Any,
        path: str = "",
        language: str = "python",
        diagnostics: list[dict[str, Any]] | None = None,
    ) -> list[dict[str, Any]]:
        if language != "python" or not path:
            return []
        for name in ("ruff", "ty"):
            if name not in self._active_names:
                continue
            raw_actions = await self._servers[name].code_actions(
                path,
                code,
                position.line - 1,
                position.character,
                diagnostics,
            )
            actions = [self._code_action_item(action) for action in raw_actions[:80]]
            if actions:
                return actions
        return []

    async def hover(
        self,
        code: str,
        position: Any,
        path: str = "",
        language: str = "python",
    ) -> dict[str, Any] | None:
        if language != "python":
            return None
        if "ty" not in self._active_names:
            return None
        hover = await self._ty.hover(path, code, position.line - 1, position.character)
        if not hover:
            return None
        contents = self._hover_text(hover.get("contents"))
        if not contents:
            return None
        signature, documentation = self._split_hover_markdown(contents)
        rendered = render_hover(
            signature=signature,
            documentation=documentation,
            description=contents,
            language="python",
        )
        return {
            "contents": contents,
            "kind": "lsp",
            "language": "python",
            "signature": signature,
            "documentation": documentation,
            "bodyHtml": rendered.get("body_html", ""),
            "sections": rendered.get("sections", []),
            "range": hover.get("range"),
        }

    async def document_symbols(
        self,
        code: str,
        path: str = "",
        language: str = "python",
    ) -> list[dict[str, Any]]:
        if language != "python":
            return []
        if "ty" not in self._active_names:
            return []
        symbols = await self._ty.document_symbols(path, code)
        return self._flatten_symbols(symbols)

    async def format_code(self, path: str, language: str = "python") -> str:
        return ""

    async def start(self) -> dict[str, Any]:
        for server in self._active_servers():
            await server.start()
        return self.status()

    async def stop(self) -> dict[str, Any]:
        for server in self._active_servers():
            await server.stop()
        return self.status()

    async def restart(self) -> dict[str, Any]:
        for server in self._active_servers():
            await server.restart()
        return self.status()

    def _active_servers(self) -> list[ExternalLSPProcess]:
        return [self._servers[name] for name in self._active_names if name in self._servers]

    @staticmethod
    def _status_label(available: list[str], running: list[str], missing: list[str]) -> str:
        if running:
            return "LSP " + "+".join(running)
        if available:
            return "LSP " + "+".join(available) + " idle"
        if missing:
            return "LSP missing: " + ", ".join(missing)
        return "LSP off"

    @staticmethod
    def _completion_item(item: dict[str, Any]) -> dict[str, str]:
        label = str(item.get("label") or "")
        insert_text = str(item.get("insertText") or label)
        kind = LSP_COMPLETION_KINDS.get(int(item.get("kind") or 0), "word")
        detail = str(item.get("detail") or item.get("documentation") or "")
        return {
            "name": label,
            "text": insert_text,
            "type": kind,
            "description": detail or f"python {kind}",
            "color": _completion_color(kind),
        }

    @staticmethod
    def _code_action_item(item: dict[str, Any]) -> dict[str, Any]:
        title = str(item.get("title") or "")
        return {
            "title": title,
            "kind": str(item.get("kind") or "quickfix"),
            "isPreferred": bool(item.get("isPreferred") or False),
            "disabled": item.get("disabled") or {},
            "edit": item.get("edit") or {},
            "command": item.get("command") or {},
            "raw": item,
        }

    @classmethod
    def _hover_text(cls, contents: Any) -> str:
        if isinstance(contents, str):
            return contents
        if isinstance(contents, dict):
            value = contents.get("value")
            return str(value or "")
        if isinstance(contents, list):
            return "\n".join(filter(None, (cls._hover_text(item) for item in contents)))
        return ""

    @classmethod
    def _flatten_symbols(cls, symbols: list[dict[str, Any]]) -> list[dict[str, Any]]:
        output: list[dict[str, Any]] = []
        for item in symbols:
            cls._append_symbol(output, item)
        return output[:500]

    @classmethod
    def _append_symbol(cls, output: list[dict[str, Any]], item: dict[str, Any]) -> None:
        name = str(item.get("name") or "")
        if name:
            range_info = item.get("selectionRange") or item.get("range") or {}
            start = range_info.get("start") or {}
            output.append({
                "name": name,
                "kind": LSP_SYMBOL_KINDS.get(int(item.get("kind") or 0), "symbol"),
                "line": int(start.get("line") or 0) + 1,
                "start": int(start.get("character") or 0),
                "end": int((range_info.get("end") or {}).get("character") or start.get("character") or 0),
            })
        for child in item.get("children") or []:
            if isinstance(child, dict):
                cls._append_symbol(output, child)

    @staticmethod
    def _split_hover_markdown(contents: str) -> tuple[str, str]:
        text = contents.strip()
        if not text:
            return "", ""
        if "---" not in text:
            return text, ""
        signature, documentation = text.split("---", 1)
        signature = signature.strip()
        documentation = documentation.strip()
        if signature.startswith("```"):
            lines = signature.splitlines()
            if len(lines) >= 3:
                signature = "\n".join(lines[1:-1]).strip()
        return signature, documentation


def _completion_color(type_: str) -> str:
    return {
        "class": "#E5C07B",
        "constructor": "#E5C07B",
        "constant": "#D19A66",
        "enum": "#E5C07B",
        "enum_member": "#D19A66",
        "field": "#ABB2BF",
        "function": "#61AFEF",
        "interface": "#E5C07B",
        "keyword": "#C678DD",
        "method": "#61AFEF",
        "module": "#56B6C2",
        "property": "#ABB2BF",
        "snippet": "#98C379",
        "struct": "#E5C07B",
        "type_parameter": "#E5C07B",
        "variable": "#ABB2BF",
        "word": "#ABB2BF",
    }.get(type_, "#ABB2BF")
