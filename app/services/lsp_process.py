from __future__ import annotations

import asyncio
import json
import os
import shutil
import subprocess
from pathlib import Path
from typing import Any
from urllib.parse import unquote, urlparse


JSON = dict[str, Any]


def path_to_uri(path: str) -> str:
    return Path(path or "untitled.py").resolve().as_uri()


def uri_to_path(uri: str) -> str:
    parsed = urlparse(uri)
    if parsed.scheme != "file":
        return uri
    return unquote(parsed.path)


def resolve_command(command: list[str]) -> list[str]:
    if not command:
        return []
    executable = command[0]
    candidates = [
        Path.cwd() / ".venv" / "bin" / executable,
        Path.cwd() / ".venv" / "Scripts" / f"{executable}.exe",
    ]
    for candidate in candidates:
        if candidate.exists():
            return [os.fspath(candidate), *command[1:]]
    found = shutil.which(executable)
    if found:
        return [found, *command[1:]]
    return []


class ExternalLSPProcess:
    def __init__(
        self,
        name: str,
        command: list[str],
        root_path: str | None = None,
        timeout: float = 1.8,
    ) -> None:
        self.name = name
        self.command = command
        self.root_path = os.path.abspath(root_path or os.getcwd())
        self.timeout = timeout
        self._process: asyncio.subprocess.Process | None = None
        self._reader_task: asyncio.Task | None = None
        self._stderr_task: asyncio.Task | None = None
        self._next_id = 0
        self._pending: dict[int, asyncio.Future] = {}
        self._diagnostics: dict[str, list[JSON]] = {}
        self._document_versions: dict[str, int] = {}
        self._logs: list[str] = []
        self._started = False
        self._start_lock = asyncio.Lock()
        self._server_capabilities: JSON = {}

    @property
    def available(self) -> bool:
        return bool(resolve_command(self.command)) and not self._command_probe_error()

    @property
    def running(self) -> bool:
        return bool(self._started and self._process and self._process.returncode is None)

    def status(self) -> JSON:
        resolved = resolve_command(self.command)
        command_error = self._command_probe_error() if resolved else ""
        return {
            "name": self.name,
            "command": " ".join(self.command),
            "available": bool(resolved) and not command_error,
            "running": self.running,
            "resolvedCommand": " ".join(resolved),
            "commandError": command_error,
            "logs": self.logs(),
        }

    async def start(self) -> bool:
        async with self._start_lock:
            if self._started:
                return True
            if self._process and self._process.returncode is None:
                return True
            command = resolve_command(self.command)
            if not command:
                self._log("missing executable")
                return False
            command_error = self._command_probe_error()
            if command_error:
                self._log(command_error)
                return False
            try:
                self._process = await asyncio.create_subprocess_exec(
                    *command,
                    stdin=asyncio.subprocess.PIPE,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE,
                    cwd=self.root_path,
                )
            except Exception as exc:
                self._log(f"start failed: {exc}")
                print(f"[LSP:{self.name}] start failed: {exc}")
                return False

            self._reader_task = asyncio.create_task(self._read_loop())
            self._stderr_task = asyncio.create_task(self._drain_stderr())
            try:
                result = await self.request("initialize", self._initialize_params())
                self._server_capabilities = result.get("capabilities", {}) if isinstance(result, dict) else {}
                await self.notify("initialized", {})
            except Exception as exc:
                self._log(f"initialize failed: {exc}")
                print(f"[LSP:{self.name}] initialize failed: {exc}")
                await self.stop()
                return False
            self._started = True
            self._log("started")
            return True

    async def stop(self) -> None:
        if not self._process:
            self._started = False
            self._log("already stopped")
            return
        try:
            await self.request("shutdown", None)
            await self.notify("exit", {})
        except Exception:
            pass
        if self._process.returncode is None:
            self._process.terminate()
            try:
                await asyncio.wait_for(self._process.wait(), timeout=0.8)
            except TimeoutError:
                self._process.kill()
        for task in (self._reader_task, self._stderr_task):
            if task:
                task.cancel()
        self._process = None
        self._started = False
        self._log("stopped")

    async def restart(self) -> bool:
        await self.stop()
        return await self.start()

    async def set_root_path(self, root_path: str) -> None:
        clean_root = os.path.abspath(os.path.expanduser(root_path or os.getcwd()))
        if clean_root == self.root_path:
            return
        await self.stop()
        self.root_path = clean_root
        self._document_versions.clear()
        self._diagnostics.clear()
        self._log(f"workspace root changed: {self.root_path}")

    def logs(self, limit: int = 30) -> list[str]:
        return self._logs[-limit:]

    def _command_probe_error(self) -> str:
        if not self.command or self.command[0] != "rust-analyzer":
            return ""
        resolved = resolve_command(self.command)
        if not resolved:
            return ""
        try:
            result = subprocess.run(
                [resolved[0], "--version"],
                capture_output=True,
                text=True,
                timeout=1.0,
                check=False,
            )
        except Exception as exc:
            return f"command probe failed: {exc}"
        if result.returncode == 0:
            return ""
        message = (result.stderr or result.stdout or "rust-analyzer is unavailable").strip()
        if "Unknown binary" in message:
            return (
                message
                + " · install it with: rustup component add rust-analyzer"
            )
        return message

    async def request(self, method: str, params: Any) -> Any:
        if not self._process or not self._process.stdin:
            raise RuntimeError(f"LSP process {self.name} is not running")
        self._next_id += 1
        request_id = self._next_id
        loop = asyncio.get_running_loop()
        future = loop.create_future()
        self._pending[request_id] = future
        self._write({"jsonrpc": "2.0", "id": request_id, "method": method, "params": params})
        try:
            return await asyncio.wait_for(future, timeout=self.timeout)
        finally:
            self._pending.pop(request_id, None)

    async def notify(self, method: str, params: Any) -> None:
        if not self._process or not self._process.stdin:
            return
        self._write({"jsonrpc": "2.0", "method": method, "params": params})

    async def open_or_update_document(self, path: str, code: str, language_id: str = "python") -> str:
        if not await self.start():
            return ""
        uri = path_to_uri(path)
        version = self._document_versions.get(uri, 0) + 1
        self._document_versions[uri] = version
        if version == 1:
            await self.notify(
                "textDocument/didOpen",
                {
                    "textDocument": {
                        "uri": uri,
                        "languageId": language_id,
                        "version": version,
                        "text": code,
                    }
                },
            )
        else:
            await self.notify(
                "textDocument/didChange",
                {
                    "textDocument": {"uri": uri, "version": version},
                    "contentChanges": [{"text": code}],
                },
            )
        return uri

    async def sync_document(self, path: str, code: str, language_id: str = "python") -> str:
        return await self.open_or_update_document(path, code, language_id)

    async def close_document(self, path: str) -> None:
        uri = path_to_uri(path)
        if uri not in self._document_versions:
            return
        if await self.start():
            await self.notify("textDocument/didClose", {"textDocument": {"uri": uri}})
        self._document_versions.pop(uri, None)
        self._diagnostics.pop(uri, None)
        self._log(f"closed document: {uri_to_path(uri)}")

    async def save_document(self, path: str, code: str = "") -> None:
        uri = await self.open_or_update_document(path, code) if code else path_to_uri(path)
        if not uri:
            return
        params: JSON = {"textDocument": {"uri": uri}}
        if code:
            params["text"] = code
        await self.notify("textDocument/didSave", params)
        self._log(f"saved document: {uri_to_path(uri)}")

    async def completion(self, path: str, code: str, line: int, character: int) -> list[JSON]:
        uri = await self.open_or_update_document(path, code)
        if not uri:
            return []
        result = await self._safe_request(
            "textDocument/completion",
            {"textDocument": {"uri": uri}, "position": {"line": line, "character": character}},
        )
        if isinstance(result, dict):
            return result.get("items") or []
        return result if isinstance(result, list) else []

    async def hover(self, path: str, code: str, line: int, character: int) -> JSON | None:
        uri = await self.open_or_update_document(path, code)
        if not uri:
            return None
        result = await self._safe_request(
            "textDocument/hover",
            {"textDocument": {"uri": uri}, "position": {"line": line, "character": character}},
        )
        return result if isinstance(result, dict) else None

    async def document_symbols(self, path: str, code: str) -> list[JSON]:
        uri = await self.open_or_update_document(path, code)
        if not uri:
            return []
        result = await self._safe_request("textDocument/documentSymbol", {"textDocument": {"uri": uri}})
        return result if isinstance(result, list) else []

    async def definition(self, path: str, code: str, line: int, character: int) -> list[JSON]:
        uri = await self.open_or_update_document(path, code)
        if not uri:
            return []
        result = await self._safe_request(
            "textDocument/definition",
            {"textDocument": {"uri": uri}, "position": {"line": line, "character": character}},
        )
        if isinstance(result, list):
            return result
        return [result] if isinstance(result, dict) else []

    async def references(self, path: str, code: str, line: int, character: int) -> list[JSON]:
        uri = await self.open_or_update_document(path, code)
        if not uri:
            return []
        result = await self._safe_request(
            "textDocument/references",
            {
                "textDocument": {"uri": uri},
                "position": {"line": line, "character": character},
                "context": {"includeDeclaration": True},
            },
        )
        return result if isinstance(result, list) else []

    async def diagnostics(self, path: str, code: str) -> list[JSON]:
        uri = await self.open_or_update_document(path, code)
        if not uri:
            return []
        result = await self._safe_request("textDocument/diagnostic", {"textDocument": {"uri": uri}})
        if isinstance(result, dict) and isinstance(result.get("items"), list):
            return result["items"]
        await asyncio.sleep(0.05)
        return self._diagnostics.get(uri, [])

    async def code_actions(
        self,
        path: str,
        code: str,
        line: int,
        character: int,
        diagnostics: list[JSON] | None = None,
    ) -> list[JSON]:
        uri = await self.open_or_update_document(path, code)
        if not uri:
            return []
        result = await self._safe_request(
            "textDocument/codeAction",
            {
                "textDocument": {"uri": uri},
                "range": {
                    "start": {"line": max(0, line), "character": max(0, character)},
                    "end": {"line": max(0, line), "character": max(0, character + 1)},
                },
                "context": {"diagnostics": diagnostics or self._diagnostics.get(uri, [])},
            },
        )
        return result if isinstance(result, list) else []

    async def _safe_request(self, method: str, params: Any) -> Any:
        try:
            return await self.request(method, params)
        except Exception:
            return None

    async def _read_loop(self) -> None:
        assert self._process and self._process.stdout
        reader = self._process.stdout
        while True:
            headers: dict[str, str] = {}
            while True:
                line = await reader.readline()
                if not line:
                    return
                decoded = line.decode("ascii", errors="replace").strip()
                if not decoded:
                    break
                key, _, value = decoded.partition(":")
                headers[key.lower()] = value.strip()

            length = int(headers.get("content-length", "0"))
            if length <= 0:
                continue
            payload = await reader.readexactly(length)
            try:
                message = json.loads(payload.decode("utf-8"))
            except json.JSONDecodeError:
                continue
            self._handle_message(message)

    async def _drain_stderr(self) -> None:
        if not self._process or not self._process.stderr:
            return
        while True:
            line = await self._process.stderr.readline()
            if not line:
                return
            text = line.decode("utf-8", errors="replace").strip()
            if text:
                self._log(text)

    def _handle_message(self, message: JSON) -> None:
        if "id" in message and ("result" in message or "error" in message):
            future = self._pending.get(message["id"])
            if future and not future.done():
                if "error" in message:
                    future.set_exception(RuntimeError(str(message["error"])))
                else:
                    future.set_result(message.get("result"))
            return
        if "id" in message and "method" in message:
            self._handle_server_request(message)
            return
        if message.get("method") == "textDocument/publishDiagnostics":
            params = message.get("params") or {}
            uri = params.get("uri")
            if uri:
                self._diagnostics[uri] = params.get("diagnostics") or []

    def _write(self, message: JSON) -> None:
        assert self._process and self._process.stdin
        payload = json.dumps(message, separators=(",", ":")).encode("utf-8")
        header = f"Content-Length: {len(payload)}\r\n\r\n".encode("ascii")
        self._process.stdin.write(header + payload)

    def _write_response(self, request_id: Any, result: Any = None) -> None:
        if not self._process or not self._process.stdin:
            return
        self._write({"jsonrpc": "2.0", "id": request_id, "result": result})

    def _handle_server_request(self, message: JSON) -> None:
        method = str(message.get("method") or "")
        request_id = message.get("id")
        params = message.get("params") or {}
        self._log(f"server request: {method}")
        if method == "workspace/configuration":
            items = params.get("items") or []
            self._write_response(request_id, [{} for _ in items])
            return
        if method in {
            "client/registerCapability",
            "client/unregisterCapability",
            "window/workDoneProgress/create",
            "workspace/applyEdit",
            "window/showDocument",
        }:
            self._write_response(request_id, None)
            return
        self._write_response(request_id, None)

    def _log(self, message: str) -> None:
        self._logs.append(message)
        if len(self._logs) > 200:
            self._logs = self._logs[-200:]

    def _initialize_params(self) -> JSON:
        root_uri = Path(self.root_path).resolve().as_uri()
        return {
            "processId": os.getpid(),
            "rootUri": root_uri,
            "workspaceFolders": [{"uri": root_uri, "name": Path(self.root_path).name}],
            "capabilities": {
                "textDocument": {
                    "completion": {"completionItem": {"snippetSupport": False}},
                    "hover": {"contentFormat": ["markdown", "plaintext"]},
                    "documentSymbol": {"hierarchicalDocumentSymbolSupport": True},
                    "publishDiagnostics": {"relatedInformation": True},
                    "diagnostic": {"dynamicRegistration": False},
                    "synchronization": {"didSave": True},
                },
                "workspace": {"configuration": True, "workspaceFolders": True},
            },
        }
