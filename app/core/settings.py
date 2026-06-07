from __future__ import annotations

import os
import json
from pathlib import Path
from platformdirs import user_data_dir, user_config_dir

APP_NAME = "Ember"
APP_DATA_DIR = user_data_dir(APP_NAME, "AllDotPy")
APP_CONFIG_DIR = user_config_dir(APP_NAME, "AllDotPy")

PATHS = {
    "BASE": APP_DATA_DIR,
    "PLUGINS": os.path.join(APP_DATA_DIR, "plugins"),
    "LOGS": os.path.join(APP_DATA_DIR, "logs"),
    "CONFIG": APP_CONFIG_DIR,
    "CONFIG_FILE": os.path.join(APP_CONFIG_DIR, "config.json"),
    "THEME_CONFIG": os.path.join(APP_CONFIG_DIR, "theme.json"),
    "DB_PATH": os.path.join(APP_DATA_DIR, "ember.db"),
    "PROJECTS": os.path.join(Path.home(), "EmberProjects"),
    "AI_CONFIG": os.path.join(APP_CONFIG_DIR, "ai.json"),
    # Backward compatibility — old code references these keys
    "BASE_PATH": APP_DATA_DIR,
    "PLUGINS_PATH": os.path.join(APP_DATA_DIR, "plugins"),
    "LOGS_PATH": os.path.join(APP_DATA_DIR, "logs"),
    "CONFIG_PATH": APP_CONFIG_DIR,
    "STUDIO_PROJECTS_PATH": os.path.join(Path.home(), "EmberProjects"),
}

for p in PATHS.values():
    if not p.endswith((".json", ".db")) and not os.path.exists(p):
        os.makedirs(p, exist_ok=True)

if not os.path.exists(PATHS["PROJECTS"]):
    os.makedirs(PATHS["PROJECTS"], exist_ok=True)

DATABASE_URL = os.environ.get(
    "EMBER_DATABASE_URL",
    f"sqlite://{PATHS['DB_PATH']}?mode=rwc",
)

DEFAULT_THEME = {
    "name": "Ember Dark",
    "type": "dark",
    "colors": {
        "editor.background": "#1E1E1E",
        "editor.foreground": "#D4D4D4",
        "editor.lineHighlight": "#2A2A2A",
        "editor.selection": "#264F78",
        "editor.cursor": "#AEAFAD",
        "editor.lineNumbers": "#858585",
        "editor.activeLineNumber": "#C6C6C6",
        "sidebar.background": "#252526",
        "sidebar.foreground": "#CCCCCC",
        "sidebar.selection": "#37373D",
        "tab.activeBackground": "#1E1E1E",
        "tab.activeForeground": "#FFFFFF",
        "tab.inactiveBackground": "#2D2D2D",
        "tab.inactiveForeground": "#969696",
        "titleBar.background": "#323233",
        "titleBar.foreground": "#CCCCCC",
        "statusBar.background": "#007ACC",
        "statusBar.foreground": "#FFFFFF",
        "panel.background": "#1E1E1E",
        "panel.border": "#3E3E42",
        "terminal.background": "#1E1E1E",
        "terminal.foreground": "#D4D4D4",
        "terminal.ansiBlack": "#000000",
        "terminal.ansiRed": "#CD3131",
        "terminal.ansiGreen": "#0DBC79",
        "terminal.ansiYellow": "#E5E510",
        "terminal.ansiBlue": "#2472C8",
        "terminal.ansiMagenta": "#BC3FBC",
        "terminal.ansiCyan": "#11A8CD",
        "terminal.ansiWhite": "#E5E5E5",
        "button.primary": "#007ACC",
        "button.hover": "#1C97EA",
        "scrollbar.background": "#1E1E1E",
        "scrollbar.thumb": "#424242",
        "scrollbar.hover": "#4F4F4F",
    },
}

THEME_KEYS = list(DEFAULT_THEME["colors"].keys())

TEMPLATES = {
    "Empty": "",
    "Backdrop": """
ScreenManager:
    id:screen_manager
    Screen:
        MDBackdrop:
            title: "Backdrop Activity"
            header_text: "Menu:"
            MDBackdropBackLayer:
                MDBoxLayout:
                    orientation:'vertical'
                    md_bg_color:hex('#f3f4f6')
            MDBackdropFrontLayer:
                MDBoxLayout:
                    orientation:'vertical'
                    md_bg_color:hex('#2e2b2b')
""",
    "Tabs": """
<Tab@MDFloatLayout+MDTabsBase>:
    text:''
    MDLabel:
        text: "Tab Content"
        halign: "center"

ScreenManager:
    id:screen_manager
    Screen:
        MDBoxLayout:
            orientation: "vertical"
            MDToolbar:
                title: "Bottom-Nav"
            MDBottomNavigation:
                Tab:
                    text: "TabOne"
                Tab:
                    text: "TabTwo"
""",
    "NavigationDrawer": """
ScreenManager:
    id:screen_manager
    Screen:
        MDBoxLayout:
            orientation: "vertical"
            MDToolbar:
                title: "Nav-Drawer"
                left_action_items: [["menu", lambda x: nav_drawer.set_state()]]
        MDNavigationDrawer:
            id:nav_drawer
""",
    "BottomNavigation": """
ScreenManager:
    id:scree_manager
    Screen:
        MDBoxLayout:
            orientation: "vertical"
            MDToolbar:
                title: "Bottom-Navigation"
            MDBottomNavigation:
                MDBottomNavigationItem:
                    name: "one"
                    text: "One"
                    icon: "numeric-1"
                MDBottomNavigationItem:
                    name: "two"
                    text: "Two"
                    icon: "numeric-2"
""",
}

PYTHON_KEYWORDS = [
    "def", "class", "in", "is", "self", "not", "and", "or", "True", "False", "None",
    "nonlocal", "del", "global", "globals", "locals", "import", "as", "try", "except",
    "for", "while", "if", "elif", "else", "return", "raise", "break", "pass", "continue",
    "with", "from", "assert", "finally", "yield", "lambda", "async", "await",
    "__init__", "__str__", "__repr__", "__dict__", "__hash__", "__class__",
    "__dir__", "__doc__", "__eq__", "__format__", "__module__", "__new__",
    "__reduce__", "__sizeof__", "__setattr__", "__slots__",
]

PYTHON_BUILTINS = [
    "print", "input", "abs", "bin", "callable", "delattr", "all", "any", "ascii",
    "chr", "dir", "classmethod", "compile", "divmod", "enumerate", "eval", "exec",
    "exit", "filter", "format", "getattr", "hasattr", "hash", "help", "hex", "id",
    "isinstance", "issubclass", "iter", "len", "map", "max", "memoryview", "min",
    "next", "object", "oct", "open", "ord", "pow", "property", "quit", "repr",
    "reversed", "round", "setattr", "slice", "sorted", "staticmethod", "sum",
    "super", "vars", "zip", "dict", "str", "int", "float", "bool", "list", "type",
    "bytearray", "bytes", "complex", "set", "tuple", "frozenset", "range",
]
