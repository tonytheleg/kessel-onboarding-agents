---
name: onboarding-provision-jira
description: >
  Builds and (after EM dry-run approval) creates the Jira issue batch for a
  Kessel service onboarding: Provider Initiative in CRCPLAN, Service Epic in
  RHCLOUD, Phase Stories 0–7 in RHCLOUD, and an optional UI Story. Returns a
  key map of created issues. Used by onboarding-provisioner agent.
---

# Onboarding provision Jira

## When to use

- Called by the `onboarding-provisioner` agent via `/kessel-onboarding:provision`, once an EM-approved handoff block exists (produced by `onboarding-format-handoff`).
- Always run with `dry_run = true` first to review the proposed issue batch before creating anything in Jira; only re-run with `dry_run = false` after the EM approves the dry-run table.

## Configuration

Read `~/.config/kessel-onboarding/config.json`:

| Key | Used for |
|-----|---------|
| `jira_cloud_id` | All MCP calls |
| `initiative_project` | Provider Initiative project (CRCPLAN) |
| `onboarding_project` | Epic + Stories project (RHCLOUD) |
| `onboarding_label` | Label on every created issue |
| `mcp_server_name` | The Atlassian MCP server used for create/update/link calls |
| `team_field_id` | Jira custom field ID for the Team field. Default documented in `docs/configuration.md`. |
| `team_field_value` | Team field value — UUID for Console - Kessel (formerly "Fabric - Kessel"). Default documented in `docs/configuration.md`. |

## Inputs

| Input | Required | Notes |
|-------|----------|-------|
| ServiceProfile JSON object | yes | Loaded by orchestrator |
| Handoff block | yes | For `approved_by`, `em_notes` |
| `dry_run` | yes | `true` = table only; `false` = create |

## Execution

### Step 1 — Resolve dedup routing

Read `dedup.status` from profile:

| Status | Action |
|--------|--------|
| `clean` | Build Initiative + Epic + Stories |
| `reuse_initiative` | Skip Initiative; find existing key from `dedup.matches[]` where `type = provider_initiative`; use as parent |
| `duplicate_found` | **Stop** — return error; orchestrator handles |

### Step 2 — Build issue batch

Construct proposed issues in creation order. Do not create yet.

#### Issue 1 — Provider Initiative (CRCPLAN, skip if `reuse_initiative`)

```
Project:     {initiative_project}
Type:        Initiative
Summary:     [Kessel Onboarding] {provider.name}
Labels:      {onboarding_label}
Description: (see below)
```

Initiative description block — render as ADF with `heading` + `bulletList` (never one paragraph dump):

```
## Overview
Kessel onboarding program tracking for {provider.name}.

## Contacts
- PM: {contacts.pm.name} <{contacts.pm.email}>
- EM: {contacts.em.name} <{contacts.em.email}>

## Services in scope
- {service.name} (wave {program.wave})
```

#### Issue 2 — Service onboarding Epic (RHCLOUD)

```
Project:     {onboarding_project}
Type:        Epic
Summary:     [Kessel Onboarding] {service.name}
Parent field: Initiative key (created above or reused)
Labels:      {onboarding_label}, kessel-phase-scheme:v1, kessel-pattern:{primary pattern id} (one label for the primary pattern; add one per pattern if multiple)
Team:        {team_field_id} = {team_field_value}  (Team: Console - Kessel — Jira's Team field accepts only the team UUID, never the display name)
Description: (see below)
```

Epic description block — **must** render as structured ADF (see [ADF structure rules](#adf-structure-rules)). Do not submit as a single paragraph or concatenated plain-text block.

```
## Overview
- Service: {service.name}
- Provider: {provider.name}
- Wave: {program.wave}
- Path: {program.path}

## Adoption pattern(s)
{for each pattern:}
- {label} ({confidence}) — {rationale}
  {nested bullet, only when patterns.length > 1: Applies to: {pattern.asset_types[] joined by ", "}}

## Integration surface
- Language: {tech_stack.lang}
- Framework: {tech_stack.framework}
- Auth today: {tech_stack.auth}

## Credentials readiness
- CMDB registered: {credentials.cmdb_registered}
- Service account (CIAM): {credentials.service_account_status}
{- Notes: {credentials.notes}  — omit this bullet when notes are empty}

## Scope
- UI access checks: {ui_access_checks}
- Inventory reporting today: {inventory_reporting}
- Inventory migration required: {inventory_migration_required}
- Asset types: {comma-separated asset_types[] or "none listed"}
- V1 permissions: {v1_permissions.summary} ({v1_permissions.source})
{- V1 permission items: one nested bullet per item in v1_permissions.items — omit when empty}
- Feature epic: {jira.feature_epic_key or "none — EM waived"} (relates to)
- Pre-dev tooling: Ephemeral/Bonfire
  {or, when ephemeral.uses_bonfire is false: Pre-dev tooling: {ephemeral.pre_dev_tooling}}
{- Target stage: {targets.stage} — omit when null}
{- Target prod: {targets.prod} — omit when null}

## Contacts
- PM: {contacts.pm.name} <{contacts.pm.email}>
- EM: {contacts.em.name} <{contacts.em.email}>
- Tech lead: {contacts.tech_lead.name} <{contacts.tech_lead.email}>

## Approval
- Approved by: {approved_by}
- EM notes: {em_notes or "none"}
```

#### Issues 3–11 — Phase Stories (RHCLOUD)

Create nine phase stories (Phase 3 is conditional — only when `inventory_migration_required` is `true`). For each story, apply both the global label and its **stable slug-based** phase label (see `context/jira-field-mapping.md`). The slug is the permanent identity used for filtering; the "Phase N" number is cosmetic display text only and may change without relabeling existing issues.

| # | Phase (display) | Summary | Phase label (stable slug) | Key map key |
|---|------------------|---------|----------------------------|-------------|
| 3 | 0 | `Phase 0: Kickoff — {service.name}` | `kessel-phase:kickoff` | `kickoff` |
| 4 | 1 | `Phase 1: Identify adoption pattern(s) — {service.name}` | `kessel-phase:adoption-pattern` | `adoption_pattern` |
| 5 | 2 | `Phase 2: Model permissions and schema — {service.name}` | `kessel-phase:permissions-schema` | `permissions_schema` |
| 6 | 3 *(cond.)* | `Phase 3: Inventory migration — {service.name}` | `kessel-phase:inventory-migration` | `inventory_migration` |
| 7 | 4 | `Phase 4: PoC — {service.name}` | `kessel-phase:poc` | `poc` |
| 8 | 5 | `Phase 5: Verified in dev environment — {service.name}` | `kessel-phase:dev-verified` | `dev_verified` |
| 9 | 6a | `Phase 6a: Enabled and verified in stage — {service.name}` | `kessel-phase:stage-enabled` | `stage_enabled` |
| 10 | 6b | `Phase 6b: Feature flag and dual-path audit — {service.name}` | `kessel-phase:ff-audit` | `ff_audit` |
| 11 | 7 | `Phase 7: Enabled and verified in prod — {service.name}` | `kessel-phase:prod-enabled` | `prod_enabled` |

**Key map key** is the JSON field name used in the returned key map (Step 5). Using stable slugs here too means anything reading the key map never breaks if the display numbering changes.

For each story:

```
Project:    {onboarding_project}
Type:       Story
Parent field (legacy name: Epic Link): Service Epic key
Labels:     {onboarding_label}, {phase_label}
Team:       {team_field_id} = {team_field_value}
Description: Done-when criteria from context/phase-checklist.md for this phase.
             Use ADF format (not plain text). See description bodies below.
             If jira-issue-templates.md is available (canonical), use that instead.
```

#### Issue 12 — Conditional UI Story (RHCLOUD, only when `ui_access_checks` is `required` or `new`)

Two variants — same trigger family, different summary/description:

```
Project:    {onboarding_project}
Type:       Story
Summary:    UI: Migrate v1 access checks — {service.name}          [ui_access_checks = required]
            UI: Implement v2 access checks — {service.name}        [ui_access_checks = new]
Parent field (legacy name: Epic Link): Service Epic key
Labels:     {onboarding_label}, kessel-phase:ui-migration            (same slug for both variants)
Team:       {team_field_id} = {team_field_value}
Description (required): Migrate UI v1 /rbac/v1/access calls to Kessel SDK or v2 patterns for {service.name}.
             Must be Done before Prod enabled (Phase 7).
Description (new): Implement Kessel v2 access checks in the UI for {service.name} — there are no existing
             v1 UI checks to migrate; this is net-new UI-layer access gating.
             Must be Done before Prod enabled (Phase 7).
             Use ADF format (not plain text) for either variant.
```

### Step 3 — Dry-run output (when `dry_run = true`)

Present table to orchestrator:

```
Proposed Jira issue batch — {service.name}
DRY RUN — no issues created

#  | Type        | Project  | Summary                                              | Parent field / Link
---|-------------|----------|------------------------------------------------------|--------------
1  | Initiative  | CRCPLAN  | [Kessel Onboarding] {provider.name}                  | —
2  | Epic        | RHCLOUD  | [Kessel Onboarding] {service.name}                   | Parent field → #1
3  | Story       | RHCLOUD  | Phase 0: Kickoff — {service.name}                    | Epic → #2
4  | Story       | RHCLOUD  | Phase 1: Identify adoption pattern(s) — {service.name} | Epic → #2
5  | Story       | RHCLOUD  | Phase 2: Model permissions and schema — {service.name} | Epic → #2
6  | Story       | RHCLOUD  | Phase 3: Inventory migration — {service.name}        | Epic → #2  [only if inventory_migration_required = true]
7  | Story       | RHCLOUD  | Phase 4: PoC — {service.name}                        | Epic → #2
8  | Story       | RHCLOUD  | Phase 5: Verified in dev environment — {service.name} | Epic → #2
9  | Story       | RHCLOUD  | Phase 6a: Enabled and verified in stage — {service.name} | Epic → #2
10 | Story       | RHCLOUD  | Phase 6b: Feature flag and dual-path audit — {service.name} | Epic → #2
11 | Story       | RHCLOUD  | Phase 7: Enabled and verified in prod — {service.name} | Epic → #2
12 | Story       | RHCLOUD  | UI: Migrate v1 access checks — {service.name}        | Epic → #2  [only if ui_access_checks = required; use "UI: Implement v2 access checks — {service.name}" if ui_access_checks = new]
```

Note if `reuse_initiative`: mark Initiative row as `REUSE — {existing_key}`.

Return table to orchestrator. Stop here if `dry_run = true`.

After presenting the dry-run table, read `context/implementation-topics.json` and offer 3–5 relevant follow-up implementation topics (see `CLAUDE.md` for the selection and presentation pattern). Good candidates at this stage: `service-account`, `sdk-setup`, `env-vars`, `dual-path`.

### Step 4 — Create issues (when `dry_run = false`)

Create in order. Capture returned key after each create before proceeding.

**Validate before first live run:** confirm cross-project parenting (RHCLOUD Epic → CRCPLAN Initiative) is enabled in this Jira instance by manually parenting one test pair, or confirm with the Jira admin. If unsupported, fall back to a "relates to" link plus Initiative description reference, and record the limitation in the run summary. Do not assert that cross-project parenting works; it is unverified.

**Sequence:**

1. Create Initiative (CRCPLAN) if `dedup.status = clean`. Capture `initiative_key`.
2. Set `epic_parent_key` = `initiative_key` (clean) or existing key (reuse_initiative).
3. Create Epic (RHCLOUD) with parent = `epic_parent_key`. Capture `epic_key`.
   - Set `{team_field_id} = {team_field_value}` (Team: Console - Kessel — Jira's Team field accepts only the team UUID, never the display name) on create or immediately after via `update_issue`.
   - Use ADF for description content per [ADF structure rules](#adf-structure-rules) (`heading` + `bulletList` sections — never a single paragraph).
4. Add **relates to** link: Epic → `jira.feature_epic_key` (if present). Use `link_issues`.
5. Create Phase Stories in order (Phase 0 → Phase 7). Capture each key.
   - Set `{team_field_id} = {team_field_value}` on each story.
   - Use ADF for description content (done-when checklist as `bulletList` nodes).
6. Create UI Story if applicable. Capture key.
   - Set `{team_field_id} = {team_field_value}` on UI story.

**Team field note:** `{team_field_id}` (Atlassian Team type) accepts a bare UUID string, not an object: `{"{team_field_id}": "{team_field_value}"}`. Values come from `~/.config/kessel-onboarding/config.json` (defaults documented in `docs/configuration.md`).

**Description format note:** All RHCLOUD descriptions must be submitted as ADF (`contentFormat: "adf"` or via direct REST API PUT), not plain markdown. Plain text will render markdown syntax literally in Jira.

### ADF structure rules

Convert every Initiative, Epic, and Story description using these node types. The goal is a scannable Jira page — not a wall of text.

| Source in template | ADF node | Rules |
|--------------------|----------|-------|
| `## Heading` | `heading` level 2 | One heading per section; never bold-paragraph fake headings |
| `- item` | `bulletList` → `listItem` → `paragraph` | One fact per bullet; label then value (`Language: Go`) |
| Nested bullets under a parent | nested `bulletList` inside the parent `listItem` | Use for `v1_permissions.items`, and for `pattern.asset_types[]` when `patterns.length > 1` |
| Done-when checklist (phase stories) | `bulletList` | Same as phase checklist items |
| Blank lines between sections | separate top-level nodes | Do not merge sections into one `paragraph` |

**Hard rules:**

1. Never put the entire Epic (or Initiative) description in a single `paragraph`.
2. Never concatenate labeled facts into one prose sentence (wrong: `Tech stack: Go, Quarkus, SDK`). Use one bullet per field under the section heading.
3. Omit bullets for null / empty optional fields (`credentials.notes`, `targets.*`, permission items) rather than writing `none` or `n/a` unless the template explicitly says to show `"none"`.
4. Initiative and Epic share the same heading + bullet pattern; Stories use heading optional + bullet checklist for done-when criteria.

If a create call fails:

- Log the failure with error message.
- Continue creating remaining issues (do not abort the batch).
- Return failure list to orchestrator for Gate 1 handling.

### Step 5 — Return key map

```json
{
  "initiative_key": "CRCPLAN-XXX",
  "epic_key": "RHCLOUD-XXX",
  "story_keys": {
    "kickoff": "RHCLOUD-XXX",
    "adoption_pattern": "RHCLOUD-XXX",
    "permissions_schema": "RHCLOUD-XXX",
    "poc": "RHCLOUD-XXX",
    "dev_verified": "RHCLOUD-XXX",
    "stage_enabled": "RHCLOUD-XXX",
    "ff_audit": "RHCLOUD-XXX",
    "prod_enabled": "RHCLOUD-XXX"
    // inventory_migration and ui_migration appear only when their conditional stories were created
  },
  "failures": [],
  "reused_initiative": false
}
```

`story_keys` uses the same stable slugs as the phase labels (not "phase_0", "phase_1", etc.) so this key map — and everything downstream that reads it — stays valid even if the display phase numbering changes later.

`inventory_migration` and `ui_migration` keys are omitted entirely from `story_keys` when their conditional stories were not created. Consumers must treat a missing key as "story does not exist", not as an error.

Return key map and failure list to orchestrator.

## MCP tools

| Tool | MCP server | Use |
|------|-----------|-----|
| `create_issue` | the Atlassian MCP server named in config `mcp_server_name` | Create Initiative (CRCPLAN), Epic, Stories (RHCLOUD) |
| `update_issue` | the Atlassian MCP server named in config `mcp_server_name` | Set parent field (legacy name: Epic Link) after create |
| `link_issues` | the Atlassian MCP server named in config `mcp_server_name` | relates-to (feature epic) only |
| `get_issue` | the Atlassian MCP server named in config `mcp_server_name` | Validate reuse_initiative key before parenting |
| `search_issues` | the Atlassian MCP server named in config `mcp_server_name` | Not used here — dedup already run by Interview Agent |
| Jira REST API (direct) | n/a | Set the Team field (config `team_field_id` = `team_field_value`) and submit ADF descriptions — `update_issue` does not support custom fields or ADF; use `PUT /rest/api/3/issue/{key}` with credentials from `.env` |

## Outputs

- Dry-run table (console, `dry_run = true`)
- Key map JSON (`dry_run = false`)
- Failure list JSON

## Changelog

- 2026-08: Dry-run output step now offers 3–5 contextually relevant follow-up implementation topics from `context/implementation-topics.json` after presenting the issue table, prompting users to consider next steps (service account setup, SDK setup, env vars, etc.).
- 2026-07: Added the `new` UI story variant (`UI: Implement v2 access checks`, triggered alongside `required` under the same `kessel-phase:ui-migration` label) and per-pattern `asset_types[]` nested bullets in the Epic description for multi-pattern services.
- 2026-07: Restructured Epic (and Initiative) descriptions into heading + bullet sections for scannability; added credentials, inventory, asset types, v1 permissions, pre-dev tooling, and targets; documented ADF structure rules so provision no longer dumps a single text block.
- 2026-07: Removed the "Platform gates" section from the Epic description, the Phase 3 "Blocked by" gate text, and the UI story "Blocked by platform readiness" text — these referenced the now-removed `onboarding-link-platform-gates` skill, which never had a populated Jira key to actually link against.
- 2026-07: Renamed Team field references from "Fabric - Kessel" to "Console - Kessel" (team display name changed; UUID unchanged).
- 2026-07: Changed the Phase 3 condition to `inventory_migration_required = true`; single-sourced the Team field via config `team_field_id`/`team_field_value`; added the cross-project parenting validation note; standardized on "parent field (legacy name: Epic Link)"; added `kessel-pattern:{id}` label; omitted conditional keys from the key map example; referenced the connected Atlassian MCP server via config.

Assisted-by: Claude (Anthropic)
