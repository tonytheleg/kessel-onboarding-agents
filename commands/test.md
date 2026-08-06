---
description: Run the full skill test loop against an already-onboarded service — interview + schema-design in test mode (Kessel blindfold on), then auto-validate against the real implementation. Used to measure and improve the interview and schema-design skills.
argument-hint: "--service NAME --codebase_ref PATH [--provider NAME] [--rbac_config_path PATH] [--inventory_api_path PATH]"
---

## Name

kessel-onboarding:test

## Synopsis

```
/kessel-onboarding:test --service "Host Based Inventory" --codebase_ref ~/dev/insights-host-inventory
/kessel-onboarding:test --service "Activation Keys" --provider "Subscription Management" --codebase_ref ~/dev/activation-keys --rbac_config_path ~/dev/rbac-config --inventory_api_path ~/go/src/github.com/tonytheleg/inventory-api
```

## Description

Runs the onboarding interview and schema-design skills against a service that has already been onboarded to Kessel, with a **Kessel blindfold** active — existing SDK code, permission classes, KSL files, and inventory-api resource schemas are ignored during analysis. The skills derive their answers from the pre-Kessel signals in the codebase (v1 RBAC patterns, domain models, tech stack), exactly as they would for a net-new service.

After the skills complete, the validate-interview skill automatically scores the outputs against the service's real implementation and produces a gap report.

**This loop is the primary mechanism for testing and improving the interview and schema-design skills.**

**Workflow:**
```
interview (--test-mode)
    → schema-design (--test-mode)
        → validate-interview
            → gap report
```

All artifacts land in `artifacts/test/{slug}/` — nothing is written to `artifacts/profiles/`, `artifacts/schemas/`, or any external system.

## Implementation

Execute the following sequence, passing `test_mode = true` throughout:

1. Run `agents/onboarding-interview.md` with `--test-mode` and the supplied flags.
   - Artifacts → `{artifacts_dir}/test/{slug}/profiles/`
   - At Gate 2, skip provisioner and schema-design prompts — proceed directly to step 2.

2. Run `skills/onboarding-schema-design/SKILL.md` with `--test-mode` using the profile from step 1.
   - Artifacts → `{artifacts_dir}/test/{slug}/schemas/`

3. Run `skills/onboarding-validate-interview/SKILL.md` using:
   - `--profile` = test profile from step 1
   - `--codebase_ref` = same codebase used in steps 1–2
   - `--rbac_config_path` = if provided
   - `--inventory_api_path` = if provided
   - `--schema_artifacts_path` = `{artifacts_dir}/test/{slug}/schemas/` (output from step 2)
   - `--output_path` = `{artifacts_dir}/test/{slug}/validation-report.md`

4. Print a final summary:
   ```
   ⚗️  Test loop complete — {service.name}

   Artifacts:
     Profile:    artifacts/test/{slug}/profiles/{slug}-profile.json
     Summary:    artifacts/test/{slug}/profiles/{slug}-summary.md
     Schemas:    artifacts/test/{slug}/schemas/
     Validation: artifacts/test/{slug}/validation-report.md

   Interview score:      {X}/12 dimensions matched or partially matched
   Schema-design score:  {Y}/4  dimensions matched or partially matched
   Type A gaps (interview improvements):       {N}
   Type B gaps (expected Phase 2 deferrals):   {N}
   Type C gaps (schema-design improvements):   {N}
   ```

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `--service NAME` | Yes | Service name to test against |
| `--codebase_ref PATH` | Yes | Local path or GitHub/GitLab URL to the service's source repo |
| `--provider NAME` | No | Provider name for Initiative context |
| `--rbac_config_path PATH` | No | Local path to rbac-config repo root (enables KSL and permissions validation). Checks `~/dev/rbac-config` if omitted. |
| `--inventory_api_path PATH` | No | Local path to inventory-api repo root (enables resource schema validation). Checks common Go module paths if omitted. |

## Return value

Paths to all test artifacts under `artifacts/test/{slug}/`, plus a printed score summary.

## When to use

- Testing the interview skill against a newly-migrated service to see how well it would have guided them
- After modifying interview questions, to measure whether the change improved prediction accuracy
- Onboarding team calibration — run against several already-migrated services to establish a baseline score

## What "test mode" ignores

The Kessel blindfold applied during interview and schema-design:

| Ignored | Kept |
|---|---|
| `kessel-sdk` dependency | Language, framework |
| `KesselPermission`, `KesselResourceType` classes | v1 RBAC enums (`RbacPermission`, `RbacResourceType`) |
| `lib/kessel.py`, Kessel client setup | `/rbac/v1/access` calls (for `ui_access_checks`) |
| `Check`, `CheckBulk`, `ListAllowedWorkspaces` calls | Domain model classes, DB migrations |
| Feature flags gating Kessel (`FLAG_RBAC_WORKSPACES`, `bypass_kessel`) | ClowdApp/Bonfire config |
| Existing `.ksl` files in rbac-config | v1 permissions/roles JSON files in rbac-config |
| Existing inventory-api resource schema dirs | API endpoint handlers |

## Changelog

- 2026-07: Initial version.

Assisted-by: Claude (Anthropic)
