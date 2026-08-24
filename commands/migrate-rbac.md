---
description: Migrate a service's RBAC v1 authorization calls to Kessel/RBAC v2. Finds v1 call sites, classifies each by KSL-016 pattern, fills schema gaps, and writes the actual replacement code for review. Run after schema-design for best results.
argument-hint: "--rbac <path> [--context <path> | --rbac-config <path>] [--inventory-api <path>] [--profile <path>] [<service-repo>]"
---

## Name

kessel-onboarding:migrate-rbac-v1

## Synopsis

```bash
# Best path — after schema-design deferred migration (context has v2 names + patterns pre-loaded)
/kessel-onboarding:migrate-rbac-v1 \
  --rbac /path/to/insights-rbac \
  --context artifacts/schemas/task-manager/migrate-context.md \
  ~/dev/my-service

# After an interview only — use the profile to skip pattern re-derivation
/kessel-onboarding:migrate-rbac-v1 \
  --rbac /path/to/insights-rbac \
  --rbac-config /path/to/rbac-config \
  --profile artifacts/profiles/task-manager-profile.json \
  ~/dev/my-service

# Standalone — no prior onboarding, discovers everything from the repo
/kessel-onboarding:migrate-rbac-v1 \
  --rbac /path/to/insights-rbac \
  --rbac-config /path/to/rbac-config \
  ~/dev/my-service

# With inventory-api (needed for native / native-ws-list resource schemas)
/kessel-onboarding:migrate-rbac-v1 \
  --rbac /path/to/insights-rbac \
  --rbac-config /path/to/rbac-config \
  --inventory-api /path/to/inventory-api \
  --context artifacts/schemas/task-manager/migrate-context.md \
  ~/dev/my-service
```

## Description

Bridges the gap between "onboarding decided what to do" and "here is the actual code change." Runs five phases:

1. **Discover** — finds every v1 RBAC call site in the service repo and checks Kessel enablement gates
2. **Classify** — assigns each permission to a KSL-016 pattern (native / native-ws-list / default-workspace)
3. **Schema** — checks rbac-config for existing v2 mappings; generates a minimal scaffold if missing, or delegates to the `kessel-onboarding:schema-design` skill if available
4. **Code** — writes the actual Kessel replacement code into the service repo (uncommitted), preserving the v1 dual-path fallback
5. **Report** — prints a summary and writes the full report to `/tmp/migrate-v1-rbac/{service}/report.md`

Nothing is committed or pushed. All changes land in the working tree for review via `git diff`.

**With `--profile`:** cross-checks Phase 1 findings against the ServiceProfile's `v1_permissions`, and uses its `patterns[]` directly in Phase 2 instead of re-running the decision tree. This eliminates redundant Q&A when the interview has already been run.

## Implementation

Load and execute [skills/onboarding-migrate-rbac-v1/SKILL.md](../skills/onboarding-migrate-rbac-v1/SKILL.md).

## Arguments

| Argument | Required | Description |
|---|---|---|
| `<service-repo>` | Yes | Local path or git URL to the service to migrate |
| `--rbac <path>` | Yes | Local path or git URL to `insights-rbac` (workspace lookup API reference) |
| `--rbac-config <path>` | Yes* | Local path or git URL to `rbac-config` (*optional only if `--profile` already supplies all v2 permission names) |
| `--inventory-api <path>` | No | Local path or git URL to `inventory-api` — needed when Phase 3 must generate resource schemas for native patterns |
| `--context <path>` | No | Path to `migrate-context.md` written by schema-design Gate 2 "migrate later". Highest-fidelity start — pre-loads v2 permission names, patterns, and all repo paths. Takes precedence over `--profile`. |
| `--profile <path>` | No | Path to a ServiceProfile JSON from the onboarding interview — eliminates redundant pattern classification. Use when schema-design was not run. |

## Return value

- Code changes written to the service repo (uncommitted)
- Schema scaffold (if generated) written to `/tmp/migrate-v1-rbac/{service}/schema/`
- Migration report at `/tmp/migrate-v1-rbac/{service}/report.md`

## When to use

Run after `/kessel-onboarding:schema-design` to translate the onboarding decisions into actual service code. Can also run standalone without a prior interview if only code migration is needed.

## Changelog

- 2026-08: Initial version — added to kessel-onboarding plugin as the code-migration step following schema-design.

Assisted-by: Claude (Anthropic)
