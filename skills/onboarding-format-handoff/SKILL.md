---
name: onboarding-format-handoff
description: >
  Packages an EM-approved ServiceProfile as an onboarding_profile handoff block
  for the Onboarding Provisioner Agent. Used by onboarding-interview agent
  after profile and dedup approval.
---

# Onboarding format handoff

## When to use

- Called automatically by the `onboarding-interview` agent after the EM has approved the ServiceProfile (Gate 1) and dedup has resolved cleanly.
- Never invoke before Gate 1 approval — the handoff block is meant to represent an EM-approved profile, not a draft.

## Prerequisites

- Gate 1 passed: EM said "Approve profile" or equivalent
- ServiceProfile JSON is complete (patterns, dedup, gates populated)

## Inputs

| Input | Required |
|-------|----------|
| ServiceProfile JSON path | yes |
| `approved_by` | EM name |
| `em_notes` | optional |

## Execution

### Step 1 — Load profile

Read `{slug}-profile.json`. Validate required fields per [handoff-schema.md](handoff-schema.md).

If `dedup.status` is `duplicate_found` and no EM exception note, **stop** and remind EM to resolve duplicate first.

### Step 2 — Build handoff block

Fill template from [handoff-schema.md](handoff-schema.md):

- `Approval date`: today's date (ISO)
- `Adoption patterns`: one bullet per `patterns[]` entry
- `Platform gates`: one bullet per `platform_gates[]` entry
- Paths: repo-relative paths to profile and summary files

### Step 3 — Write artifact

```
{artifacts_dir}/profiles/{slug}-handoff.md
```

File contains only the handoff block (fenced or plain per runtime).

### Step 4 — Gate 2 (orchestrator)

Return control to the orchestrator, which presents the Gate 2 options to the EM — see [agents/onboarding-interview.md](../../agents/onboarding-interview.md#step-7--gate-2-handoff-dispatch) for the current option set (schema design now/later, dispatch to provisioner, save only, or revise). Do not duplicate that list here — it changes independently of this skill.

### Step 5 — Return

Return handoff path and full block text to orchestrator.

## Outputs

| Output | Path |
|--------|------|
| Handoff block | `{artifacts_dir}/profiles/{slug}-handoff.md` |

## Example

See pilot output at [examples/activation-keys-handoff.md](../../examples/activation-keys-handoff.md).
