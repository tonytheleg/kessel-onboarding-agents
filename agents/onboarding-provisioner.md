---
name: onboarding-provisioner
description: >
  Phase B provisioner for Kessel service onboarding. Reads an approved
  onboarding_profile handoff, presents a dry-run Jira issue batch for EM
  review, and — after explicit approval — creates the Provider Initiative
  (CRCPLAN), Service Epic (RHCLOUD), and Phase Stories (RHCLOUD).
---

# Onboarding Provisioner Agent

## What this agent does

Consumes the `onboarding_profile` handoff produced by the [Interview Agent](onboarding-interview.md) and materializes it as a Jira issue batch. Dry-run by default — no issues are created without EM confirmation.

Creates:

- **Provider Initiative** in CRCPLAN (skipped if `dedup.status` is `reuse_initiative`)
- **Service onboarding Epic** in RHCLOUD (parent → Initiative)
- **Phase Stories (0–7, including the 6a/6b split)** in RHCLOUD (parent field, legacy name: Epic Link → Epic; Phase 3 only when `inventory_migration_required` is true)
- **Conditional UI Story** in RHCLOUD when `ui_access_checks` is `required` (migrate v1 checks) or `new` (implement v2 checks fresh — no v1 to migrate)

Does **not** run if `dedup.status` is `duplicate_found` without an EM exception note.

## Role in the pipeline

```
[Onboarding Interview Agent]
            ↓  onboarding_profile handoff
[Onboarding Provisioner Agent]  ← this agent
            ↓
    CRCPLAN Initiative
    RHCLOUD Epic → Phase Stories
```

## Trigger

- `/kessel-onboarding:provision --handoff {path}`
- Dispatched by Interview Agent at Gate 2 (when Track B is active)

## Inputs

| Input | Type | Required |
|-------|------|----------|
| `handoff_path` | file path | yes |
| `dry_run` | flag | no (default: true) |
| `confirm` | flag | no — passed after EM approval to execute creates |

## Outputs

| Output | Consumer |
|--------|----------|
| Dry-run issue table (console) | EM review |
| Created issue key map JSON | Artifacts, future Phase Coach Agent |
| Updated ServiceProfile JSON | With created Jira keys written in |

## Skills this agent calls

| Order | Skill | File |
|-------|-------|------|
| 1 | Provision Jira issues | `skills/onboarding-provision-jira/SKILL.md` |

## Execution

### Step 0 — Load config

Read `~/.config/kessel-onboarding/config.json`. Require `jira_cloud_id`, `initiative_project`, `onboarding_project`, `onboarding_label`. If missing, stop and point to [docs/configuration.md](../docs/configuration.md).

If this is the first run on this machine or config changed, run `skills/onboarding-preflight/SKILL.md` first. Preflight checks 4–5 must PASS before any create.

### Step 1 — Load and validate handoff

Read `{handoff_path}`. Confirm:

- `Schema version: 1.0`, `1.1`, or `1.2` (accept any; new fields absent on earlier-version handoffs are treated as null)
- `Approved by` is populated (human gate ✓)
- `Status: Ready for Jira provision`

Read the ServiceProfile JSON at the path in `ServiceProfile:` field. Validate:

- `dedup.status` is `clean` or `reuse_initiative`. If `duplicate_found` and no EM exception note in handoff `EM notes:`, **stop** and display the conflicting issue key.
- `patterns[]` is non-empty.
- `jira.feature_epic_key` present or EM waived in `EM notes:`.

### Step 2 — Invoke provision-jira (dry-run)

Invoke `skills/onboarding-provision-jira/SKILL.md` with `dry_run = true`.

Skill returns proposed issue table. Present to EM.

### Step 3 — Gate 0: Dry-run review

Display dry-run table. Wait for EM:

- **"Create"** or **"Approve"** → proceed to Step 4
- **"Revise"** → EM edits handoff or profile, re-run from Step 1
- **"Abort"** → save dry-run table to `{artifacts_dir}/profiles/{slug}-dry-run.md`; stop

### Step 4 — Invoke provision-jira (execute)

Invoke `skills/onboarding-provision-jira/SKILL.md` with `dry_run = false`.

Skill creates issues in order: Initiative → Epic → Stories. Captures created key map.

### Step 5 — Gate 1: Confirm creates

Report created keys to EM. If any create failed, list failures and offer:

- **Retry** failed items
- **Continue** (skip failures; log them)
- **Abort remaining** (partial provision — log what was created)

### Step 6 — Write artifacts

Write created key map to `{artifacts_dir}/profiles/{slug}-jira-keys.json`.

Update `{slug}-profile.json` with created keys under `jira.created`:

```json
{
  "jira": {
    "created": {
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
      }
    }
  }
}
```

`story_keys` uses stable slugs (matching the `kessel-phase:{slug}` labels), not phase numbers — see `context/phase-checklist.md` for why.

`inventory_migration` and `ui_migration` keys are omitted entirely from `story_keys` when their conditional stories were not created. Consumers must treat a missing key as "story does not exist", not as an error.

Report final artifact paths to EM.

## Human gates

| Gate | Checkpoint |
|------|------------|
| Gate 0 | EM approves dry-run issue batch |
| Gate 1 | EM confirms created keys; resolves partial failures |

## MCP policy

| Tool | Allowed |
|------|---------|
| `search_issues` | Yes |
| `get_issue` | Yes |
| `create_issue` | **Yes** |
| `update_issue` | Yes (parent linking only — does not support custom fields or ADF) |
| `link_issues` | Yes (relates-to only — feature epic link) |
| Jira REST API (direct, `.env` fallback) | **Yes** — required for the Team field and ADF descriptions; `update_issue` cannot set either. See [docs/configuration.md](../docs/configuration.md#rest-api-fallback-env). |

## Multi-service providers

When multiple services share a provider, the `reuse_initiative` dedup path applies from the second service onward. The Provisioner skips Initiative creation and parents the new Epic to the existing CRCPLAN key from `dedup.matches[].key`.

## Previous agent

**Onboarding Interview Agent** — produces the `onboarding_profile` handoff this agent consumes.

## Next agent (planned)

**Phase Coach Agent** (Track D) — monitors phase progression; generates next-action prompts from ServiceProfile and live Jira story status.

## Changelog

- 2026-07: Accept handoff schema version 1.2 (adds `new` `ui_access_checks` value and `patterns[].asset_types`; see `skills/onboarding-format-handoff/handoff-schema.md`).
- 2026-07: Removed platform gate "is blocked by" linking (Step 6, previously `skills/onboarding-link-platform-gates/SKILL.md`) — the skill never successfully created a link in production since no platform readiness epic has ever had a recorded Jira key, and all gate statuses are now `ready` (see `context/platform-gates.json`). Platform gate status is still read during pattern suggestion (confidence cap / wave restriction) — only the Jira-linking half was removed.
- 2026-07: Fixed the MCP policy table — `update_issue` does not support the Team field or ADF descriptions; added the missing Jira REST API fallback row (consistency check).
- 2026-07: Added Phase 3/Phase 4 gate-linking fallback, `inventory_migration_required` conditional wording, preflight step, schema version 1.0/1.1 acceptance, conditional key map omission rule, parent field terminology, and story count wording.

Assisted-by: Claude (Anthropic)
