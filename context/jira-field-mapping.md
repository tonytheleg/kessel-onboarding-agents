# Jira field mapping

Maps ServiceProfile and `onboarding_profile` handoff fields to Jira issue fields. Consumed by **Provisioner Agent** (Track B). Interview Agent uses this for narrative summary only.

Canonical templates: `context/jira-field-mapping.md` and `context/phase-checklist.md`

## Project routing

| Issue type | Jira project | Notes |
|------------|-------------|-------|
| Provider Initiative | **CRCPLAN** | One per provider / tenant |
| Service onboarding Epic | **RHCLOUD** | Parent field → CRCPLAN Initiative |
| Phase Stories | **RHCLOUD** | Parent field (legacy name: Epic Link) → Service onboarding Epic |
| Conditional UI Story | **RHCLOUD** | Parent field (legacy name: Epic Link) → Service onboarding Epic |
| Feature epic (`jira.feature_epic_key`) | Service team project (e.g. TUSC, RHINENG) | **Not created by Provisioner** — linked via **relates to** only |

`jira.home_project` in the ServiceProfile identifies the service team's own Jira project. It is used for feature epic lookup and dedup only — the Provisioner always provisions onboarding issues in CRCPLAN / RHCLOUD.

## Provider Initiative

| Profile field | Jira project | Jira field | Value pattern |
|---------------|-------------|------------|---------------|
| `provider.name` | CRCPLAN | Summary | `[Kessel Onboarding] {provider.name}` |
| — | CRCPLAN | Type | Initiative |
| `jira.label` | CRCPLAN | Labels | `kessel-onboarding` |
| `contacts.pm`, `contacts.em` | CRCPLAN | Description | Provider contact block |
| `program` services list | CRCPLAN | Description | Services in scope (if multi-service intake) |

## Service Epic

| Profile field | Jira project | Jira field | Value pattern |
|---------------|-------------|------------|---------------|
| `service.name` | RHCLOUD | Summary | `[Kessel Onboarding] {service.name}` |
| CRCPLAN Initiative key | RHCLOUD | Parent field | Provider Initiative |
| `patterns[].label` | RHCLOUD | Description | Adoption pattern line |
| `tech_stack` | RHCLOUD | Description | Tech stack line |
| `ui_access_checks` | RHCLOUD | Description | UI access checks line |
| `jira.feature_epic_key` | RHCLOUD | Link | **relates to** feature epic (service team project) |
| `jira.label` | RHCLOUD | Labels | `kessel-onboarding` |
| — | RHCLOUD | Labels | `kessel-phase-scheme:v1` — records which version of the phase checklist was used, so renumbering later doesn't create ambiguity across cohorts |
| `patterns[].id` | RHCLOUD | Labels | `kessel-pattern:{id}` — one per adopted pattern (primary pattern always included), enabling exact-match pattern queries |

## Phase Stories

| Profile field | Jira project | Jira field | Value pattern |
|---------------|-------------|------------|---------------|
| `service.name` | RHCLOUD | Summary | `Phase {n}: {title} — {service.name}` |
| — | RHCLOUD | Type | Story |
| Service Epic key | RHCLOUD | Parent field (legacy name: Epic Link) | Service onboarding Epic |
| `kessel-onboarding` | RHCLOUD | Labels | Always present |
| Phase label (see table) | RHCLOUD | Labels | Phase-specific label (for filtering) |

### Phase story summaries and labels

Each story gets two labels: `kessel-onboarding` (always) and its **stable slug-based** phase label (for filtering). The slug carries no ordinal number, so the "Phase N" display numbering can change later without relabeling any existing issue or breaking a saved JQL filter. See `context/phase-checklist.md` for the full rationale.

| Phase (current display order) | Summary | Phase label (stable slug) |
|-------------------------------|---------|---------------------------|
| 0 | `Phase 0: Kickoff — {service.name}` | `kessel-phase:kickoff` |
| 1 | `Phase 1: Identify adoption pattern(s) — {service.name}` | `kessel-phase:adoption-pattern` |
| 2 | `Phase 2: Model permissions and schema — {service.name}` | `kessel-phase:permissions-schema` |
| 3 *(conditional)* | `Phase 3: Inventory migration — {service.name}` | `kessel-phase:inventory-migration` |
| 4 | `Phase 4: PoC — {service.name}` | `kessel-phase:poc` |
| 5 | `Phase 5: Verified in dev environment — {service.name}` | `kessel-phase:dev-verified` |
| 6a | `Phase 6a: Enabled and verified in stage — {service.name}` | `kessel-phase:stage-enabled` |
| 6b | `Phase 6b: Feature flag and dual-path audit — {service.name}` | `kessel-phase:ff-audit` |
| 7 | `Phase 7: Enabled and verified in prod — {service.name}` | `kessel-phase:prod-enabled` |

Phase story Description bodies are defined in `context/phase-checklist.md`. Provisioner uses done-criteria stubs from `context/phase-checklist.md`. Phase 5/6a/6b done-when text inlines the feature flag naming convention (`<service>.kessel-check.enable`) and the org-wide v1-disablement warning directly — see `context/phase-checklist.md#feature-flag-naming-convention` for the full rationale (not copied into the Jira story text, which is self-contained).

## Conditional UI story

Create when `ui_access_checks` is `required` or `new`. Use **not required** when the service has a UI but no v1 access checks and no net-new UI checks are needed (entitlements, backend-only auth, or no UI gating). Use **n/a** when there is no user-facing UI. Must be Done before Prod enabled (Phase 7).

| Field | Jira project | Value |
|-------|-------------|-------|
| Summary (`required`) | RHCLOUD | `UI: Migrate v1 access checks — {service.name}` |
| Summary (`new`) | RHCLOUD | `UI: Implement v2 access checks — {service.name}` |
| Labels | RHCLOUD | `kessel-onboarding`, `kessel-phase:ui-migration` (same slug for both variants) |
| Parent field (legacy name: Epic Link) | RHCLOUD | Service onboarding Epic |

## Conditional inventory migration story

Create when the service has assets (resources, hosts, systems) that must be migrated or ingested into the Kessel inventory service. Can run in parallel with Phase 4 (PoC). Must be Done before Prod enabled (Phase 7).

| Field | Jira project | Value |
|-------|-------------|-------|
| Summary | RHCLOUD | `Phase 3: Inventory migration — {service.name}` |
| Labels | RHCLOUD | `kessel-onboarding`, `kessel-phase:inventory-migration` |
| Parent field (legacy name: Epic Link) | RHCLOUD | Service onboarding Epic |

## Dedup outcomes

| `dedup.status` | Provisioner action |
|----------------|-------------------|
| `clean` | Create Initiative in CRCPLAN (if missing) + Epic + Stories in RHCLOUD |
| `reuse_initiative` | Skip Initiative create; parent Epic to existing CRCPLAN Initiative |
| `duplicate_found` | Do not create Epic; link EM to existing RHCLOUD issue |

## Changelog

- 2026-07: Added the `new` UI story summary variant (`UI: Implement v2 access checks`, same `kessel-phase:ui-migration` label) and a pointer to the feature flag naming convention in `context/phase-checklist.md`.
- 2026-07: Removed the `platform_gates[]` → Jira Link row — the gate-linking skill was removed (never had a populated Jira key to link against; all gate statuses are now `ready`).
- 2026-07: Added Phase 3/4 gate-linking fallback, `kessel-pattern:{id}` label, and standardized "parent field (legacy name: Epic Link)" terminology.

Assisted-by: Claude (Anthropic)
