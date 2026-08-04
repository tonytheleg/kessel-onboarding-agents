---
description: Dry-run then create Jira issues (CRCPLAN Initiative, RHCLOUD Epic, Phase Stories) from an approved onboarding_profile handoff.
argument-hint: "--handoff PATH [--confirm] [--dry-run]"
---

## Name

kessel-onboarding:provision

## Synopsis

```
/kessel-onboarding:provision --handoff artifacts/profiles/{slug}-handoff.md
/kessel-onboarding:provision --handoff artifacts/profiles/activation-keys-handoff.md --dry-run
/kessel-onboarding:provision --handoff artifacts/profiles/activation-keys-handoff.md --confirm
```

## Description

Reads an approved `onboarding_profile` handoff and creates a Jira issue batch. Always dry-runs first and waits for EM approval before executing creates.

**Workflow:** Load + validate handoff → Dry-run batch → Gate 0 (EM approves) → Create issues → Gate 1 (confirm keys)

Issues created:

| Type | Project | Notes |
|------|---------|-------|
| Provider Initiative | CRCPLAN | Skipped if `dedup.status = reuse_initiative` |
| Service onboarding Epic | RHCLOUD | Parented to Initiative |
| Phase Stories (0–7, including the 6a/6b split) | RHCLOUD | Epic Linked to Epic |
| UI Story (conditional) | RHCLOUD | Only when `ui_access_checks = required` (migrate) or `new` (implement fresh) |

## Implementation

Load and execute [agents/onboarding-provisioner.md](../agents/onboarding-provisioner.md), which orchestrates:

1. `skills/onboarding-provision-jira/SKILL.md`

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `--handoff PATH` | Yes | Path to `{slug}-handoff.md` from Interview Agent |
| `--dry-run` | No | Show proposed batch only; do not create (default behavior) |
| `--confirm` | No | Skip dry-run prompt if EM already reviewed the table |

## Return value

- Dry-run: table of proposed issues (console)
- After create: paths to `{slug}-jira-keys.json` and updated `{slug}-profile.json` with created keys

## Prerequisites

- `~/.config/kessel-onboarding/config.json` present with `jira_cloud_id`, `initiative_project`, `onboarding_project`
- Atlassian MCP authenticated
- Handoff file contains `Approved by` and `Status: Ready for Jira provision`

## Changelog

- 2026-07: Removed the platform gate linking step — `onboarding-link-platform-gates` was removed (never had a populated Jira key to link against; all gate statuses are now `ready`).
- 2026-07: Updated the Phase Stories row to note the 6a/6b split.

Assisted-by: Claude (Anthropic)
