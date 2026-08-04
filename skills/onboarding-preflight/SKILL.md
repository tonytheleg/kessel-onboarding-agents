---
name: onboarding-preflight
description: >
  Validates config, MCP connectivity, Jira access, REST fallback credentials,
  and JQL templates before running interview or provision. Run once per
  machine and after any config change.
---

# Onboarding preflight

Run before the first `/kessel-onboarding:interview` or `/kessel-onboarding:provision` on a machine, and after any change to `~/.config/kessel-onboarding/config.json`. Produces a PASS/FAIL summary so config and access problems surface before a live session, not mid-interview or mid-provision.

## When to use

- Before the first `/kessel-onboarding:interview` or `/kessel-onboarding:provision` run on a new machine.
- After any change to `~/.config/kessel-onboarding/config.json` or the `.env` REST fallback credentials.
- Whenever an interview or provision session fails with a config, MCP, or Jira access error and you need to isolate the cause.

## Checks

| # | Check | How | Remediation on fail |
|---|-------|-----|----------------------|
| 1 | Config file exists with required keys (`jira_cloud_id`, `initiative_project`, `onboarding_project`, `onboarding_label`, `mcp_server_name`, `team_field_id`, `team_field_value`, `artifacts_dir`) | Read `~/.config/kessel-onboarding/config.json` | Point to `docs/configuration.md` template |
| 2 | Atlassian MCP connected and authenticated | Call the accessible-resources tool; confirm `jira_cloud_id` appears | Instructions: authenticate the Atlassian MCP connector; re-run |
| 3 | Jira read access | Run one JQL search: `project = {onboarding_project} ORDER BY created DESC` max 1 result | Request RHCLOUD read access; link to config doc |
| 4 | Jira create permission (Provisioner only) | Call `GET /rest/api/3/mypermissions?projectKey={onboarding_project}&permissions=CREATE_ISSUES` via REST fallback. Never create a test issue. | Request create permission in RHCLOUD/CRCPLAN |
| 5 | REST fallback credentials present (Provisioner only) | `.env` file exists with `JIRA_BASE_URL`, `JIRA_EMAIL`, `JIRA_API_TOKEN`; token requests succeed against `/rest/api/3/myself` | Point to the new `.env` section in `docs/configuration.md` |
| 6 | JQL template lint | Substitute sample values into every JQL template in `skills/onboarding-dedup-epic/SKILL.md` and the first-in-pattern query; run each with max 1 result; any syntax error = FAIL | Report the failing template verbatim |
| 7 | Artifacts dir writable | Create and delete a temp file in `{artifacts_dir}/profiles/` | Fix path or permissions |

## Execution

Run checks 1–7 in order. For each check, produce a row: `#`, check name, PASS/FAIL, remediation (only when FAIL).

Output a summary table. Overall PASS requires checks 1–3 and 6–7 for the Interview Agent, all seven for the Provisioner.

## Notes

- Tool names vary by MCP server implementation; skills refer to capabilities, not exact tool names. Check 2 confirms the connected server (named in config `mcp_server_name`) exposes the needed capabilities (search, get, create, edit, link).
- Never create a live test issue to validate permissions — check 4 uses a permissions-check endpoint, not a create call.
- Checks 4–5 apply only to the Provisioner Agent; the Interview Agent is read-only and does not need Jira create permission or REST fallback credentials.

## Outputs

- Summary table (console) with overall PASS/FAIL
- Per-check remediation guidance for any FAIL
