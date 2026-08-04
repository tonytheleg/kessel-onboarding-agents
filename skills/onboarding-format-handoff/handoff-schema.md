# onboarding_profile handoff schema v1.2

Artifact type for handoff from **Onboarding Interview Agent** to **Onboarding Provisioner Agent**.

## Block format

```
---
HANDOFF: ONBOARDING PROFILE
---
Schema version: 1.2
Source agent:   Onboarding Interview Agent
Approved by:    {EM name} (human gate ✓)
Approval date:  {ISO date}

Provider:       {provider.name}
Service:        {service.name}
Home project:   {jira.home_project}
Feature epic:   {jira.feature_epic_key}
Wave:           {program.wave}
Onboarding path: {program.path}

Adoption patterns:
- {pattern.label} ({confidence}) — {rationale one line} {— applies to: {pattern.asset_types[]} — only when patterns.length > 1}

UI access checks: {ui_access_checks}
Inventory migration: {required | not required}
Tech stack:     {tech_stack.lang}, {tech_stack.framework}, {tech_stack.auth}
Credentials:      CMDB {yes/no/unknown}; service account {status}
Platform gates:
- {epic_summary} ({jira_key or TBD})

Dedup status:   {dedup.status}
Dedup notes:    {dedup.notes or none}

Contacts:
- PM: {contacts.pm.name} <{contacts.pm.email}>
- EM: {contacts.em.name} <{contacts.em.email}>
- Tech lead: {contacts.tech_lead.name} <{contacts.tech_lead.email}>

ServiceProfile: {absolute or repo-relative path to JSON}
Summary:        {path to summary MD}

EM notes:       {optional freeform}

Next agent:     Onboarding Provisioner Agent
Status:         Ready for Jira provision (dry-run)
---
```

## Required before packaging

- EM explicitly approved profile (Gate 1)
- `dedup.status` is not `duplicate_found` OR EM documented exception
- `patterns[]` non-empty
- `jira.feature_epic_key` present or EM waived with note

## Versioning

Increment minor version for additive fields; major for breaking renames. Provisioner must read `Schema version` line.

## Machine-readable companion

Provisioner should read the ServiceProfile JSON at `ServiceProfile` path as authoritative; the handoff block is human-auditable summary.

## Changelog

- 2026-07: Bumped schema version to 1.2 (matches ServiceProfile: `new` `ui_access_checks` value and `pattern.asset_types[]`; earlier-version handoffs remain valid).
- 2026-07: Noted `pattern.asset_types[]` in the Adoption patterns line for multi-pattern services.
- 2026-07: Bumped schema version to 1.1; added the Inventory migration and Credentials lines to the block format.

Assisted-by: Claude (Anthropic)
