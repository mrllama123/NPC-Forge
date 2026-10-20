import os
from pathlib import Path

# Force mapping onto the deployment directory (XDG Standard)
FORGE_DIR_ENV = os.getenv("FORGE_DIR")
FORGE_DIR = (
    Path(FORGE_DIR_ENV)
    if isinstance(FORGE_DIR_ENV, str)
    else Path.home() / ".local" / "share" / "npc-forge"
)


FORGE_LOG_FILE = os.getenv("FORGE_LOG_FILE", "1")

