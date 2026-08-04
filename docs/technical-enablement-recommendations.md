# Technical enablement recommendations

> Deferred to the engineering team building the detailed onboarding skills/agents. These recommendations are grounded in the Kessel ecosystem repos; treat as a starting spec, not a mandate.

## KSL starter schema skill

Given intake `v1_permissions`, generate a draft `.ksl` file using `@rbac.add_v1_based_permission()` (and `@rbac.add_contingent_permission()` for host-centric assets), following the conventions in the public migration guide and the existing schemas in `rbac-config/configs/stage/schemas/src/` (16 working examples).

**Output:** a ready-to-review PR body for `rbac-config`. Turns Phase 2 from "go figure it out" into "review this draft."

## Inventory ingestion decision table

One context doc comparing the three real ingestion paths with when-to-use guidance:

- Direct `ReportResource` gRPC calls (SDK)
- Kafka topic consumed by `kessel-inventory-consumer` (KIC)
- Debezium outbox via `kessel-kafka-connect` (HBI's migration and outbox connectors are working reference implementations)

Attach to the Phase 3 story description.

## SDK pointer by tech stack

Intake already captures `tech_stack.lang`; emit the matching SDK link (Go, Python, Java, Ruby) plus the authentication quickstart in the handoff and Epic description.

## Deploy cadence note

`rbac-config` deploys stage every Tuesday and prod every Thursday; Phase 2 merge timing and Phase 6a/7 enablement dates depend on this cadence. Belongs in the phase checklist once confirmed current.
