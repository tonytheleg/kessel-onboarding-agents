# migrate-v1-rbac — Reference

Everything Phases 2–4 of `SKILL.md` depend on: the adoption-pattern
decision tree, the language-agnostic call shapes, a gotchas checklist,
and a minimal schema scaffold. Self-contained — no other skill or
plugin is required.

**This reference is language- and service-agnostic.** The target
service may be Go, Java, Python, Ruby, Node, etc. This file describes
*what to call and why*; the *how* (exact types, imports, transport)
comes from the official Kessel SDK and API for the target language —
see [Source of truth](#source-of-truth). Do not hardcode one service's
implementation as the standard; use it only to build intuition, then
write idiomatic code for the service in front of you.

---

## Source of truth

Always resolve concrete API/schema details from these canonical
sources, not from memory or from any single service's code:

| Concern | Canonical source |
|---|---|
| v1→v2 permission names, KSL schema conventions | `project-kessel/rbac-config` |
| Kessel **Inventory API** — `Check`, `CheckForUpdate`, `StreamedListObjects` | `project-kessel/inventory-api` (`api/kessel/inventory/v1beta2`) |
| Kessel **Relations API** — `Check`, `CheckForUpdate`, lookup/list | `project-kessel/relations-api` (`api/kessel/relations/v1beta1`) |
| Language **SDKs / clients** (Go, Java, Python, …) | the `project-kessel` GitHub org (per-language client libraries + generated stubs) |
| RBAC **v2 workspace lookup** | `insights-rbac` — `GET /api/rbac/v2/workspaces/?type=default|root` |

> URLs: `https://github.com/project-kessel/<repo>` for the above repos;
> RBAC v2 API docs ship with `insights-rbac`. Prefer the **upstream**
> project-kessel / RedHatInsights repos over any local fork.

**Learning from existing implementations.** Several mature console
services have already migrated. Reading one end-to-end is the fastest
way to build context on how the pieces fit (identity → subject,
workspace listing → query filter, the dual-path gate). Use them as
worked examples to understand the flow — **do not copy their code
verbatim into the target service or treat any one of them as the
standard.** The standard is the SDK + API above.

---

## Background: what actually changes from v1 to v2

**v1 (`GET /api/rbac/v1/access/?application={app}`)** returns a flat
list of the principal's permissions, each with optional
`resourceDefinitions` that scope the permission to specific resource
attributes (for inventory, an `attributeFilter` on `group.id`). The
service reads that list and filters its own data. Two implicit rules
carry a lot of weight:

- An entry with an **empty `resourceDefinitions`** means *unrestricted*
  access to that permission (all resources in the org).
- A `group.id` filter value may carry semantics beyond plain IDs
  (e.g. inventory's "ungrouped" bucket, historically a `null` id).

**v2 (Kessel)** is relationship-based. Resources (hosts, images,
activation keys, …) live under **workspaces**; workspaces form a tree
(`root` → `default` → standard workspaces). A principal is granted
roles bound to a workspace, and permission flows down the tree. Instead
of "give me my permissions and I'll filter," you ask Kessel directly:

- **Check** — "may this principal do `X` on this specific resource?"
  → Inventory/Relations API `Check` / `CheckForUpdate`. Boolean answer.
- **List** — "which resources (or workspaces) may this principal do
  `X` on?" → Inventory API `StreamedListObjects` (server-streaming) /
  Relations API lookup. A stream of object ids, used to pre-filter a
  query.

A binding at the **root workspace** is the v2 expression of v1's
"unrestricted" — it means *all resources*, not *zero resources*.
Getting that mapping wrong is the #1 migration bug (see
[Gotchas](#gotchas)).

The v1→v2 **permission name** mapping is not invented per-service — it
already exists in rbac-config `.ksl` files as
`add_v1_based_permission(... v2_perm:'...')`. Phase 3 extracts it;
Phase 4 uses those exact names.

---

## Pattern catalog

For each distinct v1 permission `{app}:{resource}:{verb}`, classify it
into one adoption pattern. Walk the tree top to bottom; take the first
match.

```
Is the resource individually registered in Kessel inventory
(has its own object type, each instance parented to a workspace)?
│
├─ NO ─────────────────────────────────────────────────────────────┐
│   Access is granted at workspace granularity only, not per object. │
│   → PATTERN: default-workspace                                     │
│                                                                    │
│      Look up the org's default (or root) workspace, then Check the │
│      v2_perm against that workspace. Use when the service has no   │
│      per-resource ACL story and "can the user use this feature /   │
│      see this org-wide data" is the real question.                 │
│                                                                    │
├─ YES ──┐                                                           │
│        │  The resource IS native. Now: is the check one-at-a-time  │
│        │  on a known resource id, or do you need to enumerate /    │
│        │  filter many resources by access?                         │
│        │                                                           │
│        ├─ Single known resource id, per request                   │
│        │  (e.g. "GET /hosts/{id}" → may I view THIS host?)         │
│        │   → PATTERN: native                                       │
│        │      One Check(principal, view, resource:{id}) per call.  │
│        │                                                           │
│        └─ Must return / filter a COLLECTION by access              │
│           (e.g. "GET /hosts" → list every host I may view;         │
│            or a report that joins across all my hosts)             │
│            → PATTERN: native-ws-list                               │
│               Don't Check N times. StreamedListObjects the         │
│               workspaces (or resources) the principal may view,    │
│               then pre-filter the query by workspace_id / id.      │
│               This is the direct replacement for v1's group.id     │
│               resourceDefinition filtering.                        │
└────────────────────────────────────────────────────────────────────┘
```

### Choosing between `native` and `native-ws-list`

These differ only in **cardinality × access probability**, and the
choice determines whether the service needs a `workspace_id` column and
pre-filtering:

| Signal | Lean `native` (per-resource Check) | Lean `native-ws-list` (list + pre-filter) |
|---|---|---|
| Request shape | one resource id in the path | a list/report/search endpoint |
| Result set size | small, bounded | large / unbounded |
| Fraction accessible | user usually can access the one they asked for | user can access a small subset of many |
| Data-layer story | can check after fetching one row | needs `workspace_id` to filter in the query |

If you can't tell (no cardinality/probability data), **ask the user** —
do not guess. Guessing `native` for a list endpoint produces N Checks
per request; guessing `native-ws-list` for a single-resource endpoint
adds a needless list call and a schema column.

### Pattern → confidence

Record confidence per permission:

- **high** — request shape + rbac-config mapping both unambiguous.
- **medium** — pattern clear but a detail is assumed (e.g. verb
  grouping: v1 `write` often covers update *and* delete; confirm
  whether v2 should split).
- **low** — cardinality unknown, or no v2 mapping exists and the
  resource model is unclear. **Do not write code for `low`** — flag in
  Phase 5 and ask (per SKILL.md "Important Notes").

---

## Call shapes

Language-agnostic. Realize each in the target language using its Kessel
SDK (types, imports, and transport come from
[Source of truth](#source-of-truth)); mirror the service's existing
config/HTTP idioms. Three invariants hold in every language:

- **Subject** = the authenticated principal, derived from the same
  identity the v1 call used (the `x-rh-identity` header → org + user /
  service-account id). Don't hardcode; don't reuse a service PSK as the
  subject.
- **Relation / permission** = the exact `v2_perm` from rbac-config.
- **Fail closed.** Any error/timeout → deny, never allow.

### Preserve the dual path

Never delete the v1 branch as a side effect. Gate on a service flag
(e.g. `KESSEL_ENABLED`):

```
if kessel_enabled:
    allowed = allowed_via_kessel(...)     # new v2 branch
else:
    allowed = allowed_via_rbac_v1(...)    # existing v1 branch, untouched
```

Removing v1 is an explicit Phase 5 decision, made only after the Kessel
path is verified in stage.

### Pattern: `native` (per-resource Check)

```
function may_view(subject, resource_id):
    try:
        return kessel.Check(
            subject   = principal(subject),
            relation  = "<v2_perm>",              # e.g. inventory_host_view
            resource  = (resource_type, resource_id),
        ).allowed
    catch any error:
        log; return false                          # fail closed
```

### Pattern: `native-ws-list` (list workspaces → pre-filter)

Direct replacement for v1 `group.id` resourceDefinition filtering.

**Before (v1), conceptually:** read `/v1/access`, and for each matching
permission either (a) note an **empty resourceDefinition → UNRESTRICTED**
and stop, or (b) collect the `group.id` values (which may include a
special "ungrouped" marker) into an allowed set; then filter the
service's data by that set.

**After (v2):** ask Kessel which workspaces the principal may view, and
handle the unrestricted case explicitly:

```
function allowed_workspaces(subject, org_id):
    # UNRESTRICTED check: can the principal view at the ROOT workspace?
    root_ws = rbac.workspace(org_id, type="root")        # RBAC v2 lookup
    if kessel.Check(principal(subject), "<v2_perm>",
                    ("workspace", root_ws)).allowed:
        return UNRESTRICTED            # sentinel — apply NO workspace filter

    allowed = empty set
    # StreamedListObjects is server-streaming AND paginated:
    # consume the FULL stream, following continuation tokens.
    for obj in kessel.StreamedListObjects(
                   object_type = "workspace",
                   relation    = "<v2_perm>",
                   subject     = principal(subject)):
        allowed.add(obj.id)
    return allowed                     # empty set → genuinely deny
```

Downstream filtering (the query layer) is unchanged if the v1 code
already filtered by group id — host/group id == workspace id in v2.
Two contract points to get right (see Gotchas): distinguish
**UNRESTRICTED** (sentinel) from **empty set** (deny), and preserve any
special bucket (e.g. previously-"ungrouped" resources, which in the
workspace model live in the org's **default** workspace).

### Pattern: `default-workspace` (feature / org-wide gate)

```
function may_use_feature(subject, org_id):
    default_ws = rbac.workspace(org_id, type="default")  # RBAC v2 lookup
    try:
        return kessel.Check(principal(subject), "<v2_perm>",
                            ("workspace", default_ws)).allowed
    catch any error:
        log; return false                                 # fail closed
```

Workspace lookup uses RBAC v2:
`GET /api/rbac/v2/workspaces/?type=default` (or `type=root`), keyed off
the identity header. Cache per-org where the service already caches.

---

## Gotchas

Apply to every new **or existing** Kessel branch. Phase 1c "partial
migration" audits find real bugs here — a half-written Kessel branch is
more dangerous than none.

1. **Unrestricted ≠ empty.** A root-workspace binding means *access to
   everything*. The classic bug: an `unrestricted`/`can_see_all` flag
   that defaults to `false` and is never set `true` on the root-binding
   path, so a fully-privileged user is silently denied everything.
   Verify the root/default-workspace Check exists **and** that hitting
   it short-circuits filtering.

2. **Empty list = deny (v2), but empty resourceDefinition = allow-all
   (v1).** These are opposite. When porting, make the "no filter"
   sentinel explicit so an empty collection can't be misread as "allow
   all" or vice-versa.

3. **Preserve special buckets.** Any bucket the v1 path supported must
   still work — e.g. previously-"ungrouped" resources. In the workspace
   model these usually move to the org's **default** workspace; confirm
   the mapping rather than dropping the special member.

4. **Map every v1 wildcard.** v1 grants can arrive as `{app}:*:*`,
   `{app}:*:{verb}`, `{app}:{resource}:*` as well as the exact
   `{app}:{resource}:{verb}`. The v1 code likely accepted a set of
   these; the v2 relation must cover the same span, or a user who held
   only `{app}:*:{verb}` loses access.

5. **Verb grouping.** v1 `write` frequently covers update *and* delete.
   rbac-config may split them (`..._update`, `..._delete`). Pick the
   relation matching the operation the call site guards; flag a coarse
   call site as an open question.

6. **Consume the whole stream / paginate.** `StreamedListObjects` /
   lookup calls are streamed/paged. Reading only the first page
   silently under-authorizes (user sees a subset of their own
   resources). Iterate to completion, following continuation tokens.

7. **Fail closed.** Timeouts, transport errors, malformed responses →
   deny (and log), never allow. Mirror the v1 code's error posture.

8. **Use the exact v2_perm from rbac-config.** Never invent a relation
   name when `add_v1_based_permission(... v2_perm:'X')` already exists.
   Extract `X` in Phase 3 and use it verbatim.

9. **Principal / identity plumbing.** The Kessel subject is derived
   from the same identity the v1 call used. Handle both `User` and
   `ServiceAccount` identity types if the service serves both.

10. **Don't widen the blast radius.** Keep each edit scoped to the auth
    seam. Migrating authorization is not the time to refactor the query
    layer.

---

## Minimal schema scaffold

Only used when Phase 3 finds **no** existing v2 mapping for a namespace
*and* no schema-design skill/plugin is available. Produces just enough
to unblock Phase 4. Write it to
`/tmp/migrate-v1-rbac/{service-name}/schema/` — **never** into the
`--rbac-config` checkout. Flag in Phase 5 that a human must review it
against rbac-config before merging.

KSL (the schema language) is service-language-independent — these files
describe the authorization model, not the service. The shapes below
mirror rbac-config conventions (`.ksl` with the `add_v1_based_permission`
macro, plus `permissions.json` and `roles.json`). Replace `myapp` /
`myresource` and the verbs with the real values discovered in Phase 1b,
and confirm current syntax against `project-kessel/rbac-config`.

### `{namespace}.ksl`

```ksl
version 0.1
namespace myapp

import rbac

// One line per distinct v1 permission found in Phase 1b.
// v2_perm convention: {app}_{resource}_{action}  (view/update/delete)
public type myresource {
    private relation workspace: [ExactlyOne rbac.workspace]
    relation tenant: workspace.tenant

    @rbac.add_v1_based_permission(app:'myapp', resource:'myresource', verb:'read', v2_perm:'myapp_myresource_view')
    relation view: workspace.myapp_myresource_view
    @rbac.add_v1_based_permission(app:'myapp', resource:'myresource', verb:'write', v2_perm:'myapp_myresource_update')
    relation update: workspace.myapp_myresource_update
}
```

> If a resource is not individually modeled (the `default-workspace`
> pattern), you don't need a `type` block — a bare
> `@rbac.add_v1_based_permission(...)` at namespace top level is enough
> to register the permission.

### `permissions/{app}.json`

```json
{
    "myresource": [
        { "verb": "read" },
        { "verb": "write" },
        { "verb": "*" }
    ]
}
```

### `roles/{app}.json`

```json
{
  "roles": [
    {
      "name": "MyApp Viewer",
      "display_name": "MyApp viewer",
      "description": "Perform read operations on MyApp data.",
      "system": true,
      "platform_default": false,
      "admin_default": false,
      "version": 1,
      "access": [
        { "permission": "myapp:myresource:read" }
      ]
    }
  ]
}
```

After writing the scaffold, re-read it exactly as the "already exist"
path does — extract the `v2_perm` names from the `.ksl` — and continue
to Phase 4 using those names.
