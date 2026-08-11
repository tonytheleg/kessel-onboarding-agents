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
| Resource type directory | `snake_case` lowercase | `host`, `k8s_cluster`, `notifications_integration` |
| Resource type value in config.yaml | `snake_case` or slash-separated | `host`, `notifications/integration` |
| `resource_reporters` list entries | **UPPERCASE** | `HBI`, `TASKMANAGER`, `NOTIFICATIONS` |
| Reporter directory name | lowercase | `hbi`, `taskmanager`, `notifications` |
| `reporter_name` field in reporter config.yaml | lowercase | `hbi`, `taskmanager` |
| `namespace` field in reporter config.yaml | lowercase (matches `reporter_name`) | `hbi`, `taskmanager` |
| Reporter JSON file | `{resource_type_directory}.json` | `host.json`, `k8s_cluster.json` |
| `reporter_type` in gRPC calls | UPPERCASE | `"HBI"`, `"TASKMANAGER"` |

**Reporter casing duality:** the same reporter is written UPPERCASE in `resource_reporters` and gRPC `reporter_type`, and lowercase in the filesystem directory, `reporter_name` field, and `namespace` field. The values are case-insensitively matched at registration. Example: `resource_reporters: [TASKMANAGER]` ↔ `reporters/taskmanager/` ↔ `reporter_name: taskmanager`.

Slash-separated type names (`notifications/integration`) are normalized to underscores for directory names (`notifications_integration`) and lowercased during registration.

### config.yaml (resource level)

```yaml
resource_type: {type_name}
resource_reporters:
  - {reporter_name_1}
  - {reporter_name_2}
```

Reporter names use **UPPERCASE** — see naming conventions table above for the full casing duality.

### common_representation.json

JSON Schema draft-07. Every resource type that participates in access control must include `workspace_id` as a required field.

**Why `workspace_id` is required:** When inventory-api receives a `ReportResource` call with a common representation containing `workspace_id`, it automatically creates an authorization graph tuple `{type}:{local_resource_id}#workspace@rbac/workspace:{workspace_id}`. This is hardcoded behavior — without this tuple, SpiceDB has no relationship to traverse and permission checks against the resource will fail. Omitting `workspace_id` from the common representation will cause the consumer to fail to write tuples with `object definition not found`.

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

Additional common fields beyond `workspace_id` are rare — most services only need `workspace_id`. Add more only when a field genuinely needs to be shared identically across all reporters.

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
| `{ "type": "string", "pattern": "^[a-z0-9.-]+$" }` | Regex-constrained strings |
| `{ "type": "string", "enum": ["VALUE_1", "VALUE_2"] }` | Fixed set of values |
| `{ "type": "integer", "minimum": 1 }` | Whole numbers with lower bound |
| `{ "type": "number", "minimum": 0 }` | Decimal/float numbers (e.g. memory in GB) |
| `{ "type": "boolean" }` | True/false |
| `{ "type": "array", "items": { ... } }` | Lists of objects/values |

Add `"description": "..."` to any field that would benefit from a human-readable explanation. Descriptions are preserved in the schema and surfaced in validation error messages.

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

### What to include in reporter-specific fields

**Only report fields that serve at least one of these purposes:**
1. Access control depends on the attribute or relationship (e.g. workspace assignment, owner, status that gates access)
2. Downstream services or external consumers rely on the data for automation, reporting, or decision-making

Do NOT report a field just because the service has it. Unnecessary fields increase storage costs, replication load, and processing time.

**`local_resource_id` format guidance:** UUIDs are preferred for service-generated resource IDs. Human-readable strings are acceptable for user-facing resources (e.g. usernames, group names) where the ID is meaningful to users.

### gRPC representation metadata fields

When calling `ReportResource`, the `representations.metadata` object contains:

| Field | Type | Purpose |
|---|---|---|
| `local_resource_id` | string | The service-local identifier for this resource |
| `api_href` | string | URL to the REST API for this resource |
| `console_href` | string | URL to the UI console for this resource (optional) |
| `reporter_version` | string | Version string for the reporter service (optional) |

These are separate from the schema-validated `common` and `reporter` fields. The schema only validates the `common` and `reporter` bodies — `metadata` fields are not schema-validated.

### Validation

Schemas are validated at runtime by `SchemaService.ValidateReportAgainstSchema()`:
1. Reporter must be listed in the resource's `config.yaml`
2. Reporter representation validated against reporter JSON Schema
3. Common representation validated against common JSON Schema

Validation errors are returned as gRPC `INVALID_ARGUMENT` with field-level details:
```
failed validation for report resource: validation failed:
  cpu_count: Invalid type. Expected: integer, given: string;
  hostname is required
```

**Restart required:** After adding new schema files under `data/schema/resources/`, restart the Inventory API to pick up the new resource type.

Test locally:
```bash
go run main.go preload-schema    # Regenerate schema_cache.json
make build-schemas               # Update resources.tar.gz for deployment
```

---

## Workspace and tenancy concepts (relevant to schema design)

Understanding Kessel's workspace model is essential for choosing the right KSL pattern and designing the `workspace_id` field correctly.

### Workspace types

Every organization (tenant) automatically gets two workspaces at creation time:

| Type | Purpose | Notes |
|---|---|---|
| `ROOT` | Top-level hierarchy container | No parent; unique per tenant; cannot be created via API |
| `DEFAULT` | Primary resource container | Parent is ROOT; unique per tenant; cannot be created via API |
| `STANDARD` | User-defined team/project workspaces | Default parent is DEFAULT if unspecified |
| `UNGROUPED_HOSTS` | System workspace for unassigned hosts | Has a parent |

These map directly to the KSL adoption patterns:
- `default-workspace` pattern → checks against the **DEFAULT** workspace for the org
- `root-workspace` pattern → checks against the **ROOT** workspace for the org
- `native` / `native-ws-list` patterns → checks against the specific workspace the resource belongs to

### Resources belong to exactly one workspace

The `workspace_id` field in `common_representation.json` assigns the resource to a workspace. A resource can belong to **at most one workspace at a time** — reassignment removes the old relationship. This is why `workspace_id` is a single `string`, not an array.

### Permission inheritance

Permissions granted on a parent workspace automatically apply to all descendant workspaces. A Check traversal works upward: current workspace → parent → grandparent → ROOT. If no role binding grants the permission at any level, access is denied.

This is why `default-workspace` and `root-workspace` patterns work without per-resource tuples: the Check targets the org's DEFAULT or ROOT workspace, and the user's role binding at that workspace grants access.

Workspace ID resolution API and auth header rules are in the **Pattern-specific implementation notes** section below.

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

The `_assigned` suffix convention for contingent permissions is covered with a full example in **Pattern-specific implementation notes** below.

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

**Authoring rules:** The top-level object must contain only the `roles` key — `roles.schema` uses `additionalProperties: false`, so any extra key (including `_comment`) is a validation error. Put scaffold notes in the generated README, not in the JSON file.

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

---

## KSL PR review checklist (authoritative gate criteria)

These are the checks a Kessel schema reviewer applies to every KSL PR. The schema-design skill must produce output that passes all of them.

### 1. CI must pass

The compiled schema must build cleanly (`make ksl-test-schema-stage`) and pass SpiceDB schema validation. Never generate KSL that you know will not compile.

### 2. `migrated_apps.lst` must be updated

See the **migrated_apps.lst** section for format. Both stage and prod files must be updated. If the service spans multiple v1 app namespaces, add each one separately.

### 3. Design pattern check

**Extension-only schemas** (body is entirely `@rbac.*` extension calls, no `type` definitions):
- Common for services that are host-centric or only partially onboarding
- If host-centric and NOT using `@hbi.expose_host_permission`, flag this: ask whether the omission is intentional. Using it enables per-host-ID permission checks.
- No data migration required for initial onboarding

**Schemas with `public type` definitions** (body contains type blocks):
- Require cross-team coordination before merging
- The service team is responsible for populating all writable relations (box notation `[...]`) via the outbox pattern
- A data migration is required to backfill existing data
- Kessel inventory-api needs a compatible (usually superset) resource schema

### 4. Naming conventions (PR reviewers enforce all of these)

Full naming rules are in the **V2 permission naming convention** section. Checklist-specific additions:

**Namespaces:** Must match the service's KSL namespace — all lowercase. This is the same as the reporter type lowercased: reporter `TASKMANAGER` → namespace `taskmanager`.

**`app` and `resource` parameters in `add_v1_based_permission`:**
- `app`: must match the filename of the permissions JSON (without `.json`)
- `resource`: must match the first-level key in that JSON file exactly

**Resource types** (the `name` in `public type name`):
- Lowercase singular nouns: `host` not `hosts`, `task` not `tasks`
- `snake_case` for multi-word: `k8s_cluster`, `role_binding`

**Relations:** Short and descriptive — type context is implied. Don't say `view_host` on a `host` type, just `view`. Exception: if a relation is transitive across resource types, include the target (e.g. `view_vulnerabilities` on a `host` type).

**Extensions:** `snake_case` verbal phrases: `add_v1_based_permission`, `expose_host_permission`.

### 5. Breaking change check

Removed SpiceDB relations are **red flags** — equivalent to dropping a database column. Before removing any relation:
- Confirm it is intentional
- Verify RBAC has purged the data for that permission before publishing the new schema (publishing a schema without a relation that has existing data will fail)
- If the PR adds an app to `migrated_apps.lst`, a missing or incorrect `add_v1_based_permission` call is more likely the root cause than an intentional removal

Added SpiceDB relations are generally safe. Wildcard permutations (`t_app_resource_all`, `t_app_all_verb`, etc.) are expected and harmless.

### 6. KSL authoring rules

1. **No redundant top-level declarations for `public type` permissions.** Permissions inside a `public type` block auto-generate workspace-propagation chains — a matching top-level `@rbac.add_v1_based_permission(...)` causes duplicate symbol errors.
2. **Do not declare permissions owned by `rbac.ksl`.** Workspace permissions (`rbac_workspace_edit`, `rbac_workspace_create`, etc.) belong to `rbac.ksl`. Include them in `permissions.json` and `roles.json` only.
3. **Top-level declarations are only for workspace-level permissions with no `public type` block.** Typical use: secondary-namespace permissions (e.g. `staleness:staleness:*`) and permissions not tied to a service-owned resource type.
4. **One KSL file per service.** If a service spans multiple v1 app namespaces (e.g. `inventory` and `staleness`), consolidate into a single KSL file. Secondary namespace declarations go at the top with a comment.

---

## KSL language reference (syntax and semantics)

### Visibility keywords

| Keyword | Within namespace | From other namespaces |
|---|---|---|
| `public` | Yes | Yes |
| `internal` | Yes | No |
| `private` | No | No |

Omitting visibility defaults to `public`. Use `private` for workspace relations that should not be referenced externally. Use `internal` for implementation types (role, role_binding) that other namespaces must not reference directly.

### Relation body forms

| Form | Syntax | Meaning |
|---|---|---|
| Direct link (self) | `[Cardinality TypeA or TypeB.rel]` | Stores an explicit object link |
| Alias | `someRelation` | Resolves to the same set as another relation |
| Sub-relation (traversal) | `someRelation.aPermission` | Follow link, evaluate permission on target |
| Union | `a or b` | Either satisfies |
| Intersection | `a and b` | Both must be satisfied simultaneously |
| Exclusion | `a unless b` | a, minus anything also matching b |

**Arrow direction rule:** always `relation→permission`, never `relation→relation`. The right-hand side of traversal arrows must reference a **permission** (not a raw relation) on the target type. This decouples the caller from internal structural changes in the target.

### Cardinality keywords

| Keyword | Meaning |
|---|---|
| `Any` | Zero or more (default when omitted) |
| `AtMostOne` | Zero or one — use for optional parent links |
| `ExactlyOne` | Exactly one — use for required workspace relations |
| `AtLeastOne` | One or more |

```ksl
private relation workspace: [ExactlyOne rbac.workspace]   // required, exactly one
relation parent: [AtMostOne workspace]                    // optional
relation member: [Any principal or group.member]          // any number
```

### The `[bool]` pseudo-type

`[bool]` means "any principal in the system" — used on role relations to mark a permission as directly assignable. When a role carries `relation drive_document_view: [bool]`, any user assigned that role gains the permission.

### `allow_duplicates`

When multiple extension calls each try to add the same relation to a type (e.g. a shared wildcard like `drive_all_all`), KSL raises a duplicate-symbol error by default. `allow_duplicates` suppresses this for relations that are intentionally shared:

```ksl
allow_duplicates private relation `${app}_all_all`: [bool]
```

Essential for wildcard catch-all relations shared across many `add_v1_based_permission` calls.

### Extension invocation — two placements

**File level** (most common): `@namespace.extension(params);` — injects relations into types defined in the extension body. Semicolon required.

**Inside a type body** (when the extension also needs to interact with that type's own relations):
```ksl
public type document {
    private relation workspace: [ExactlyOne rbac.workspace]

    @rbac.workspace_permission(full_name:'drive_document_view')
    public relation view: workspace.drive_document_view
}
```

### Built-in implicit variables in extensions

| Variable | Resolves to |
|---|---|
| `${NAMESPACE}` | The namespace invoking the extension |
| `${MODULE}` | Same as `${NAMESPACE}` |
| `${TYPE}` | The type the extension is applied to |
| `${RELATION}` | The relation the extension is applied to |

Use backtick template syntax for compound names: `` `${app}_${resource}_${verb}` ``

### Escaping reserved keywords

Prefix with `#` when a relation name conflicts with a KSL keyword:

```ksl
relation #version: [ExactlyOne lockversion]   // stored as "version" in SpiceDB output
```

### KSL → SpiceDB output mapping

| KSL | SpiceDB |
|---|---|
| `namespace rbac` + `type workspace` | `definition rbac/workspace` |
| `relation workspace: [ExactlyOne rbac.workspace]` | `relation t_workspace: rbac/workspace` + `permission workspace = t_workspace` |
| `or` | `+` (union) |
| `and` | `&` (intersection) |
| `unless` | `-` (exclusion) |
| `workspace.drive_document_view` | `t_workspace->drive_document_view` |
| `[bool]` | `rbac/principal:*` |

Relations become two SpiceDB entries: a `t_<name>` raw storage relation and a queryable `permission`. The `t_` prefix is SpiceDB's convention — do not reference it in KSL.

---

## Schema design rules and anti-patterns

### Fail-closed (non-negotiable)

**The schema must default to denial.** If a relationship is never written, the user must have no access. Never build a schema where access is granted by default and denied via a denylist.

Anti-pattern (fail-open — do not use):
```ksl
// WRONG: user gets access unless explicitly denied
relation public: [bool]
relation deny: [Any principal]
permission view = public unless deny
```

Correct (fail-closed):
```ksl
// CORRECT: user gets access only when explicitly granted
relation viewer: [Any principal]
permission view = viewer
```

### Centralize logic in the schema

Do not perform authorization logic in application code by combining multiple `Check` calls with `AND`/`OR`. The combined logic belongs in a single SpiceDB permission:

```ksl
// CORRECT: schema encodes the combined logic
permission view = read_grant and subscription_active
```

```go
// WRONG: application combines two checks
if Check(read_grant) && Check(subscription_active) { ... }
```

Application-side logic is invisible to schema audits and creates drift.

### Use permissions for traversal, not relations

Call `Check` against **permissions**, not raw relations. If the schema's internal structure changes, updating a permission definition requires no data migration; changing a relation definition does.

### Additive / positive phrasing

Build permissions additively from no access. Use wildcards (`user:*`) and negation (`unless`) sparingly. A schema that starts from denial and adds grants is easier to audit than one that starts with access and subtracts it.

### Self-referential types for hierarchies

If a type needs to recur (e.g. nested groups, nested workspaces), the type should reference itself directly. Multi-type circular references (A→B→C→A) are not supported and will loop until hitting the 50-hop depth limit.

Correct (self-referential):
```ksl
definition group {
    relation member: user | group
}
```

Anti-pattern (circular across types — avoid):
```ksl
// type A references B, B references C, C references A — cycle
```

### Cycle prevention before writes

Before writing a relationship that could create a cycle (e.g. adding `group:parent#member@group:child#member`), run a pre-write Check:
```
Check: group:child member group:parent
```
If the result is **allowed**, the relationship would create a cycle — abort. If **denied**, it is safe to write.

### Relations vs caveats vs permissions

| Concept | When to use |
|---|---|
| Relation | Static structural authorization (role, membership, parent, workspace) |
| Permission | Computed capability derived from relations — use for all authorization checks |
| Caveat | Dynamic contextual gate that relations cannot express (time of day, IP) — avoid where possible |
| Native expiration | Time-bound access — more efficient than caveats |

Prefer relations over caveats. Caveats are harder to cache and slow traversal.

---

## Pattern-specific implementation notes

These inform descriptions in Phase Story done-when criteria and schema rationale fields.

### `Check` vs `CheckForUpdate`

| Operation type | Use |
|---|---|
| All read operations | `Check` |
| Write operations and sensitive reads (e.g. credential access) | `CheckForUpdate` |

### Workspace ID resolution

```
GET /api/rbac/v2/workspaces/?type=default   # default-workspace pattern
GET /api/rbac/v2/workspaces/?type=root      # root-workspace pattern
```

**Critical:** Do NOT relay the `x-rh-identity` header when requesting workspace IDs. Use the Kessel SDK OAuth token and include `x-rh-rbac-org-id` instead.

### `StreamedListObjects` for native-ws-list pattern

Call `StreamedListObjects` (or equivalent `ListAllowedWorkspaces`) to resolve all workspace IDs where a principal holds a permission, then pass those IDs as a database filter. Do not enumerate resources individually at scale.

Performance limit: `LookupResources`/`ListObjects` starts degrading above approximately **10,000 accessible resources** per user. Above that threshold, use `CheckBulkPermissions` with pagination instead.

### `CheckBulkPermissions` with pagination for large sets

1. Fetch a candidate page of resources from the database
2. Call `CheckBulkPermissions` on those candidates
3. Filter to only accessible items
4. Use the `ZedToken` from the first call for all subsequent calls to get a consistent permission view
5. Repeat until you accumulate a full authorized page

Works better with cursor-based pagination than limit-offset, since the database cannot pre-determine the correct offset when items are filtered mid-page.

### Consistency: ZedToken pattern

After any write, capture the `ZedToken` from the response and pass it in subsequent read calls. This gives "at least as fresh" consistency while still using caches. Avoid `fully_consistent` reads — they bypass all caches, increase latency, and add datastore load.

### `_assigned` suffix convention for contingent permissions

The intermediate permission in a contingent (AND) permission chain always uses the `_assigned` suffix to distinguish it from the final checkable permission:

```ksl
// Step 1: intermediate (workspace-level assignment)
@rbac.add_v1_based_permission(app:'patch', resource:'system', verb:'read', v2_perm:'patch_system_view_assigned');

// Step 2: contingent final permission (requires BOTH)
@rbac.add_contingent_permission(first: 'inventory_host_view', second: 'patch_system_view_assigned', contingent: 'patch_system_view');

// Step 3: expose on individual host objects
@hbi.expose_host_permission(v2_perm: 'patch_system_view', host_perm: 'patch_system_view');
```

The final permission `patch_system_view` is what the application calls `Check` against. Never use the `_assigned` intermediate for authorization checks.

### Role definition scope

When defining roles.json entries, cover both:
- Application-specific roles (e.g. "Advisor Viewer")
- RHEL persona-based roles (e.g. "RHEL Viewer") for broader platform coverage

---

## Changelog

- 2026-08: Added workspace/tenancy concepts section; expanded resource schema section with reporter casing duality, workspace_id mechanism explanation, gRPC metadata fields, data reporting discipline rule, additional JSON Schema types (number, pattern, description), and validation error format — sourced from Kessel resource schema docs (add-resource-type, resources-representations, schema, tenancy).
- 2026-08: Added KSL PR review checklist, KSL language reference, schema design rules, and pattern-specific implementation notes — sourced from KSL PR Review Guidelines PDF, KSL beginners guide, Kessel migration docs, and AuthZed SpiceDB best practices docs.
- 2026-07: Added KSL generation rules and roles.json authoring rules sections based on live compiler and validator testing.
- 2026-07: Initial version.

Assisted-by: Claude (Anthropic)
