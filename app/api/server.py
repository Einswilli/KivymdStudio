"""
Embedded API server — Batya + Falcorn on localhost:9865.

Provides the plugin marketplace API.
Gracefully degrades if Batya/Falcorn are not installed.
"""

from __future__ import annotations

import asyncio


class EmbeddedServer:
    def __init__(self, host: str = "127.0.0.1", port: int = 9865):
        self._host = host
        self._port = port
        self._app = None
        self._server = None
        self._running = False

    @property
    def is_running(self) -> bool:
        return self._running

    async def start(self) -> None:
        if self._running:
            return
        try:
            from app.api.marketplace import build_asgi_app
            self._app = build_asgi_app()

            if self._app is None:
                print("[Ember API] Batya not available — marketplace disabled.")
                return

            import falcorn
            from falcorn import FalcornServer, ServerConfig, WorkerClass, ProtocolType

            config = ServerConfig(
                app_module="ember_api",
                app_callable="app",
                host=self._host,
                port=self._port,
                workers=1,
                worker_class=WorkerClass.Async,
                protocol=ProtocolType.Asgi,
                worker_mode=False,
            )
            self._server = FalcornServer.from_config(config)
            self._server.start()
            self._running = True
            print(f"[Ember API] Marketplace running on http://{self._host}:{self._port}")
        except ImportError as e:
            print(f"[Ember API] Dependency missing ({e}) — marketplace disabled.")
            self._running = False
        except Exception as e:
            print(f"[Ember API] Failed to start: {e}")
            self._running = False

    async def stop(self) -> None:
        if self._running and self._server:
            try:
                self._server.stop()
            except Exception:
                pass
            self._running = False
            print("[Ember API] Marketplace stopped.")
