# cactus-docker

Dockerized [Cactus Needle 3](https://cactuscompute.com/needle) API server.
Needle 3 is a tiny (8–29 MB) on-device foundation model for tool calling and
structured extraction. This project wraps the official `needle playground`
server so **tools are configured per API request — nothing is hardcoded**:

```bash
curl -X POST http://localhost:7860/complete \
  -H 'Content-Type: application/json' \
  -d '{"tools": [{"name": "get_weather", "description": "Weather in a city", "parameters": {"type": "object", "properties": {"city": {"type": "string"}}, "required": ["city"]}}], "query": "weather in Lagos?"}'
```

Model + engines: [Cactus-Compute/needle3](https://huggingface.co/Cactus-Compute/needle3) ·
Server source: [cactus-compute/needle](https://github.com/cactus-compute/needle) ·
Python docs: [needle-python-docs](https://cactuscompute.com/blog/needle-python-docs)

## Quickstart

Requirements: Docker with the Compose plugin.

```bash
docker compose up --build -d
curl -X POST http://localhost:7860/complete \
  -H 'Content-Type: application/json' \
  --data @tools.example.json
```

A sample request body lives in [`tools.example.json`](tools.example.json).
First startup downloads the engine + weights (cached in the image); later
starts are instant.

## Deploy with Coolify

This repo is Coolify-ready: `docker-compose.yml` follows the Coolify rules —
no `container_name`, no `ports`, no custom networks (Coolify creates an
isolated network per stack and routes via its proxy), and the server already
listens on `0.0.0.0`.

1. Coolify → **+ New Resource → Docker Compose**, point it at this repo.
   Compose file path: `docker-compose.yml` (repo root).
2. Under the `needle3` service add a **Domain** with the port suffix **`:7860`**,
   e.g. `https://needle.example.com:7860` → Coolify routes it to the
   container's internal port 7860. (Plain `https://needle.example.com` only
   works for port 80.)
3. Deploy. Health is Compose-owned (`healthcheck` in `docker-compose.yml`),
   so Coolify picks it up automatically.

Notes:

- In-stack, other services reach it at `http://needle3:7860` (service name as
  hostname on the Coolify-managed network).
- `docker-compose.override.yml` (host port publishing) is local-dev only and
  does not affect the Coolify deployment.

## API

Base URL: `http://localhost:7860`. The browser playground UI is at `/`.

| Endpoint | Description |
|---|---|
| `POST /complete` | `{"tools": [...]` or JSON string, `"query": "..."}` → tool-call JSON (`function_calls`, `reasoning`, `confidence`, …) |
| `POST /reset` | Clear server-side state → `{"ok": true}` |
| `GET /model` | Active weights → `{"name": ...}` |
| `POST /load-model` | Upload a `.cact` (raw bytes + `X-Filename` header) to swap weights at runtime |
| `POST /finetune` | `{"tools": [...], "api_key": "sk-or-…", "samples": 200}` — needs the `[train]` image variant (below) |
| `GET /finetune/status` | Background fine-tune progress |
| `GET /download/<file>` | Download a fine-tuned `.cact` produced via `/finetune` |

Notes:

- Requests are stateless: the server re-binds when your `tools` change, so each
  caller can use a completely different tool surface with no restart.
- `tools` accepts raw JSON-schema dicts, OpenAI-style
  `{"type": "function", "function": {...}}` wrappers, or a JSON-encoded string.
- With 6+ tools, Needle's retrieval head admits only the top-5 per turn.
- Off-topic input returns empty `function_calls` (a refusal, not free text) —
  always handle the empty case. Optional arguments may be omitted when the
  query gives no evidence for them.

## Configuration

Serve a fine-tuned archive instead of the base model:

1. Build/export `tuned.cact` ([fine-tuning guide](https://cactuscompute.com/blog/finetuning-needle))
2. Place it next to `docker-compose.yml` and uncomment the `volumes:` /
   `command:` lines there.

Enable `POST /finetune` (pulls JAX, larger image):

```yaml
build:
  args:
    CACTUS_NEEDLE_SPEC: "cactus-needle[train]"
```

| Knob | Where | Default |
|---|---|---|
| Published port | `docker-compose.yml` → `ports` | `7860` |
| Package spec | `Dockerfile` → `CACTUS_NEEDLE_SPEC` | `cactus-needle` |
| Telemetry off | `NEEDLE_TELEMETRY=0`, `DO_NOT_TRACK=1` | set in both files |

## Project layout

```text
docker-compose.yml   service, port, healthcheck, tuned-weights example
Dockerfile           python:3.12-slim + cactus-needle, pre-warmed weights cache
tools.example.json   sample POST body for /complete (not mounted, docs only)
LICENSE              MIT
```

## Contributing

Issues and PRs welcome. Please include the request/response JSON (with
`reasoning` and `confidence`) when reporting bad tool calls.

## License

MIT — see [LICENSE](LICENSE). Needle 3 weights/engine are Apache-2.0 via
[Cactus Compute](https://github.com/cactus-compute/needle).
