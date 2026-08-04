# Configuration

Create `~/.config/kessel-onboarding/config.json` on your machine. **Do not commit this file or tokens to git.**

## Template

```json
{
  "jira_host": "redhat.atlassian.net",
  "jira_cloud_id": "YOUR_CLOUD_ID",
  "initiative_project": "CRCPLAN",
  "onboarding_project": "RHCLOUD",
  "allowed_projects": ["CRCPLAN", "RHCLOUD", "RHINENG", "TUSC"],
  "onboarding_label": "kessel-onboarding",
  "platform_gates_path": "context/platform-gates.json",
  "artifacts_dir": "./artifacts",
  "kessel_docs_base": "https://project-kessel.github.io/docs/",
  "mcp_server_name": "YOUR_ATLASSIAN_MCP_SERVER_NAME",
  "team_field_id": "customfield_10001",
  "team_field_value": "0565e73b-8086-4228-9d8e-58a35ae78984"
}
```

## Fields

| Field | Purpose |
|-------|---------|
| `jira_cloud_id` | Atlassian cloud ID for MCP JQL and get-issue calls |
| `initiative_project` | Jira project for Provider Initiatives (`CRCPLAN`) |
| `onboarding_project` | Jira project for Service Epics and Phase Stories (`RHCLOUD`) |
| `allowed_projects` | All projects searched during dedup — include `initiative_project`, `onboarding_project`, and any service team projects (RHINENG, TUSC, …) |
| `onboarding_label` | Label on all onboarding issues (`kessel-onboarding`) |
| `platform_gates_path` | Relative path from repo root to pattern → platform readiness status map (`context/platform-gates.json`) |
| `artifacts_dir` | Local directory for ServiceProfile JSON and handoff files |
| `mcp_server_name` | Name of the connected Atlassian MCP server in the runtime. Skills reference this instead of hardcoding a personal MCP server name. |
| `team_field_id` | Jira custom field ID for the Team field. Default `customfield_10001`. |
| `team_field_value` | Team field value — the **UUID** for Console - Kessel (formerly "Fabric - Kessel"; the team was renamed but the UUID is stable), not the display name (Jira's Team field requires the UUID). Default `0565e73b-8086-4228-9d8e-58a35ae78984`. |

## REST API fallback (.env)

The Atlassian MCP cannot set Jira custom fields (Team) or submit ADF descriptions; those calls use the Jira REST API directly.

Create a `.env` file in the repo root with:

```
JIRA_BASE_URL=https://redhat.atlassian.net
[email protected]
JIRA_API_TOKEN=your-atlassian-api-token
```

`JIRA_API_TOKEN` is an Atlassian API token, not a password. Never commit `.env` — confirm it is listed in `.gitignore` (add it if missing). Tokens are personal and scoped to the operator running the Provisioner.

Run `/kessel-onboarding:preflight` after completing this configuration.

## Project routing summary

| Issue type | Project | Configured by |
|------------|---------|--------------|
| Provider Initiative | `initiative_project` (CRCPLAN) | Config field |
| Service onboarding Epic | `onboarding_project` (RHCLOUD) | Config field |
| Phase Stories | `onboarding_project` (RHCLOUD) | Config field |
| Feature epic (relates-to link) | `jira.home_project` from ServiceProfile | EM provides at intake |

## Finding your cloud ID

Use Atlassian MCP `getAccessibleAtlassianResources` or your Jira site admin. Store only in local config.

## Platform gate status

`context/platform-gates.json` maps each KSL-016 pattern to a platform readiness `status` (`ready` / `partial` / `ongoing` / `unknown`). Only `status` is consumed by any skill today — `onboarding-interview-suggest-patterns` reads it to cap pattern-suggestion confidence and set the paired-path default for wave 3+ services. The `jira_key` field is no longer consumed by anything (the Jira gate-linking skill was removed in 2026-07 because it never had a populated key to link against); it's kept for the Kessel PM's own record-keeping only.

## Changelog

- 2026-07: Replaced "Platform gate keys" with "Platform gate status" — clarified that only `status` is used (pattern-suggestion confidence), since the Jira gate-linking skill that consumed `jira_key` was removed.
- 2026-07: Renamed the Team field reference from "Fabric - Kessel" to "Console - Kessel" (team display name changed; UUID unchanged).
- 2026-07: Added `mcp_server_name`, `team_field_id`, `team_field_value` config keys and the REST API fallback (`.env`) section.

Assisted-by: Claude (Anthropic)
