# TaskManager — Kessel Onboarding Demo Service

A simple Go HTTP service used to demonstrate the Kessel onboarding skills. TaskManager manages tasks in workspaces and reports them to Kessel Inventory.

This service is intentionally **not pre-onboarded** — the onboarding skills run against it live during the demo.

---

## Architecture

```
curl / HTTP client
      │  HTTP (REST)
      ▼
TaskManager (this service)
      │  gRPC
      ▼
Kessel Inventory API
```

The service exposes a REST API for ease of interaction. Internally, all calls to Kessel Inventory are made over gRPC using the Kessel SDK — because that's the only transport Kessel Inventory supports.

---

## Prerequisites

- Go 1.23+
- Docker or Podman
- `yq` — required by the Kessel startup script (`brew install yq` / `dnf install yq`)
- A local clone of [inventory-api](https://github.com/project-kessel/inventory-api)
- A local clone of [rbac-config](https://github.com/project-kessel/rbac-config)

### Running Kessel locally with `make kessel-up`

`make kessel-up` in inventory-api starts the full Kessel stack (Inventory API, Relations API, SpiceDB, RBAC, Kafka) via Docker Compose. The Inventory API gRPC endpoint is exposed on **`:9081`** — this is what TaskManager connects to.

> **Port note:** `:9000` is the Relations API gRPC port (internal coordination), not Inventory API. TaskManager must use `:9081`.

Before running `kessel-up`, the taskmanager schemas need to be loaded into both Inventory API (resource schema) and SpiceDB (permissions schema). Do this after running the schema-design skill:

```bash
# 1. Load the resource schema into inventory-api and regenerate the cache
cp -r artifacts/schemas/task-manager/inventory-api/task \
      /path/to/inventory-api/data/schema/resources/
cd /path/to/inventory-api
go run main.go preload-schema        # regenerates schema_cache.json (mounted by compose)

# 2. Add the KSL to rbac-config and compile to schema.zed
cp artifacts/schemas/task-manager/rbac-config/schemas/src/taskmanager.ksl \
   /path/to/rbac-config/configs/stage/schemas/src/
echo "taskmanager" >> /path/to/rbac-config/configs/stage/schemas/migrated_apps.lst
cd /path/to/rbac-config && make ksl-test-schema-stage
# Compiled schema written to: _private/test-schema/stage-schema.zed

# 3. Start the full Kessel stack with the compiled schema
cd /path/to/inventory-api
SCHEMA_ZED_FILE=/path/to/rbac-config/_private/test-schema/stage-schema.zed make kessel-up
```

Wait for all services to be healthy (the script will show progress). Then start TaskManager.

---

## Running TaskManager

```bash
cd demo/taskmanager

# Run without Kessel (tasks managed locally, Kessel calls logged as errors)
go run .

# Run with Kessel (after make kessel-up)
KESSEL_ENDPOINT=localhost:9081 go run .

# With all options
KESSEL_ENDPOINT=localhost:9081 \
REPORTER_INSTANCE_ID=taskmanager-demo \
BASE_URL=http://localhost:8080 \
ADDR=:8080 \
go run .
```

The service starts on `:8080`. Kessel calls fail gracefully with a log message if the endpoint is unavailable — the service still works for managing tasks locally.

---

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `KESSEL_ENDPOINT` | `localhost:9081` | Kessel Inventory API gRPC endpoint. Use `:9081` with `make kessel-up` (`:9000` is Relations API, not Inventory API). |
| `REPORTER_INSTANCE_ID` | `taskmanager-1` | Reporter instance ID sent to Kessel |
| `BASE_URL` | `http://localhost:8080` | Base URL for resource `api_href` links |
| `ADDR` | `:8080` | Address for the HTTP server |

---

## API

### Create a task

```bash
curl -s -X POST http://localhost:8080/tasks \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Write onboarding docs",
    "status": "open",
    "workspace_id": "workspace-abc-123",
    "assignee_id": "user-1"
  }' | jq
```

Response:
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "title": "Write onboarding docs",
  "status": "open",
  "assignee_id": "user-1",
  "workspace_id": "workspace-abc-123"
}
```

### List all tasks

```bash
curl -s http://localhost:8080/tasks | jq
```

### Get a single task

```bash
curl -s http://localhost:8080/tasks/{id} | jq
```

### Delete a task

```bash
curl -s -X DELETE http://localhost:8080/tasks/{id}
```

---

## What happens when Kessel is running

**On create (`POST /tasks`):**
1. Task is stored in memory
2. `ReportResource` gRPC call sends the task to Kessel Inventory with:
   - `type: task`
   - `reporter_type: TASKMANAGER`
   - Common fields: `workspace_id`
   - Reporter fields: `title`, `status`, `assignee_id`

**On delete (`DELETE /tasks/{id}`):**
1. Task is removed from memory
2. `DeleteResource` gRPC call removes it from Kessel Inventory

---

## Demo flow

This service is meant to be used with the Kessel onboarding skills:

```
1. Run the service (go run .)
2. /kessel-onboarding:interview  — captures TaskManager's onboarding profile
3. /kessel-onboarding:schema-design  — generates KSL and inventory-api schemas
4. Show the generated schemas alongside the ReportResource call in main.go
5. With Kessel running: create and delete tasks, watch them appear in inventory
```

See [taskmanager-overview.md](../taskmanager-overview.md) for the one-pager describing the service.
