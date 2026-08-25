# Kessel Onboarding Agents — Claude context

This repo ships as a Claude Code plugin. When working in this repo or after completing any onboarding skill, use `context/implementation-topics.json` to offer relevant follow-up implementation guidance.

## Follow-up prompt pattern

After any main skill completes its primary output (interview → profile approved, schema-design → schemas generated, provision → dry-run shown, migrate-rbac-v1 → report written), if the user is not immediately moving to another skill:

1. Read `context/implementation-topics.json`.
2. Select 3–5 topics whose `tags` match the service's context:
   - `inventory_migration_required = true` → suggest `inventory-reporting`, `schema-pr`
   - `ui_access_checks = required` → suggest `endpoint-protection`
   - Pattern = `native-ws-list` → suggest `list-endpoint-authorization`
   - Pattern = `default-workspace` or `root-workspace` → suggest `workspace-lookup`
   - Credentials not set up → always suggest `service-account`
   - Any service → always include `sdk-setup`, `check-vs-checkforupdate`
3. Present suggestions conversationally — not as a menu, just a short list:
   > "A few things worth looking at next:
   > - **SDK Setup** — configuring the Kessel client for Go
   > - **Check vs CheckForUpdate** — which to use for reads vs writes
   > - **Inventory Reporting** — calling ReportResource and DeleteResource correctly
   > Want to dig into any of these, or something else?"
4. When the user picks a topic or asks a related question, resolve it based on which field is set:
   - `public_url` — fetch with WebFetch and answer from the doc content. Do not reproduce the full doc; answer the specific question with citations.
   - `inscope_guide` — tell the user: "See the '[inscope_guide value]' guide in InScope." Do not fabricate content for internal docs.
   - `plugin_ref` — read that file from within the plugin directory and answer from it.
5. Keep the interview profile, schema artifacts, and migration context in scope throughout — tailor answers to the specific service (language, patterns, asset types) rather than giving generic guidance.

## What this is not

This is not a structured skill. It is free-form conversation guided by the topic index. Do not force users through a fixed flow — answer what they ask, suggest what's relevant, and follow their lead.

## Topic index location

`context/implementation-topics.json` — read this file to get the current topic list and URLs. Never hardcode topic URLs in skill files; always read from this file so docs stay as the single source of truth.
