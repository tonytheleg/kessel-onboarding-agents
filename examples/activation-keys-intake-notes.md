# Intake notes — Activation Keys (wave 2 pilot)

Provider: Subscription Management
Service: Activation Keys
Home Jira project: TUSC
Feature epic: TUSC-271
Wave: 2

## Contacts

- PM: Example PM (pm@example.com)
- EM: Example EM (em@example.com)
- Tech lead: Example Tech Lead (tech@example.com)

## Phase 0

- Checklist and migration guide reviewed: yes
- UI v1 access checks: Not required (backend-only service)

## Phase 1

- Tech stack: Java, Quarkus, Kessel SDK
- Asset types: activation_key
- v1 permissions: config_manager:activation_keys:read, config_manager:activation_keys:write (workspace-scoped)
- Inventory reporting: no
- Ephemeral/Bonfire: yes

## Notes

Wave 2 self-service pilot. Default workspace pattern expected. First subscription-management service to onboard in this pattern.

## Changelog

- 2026-07: Corrected v1 permissions to the real three-part `config_manager:activation_keys:{read,write}` names.

Assisted-by: Claude (Anthropic)
