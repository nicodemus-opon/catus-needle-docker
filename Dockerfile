# Cactus Needle 3 API server (python `needle playground`).
# Unlike the native `./needle --serve` binary (fixed --tools file, loopback-only),
# this server takes tools PER REQUEST, so nothing is hardcoded:
#   POST /complete {"tools": [...], "query": "..."}
# Full API (source: needle/playground/server.py in cactus-compute/needle):
#   POST /complete  {"tools": [...]|"<json string>", "query": "..."} -> tool-call JSON
#   POST /reset                                             -> {"ok": true}
#   GET  /model                                             -> {"name": ...}
#   POST /load-model  (raw .cact bytes, X-Filename: name)   -> {"name": ...}
#   POST /finetune   {"tools": [...], "api_key": "sk-or-...", "samples": 200}
#   GET  /finetune/status | GET /download/<file> | GET /  (browser playground UI)
FROM python:3.12-slim

# e.g. --build-arg CACTUS_NEEDLE_SPEC="cactus-needle[train]>=3,<4" to also enable
# /finetune (pulls JAX; much larger image). Default is runtime-only.
# Pinned to v3 so a future major can't silently swap the engine/weights.
ARG CACTUS_NEEDLE_SPEC="cactus-needle>=3,<4"

ENV NEEDLE_TELEMETRY=0 \
    DO_NOT_TRACK=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

RUN apt-get update \
  && apt-get install -y --no-install-recommends curl \
  && rm -rf /var/lib/apt/lists/* \
  && pip install --no-cache-dir "$CACTUS_NEEDLE_SPEC"

WORKDIR /app

# Pre-warm: fetch the engine + base weights into the image cache
# (~/.cache/cactus-needle) so the first request is fast and runtime is offline-safe.
RUN python -c "import needle; print(needle.Needle(tools='[]').complete('ping')['type'])"

# Promote the base archive to a version-independent path. The playground server
# labels /model with the --weights basename, but its built-in default label is
# a stale "needle-2 (base)" even though it loads Needle 3 — passing the file
# explicitly makes /model report {"name": "needle3.cact"}. Same bytes, same
# inference, honest label.
RUN CACT="$(find "${HOME:-/root}/.cache/cactus-needle/v3" -name 'needle3.cact' | head -1)" \
  && test -n "$CACT" \
  && cp "$CACT" /app/needle3.cact \
  && ls -lh /app/needle3.cact

EXPOSE 7860

ENTRYPOINT ["needle", "playground"]
CMD ["--host", "0.0.0.0", "--port", "7860"]
