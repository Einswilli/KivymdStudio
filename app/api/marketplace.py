"""
Marketplace REST API — Built on Batya (ViewSet + Router).

Serves the plugin marketplace on localhost:9865.
Uses Ryx for data via the PluginInfo model.

NOTE: Requires batya to be installed. Falls back gracefully if not available.
"""

from __future__ import annotations

try:
    from batya.routing import Router
    from batya.response import Response
    HAS_BATYA = True
except ImportError:
    HAS_BATYA = False


def _ok(data):
    return {"status": 200, "body": data}


def _not_found(data):
    return {"status": 404, "body": data}


marketplace_router = None


def get_marketplace_router():
    global marketplace_router
    if not HAS_BATYA:
        return None

    if marketplace_router is None:
        marketplace_router = Router(prefix="/api/marketplace")
        _register_routes(marketplace_router)
        marketplace_router.compile()
    return marketplace_router


def _register_routes(router):
    @router.get("/plugins")
    async def list_plugins(request):
        from app.data.models import PluginInfo
        try:
            plugins = await PluginInfo.objects.filter(enabled=True).all()
            data = [
                {
                    "name": p.name, "version": p.version, "author": p.author,
                    "description": p.description, "manifest": p.manifest,
                    "installed_at": p.installed_at.isoformat() if p.installed_at else None,
                }
                for p in plugins
            ]
            return Response.ok({"count": len(data), "results": data})
        except Exception as e:
            return Response.ok({"count": 0, "results": [], "error": str(e)})

    @router.get("/plugins/{name}")
    async def get_plugin(request, name: str):
        from app.data.models import PluginInfo
        try:
            p = await PluginInfo.objects.get(name=name)
            return Response.ok({
                "name": p.name, "version": p.version, "author": p.author,
                "description": p.description, "manifest": p.manifest,
            })
        except Exception:
            return Response.not_found({"detail": f"Plugin '{name}' not found"})

    @router.get("/search")
    async def search_plugins(request):
        from app.data.models import PluginInfo
        search = request.query_params.get("q", "")
        try:
            all_plugins = await PluginInfo.objects.filter(enabled=True).all()
            if search:
                all_plugins = [
                    p for p in all_plugins
                    if search.lower() in p.name.lower()
                    or (p.description and search.lower() in p.description.lower())
                ]
            data = [
                {"name": p.name, "version": p.version, "author": p.author,
                 "description": p.description}
                for p in all_plugins
            ]
            return Response.ok({"count": len(data), "results": data})
        except Exception as e:
            return Response.ok({"count": 0, "results": [], "error": str(e)})

    @router.get("/health")
    async def health(request):
        return Response.ok({"status": "ok", "service": "ember-marketplace"})


# Standalone ASGI app for Falcorn
def build_asgi_app():
    if not HAS_BATYA:
        return None
    from batya import Batya
    from batya.conf import Settings

    class EmberAPISettings(Settings):
        APP_NAME = "Ember API"
        APP_VERSION = "2.0.0"
        DEBUG = False
        INSTALLED_APPS: list = []
        MIDDLEWARE: list = []
        ALLOWED_HOSTS = ["localhost", "127.0.0.1"]

    router = get_marketplace_router()
    if router is None:
        return None
    return Batya(settings=EmberAPISettings, router=router)
