---
description: Generate draft resource schemas (inventory-api) and permissions schemas (rbac-config) from an approved ServiceProfile.
argument-hint: "--profile PATH [--codebase_ref PATH] [--output_dir PATH]"
---

## Name

kessel-onboarding:schema-design

## Synopsis

```
/kessel-onboarding:schema-design --profile artifacts/profiles/{slug}-profile.json
/kessel-onboarding:schema-design --profile artifacts/profiles/activation-keys-profile.json --codebase_ref ~/dev/activation-keys
/kessel-onboarding:schema-design --profile artifacts/profiles/host-based-inventory-profile.json --output_dir ./schemas-draft
```

## Description

Reads a completed ServiceProfile and generates the schema files a service needs for Kessel integration. Conducts a short follow-up Q&A for reporter naming, v2 permission names, and reporter-specific fields, then writes all output as local files.

**Workflow:** Load profile → Classify asset types → Reporter Q&A → Permission naming Q&A → Generate resource schemas → Generate KSL + permissions.json + roles.json → Present for review

Nothing is written to Jira or any external system. All artifacts land in `./artifacts/schemas/{slug}/` (or `--output_dir`).

## Implementation

Load and execute [skills/onboarding-schema-design/SKILL.md](../skills/onboarding-schema-design/SKILL.md).

## Examples

```
/kessel-onboarding:schema-design --profile artifacts/profiles/activation-keys-profile.json
/kessel-onboarding:schema-design --profile artifacts/profiles/host-based-inventory-profile.json --codebase_ref ~/dev/insights-host-inventory
```

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `--profile PATH` | Yes | Path to `{slug}-profile.json` from Interview Agent |
| `--codebase_ref PATH` | Yes* | GitHub/GitLab URL or local path to service repo. *Can be omitted if the profile already has `interview.codebase_ref` set; otherwise the skill will ask for it before proceeding. |
| `--output_dir PATH` | No | Output directory (default `./artifacts/schemas/{slug}/`) |
| `--test-mode` | No | Activates the Kessel blindfold — ignores existing KSL files, inventory-api resource schema dirs, and Kessel client code during codebase analysis. Artifacts written to `artifacts/test/{slug}/schemas/` instead of `artifacts/schemas/{slug}/`. |

## Return value

Paths to all generated files under the output directory:
- `inventory-api/{asset_type}/` directories (one per resource type)
- `rbac-config/schemas/src/{namespace}.ksl`
- `rbac-config/permissions/{app}.json`
- `rbac-config/roles/{app}.json`
- `README.md` with next steps and validation commands

## Prerequisites

- ServiceProfile must have `asset_types[]`, `v1_permissions`, and `patterns[]` populated (run `/kessel-onboarding:interview` first)
- **Codebase access is required** — the skill will not generate schemas without analyzing the service's source code
- `~/.config/kessel-onboarding/config.json` present (for `artifacts_dir`)
- If the interview was deferred, check for `{slug}-schema-context.md` alongside the profile — it contains interview findings and open questions relevant to schema design

## Changelog

- 2026-07: Initial version.

Assisted-by: Claude (Anthropic)
