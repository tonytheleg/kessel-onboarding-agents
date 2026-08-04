# Provisioner stub validation — Activation Keys pilot

Dry-run validation that the Activation Keys handoff contains every field the Provisioner Agent needs to clone the templates in `context/phase-checklist.md`.

**Handoff:** [activation-keys-handoff.md](activation-keys-handoff.md)  
**Profile:** [../artifacts/profiles/activation-keys-profile.json](../artifacts/profiles/activation-keys-profile.json)

## Handoff parse check

| Handoff field | Present | Maps to Jira |
|---------------|---------|--------------|
| Provider | yes | Initiative summary `[Kessel Onboarding] Subscription Management` |
| Service | yes | Epic summary `[Kessel Onboarding] Activation Keys` |
| Home project | yes | Feature epic lookup / dedup project (TUSC); onboarding issues go to RHCLOUD |
| Feature epic | yes | Epic link relates to TUSC-271 |
| Wave | yes | Description / reporting only |
| Onboarding path | yes | Phase 3 pairing note if `paired` |
| Adoption patterns | yes | Epic description |
| UI access checks | yes | Skip UI story (`not_required`) |
| Tech stack | yes | Epic description |
| Platform gates | yes | Informational only — no Jira link is created (gate-linking skill removed 2026-07) |
| Dedup status | yes | `clean` → provision allowed |
| Contacts | yes | Epic + Initiative descriptions |
| ServiceProfile path | yes | Machine-readable source |
| Schema version | yes | 1.2 |
| Status | yes | Ready for dry-run |

**Result:** PASS — handoff block parses completely.

## ServiceProfile field check (Provisioner)

| Profile path | Value | Provisioner use |
|--------------|-------|-----------------|
| `provider.name` | Subscription Management | Initiative |
| `service.name` | Activation Keys | Epic |
| `service.slug` | activation-keys | Artifact naming |
| `jira.home_project` | TUSC | Project |
| `jira.feature_epic_key` | TUSC-271 | relates to |
| `jira.label` | kessel-onboarding | Labels |
| `patterns[0].id` | default-workspace | Gate lookup |
| `ui_access_checks` | not_required | No UI story |
| `dedup.status` | clean | Create issues |
| `kickoff.docs_reviewed` | true | Phase 0 checklist in story desc |

**Result:** PASS — all required JSON fields populated.

## Simulated dry-run issue batch

Provisioner would propose (not create):

| # | Type | Summary | Parent / Link |
|---|------|---------|---------------|
| 1 | Initiative | `[Kessel Onboarding] Subscription Management` | — |
| 2 | Epic | `[Kessel Onboarding] Activation Keys` | Parent → #1 |
| 3 | Story | `Phase 0: Kickoff — Activation Keys` | Epic Link → #2 |
| 4 | Story | `Phase 1: Identify adoption pattern(s) — Activation Keys` | Epic Link → #2 |
| 5 | Story | `Phase 2: Model permissions and schema — Activation Keys` | Epic Link → #2 |
| — | — | *Phase 3: Inventory migration — skipped (`inventory_reporting: false`)* | — |
| 6 | Story | `Phase 4: PoC — Activation Keys` | Epic Link → #2 |
| 7 | Story | `Phase 5: Verified in dev environment — Activation Keys` | Epic Link → #2 |
| 8 | Story | `Phase 6a: Enabled and verified in stage — Activation Keys` | Epic Link → #2 |
| 9 | Story | `Phase 6b: Feature flag and dual-path audit — Activation Keys` | Epic Link → #2 |
| 10 | Story | `Phase 7: Enabled and verified in prod — Activation Keys` | Epic Link → #2 |

UI story omitted (`ui_access_checks: not_required`). Phase 3 (Inventory migration) omitted (`inventory_reporting: false`). Full batch with all conditionals would be 12 issues.

**Result:** PASS — 10 issues derivable from profile + [jira-field-mapping.md](../context/jira-field-mapping.md).

## Gaps for Track B (Provisioner implementation)

1. Live dedup not run in pilot — production runs must use Atlassian MCP.
2. RHCLOUD MCP create permission may be blocked for some users; the Team field and ADF descriptions always require the Jira REST API (`.env`) fallback regardless.

(Gate-linking, previously listed as gap #1, was removed 2026-07 — see [docs/configuration.md](../docs/configuration.md#platform-gate-status).)

## Pilot conclusion

Interview Agent v1 deliverables are sufficient for Provisioner stub input. EM review time target: under 30 minutes for Activation Keys-shaped services.
