# Responsible use

Kessel onboarding agents assist EMs and tech leads; they do not replace program judgment or Jira admin policy.

## Human gates (Interview Agent)

| Gate | Who | What |
|------|-----|------|
| Session setup | EM | Scope (single service vs provider), participants, home Jira project |
| Profile review | EM | Approve ServiceProfile (patterns, wave, UI checks, contacts) before handoff |
| Handoff dispatch | EM | Choose schema design (now/later), save-only, or invoke Provisioner |

Agents **propose**; humans **commit**. No Jira creates or updates from the Interview Agent.

## Validation against sources of record

Treat agent output as drafts until validated against:

- [KesselDocs](https://project-kessel.github.io/docs/)
- Live Jira state (dedup results)
- KSL-016 decision tree (VPN) for pattern disputes

## MCP and project restrictions

- RHCLOUD issue creation via MCP may be blocked for some users. Interview Agent stays read-only; Provisioner always dry-runs first and falls back to the Jira REST API (`.env` credentials) for the Team field and ADF descriptions — see [docs/configuration.md](configuration.md#rest-api-fallback-env).
- Never commit `~/.config/kessel-onboarding/config.json` or API tokens. This is enforced automatically: CI runs a gitleaks secret scan and a PII/sensitive-content scan on every merge request and push to `main` (see [`.gitlab-ci.yml`](../.gitlab-ci.yml) and [scripts/README.md](../scripts/README.md)); `.pre-commit-config.yaml` mirrors the same checks locally before push.

## When not to use agents

- Retrofitting wave 1 services with existing epics — dedup will flag duplicates.
- Org-level or root-workspace patterns before platform readiness epics are Done (wave 3+).
