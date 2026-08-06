---
name: onboarding-validate-interview
description: >
  Validates the accuracy of the onboarding interview and schema-design skills by
  comparing their outputs against a service's actual Kessel implementation — source
  code, resource schemas (inventory-api), and permissions schemas (rbac-config).
  When schema design artifacts are provided (test mode), also scores the generated
  draft schemas against the real ones. Produces a structured alignment report that
  identifies gaps and informs skill improvements.
---

# Onboarding interview validation

## When to use

- After Phase 4 (PoC) or later, once a service has a real Kessel implementation to compare against — running it earlier can produce misleading results.
- Retroactively against already-migrated services (e.g. HBI) to establish a baseline for how accurately the skills predict implementation needs.
- Automatically at the end of a `/kessel-onboarding:test` run — receives both interview profile and schema-design artifacts for a full end-to-end score.

## What this skill does

Takes outputs from the interview and (optionally) schema-design skills alongside a live service implementation and answers two questions:

1. **Did the interview correctly anticipate what the team needed to build?** (interview accuracy — 12 dimensions)
2. **Did the schema-design skill generate schemas that match the real ones?** (schema accuracy — 4 dimensions, only scored when schema artifacts are provided)

Produces a structured report at `{output_path}` (default `artifacts/validation/{slug}-validation-report.md`).

## Inputs

| Input | Required | Source |
|-------|----------|--------|
| ServiceProfile JSON path | yes | Interview output or `--profile` flag |
| `codebase_ref` | yes | Service source repo — GitHub/GitLab URL or local path |
| `rbac_config_path` | no | Local path to rbac-config repo root. If omitted, checks common locations: `~/dev/rbac-config`, `../rbac-config` |
| `inventory_api_path` | no | Local path to inventory-api repo root. If omitted, checks common locations: `~/go/src/github.com/*/inventory-api`, `../inventory-api` |
| `schema_artifacts_path` | no | Path to schema-design output directory (e.g. `artifacts/test/{slug}/schemas/`). When provided, enables dimensions 13–16 scoring the generated draft schemas against the real ones. |
| `output_path` | no | Path for the validation report. Default: `{artifacts_dir}/validation/{slug}-validation-report.md`. In test mode the `/kessel-onboarding:test` command passes `artifacts/test/{slug}/validation-report.md`. |

All inputs except the profile and codebase are optional — the skill validates the dimensions it can reach and notes what was skipped.

## Configuration

Read `~/.config/kessel-onboarding/config.json` for `artifacts_dir`. Output goes to `{artifacts_dir}/validation/{slug}-validation-report.md`.

## Execution

### Step 0 — Load inputs

Read the ServiceProfile JSON. Extract:
- `service.name`, `service.slug`
- `asset_types[]`, `v1_permissions.items`, `patterns[]`
- `ui_access_checks`, `inventory_migration_required`, `inventory_reporting`
- `tech_stack`, `ephemeral`
- `interview.codebase_ref` (use as fallback if `--codebase_ref` not supplied)

Resolve `codebase_ref`. If neither the profile nor the flag provides one, **stop and ask** — the validation cannot proceed without code access.

Resolve `rbac_config_path` and `inventory_api_path`. If neither flag nor common locations exist, note the skipped dimensions and continue with what is available.

Create `{artifacts_dir}/validation/` if needed.

### Step 1 — Codebase analysis

Access the service's source code. Collect evidence for each validation dimension:

#### SDK and auth integration

| Signal | Where to look |
|---|---|
| Kessel SDK dependency | Manifest files: `pyproject.toml`, `go.mod`, `package.json`, `pom.xml`, `build.gradle` — look for `kessel-sdk`, `github.com/project-kessel/inventory-client-go`, etc. |
| SDK version | Same manifest files |
| `ClientBuilder` or equivalent | Kessel client initialization code |
| Auth mechanism | OAuth2 credentials setup (`OAuth2ClientCredentials`, service account env vars) |
| Namespace / reporter name | Kessel client config, app config, ClowdApp YAML |

#### Authorization call patterns

| Signal | Where to look |
|---|---|
| `Check` / single-resource checks | Request handlers, middleware, decorators |
| `CheckBulk` / `CheckForUpdate` | Same |
| `ListObjects` / `ListAllowedWorkspaces` / workspace pre-filter for LIST ops | Query/filter layers, middleware |
| `ReportResource` / inventory reporting calls | Outbox, event publisher, background workers |
| Permission constants / classes | Dedicated permission module (e.g. `app/auth/rbac.py`, `internal/authz/`) |

Map each permission class/constant found to: resource type, namespace, and the v2 permission name used.

#### Feature flag and dual-path strategy

| Signal | Where to look |
|---|---|
| Feature flag name and gating logic | Feature flag definitions, flag-checking functions |
| v1 RBAC bypass / fallback path | Condition that determines v1 vs v2 code path |
| `bypass_kessel` or equivalent | Config flags |

#### UI access checks

| Signal | Where to look |
|---|---|
| v1 RBAC route calls from UI layer | Grep for `/rbac/v1/access` in frontend code or middleware that serves UI requests |
| v2 workspace lookup for UI | Grep for `/rbac/v2/workspaces` |

#### Inventory reporting

| Signal | Where to look |
|---|---|
| `ReportResource` / inventory API calls | Search for Kessel inventory API client usage, outbox publishers, event producers |
| Resource references in reporting code | What `resource_type` and `reporter_type` are passed |

#### Ephemeral / Bonfire

| Signal | Where to look |
|---|---|
| Bonfire/ClowdApp config | `deploy/clowdapp.yml`, `bonfire.yaml`, `.clowdenv` |
| IQE test plugin | `iqe-*-plugin` directory |

### Step 2 — rbac-config analysis

If `rbac_config_path` is available:

1. **Find the service's KSL file**: look for `configs/stage/schemas/src/{namespace}.ksl` where namespace matches the service slug (hyphens → underscores) or a short alias. If ambiguous, check multiple candidates.

2. **Read the KSL file** in full.

3. **Find the permissions JSON**: `configs/stage/permissions/{app}.json` for each v1 app namespace in the profile's `v1_permissions.items`.

4. **Find the roles JSON**: `configs/stage/roles/{app}.json`.

5. **Check `migrated_apps.lst`**: `configs/stage/schemas/migrated_apps.lst` — is the app listed?

### Step 3 — inventory-api analysis

If `inventory_api_path` is available:

1. **Find the resource schema directories**: `data/schema/resources/` — look for directories matching the profile's `asset_types[]` (snake_case form).

2. **Read all files** in each matching directory: `config.yaml`, `common_representation.json`, `reporters/*/config.yaml`, `reporters/*/{type}.json`.

3. Note any asset types from the profile that have **no matching directory** — these are pending or not yet registered.

### Step 3.5 — Schema-design artifact analysis (when `schema_artifacts_path` is provided)

If `schema_artifacts_path` is set, load the draft files generated by the schema-design skill and prepare them for comparison in dimensions 13–16:

**rbac-config drafts** — read from `{schema_artifacts_path}/rbac-config/schemas/src/`:
- `{namespace}.ksl` — the generated KSL file

**rbac-config JSON drafts** — read from `{schema_artifacts_path}/rbac-config/`:
- `permissions/{app}.json` for each v1 app namespace
- `roles/{app}.json` for each v1 app namespace

**inventory-api resource schema drafts** — read from `{schema_artifacts_path}/inventory-api/`:
- `{asset_type}/config.yaml`, `{asset_type}/common_representation.json`
- `{asset_type}/reporters/{reporter_name}/config.yaml`, `{asset_type}/reporters/{reporter_name}/{asset_type}.json`

If any expected file is missing, record it as a schema-design gap in dimension 13–16 findings.

### Step 4 — Score each validation dimension

For each dimension, assign a status and collect evidence:

| Status | Meaning |
|---|---|
| ✅ Match | Interview data correctly predicted the implementation |
| ⚠️ Partial | Interview captured the intent but not all specifics |
| ❌ Miss | Interview did not capture something the implementation required |
| ➖ N/A | Not applicable for this service |
| ⏭️ Skipped | Could not access the required files/code |

#### Dimension 1: Tech stack and SDK

Compare `tech_stack.lang`, `tech_stack.framework`, `tech_stack.auth` from the profile against what the codebase actually uses.

#### Dimension 2: Adoption patterns → authorization call patterns

For each pattern in `patterns[]`, verify the service uses the expected Kessel API call pattern:

| Pattern | Expected call pattern |
|---|---|
| `native-ws-list` | `ListObjects` or workspace pre-filter (e.g. `ListAllowedWorkspaces`) for LIST ops; per-resource `Check` for single-resource ops |
| `native` | Per-resource `Check` or `CheckForUpdate` |
| `default-workspace` | `Check` against the default workspace ID |
| `root-workspace` | `Check` against the root workspace ID |
| `org-level` | Org-level permission check |

#### Dimension 3: V1 permissions → KSL declarations

For each permission in `v1_permissions.items`, check whether a matching declaration exists in the KSL file:

- `@rbac.add_v1_based_permission(app:'{app}', resource:'{resource}', verb:'{verb}', ...)` present?
- Is the v2 permission name used in service code (via permission constants) consistent with the KSL?

#### Dimension 4: Asset types → KSL type definitions

For each asset type in `asset_types[]`, check:
- If native/native-ws-list: `public type {asset_type}` present in KSL with `workspace` relation?
- If default/root/org: no custom type needed — permissions at namespace level?

#### Dimension 5: Permissions.json coverage

Compare `v1_permissions.items` against what is actually in `permissions/{app}.json`:
- All resources listed?
- All verbs present?
- Any additional permissions in the JSON not captured by the interview?

#### Dimension 6: Roles.json structure

Check whether roles exist and what permissions they bundle. Note any roles that go beyond the scaffold (admin/viewer) — these indicate product decisions the interview wouldn't predict.

#### Dimension 7: Resource schema (inventory-api)

For each asset type expected to have a resource schema (native/native-ws-list + `inventory_migration_required = true`):
- Does `data/schema/resources/{type}/` exist?
- Does `common_representation.json` require `workspace_id`?
- Is the reporter name in `reporters/` consistent with what the interview would derive?

#### Dimension 8: UI access checks

Compare `ui_access_checks` value from the profile against what the codebase shows:
- `required` — does the code actually have v1 RBAC route calls?
- `not_required` — confirmed no v1 UI access check calls?
- `new` — no existing v1 calls, but v2 checks are being built?
- `n/a` — truly no UI?

#### Dimension 9: Inventory migration

Compare `inventory_migration_required` against actual `ReportResource`/inventory API usage found in Step 1.

#### Dimension 10: Credential setup

Compare `credentials.service_account_status` against evidence of OAuth2 credentials, service account env vars, or OIDC configuration in the codebase.

#### Dimension 11: Feature flag strategy

Check whether the service has:
- A feature flag gating Kessel v2 vs v1 path
- What the flag is named (compare against convention `{service-slug}.kessel-check.enable`)
- Whether there is a bypass/fallback path to v1

#### Dimension 12: Ephemeral / Bonfire

Compare `ephemeral.uses_bonfire` against presence of ClowdApp config, IQE plugin, or Bonfire references.

---

### Schema-design dimensions (13–16) — only scored when `schema_artifacts_path` is provided

These dimensions compare the schema-design skill's **generated draft files** against the service's **real production files**. They score the schema-design skill's accuracy independently from the interview's accuracy.

Use the same status codes (✅ / ⚠️ / ❌ / ➖ / ⏭️). A ⏭️ on any of 13–16 means `schema_artifacts_path` was not provided — skip and note.

#### Dimension 13: Generated KSL vs real KSL

Compare the generated `{namespace}.ksl` against the real KSL file found in Step 2:

- **Namespace** — does the generated namespace match the real one?
- **Imports** — `import rbac` present? `import hbi` present when needed?
- **Permission declarations** — for each `@rbac.add_v1_based_permission(...)` in the real KSL, is there a matching declaration (same `app`, `resource`, `verb`, `v2_perm`) in the generated file? List any missing or extra declarations.
- **Type definitions** — if the real KSL has `public type {asset_type}`, did the generated file produce one? Do the relations (`workspace`, `tenant`, permission relations) match?
- **Extension patterns** — `add_contingent_permission`, `add_v1only_permission`, `expose_*_permission` — present in real but absent in generated?
- **Extension definitions** — if the real KSL defines a `public extension`, did the generated file include it?

Score: ✅ if all declarations and type structure match; ⚠️ if minor differences (e.g. ordering, v2 name variant); ❌ if significant structural or permission mismatches.

#### Dimension 14: Generated permissions.json vs real permissions.json

Compare each generated `permissions/{app}.json` against the real file for the same app namespace:

- All resources listed?
- All verbs present per resource?
- Any resources or verbs in the real file not in the generated file?
- Any extra resources or verbs in the generated file not in the real file?

Score: ✅ complete match; ⚠️ minor differences (extra wildcard, missing `*` verb); ❌ significant missing resources or verbs.

#### Dimension 15: Generated roles.json vs real roles.json

Compare each generated `roles/{app}.json` against the real file:

- Do the generated roles' permission sets cover the real roles' access lists?
- Are role names and `platform_default`/`admin_default` settings consistent?
- Note: generated roles are scaffolds (admin + viewer); real files often have additional product-specific roles — these are expected gaps, not errors.

Score: ✅ scaffold covers the real roles' permission surface; ⚠️ some real permissions not in any generated role; ❌ significant coverage gaps or wrong `platform_default` assignment.

#### Dimension 16: Generated resource schemas vs real resource schemas

For each asset type with a generated resource schema in `{schema_artifacts_path}/inventory-api/`:

- **config.yaml** — `resource_type` value matches real? Reporter name matches?
- **common_representation.json** — fields and `required` array match the real file?
- **reporter config.yaml** — `reporter_name` and `namespace` match?
- **reporter JSON Schema** — are the generated properties a reasonable subset/superset of the real schema? Note any fields in the real schema absent from the generated one (these are reporter-specific details the team would have provided in the Q&A).

Score: ✅ structure and required fields match; ⚠️ reporter-specific fields differ (expected — Q&A answers may vary); ❌ wrong resource_type, missing reporter, or incompatible common representation.

### Step 5 — Identify gaps

Gaps fall into three categories:

**Type A — Interview missed something the service needed**
The interview did not capture a requirement that turned out to be essential. These indicate potential improvements to the interview questions.

**Type B — Detail deferred correctly to Phase 2**
The interview captured the intent and scope correctly, but not the implementation specifics. These are expected — the interview is Phase 0/1 intake, not a design tool.

**Type C — Schema-design generation gap** *(only when `schema_artifacts_path` provided)*
The schema-design skill generated something incorrect, incomplete, or structurally different from the real schema. These indicate improvements needed in the schema-design skill or its reference material — not the interview skill.

For each gap found, classify it and document:
- What was missed or wrong
- Where the actual value was found (file, line, pattern)
- For Type A: whether the interview skill should be updated to capture it
- For Type C: whether the schema-design skill, its reference.md, or the Q&A flow should be improved

### Step 6 — Write validation report

Write `{artifacts_dir}/validation/{slug}-validation-report.md` using this structure:

```markdown
# Interview validation report: {service.name}

**Date:** {ISO date}
**Profile:** {profile path}
**Codebase:** {codebase_ref}
**rbac-config:** {rbac_config_path or "not analyzed"}
**inventory-api:** {inventory_api_path or "not analyzed"}
**Schema artifacts:** {schema_artifacts_path or "not provided — schema-design dimensions skipped"}

---

## Overall alignment

**Interview score: {X}/12 dimensions matched or partially matched**
**Schema-design score: {Y}/4 dimensions matched or partially matched** *(omit line if schema artifacts not provided)*

{2-3 sentence summary — did the interview data lead to the right outcomes? If schema artifacts provided, add one sentence on schema-design accuracy.}

---

## Interview accuracy (dimensions 1–12)

| # | Dimension | Status | Notes |
|---|---|---|---|
| 1 | Tech stack and SDK | {✅/⚠️/❌/➖/⏭️} | {one-line finding} |
| 2 | Adoption patterns → auth call patterns | {status} | |
| 3 | V1 permissions → KSL declarations | {status} | |
| 4 | Asset types → KSL type definitions | {status} | |
| 5 | Permissions.json coverage | {status} | |
| 6 | Roles.json structure | {status} | |
| 7 | Resource schema (inventory-api) | {status} | |
| 8 | UI access checks | {status} | |
| 9 | Inventory migration | {status} | |
| 10 | Credential setup | {status} | |
| 11 | Feature flag strategy | {status} | |
| 12 | Ephemeral / Bonfire | {status} | |

## Schema-design accuracy (dimensions 13–16)

*Omit this section entirely if `schema_artifacts_path` was not provided.*

| # | Dimension | Status | Notes |
|---|---|---|---|
| 13 | Generated KSL vs real KSL | {✅/⚠️/❌/⏭️} | {one-line finding} |
| 14 | Generated permissions.json vs real | {status} | |
| 15 | Generated roles.json vs real | {status} | |
| 16 | Generated resource schemas vs real | {status} | |

---

## Detail findings

### Dimension 1: Tech stack and SDK

{Evidence from codebase vs interview profile — include file references}

### Dimension 2: Adoption patterns → auth call patterns

{For each pattern: what the interview suggested, what the code does, verdict}

{... repeat for all 12 interview dimensions ...}

### Dimension 13: Generated KSL vs real KSL

{Side-by-side comparison of key KSL constructs — namespace, imports, types, permission declarations, extensions}

{... repeat for dimensions 14–16 ...}

---

## Gaps

### Type A — Interview missed something (potential interview skill improvements)

{numbered list: what was missed, where found, recommendation}

### Type B — Detail correctly deferred to Phase 2

{numbered list: what was deferred, why it's expected}

### Type C — Schema-design generation gap (potential schema-design skill improvements)

*Omit this section if schema artifacts were not provided.*

{numbered list: what the generated schema got wrong, what the real schema has, recommendation for improving the skill}

---

## Recommendations for interview skill

{Only if Type A gaps exist}

{Concrete, actionable suggestions — e.g. "Add a question about write-verb splitting", "Ask for the reporter short name during the interview"}

---

## Validation coverage

{Note any dimensions skipped due to missing access, and what would be needed to complete them}

*Validated by: onboarding-validate-interview skill*
*Sources: {list of files/paths read}*
```

### Step 7 — Present summary

Show the EM/tech lead:
1. The dimension scorecard table
2. Count of Type A gaps (potential interview improvements) vs Type B (expected deferrals)
3. Path to the full report
4. Any skipped dimensions

## Outputs

| Output | Path |
|--------|------|
| Validation report | `{artifacts_dir}/validation/{slug}-validation-report.md` |

## MCP policy

| Tool | Allowed |
|------|---------|
| `search_issues` / `get_issue` | No (not needed) |
| `create_issue` / `update_issue` | **No** |
| File reads (codebase, rbac-config, inventory-api) | Yes |
| File writes (report only) | Yes |

## Usage pattern

This skill is meant to be run after a team has completed Phase 4 or later (PoC or beyond), when there is enough real implementation to compare against. Running it earlier may produce misleading results if the service's Kessel integration is incomplete.

Ideal validation points:
- After Phase 4 (PoC) — SDK integration and authorization call patterns are established
- After Phase 7 (Prod enabled) — full picture including feature flags, roles, UI migration

Can also be run retroactively against already-migrated services (like HBI) to calibrate the interview skill baseline.

## Changelog

- 2026-07: Initial version. Modeled on the manual HBI validation performed during the interview skill test run.

Assisted-by: Claude (Anthropic)
