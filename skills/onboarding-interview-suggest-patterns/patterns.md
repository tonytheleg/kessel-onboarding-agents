# Adoption pattern catalog

Full KSL-016 pattern definitions for pattern suggestion. Canonical source: [KSL-016: Migrating host and organization level permissions](https://docs.google.com/document/d/1XnINsHuYeHEi22q_1cS0gUalX-eXl3V19gGf0Wr8NsE/) (internal).

Migration guide: Identify the patterns

## Pattern overview

KSL-016 defines 5 patterns organized into 3 categories:

| Category | Pattern | ID |
|----------|---------|-----|
| Workspace-aware assets | Native | `native` |
| Workspace-aware assets | Native, workspace-level list | `native-ws-list` |
| Non-workspace-aware assets | Default workspace | `default-workspace` |
| Org-wide settings | Root workspace | `root-workspace` |
| Org-wide settings | Organization-level | `org-level` |

## Patterns

### Native (`native`)

**Category:** Workspace-aware assets

**When to use — ALL conditions must be met:**

1. Service-resource is **already Workspace-aware** (application already organizes resources into Workspaces — currently only Workspaces themselves and Hosts via Inventory Groups)
2. AND either:
   - Queries return **< 10,000 results** (low cardinality), OR
   - **> 80% of results** are accessible to the requesting user (high probability of access)

**Examples:** Workspaces, Hosts (low-cardinality operations)

**Kessel call:** `Check` (post-filter) or `ListObjects` (pre-filter) per-resource natively.

**RBAC translation:**

| Request input | Translation | Kessel input |
|---------------|-------------|--------------|
| `org_id` | n/a | n/a |
| `resource` | format as resource reference or resource type | object (checks) or object type (list objects) |
| `operation` | 1:1 mapping to relation (permission) | relation |
| `user` | format as subject reference | subject |

**Note:** Only valid for resources already modeled natively in Kessel (Workspace-aware). Cannot be used for resources that have not yet been migrated into the Workspace hierarchy.

---

### Native, workspace-level list (`native-ws-list`)

**Category:** Workspace-aware assets

**When to use — ALL conditions must be met:**

1. Service-resource is **already Workspace-aware**
2. AND queries return **> 10,000 results** (high cardinality, e.g. Hosts at scale)
3. AND **< 80% of results** are accessible (low probability of access for a given user)

**Examples:** Hosts (high-cardinality LIST operations), any Insights service resource that relates to Hosts

**Why not Native?** At ~10^5 results, per-resource `ListObjects` becomes prohibitively slow (multiple seconds). Workspace-level list pre-filters by Workspace before hitting the application database.

**Kessel call:** `ListObjects` for Workspaces where the user is allowed to list (workspace-level permission), then pass resulting workspace IDs as a filter in the application's database query.

**Additional requirement:** Application's database must track the Workspace for each asset (e.g. `workspace_id` on host records).

**RBAC translation:**

| Request input | Translation | Kessel input |
|---------------|-------------|--------------|
| `org_id` | n/a | n/a |
| `resource` | n/a | object type = `rbac/workspace` |
| `operation` | 1:1 mapping to relation, taking into account Host permission | relation |
| `user` | format as subject reference | subject |

**Permission relation design:** The relation used must encode both the RBAC application permission and the host `view` permission (externalized in the Kessel schema).

---

### Default workspace (`default-workspace`)

**Category:** Non-workspace-aware assets

**When to use — ALL conditions must be met:**

1. Service-resource is **NOT Workspace-aware** (not already in Workspace hierarchy)
2. AND resource can be conceptualized as an **"asset"** — customer manages CRUD; could logically be placed into a Workspace in the future

**Examples:** Repositories, SCAP policies, Activation Keys

**Kessel call:** `Check` against the **Default Workspace** for the user's org (look up Default Workspace ID from RBAC, then check against it).

**RBAC workspace lookup:**
```
GET /v2/workspaces?type=default
```
(requires org_id via identity header)

**RBAC translation:**

| Request input | Translation | Kessel input |
|---------------|-------------|--------------|
| `org_id` | lookup Default Workspace ID for the org from RBAC | object (the Default Workspace) |
| `resource` | n/a | n/a |
| `operation` | 1:1 mapping to relation, taking into account Host permission | relation |
| `user` | format as subject reference | subject |

**Note:** This is the most common pattern for wave 2 services whose resources are not yet Workspace-native. The intent is that these resources eventually migrate to the Native pattern, but Default Workspace avoids requiring domain model changes up front.

---

### Root workspace (`root-workspace`)

**Category:** Org-wide settings

**When to use — ALL conditions must be met:**

1. Resource today is **"the organization" as a whole** (e.g. managing an org-wide setting, not a per-workspace asset)
2. AND the operation is **asset-centric** — could logically be scoped to a Workspace or Host in the future; "we could imagine it being Workspace-level"

**Examples:** Advisor recommendation acknowledgement (org-wide but could be Workspace-level), RHC configuration

**Why not Default Workspace?** Default Workspace does not map to the entire organization in the future when a Root Workspace also exists. Using Default Workspace here would break V1→V2 access compatibility.

**Kessel call:** `Check` against the **Root Workspace** for the user's org.

**RBAC workspace lookup:**
```
GET /v2/workspaces?type=root
```
(requires org_id via identity header)

**RBAC translation:**

| Request input | Translation | Kessel input |
|---------------|-------------|--------------|
| `org_id` | lookup Root Workspace ID for the org from RBAC | object (the Root Workspace) |
| `resource` | n/a | n/a |
| `operation` | 1:1 mapping to relation, taking into account Host permission | relation |
| `user` | format as subject reference | subject |

**Caution:** Customers must bind Roles at the Root Workspace to gain access. Bindings at other Workspaces do nothing for Root-scoped permissions, which can be confusing. Flag this in EM review.

---

### Organization-level (`org-level`)

**Category:** Org-wide settings

**When to use — ALL conditions must be met:**

1. Resource today is **"the organization" as a whole**
2. AND the operation is **NOT asset-centric** — would never logically belong at a Workspace level

**Examples:** Authentication policy, permission to invite users, permission to create user groups

**Expected scope:** Mainly outside the realm of Insights apps. More applicable to meta-authorization concerns. No known Insights service currently requires this pattern.

**Note on RBAC migration:** Roles with at least one Organization-level permission get bound at the Organization level (not per-permission — per V2 Role). If a Role mixes Organization-level and Root Workspace permissions, RBAC migrates to two bindings (one at each level). No known System Roles require this.

---

## Decision heuristics (interview questions)

Ask these in order to select the pattern:

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

4. Is the operation "asset-centric" — could it be scoped to a Workspace or Host in the future?
   → YES: root-workspace
   → NO:  org-level
```

---

## Platform gate lookup

Read `context/platform-gates.json` (or path from config `platform_gates_path`). Map each suggested pattern `id` to `gates.{id}` and copy into `platform_gates[]` on the profile.

`jira_key` is informational only (Kessel PM record-keeping) — no skill links against it; the Jira gate-linking skill was removed 2026-07 because it never had a populated key to link against. `platform_gates[]` on the profile exists to support the confidence-cap and paired-path rules above and to give the EM a status readout in the handoff.

---

## Confidence

| Level | Criteria |
|-------|----------|
| `high` | Asset types and v1 permission scope clearly match one pattern; no ambiguity in decision heuristics |
| `medium` | Likely match; EM should confirm — e.g. cardinality unknown, or asset-centric judgment unclear |
| `low` | Insufficient data or multiple patterns possible; document alternatives and flag for Phase 1 follow-up |

Never assign `high` to `org-level` or `root-workspace` for wave 3+ when the corresponding platform gate status is not `ready`.

---

## First-in-pattern (paired path)

Set `program.path` to `paired` (soft warning, EM can override) when:

- No existing `kessel-onboarding` epic with the same primary pattern has Phase 7 Done in prod, **or**
- Platform readiness epic status is `partial` or `ongoing` for the chosen pattern.

Add note in profile: "First service in pattern — Kessel pairing through Phase 5 minimum."

---

## Wave restrictions

- Wave 3+ providers: do **not** suggest `org-level` or `root-workspace` unless platform readiness epic status is `ready`.
- If suggested despite partial gate, set confidence to `low` and flag blocker risk in rationale.

---

## Multi-pattern services

A service may require multiple patterns when different asset types have different access models. In that case:

- List the **primary pattern** first in `patterns[]` (the one covering the majority of permissions).
- **Every asset type in `asset_types[]` must resolve to exactly one pattern.** Set each pattern object's own `asset_types[]` (see [Pattern object](../onboarding-interview-conduct/reference.md#pattern-object)) to the specific asset types that use it — do not leave this implicit in prose. Sum of all patterns' `asset_types[]` must equal the profile's full `asset_types[]`, with no overlaps.
- Document secondary patterns with their own rationale.
- Map each pattern to its corresponding platform gate separately.
- Set `confidence` per-pattern; the overall profile confidence is the lowest of all patterns.
