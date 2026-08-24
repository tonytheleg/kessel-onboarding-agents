# Kessel Onboarding Agents

AI agents and skills for the Kessel service onboarding program. Jira remains the system of record; agents propose artifacts and humans approve writes.

## Quick start

> **New here?** Start with the interview. Jira access is only needed if you plan to provision issues — the interview and schema design skills work without it.

1. Install the plugin (see [Installing this plugin](#installing-this-plugin) below).
2. Run an intake session:
   ```text
   /kessel-onboarding:interview --provider "Subscription Management" --service "Activation Keys"
   ```
3. Review the generated ServiceProfile and handoff in `./artifacts/profiles/`.
4. Optionally design schemas:
   ```bash
   /kessel-onboarding:schema-design --profile artifacts/profiles/{slug}-profile.json \
     --codebase_ref ~/dev/my-service
   ```
5. To preview what would be created in Jira (no writes):
   ```text
   /kessel-onboarding:provision --handoff artifacts/profiles/{slug}-handoff.md --dry-run
   ```

**Only need steps 2–3?** Skip preflight. It is only required before live Jira provisioning (`provision` without `--dry-run`).

---

## Installing this plugin

### Via the marketplace (recommended)

The plugin is hosted as a Claude Code marketplace on GitHub. Install it permanently in one step:

```bash
# 1. Register the Kessel marketplace (one-time)
/plugin marketplace add project-kessel/kessel-onboarding-agents

# 2. Install the plugin from that marketplace
/plugin install kessel-onboarding@kessel-onboarding-agents
```

Once installed, all slash commands are available in every Claude Code session without any flags.

### Claude Code (CLI or desktop app) — local or session-only

```bash
# Session-only — available for this session only, nothing written to global config
claude --plugin-dir /path/to/kessel-onboarding-agents

# Persistent local install — inside a Claude Code session
/install-plugin /path/to/kessel-onboarding-agents
```

Once loaded, all slash commands listed below become available in Claude Code.

### Cursor

Cursor uses a different skill system from Claude Code. Skills are SKILL.md files placed in:

- **User-level** (available in all projects): `~/.cursor/skills/{skill-name}/SKILL.md`
- **Project-level** (available only in the current repo): `.cursor/skills/{skill-name}/SKILL.md`

To make the kessel-onboarding skills available in Cursor, copy or symlink the skill directories you want into one of those locations:

```bash
# User-level — available across all your Cursor projects
mkdir -p ~/.cursor/skills
cp -r /path/to/kessel-onboarding-agents/skills/onboarding-schema-design ~/.cursor/skills/
cp -r /path/to/kessel-onboarding-agents/skills/onboarding-validate-interview ~/.cursor/skills/

# Or project-level — only in this repo
mkdir -p .cursor/skills
cp -r /path/to/kessel-onboarding-agents/skills/onboarding-schema-design .cursor/skills/
```

Cursor does not use the `agents/` or `commands/` directories — only the `skills/*/SKILL.md` files. The slash command interface (`/kessel-onboarding:interview`) is Claude Code-specific; in Cursor, reference the skill by asking the agent to follow the instructions in the SKILL.md file, or by including it as a Cursor rule.

The `--plugin-dir` flag is Claude Code CLI only — Cursor does not support it.

---

## Setting up for Jira provisioning

The interview and schema-design skills work without any Jira configuration. To enable live Jira provisioning (`/kessel-onboarding:provision` without `--dry-run`):

1. Create `~/.config/kessel-onboarding/config.json` with the following required keys:
   ```json
   {
     "jira_host": "redhat.atlassian.net",
     "jira_cloud_id": "YOUR_CLOUD_ID",
     "initiative_project": "YOUR_INITIATIVE_PROJECT",
     "onboarding_project": "YOUR_ONBOARDING_PROJECT",
     "onboarding_label": "kessel-onboarding",
     "platform_gates_path": "context/platform-gates.json",
     "artifacts_dir": "./artifacts",
     "mcp_server_name": "YOUR_ATLASSIAN_MCP_SERVER_NAME",
     "team_field_id": "YOUR_TEAM_FIELD_ID",
     "team_field_value": "YOUR_TEAM_UUID"
   }
   ```
   - `initiative_project` — the Jira project where Provider Initiatives are created (e.g. your team's feature/initiative tracking project)
   - `onboarding_project` — the Jira project where Service Epics and Phase Stories are created (e.g. your team's sprint/work-item project)
   - `team_field_value` — the UUID of your team's entry in the Jira "Team" field (not the display name).

   See [docs/configuration.md](docs/configuration.md) for all field descriptions, how to find your `jira_cloud_id`, and how to look up your team UUID.
2. Create a `.env` file with your Atlassian API credentials (see [docs/configuration.md](docs/configuration.md) for the REST fallback setup).
3. Run `/kessel-onboarding:preflight --provisioner` to validate all checks required for live provisioning.

---

## Skills and agents

### Full onboarding pipeline

```
                    ┌── provision          (creates Jira tracking issues)
preflight → interview ─┤
                    └── schema-design → migrate-rbac-v1   (implementation)

validate-interview  (run against already-migrated services, independent)
```

### Skill reference

| Command | What it does | When to use |
|---------|-------------|-------------|
| `/kessel-onboarding:preflight` | Validates config, MCP connection, Jira access, and JQL templates | Before first run on a machine and after any config change |
| `/kessel-onboarding:interview` | Phase 0/1 intake — structured Q&A with EM/tech lead, builds ServiceProfile, suggests adoption patterns, dedups Jira | Start of every new service onboarding |
| `/kessel-onboarding:schema-design` | Phase 2 head start — analyzes service codebase and generates draft resource schemas (inventory-api) and permissions schemas (rbac-config KSL + JSON) | After the interview, before Phase 2 begins |
| `/kessel-onboarding:provision` | Dry-run then create Jira issue batch (Initiative + Epic + Phase Stories) from an approved handoff | After the interview, when you're ready to provision Jira issues |
| `/kessel-onboarding:validate-interview` | Scores an interview's accuracy by comparing its ServiceProfile against the service's actual Kessel implementation | After Phase 4+, or retroactively on already-migrated services, to calibrate and improve the interview skill |
| `/kessel-onboarding:migrate-rbac-v1` | Finds v1 RBAC call sites, classifies each by KSL-016 pattern, and writes the actual Kessel v2 replacement code into the service repo (uncommitted) | After schema-design — bridges "onboarding decided what to do" to "here is the code change" |
| `/kessel-onboarding:test` | Full test loop — interview + schema-design with Kessel blindfold on, then auto-validate against real implementation | Against any already-migrated service; primary tool for measuring skill accuracy |

### Agents

| Agent | Orchestrates | Command |
|-------|-------------|---------|
| [Onboarding Interview](agents/onboarding-interview.md) | `onboarding-interview-conduct` → `onboarding-interview-suggest-patterns` → `onboarding-dedup-epic` → `onboarding-format-handoff` | `/kessel-onboarding:interview` |
| [Onboarding Provisioner](agents/onboarding-provisioner.md) | `onboarding-provision-jira` | `/kessel-onboarding:provision` |

The remaining skills (`onboarding-schema-design`, `onboarding-validate-interview`, `onboarding-migrate-rbac-v1`, `onboarding-preflight`) are standalone — they do not require a full agent and can be invoked directly via their slash commands.

### When to run each skill

```
New service → /kessel-onboarding:preflight           (once per machine, only needed for live Jira provisioning)
           → /kessel-onboarding:interview            (Phase 0/1 intake — produces profile + handoff)
           ├── /kessel-onboarding:provision          (creates Jira tracking issues from the handoff)
           └── /kessel-onboarding:schema-design      (Phase 2 — generates KSL + resource schemas)
                   └── /kessel-onboarding:migrate-rbac-v1  (Phase 4 — writes v1→v2 code changes)

Already-migrated service
           → /kessel-onboarding:validate-interview  (score the interview vs real implementation)
           → /kessel-onboarding:test               (full automated loop: blindfolded run + auto-validate)
```

`schema-design` requires codebase access and will ask for a repo URL or local path if the interview did not capture one. It generates local draft files only — no PRs are opened.

`validate-interview` is most useful after Phase 4 (PoC) when the service's Kessel integration is established. Running it retroactively on services like HBI gives a baseline for how accurately the interview predicts implementation needs.

---

### Command examples

#### `/kessel-onboarding:preflight`

```bash
# Run before first use on a machine, or after any config change
/kessel-onboarding:preflight
```

---

#### `/kessel-onboarding:interview`

```bash
# Simplest — just the service name; Claude will ask for everything else
/kessel-onboarding:interview "Activation Keys"

# With provider context (avoids being asked for it during the session)
/kessel-onboarding:interview --provider "Subscription Management" --service "Activation Keys"

# With a known feature epic to link
/kessel-onboarding:interview --provider "Subscription Management" --service "Activation Keys" \
  --feature-epic TUSC-271

# Headless — build profile from an existing notes file, skip live Q&A
/kessel-onboarding:interview --service "Activation Keys" \
  --headless examples/activation-keys-intake-notes.md

# Save only — run the interview but don't offer provisioner dispatch at the end
/kessel-onboarding:interview --provider "Insights" --service "Host Based Inventory" \
  --save-only

# Test mode — Kessel blindfold on; artifacts go to artifacts/test/{slug}/ (for skill testing)
/kessel-onboarding:interview --provider "Insights" --service "Host Based Inventory" \
  --test-mode
```

---

#### `/kessel-onboarding:schema-design`

```bash
# Simplest — profile only; Claude will ask for codebase reference before continuing
/kessel-onboarding:schema-design \
  --profile artifacts/profiles/activation-keys-profile.json

# With codebase reference (avoids being prompted)
/kessel-onboarding:schema-design \
  --profile artifacts/profiles/activation-keys-profile.json \
  --codebase_ref ~/dev/activation-keys

# Custom output directory
/kessel-onboarding:schema-design \
  --profile artifacts/profiles/activation-keys-profile.json \
  --codebase_ref ~/dev/activation-keys \
  --output_dir ~/scratch/activation-keys-schemas

# Test mode — ignores existing KSL and inventory-api schemas; outputs to artifacts/test/{slug}/schemas/
/kessel-onboarding:schema-design \
  --profile artifacts/test/host-based-inventory/profiles/host-based-inventory-profile.json \
  --codebase_ref ~/dev/insights-host-inventory \
  --test-mode
```

---

#### `/kessel-onboarding:provision`

```bash
# Simplest — always dry-runs first and waits for approval before creating anything
/kessel-onboarding:provision \
  --handoff artifacts/profiles/activation-keys-handoff.md

# Explicit dry-run only — present the proposed issue table, stop before the approval prompt
/kessel-onboarding:provision \
  --handoff artifacts/profiles/activation-keys-handoff.md \
  --dry-run

# Skip the dry-run prompt if you've already reviewed the table
/kessel-onboarding:provision \
  --handoff artifacts/profiles/activation-keys-handoff.md \
  --confirm
```

---

#### `/kessel-onboarding:validate-interview`

```bash
# Simplest — codebase only; skips KSL and resource schema dimensions
/kessel-onboarding:validate-interview \
  --profile artifacts/profiles/host-based-inventory-profile.json \
  --codebase_ref ~/dev/insights-host-inventory

# With rbac-config — adds KSL, permissions.json, and roles.json scoring
/kessel-onboarding:validate-interview \
  --profile artifacts/profiles/host-based-inventory-profile.json \
  --codebase_ref ~/dev/insights-host-inventory \
  --rbac_config_path ~/dev/rbac-config

# Full — all repos; scores all 12 interview dimensions
/kessel-onboarding:validate-interview \
  --profile artifacts/profiles/host-based-inventory-profile.json \
  --codebase_ref ~/dev/insights-host-inventory \
  --rbac_config_path ~/dev/rbac-config \
  --inventory_api_path ~/go/src/github.com/tonytheleg/inventory-api

# Full + schema artifacts — adds 4 schema-design dimensions (dimensions 13–16)
/kessel-onboarding:validate-interview \
  --profile artifacts/profiles/host-based-inventory-profile.json \
  --codebase_ref ~/dev/insights-host-inventory \
  --rbac_config_path ~/dev/rbac-config \
  --inventory_api_path ~/go/src/github.com/tonytheleg/inventory-api \
  --schema_artifacts_path artifacts/schemas/host-based-inventory
```

---

#### `/kessel-onboarding:test`

```bash
# Simplest — interview + schema-design (blindfolded) + validate; Claude finds rbac-config/inventory-api automatically
/kessel-onboarding:test \
  --service "Host Based Inventory" \
  --codebase_ref ~/dev/insights-host-inventory

# With provider context
/kessel-onboarding:test \
  --service "Host Based Inventory" \
  --provider "Insights" \
  --codebase_ref ~/dev/insights-host-inventory

# Full — explicit repo paths for complete 16-dimension scoring
/kessel-onboarding:test \
  --service "Host Based Inventory" \
  --provider "Insights" \
  --codebase_ref ~/dev/insights-host-inventory \
  --rbac_config_path ~/dev/rbac-config \
  --inventory_api_path ~/go/src/github.com/tonytheleg/inventory-api
```

---

## Program docs (canonical)

- [Service onboarding checklist](context/phase-checklist.md)
- [Jira issue templates](context/jira-field-mapping.md)
- [Platform readiness gate statuses](context/platform-gates.json)
- [Configuration reference](docs/configuration.md)
- [Data flow and handoff contracts](docs/data-flow.md)

## Jira

- **Filter (all onboarding):** [`labels = kessel-onboarding`](https://redhat.atlassian.net/issues/?jql=labels%20%3D%20kessel-onboarding)
- **Completed services:** `labels = kessel-onboarding AND type = Epic AND status = Done`
- **Office hours:** Tuesdays 8:00–8:30am ET — [meet.google.com/exy-ohre-yov](https://meet.google.com/exy-ohre-yov)

Support: [#forum-mgmt-fabric](https://redhat.enterprise.slack.com/archives/C064X43CMLK)

## Changelog

- 2026-07: Added `test` command and `--test-mode` flag to interview and schema-design; added command examples section covering simple to fully-flagged invocations for all skills.
- 2026-07: Added `schema-design` and `validate-interview` skills; updated quick start, skill reference table, and loading instructions for Claude Code and Cursor.
- 2026-07: Reworded the platform-gates quick-start step — gate status now only affects pattern-suggestion confidence, since Jira gate-linking was removed (the linking skill never had a populated Jira key to link against).
- 2026-07: Corrected the support Slack channel and added `/kessel-onboarding:preflight` as quick-start step 3.

Assisted-by: Claude (Anthropic)
