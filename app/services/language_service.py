from __future__ import annotations

import asyncio
import json
import os
import re
from dataclasses import dataclass
from typing import Any, Protocol

from app.services.hover_renderer import render_hover
from app.services.language_detection import detect_language
from app.services.generic_lsp_service import GenericLSPProviderRuntime
from app.services.python_lsp_service import PythonLSPService

try:
    import ferrite

    HAS_FERRITE = True
except Exception:
    ferrite = None
    HAS_FERRITE = False


@dataclass(slots=True, frozen=True)
class TextPosition:
    line: int
    character: int
    offset: int


class LanguageService(Protocol):
    async def completions(
        self,
        code: str,
        position: TextPosition,
        path: str = "",
        language: str = "text",
    ) -> list[dict[str, str]]:
        ...

    async def diagnostics(
        self,
        path: str,
        language: str = "text",
        code: str = "",
    ) -> list[dict[str, Any]]:
        ...

    async def hover(
        self,
        code: str,
        position: TextPosition,
        path: str = "",
        language: str = "text",
    ) -> dict[str, Any] | None:
        ...

    async def document_symbols(
        self,
        code: str,
        path: str = "",
        language: str = "text",
    ) -> list[dict[str, Any]]:
        ...

    async def format_code(self, path: str, language: str = "text") -> str:
        ...


LANGUAGE_KEYWORDS: dict[str, set[str]] = {
    "python": {
        "False", "None", "True", "and", "as", "assert", "async", "await", "break",
        "class", "continue", "def", "del", "elif", "else", "except", "finally", "for",
        "from", "global", "if", "import", "in", "is", "lambda", "nonlocal", "not", "or",
        "pass", "raise", "return", "try", "while", "with", "yield",
    },
    "javascript": {
        "async", "await", "break", "case", "catch", "class", "const", "continue",
        "default", "delete", "do", "else", "export", "extends", "finally", "for",
        "from", "function", "if", "import", "in", "instanceof", "let", "new", "return",
        "super", "switch", "this", "throw", "try", "typeof", "var", "void", "while",
    },
    "typescript": {
        "abstract", "any", "as", "async", "await", "boolean", "break", "case", "catch",
        "class", "const", "constructor", "continue", "declare", "default", "else",
        "enum", "export", "extends", "finally", "for", "from", "function", "if",
        "implements", "import", "interface", "let", "namespace", "new", "private",
        "protected", "public", "readonly", "return", "string", "super", "switch",
        "this", "throw", "try", "type", "typeof", "void", "while",
    },
    "rust": {
        "as", "async", "await", "break", "const", "continue", "crate", "else", "enum",
        "extern", "false", "fn", "for", "if", "impl", "in", "let", "loop", "match",
        "mod", "move", "mut", "pub", "ref", "return", "self", "Self", "static",
        "struct", "super", "trait", "true", "type", "unsafe", "use", "where", "while",
    },
    "qml": {
        "ApplicationWindow", "Component", "Item", "ListView", "MouseArea", "QtObject",
        "Rectangle", "Repeater", "Text", "TextField", "property", "readonly", "signal",
        "anchors", "color", "height", "id", "model", "onClicked", "parent", "width",
    },
    "kivy": {
        "AnchorLayout", "BoxLayout", "Button", "FloatLayout", "GridLayout", "Label",
        "MDApp", "MDBoxLayout", "MDLabel", "Screen", "ScreenManager", "Widget",
        "canvas", "id", "on_press", "orientation", "pos_hint", "size_hint", "text",
    },
    "json": {"false", "null", "true"},
    "yaml": {"false", "null", "true", "yes", "no"},
    "toml": {"false", "true"},
    "html": {"body", "button", "div", "head", "html", "input", "link", "meta", "script", "span"},
    "css": {"align-items", "background", "border", "color", "display", "flex", "font-size", "margin", "padding"},
    "go": {"break", "case", "chan", "const", "continue", "defer", "else", "fallthrough", "for", "func", "go", "if", "import", "interface", "map", "package", "range", "return", "select", "struct", "switch", "type", "var"},
    "java": {"abstract", "class", "else", "extends", "final", "for", "if", "implements", "import", "interface", "new", "package", "private", "protected", "public", "return", "static", "this", "void"},
    "ruby": {"begin", "class", "def", "do", "else", "elsif", "end", "false", "if", "module", "nil", "return", "self", "true", "unless", "while", "yield"},
}


SYMBOL_NODE_KINDS = {
    "function_definition": "function",
    "class_definition": "class",
    "decorated_definition": "decorator",
    "function_declaration": "function",
    "method_definition": "method",
    "class_declaration": "class",
    "struct_item": "struct",
    "enum_item": "enum",
    "trait_item": "trait",
    "impl_item": "impl",
}


class FerriteLanguageService:
    async def completions(
        self,
        code: str,
        position: TextPosition,
        path: str = "",
        language: str = "text",
        force: bool = False,
    ) -> list[dict[str, str]]:
        return await asyncio.to_thread(self._complete_sync, code, position, path, language, force)

    async def diagnostics(
        self,
        path: str,
        language: str = "text",
        code: str = "",
    ) -> list[dict[str, Any]]:
        if language == "python":
            if code:
                return []
            return await self._ruff_diagnostics(path)
        return []

    async def hover(
        self,
        code: str,
        position: TextPosition,
        path: str = "",
        language: str = "text",
    ) -> dict[str, Any] | None:
        context = _token_context_at(code, position.offset, language)
        if context in {"string", "comment"}:
            return None
        word = _word_at(code, position.offset)
        if not word:
            return None
        kind = _hover_kind(code, position.offset, word, language)
        signature = _python_signature(code, word) if language == "python" else ""
        documentation = _python_docstring(code, word) if language == "python" else ""
        description = _hover_description(kind, language)
        contents = "\n\n".join(
            part for part in (signature or word, documentation or description) if part
        )
        rendered = render_hover(
            signature=signature or word,
            documentation=documentation,
            description=description,
            language=language,
        )
        return {
            "contents": contents,
            "name": word,
            "word": word,
            "kind": kind,
            "language": language,
            "signature": signature,
            "documentation": documentation,
            "description": description,
            "bodyHtml": rendered.get("body_html", ""),
            "sections": rendered.get("sections", []),
            "range": _word_range(code, position.offset),
        }

    async def document_symbols(
        self,
        code: str,
        path: str = "",
        language: str = "text",
    ) -> list[dict[str, Any]]:
        return await asyncio.to_thread(self._document_symbols_sync, code, language)

    async def format_code(self, path: str, language: str = "text") -> str:
        if language == "python":
            await _run_optional_command(["ruff", "format", path])
        try:
            from app.services.file_service import read_text

            return await read_text(path)
        except Exception:
            return ""

    def _complete_sync(
        self,
        code: str,
        position: TextPosition,
        path: str,
        language: str,
        force: bool = False,
    ) -> list[dict[str, str]]:
        prefix = _prefix_at(code, position.offset)
        if len(prefix) < 2 and not force:
            return []

        keywords = LANGUAGE_KEYWORDS.get(language, set())
        words = set(re.findall(r"\b[A-Za-z_][A-Za-z0-9_]{2,}\b", code))
        words.update(keywords)
        words.update(self._symbol_names(code, language))

        results = []
        for word in sorted(words):
            if prefix and word == prefix:
                continue
            if prefix and not word.startswith(prefix):
                continue
            item_type = "keyword" if word in keywords else self._infer_completion_type(word, code, language)
            results.append({
                "name": word,
                "text": word[len(prefix):] if prefix else word,
                "type": item_type,
                "description": f"{language} {item_type}",
                "color": completion_color(item_type),
            })
            if len(results) >= 50:
                break
        return results

    def _document_symbols_sync(self, code: str, language: str) -> list[dict[str, Any]]:
        symbols: list[dict[str, Any]] = []
        for kind, pattern in _symbol_patterns(language):
            for match in pattern.finditer(code):
                line = code[:match.start()].count("\n") + 1
                symbols.append({
                    "name": match.group("name"),
                    "kind": kind,
                    "line": line,
                    "start": match.start("name"),
                    "end": match.end("name"),
                })
        if symbols or not HAS_FERRITE:
            return sorted(symbols, key=lambda item: item["start"])[:200]

        try:
            return json.loads(ferrite.document_symbols(code, language))[:200]
        except Exception:
            return []

    def _symbol_names(self, code: str, language: str) -> set[str]:
        return {symbol["name"] for symbol in self._document_symbols_sync(code, language)}

    @staticmethod
    def _infer_completion_type(word: str, code: str, language: str) -> str:
        for kind, pattern in _symbol_patterns(language):
            if pattern.search(code) and re.search(rf"\b{re.escape(word)}\b", code):
                return kind
        return "word"

    @staticmethod
    async def _ruff_diagnostics(path: str) -> list[dict[str, Any]]:
        if not path:
            return []
        try:
            process = await asyncio.create_subprocess_exec(
                "ruff",
                "check",
                "--output-format",
                "json",
                path,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            stdout, _ = await process.communicate()
            if stdout:
                return json.loads(stdout.decode("utf-8", errors="replace"))
        except FileNotFoundError:
            return []
        except Exception as exc:
            print(f"[LanguageService] ruff diagnostics failed: {exc}")
        return []


class ExternalLSPService:
    async def completions(
        self,
        code: str,
        position: TextPosition,
        path: str = "",
        language: str = "text",
    ) -> list[dict[str, str]]:
        return []

    async def diagnostics(
        self,
        path: str,
        language: str = "text",
        code: str = "",
    ) -> list[dict[str, Any]]:
        return []

    async def hover(
        self,
        code: str,
        position: TextPosition,
        path: str = "",
        language: str = "text",
    ) -> dict[str, Any] | None:
        return None

    async def document_symbols(
        self,
        code: str,
        path: str = "",
        language: str = "text",
    ) -> list[dict[str, Any]]:
        return []

    async def format_code(self, path: str, language: str = "text") -> str:
        return ""


class BatyaLanguageGateway(ExternalLSPService):
    def __init__(self, endpoint: str = "http://127.0.0.1:9865/api/language"):
        self.endpoint = endpoint


class LanguageServiceRouter:
    def __init__(self):
        self._ferrite = FerriteLanguageService()
        self._external = ExternalLSPService()
        self._python_lsp = PythonLSPService()
        self._generic_lsp = GenericLSPProviderRuntime()
        self._batya: BatyaLanguageGateway | None = None

    def configure_lsp_providers(
        self,
        language: str,
        provider_ids: list[str],
        provider_options: list[dict[str, Any]] | None = None,
    ) -> None:
        if language == "python":
            self._python_lsp.set_active_providers(provider_ids)
            return
        selected = set(provider_ids or [])
        providers = [
            provider
            for provider in (provider_options or [])
            if not selected or str(provider.get("id") or provider.get("name") or "") in selected
        ]
        self._generic_lsp.configure(language, providers)

    async def get_completions(
        self,
        code: str,
        cursor_pos: int,
        path: str = "",
        language: str = "",
        force: bool = False,
    ) -> list[dict[str, str]]:
        language = language or detect_language(path)
        position = text_position(code, cursor_pos)
        if len(_prefix_at(code, position.offset)) < 2 and not force:
            return []
        if language == "python" and not force:
            external = await self._python_lsp.completions(code, position, path, language)
            if external:
                return external
        if language != "python" and not force:
            external = await self._generic_lsp.completions(code, position, path, language)
            if external:
                return external
        local = await self._ferrite.completions(code, position, path, language, force)
        if local:
            return local
        return await self._external.completions(code, position, path, language)

    async def get_diagnostics(
        self,
        path: str,
        language: str = "",
        code: str = "",
    ) -> list[dict[str, Any]]:
        language = language or detect_language(path)
        diagnostics = []
        if language == "python":
            diagnostics.extend(await self._python_lsp.diagnostics(path, language, code))
        elif self._generic_lsp.has_providers(language):
            diagnostics.extend(await self._generic_lsp.diagnostics(path, language, code))
        diagnostics.extend(await self._ferrite.diagnostics(path, language, code))
        diagnostics.extend(await self._external.diagnostics(path, language, code))
        return diagnostics

    async def get_hover(
        self,
        code: str,
        cursor_pos: int,
        path: str = "",
        language: str = "",
    ) -> dict[str, Any] | None:
        language = language or detect_language(path)
        position = text_position(code, cursor_pos)
        if language == "python":
            external = await self._python_lsp.hover(code, position, path, language)
            if external:
                return external
        elif self._generic_lsp.has_providers(language):
            external = await self._generic_lsp.hover(code, position, path, language)
            if external:
                return external
        return await self._ferrite.hover(code, position, path, language)

    async def get_document_symbols(
        self,
        code: str,
        path: str = "",
        language: str = "",
    ) -> list[dict[str, Any]]:
        language = language or detect_language(path)
        if language == "python":
            external = await self._python_lsp.document_symbols(code, path, language)
            if external:
                return external
        elif self._generic_lsp.has_providers(language):
            external = await self._generic_lsp.document_symbols(code, path, language)
            if external:
                return external
        return await self._ferrite.document_symbols(code, path, language)

    async def sync_document(
        self,
        path: str,
        code: str,
        language: str = "",
    ) -> None:
        language = language or detect_language(path)
        if language == "python":
            await self._python_lsp.sync_document(path, code, language)
        elif self._generic_lsp.has_providers(language):
            await self._generic_lsp.sync_document(path, code, language)

    async def close_document(self, path: str, language: str = "") -> None:
        language = language or detect_language(path)
        if language == "python":
            await self._python_lsp.close_document(path)
        elif self._generic_lsp.has_providers(language):
            await self._generic_lsp.close_document(path, language)

    async def save_document(self, path: str, code: str, language: str = "") -> None:
        language = language or detect_language(path)
        if language == "python":
            await self._python_lsp.save_document(path, code, language)
        elif self._generic_lsp.has_providers(language):
            await self._generic_lsp.save_document(path, code, language)

    async def get_code_actions(
        self,
        code: str,
        cursor_pos: int,
        path: str = "",
        language: str = "",
        diagnostics: list[dict[str, Any]] | None = None,
    ) -> list[dict[str, Any]]:
        language = language or detect_language(path)
        position = text_position(code, cursor_pos)
        if language == "python":
            return await self._python_lsp.code_actions(
                code,
                position,
                path,
                language,
                diagnostics,
            )
        if self._generic_lsp.has_providers(language):
            return await self._generic_lsp.code_actions(code, position, path, language, diagnostics)
        return []

    async def set_workspace(self, root_path: str) -> dict[str, Any]:
        status = await self._python_lsp.set_workspace(root_path)
        await self._generic_lsp.set_workspace(root_path)
        return status

    async def format_code(self, path: str, language: str = "") -> str:
        language = language or detect_language(path)
        return await self._ferrite.format_code(path, language)

    def get_status(self, language: str = "python") -> dict[str, Any]:
        if language == "python":
            return self._python_lsp.status()
        if self._generic_lsp.has_providers(language):
            return self._generic_lsp.status(language)
        return {
            "language": language,
            "servers": [],
            "available": [],
            "running": [],
            "missing": [],
            "label": f"{language} · Ferrite",
            "healthy": True,
        }

    async def start_lsp(self, language: str = "python") -> dict[str, Any]:
        if language == "python":
            return await self._python_lsp.start()
        if self._generic_lsp.has_providers(language):
            return await self._generic_lsp.start(language)
        return self.get_status(language)

    async def stop_lsp(self, language: str = "python") -> dict[str, Any]:
        if language == "python":
            return await self._python_lsp.stop()
        if self._generic_lsp.has_providers(language):
            return await self._generic_lsp.stop(language)
        return self.get_status(language)

    async def restart_lsp(self, language: str = "python") -> dict[str, Any]:
        if language == "python":
            return await self._python_lsp.restart()
        if self._generic_lsp.has_providers(language):
            return await self._generic_lsp.restart(language)
        return self.get_status(language)


def text_position(code: str, cursor_pos: int) -> TextPosition:
    offset = max(0, min(cursor_pos, len(code)))
    before = code[:offset]
    return TextPosition(
        line=before.count("\n") + 1,
        character=len(before.rsplit("\n", 1)[-1]),
        offset=offset,
    )


def completion_color(type_: str) -> str:
    return {
        "class": "#E5C07B",
        "enum": "#E5C07B",
        "function": "#61AFEF",
        "impl": "#C678DD",
        "keyword": "#C678DD",
        "method": "#61AFEF",
        "module": "#56B6C2",
        "property": "#ABB2BF",
        "struct": "#E5C07B",
        "trait": "#E5C07B",
        "word": "#ABB2BF",
    }.get(type_, "#ABB2BF")


def _prefix_at(code: str, offset: int) -> str:
    before = code[:max(0, min(offset, len(code)))]
    match = re.search(r"[A-Za-z_][A-Za-z0-9_]*$", before)
    return match.group(0) if match else ""


def _word_at(code: str, offset: int) -> str:
    start, end = _word_range(code, offset)
    return code[start:end] if end > start else ""


def _word_range(code: str, offset: int) -> tuple[int, int]:
    offset = max(0, min(offset, len(code)))
    if offset >= len(code) or not re.match(r"[A-Za-z0-9_]", code[offset]):
        return offset, offset
    start = offset
    while start > 0 and re.match(r"[A-Za-z0-9_]", code[start - 1]):
        start -= 1
    end = offset
    while end < len(code) and re.match(r"[A-Za-z0-9_]", code[end]):
        end += 1
    return start, end


def _hover_kind(code: str, offset: int, word: str, language: str) -> str:
    if word in LANGUAGE_KEYWORDS.get(language, set()):
        return "keyword"
    if language == "python":
        line_start = code.rfind("\n", 0, offset) + 1
        line_end = code.find("\n", offset)
        if line_end < 0:
            line_end = len(code)
        line = code[line_start:line_end]
        if line.lstrip().startswith("@"):
            return "decorator"
        if re.search(rf"^\s*(?:async\s+)?def\s+{re.escape(word)}\s*\(", code, re.MULTILINE):
            return "function"
        if re.search(rf"^\s*class\s+{re.escape(word)}\b", code, re.MULTILINE):
            return "class"
    for kind, pattern in _symbol_patterns(language):
        for match in pattern.finditer(code):
            if match.group("name") == word and match.start("name") <= offset <= match.end("name"):
                return kind
    return "symbol"


def _token_context_at(code: str, offset: int, language: str) -> str:
    line_start = code.rfind("\n", 0, offset) + 1
    line_end = code.find("\n", offset)
    if line_end < 0:
        line_end = len(code)
    line = code[line_start:line_end]
    column = max(0, offset - line_start)
    stripped = line.lstrip()
    if stripped.startswith("#") or stripped.startswith("//"):
        return "comment"
    in_string = False
    quote = ""
    escaped = False
    index = 0
    while index < min(column, len(line)):
        char = line[index]
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif line.startswith(quote, index):
                index += len(quote) - 1
                in_string = False
                quote = ""
        else:
            if line.startswith("'''", index) or line.startswith('"""', index):
                quote = line[index:index + 3]
                in_string = True
                index += 2
            elif char in {"'", '"', "`"}:
                quote = char
                in_string = True
        index += 1
    if in_string:
        return "string"
    if language == "python" and _inside_python_docstring(code, offset):
        return "string"
    return "code"


def _inside_python_docstring(code: str, offset: int) -> bool:
    for match in re.finditer(r"(?P<quote>'''|\"\"\")(?P<body>.*?)(?P=quote)", code, re.DOTALL):
        if match.start() <= offset <= match.end():
            prefix = code[:match.start()]
            line_start = prefix.rfind("\n") + 1
            before_quote = prefix[line_start:]
            return before_quote.strip() == ""
    return False


def _hover_description(kind: str, language: str) -> str:
    descriptions = {
        "class": "Class declaration.",
        "decorator": "Python decorator: an expression evaluated at load time to transform a function or class.",
        "function": "Function declaration.",
        "keyword": f"Reserved {language} keyword.",
        "method": "Method associated with a class or object.",
        "symbol": "Symbol detected in the current document.",
    }
    return descriptions.get(kind, f"{kind} detected in {language}.")


def _python_signature(code: str, word: str) -> str:
    pattern = re.compile(
        rf"^\s*(?P<prefix>(?:async\s+)?def|class)\s+{re.escape(word)}\s*(?P<tail>\([^)\n]*\))?",
        re.MULTILINE,
    )
    match = pattern.search(code)
    if not match:
        return ""
    prefix = match.group("prefix")
    tail = match.group("tail") or ""
    return f"{prefix} {word}{tail}"


def _python_docstring(code: str, word: str) -> str:
    pattern = re.compile(
        rf"^\s*(?:async\s+)?(?:def|class)\s+{re.escape(word)}\s*(?:\([^)\n]*\))?\s*:\s*\n"
        r"(?P<body>(?:[ \t]+.*\n?)*)",
        re.MULTILINE,
    )
    match = pattern.search(code)
    if not match:
        return ""
    body = match.group("body")
    doc_match = re.search(
        r"^[ \t]*(?:[rubfRUBF]{0,3})?(?P<quote>'''|\"\"\")(?P<doc>.*?)(?P=quote)",
        body,
        re.DOTALL | re.MULTILINE,
    )
    if not doc_match:
        return ""
    return re.sub(r"\s+", " ", doc_match.group("doc").strip())


def _symbol_patterns(language: str) -> list[tuple[str, re.Pattern]]:
    common_identifier = r"(?P<name>[A-Za-z_][A-Za-z0-9_]*)"
    patterns = {
        "python": [
            ("class", re.compile(rf"^\s*class\s+{common_identifier}", re.MULTILINE)),
            ("function", re.compile(rf"^\s*(?:async\s+)?def\s+{common_identifier}", re.MULTILINE)),
        ],
        "javascript": [
            ("class", re.compile(rf"\bclass\s+{common_identifier}")),
            ("function", re.compile(rf"\bfunction\s+{common_identifier}")),
            ("function", re.compile(rf"\b(?:const|let|var)\s+{common_identifier}\s*=\s*(?:async\s*)?\(")),
        ],
        "typescript": [
            ("class", re.compile(rf"\bclass\s+{common_identifier}")),
            ("function", re.compile(rf"\bfunction\s+{common_identifier}")),
            ("class", re.compile(rf"\binterface\s+{common_identifier}")),
            ("class", re.compile(rf"\btype\s+{common_identifier}\s*=")),
        ],
        "rust": [
            ("function", re.compile(rf"\bfn\s+{common_identifier}")),
            ("struct", re.compile(rf"\bstruct\s+{common_identifier}")),
            ("enum", re.compile(rf"\benum\s+{common_identifier}")),
            ("trait", re.compile(rf"\btrait\s+{common_identifier}")),
            ("impl", re.compile(rf"\bimpl\s+{common_identifier}")),
        ],
        "go": [("function", re.compile(rf"\bfunc\s+{common_identifier}"))],
        "java": [
            ("class", re.compile(rf"\bclass\s+{common_identifier}")),
            ("function", re.compile(rf"\b(?:public|private|protected)?\s*(?:static\s+)?[A-Za-z_][A-Za-z0-9_<>,\\[\\]]*\s+{common_identifier}\s*\(")),
        ],
        "ruby": [
            ("class", re.compile(rf"^\s*class\s+{common_identifier}", re.MULTILINE)),
            ("function", re.compile(rf"^\s*def\s+{common_identifier}", re.MULTILINE)),
        ],
    }
    return patterns.get(language, [])


async def _run_optional_command(command: list[str]) -> None:
    try:
        process = await asyncio.create_subprocess_exec(
            *command,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        await process.communicate()
    except FileNotFoundError:
        return
