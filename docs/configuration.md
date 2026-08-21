# Configuration

Create `~/.config/kessel-onboarding/config.json` on your machine. **Do not commit this file or tokens to git.**

## Template

Replace all values marked `YOUR_*` with your own. The Kessel team examples are provided for reference only.

```json
{
  "jira_host": "redhat.atlassian.net",
  "jira_cloud_id": "YOUR_CLOUD_ID",
  "initiative_project": "YOUR_INITIATIVE_PROJECT",
  "onboarding_project": "YOUR_ONBOARDING_PROJECT",
  "onboarding_label": "kessel-onboarding",
  "platform_gates_path": "context/platform-gates.json",
  "artifacts_dir": "./artifacts",
  "kessel_docs_base": "https://project-kessel.github.io/docs/",
  "mcp_server_name": "YOUR_ATLASSIAN_MCP_SERVER_NAME",
  "team_field_id": "YOUR_TEAM_FIELD_ID",
  "team_field_value": "YOUR_TEAM_UUID"
}
```

## Fields

| Field | Purpose | Example (Kessel team) |
|-------|---------|----------------------|
| `jira_cloud_id` | Atlassian cloud ID for MCP JQL and get-issue calls. See [Finding your cloud ID](#finding-your-cloud-id). | — |
| `initiative_project` | Jira project where Provider Initiatives are created. Use your team's feature/initiative tracking project. | `CRCPLAN` |
| `onboarding_project` | Jira project where Service Epics and Phase Stories are created. Use your team's sprint/work-item project. | `RHCLOUD` |
| `onboarding_label` | Label applied to all onboarding issues. Keep as `kessel-onboarding` unless your team uses a different convention. | `kessel-onboarding` |
| `platform_gates_path` | Relative path from repo root to pattern → platform readiness status map. Leave as default. | `context/platform-gates.json` |
| `artifacts_dir` | Local directory for ServiceProfile JSON and handoff files. | `./artifacts` |
| `mcp_server_name` | Name of the connected Atlassian MCP server in your runtime. Skills reference this instead of hardcoding a personal server name. | — |
| `team_field_id` | Jira custom field ID for the Team field. Most Red Hat Jira instances use `customfield_10001`. Confirm with your Jira admin if issues aren't saving the team correctly. | `customfield_10001` |
| `team_field_value` | UUID of your team's entry in the Jira Team field. Must be the UUID — not the display name. See [Finding your team UUID](#finding-your-team-uuid). | `0565e73b-8086-4228-9d8e-58a35ae78984` (Console - Kessel) |

## Finding your cloud ID

Use Atlassian MCP `getAccessibleAtlassianResources` or ask your Jira site admin. Store only in local config.

## Finding your team UUID

Jira's Team field requires a UUID, not the team display name. To find yours:

1. Open any existing Jira issue in your project that already has the Team field set.
2. Call the Jira REST API:
   ```bash
   curl -u your@email.com:YOUR_API_TOKEN \
     "https://redhat.atlassian.net/rest/api/3/issue/ISSUE-KEY?fields=customfield_10001"
   ```
3. The response will include the team UUID in the `customfield_10001` field.

Alternatively, you can:
1. Export a card to XML and search for `customfield_10001` above, the value will defined below it
```xml
<customfield id="customfield_10001" key="com.atlassian.jira.plugin.system.customfieldtypes:atlassian-team">
  <customfieldname>Team</customfieldname>
  <customfieldvalues>
    <customfieldvalue id="0565e73b-8086-4228-9d8e-58a35ae78984">Console - Kessel</customfieldvalue>
  </customfieldvalues>
</customfield>
```
2. Export a card to Excel and look for the "Team Id" column, it will continued the UUID

## REST API fallback (.env)

The Atlassian MCP cannot set Jira custom fields (Team) or submit ADF descriptions; those calls use the Jira REST API directly.

Create a `.env` file in the repo root with:

```
JIRA_BASE_URL=https://redhat.atlassian.net
[email protected]
JIRA_API_TOKEN=your-atlassian-api-token
```

`JIRA_API_TOKEN` is an Atlassian API token, not a password. Never commit `.env` — confirm it is listed in `.gitignore` (add it if missing). Tokens are personal and scoped to the operator running the Provisioner.

Run `/kessel-onboarding:preflight --provisioner` after completing this configuration.

## Project routing summary

| Issue type | Project | Configured by |
|------------|---------|--------------|
| Provider Initiative | `initiative_project` | Config field — set to your initiative/feature tracking project |
| Service onboarding Epic | `onboarding_project` | Config field — set to your sprint/work-item project |
| Phase Stories | `onboarding_project` | Config field |
| Feature epic (relates-to link) | `jira.home_project` from ServiceProfile | EM provides at intake |

## Platform gate status

`context/platform-gates.json` maps each KSL-016 pattern to a platform readiness `status` (`ready` / `partial` / `ongoing` / `unknown`). Only `status` is consumed by any skill today — `onboarding-interview-suggest-patterns` reads it to cap pattern-suggestion confidence and set the paired-path default for wave 3+ services.

## Changelog

- 2026-08: Removed `allowed_projects` (no longer used); updated template to use `YOUR_*` placeholders to make clear users must supply their own project/team values; added Finding your team UUID section.
- 2026-07: Replaced "Platform gate keys" with "Platform gate status" — clarified that only `status` is used (pattern-suggestion confidence), since the Jira gate-linking skill that consumed `jira_key` was removed.
- 2026-07: Renamed the Team field reference from "Fabric - Kessel" to "Console - Kessel" (team display name changed; UUID unchanged).
- 2026-07: Added `mcp_server_name`, `team_field_id`, `team_field_value` config keys and the REST API fallback (`.env`) section.

Assisted-by: Claude (Anthropic)
