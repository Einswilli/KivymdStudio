"""Frido Plugin — Example plugin backend."""

__all__ = ["hello", "deactivate", "CONFIG"]

# Legacy CONFIG for backward compat
CONFIG = {
    "name": "Einswilli",
    "author": "frido",
    "type": "",
    "description": "plugin de frido",
    "version": "1.1",
    "icon": "fridoPlugin/Dot.png",
    "template": "frido.qml",
    "backend": "fri.py",
    "display_view": "leftbar",
}


def hello(api=None):
    """Called on plugin activation. Receives PluginAPI instance."""
    print("[frido] Activated!")
    if api:
        api.events.on("editor:save", _on_save)
    return True


def deactivate():
    """Called on plugin deactivation."""
    print("[frido] Deactivated.")


async def _on_save(path: str, content: str):
    print(f"[frido] File saved: {path}")
