---
name: onboarding-schema-design
description: >
  Phase 2 schema design for Kessel service onboarding. Reads a ServiceProfile
  from the interview skill, conducts a short follow-up Q&A for reporter and
  permission naming details, then generates draft resource schemas (inventory-api)
  and permissions schemas (rbac-config KSL + permissions.json + roles.json).
  All output is local files — no Jira or external writes.
---

# Onboarding schema design

## When to use

- After a service's onboarding interview is complete (Phase 0/1) and before Phase 2 schema modeling begins — gives the team a head start on resource and permissions schemas.
- Only when a codebase reference (repo URL, local path, or archive) is available — this skill stops and asks for one if it's missing, since schema generation without code access produces output that needs too much manual correction to be useful.

## What this skill does

Takes a completed ServiceProfile from the interview skill and generates the two sets of schema files a service needs for Kessel integration:

1. **Resource schemas** for inventory-api — `config.yaml` + JSON Schema files per resource type
2. **Permissions schemas** for rbac-config — `.ksl` file + `permissions.json` + `roles.json`

Conducts a short follow-up Q&A to fill in details the interview defers to Phase 2 (reporter naming, v2 permission names, reporter-specific fields, cross-service dependencies).

Does **not** create PRs, Jira issues, or any external resources. All output is local files under `artifacts/schemas/{slug}/`.

## Inputs

| Input | Required | Source |
|-------|----------|--------|
| ServiceProfile JSON path | yes | Interview output or `--profile` flag |
| `codebase_ref` | **yes** | From profile `interview.codebase_ref` or `--codebase_ref` flag |
| `rbac_config_path` | no | Local path to rbac-config repo root. Used by Step 8.5 for KSL syntax check and permissions/roles structural validation. If omitted, checks `~/dev/rbac-config` and `../rbac-config`. |
| `output_dir` | no | Default `./artifacts/schemas/{slug}/` |

## Prerequisites

- ServiceProfile must have `asset_types[]`, `v1_permissions`, and `patterns[]` populated (run the interview skill first)
- `dedup.status` should not be `duplicate_found`
- **Codebase access is required.** The service's source code provides essential context for resource type modeling, reporter field definitions, and permission mapping. If `interview.codebase_ref` is null and `--codebase_ref` is not provided, **stop and ask** for a repo URL, local path, or archive before proceeding. Do not attempt to generate schemas without codebase analysis — the output would require too much manual correction to be useful.

## Configuration

Read `~/.config/kessel-onboarding/config.json` for `artifacts_dir`. If missing, direct the user to [docs/configuration.md](../../docs/configuration.md).

## Execution

### Step 0 — Load profile, validate codebase access, and load reference

Read the ServiceProfile JSON. Validate:

- `asset_types[]` is non-empty
- `v1_permissions.items` is non-empty (or explicit "unknown" flagged)
- `patterns[]` is non-empty and every `asset_types[]` entry appears in exactly one pattern's `asset_types[]`

**Codebase access gate:** Resolve `codebase_ref` from the profile's `interview.codebase_ref` field or the `--codebase_ref` flag. If neither is set, **stop and ask**: "Schema design requires access to the service's source code. Please provide a GitHub/GitLab URL, local path, or archive."

Once `codebase_ref` is available, attempt to access it. If access fails (private repo, no matching tool, unreadable path), **stop and report the error** — do not fall back to asking questions cold. The user must resolve access before continuing.

When access succeeds, perform initial codebase analysis before starting the Q&A:

| What to look for | Where to look |
|---|---|
| Domain models / resource types | Model classes, DB migrations, API resource definitions, protobuf messages |
| Reporter-specific fields | DB columns, API response schemas, serializers, marshmallow/pydantic schemas |
| Existing Kessel SDK usage | `kessel-sdk` imports, `ClientBuilder` calls, permission constants, `KesselPermission` classes |
| Existing permission definitions | rbac-config references, permission YAML/JSON, `@access` decorators |
| Service namespace / reporter name | App config, Kessel client setup, ClowdApp config |
| Cross-service dependencies | Stacked `@access` decorators, imports from other services' permission modules |

Carry all analysis results into Steps 1–3 as drafts for the confirm-or-correct pattern. **Never invent file contents** — only draft a value when the agent actually read a matching file.

Check for a schema-context snapshot at `{artifacts_dir}/profiles/{slug}-schema-context.md`. If present, this means the user deferred schema design from a prior interview session — load the snapshot for additional context (interview findings, codebase analysis notes, open questions). The snapshot supplements the profile but the profile JSON is always authoritative for field values.

Read [reference.md](reference.md) for schema format templates and naming conventions.

**Tool preflight:** Before generating any files, check which validators are available in the session environment and report their status. This determines what validation can be run in Step 8.5.

| Tool | Check command | Used for |
|---|---|---|
| `ksl` binary | `which ksl \|\| ls $GOBIN/ksl \|\| ls ~/go/bin/ksl` | KSL syntax + import check |
| `jq` | `which jq` | JSON syntax validation of all `.json` files |
| `python3` + `jsonschema` | `python3 -c "import jsonschema"` | Structural validation of permissions.json/roles.json against rbac-config schemas; draft-07 meta-validation of inventory-api JSON Schema files |

If `ksl` is not found, note: "KSL syntax check unavailable — install with `make init` in the rbac-config repo (requires Go), then re-run schema-design or manually validate with `make ksl-test-schema-stage`."

Do not block generation on missing tools — report availability and proceed. Validation happens in Step 8.5 after files are written.

### Step 1 — Classify each asset type

`patterns[]` is the sole authoritative source for classification. For each entry in `asset_types[]`, determine which schema artifacts it needs based on its matched pattern:

| Pattern | Needs inventory-api resource schema? | Needs KSL type definition? |
|---|---|---|
| `native` or `native-ws-list` | Yes (when `inventory_migration_required = true`) | Yes — `public type` with workspace relation |
| `default-workspace` | Yes (when `inventory_migration_required = true`) | No — workspace-level permissions only |
| `root-workspace` | No | No — workspace-level permissions only |
| `org-level` | No | No — workspace-level permissions only |

If the interview narrative summary notes that an asset type "maps to rbac.workspace" (from the Group 5 ownership follow-up) but its pattern is `native` or `native-ws-list`, that is a contradiction — pause and ask the EM to confirm which is correct before proceeding. Do not silently override the pattern; pattern classification and platform-type ownership must agree.

Present a classification table to the EM/tech lead for confirmation before proceeding.

Asset types matched to `root-workspace` or `org-level` do not get inventory-api resource schemas — they use the existing `rbac.workspace` type for permission checks and do not report resources to inventory.

Asset types matched to `native` or `native-ws-list` but with `inventory_migration_required = false` also skip resource schema generation — flag this as a follow-up for when the team is ready to report to inventory.

### Step 2 — Reporter Q&A (one group per asset type needing a resource schema)

For each asset type classified as needing an inventory-api resource schema in Step 1, ask one group of questions:

1. **Reporter name** — "What short name identifies your service as a reporter for `{asset_type}` resources? This becomes the reporter namespace in inventory-api (e.g. `hbi` for Host Based Inventory, `acm` for Advanced Cluster Management, `notifications` for Notifications). Must be lowercase, no hyphens."

2. **Reporter-specific fields** — "What fields does your service report for each `{asset_type}` beyond the standard metadata (local_resource_id, api_href, console_href)? For each field, provide:"
   - Field name (snake_case)
   - Type: `string`, `number`, `integer`, `boolean`, `array`, or `object`
   - Required or optional
   - Any constraints: enum values, format (`uuid`, `date-time`, `uri`), pattern (regex), maxLength
   - Whether it can be null (adds `oneOf` with null type)

3. **Common representation fields** — "Does your `{asset_type}` need any common fields beyond `workspace_id`? (Common fields are shared across all reporters for this resource type. Most services only need `workspace_id`.)"

If `codebase_ref` produced model/schema analysis during the interview, draft answers from it (same confirm-or-correct pattern — never auto-accept). Look for:

| Signal | Where to look |
|---|---|
| Reporter name | Service slug, app config, or existing Kessel SDK client setup |
| Reporter fields | Domain model classes, DB migration columns, API response schemas, protobuf message definitions |
| Common fields | Fields shared across different data sources for the same resource |

### Step 3 — Permission naming Q&A

**Step 3a — KSL namespace and file consolidation**

Ask: "What namespace should your KSL schema use? Convention is a short lowercase identifier (hyphens become underscores). Examples: `hbi`, `notifications`, `content_sources`, `compliance`."

If `codebase_ref` analysis found Kessel SDK usage with a namespace, draft the answer.

**Multi-namespace consolidation:** If `v1_permissions.items` spans more than one v1 app namespace (e.g. both `inventory:*` and `staleness:*`), ask: "Are all of these v1 app namespaces owned and operated by the same deployable service? If yes, should they be consolidated into a single KSL file under one namespace, or kept in separate files?" The answer determines whether to generate one combined KSL or one per namespace.

**Default:** If the EM confirms the same service owns all namespaces and does not specify, generate a single KSL file using the primary namespace and consolidate secondary namespace declarations at the top of that file with a comment. Do not generate separate KSL files for secondary namespaces unless the EM explicitly requests it or the namespaces are owned by different deployable services.

**Step 3b — V2 permission name mapping**

Present a proposed mapping table derived from `v1_permissions.items` using the naming convention `{app}_{resource_singular}_{action}`:

| v1 action | v2 action mapping |
|---|---|
| `read` | `view` |
| `write` | Ask: "Does `write` cover update, delete, move, or a combination? List which." |
| `create` | `new` |
| `delete` | `remove` or `delete` |
| `*` | `admin` (or expand to individual permissions) |

For each v1 permission, propose the v2 name and ask for confirmation. Example:

```
v1: inventory:hosts:read   → v2: inventory_host_view          ✓ confirm?
v1: inventory:hosts:write  → v2: inventory_host_update         ✓ confirm?
                              → v2: inventory_host_delete       (if write includes delete)
                              → v2: inventory_host_move         (if write includes move)
```

**Step 3c — Cross-service dependencies**

Ask: "Do any of your permissions require the user to also have a permission from another service? For example, viewing patch results requires `inventory:hosts:read`. If yes, list which of your permissions depend on which external permission."

This determines whether the KSL file needs:
- `@rbac.add_contingent_permission(first, second, contingent)` calls
- `import hbi` and `@hbi.expose_host_permission(v2_perm, host_perm)` calls (for host-scoped permissions)

**Step 3d — Extension point (only for services defining `public type` resources)**

If any asset type requires a KSL `public type` definition (native/native-ws-list pattern), ask:

> "Will other services in the platform need to check permissions on individual `{asset_type}` records your service manages — not just 'does the user have permission in this workspace', but 'does the user have permission on this specific `{asset_type}`?' If yes, your KSL needs a public extension so those services can scope their own permissions to your resource instances."

**Policy:**
- EM says **yes** → include `expose_{asset_type}_permission`.
- EM says **no** → omit.
- EM is **unsure** → omit. New services have no existing dependents; a missing extension does not cause KSL compilation failures. Note in the generated README that the extension can be added later if other services need to scope permissions to individual `{asset_type}` objects.

### Step 4 — Generate inventory-api resource schemas

For each asset type needing a resource schema, generate the directory tree under `{output_dir}/inventory-api/`:

```
{asset_type}/
  config.yaml
  common_representation.json
  reporters/{reporter_name}/
    config.yaml
    {asset_type}.json
```

**config.yaml** (resource level):
```yaml
resource_type: {asset_type}
resource_reporters:
  - {reporter_name}
```

**common_representation.json**:
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "workspace_id": { "type": "string" }
  },
  "required": [
    "workspace_id"
  ]
}
```
Add any additional common fields from Step 2.

**reporters/{reporter_name}/config.yaml**:
```yaml
resource_type: {asset_type}
reporter_name: {reporter_name}
namespace: {reporter_name}
```

**reporters/{reporter_name}/{asset_type}.json**:
JSON Schema draft-07 from Step 2 reporter-specific fields. For nullable fields, use `oneOf` with null:
```json
{
  "field_name": {
    "oneOf": [
      { "type": "string", "format": "uuid" },
      { "type": "null" }
    ]
  }
}
```

### Step 5 — Generate KSL permissions schema

Generate `{output_dir}/rbac-config/schemas/src/{namespace}.ksl`.

**Structure:**

```
version 0.1
namespace {namespace}

import rbac
{import hbi  — only if using expose_host_permission or contingent with inventory_host_view}
```

**KSL generation rules — read before writing any declarations:**

1. **No redundant top-level declarations for `public type` permissions.** If a permission is declared inside a `public type` block, do NOT also emit a standalone `@rbac.add_v1_based_permission(...)` for it at the top level. The type block's extension auto-generates all required workspace-propagation chains. Emitting both produces duplicate/incorrect KSL.

2. **Do not emit permissions for types owned by `rbac.ksl`.** Asset types that map to `rbac.workspace` (identified in Step 1 via the interview's asset type ownership notes, or by a `KesselResourceType(namespace="rbac")` in the codebase) have their write-operation permissions (`rbac_workspace_edit`, `rbac_workspace_create`, `rbac_workspace_delete`, `rbac_workspace_move`) declared in `rbac.ksl`. The service's KSL should **not** re-declare these. Include them in `permissions.json` and `roles.json` as needed, but not in the KSL.

3. **Top-level declarations are only for workspace-level permissions that have no corresponding `public type` block.** Typical uses: secondary-namespace permissions (e.g. `staleness:staleness:*`), and any permission not associated with a service-owned resource type.

**Permission declarations** — select the extension based on the pattern and Step 3 answers:

| Situation | Extension to use |
|---|---|
| Standard v1→v2 migration (most common) | `@rbac.add_v1_based_permission(app:'{app}', resource:'{resource}', verb:'{verb}', v2_perm:'{v2_perm}')` |
| Permission that is v1-only and being deprecated | `@rbac.add_v1only_permission(perm:'{v2_perm}')` |
| Permission where v1 and v2 names are identical | `@rbac.add_unified_permission(app:'{app}', resource:'{resource}', verb:'{verb}')` |
| Permission contingent on another service's permission | `@rbac.add_contingent_permission(first: '{external_perm}', second: '{own_assigned_perm}', contingent: '{final_perm}')` |
| Host-scoped permission (requires hbi import) | `@hbi.expose_host_permission(v2_perm: '{final_perm}', host_perm: '{host_perm}')` |

**Resource type definition** — only for native/native-ws-list patterns:

```
public type {asset_type} {
    private relation workspace: [ExactlyOne rbac.workspace]
    relation tenant: workspace.tenant

    @rbac.add_v1_based_permission(app:'{app}', resource:'{resource}', verb:'{verb}', v2_perm:'{v2_perm}')
    relation {action}: workspace.{v2_perm}
}
```

**Extension point** — only if Step 3d confirmed other services need to attach permissions:

```
public extension expose_{asset_type}_permission(v2_perm, {asset_type}_perm) {
    type {asset_type} {
        public relation `${{{asset_type}_perm}}`: view and workspace.`${{v2_perm}}`
    }
}
```

Group permissions by comment block (e.g. `// App: {app} - Resource: {resource}`).

### Step 6 — Generate permissions.json

Generate `{output_dir}/rbac-config/permissions/{app}.json` for each distinct v1 app namespace in `v1_permissions.items`.

Group permissions by resource, list verbs:

```json
{
  "{resource}": [
    { "verb": "read" },
    { "verb": "write" }
  ]
}
```

If v1 permissions span multiple app namespaces (e.g. `inventory` and `staleness`), generate one file per app.

### Step 7 — Generate roles.json

Generate `{output_dir}/rbac-config/roles/{app}.json` with scaffold roles:

1. **{App} administrator** — `system: true`, `admin_default: true`, access: `["{app}:*:*"]`
2. **{App} viewer** — `system: true`, `platform_default: true`, access: all `read` permissions listed individually

Use this template for each role:
```json
{
  "name": "{App} administrator",
  "description": "Perform any available operation on {App} resources.",
  "system": true,
  "platform_default": false,
  "admin_default": true,
  "version": 1,
  "access": [
    { "permission": "{app}:*:*" }
  ]
}
```

Add a note in the README (not in the JSON file itself) that roles are scaffolded defaults — the team should customize role names, descriptions, and permission bundles. Do **not** add a `_comment` or any other extra key to the roles JSON file; `roles.schema` uses `additionalProperties: false` and will reject any key that is not `roles`.

If multiple app namespaces, generate one roles file per app.

### Step 8 — Generate README

Write `{output_dir}/README.md` with:

1. File tree of all generated artifacts
2. Next steps:
   - Review and adjust all generated files
   - For resource schemas: copy `{asset_type}/` directories to `inventory-api/data/schema/resources/`, run `go run main.go preload-schema`, run `make build-schemas`
   - For KSL: copy `{namespace}.ksl` to `rbac-config/configs/stage/schemas/src/`, run `make ksl-test-schema-stage` to validate
   - For permissions/roles JSON: copy to `rbac-config/configs/stage/permissions/` and `rbac-config/configs/stage/roles/`, validate against JSON schemas in `rbac-config/schemas/`
   - Add app name(s) to `rbac-config/configs/stage/schemas/migrated_apps.lst`
   - Open PRs against both repos for review
3. Validation commands (see Step 8.5 results for what was already run; include remaining manual steps)
4. Testing resources — include the following links verbatim in the generated README, grouped by purpose:

```markdown
## Testing and validation resources

### KSL / permissions schema

- **Migration guide — Model the permissions**
  https://project-kessel.github.io/docs/building-with-kessel/how-to/migrate-from-rbac-v1-to-v2/
  Explains KSL extension patterns (`add_v1_based_permission`, `add_contingent_permission`, `expose_host_permission`),
  role definitions, and how to check in permission definitions to rbac-config.

- **rbac-config stage schemas** (reference implementations)
  https://github.com/project-kessel/rbac-config/tree/master/configs/stage/schemas/src
  Browse existing `.ksl` files to see how other services (advisor, patch, compliance, content-sources) structured
  their permission schemas. Useful for calibrating your own KSL before opening a PR.

- **SpiceDB Playground** (interactive KSL/zed testing — no running Kessel required)
  https://play.authzed.com/schema
  Run `make ksl-test-schema-stage` in rbac-config to compile your KSL to a `.zed` schema, then paste the output
  here to interactively test relationship checks (e.g. "does user X have `view` on host Y?") before deploying.
  This is the fastest way to verify your permission model behaves as intended.

- **KSL-016: Migrating host and organization level permissions** (internal, Red Hat only)
  https://docs.google.com/document/d/1XnINsHuYeHEi22q_1cS0gUalX-eXl3V19gGf0Wr8NsE/
  The source design document for the five KSL-016 patterns. Authoritative rationale for pattern selection,
  cardinality rules, and the workspace hierarchy model.

- **RBAC Platform documentation** (internal, Red Hat only)
  https://consoledot.pages.redhat.com/docs/dev/services/rbac.html
  RBAC service internals, workspace lookup APIs (`/v2/workspaces?type=default|root`), and service account setup.

### inventory-api resource schema

- **Kessel Inventory API — gRPC reference**
  https://buf.build/project-kessel/inventory-api/docs/main:kessel.inventory.v1beta2
  Full protobuf reference for `Check`, `CheckForUpdate`, `StreamedListObjects`, and `ReportResource` calls.
  Use alongside your resource schema to confirm field names and types match what the API expects.

- **inventory-api repository**
  https://github.com/project-kessel/inventory-api
  Source for the schema loader (`data/schema/resources/`), validation logic, and `go run main.go preload-schema`.

### Ephemeral environment testing

- **Validate in ephemeral environment** (migration guide section)
  https://project-kessel.github.io/docs/building-with-kessel/how-to/migrate-from-rbac-v1-to-v2/#validate-in-ephemeral-environment
  Step-by-step guide to deploying your service + Kessel in an ephemeral environment via insights-service-deployer,
  setting up authentication, and running end-to-end permission checks.

- **insights-service-deployer**
  https://github.com/project-kessel/insights-service-deployer/tree/main
  Tool for spinning up Kessel + your service in an ephemeral environment for integration testing.
```

### Step 8.5 — Validate generated artifacts

Run whichever validators are available (from the Step 0 preflight). All checks are structural — they verify the files are syntactically and schema-conformant, not that permissions behave correctly at runtime.

**JSON syntax — all `.json` files** (requires `jq`):
```bash
jq . {file}.json
```
Run against every generated JSON file: `host.json`, `common_representation.json`, `permissions/{app}.json`, `roles/{app}.json`. A non-zero exit code means the file is malformed JSON. Fix before reporting results.

**permissions.json structural validation** (requires `python3` + `jsonschema` + `rbac_config_path`):
```bash
python3 -c "
import json, jsonschema
schema = json.load(open('{rbac_config_path}/schemas/permissions.schema'))
data   = json.load(open('{output_dir}/rbac-config/permissions/{app}.json'))
jsonschema.validate(data, schema)
print('OK')
"
```
Run for each generated permissions file. Validates structure against rbac-config's own JSON Schema.

**roles.json structural validation** (requires `python3` + `jsonschema` + `rbac_config_path`):
```bash
python3 -c "
import json, jsonschema
schema = json.load(open('{rbac_config_path}/schemas/roles.schema'))
data   = json.load(open('{output_dir}/rbac-config/roles/{app}.json'))
jsonschema.validate(data, schema)
print('OK')
"
```

**inventory-api JSON Schema meta-validation** (requires `python3` + `jsonschema`):
```bash
python3 -c "
import json, jsonschema
for path in ['{output_dir}/inventory-api/{type}/common_representation.json',
             '{output_dir}/inventory-api/{type}/reporters/{reporter}/{type}.json']:
    jsonschema.Draft7Validator.check_schema(json.load(open(path)))
    print(f'OK: {path}')
"
```
Confirms each inventory-api schema file is a valid JSON Schema draft-07 document (not that the schema content is semantically correct — that requires runtime validation via `go run main.go preload-schema`).

**KSL syntax check** (requires `ksl` binary + `rbac_config_path`):
```bash
# Compile generated KSL alongside all existing KSL files and the v1 permissions JSON
$(GOBIN)/ksl -o /tmp/draft-{namespace}-schema.zed \
  {rbac_config_path}/configs/stage/schemas/src/*.ksl \
  {output_dir}/rbac-config/schemas/src/{namespace}.ksl \
  {rbac_config_path}/configs/stage/schemas/src/rbac_v1_permissions.json
```
This compiles the draft alongside the full real schema set so import resolution works. A non-zero exit means a KSL syntax or type error — include the compiler output in the Step 9 report.

Note: this command reads from but does not modify the real rbac-config repo. The generated `.ksl` is passed as an additional input file.

**After running all available checks**, set a validation status for each artifact type:
- ✅ **Validated** — check ran and passed
- ⚠️ **Partially validated** — some checks ran (e.g. JSON valid but structural schema check skipped due to missing tool)
- ❌ **Failed** — check ran and found errors (include error output; do not proceed to Step 9 without flagging)
- ⏭️ **Unvalidated** — required tool not available

### Step 9 — Present output and review

Show the EM/tech lead:

1. Full content of the `.ksl` file
2. Summary table of resource schemas generated
3. Permissions and roles overview
4. **Validation results** — one line per artifact type with its status from Step 8.5; if any check failed, show the error output before anything else
5. Any flags or warnings (e.g. "write verb was not split — confirm whether delete/move are separate operations")

## Outputs

| Output | Path |
|--------|------|
| Resource schemas | `{output_dir}/inventory-api/{asset_type}/` (one per asset type) |
| KSL schema | `{output_dir}/rbac-config/schemas/src/{namespace}.ksl` |
| Permissions JSON | `{output_dir}/rbac-config/permissions/{app}.json` (one per v1 app) |
| Roles JSON | `{output_dir}/rbac-config/roles/{app}.json` (one per v1 app) |
| README | `{output_dir}/README.md` |

Return all paths to the orchestrating agent or user.

## MCP policy

| Tool | Allowed |
|------|---------|
| `create_issue` / `update_issue` | **No** |
| `search_issues` / `get_issue` | No (not needed) |
| File reads (codebase_ref) | Yes |
| File writes (output_dir) | Yes — local artifacts only |

## Codebase analysis signals

When `codebase_ref` is available, look for these to draft Step 2–3 answers:

| Field to draft | Signals to look for |
|---|---|
| Reporter name | Kessel SDK `ClientBuilder` calls, reporter config, app short name |
| Reporter fields | DB model/migration columns, API response schemas, protobuf messages, marshmallow/pydantic schemas |
| KSL namespace | Existing `.ksl` files, Kessel SDK namespace config, app identifier |
| V2 permission names | `KesselPermission` or equivalent classes, Kessel SDK permission constants |
| Contingent permissions | Cross-service API calls, stacked `@access` decorators, permission dependencies |

## Changelog

- 2026-07: Steps 0/3a/3d/5/7/8/8.5 — tool preflight (ksl, jq, jsonschema); multi-namespace KSL consolidation; concrete extension-point question (omit when unsure, new services have no dependents); three KSL generation rules (no redundant top-level declarations, no rbac.ksl-owned permissions, top-level for workspace-level only); roles.json must not use _comment (additionalProperties:false); real testing/validation resource links in README; structural validation step after generation.
- 2026-07: Initial version.

Assisted-by: Claude (Anthropic)
