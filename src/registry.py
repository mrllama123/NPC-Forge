import os
import sys
from pathlib import Path
import traceback

from constants import FORGE_DIR

NPC_REGISTRY = {}


def load_npc(npc_name):
    """Ensures that each NPC Engine is instantiated and baked ONCE on startup."""
    npc_path = FORGE_DIR / "npcs" / npc_name
    if not os.path.exists(npc_path):
        return None

    # If the NPC instance does not exist in memory cache, initialize it now
    if npc_name not in NPC_REGISTRY:
        old_cwd = os.getcwd()
        try:
            os.chdir(str(FORGE_DIR))

            if str(FORGE_DIR) not in sys.path:
                sys.path.insert(0, str(FORGE_DIR))

            from FlintNPC import FlintNPC

            NPC_REGISTRY[npc_name] = FlintNPC(npc_name)
            os.chdir(old_cwd)

        except Exception as init_error:
            if "old_cwd" in locals():
                os.chdir(old_cwd)
            sys.stderr.write(
                f"NPC-Forge registry failed to initialize NPC '{npc_name}': {str(init_error)}"
            )
            traceback.print_exc()
            return None

    return NPC_REGISTRY[npc_name]
