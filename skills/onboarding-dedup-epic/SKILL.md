---
name: onboarding-dedup-epic
description: >
  JQL search for existing Kessel onboarding Initiatives, service Epics, and
  feature epics before Jira provision. Prevents double-provisioning. Read-only
  Atlassian MCP. Used by onboarding-interview agent.
---

# Onboarding dedup epic

## When to use

- Called automatically by the `onboarding-interview` agent after `onboarding-interview-conduct`, before the profile is presented for EM approval.
- Run standalone whenever you need to re-check Jira for existing Initiatives, Service Epics, or feature epics for a service before provisioning (e.g. after a long gap between interview and provision, or when re-running dedup after a manual Jira change).

## Configuration

Read `~/.config/kessel-onboarding/config.json`: `jira_cloud_id`, `initiative_project`, `onboarding_project`, `onboarding_label`.

## Inputs

| Input | From |
|-------|------|
| `service.name` | ServiceProfile |
| `provider.name` | ServiceProfile |
| `jira.home_project` | ServiceProfile (service team's own project — for feature epic lookup) |
| `jira.feature_epic_key` | ServiceProfile |

## JQL templates

Substitute `{label}`, `{service_name}`, `{provider_name}`, `{home_project}`, `{feature_epic_key}`.

Use `initiative_project` and `onboarding_project` from config for Initiative and Epic searches respectively.

### Existing onboarding epic for this service

```
project = {onboarding_project} AND type = Epic AND labels = {label} AND summary ~ "{service_name}"
```

### Provider initiative

```
project = {initiative_project} AND type = Initiative AND labels = {label} AND summary ~ "{provider_name}"
```

Feature epic templates unchanged. Never include square brackets or other JQL special characters inside `~` text matches — brackets are JQL special characters, so these templates anchor on labels instead.

All JQL templates in this skill are linted by `/kessel-onboarding:preflight`.

### Feature epic validation

If `feature_epic_key` provided:

```
key = {feature_epic_key}
```

Else:

```
project = {home_project} AND type = Epic AND summary ~ "{service_name}"
```

## Execution

### Step 1 — Run JQL searches

Use `search_issues` on the Atlassian MCP server named in config `mcp_server_name`, with `jira_cloud_id`. Max 10 results per query.

If MCP fails, set `dedup.status` to `unknown` and note "Manual dedup required — MCP unavailable" in summary. Still allow EM to proceed with caution.

### Step 2 — Classify matches

| Match type | Condition | Suggested action |
|------------|-----------|------------------|
| `service_epic` | Onboarding epic exists for same service name | **stop** — link existing; retrofit only |
| `provider_initiative` | Initiative exists for provider | **reuse** — do not create second Initiative |
| `feature_epic` | Key resolves and summary plausibly matches | **ok** |
| `feature_epic_missing` | Key not found or wrong project | **clarify** |
| none | No conflicts | **proceed** |

### Step 3 — Set dedup object on profile

```json
{
  "dedup": {
    "status": "clean",
    "notes": "",
    "matches": [
      {
        "type": "provider_initiative",
        "key": "TUSC-100",
        "summary": "[Kessel Onboarding] Subscription Management",
        "action": "reuse"
      }
    ]
  }
}
```

`status` values:

- `clean` — no blocking duplicate
- `reuse_initiative` — initiative exists; provisioner should reuse
- `duplicate_found` — service epic duplicate; **stop** provision
- `unknown` — MCP failed

### Step 4 — Present to EM

Show match table with Jira keys and recommended action. If `duplicate_found`, recommend linking to existing epic instead of new intake.

EM must acknowledge dedup result before profile approval gate.

### Step 5 — Update artifacts

Write updated `dedup` into `{slug}-profile.json`. Append dedup section to `{slug}-summary.md`.

## MCP tools

| Tool | Use |
|------|-----|
| `search_issues` | Yes |
| `get_issue` | Validate feature epic details |
| `create_issue` | **No** |
| `update_issue` | **No** |

## Outputs

Updated ServiceProfile with `dedup` populated.

## Changelog

- 2026-07: Hardened JQL templates to anchor on labels instead of bracketed summary text; referenced the connected Atlassian MCP server via config instead of a hardcoded name.

Assisted-by: Claude (Anthropic)
