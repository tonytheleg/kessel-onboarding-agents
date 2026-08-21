---
name: onboarding-interview-suggest-patterns
description: >
  Given asset types and v1 permissions from a ServiceProfile, applies KSL-016
  decision heuristics to propose adoption pattern(s) with confidence, maps
  platform readiness gates, and flags first-in-pattern paired path. Used by
  onboarding-interview agent after conduct.
---

# Onboarding interview suggest patterns

## When to use

- Called automatically by the `onboarding-interview` agent immediately after `onboarding-interview-conduct` produces a ServiceProfile with `asset_types` and `v1_permissions` populated.
- Re-run standalone if the EM wants to revisit pattern choice or platform-gate status after profile fields change (e.g. new asset types discovered in a follow-up conversation).

## Inputs

| Input | Required | Source |
|-------|----------|--------|
| ServiceProfile JSON path or object | yes | — |
| `asset_types` | yes | from profile |
| `v1_permissions` | yes | from profile |
| `inventory_reporting` | yes | from profile |
| `program.wave` | yes | from profile |
| workspace-awareness per asset type | yes for native/native-ws-list | collected from EM in Step 2 |
| result cardinality per asset type | yes for native/native-ws-list | collected from EM in Step 2 (approximate: hundreds / thousands / millions) |
| access probability per asset type | yes for native/native-ws-list | collected from EM in Step 2 (approximate: most results accessible, or small fraction) |

Workspace-awareness, cardinality, and access-probability are not stored on the profile — they are elicited from the EM during Step 2 analysis when the asset type appears to qualify for a native pattern. If either cardinality or access-probability is unknown, assign `medium` confidence and record what needs confirming.

## Execution

### Step 1 — Load catalogs

Read [patterns.md](patterns.md) and `context/platform-gates.json` (from config `platform_gates_path`).

### Step 2 — Analyze permission scope

Apply the KSL-016 decision tree from [patterns.md](patterns.md#decision-heuristics-interview-questions) in order. Key questions:

**Is the resource already Workspace-aware?** (Only Workspaces and Hosts via Inventory Groups qualify today)

- Yes, AND queries are low-cardinality (<10k) or high-access-probability (>80%) → `native`
- Yes, AND queries are high-cardinality (>10k) AND low-access-probability (<80%) → `native-ws-list`

**If not Workspace-aware:**

- Can the resource be conceptualized as a customer-managed "asset" (CRUD, could logically live in a Workspace)? → `default-workspace`
  - Common signals: workspace-scoped CRUD permissions (create/view/edit/delete on an asset type)
  - Most wave 2 services land here
- Is the operation org-wide AND asset-centric (could be Workspace-scoped in the future)? → `root-workspace`
- Is the operation org-wide AND NOT asset-centric (meta-authorization, authentication policy)? → `org-level`
  - Rare for Insights services; flag if suggested

**Choosing between `native` and `native-ws-list`** requires three inputs:
1. **Workspace-awareness** — is the resource already organized by workspaces/groups in the service's data model? (Required for both native patterns.)
2. **Result cardinality** — how many records does a typical org-scoped LIST return?
3. **Access probability** — of those results, what fraction does a requesting user typically have access to?

Decision rules:
- Workspace-aware + **fewer than 10,000 results** OR **more than 80% accessible** → `native` (per-resource Check)
- Workspace-aware + **more than 10,000 results** AND **fewer than 80% accessible** → `native-ws-list` (workspace pre-filter + DB query)

**When asking the EM**, frame it without Kessel jargon:

> "For the `{asset_type}` resources in your service: roughly how many records does a typical LIST query return for a single org — hundreds, thousands, or millions? And of those results, what fraction does the requesting user typically have access to — most of them, or a small subset?"
>
> Fewer than ~10,000 results, or users can typically see most of them → use `native` (Kessel checks each resource individually).
> More than ~10,000 results AND users only see a small fraction → use `native-ws-list` (Kessel pre-filters by workspace before your DB query, which scales better at high volume).
> See: https://project-kessel.github.io/docs/building-with-kessel/how-to/migrate-from-rbac-v1-to-v2/

Document rationale per pattern in the `rationale` field. If either cardinality or access-probability is unknown, default to `medium` confidence and note what needs confirming with the EM before Phase 2.

### Step 3 — Assign confidence

Per [patterns.md](patterns.md#confidence). Never assign `high` to org-level or root-workspace for wave 3+ when gate status is not `ready`.

### Step 4 — Build patterns array

```json
{
  "id": "default-workspace",
  "label": "Default workspace",
  "confidence": "high",
  "rationale": "...",
  "guide_anchor": "/building-with-kessel/how-to/migrate-from-rbac-v1-to-v2/#identify-the-patterns",
  "asset_types": ["activation_key"]
}
```

Multiple patterns allowed when multiple asset types need different patterns; mark primary pattern first. Every asset type in the profile's `asset_types[]` must appear in exactly one pattern's `asset_types[]` — see [patterns.md#multi-pattern-services](patterns.md#multi-pattern-services). For a single-pattern service, list all `asset_types[]` on that one pattern.

### Step 5 — Map platform gates

For each pattern id, append to `platform_gates[]`:

```json
{
  "pattern_id": "default-workspace",
  "epic_summary": "Platform Readiness: Default workspace",
  "jira_key": null,
  "status": "ready"
}
```

Always include `sdk-client` and `ephemeral-infra` gates for Phase 3+ and Phase 4 context in summary (optional entries in `platform_gates` with note "Phase 4 gate").

If `ui_access_checks` is `required` or `new` (both create a conditional UI story), add UI platform gate from `platform-gates.json` `gates.ui-platform`.

### Step 6 — First-in-pattern check

JQL (optional, if MCP available):

```
labels = kessel-onboarding AND labels = "kessel-pattern:{id}" AND type = Epic AND status = Done
```

Pre-label cohorts (epics created before the `kessel-pattern:{id}` label existed) may not match this query — this is expected and does not necessarily mean no prior service has shipped the pattern. If the query returns nothing, fall back to asking the EM (see below) rather than treating the empty result as conclusive.

All JQL templates in this skill are linted by `/kessel-onboarding:preflight`.

If no Done prod epic found for this pattern in the provider's wave cohort, issue a **soft warning** — do not block:

> ⚠️ No completed {pattern label} epic found in RHCLOUD. This may be the first service in your cohort to ship this pattern to prod. Consider the **paired path** (Kessel team pairing through Phase 5 minimum). EM can override to self-service.

Set `program.path` to `paired` unless EM explicitly overrides.

If MCP unavailable, ask EM: "Is this the first service in your org to ship this pattern to prod?" Apply the same soft warning if EM says yes.

### Step 7 — Update profile file

Merge `patterns`, `platform_gates`, and `program.path` into `{slug}-profile.json`. Append pattern section to `{slug}-summary.md`.

### Step 8 — Present to EM

Table: Pattern | Confidence | Platform gate status | Path (self-service / paired)

EM may override pattern choice before dedup — apply overrides to JSON when stated explicitly.

## Outputs

Updated ServiceProfile with `patterns[]`, `platform_gates[]`, and possibly `program.path`.

## Changelog

- 2026-08: Added structured native vs native-ws-list decision guidance with explicit cardinality (<10k) and access-probability (>80%) thresholds; added EM-facing question framing explaining workspace pre-filtering vs per-resource checks without Kessel jargon.
- 2026-07: Fixed Step 5 to also map the UI platform gate when `ui_access_checks` is `new`, not just `required` — both trigger a conditional UI story and need the same gate tracking.
- 2026-07: Added `asset_types[]` to each pattern object so multi-pattern services map every asset type to exactly one pattern instead of leaving the split implicit in rationale text.
- 2026-07: Replaced the first-in-pattern JQL with an exact-match `kessel-pattern:{id}` label query; read the UI gate from `gates.ui-platform` instead of the removed top-level `ui_gate`.

Assisted-by: Claude (Anthropic)
