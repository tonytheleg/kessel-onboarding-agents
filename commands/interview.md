---
description: Run Kessel onboarding Phase 0/1 intake and produce an approved onboarding_profile handoff.
argument-hint: "[service name] [--provider NAME] [--feature-epic KEY] [--headless] [--save-only]"
---

## Name

kessel-onboarding:interview

## Synopsis

```
/kessel-onboarding:interview [service name]
/kessel-onboarding:interview --provider "Subscription Management" --service "Activation Keys"
/kessel-onboarding:interview --feature-epic TUSC-271 --service "Activation Keys"
/kessel-onboarding:interview --headless @intake-notes.md
/kessel-onboarding:interview --service "Activation Keys" --save-only
```

## Description

Structured intake with the service EM and tech lead. Builds a ServiceProfile, suggests adoption patterns, dedups existing Jira onboarding work, and packages an EM-approved handoff for the Provisioner Agent.

**Workflow:** Session setup → Interview → Pattern suggestion → Dedup → EM approves profile → Handoff block

Nothing is written to Jira. Artifacts land in `./artifacts/profiles/`.

## Implementation

Load and execute [agents/onboarding-interview.md](../agents/onboarding-interview.md), which orchestrates:

1. `skills/onboarding-interview-conduct/SKILL.md`
2. `skills/onboarding-interview-suggest-patterns/SKILL.md`
3. `skills/onboarding-dedup-epic/SKILL.md`
4. `skills/onboarding-format-handoff/SKILL.md` (after EM approval)

## Examples

```
/kessel-onboarding:interview Activation Keys
/kessel-onboarding:interview --provider "Subscription Management" --service "Activation Keys"
/kessel-onboarding:interview --feature-epic TUSC-271 --service "Activation Keys"
/kessel-onboarding:interview --headless examples/activation-keys-intake-notes.md
```

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| service name | Yes* | Deployable service name (*or `--service`) |
| `--provider` | No | Provider / tenant name for Initiative context |
| `--service` | No | Service name (alternative to positional) |
| `--feature-epic KEY` | No | Existing feature epic for relates-to link |
| `--headless` | No | Build profile from file/notes; skip live Q&A |
| `--save-only` | No | Write handoff; do not invoke Provisioner |

## Return value

Paths to `{slug}-profile.json`, `{slug}-summary.md`, and `{slug}-handoff.md` under `artifacts/profiles/`.
