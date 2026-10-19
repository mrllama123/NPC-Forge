# syntax=docker/dockerfile:1
#
# NPC-Forge — HTTP server image (deterministic engine + OpenAI-compatible API
# + HTML chat UI). No systemd, no CLI, no TTS. See docs/DOCKER.md.
#
# Build:
#   docker build -t npc-forge:local .
#   docker build --build-arg NPCS=smith -t npc-forge:slim .
#
FROM python:3.12-slim

# ---- non-root user (setup.sh refuses root; mirror that) ------------------
ENV HOME=/home/forge
RUN useradd -m -u 1000 -s /bin/bash forge

# Registry dir the three path-anchored modules (registry/bundler/logger) expect:
#   $HOME/.local/share/npc-forge
ENV FORGE_DIR=$HOME/.local/share/npc-forge
ENV PYTHONPATH=$FORGE_DIR
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HOST=0.0.0.0 \
    PORT=5000 \
    WORKERS=4 \
    OLLAMA_URL=""

WORKDIR $FORGE_DIR

# ---- install dependencies first (best layer cache) ----------------------
# Only Flask + flask-cors + transitive deps are needed by the server.
# gunicorn provides the production WSGI server (skips server.py's __main__).
COPY pyproject.toml README.md ./
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir "gunicorn>=23" .

# ---- application code (must mirror setup.sh's $FORGE_DIR layout) ---------
# src/* -> registry root (top-level modules + web/ assets)
COPY src/ ./
# npcs/ -> registry root (registry loads npcs/<name> via a relative path after
# chdir). Baked-in NPCs are a build ARG; default keeps the full set.
ARG NPCS=termy,smith,example
# Build a small helper layer that selects which npc subdirs to copy.
RUN mkdir -p npcs
# NOTE: COPY can't glob per-ARG at build time cleanly, so copy the whole tree
# and prune anything not listed in NPCS at build time.
COPY npcs/ npcs/
RUN for npc in $(echo "$NPCS" | tr ',' ' '); do \
      if [ ! -d "npcs/$npc" ]; then echo "WARN: npc '$npc' not found, skipping"; fi; \
    done \
    && for npc in $(ls npcs); do \
         echo "$NPCS" | tr ',' '\n' | grep -qx "$npc" || rm -rf "npcs/$npc"; \
       done

# logs/ is created by logger.py on first import; pre-create so it's writable.
COPY docker/entrypoint.sh $FORGE_DIR/entrypoint.sh
RUN chmod +x $FORGE_DIR/entrypoint.sh && chown -R forge:forge $FORGE_DIR
USER forge

EXPOSE 5000

# Smoke-test the OpenAI-compatible models endpoint.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:5000/api/v1/models').status==200 else 1)"

ENTRYPOINT ["/home/forge/.local/share/npc-forge/entrypoint.sh"]
CMD ["gunicorn"]
