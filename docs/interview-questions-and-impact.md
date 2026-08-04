# Onboarding intake questions and how answers shape the output

This document explains what the Kessel onboarding intake asks service teams, and how each answer drives the Jira stories, adoption pattern, and onboarding path that come out the other end.

---

## How to read this document

The intake is split into two phases. **Phase 0** establishes the service identity and Jira context. **Phase 1** collects technical details used to select the adoption pattern and scope the work. After both phases, a pattern-suggestion step and dedup check run automatically before the EM reviews and approves.

The "Impact on output" column for each question describes exactly what changes in the generated ServiceProfile, Jira issue plan, and onboarding phases.

**A note on phase numbers:** the "Phase N" numbering you see throughout this doc (and in Jira story summaries) is cosmetic display text. The actual Jira label used for filtering and dashboards on each phase story is a stable slug (e.g. `kessel-phase:stage-enabled`, not `kessel-phase:6a-stage-enabled`) that carries no number. This means the phase numbering can be revised in the future without relabeling existing Jira issues or breaking saved reports — see `context/phase-checklist.md` for the full label table.

---

## Phase 0 — Kickoff questions


| #   | Question                                                                | Possible answers                                                                                                                                         | Impact on output                                                                                                                                                                                                                            |
| --- | ----------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | **What is the provider / tenant name?**                                 | Free text (e.g. "Subscription Management")                                                                                                               | Sets `provider.name`. Provisioner creates (or reuses) a **Provider Initiative** in CRCPLAN with summary `[Kessel Onboarding] {provider.name}`. Multiple services under the same provider share one Initiative.                              |
| 2   | **What is the deployable service name?**                                | Free text (e.g. "Activation Keys")                                                                                                                       | Sets `service.name` and generates the slug (e.g. `activation-keys`). Provisioner creates a **service onboarding Epic** in RHCLOUD with summary `[Kessel Onboarding] {service.name}`. One Epic per service — this is the unit of onboarding. |
| 3   | **What Jira project key owns this service?**                            | Project key (e.g. TUSC, RHINENG)                                                                                                                         | Sets `jira.home_project`. Used for feature epic lookup and dedup search. Onboarding issues are *not* created here — they go to CRCPLAN/RHCLOUD.                                                                                             |
| 4   | **What is the existing feature epic key to link?**                      | Jira key or none                                                                                                                                         | Sets `jira.feature_epic_key`. Provisioner creates a **relates-to** link from the RHCLOUD onboarding Epic to this feature epic in the service team's project. If none, EM documents why.                                                     |
| 4a  | **Do you have a link to the service's repo (GitHub/GitLab URL), a local path, or an archive I can look at?** | Repo URL / path / archive, or none | Sets `interview.codebase_ref` (optional). If provided, the agent analyzes it and drafts answers for questions 8 (UI access checks), 9 (tech stack), 10 (asset types), and 11 (v1 permissions). Those questions are still asked — the EM/tech lead **confirms or corrects** the draft rather than answering cold. Confirmed fields are marked "(confirmed from repo analysis)" in the summary. If none, or analysis fails, those questions are asked normally with no change in behavior. |
| 5   | **Which wave best fits your team?** (Kessel onboards services in waves — batches of teams migrating on a rough timeline, not a hard deadline.) | (1) Already integrating — started or finished early phases before this intake existed. (2) Current wave — onboarding now, as part of today's active batch (default if unsure). (3) Future wave — planned, but not yet started. | Sets `program.wave` (1, 2, or 3 internally). **Wave 3+ restriction:** `org-level` and `root-workspace` patterns will not be suggested unless their platform readiness gate is `ready`. Wave also informs paired-path logic (see below).     |
| 6   | **PM, EM, and tech lead names and emails?**                             | Contact info                                                                                                                                             | Populates `contacts`. Written into the Initiative and Epic descriptions in Jira.                                                                                                                                                            |
| 7   | **Has the team reviewed the onboarding checklist and migration guide?** | Yes / No                                                                                                                                                 | Sets `kickoff.docs_reviewed`. Captured in the Phase 0 story. If no, flagged as an open action item.                                                                                                                                         |
| 7a  | **Is your application registered in CMDB with a valid Application ID?** | Yes / No / Unknown | Sets `credentials.cmdb_registered`. Populates `credentials.*`. If `service_account_status` is `none`, the Phase 0 story gets an open action item: submit the CIAM request now (long lead time). Recorded in the Epic description so the Kessel team can see credential readiness at a glance. |
| 7b  | **Have you provisioned a Kessel service account through the CIAM process?** (Answer for both stage and prod) | None / Requested / Stage only / Stage and prod | Sets `credentials.service_account_status`. Populates `credentials.*`. If `service_account_status` is `none`, the Phase 0 story gets an open action item: submit the CIAM request now (long lead time). Recorded in the Epic description so the Kessel team can see credential readiness at a glance. |
| 8   | **Does your UI call `/rbac/v1/access` today, or does it need new v2 access checks built for the first time?** | `required` / `new` / `not_required` / `n/a` | Sets `ui_access_checks`. **Conditional UI story trigger — see detail below.** |


### UI access checks — detailed impact

This question is about **v1 access check API calls in the UI layer**, not whether the service has a UI or does access control elsewhere.

**How to choose:**

| Answer | Choose when… |
|--------|--------------|
| **Required** | The UI calls `/rbac/v1/access` (or equivalent v1 access-check APIs) today, and those calls need migration to Kessel. |
| **New** | The UI has **no existing v1 access checks** (net-new service, or a UI that was previously unguarded/entitlements-only) but the team wants Kessel v2 access checks implemented in the UI layer from scratch. There is nothing to migrate — this is greenfield UI work, not a port. |
| **Not required** | The service may have a UI, but the UI does **not** call `/rbac/v1/access`, and the team does not need net-new UI-layer checks either. Common cases: access enforced only in the API/backend; UI uses **entitlements** or other non–v1-access mechanisms; UI has no access-gating logic (shows/hides based on what the API returns). |
| **N/A** | The deployable has **no user-facing UI** (API/backend-only). |

**What each answer does in Jira:**

| Answer | What happens |
|--------|-------------|
| **`required`** | A **conditional UI story** is added: `UI: Migrate v1 access checks — {service.name}` with label `kessel-phase:ui-migration`. Must be Done before Prod enabled (Phase 7). |
| **`new`** | A **conditional UI story** is added: `UI: Implement v2 access checks — {service.name}` with label `kessel-phase:ui-migration` (same slug as `required` — the summary text is what differs, filtering treats both as one UI-work bucket). Must be Done before Prod enabled (Phase 7). |
| **`not_required`** | No UI story. Backend auth migration still happens via the standard phase stories (2–7). |
| **`n/a`** | No UI story. Same as not required — nothing to migrate in a UI layer that does not exist. |


---

## Phase 1 — Pattern input questions


| #   | Question                                                       | Possible answers                                        | Impact on output                                                                                                                                                                      |
| --- | -------------------------------------------------------------- | ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 9   | **Language, framework, and how the service calls auth today?** | Free text (e.g. "Java, Quarkus, Kessel SDK")            | Sets `tech_stack.lang`, `tech_stack.framework`, `tech_stack.auth`. Written into the Epic description for Kessel engineers to know the integration surface.                            |
| 10  | **What resource / asset types are in scope?**                  | List of types (e.g. `activation_key`, `policy`, `host`) | Sets `asset_types[]`. **Primary input to the pattern decision tree** — determines whether assets are workspace-aware, can be conceptualized as CRUD assets, or are org-wide settings. Also surfaces more advanced use cases early — e.g. Host-Based-Inventory-style resource relationships, or cross-resource orchestration like Remediations — which may need pattern handling beyond simple CRUD assets (see question 12 below, and [multi-pattern services](../skills/onboarding-interview-suggest-patterns/patterns.md#multi-pattern-services)). |
| 11  | **Paste v1 permissions or give rbac-config repo path**         | Permission list or repo path                            | Sets `v1_permissions`. Permissions are analyzed for scope (workspace-scoped CRUD vs org-wide) to confirm the pattern selection. Listed in the Epic description.                       |
| 12  | **Does your service currently report resources to Kessel inventory?** (This builds on the asset types from question 10 — if any of those types are things Kessel needs to know about for authorization decisions, e.g. host-based or workspace-scoped resources, the service likely needs to report them.) | Yes / No | Sets `inventory_reporting`. Informational current-state only — does **not** trigger Phase 3 by itself. See detail below. |
| 12b | **Does your service have resources (hosts, systems, assets) that need to be migrated or ingested into Kessel inventory before prod enablement — via batch migration, ongoing sync, or both?** | Yes / No | Sets `inventory_migration_required`. **This is the conditional Phase 3 story trigger — see detail below.** |
| 13  | **Do you use Ephemeral/Bonfire for pre-dev testing?**          | Yes / No                                                | Sets `ephemeral.uses_bonfire`. Noted in Phase 5 story context.                                                                                                                        |
| 14  | **If no: What do you use for pre-dev testing?**                | Free text (e.g. integration env, local kessel-in-a-box) | Sets `ephemeral.pre_dev_tooling`. Only asked when `uses_bonfire` is false.                                                                                                            |
| 15  | **Target stage/prod dates?**                                   | Dates or none                                           | Sets `targets.stage` and `targets.prod`. Optional. Recorded for planning context.                                                                                                                                              |


### Inventory reporting — detailed impact

The Phase 3 trigger is `inventory_migration_required`, not `inventory_reporting`. The two fields are independent: a service can already report inventory with nothing left to migrate, or not report yet and need a full pipeline. A service already reporting inventory may still answer Yes here (e.g. a remaining batch migration), and a service not yet reporting may answer No (no inventory involvement at all).

| Answer (`inventory_migration_required`) | What happens                                                                                                                                                                                                                                                                                                                                                                                    |
| ------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Yes** | A **conditional Phase 3 story** is added: `Phase 3: Inventory migration — {service.name}` with label `kessel-phase:inventory-migration`. This phase covers inventory schema definition, migration/ingestion pipeline build, and data validation. Runs in parallel with Phase 4 but must be Done before Prod enabled (Phase 7). |
| **No**  | Phase 3 is skipped entirely. The service goes directly from Phase 2 (permissions schema) to Phase 4 (PoC).                                                                                                                                                                                                                                                                                      |


### Ephemeral/Bonfire — detailed impact


| Answer  | What happens                                                                                                                                                                                                                 |
| ------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Yes** | Sets `ephemeral.uses_bonfire` = true. Phase 5 expects E2E authz verification in Ephemeral/Bonfire. No follow-up question.                                                                                                    |
| **No**  | Sets `ephemeral.uses_bonfire` = false. Agent asks what the team uses for pre-dev testing and records `ephemeral.pre_dev_tooling`. Noted in the Epic description and Phase 5 context so Kessel knows the alternate toolchain. |


---

## Derived decisions (not directly asked — computed from answers)

These are not interview questions. They are determined automatically based on the answers above.

### Adoption pattern selection

The asset types, v1 permissions, and inventory reporting answers feed into the **KSL-016 decision tree**:

```
1. Is the resource already Workspace-aware (uses Inventory Groups / Workspace hierarchy)?
   → YES: go to 2
   → NO:  go to 3

2. Do LIST queries return > 10,000 results AND is user access probability < 80%?
   → YES: native-ws-list
   → NO:  native

3. Can this resource be conceptualized as an "asset" (customer-managed, CRUD, could live in a Workspace)?
   → YES: default-workspace
   → NO:  go to 4

4. Is the operation "asset-centric" — could it be scoped to a Workspace in the future?
   → YES: root-workspace
   → NO:  org-level
```


| Pattern                 | When it's selected                                                                               | What it means for the service                                                                                                                                      |
| ----------------------- | ------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `**native**`            | Resource is already Workspace-aware AND queries are low-cardinality or high-access-probability   | Service calls Kessel `Check` or `ListObjects` per-resource natively. Simplest migration.                                                                           |
| `**native-ws-list**`    | Resource is already Workspace-aware AND queries return >10k results with <80% access probability | Service calls `ListObjects` at the Workspace level first, then filters in its own DB. Requires `workspace_id` on asset records.                                    |
| `**default-workspace**` | Resource is NOT Workspace-aware but is a customer-managed CRUD asset                             | Service looks up the Default Workspace for the org, then calls `Check` against it. **Most common for wave 2 services.** No domain model changes required up front. |
| `**root-workspace**`    | Operation is org-wide AND asset-centric (could be Workspace-scoped in the future)                | Service calls `Check` against the Root Workspace. Customers must bind Roles at Root Workspace level — flagged as a UX consideration.                               |
| `**org-level**`         | Operation is org-wide AND NOT asset-centric (meta-authorization, auth policy)                    | Rare for Insights services. **Not suggested at `high` confidence for wave 3+ unless platform gate is `ready`** (see below).                                        |


A service can have **multiple patterns** if different asset types require different access models. The primary pattern (covering the majority of permissions) is listed first. Each pattern object in the profile now carries its own `asset_types[]` — the specific asset types (from question 10) that use that pattern — so every asset type resolves to exactly one pattern rather than a single pattern being assumed to cover the whole service. See the [Pattern object schema](../skills/onboarding-interview-conduct/reference.md#pattern-object).

### Platform readiness gates

Each pattern has a platform readiness `status` recorded in `context/platform-gates.json`, maintained manually by the Kessel PM. **This status only affects two things during pattern suggestion** — it does not create any Jira link or block any story (the Jira gate-linking skill was removed in 2026-07; it never had a populated epic key to link against):

1. **Confidence cap:** `org-level`/`root-workspace` cannot be suggested at `high` confidence for wave 3+ services unless their gate status is `ready`.
2. **Paired-path default:** if the chosen pattern's gate status is `partial` or `ongoing`, `program.path` defaults to `paired` (same effect as the first-in-pattern signal — EM can override).

| Gate                | Current status |
| ------------------- | -------------- |
| `native`            | `ready`        |
| `default-workspace` | `ready`        |
| `native-ws-list`    | `ready`        |
| `org-level`         | `ready`        |
| `root-workspace`    | `ready`        |
| `ephemeral-infra`   | `ready`        |
| `sdk-client`        | `ready`        |
| `ui-platform`       | `ready`        |

As of 2026-07 all gates are `ready` (Kessel core + Access APIs, SDKs, and UI migration tooling confirmed complete), so neither rule above currently changes any suggestion — see `context/platform-gates.json` for the live values.


### Onboarding path (self-service vs paired)


| Condition                                                                 | Path set           | What it means                                                                                                    |
| ------------------------------------------------------------------------- | ------------------ | ---------------------------------------------------------------------------------------------------------------- |
| Another service in the same pattern has already completed Phase 7 in prod | `**self-service**` | Service team drives all phases. Kessel available via office hours (Tuesdays 8:00–8:30am ET).                     |
| No prior service has completed this pattern in prod (first-in-pattern)    | `**paired**`       | Kessel paired engineer works with the service team **through Phase 5 minimum**. EM can override to self-service. |
| Platform readiness gate is `partial` or `ongoing` for the chosen pattern  | `**paired**`       | Same as first-in-pattern — paired path recommended through Phase 5 minimum. (No gate is currently non-`ready`, so this rule is presently inactive.) |


---

## Full picture: answer → Jira stories created

Here is the complete set of Jira stories the Provisioner creates, and which answers control inclusion:


| Story                                      | Always created?                            | Conditional on                                                                                                                               |
| ------------------------------------------ | ------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------- |
| Provider Initiative (CRCPLAN)              | Yes (or reused if provider already exists) | `provider.name`                                                                                                                              |
| Service onboarding Epic (RHCLOUD)          | Yes                                        | `service.name`                                                                                                                               |
| Phase 0: Kickoff                           | Yes                                        | —                                                                                                                                            |
| Phase 1: Identify adoption pattern(s)      | Yes                                        | —                                                                                                                                            |
| Phase 2: Model permissions and schema      | Yes                                        | —                                                                                                                                            |
| **Phase 3: Inventory migration**           | **No**                                     | **Only when `inventory_migration_required` = true** (service has assets to migrate into Kessel inventory). |
| Phase 4: PoC                               | Yes                                        | —                                                                                                                                            |
| Phase 5: Verified in dev environment       | Yes                                        | —                                                                                                                                            |
| Phase 6a: Enabled and verified in stage    | Yes                                        | —                                                                                                                                            |
| Phase 6b: Feature flag and dual-path audit | Yes                                        | —                                                                                                                                            |
| Phase 7: Enabled and verified in prod      | Yes                                        | —                                                                                                                                            |
| **UI: Migrate v1 access checks** / **UI: Implement v2 access checks** | **No** | **Only when `ui_access_checks` = `required`** (migrate existing `/rbac/v1/access` calls) **or `new`** (implement v2 checks fresh — nothing to migrate) |


### Common scenarios

**Backend-only service, no inventory (e.g. Activation Keys)**

- `ui_access_checks` = `not_required` or `n/a` → no UI story
- `inventory_migration_required` = false → no Phase 3
- Result: **8 stories** (Phases 0, 1, 2, 4, 5, 6a, 6b, 7) under 1 Epic under 1 Initiative

**Service with UI but no inventory**

- `ui_access_checks` = `required` or `new` → UI story added (summary text differs; same `kessel-phase:ui-migration` label either way)
- `inventory_migration_required` = false → no Phase 3
- Result: **9 stories** (Phases 0, 1, 2, 4, 5, 6a, 6b, 7, + UI) under 1 Epic

**Service with inventory but no UI**

- `ui_access_checks` = `not_required` → no UI story
- `inventory_migration_required` = true → Phase 3 added (runs parallel with Phase 4)
- Result: **9 stories** (Phases 0, 1, 2, 3, 4, 5, 6a, 6b, 7) under 1 Epic

**Service with both UI and inventory**

- Both conditionals fire
- Result: **10 stories** (Phases 0, 1, 2, 3, 4, 5, 6a, 6b, 7, + UI) under 1 Epic

**Service where v1 RBAC was never used**

- If the service has no existing v1 RBAC permissions, there is no migration of RBAC data — the v1 permissions list will be empty or marked as N/A
- Phases 6a/6b parity testing steps (comparing Kessel decisions against v1 RBAC) are simplified since there is no legacy behavior to match
- Phase 7 v1 RBAC retirement step is N/A

---

## Example: Activation Keys (wave 2 pilot)


| Question            | Answer                                   | Effect                                                                           |
| ------------------- | ---------------------------------------- | -------------------------------------------------------------------------------- |
| Provider            | Subscription Management                  | Initiative: `[Kessel Onboarding] Subscription Management`                        |
| Service             | Activation Keys                          | Epic: `[Kessel Onboarding] Activation Keys`                                      |
| Home project        | TUSC                                     | Dedup searches TUSC; onboarding issues go to RHCLOUD                             |
| Feature epic        | TUSC-271                                 | Relates-to link from RHCLOUD Epic → TUSC-271                                     |
| Migration timeline  | Current cohort (wave 2)                  | No wave restrictions on pattern selection                                        |
| UI access checks    | Not required                             | No UI story created                                                              |
| Asset types         | `activation_key`                         | CRUD asset → decision tree selects `default-workspace`                           |
| v1 permissions      | `activation_key:create/view/edit/delete` | Workspace-scoped CRUD confirms `default-workspace` pattern                       |
| Inventory reporting | No                                       | Informational only                                                               |
| Inventory migration required | No                              | No Phase 3 story                                                                 |
| Onboarding path     | self-service (computed)                  | Service team drives; Kessel available via office hours                           |
| **Result**          |                                          | **8 phase stories** under 1 Epic, `default-workspace` pattern, self-service path |

---

## Docs gaps

During intake, the agent may encounter questions it cannot answer from KesselDocs or the internal docs. These are captured in `docs_gaps[]` rather than researched mid-interview, so the session keeps moving.

Captured gaps are the evidence base for the docs backlog and will feed the future Docs Agent (Track C). Until then, the Kessel PM reviews them from the summary files (`{slug}-summary.md`, "Docs gaps captured" section).

## Changelog

- 2026-07: Added question 4a (`interview.codebase_ref`) — an optional repo URL/path/archive the agent can analyze to draft answers for questions 8–11, which the EM/tech lead confirms or corrects rather than answering cold. See `skills/onboarding-interview-conduct/SKILL.md` Step 1.5.
- 2026-07: Consistency check — updated the "Service with UI but no inventory" scenario to include `new` alongside `required`, matching the fix in `onboarding-interview-suggest-patterns/SKILL.md` Step 5 (UI platform gate now maps for both).
- 2026-07: Added `new` as a fourth `ui_access_checks` answer (net-new v2 UI checks, nothing to migrate — closes a review-doc gap about services with no existing v1 UI checks); added asset-type context (advanced use cases like HBI/Remediations) to question 10 and tied question 12 back to it; noted that each `patterns[]` entry now carries its own `asset_types[]` for multi-pattern services.
- 2026-07: Rewrote the "Platform readiness gates" section — removed the "what it blocks" framing and all "blocked by gate" references throughout this doc. The Jira gate-linking skill was removed (it never had a populated epic key to link against); gate status now only affects pattern-suggestion confidence and the paired-path default, both documented explicitly.
- 2026-07: Added the missing `native` row to the platform readiness gate table (consistency check — the gate was absent from `context/platform-gates.json` despite `native` being one of the 5 KSL-016 patterns).
- 2026-07: Split question 12 into `inventory_reporting` (informational) and `inventory_migration_required` (Phase 3 trigger); added the CMDB/CIAM credentials questions (7a/7b); noted `targets.stage`/`targets.prod`; added the Docs gaps closing section.
- 2026-07: Clarified question 5 (`program.wave`) — defined "wave" before asking, added a default-if-unsure hint, and separated the question text from the answer options.

Assisted-by: Claude (Anthropic)


