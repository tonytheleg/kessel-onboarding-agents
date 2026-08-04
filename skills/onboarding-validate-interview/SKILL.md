---
name: onboarding-validate-interview
description: >
  Validates the accuracy of a completed onboarding interview by comparing its
  ServiceProfile against a service's actual Kessel implementation — source code,
  resource schemas (inventory-api), and permissions schemas (rbac-config). Produces
  a structured alignment report that scores the interview's findings and identifies
  gaps, used to refine the interview skill over time.
---

# Onboarding interview validation

## When to use

- After Phase 4 (PoC) or later, once a service has a real Kessel implementation to compare against — running it earlier can produce misleading results.
- Retroactively against already-migrated services (e.g. HBI) to establish a baseline for how accurately the interview skill predicts implementation needs, and to surface concrete improvements to the interview questions.

## What this skill does

Takes a completed ServiceProfile from the interview skill alongside a live service implementation and answers: **did the interview correctly anticipate what the team actually needed to build?**

Validates across four dimensions:

1. **Implementation** — SDK integration, authorization call patterns, feature flag strategy, UI migration, inventory reporting, credential setup, ephemeral tooling
2. **KSL schema** — namespace, type definitions, permission declarations, extension patterns
3. **Permissions and roles** — `permissions.json` and `roles.json` coverage and accuracy
4. **Resource schema** — inventory-api directory structure, common and reporter-specific JSON Schemas

Produces a structured report at `artifacts/validation/{slug}-validation-report.md`.

## Inputs

| Input | Required | Source |
|-------|----------|--------|
| ServiceProfile JSON path | yes | Interview output or `--profile` flag |
| `codebase_ref` | yes | Service source repo — GitHub/GitLab URL or local path |
| `rbac_config_path` | no | Local path to rbac-config repo root. If omitted, checks common locations: `~/dev/rbac-config`, `../rbac-config` |
| `inventory_api_path` | no | Local path to inventory-api repo root. If omitted, checks common locations: `~/go/src/github.com/*/inventory-api`, `../inventory-api` |

All four pieces of input are needed for a complete validation. If `rbac_config_path` or `inventory_api_path` cannot be resolved, the skill validates the dimensions it can reach and notes what was skipped.

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

### Step 5 — Identify gaps

Gaps fall into two categories:

**Type A — Interview missed something the service needed**
The interview did not capture a requirement that turned out to be essential. These indicate potential improvements to the interview questions.

**Type B — Detail deferred correctly to Phase 2**
The interview captured the intent and scope correctly, but not the implementation specifics. These are expected — the interview is Phase 0/1 intake, not a design tool.

For each gap found, classify it as Type A or Type B and document:
- What was missed
- Where the actual value was found (file, line, pattern)
- Whether the interview skill should be updated to capture it (Type A only)

### Step 6 — Write validation report

Write `{artifacts_dir}/validation/{slug}-validation-report.md` using this structure:

```markdown
# Interview validation report: {service.name}

**Date:** {ISO date}
**Profile:** {profile path}
**Codebase:** {codebase_ref}
**rbac-config:** {rbac_config_path or "not analyzed"}
**inventory-api:** {inventory_api_path or "not analyzed"}

---

## Overall alignment

**Score: {X}/12 dimensions matched or partially matched**

{2-3 sentence summary of the overall finding — did the interview data lead to the right outcomes?}

---

## Dimension-by-dimension results

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

---

## Detail findings

### Dimension 1: Tech stack and SDK

{Evidence from codebase vs interview profile — include file references}

### Dimension 2: Adoption patterns → auth call patterns

{For each pattern: what the interview suggested, what the code does, verdict}

{... repeat for all 12 dimensions ...}

---

## Gaps

### Type A — Interview missed something (potential skill improvements)

{numbered list: what was missed, where found, recommendation}

### Type B — Detail correctly deferred to Phase 2

{numbered list: what was deferred, why it's expected}

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
