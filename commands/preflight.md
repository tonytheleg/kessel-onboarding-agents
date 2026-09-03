---
description: Validates config, MCP connection, Jira access, REST fallback, and JQL templates. Run once per machine and after any config change.
argument-hint: "[--provisioner]"
---

## Name

kessel-onboarding:preflight

## Synopsis

```
/kessel-onboarding:preflight
/kessel-onboarding:preflight --provisioner
```

_For OpenAI, substitute `/kessel-onboarding:preflight` with `@kessel-onboarding onboarding:preflight` for any commands._

## Description

Validates config, MCP connection, Jira access, REST fallback, and JQL templates. Run once per machine and after any config change.

## Implementation

Load and execute [skills/onboarding-preflight/SKILL.md](../skills/onboarding-preflight/SKILL.md).

`--provisioner` enables checks 4–5 (Jira create permission and REST fallback credentials).

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `--provisioner` | No | Also run Provisioner-only checks (Jira create permission, REST fallback credentials) |

## Return value

Summary table (console) with PASS/FAIL per check and remediation guidance for any failures.
