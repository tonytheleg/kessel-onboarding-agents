# Schema design reference

Format specifications, naming conventions, and examples for generating Kessel resource and permissions schemas.

## Inventory-API resource schema format

### Directory structure

```
data/schema/resources/{resource_type}/
  config.yaml                         # resource-level config
  common_representation.json          # JSON Schema draft-07 — shared fields
  reporters/{reporter_name}/
    config.yaml                       # reporter-level config
    {resource_type}.json              # JSON Schema draft-07 — reporter-specific fields
```

Resource types are auto-discovered at startup by scanning this directory tree. No Go code changes needed.

### Naming conventions

| Element | Convention | Example |
|---|---|---|
| Resource type directory | snake_case | `host`, `k8s_cluster`, `notifications_integration` |
| Resource type value in config.yaml | snake_case or slash-separated | `host`, `notifications/integration` |
| Reporter name directory | lowercase | `hbi`, `acm`, `notifications` |
| Reporter JSON file | `{resource_type_directory}.json` | `host.json`, `k8s_cluster.json` |

Slash-separated type names (`notifications/integration`) are normalized to underscores for directory names (`notifications_integration`) and lowercased during registration.

### config.yaml (resource level)

```yaml
resource_type: {type_name}
resource_reporters:
  - {reporter_name_1}
  - {reporter_name_2}
```

Reporter names in the list should match the directory names under `reporters/`.

### common_representation.json

JSON Schema draft-07. Every resource type requires at least `workspace_id`:

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

### config.yaml (reporter level)

```yaml
resource_type: {type_name}
reporter_name: {reporter_name}
namespace: {namespace}
```

`namespace` is typically the same as `reporter_name`.

### Reporter-specific JSON Schema

JSON Schema draft-07. Reporter-specific fields that this reporter sends alongside the common representation.

#### Type patterns

| JSON Schema type | When to use |
|---|---|
| `{ "type": "string" }` | Plain text field |
| `{ "type": "string", "format": "uuid" }` | UUID identifiers |
| `{ "type": "string", "maxLength": 255 }` | Length-constrained strings |
| `{ "type": "string", "enum": ["VALUE_1", "VALUE_2"] }` | Fixed set of values |
| `{ "type": "integer" }` | Whole numbers |
| `{ "type": "boolean" }` | True/false |
| `{ "type": "array", "items": { ... } }` | Lists of objects/values |

#### Nullable fields

Use `oneOf` with null for fields that may not be present:

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

#### Required fields

List field names in the `"required"` array. Use an empty array `[]` when all fields are optional.

### Existing resource type examples

| Resource type | Reporters | Notable features |
|---|---|---|
| `host` | `hbi` | 1 reporter, nullable UUID fields, minimal common representation |
| `k8s_cluster` | `acm`, `acs`, `ocm` | 3 reporters (identical schemas), enum fields, nested array objects |
| `k8s_policy` | `acm` | 1 reporter, simple schema |
| `notifications_integration` | `notifications` | Slash-separated type name (`notifications/integration`), fixed enum reporter_type |

### Validation

Schemas are validated at runtime by `SchemaService.ValidateReportAgainstSchema()`:
1. Reporter must be listed in the resource's `config.yaml`
2. Reporter representation validated against reporter JSON Schema
3. Common representation validated against common JSON Schema

Test locally:
```bash
go run main.go preload-schema    # Regenerate schema_cache.json
make build-schemas               # Update resources.tar.gz for deployment
```

---

## KSL permissions schema format

KSL (Kessel Schema Language) is a DSL that compiles to SpiceDB's `.zed` format. Each service gets one `.ksl` file in `rbac-config/configs/{env}/schemas/src/`.

### File structure

```
version {version}
namespace {namespace}

import rbac
{import hbi  — only when using hbi.expose_host_permission}

{permission declarations}

{type definitions — only for native/native-ws-list patterns}

{extension definitions — only when other services need to attach permissions}
```

### Version

- `0.1` — standard (most services)
- `0.2` — used by notifications (no functional difference currently)

### Namespace

Lowercase, underscores instead of hyphens. Derived from service short name:

| Service | Namespace |
|---|---|
| Host Based Inventory | `hbi` |
| Content Sources | `content_sources` |
| Config Manager | `config_manager` |
| Playbook Dispatcher | `playbook_dispatcher` |

### Imports

Every service imports `rbac`. Services with host-scoped permissions also import `hbi`.

### Extension patterns

#### `add_v1_based_permission` — Standard v1→v2 migration

The most common pattern. Maps a v1 `app:resource:verb` triple to a v2 permission name that flows through the workspace hierarchy.

```
@rbac.add_v1_based_permission(app:'{app}', resource:'{resource}', verb:'{verb}', v2_perm:'{v2_perm}');
```

The v2 permission becomes checkable on workspaces and (if used inside a `type` block) on resource instances. The extension auto-generates relations on `role`, `role_binding`, `platform`, `tenant`, and `workspace` types, plus wildcard resolution chains (`app_resource_all`, `app_all_verb`, `app_all_all`, `all_all_all`).

**Example** (content-sources — simple workspace-level):
```
@rbac.add_v1_based_permission(app:'content_sources', resource:'repositories', verb:'read', v2_perm:'content_sources_repository_view');
@rbac.add_v1_based_permission(app:'content_sources', resource:'repositories', verb:'write', v2_perm:'content_sources_repository_edit');
```

#### `add_unified_permission` — Same name for v1 and v2

Used when the v1 permission name is identical to the desired v2 permission. Adds `[bool]` for direct writability.

```
@rbac.add_unified_permission(app:'{app}', resource:'{resource}', verb:'{verb}')
```

The v2 permission name is auto-derived as `{app}_{resource}_{verb}`.

**Example** (rbac service's own permissions):
```
@rbac.add_unified_permission(app:'rbac', resource:'principal', verb:'read')
```

#### `add_v1only_permission` — Deprecated v1 permission

Assigns a permission to the role only (does not propagate through workspaces). Used for migration placeholders.

```
@rbac.add_v1only_permission(perm:'{permission_name}');
```

**Example** (compliance — deprecated frontend permissions):
```
@rbac.add_v1only_permission(perm:'compliance_policy_update');
```

#### `add_contingent_permission` — Requires two permissions

Creates a permission that requires the user to have **both** an external permission and the service's own permission (intersection). Common for host-scoped services.

```
@rbac.add_contingent_permission(first: '{external_perm}', second: '{own_assigned_perm}', contingent: '{final_perm}');
```

Three-step pattern for host-scoped permissions:
1. `add_v1_based_permission` → creates `{perm}_assigned`
2. `add_contingent_permission` → intersects with `inventory_host_view` → creates `{perm}`
3. `hbi.expose_host_permission` → makes it checkable on individual host objects

**Example** (advisor — host-scoped read):
```
@rbac.add_v1_based_permission(app:'advisor', resource:'recommendation_results', verb:'read', v2_perm:'advisor_recommendation_results_view_assigned');
@rbac.add_contingent_permission(first: 'inventory_host_view', second: 'advisor_recommendation_results_view_assigned', contingent: 'advisor_recommendation_results_view');
@hbi.expose_host_permission(v2_perm: 'advisor_recommendation_results_view', host_perm: 'advisor_recommendation_results_view');
```

#### `hbi.expose_host_permission` — Permission on individual hosts

Makes a permission checkable on `hbi/host` resource instances. Requires `import hbi`.

```
@hbi.expose_host_permission(v2_perm: '{v2_perm}', host_perm: '{host_perm}');
```

The exposed permission requires both `view` on the host AND the workspace-level permission.

### Type definitions

Only needed for native/native-ws-list patterns where the service defines its own resource type in the Kessel authorization graph.

```
public type {resource_type} {
    private relation workspace: [ExactlyOne rbac.workspace]
    relation tenant: workspace.tenant

    @rbac.add_v1_based_permission(app:'{app}', resource:'{resource}', verb:'{verb}', v2_perm:'{v2_perm}')
    relation {action}: workspace.{v2_perm}
}
```

**Example** (hbi — host type):
```
public type host {
    private relation workspace: [ExactlyOne rbac.workspace]
    relation tenant: workspace.tenant

    @rbac.add_v1_based_permission(app:'inventory', resource:'hosts', verb:'read', v2_perm:'inventory_host_view')
    relation view: workspace.inventory_host_view
    @rbac.add_v1_based_permission(app:'inventory', resource:'hosts', verb:'write', v2_perm:'inventory_host_update')
    relation update: workspace.inventory_host_update
    @rbac.add_v1_based_permission(app:'inventory', resource:'hosts', verb:'write', v2_perm:'inventory_host_delete')
    relation delete: workspace.inventory_host_delete
    @rbac.add_v1_based_permission(app:'inventory', resource:'groups', verb:'write', v2_perm:'inventory_host_move')
    relation move: workspace.inventory_host_move
}
```

Key rules:
- `workspace` relation is always `private` with `[ExactlyOne rbac.workspace]`
- `tenant` relation always derives from `workspace.tenant`
- Each permission relation derives from `workspace.{v2_perm}`
- The relation name (e.g. `view`, `update`) becomes the `relation` value in Kessel `Check` calls
- Multiple v1 permissions can map to the same v1 `verb` with different v2 actions (e.g. `write` → `update`, `delete`, `move`)

### Extension point definitions

Only needed when other services need to attach permissions to this resource type.

```
public extension expose_{resource_type}_permission(v2_perm, {resource_type}_perm) {
    type {resource_type} {
        public relation `${{{resource_type}_perm}}`: view and workspace.`${{v2_perm}}`
    }
}
```

**Example** (hbi — allows advisor, patch, etc. to attach permissions to hosts):
```
public extension expose_host_permission(v2_perm, host_perm) {
    type host {
        public relation `${host_perm}`: view and workspace.`${v2_perm}`
    }
}
```

---

## V2 permission naming convention

Pattern: `{app}_{resource_singular}_{action}`

### Action mapping from v1 verbs

| v1 verb | v2 action(s) | Notes |
|---|---|---|
| `read` | `view` | Always `view`, never `read` |
| `write` | `edit`, `update`, `delete`, `move`, `new` | **Must ask** — `write` almost always splits into multiple v2 actions |
| `create` | `new` | |
| `delete` | `remove` or `delete` | Prefer `remove` for consistency with other services; `delete` is also used (e.g. `inventory_host_delete`) |
| `*` | N/A | Wildcard — handled by the extension's chain (`app_resource_all`, etc.); no explicit v2 permission needed |
| `upload` | `upload` | Carried through as-is (e.g. `content_sources_repository_upload`) |

### Resource name singularization

v2 permission names use the **singular** form:

| v1 resource | v2 resource |
|---|---|
| `hosts` | `host` |
| `groups` | `workspace` (special case — groups became workspaces) |
| `repositories` | `repository` |
| `endpoints` | `endpoint` |
| `notifications` | `notification` (but `notifications_notifications_view` keeps the app prefix) |

### Host-scoped permission naming

For permissions that go through the contingent + expose pattern, use the `_assigned` suffix for the intermediate permission:

```
{app}_{resource}_{action}_assigned    → intermediate (workspace-level)
{app}_{resource}_{action}             → final (host-level, after intersection with inventory_host_view)
```

---

## Permissions.json format

One JSON file per v1 app namespace. Located at `rbac-config/configs/{env}/permissions/{app}.json`.

```json
{
  "{resource_1}": [
    { "verb": "read" },
    { "verb": "write" },
    { "verb": "*" }
  ],
  "{resource_2}": [
    { "verb": "read" }
  ],
  "*": [
    { "verb": "*" }
  ]
}
```

Validated against `rbac-config/schemas/permissions.schema` (JSON Schema).

---

## Roles.json format

One JSON file per v1 app namespace. Located at `rbac-config/configs/{env}/roles/{app}.json`.

```json
{
  "roles": [
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
    },
    {
      "name": "{App} viewer",
      "description": "Perform read operations on {App} resources.",
      "system": true,
      "platform_default": true,
      "admin_default": false,
      "version": 1,
      "access": [
        { "permission": "{app}:{resource_1}:read" },
        { "permission": "{app}:{resource_2}:read" }
      ]
    }
  ]
}
```

### Role fields

| Field | Type | Description |
|---|---|---|
| `name` | string | Display name |
| `display_name` | string | Optional override for UI display |
| `description` | string | What this role grants |
| `system` | boolean | `true` for platform-defined roles |
| `platform_default` | boolean | `true` = granted to all users by default |
| `admin_default` | boolean | `true` = granted to org admins by default |
| `version` | integer | Start at 1; increment on any change to access list |
| `access` | array | List of `{ "permission": "app:resource:verb" }` |

Validated against `rbac-config/schemas/roles.schema` (JSON Schema).

### Common role patterns

| Pattern | `platform_default` | `admin_default` | Access |
|---|---|---|---|
| Full admin | false | true | `{app}:*:*` |
| Resource admin | false | true | `{app}:{resource}:read` + `{app}:{resource}:write` |
| Viewer | true | false | All `read` permissions |
| No default access | false | false | Specific permission set |

Cross-service permissions (e.g. compliance admin needing `remediations:remediation:read`) are valid in role access lists.

---

## migrated_apps.lst

After adding permissions, the app name must be added to `rbac-config/configs/{env}/schemas/migrated_apps.lst` (one app name per line, no quotes). This enables v2 schema generation for the app.

If the service spans multiple v1 app namespaces (e.g. `inventory` and `staleness`), each app name needs its own line.

---

## Validation commands

### rbac-config

```bash
make init                      # Install ksl compiler
make ksl-test-schema-stage     # Compile and validate stage schemas (writes to _private/test-schema/)
```

The `ksl-test-schema-stage` target compiles all `.ksl` files, generates the combined `schema.zed`, and validates it against SpiceDB. Errors indicate invalid KSL syntax, missing imports, or type conflicts.

### inventory-api

```bash
go run main.go preload-schema  # Regenerate schema_cache.json from data/schema/resources/
make build-schemas             # Package schemas for deployment
make test                      # Run full test suite including schema validation tests
```

---

## Existing KSL files by pattern complexity

### Simple — workspace-level only (no custom type)

- `content-sources.ksl` — 2 resources, 5 permissions
- `subscriptions.ksl` — 5 resources, 9 permissions
- `tasks.ksl`
- `ros.ksl`
- `malware.ksl`

### Medium — contingent + host-scoped

- `compliance.ksl` — contingent permission with `inventory_host_view`, v1only deprecated permissions
- `advisor.ksl` — full three-step host-scoped pattern (assigned → contingent → expose)
- `patch.ksl` — host-scoped with cross-service contingent (content_sources + patch)
- `vulnerability.ksl`

### Complex — defines a public type

- `hbi.ksl` — defines `public type host` with workspace relation, plus `expose_host_permission` extension
- `rbac.ksl` — defines all core types and extensions (not a service schema — framework only)

## KSL generation rules

These rules apply when writing any KSL file. See SKILL.md Step 5 for full context.

1. **No redundant top-level declarations for `public type` permissions.** Permissions declared inside a `public type` block auto-generate workspace-propagation chains — a matching top-level `@rbac.add_v1_based_permission(...)` is incorrect and will cause duplicate symbol errors.

2. **Do not declare permissions owned by `rbac.ksl`.** Workspace write-operation permissions (`rbac_workspace_edit`, `rbac_workspace_create`, `rbac_workspace_delete`, `rbac_workspace_move`) are declared on the `rbac.workspace` type inside `rbac.ksl`. A service's KSL must not re-declare them. Include them in `permissions.json` and `roles.json` as needed.

3. **Top-level declarations are only for workspace-level permissions with no `public type` block.** Typical use: secondary-namespace permissions (e.g. `staleness:staleness:*`) and permissions not tied to a service-owned resource type.

4. **Multi-namespace default: one KSL file per service.** If a service owns multiple v1 app namespaces (e.g. `inventory` and `staleness`), consolidate them in a single KSL file under the primary namespace unless the EM explicitly requests separate files. Secondary namespace declarations go at the top of the file with a comment.

## Roles.json authoring rules

- The top-level object must contain only the `roles` key. `roles.schema` uses `additionalProperties: false` — any extra key (including `_comment`) is a validation error.
- Put scaffold notes and customization guidance in the generated README, not in the JSON file.

## Changelog

- 2026-07: Added KSL generation rules and roles.json authoring rules sections based on live compiler and validator testing.
- 2026-07: Initial version.

Assisted-by: Claude (Anthropic)
