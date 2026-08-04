# ServiceProfile schema and interview reference

## ServiceProfile JSON schema (v1.3)

All fields unless noted are required before handoff.

| Field | Type | Description |
|-------|------|-------------|
| `schema_version` | string | `"1.0"`, `"1.1"`, `"1.2"`, or `"1.3"`. Each version's new fields are optional/additive; treat them as null (or, for `patterns[].asset_types`, absent) when the profile predates that version. 1.1 added `credentials.*`, `targets.*`, `inventory_migration_required`, `docs_gaps`. 1.2 added the `new` `ui_access_checks` value and `patterns[].asset_types`. 1.3 added `interview.codebase_ref`. |
| `provider.name` | string | Provider / tenant name |
| `service.name` | string | Deployable service name |
| `service.slug` | string | kebab-case filename slug |
| `jira.home_project` | string | Service team's own Jira project key (e.g. TUSC, RHINENG). Used for feature epic lookup and dedup only — Provisioner creates onboarding issues in CRCPLAN / RHCLOUD, not here |
| `jira.feature_epic_key` | string | Existing feature epic in `home_project` — linked via **relates to** from the RHCLOUD onboarding Epic |
| `jira.label` | string | Default `kessel-onboarding` |
| `program.wave` | number | 1 (already integrating), 2 (current cohort), or 3 (future cycle) |
| `program.path` | string | `self-service` or `paired` (set by suggest-patterns) |
| `contacts.pm` | object | `{ name, email }` |
| `contacts.em` | object | `{ name, email }` |
| `contacts.tech_lead` | object | `{ name, email }` |
| `kickoff.docs_reviewed` | boolean | Phase 0 criterion |
| `credentials.cmdb_registered` | enum | `yes`, `no`, `unknown` — application has a CMDB entry with a valid Application ID |
| `credentials.service_account_status` | enum | `none`, `requested`, `stage_only`, `stage_and_prod` — CIAM service account provisioning state |
| `credentials.notes` | string | Optional freeform (e.g. request ticket link) |
| `ui_access_checks` | enum | `required`, `new` (schema 1.2+), `not_required`, `n/a` — see [UI access checks](#ui-access-checks-how-to-choose) |
| `tech_stack.lang` | string | Primary language |
| `tech_stack.framework` | string | Framework (optional) |
| `tech_stack.auth` | string | Auth integration (e.g. Kessel SDK) |
| `asset_types` | string[] | Resource / asset type names |
| `v1_permissions.source` | enum | `paste` or `repo_path` |
| `v1_permissions.summary` | string | Short description |
| `v1_permissions.items` | string[] | Permission identifiers |
| `inventory_reporting` | boolean | Reports inventory to Kessel today (informational current-state only) |
| `inventory_migration_required` | boolean | True when the service has resources that must be migrated or ingested into Kessel inventory (batch migration and/or ongoing sync). This is the field the Provisioner reads to create the Phase 3 story. `inventory_reporting` is informational current-state only. |
| `ephemeral.uses_bonfire` | boolean | Team uses Ephemeral/Bonfire for pre-dev testing |
| `ephemeral.pre_dev_tooling` | string | What the team uses for pre-dev testing when `uses_bonfire` is false; omit when true |
| `targets.stage` | ISO date | Optional target for stage enablement |
| `targets.prod` | ISO date | Optional target for prod enablement |
| `patterns` | array | Filled by suggest-patterns skill |
| `platform_gates` | array | Filled by suggest-patterns skill |
| `dedup` | object | Filled by dedup-epic skill |
| `interview.conducted_at` | ISO-8601 | Session timestamp |
| `interview.participants` | string[] | Names |
| `interview.transcript_ref` | string | Optional doc URL or path |
| `interview.codebase_ref` | string | Optional (schema 1.3+) — GitHub/GitLab URL, local path, or archive path to the service's repo, if shared during intake for analysis. Null when not provided. |
| `docs_gaps` | array | Questions raised during intake that could not be answered from KesselDocs or internal docs. Each entry: `{ "question": string, "context": string, "phase": string, "suggested_location": string }`. Optional; empty array when none. |

### Pattern object

```json
{
  "id": "default-workspace",
  "label": "Default workspace",
  "confidence": "high",
  "rationale": "Why this pattern fits",
  "guide_anchor": "/building-with-kessel/how-to/migrate-from-rbac-v1-to-v2/#identify-the-patterns",
  "asset_types": ["activation_key"]
}
```

`confidence`: `high`, `medium`, `low`.

`asset_types` (schema 1.2+): the subset of the profile's `asset_types[]` that use this pattern. Required whenever `patterns[]` has more than one entry — every asset type in the profile must appear under exactly one pattern's `asset_types[]`. For a single-pattern service, list all of `asset_types[]` here for consistency (optional but recommended). Absent on profiles written before 1.2 — treat as "applies to all of the profile's `asset_types[]`" when reading an older single-pattern profile.

### Platform gate object

```json
{
  "pattern_id": "default-workspace",
  "epic_summary": "Platform Readiness: Default workspace",
  "jira_key": "RHCLOUD-XXXX",
  "status": "ready"
}
```

### Dedup object

```json
{
  "status": "clean",
  "notes": "",
  "matches": [
    {
      "type": "service_epic",
      "key": "TUSC-123",
      "summary": "[Kessel Onboarding] Activation Keys",
      "action": "stop"
    }
  ]
}
```

`status`: `clean`, `reuse_initiative`, `duplicate_found`.

## Full example

See [examples/activation-keys-profile.json](../../examples/activation-keys-profile.json).

## Question script

### Phase 0 — Kickoff

| Field | Question |
|-------|----------|
| `provider.name` | What is the provider / tenant name (e.g. Subscription Management)? |
| `service.name` | What is the deployable service name (one epic per service)? |
| `jira.home_project` | What Jira project key owns this service (RHINENG, TUSC, …)? This is the service team's tracking project — onboarding issues will be created separately in CRCPLAN / RHCLOUD. |
| `jira.feature_epic_key` | What is the existing feature epic key to link (relates to)? |
| `interview.codebase_ref` | Do you have a link to the service's repo (GitHub/GitLab URL), a local path, or an archive I can look at? This lets me draft answers for UI access checks, tech stack, asset types, and v1 permissions for you to confirm rather than dictating from scratch. Optional — skip if nothing to share. |
| `program.wave` | Kessel onboards services in waves — batches of teams migrating on a rough timeline, not a hard deadline. Which best fits your team? (1) Already integrating — started or finished early phases before this intake existed. (2) Current wave — onboarding now, as part of today's active batch (default if unsure). (3) Future wave — planned, but not yet started. |
| `contacts` | PM, EM, and tech lead names and emails? |
| `kickoff.docs_reviewed` | Has the team reviewed the onboarding checklist and migration guide? |
| `credentials.cmdb_registered` | Is your application registered in CMDB with a valid Application ID? (Required before CIAM will provision a service account.) |
| `credentials.service_account_status` | Have you provisioned a Kessel service account through the CIAM process? Answer for both stage and prod. (None / Requested / Stage only / Stage and prod) |

**Why this is asked at kickoff:** service account provisioning involves external teams (CMDB, CIAM) with approval lead times measured in weeks, and separate client definitions are required for stage and prod. Starting at Phase 0 prevents a credential stall at Phase 4–6a. Full walkthrough: Kessel internal docs, "Service Account and Credentials Setup" (Using Kessel → Prerequisites, on InScope).

| Field | Question |
|-------|----------|
| `ui_access_checks` | Does your UI call `/rbac/v1/access` today, or do you need new v2 access checks built in the UI for the first time? **Required** if the UI already calls v1 access-check APIs; **New** if there's no existing v1 UI check but you want Kessel v2 checks built fresh; **Not required** if the UI exists but uses entitlements, backend-only auth, or no access gating; **N/A** if there is no user-facing UI. |

### UI access checks: how to choose

This question is about **v1 access check API calls in the UI layer**, not about whether the service has a UI or does any access control at all.

| Answer | Choose when… |
|--------|--------------|
| **Required** | The UI calls `/rbac/v1/access` (or equivalent v1 access-check APIs) today and those calls need migration to Kessel. |
| **New** | The UI has **no existing v1 access checks** (net-new service, or previously unguarded/entitlements-only UI) but the team wants Kessel v2 checks implemented in the UI from scratch. Nothing to migrate — greenfield, not a port. |
| **Not required** | The service may have a UI, but the UI does **not** call `/rbac/v1/access`, and no net-new UI checks are needed either. Common cases: access enforced only in the API/backend; UI uses **entitlements** or other non–v1-access mechanisms; UI has no access-gating logic (shows/hides based on what the API returns). |
| **N/A** | The deployable has **no user-facing UI** (API/backend-only). |

**Required** and **New** both add a conditional UI story (different summary text — see `context/phase-checklist.md`). Backend auth migration is covered by the standard phase stories regardless of this answer.

| Field | Question |
|-------|----------|
| `tech_stack` | Language, framework, and how the service calls auth today? |
| `asset_types[]` | What resource / asset types are in scope? |
| `v1_permissions` | Paste permissions or give rbac-config path |
| `inventory_reporting` | Does your service currently report resources to Kessel inventory? |
| `inventory_migration_required` | Does your service have resources (hosts, systems, assets) that need to be migrated or ingested into Kessel inventory before prod enablement — via batch migration, ongoing sync, or both? |
| `ephemeral.uses_bonfire` | Do you use Ephemeral/Bonfire for pre-dev testing? |
| `ephemeral.pre_dev_tooling` | If no: What do you use for pre-dev testing? |
| `targets` | Optional target stage/prod dates |

## Slug generation

Lowercase `service.name`, replace spaces with hyphens, strip non-alphanumeric except hyphens.

Example: `Activation Keys` → `activation-keys`.

## Narrative summary template

Write `{artifacts_dir}/profiles/{slug}-summary.md`:

```markdown
# Service profile: {service.name}

**Provider:** {provider.name}
**Wave:** {program.wave}
**Home project:** {jira.home_project}
**Feature epic:** {jira.feature_epic_key}
**Codebase reference:** {interview.codebase_ref or none}

## Contacts

- PM: {pm}
- EM: {em}
- Tech lead: {tech_lead}

## Phase 0

- Docs reviewed: {yes/no}
- CMDB registered: {value}
- Service account: {value}
- UI access checks: {ui_access_checks}

## Phase 1 inputs

- Tech stack: {lang}, {framework}, {auth}
- Asset types: {list}
- v1 permissions: {summary}
- Inventory reporting: {yes/no}
- Inventory migration required: {yes/no}
- Ephemeral/Bonfire: {yes/no}
- Pre-dev testing (if not Bonfire): {pre_dev_tooling or n/a}
- Targets: stage {targets.stage or none}, prod {targets.prod or none}

## Notes

{freeform from interview}

## Docs gaps captured

{one bullet per docs_gaps entry, or "None"}
```

Append `(confirmed from repo analysis)` after any of the Phase 1 inputs lines above whose value was drafted from `codebase_ref` and confirmed (or corrected) rather than answered cold.

## Changelog

- 2026-07: Bumped schema to v1.3 — added `interview.codebase_ref` (optional repo URL/path/archive shared during intake) and the "confirmed from repo analysis" narrative summary marker for fields drafted from repo analysis in Step 1.5.
- 2026-07: Bumped schema to v1.2 — the `new` `ui_access_checks` value and `patterns[].asset_types` (both added below) are the 1.2 additions. 1.0/1.1 profiles remain valid; absent fields are treated as null (or "applies to all asset types" for a missing `patterns[].asset_types`).
- 2026-07: Added `new` as a fourth `ui_access_checks` value (net-new v2 UI checks, nothing to migrate) and added `asset_types[]` to the Pattern object so multi-pattern services map each asset type to exactly one pattern.
- 2026-07: Bumped schema to v1.1; added `inventory_migration_required`, `credentials.*`, `targets.*`, and `docs_gaps` fields, questions, and narrative summary lines.
- 2026-07: Clarified the `program.wave` question — defined "wave" before asking, added a default-if-unsure hint, and stated the concrete downstream consequence.

Assisted-by: Claude (Anthropic)
