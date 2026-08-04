---
name: onboarding-interview-conduct
description: >
  Runs structured Kessel onboarding intake (Phase 0/1): provider, service, Jira
  project, feature epic, wave, tech stack, asset types, UI access checks, v1
  permissions. Outputs ServiceProfile JSON and narrative summary. Used by
  onboarding-interview agent.
---

# Onboarding interview conduct

Structured Phase 0/1 intake with the service EM and tech lead. Produces a draft `ServiceProfile` for pattern suggestion and dedup.

## When to use

- At the start of every new Kessel service onboarding — this is the first skill the `onboarding-interview` agent runs via `/kessel-onboarding:interview`.
- For both live Q&A sessions (EM/tech lead present) and headless sessions where intake notes or a repo reference are supplied up front.

## Configuration

Read `~/.config/kessel-onboarding/config.json`. Use `artifacts_dir` for output paths. If missing, direct the user to [docs/configuration.md](../../docs/configuration.md).

## Inputs

| Input | Required | Notes |
|-------|----------|-------|
| `service_name` | yes | From command or positional arg |
| `provider_name` | no | Infer or ask |
| `feature_epic_key` | no | `--feature-epic` flag |
| `intake_notes` | no | Pasted doc or file for `--headless` |
| `codebase_ref` | no | GitHub/GitLab URL, local path, or archive to the service's repo — see [Step 1.5](#step-15--codebase-reference-optional) |
| `headless` | no | Skip live Q&A |

## Execution

### Step 0 — Load reference

Read [reference.md](reference.md) for schema and question script. Optionally read [examples/activation-keys-profile.json](../../examples/activation-keys-profile.json) for shape.

### Step 1 — Session setup (Gate 0)

Confirm with EM:

- Single service intake vs provider-wide context
- EM is present or explicitly delegated
- Home Jira project

**Rule:** Do not infer or default intake type or EM presence. These determine session scope and must be explicitly confirmed before proceeding to Step 2. If the user skips or does not answer, re-ask — do not assume.

If `--headless` with `intake_notes`, skip to Step 3 after parsing notes.

### Step 1.5 — Codebase reference (optional)

Ask once, before Group 1: "Do you have a link to the service's repo (GitHub or GitLab URL), a local path, or an archive I can look at? Pointing me at the code lets me draft answers for UI access checks, tech stack, asset types, and v1 permissions, which you then confirm or correct rather than dictating from scratch."

- If the EM/tech lead has nothing to share, record `codebase_ref` as none and proceed to Group 1 with no analysis — this step never blocks the interview.
- If provided, record it as `interview.codebase_ref` and attempt analysis with whatever tools are available in this session (e.g. GitHub/GitLab MCP tools for a URL, direct file reads for a local/unzipped path). If access fails — private repo, no matching tool, unreadable archive, `--headless` with no attachment — say so and fall back to asking the affected groups cold; do not stall the session waiting for access.
- **Never invent file contents or guess at a repo's structure.** Only draft an inferred value for a field when the agent actually read a matching file; otherwise leave that field unknown and ask the normal question in Step 2.

**What to look for, by field:**

| Field | Signals to check |
|-------|-------------------|
| `tech_stack.lang` / `framework` | Manifest files: `pom.xml`/`build.gradle` (Java), `package.json` (Node), `go.mod` (Go), `requirements.txt`/`pyproject.toml` (Python), `Gemfile` (Ruby) |
| `tech_stack.auth` | Kessel SDK dependency/imports, or existing RBAC v1 client calls |
| `ui_access_checks` | Frontend source calling `/rbac/v1/access` (or equivalent) — grep for the literal path |
| `asset_types[]` | Domain/model classes, DB migrations, or API resource names that look like customer-managed resources |
| `v1_permissions` | `rbac-config`-style permission definition files (e.g. `permissions.yaml`, access-config manifests) |

For each field with a match, draft the value with a one-line rationale citing what was found (e.g. "`pom.xml` has Quarkus + a `kessel-sdk` dependency → lang=Java, framework=Quarkus, auth=Kessel SDK"). Carry these drafts into Step 2 — see the confirmation rule below.

### Step 2 — Interview (one fixed group per turn)

Ask only for **missing** fields, one group at a time, in this fixed order. Never combine groups into a single message, and never send more than one group before the EM responds — this applies in both single-service and multi-service (provider-context) sessions.

| Group | Fields | Phase |
|-------|--------|-------|
| 1. Jira linkage | `jira.feature_epic_key`, `program.wave` | 0 |
| 2. Contacts | `contacts.pm`, `contacts.em`, `contacts.tech_lead` | 0 |
| 3. Kickoff/credentials | `kickoff.docs_reviewed`, `credentials.cmdb_registered`, `credentials.service_account_status` | 0 |
| 4. UI access | `ui_access_checks` | 0 |
| 5. Tech stack & assets | `tech_stack.lang`/`framework`/`auth`, `asset_types` | 1 |
| 6. Permissions & inventory | `v1_permissions`, `inventory_reporting`, `inventory_migration_required` | 1 |
| 7. Ephemeral & targets | `ephemeral.uses_bonfire` (+ `ephemeral.pre_dev_tooling` only if false), `targets.stage`/`targets.prod` | 1 |

Skip a group entirely if every field in it is already known (from provider context, a prior service in the same multi-service session, or headless notes). In multi-service provider sessions, `jira.home_project` and provider-level fields (`provider.name`) are captured once during provider context and are not re-asked per service.

**Repo-drafted fields (groups 4, 5, 6):** if Step 1.5 produced a draft for a field in that group's turn, present the draft and its rationale in place of the raw question and ask the EM/tech lead to confirm or correct it — do not skip the group or auto-accept the draft. Record whatever they confirm (which may differ from the draft) as the final value, and mark that field `(confirmed from repo analysis)` in the narrative summary. A field with no draft in an otherwise-drafted group is still asked normally.

**Group 5 follow-up — asset type ownership:** After the EM confirms `asset_types[]`, ask for each type: "Is `{asset_type}` modeled as a new Kessel resource type your service defines and owns, or does it map to an existing Kessel type like `rbac.workspace`?"

This question is specifically to catch the case where an asset type uses an existing platform type rather than introducing a new service-specific one. If the EM confirms an asset type maps to `rbac.workspace`:

- Record this in the **narrative summary** under that asset type's entry (e.g. "group — maps to rbac.workspace; permissions handled by rbac.ksl").
- **Update or annotate the pattern rationale** for that asset type in `patterns[]` to reflect this (e.g. add "uses existing rbac.workspace type" to the rationale string). Schema-design Step 1 reads `patterns[]` as its authoritative classification source — a clear rationale note is the correct handoff channel. Do not use `docs_gaps[]` (for unanswered doc questions only) or create a separate field (`asset_types` is `string[]`).
- If the suggested pattern (`native`, `native-ws-list`, `default-workspace`) is inconsistent with the EM confirming the type uses `rbac.workspace`, flag the contradiction and resolve it before the interview completes — the pattern must be corrected or the ownership answer re-confirmed.

**Important scope limit:** This follow-up identifies whether an asset type uses an existing platform type. It does **not** independently determine whether the schema-design skill generates a KSL type definition or inventory-api schema — those decisions are made solely by schema-design Step 1 using `patterns[]` and `inventory_migration_required`. "Service-owned" alone does not imply a KSL `public type`; that depends on whether the pattern is `native` or `native-ws-list` specifically.

If codebase analysis in Step 1.5 found a `KesselResourceType` subclass with `namespace="rbac"` for an asset type, draft the answer as "maps to rbac.workspace" and ask the EM to confirm.

**Group 6 — wildcard resource permissions:** When presenting codebase-drafted `v1_permissions`, always include wildcard resource entries (`{app}:*:read`, `{app}:*:write`, `{app}:*:*`) if found in the analysis — do not filter them out as noise. These are meaningful grants (cross-resource-type access) that appear in `permissions.json` and are distinct from resource-specific wildcards like `{app}:{resource}:*`. If the codebase analysis found them, include them in the draft list. Explicitly prompt: "Does your app have any permissions that span all resource types — like `{app}:*:read` or `{app}:*:*`? These are often admin bypass grants."

Rules:

- Infer `service.slug` from `service.name` (kebab-case).
- Default `jira.label` to `kessel-onboarding`.
- Default `program.path` to `self-service` (suggest-patterns may override).
- Set `interview.conducted_at` to current ISO-8601 timestamp.
- Record `interview.participants` from names provided.
- Leave `patterns`, `platform_gates`, and `dedup` empty or omit until downstream skills run.

Whenever the EM or tech lead asks a question the agent cannot answer from KesselDocs or the internal docs, record it in `docs_gaps[]` with enough context to reproduce the question. Do not interrupt the interview to research; capture and move on.

### Step 3 — Build ServiceProfile JSON

Assemble object per schema v1.3 (accept 1.0, 1.1, 1.2, or 1.3; new fields absent on earlier-version profiles are treated as null). Validate:

- `ui_access_checks` is one of `required`, `new`, `not_required`, `n/a`
- `program.wave` is 1, 2, or 3
- `v1_permissions.items` is non-empty array (or explicit "unknown — Phase 1 follow-up" in summary)

### Step 4 — Write artifacts

```
{artifacts_dir}/profiles/{slug}-profile.json
{artifacts_dir}/profiles/{slug}-summary.md
```

Create `artifacts/profiles/` if needed.

Summary format: see [reference.md](reference.md#narrative-summary-template).

### Step 5 — Present draft

Show EM a concise summary table of captured fields. List any gaps flagged for Phase 1 follow-up. Do **not** run suggest-patterns or dedup here — the agent orchestrator calls those next.

## Headless mode

When `--headless` is set:

1. Parse `intake_notes` or attached file into profile fields.
2. If `codebase_ref` is also passed, run the Step 1.5 analysis and merge drafted values into the parsed notes for any field the notes left blank; since there is no live EM/tech lead to confirm, mark those fields `"TBD — confirm with EM (drafted from repo analysis)"` in summary rather than treating the draft as final.
3. Mark missing required fields as `"TBD — confirm with EM"` in summary only; use null-safe defaults in JSON where schema allows.
4. Write artifacts and return paths.

## Outputs

| Output | Path |
|--------|------|
| ServiceProfile JSON | `{artifacts_dir}/profiles/{slug}-profile.json` |
| Narrative summary | `{artifacts_dir}/profiles/{slug}-summary.md` |

Return both paths to the orchestrating agent.

## Changelog

- 2026-07: Group 5 — ask whether each asset type is service-owned or maps to an existing `rbac.workspace` type; passes ownership context to schema-design. Group 6 — always include wildcard resource permissions (`{app}:*:read`, `{app}:*:*`) in codebase-drafted permission lists.
- 2026-07: Added optional `codebase_ref` input and Step 1.5 for codebase-analysis-driven drafts (schema v1.3). Added `new` ui_access_checks value. Fixed question order to one group per turn.
- 2026-07: Initial version — accept schema v1.0/1.1/1.2; fixed 7-group interview order; docs-gap capture rule.

Assisted-by: Claude (Anthropic)
