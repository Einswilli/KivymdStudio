"""
Ember — A modern, extensible, AI-powered code editor.
Entry point for the Qt/QML application.
"""

from __future__ import annotations

import sys
import os
import asyncio
from pathlib import Path

os.environ["QT_QUICK_CONTROLS_STYLE"] = "Fusion"

from PySide6.QtWidgets import QApplication
from PySide6.QtQml import QQmlApplicationEngine, qmlRegisterType
from qasync import QEventLoop

from app.core.di import ServiceProvider
from app.data.models import init_database
from app.editor.document import EditorDocument
from app.plugins.manager import PluginManager
from app.api.server import EmbeddedServer


def _ensure_dirs():
    from app.core.settings import PATHS

    for p in PATHS.values():
        if not p.endswith((".json", ".db", ".conf")) and not os.path.exists(p):
            os.makedirs(p, exist_ok=True)
    proj = PATHS["PROJECTS"]
    if not os.path.exists(proj):
        os.makedirs(proj, exist_ok=True)


async def _startup():
    print("[Ember] Starting up...")
    _ensure_dirs()
    try:
        await init_database()
        print("[Ember] Database initialized.")
    except Exception as e:
        print(f"[Ember] Database init skipped: {e}")


def main():
    app = QApplication(sys.argv)
    app.setApplicationName("Ember")
    app.setApplicationVersion("2.0.0")

    qmlRegisterType(EditorDocument, "Ember.Editor", 1, 0, "EditorDocument")

    loop = QEventLoop(app)
    asyncio.set_event_loop(loop)
    loop.run_until_complete(_startup())

    provider = ServiceProvider()

    # ── Plugin System v2 ──────────────────────────────────
    plugin_manager = PluginManager(provider.command_vm)
    plugin_manager.create_api(
        editor_vm=provider.editor_vm,
        file_vm=provider.file_vm,
        project_vm=provider.project_vm,
        terminal_vm=provider.terminal_vm,
        event_bus=provider.events,
        notification_vm=provider.notification_vm,
        action_service=provider.action_service,
    )
    provider.plugin_vm.set_manager(plugin_manager)
    provider.panel_vm.set_manager(plugin_manager)
    provider.search_vm.set_plugin_manager(plugin_manager)
    plugin_manager.set_settings_service(provider.settings_vm.settings_service)
    plugin_manager.set_notification_vm(provider.notification_vm)
    plugin_manager.set_action_service(provider.action_service)

    # ── Discover & activate plugins ────────────────────────
    loop.run_until_complete(plugin_manager.discover_all())
    loop.run_until_complete(plugin_manager.activate_all())
    provider.plugin_vm.refresh_from_manager()
    provider.panel_vm.refresh()
    provider.search_vm.applySettings(provider.settings_vm.getSearchConfig())
    providers = provider.settings_vm.getAppearanceProviders()
    font_provider = providers.get("fonts", "core")
    loaded_fonts = plugin_manager.load_fonts_for(font_provider)
    if loaded_fonts:
        print(f"[Ember] Loaded font provider '{font_provider}': {', '.join(loaded_fonts)}")

    # ── Marketplace API (Batya + Falcorn) ──────────────────
    # NOTE: Falcorn worker spawn tries to resolve 'app_module' as a file path.
    # Disabled until Falcorn config is corrected to use inline ASGI app.
    # marketplace = EmbeddedServer(host="127.0.0.1", port=9865)
    # loop.run_until_complete(marketplace.start())
    print("[Ember] Marketplace server disabled (Falcorn config pending).")

    engine = QQmlApplicationEngine()

    qml_path = os.fspath(Path(__file__).resolve().parent / "qml" / "main.qml")

    engine.addImportPath(os.path.join(os.path.dirname(qml_path), "settings"))

    ctx = engine.rootContext()

    ctx.setContextProperty("EditorVM", provider.editor_vm)
    ctx.setContextProperty("FileVM", provider.file_vm)
    ctx.setContextProperty("ProjectVM", provider.project_vm)
    ctx.setContextProperty("TerminalVM", provider.terminal_vm)
    ctx.setContextProperty("PluginVM", provider.plugin_vm)
    ctx.setContextProperty("StatusVM", provider.status_vm)
    ctx.setContextProperty("NotificationVM", provider.notification_vm)
    ctx.setContextProperty("SettingsVM", provider.settings_vm)
    ctx.setContextProperty("UiVM", provider.ui_vm)
    ctx.setContextProperty("ChatVM", provider.chat_vm)
    ctx.setContextProperty("CommandVM", provider.command_vm)
    ctx.setContextProperty("ActionVM", provider.action_vm)
    ctx.setContextProperty("PanelVM", provider.panel_vm)
    ctx.setContextProperty("SearchVM", provider.search_vm)

    # Add components dir to import path
    engine.addImportPath(os.path.join(os.path.dirname(qml_path), "components"))
    engine.addImportPath(os.path.join(os.path.dirname(qml_path), "editor"))
    engine.addImportPath(os.path.join(os.path.dirname(qml_path), "settings"))

    # Use the new clean main.qml
    main_qml = os.path.join(os.path.dirname(qml_path), "main.qml")
    if os.path.exists(main_qml):
        qml_path = main_qml
        print("[Ember] Loading main.qml")

    engine.load(qml_path)

    if not engine.rootObjects():
        sys.exit(-1)

    with loop:
        loop.run_forever()


if __name__ == "__main__":
    main()
