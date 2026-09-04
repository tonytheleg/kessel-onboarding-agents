# AGENTS.md — Kessel Onboarding Agents

Agent + skill framework for Kessel service onboarding intake and (future) Jira provisioning. Follows the same **agent + skill + human gate** pattern as Red Hat's AI-first PM framework.

## Conventions

- **Human in the loop:** Agents propose ServiceProfiles and handoffs; EMs approve before any Jira writes. See [docs/responsible-use.md](docs/responsible-use.md).
- **Jira read-only in Interview Agent:** Dedup and feature-epic validation only. Provisioner owns creates/updates (dry-run default).
- **Artifacts:** Written to `{artifacts_dir}/profiles/` per [docs/configuration.md](docs/configuration.md).
- **Grounding:** Canonical templates live in `context/`.
- **Implementation follow-up:** After any main skill completes, read `context/implementation-topics.json` and offer contextually relevant implementation topics. Follow the [Follow-up implementation topics](#follow-up-implementation-topics) workflow below. This keeps docs as the single source of truth — topic content is fetched from URLs at runtime, never duplicated here.
- **CI checks:** [`.gitlab-ci.yml`](.gitlab-ci.yml) runs structure/skill-metadata validation and secret/PII scanning on every MR and push to `main` — see [scripts/README.md](scripts/README.md) for what each check does and how to fix a failure locally.

## Follow-up implementation topics

After any main skill completes its primary output (interview → profile approved, schema-design → schemas generated, provision → dry-run shown, migrate-rbac-v1 → report written), if the user is not immediately moving to another skill:

1. Read `context/implementation-topics.json`.
2. Select 3–5 topics whose `tags` match the service's context:
   - `inventory_migration_required = true` → suggest `inventory-reporting`, `schema-pr`
   - `ui_access_checks = required` → suggest `endpoint-protection`
   - Pattern = `native-ws-list` → suggest `list-endpoint-authorization`
   - Pattern = `default-workspace` or `root-workspace` → suggest `workspace-lookup`
   - Credentials not set up → always suggest `service-account`
   - Any service → always include `sdk-setup`, `check-vs-checkforupdate`
3. Present suggestions conversationally — not as a menu, just a short list:
   > "A few things worth looking at next:
   > - **SDK Setup** — configuring the Kessel client for Go
   > - **Check vs CheckForUpdate** — which to use for reads vs writes
   > - **Inventory Reporting** — calling ReportResource and DeleteResource correctly
   > Want to dig into any of these, or something else?"
4. When the user picks a topic or asks a related question, resolve it based on which field is set:
   - `public_url` — fetch with the available web-fetch tool and answer from the document content. Do not reproduce the full document; answer the specific question with citations.
   - `inscope_guide` — tell the user: "See the '[inscope_guide value]' guide in InScope." Do not fabricate content for internal docs.
   - `plugin_ref` — read that file from within the plugin directory and answer from it.
5. Keep the interview profile, schema artifacts, and migration context in scope throughout — tailor answers to the specific service (language, patterns, asset types) rather than giving generic guidance.

This is free-form conversation guided by the topic index, not a structured skill. Do not force users through a fixed flow — answer what they ask, suggest what's relevant, and follow their lead.

`context/implementation-topics.json` is the current topic list and URL source. Never hardcode topic URLs in skill files; keep topic content in the index and fetch it at runtime.

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
| `onboarding-migrate-rbac-v1` | `/kessel-onboarding:migrate-rbac-v1` | Finds v1 RBAC call sites, classifies by KSL-016 pattern, fills schema gaps, writes Kessel v2 replacement code into the service repo (uncommitted) |
| *(orchestration)* | `/kessel-onboarding:test` | Full test loop — interview + schema-design with Kessel blindfold, then auto-validate. No dedicated skill file; orchestrated by the `test.md` command. |

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
├── onboarding-validate-interview/   # Validates interview accuracy vs real implementation
└── onboarding-migrate-rbac-v1/     # Writes v1→v2 RBAC code changes into the service repo
```

## Command locations

```
commands/
├── preflight.md          # /kessel-onboarding:preflight
├── interview.md          # /kessel-onboarding:interview  (supports --test-mode)
├── provision.md          # /kessel-onboarding:provision
├── schema-design.md      # /kessel-onboarding:schema-design  (supports --test-mode)
├── validate-interview.md # /kessel-onboarding:validate-interview
├── migrate-rbac.md       # /kessel-onboarding:migrate-rbac-v1
└── test.md               # /kessel-onboarding:test  (full test loop: interview + schema-design + validate)
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

- 2026-09: Moved the follow-up implementation topic selection and presentation workflow from `CLAUDE.md` into this shared instruction file so all supported runtimes can apply it.
- 2026-07: Added GitLab CI (`.gitlab-ci.yml`, `scripts/`, `.gitleaks.toml`, `.pre-commit-config.yaml`) — structure/skill-metadata validation and secret/PII scanning, adapted from the TAILWIND program repo's CI and trimmed to this repo's single-contributor, no-registry/no-sandbox/no-license layout. Added a `## When to use` section to every `skills/*/SKILL.md` to satisfy the new metadata check.
- 2026-07: Added `onboarding-schema-design` and `onboarding-validate-interview` to skill index, locations tree, and commands table.
- 2026-07: Removed `onboarding-link-platform-gates` from the Provisioner's skill list and the skill locations tree — the skill was removed (it never had a populated Jira key to link against; all gate statuses are now `ready`). Platform gate status is still read during pattern suggestion (confidence cap / wave restriction); only the Jira-linking half was removed.
- 2026-07: Replaced the tool-name MCP policy table with a capability-based table, added the preflight skill to the skill index, and folded agents/README.md and commands/README.md content into this file.

Assisted-by: Claude (Anthropic)
