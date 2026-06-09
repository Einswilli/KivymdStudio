"""Gracia Plugin — Example plugin backend."""

__all__ = ["activate", "deactivate", "hellogra", "CONFIG"]

# Legacy CONFIG for backward compat
CONFIG = {
    "name": "Gracia",
    "author": "gracia",
    "type": "",
    "description": "plugin de gracia",
    "version": "1.0",
    "icon": "graciaPlugin/Dot.png",
    "template": "gracia.qml",
    "backend": "gra.py",
    "display_view": "leftbar",
}


def activate(api=None):
    """Called on plugin activation."""
    print("[gracia] Activated!")
    if api:
        api.events.on("editor:save", _on_save)
    hellogra()


def deactivate():
    """Called on plugin deactivation."""
    print("[gracia] Deactivated.")


def hellogra():
    print("[gracia] yes gracia plugin works!")


async def _on_save(path: str, content: str):
    print(f"[gracia] File saved: {path}")
