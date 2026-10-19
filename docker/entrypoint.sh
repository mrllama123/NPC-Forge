#!/usr/bin/env bash
#
# NPC-Forge server entrypoint.
#
# Env:
#   HOST        bind host            (default 0.0.0.0)
#   PORT        bind port            (default 5000)
#   WORKERS     gunicorn workers      (default 4)
#   OLLAMA_URL  override termy's LLM  (default empty -> use baked-in config.json)
#               e.g. http://ollama:11434  for a compose-side Ollama service
#
set -euo pipefail

FORGE_DIR="${FORGE_DIR:-$HOME/.local/share/npc-forge}"
cd "$FORGE_DIR"

# ---- optional: point the probabilistic engine at a reachable Ollama ------
# termy/config.json hardcodes "api_url": "http://localhost:11434". If OLLAMA_URL
# is provided, rewrite it so the LLM fallback can reach a separate Ollama host.
if [ -n "${OLLAMA_URL:-}" ] && [ -f npcs/termy/config.json ]; then
  echo "[entrypoint] overriding termy llm.api_url -> $OLLAMA_URL"
  python - "$OLLAMA_URL" <<'PY'
import json, sys
p = "npcs/termy/config.json"
url = sys.argv[1]
with open(p) as f: cfg = json.load(f)
cfg.setdefault("llm", {})["api_url"] = url
with open(p, "w") as f: json.dump(cfg, f, indent=2)
PY
fi

# ---- optional: install NPCs at boot from a mounted path ------------------
if [ -n "${NPC_INSTALL:-}" ]; then
  echo "[entrypoint] installing NPC from $NPC_INSTALL"
  python cli.py install "$NPC_INSTALL"
fi

# ---- run the server ------------------------------------------------------
echo "[entrypoint] gunicorn server:app on ${HOST}:${PORT} (${WORKERS} workers)"
exec gunicorn server:app \
  --bind "${HOST}:${PORT}" \
  --workers "${WORKERS:-4}" \
  --access-logfile - \
  --error-logfile -
