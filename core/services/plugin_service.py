import os
import glob
import importlib
import shutil
from typing import List, Dict, Any
import simplejson as Json
import utils


class PluginService:
    """
    Handles plugin lifecycle: discovery, loading, and installation.
    """

    def __init__(self):
        self.plugins_path = utils.PATHS["PLUGINS_PATH"]

    async def discover_plugins(self) -> str:
        pluglist = glob.glob(os.path.join(self.plugins_path, "*Plugin"))
        loaded_plugins = []

        for plugin_dir in pluglist:
            # Find the actual plugin python file
            plugin_files = glob.glob(os.path.join(plugin_dir, "*Plugin.py"))
            for p in plugin_files:
                module_name = p.split("/")[-1].split(".")[0]
                if module_name == "__init__":
                    continue

                try:
                    # Convert path to module notation
                    # This is a simplification; a real system would use a proper plugin loader
                    package_path = self.plugins_path.replace("/", ".").strip(".")
                    folder_name = p.split("/")[-2]
                    full_module_path = f"{package_path}.{folder_name}.{module_name}"

                    module = importlib.import_module(full_module_path)
                    if hasattr(module, "CONFIG"):
                        config = module.CONFIG.copy()
                        # Update template path to absolute
                        config["template"] = os.path.join(
                            self.plugins_path, folder_name, config["template"]
                        )
                        loaded_plugins.append(config)

                        # Load backend if specified
                        backend_module = config["backend"].split(".")[0]
                        importlib.import_module(
                            f"{package_path}.{folder_name}.{backend_module}"
                        )
                except Exception as e:
                    print(f"Error loading plugin {p}: {e}")

        return Json.dumps(loaded_plugins, indent=4)

    async def install_plugin(self, link: str) -> str:
        origin = link[7:] if link.startswith("file://") else link
        target = os.path.join(self.plugins_path, os.path.basename(origin))
        shutil.copytree(origin, target)
        return Json.dumps({"msg": "SUCCESS:"}, indent=4)
