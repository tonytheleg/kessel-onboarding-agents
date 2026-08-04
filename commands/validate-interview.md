---
description: Validate an onboarding interview's accuracy by comparing its ServiceProfile against a service's actual Kessel implementation. Produces a scored alignment report.
argument-hint: "--profile PATH --codebase_ref PATH [--rbac_config_path PATH] [--inventory_api_path PATH]"
---

## Name

kessel-onboarding:validate-interview

## Synopsis

```
/kessel-onboarding:validate-interview --profile artifacts/profiles/{slug}-profile.json --codebase_ref ~/dev/my-service
/kessel-onboarding:validate-interview --profile artifacts/profiles/hbi-profile.json --codebase_ref ~/dev/insights-host-inventory --rbac_config_path ~/dev/rbac-config --inventory_api_path ~/go/src/github.com/tonytheleg/inventory-api
```

## Description

Compares a completed onboarding interview ServiceProfile against the service's actual Kessel implementation across 12 dimensions:

| Dimension | What it checks |
|---|---|
| Tech stack and SDK | Was the right SDK and language identified? |
| Adoption patterns → auth call patterns | Did the KSL-016 pattern selection match how the service actually calls Kessel? |
| V1 permissions → KSL declarations | Do the captured v1 permissions map to real KSL entries? |
| Asset types → KSL type definitions | Are the right resource types defined (or not defined) in the KSL? |
| Permissions.json coverage | Do the captured permissions match what's in rbac-config? |
| Roles.json structure | Are the right roles present? |
| Resource schema (inventory-api) | Are the right resource types registered in inventory-api? |
| UI access checks | Was the v1/v2 UI migration scope correctly identified? |
| Inventory migration | Was the inventory reporting requirement correctly captured? |
| Credential setup | Were service account requirements correctly flagged? |
| Feature flag strategy | Was the dual-path gating strategy correctly anticipated? |
| Ephemeral / Bonfire | Was the pre-dev tooling correctly identified? |

Gaps are classified as **Type A** (interview missed something — candidate for skill improvement) or **Type B** (detail correctly deferred to Phase 2 — expected).

Nothing is written to Jira or any external system.

## Implementation

Load and execute [skills/onboarding-validate-interview/SKILL.md](../skills/onboarding-validate-interview/SKILL.md).

## Examples

```
# Validate HBI interview against its full implementation
/kessel-onboarding:validate-interview \
  --profile artifacts/profiles/host-based-inventory-profile.json \
  --codebase_ref ~/dev/insights-host-inventory \
  --rbac_config_path ~/dev/rbac-config \
  --inventory_api_path ~/go/src/github.com/tonytheleg/inventory-api

# Validate with codebase only (partial — skips schema dimensions)
/kessel-onboarding:validate-interview \
  --profile artifacts/profiles/activation-keys-profile.json \
  --codebase_ref ~/dev/activation-keys
```

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `--profile PATH` | Yes | Path to `{slug}-profile.json` from Interview Agent |
| `--codebase_ref PATH` | Yes | GitHub/GitLab URL or local path to the service's source repo |
| `--rbac_config_path PATH` | No | Local path to rbac-config repo root. Skill will check `~/dev/rbac-config` if not provided. |
| `--inventory_api_path PATH` | No | Local path to inventory-api repo root. Skill will check common Go module paths if not provided. |

## Return value

Path to `{artifacts_dir}/validation/{slug}-validation-report.md` — a scored alignment report with:
- Dimension scorecard (12 dimensions, each ✅/⚠️/❌/➖/⏭️)
- Detail findings per dimension with file references
- Gap classification (Type A: interview improvement candidates vs Type B: expected deferrals)
- Recommendations for interview skill refinement

## When to run

- **After Phase 4 (PoC)** — SDK integration and authorization call patterns are established
- **After Phase 7 (Prod enabled)** — full picture including feature flags, roles, UI migration
- **Retroactively on already-migrated services** — to calibrate the interview skill baseline (as done for HBI)

Running before Phase 4 may produce incomplete results as the Kessel integration is still in progress.

## Changelog

- 2026-07: Initial version. Codifies the manual HBI interview validation process.

Assisted-by: Claude (Anthropic)
