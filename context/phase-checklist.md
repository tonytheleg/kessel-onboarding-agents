# Phase checklist

Source: [HCC / Kessel Service Onboarding Plan (DRAFT)](https://docs.google.com/document/d/1Fa9JaJwMtf3adgwy3nwek9lJYR3iadVKhB6WufSJJQk/).

Interview Agent covers **Phase 0 and Phase 1** only. All phases are tracked as Jira Stories under the service onboarding Epic.

---

## Jira label convention

Every issue: `kessel-onboarding`

Each phase Story also gets a **stable, slug-based phase label** for filtering. Slugs carry no ordinal number — they identify the phase's *content*, not its position. This means the display order (the "Phase N" numbering below and in story summaries) can change without ever touching an existing issue's label or breaking a saved JQL filter/dashboard.

| Phase (current display order) | Phase label (stable slug) |
|-------------------------------|---------------------------|
| 0 — Kickoff | `kessel-phase:kickoff` |
| 1 — Identify adoption pattern(s) | `kessel-phase:adoption-pattern` |
| 2 — Model permissions and schema | `kessel-phase:permissions-schema` |
| 3 *(conditional — services with inventory assets only)* — Inventory migration | `kessel-phase:inventory-migration` |
| 4 — PoC | `kessel-phase:poc` |
| 5 — Verified in dev environment | `kessel-phase:dev-verified` |
| 6a — Stage enabled | `kessel-phase:stage-enabled` |
| 6b — Feature flag audit | `kessel-phase:ff-audit` |
| 7 — Prod enabled and verified | `kessel-phase:prod-enabled` |
| UI (conditional, non-numbered) | `kessel-phase:ui-migration` |

**Why this matters:** if the display numbering is ever revised (renumbered, phases inserted/split), only this table and the story summary text change. No existing Jira issue needs relabeling, and every JQL filter or dashboard built on `kessel-phase:{slug}` keeps working across old and new cohorts.

Every Epic also gets a **scheme version label** recording which version of this checklist was used to provision it: `kessel-phase-scheme:v1`. Bump this when phases are materially restructured (not just renumbered) so reporting tools know which mapping table applies to a given epic's vintage.

Every Epic also gets `kessel-pattern:{id}` for its adoption pattern(s), enabling exact-match pattern queries.

---

## Feature flag naming convention

Every service's Kessel v2 enablement flag follows a standard name: **`<service>.kessel-check.enable`** (e.g. `activation-keys.kessel-check.enable`). Adopted 2026-07 to replace inconsistent prior naming across services (`KESSEL_ENABLED` and various ad hoc flag names).

- `<service>` is the same slug used as `service.slug` elsewhere in this program (kebab-case).
- The flag gates the v2 Kessel `Check`/`ListObjects` calls; when `true`, the service reads authorization decisions from Kessel instead of v1 RBAC for the resources in scope.
- Referenced in Phase 5 (enabled in dev), Phase 6a (enabled in stage), Phase 6b (audited before prod), and Phase 7 (enabled in prod).
- **Org-wide impact — read before flipping:** enabling this flag can disable **v1 access checks for the entire org**, not only for the resource(s) being migrated. Any other feature in that org still relying on v1 checks loses enforcement until it is also migrated. See the explicit warning in Phase 6a below.

---

## Phase 0 — Kickoff

**Story summary:** `Phase 0: Kickoff — {service.name}`
**Label:** `kessel-phase:kickoff`

**Done when:**

- Team has reviewed the [onboarding checklist](https://project-kessel.github.io/docs/)
- Adoption pattern(s) identified (or flagged for Phase 1 follow-up)
- UI v1 access check decision made: Required / New / Not required / N/A
- Service account status captured; CIAM service account request submitted if not yet provisioned (external approval lead time — start early). See internal docs: Service Account and Credentials Setup.
- Provider Initiative confirmed (created or reused in CRCPLAN)
- Service onboarding Epic created in RHCLOUD with Epic Link to Initiative

**Responsibility:** Service team EM + Interview Agent (if using AI tooling)

---

## Phase 1 — Identify adoption pattern(s)

**Story summary:** `Phase 1: Identify adoption pattern(s) — {service.name}`
**Label:** `kessel-phase:adoption-pattern`

**Done when:**

- Pattern(s) documented in the Epic description
- v1 permissions listed (from rbac-config repo or permissions paste)
- [KSL-016 decision tree](https://docs.google.com/document/d/1XnINsHuYeHEi22q_1cS0gUalX-eXl3V19gGf0Wr8NsE/) applied and pattern confirmed
- Platform readiness epic confirmed (or flagged as partial/pending) for chosen pattern(s)
- `program.path` set: `self-service` or `paired` (paired required for first-in-pattern services)

**Responsibility:** Service tech lead + Kessel (if paired path)

---

## Phase 2 — Model permissions and schema

**Story summary:** `Phase 2: Model permissions and schema — {service.name}`
**Label:** `kessel-phase:permissions-schema`

**Done when:**

- `.ksl` permission definitions merged (or PR open for schema review)
- Schema review completed with Kessel team (required for novel patterns)
- Permission names and relations documented in Epic

**Responsibility:** Service tech lead; Kessel schema review (novel patterns only)

---

## Phase 3 — Inventory migration *(conditional)*

**Story summary:** `Phase 3: Inventory migration — {service.name}`
**Label:** `kessel-phase:inventory-migration`

Create **only** when the service has assets (resources, hosts, systems) that must be migrated or ingested into the **Kessel inventory service** (e.g., Insights Host-Based Inventory systems).

Can run **in parallel** with Phase 4 (PoC). Must be Done **before** Prod enabled (Phase 7).

**Done when:**

- Inventory schema defined and reviewed with Kessel team
- Migration or ingestion pipeline implemented (batch migration and/or ongoing sync)
- Asset data validated in stage (inventory query results match expected resource set)
- Asset data validated in prod (inventory query results match expected resource set)
- Rollback or reconciliation plan documented in case of data inconsistency

**Responsibility:** Service tech lead; Kessel inventory team (schema review and platform support)

---

## Phase 4 — PoC

**Story summary:** `Phase 4: PoC — {service.name}`
**Label:** `kessel-phase:poc`

**Done when:**

- First Kessel Check call succeeds in development or CI
- Platform readiness gate confirmed clear for the chosen pattern
- Basic authz flow verified end-to-end (request → Kessel → allow/deny)
- Bearer token successfully requested from SSO using the service account (confirms credentials work before deeper integration)

**Responsibility:** Service tech lead; Kessel paired engineer (if paired path)

---

## Phase 5 — Verified in dev environment

**Story summary:** `Phase 5: Verified in dev environment — {service.name}`
**Label:** `kessel-phase:dev-verified`

**Done when:**

- E2E authorization test passes in a non-production environment (ephemeral via bonfire; kessel-in-a-box when available — not yet built)
- Feature flag enabled in the dev environment, named `<service>.kessel-check.enable` per the program's feature-flag naming convention
- Dev toolchain confirmed working (bonfire deploy of the full Kessel stack; see internal docs "Deploying the Full Kessel Stack in Ephemeral")

**Responsibility:** Service tech lead; Kessel paired engineer (if paired path, through Phase 5 minimum)

---

## Phase 6a — Stage enabled

**Story summary:** `Phase 6a: Enabled and verified in stage — {service.name}`
**Label:** `kessel-phase:stage-enabled`

**Done when:**

- Cluster access configured in stage: service account set up to authenticate with the HCC cluster (replaces network policy for multi-cluster deployments; confirm applicable approach with Kessel platform team)
- Feature flag enabled in stage, named `<service>.kessel-check.enable` per the program's feature-flag naming convention
- **Org-wide impact warning acknowledged:** EM/tech lead confirmed they understand that enabling this flag disables v1 access checks for the **entire org**, not just the resource(s) being migrated — any other feature in this org still relying on v1 checks loses enforcement until it is also migrated. Acknowledged in writing (Epic comment or profile notes) before flipping the flag in stage.
- Smoke test passed (basic authz flows verified in stage)
- **(Strongly recommended)** Parity test run in stage: compare Kessel authz decisions against v1 RBAC responses for a representative sample of real requests; discrepancies documented and resolved before proceeding to 6b

**Responsibility:** Service team

---

## Phase 6b — Feature flag audit

**Story summary:** `Phase 6b: Feature flag and dual-path audit — {service.name}`
**Label:** `kessel-phase:ff-audit`

**Done when:**

- Feature flags aligned for prod promotion (no dev/stage-only flags remaining), named `<service>.kessel-check.enable` per the program's feature-flag naming convention
- No bypass branches (all code paths route through Kessel check)
- Dual-path (v1 + v2) code audit complete
- **Org-wide impact re-verified:** audit confirms whether this org has any other v1-only features that will be silently disabled when the flag flips to prod (enabling the Kessel v2 flag for one resource can disable v1 access checks for the **entire org**, not just the migrated resource). If yes, EM has an explicit plan and date to migrate them, documented in the Epic.
- **(Strongly recommended)** Parity soak complete: Kessel authz ran in shadow/dual-write mode in stage long enough to validate consistency with v1 RBAC at volume; results reviewed and signed off (see Config Manager pattern for reference)

**Responsibility:** Service team

---

## Phase 7 — Prod enabled and verified

**Story summary:** `Phase 7: Enabled and verified in prod — {service.name}`
**Label:** `kessel-phase:prod-enabled`

**Done when:**

- Cluster access configured in prod: service account set up to authenticate with the HCC cluster (multi-cluster) or equivalent
- **(Strongly recommended)** Parity soak in prod: run Kessel authz in shadow mode in prod for a defined soak period; compare decision logs against v1 RBAC; resolve any discrepancies before flipping enforcement flag (Config Manager pattern)
- Kessel enforcement flag enabled in prod
- v1 RBAC calls retired (or scheduled for retirement with a firm date)
- Monitoring and alerting in place for authz errors
- EM sign-off on Phase 7 (required human gate)

**Onboarding complete.** Phase 7 Done = service onboarded.

**Responsibility:** Service team EM (sign-off); service tech lead (implementation)

---

## Conditional — UI story

Create **only** when `ui_access_checks` is `required` or `new`. Two variants, same trigger family:

**Not the same as entitlements or backend-only auth.** Services whose UI uses entitlements, relies on the API for access decisions, or has no UI gating should answer **Not required** — no UI story is created; backend migration is covered by the standard phase stories.

Must be Done **before** Prod enabled (Phase 7).

### `required` — migrate existing v1 UI checks

**Story summary:** `UI: Migrate v1 access checks — {service.name}`
**Label:** `kessel-phase:ui-migration`

**Done when:**

- All UI v1 access check calls migrated to Kessel SDK or v2 patterns
- UI smoke test confirms correct access control in stage and prod

### `new` — net-new v2 UI checks, no v1 to migrate

For a net-new service, or a service whose UI currently has no `/rbac/v1/access` calls but needs UI-layer access gating built for the first time using Kessel v2. There is nothing to migrate — this is greenfield implementation, not a port.

**Story summary:** `UI: Implement v2 access checks — {service.name}`
**Label:** `kessel-phase:ui-migration` (same slug — filtering treats both variants as one UI-work bucket; the summary text is what differs)

**Done when:**

- Kessel v2 access checks implemented in the UI layer for the in-scope resources (no v1 code to remove)
- UI smoke test confirms correct access control in stage and prod

**Responsibility (both variants):** Service team frontend/UI engineers

---

## Onboarding complete

| Scope | Criterion |
|-------|-----------|
| Per service | Phase 7 story Done on that service's Epic |
| Per provider | All service Epics under the provider Initiative have Phase 7 Done |

No M1-M5 launch-milestone gates. No spreadsheet to update. Track via JQL:

```
labels = kessel-onboarding AND type = Epic AND status = Done
```

---

## Responsibility split

| Kessel platform team | Service team |
|---------------------|--------------|
| Platform readiness gates | All phase stories (implementation) |
| SDK and client libraries | Feature flags and dual-path audit |
| bonfire ephemeral toolchain (kessel-in-a-box planned, not yet available) | UI migration (if applicable) |
| Schema review (novel patterns) | EM sign-off on Phase 7 |
| Inventory schema review and platform support | Inventory migration pipeline (if applicable) |
| Paired engineer (first-in-pattern, through Phase 5) | Parity testing / soak (strongly recommended in 6a, 6b, 7) |
| Office hours support (Tuesdays 8:00–8:30am ET) | |

## Changelog

- 2026-07: Consistency check — added the missing `New` option to the Phase 0 done-when item "UI v1 access check decision made" (was still listing only the pre-`new` three-way enum).
- 2026-07: Made the Phase 5/6a/6b feature-flag done-when bullets self-contained (inlined `<service>.kessel-check.enable` and the org-wide-impact wording instead of markdown anchors to the "Feature flag naming convention" section) — anchors don't resolve once a bullet is copied into its own separate Jira story description.
- 2026-07: Added the "Feature flag naming convention" section (`<service>.kessel-check.enable`, replacing inconsistent `KESSEL_ENABLED`-style names) and the org-wide v1-disablement warning as explicit done-when items on Phase 6a and 6b — closes review-doc threads on FF naming and the "has the team been warned" check. Split the conditional UI story into `required` (migrate existing v1 checks) and `new` (net-new v2 checks, nothing to migrate) variants with distinct summaries; both still use the `kessel-phase:ui-migration` label.
- 2026-07: Removed the "Blocked by" gate lines from Phase 3, Phase 4, and the UI story — these described the `onboarding-link-platform-gates` skill, which was removed (it never had a populated Jira epic key to link against). The manual "confirmed clear"/"confirmed (or flagged...)" done-when items for Phase 1 and Phase 4 are unaffected — those are service-team checks, not automated Jira links.
- 2026-07: Added the CMDB/CIAM credentials done-when items, the Phase 3/4 gate fallback note, the `kessel-pattern:{id}` label, and caveated kessel-in-a-box as not yet built.

Assisted-by: Claude (Anthropic)
