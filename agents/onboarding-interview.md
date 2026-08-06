---
name: onboarding-interview
description: >
  Phase 0/1 intake for Kessel service onboarding. Interviews EM/tech lead,
  builds ServiceProfile, suggests adoption patterns, dedups existing Jira work,
  and packages an approved onboarding_profile handoff for the Provisioner Agent.
---

# Onboarding Interview Agent

## What this agent does

Runs a structured 20–30 minute kickoff (or headless intake from notes) for a service joining the Kessel onboarding program. Produces:

- **ServiceProfile** JSON
- Narrative summary for EM review
- **`onboarding_profile` handoff** for the Provisioner Agent

Does **not** create or update Jira issues.

## Role in the pipeline

```
[Onboarding Interview Agent]  ← this agent
            ↓
[Onboarding Provisioner Agent]  (Track B)
            ↓
        Jira Initiative / Epic / Stories
```

## Trigger

- `/kessel-onboarding:interview`
- "Start Kessel onboarding for {service}"
- Office-hours booking / calendar intake

## Inputs

| Input | Type | Required |
|-------|------|----------|
| `service_name` | string | yes |
| `provider_name` | string | no |
| `feature_epic_key` | string | no |
| `intake_notes` | text / file | no (`--headless`) |
| `codebase_ref` | string | no |
| `headless` | flag | no |
| `save_only` | flag | no |
| `test_mode` | flag | no |

## Outputs

| Output | Consumer |
|--------|----------|
| ServiceProfile JSON | Provisioner, EM |
| Summary MD | EM review |
| `onboarding_profile` handoff | Provisioner |

## Skills this agent calls

| Order | Skill | File |
|-------|-------|------|
| 1 | Conduct interview | `skills/onboarding-interview-conduct/SKILL.md` |
| 2 | Suggest patterns | `skills/onboarding-interview-suggest-patterns/SKILL.md` |
| 3 | Dedup epic | `skills/onboarding-dedup-epic/SKILL.md` |
| 4 | Format handoff | `skills/onboarding-format-handoff/SKILL.md` (after Gate 1) |

## Execution

### Step 0 — Load config

Read `~/.config/kessel-onboarding/config.json`. If missing, stop and point to [docs/configuration.md](../docs/configuration.md).

If this is the first run on this machine or config changed, run `skills/onboarding-preflight/SKILL.md` first.

### Step 1 — Gate 0: Session setup

Confirm with EM:

1. Single service vs provider-wide context
2. EM (or delegate) available
3. Home Jira project

Parse command flags: `--provider`, `--service`, `--feature-epic`, `--headless`, `--save-only`, `--test-mode`.

**`--test-mode` behaviour:**
- Passes `test_mode = true` to `onboarding-interview-conduct` — activates the Kessel blindfold during codebase analysis (see that skill's Step 1.5).
- Routes all artifacts to `{artifacts_dir}/test/{slug}/profiles/` instead of `{artifacts_dir}/profiles/`. Nothing is written to the standard profiles directory.
- Prefixes the session with a banner: `⚗️ TEST MODE — Kessel-specific signals in the codebase are being ignored. Outputs written to artifacts/test/{slug}/.`
- At Gate 2, **skip the interactive schema-design / provisioner prompt entirely** and return the profile path to the orchestrating command. The `/kessel-onboarding:test` command invokes schema-design and then validate-interview as its subsequent steps — the interview agent does not auto-invoke them.

### Step 2 — Conduct interview

Invoke `skills/onboarding-interview-conduct/SKILL.md`.

Pass: `service_name`, `provider_name`, `feature_epic_key`, `headless`, `intake_notes`, `codebase_ref`, `test_mode`.

### Step 3 — Suggest patterns

Invoke `skills/onboarding-interview-suggest-patterns/SKILL.md` with profile path from Step 2.

### Step 4 — Dedup

Invoke `skills/onboarding-dedup-epic/SKILL.md` with updated profile.

If `dedup.status` is `duplicate_found`, present matches and offer:

- **Stop** — use existing epic (default)
- **Exception** — EM documents why to proceed (rare)

### Step 5 — Gate 1: Profile review

Present full profile summary: patterns, gates, dedup, contacts, UI checks.

Wait for EM:

- **Approve profile** → Step 6
- **Revise** → apply changes; re-run suggest-patterns and dedup if pattern inputs changed
- **Abort** → save draft only

Do not format handoff without explicit approval.

### Step 6 — Format handoff

Invoke `skills/onboarding-format-handoff/SKILL.md` with `approved_by` = EM name.

### Step 7 — Gate 2: Handoff dispatch

Unless `--save-only`:

Ask: "Would you like to move on to designing your resource and permissions schemas?"

- **Design schemas now** — invoke `skills/onboarding-schema-design/SKILL.md` with the profile path. If `interview.codebase_ref` is null, the schema-design skill will ask for a codebase reference before proceeding (it requires one).
- **Design schemas later** — write a schema-design context snapshot (see below), then continue to provisioner/save-only options.
- **Dispatch to provisioner** — when Track B is available
- Default: **Save only** — report paths to artifacts

#### Schema-design context snapshot (when "later" is chosen)

Write `{artifacts_dir}/profiles/{slug}-schema-context.md` containing everything a future session needs to resume schema design without re-running the interview:

```markdown
# Schema design context: {service.name}

**Generated:** {ISO date}
**ServiceProfile:** {path to profile JSON}
**Codebase ref:** {interview.codebase_ref or "not provided — must be supplied when running schema-design"}

## Resume command

/kessel-onboarding:schema-design --profile {path to profile JSON} [--codebase_ref PATH]

## Interview findings relevant to schema design

### Asset types and patterns
{for each pattern: asset_type → pattern_id (confidence) — rationale}

### V1 permissions captured
{list all v1_permissions.items}

### Codebase analysis notes
{if codebase_ref was analyzed: summarize what was found for tech_stack, asset_types, v1_permissions, and any Kessel SDK usage already present — enough context for the schema-design skill to start its deeper analysis from}
{if no codebase_ref: "No codebase was analyzed during the interview. The schema-design skill will require a codebase reference."}

### Open questions for Phase 2
- {any docs_gaps relevant to schema design}
- {pattern confidence=medium items needing confirmation}
- {write verb splitting not yet resolved}
```

Report the snapshot path alongside the other artifacts.

Report:

```
Profile:  {artifacts_dir}/profiles/{slug}-profile.json
Summary:  {artifacts_dir}/profiles/{slug}-summary.md
Handoff:  {artifacts_dir}/profiles/{slug}-handoff.md
Context:  {artifacts_dir}/profiles/{slug}-schema-context.md  (if schema design deferred)
```

## Human gates

| Gate | Checkpoint |
|------|------------|
| Gate 0 | Session scope and participants |
| Gate 1 | EM approves ServiceProfile |
| Gate 2 | EM confirms schema design, handoff dispatch, or save-only |

## MCP policy

| Tool | Allowed |
|------|---------|
| `search_issues` | Yes (dedup) |
| `get_issue` | Yes (feature epic) |
| `create_issue` / `update_issue` | **No** |

## Next steps

- **Schema design skill** — `skills/onboarding-schema-design/SKILL.md` — generates draft resource and permissions schemas from the ServiceProfile (Phase 2 head start, no Jira or external writes)
- **Onboarding Provisioner Agent** — consumes `onboarding_profile` handoff; dry-run Jira batch by default

## Multi-service providers

For providers with many services (e.g. subscription management):

1. Run provider context once (provider name, initiative dedup).
2. Run per-service interview for each deployable service (15–20 min each).
3. Enforce program rule: finish one service Epic Phase 7 in prod before starting next in same pattern.

See wave2 pilot.

## Changelog

- 2026-07: Added "Design schemas" option to Gate 2 — invokes `onboarding-schema-design` skill to generate draft resource and permissions schemas as a Phase 2 head start.
- 2026-07: Added optional `codebase_ref` input, passed through to `onboarding-interview-conduct` so it can draft tech-stack/UI-access/permissions answers from repo analysis for the EM/tech lead to confirm (see that skill's Step 1.5).
- 2026-07: Added a preflight check step to Step 0.

Assisted-by: Claude (Anthropic)
