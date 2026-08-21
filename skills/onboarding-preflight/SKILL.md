---
name: onboarding-preflight
description: >
  Gate check before live Jira provisioning. Validates config, MCP connectivity,
  Jira read access, and JQL templates. When --provisioner is supplied, also
  validates Jira create-access and REST fallback credentials. Not required for
  interview, schema-design, or dry-run workflows.
---

# Onboarding preflight

Gate check before live Jira provisioning. Produces a PASS/FAIL summary so config and access problems surface before a provision session, not mid-run.

## When preflight is required

**Preflight is only required before live Jira provisioning.** The interview and schema-design skills work without it — they are entirely local and do not call Jira.

| Workflow | Preflight needed? |
|---|---|
| Interview only (local artifacts) | No |
| Schema design | No |
| Provision `--dry-run` (table only, no writes) | No |
| Live provision (creates Jira issues) | **Yes — run preflight first** |

Run preflight when:
- Setting up live provisioning on a new machine for the first time.
- After changing `~/.config/kessel-onboarding/config.json` or `.env` REST credentials.
- Troubleshooting a failed provision session.

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

## Inputs

| Input | Required | Notes |
|---|---|---|
| `--provisioner` | no | When set, run all 7 checks including create-permission (4) and REST credentials (5). Without this flag, run only checks 1–3, 6–7. |

## Execution

Run checks in order based on the input flag. For each check, produce a row: `#`, check name, PASS/FAIL, remediation (only when FAIL).

Output a summary table. Overall PASS:
- Without `--provisioner`: checks 1–3 and 6–7 must pass
- With `--provisioner`: all seven checks must pass

## Notes

- Tool names vary by MCP server implementation; skills refer to capabilities, not exact tool names. Check 2 confirms the connected server (named in config `mcp_server_name`) exposes the needed capabilities (search, get, create, edit, link).
- Never create a live test issue to validate permissions — check 4 uses a permissions-check endpoint, not a create call.
- Checks 4–5 apply only to the Provisioner Agent; the Interview Agent is read-only and does not need Jira create permission or REST fallback credentials.

## Outputs

- Summary table (console) with overall PASS/FAIL
- Per-check remediation guidance for any FAIL

## Changelog

- 2026-08: Clarified that preflight is a gate before live Jira provisioning only — interview, schema-design, and `provision --dry-run` workflows are entirely local and do not require it. Added `--provisioner` input flag to select the full 7-check mode (including create-permission and REST credential checks); without the flag only checks 1–3 and 6–7 run. Updated description and scope accordingly.
