---
HANDOFF: ONBOARDING PROFILE
---
Schema version: 1.2
Source agent:   Onboarding Interview Agent
Approved by:    Example EM (human gate ✓)
Approval date:  2026-06-11

Provider:       Subscription Management
Service:        Activation Keys
Home project:   TUSC
Feature epic:   TUSC-271
Wave:           2
Onboarding path: self-service

Adoption patterns:
- Default workspace (high) — Workspace-scoped assets with standard Check calls (StreamedListObjects not required at this scale)

UI access checks: not_required
Inventory migration: not required
Tech stack:     Java, Quarkus, Kessel SDK
Credentials:      CMDB yes; service account stage_only
Platform gates:
- Platform Readiness: Default workspace (TBD)
- Platform Readiness: SDK / client (TBD)
- Platform Readiness: Ephemeral infra (TBD)

Dedup status:   clean
Dedup notes:    Dry-run pilot — dedup simulated

Contacts:
- PM: Example PM <pm@example.com>
- EM: Example EM <em@example.com>
- Tech lead: Example Tech Lead <tech@example.com>

ServiceProfile: artifacts/profiles/activation-keys-profile.json
Summary:        artifacts/profiles/activation-keys-summary.md

EM notes:       Wave 2 pilot — first subscription-management service in Default workspace pattern

Next agent:     Onboarding Provisioner Agent
Status:         Ready for Jira provision (dry-run)
---

## Changelog

- 2026-07: Bumped schema version to 1.2, matching the paired `activation-keys-profile.json` example (no content change — this example doesn't exercise `new` `ui_access_checks` or multi-pattern `asset_types`, both still valid at 1.0/1.1 shape).
- 2026-07: Bumped schema version to 1.1 and added the Inventory migration and Credentials lines, matching the paired `activation-keys-profile.json` example.
- 2026-07: Fixed API terminology in the pattern rationale to use the correct v1beta2 call names.

Assisted-by: Claude (Anthropic)
