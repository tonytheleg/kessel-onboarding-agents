# Kessel Onboarding Agents

AI agents and skills for the Kessel service onboarding program. Jira remains the system of record; agents propose artifacts and humans approve writes.

## Loading this plugin

### Claude Code (CLI or desktop app)

**Session-only (recommended for testing):**
```bash
claude --plugin-dir /path/to/kessel-onboarding-agents
```
The `--plugin-dir` flag can be repeated to load multiple plugins simultaneously. Skills and slash commands are available for that session only — nothing is written to your global config.

**Persistent (installed for all sessions):**

Claude Code also supports installing plugins permanently via the `/install-plugin` command or the settings UI. For a local repo, point it at the directory. For a shared team plugin, the repo can be packaged as a `.zip` or hosted at a URL:

```bash
# Load from a URL for this session
claude --plugin-url https://example.com/kessel-onboarding-agents.zip

# Or install permanently via the CLI
claude  # then inside the session:
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

## Quick start

1. Copy [docs/configuration.md](docs/configuration.md) to `~/.config/kessel-onboarding/config.json` and fill in your Jira cloud ID and allowed projects.
2. Update [context/platform-gates.json](context/platform-gates.json) if a pattern's platform readiness status changes — this only affects pattern-suggestion confidence and the paired-vs-self-service default for wave 3+ services; it no longer drives any Jira linking.
3. Run `/kessel-onboarding:preflight` to validate config, MCP connectivity, Jira access, and JQL templates.
4. Run an intake session:

```
/kessel-onboarding:interview --provider "Subscription Management" --service "Activation Keys"
```

5. Review the generated ServiceProfile and handoff in `./artifacts/profiles/`.
6. Optionally design schemas: `/kessel-onboarding:schema-design --profile artifacts/profiles/{slug}-profile.json --codebase_ref ~/dev/my-service`
7. Hand off to the Provisioner Agent: `/kessel-onboarding:provision --handoff artifacts/profiles/{slug}-handoff.md`

---

## Skills and agents

### Full onboarding pipeline

```
preflight → interview → schema-design → provision
                ↓
          validate-interview  (run against already-migrated services)
```

### Skill reference

| Command | What it does | When to use |
|---------|-------------|-------------|
| `/kessel-onboarding:preflight` | Validates config, MCP connection, Jira access, and JQL templates | Before first run on a machine and after any config change |
| `/kessel-onboarding:interview` | Phase 0/1 intake — structured Q&A with EM/tech lead, builds ServiceProfile, suggests adoption patterns, dedups Jira | Start of every new service onboarding |
| `/kessel-onboarding:schema-design` | Phase 2 head start — analyzes service codebase and generates draft resource schemas (inventory-api) and permissions schemas (rbac-config KSL + JSON) | After the interview, before Phase 2 begins |
| `/kessel-onboarding:provision` | Dry-run then create Jira issue batch (Initiative + Epic + Phase Stories) from an approved handoff | After the interview, when you're ready to provision Jira issues |
| `/kessel-onboarding:validate-interview` | Scores an interview's accuracy by comparing its ServiceProfile against the service's actual Kessel implementation | After Phase 4+, or retroactively on already-migrated services, to calibrate and improve the interview skill |
| `/kessel-onboarding:test` | Full test loop — interview + schema-design with Kessel blindfold on, then auto-validate against real implementation | Against any already-migrated service; primary tool for measuring skill accuracy |

### Agents

| Agent | Orchestrates | Command |
|-------|-------------|---------|
| [Onboarding Interview](agents/onboarding-interview.md) | `onboarding-interview-conduct` → `onboarding-interview-suggest-patterns` → `onboarding-dedup-epic` → `onboarding-format-handoff` | `/kessel-onboarding:interview` |
| [Onboarding Provisioner](agents/onboarding-provisioner.md) | `onboarding-provision-jira` | `/kessel-onboarding:provision` |

The remaining skills (`onboarding-schema-design`, `onboarding-validate-interview`, `onboarding-preflight`) are standalone — they do not require a full agent and can be invoked directly via their slash commands.

### When to run each skill

```
New service → /kessel-onboarding:preflight      (once per machine)
           → /kessel-onboarding:interview       (Phase 0/1 intake)
           → /kessel-onboarding:schema-design   (Phase 2 — before schema modeling begins)
           → /kessel-onboarding:provision       (when ready to create Jira issues)

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
