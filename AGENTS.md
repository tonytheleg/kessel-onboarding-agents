# AGENTS.md — Kessel Onboarding Agents

Agent + skill framework for Kessel service onboarding intake and (future) Jira provisioning. Follows the same **agent + skill + human gate** pattern as Red Hat's AI-first PM framework.

## Conventions

- **Human in the loop:** Agents propose ServiceProfiles and handoffs; EMs approve before any Jira writes. See [docs/responsible-use.md](docs/responsible-use.md).
- **Jira read-only in Interview Agent:** Dedup and feature-epic validation only. Provisioner owns creates/updates (dry-run default).
- **Artifacts:** Written to `{artifacts_dir}/profiles/` per [docs/configuration.md](docs/configuration.md).
- **Grounding:** Canonical templates live in `context/`.
- **CI checks:** [`.gitlab-ci.yml`](.gitlab-ci.yml) runs structure/skill-metadata validation and secret/PII scanning on every MR and push to `main` — see [scripts/README.md](scripts/README.md) for what each check does and how to fix a failure locally.

## Agent index

Slash-command specs live in `commands/` for Claude Code and compatible runtimes; each command dispatches to an agent and its skills. Invoke via slash command or by referencing the agent/skill file directly.

| Agent | Skills orchestrated | Command | Status |
|-------|---------------------|---------|--------|
| `onboarding-interview` | `onboarding-interview-conduct`, `onboarding-interview-suggest-patterns`, `onboarding-dedup-epic`, `onboarding-format-handoff` | `/kessel-onboarding:interview` | Active |
| `onboarding-provisioner` | `onboarding-provision-jira` | `/kessel-onboarding:provision` | Active (Track B) |

The following are **standalone skills** (no full agent required) invoked directly via their slash commands:

| Skill | Command | Purpose |
|-------|---------|---------|
| `onboarding-preflight` | `/kessel-onboarding:preflight` | Validates config, MCP, Jira access — run once per machine |
| `onboarding-schema-design` | `/kessel-onboarding:schema-design` | Generates draft resource schemas (inventory-api) and permissions schemas (rbac-config) from a ServiceProfile + codebase analysis |
| `onboarding-validate-interview` | `/kessel-onboarding:validate-interview` | Scores an interview's accuracy against a service's actual Kessel implementation; produces a structured gap report |

## Skill locations

```
skills/
├── onboarding-preflight/            # Config + MCP + Jira validation
├── onboarding-interview-conduct/    # Phase 0/1 Q&A → ServiceProfile
├── onboarding-interview-suggest-patterns/  # KSL-016 pattern matching
├── onboarding-dedup-epic/           # JQL dedup (read-only)
├── onboarding-format-handoff/       # Packages approved profile as handoff
├── onboarding-provision-jira/       # Creates Jira issue batch (dry-run default)
├── onboarding-schema-design/        # Generates inventory-api + rbac-config schemas
└── onboarding-validate-interview/   # Validates interview accuracy vs real implementation
```

## Command locations

```
commands/
├── preflight.md          # /kessel-onboarding:preflight
├── interview.md          # /kessel-onboarding:interview
├── provision.md          # /kessel-onboarding:provision
├── schema-design.md      # /kessel-onboarding:schema-design
└── validate-interview.md # /kessel-onboarding:validate-interview
```

## Jira project routing

| Issue type | Project |
|------------|---------|
| Provider Initiative | CRCPLAN |
| Service onboarding Epic | RHCLOUD |
| Phase Stories (0–7), UI Story | RHCLOUD |
| Feature epic (relates-to link only) | Service team project (e.g. TUSC, RHINENG) |

## Data flow

See [docs/data-flow.md](docs/data-flow.md) for handoff contracts between Interview and Provisioner agents.

## MCP policy

The real architecture is hybrid: the Atlassian MCP server (named in config `mcp_server_name`) handles reads and basic creates; direct Jira REST API calls (`.env` credentials) handle what MCP cannot do — setting the Team custom field and submitting ADF descriptions.

| Capability | Atlassian MCP tool (typical) | Interview Agent | Provisioner Agent |
|------------|-------------------------------|------------------|--------------------|
| Search issues (JQL) | `searchJiraIssuesUsingJql` | Yes | Yes |
| Get issue | `getJiraIssue` | Yes | Yes |
| Create issue | `createJiraIssue` | No | **Yes** |
| Edit issue | `editJiraIssue` | No | **Yes** |
| Link issues | `createIssueLink` | No | **Yes** |
| Team field / ADF descriptions | Jira REST API (`.env` fallback) | No | **Yes** |

Tool names vary by MCP server implementation; skills refer to capabilities, not exact tool names. `/kessel-onboarding:preflight` check 2 confirms the connected server exposes them. Run `/kessel-onboarding:preflight` before the first run on a machine and after any config change (Provisioner runs also require preflight checks 4–5 to PASS before any create).

## Changelog

- 2026-07: Added GitLab CI (`.gitlab-ci.yml`, `scripts/`, `.gitleaks.toml`, `.pre-commit-config.yaml`) — structure/skill-metadata validation and secret/PII scanning, adapted from the TAILWIND program repo's CI and trimmed to this repo's single-contributor, no-registry/no-sandbox/no-license layout. Added a `## When to use` section to every `skills/*/SKILL.md` to satisfy the new metadata check.
- 2026-07: Added `onboarding-schema-design` and `onboarding-validate-interview` to skill index, locations tree, and commands table.
- 2026-07: Removed `onboarding-link-platform-gates` from the Provisioner's skill list and the skill locations tree — the skill was removed (it never had a populated Jira key to link against; all gate statuses are now `ready`). Platform gate status is still read during pattern suggestion (confidence cap / wave restriction); only the Jira-linking half was removed.
- 2026-07: Replaced the tool-name MCP policy table with a capability-based table, added the preflight skill to the skill index, and folded agents/README.md and commands/README.md content into this file.

Assisted-by: Claude (Anthropic)
