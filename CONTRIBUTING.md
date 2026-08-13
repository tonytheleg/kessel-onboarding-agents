# Contributing to kessel-onboarding-agents

## Overview

This repo ships as a Claude Code marketplace plugin. Changes to skills, agents, or commands become available to users only when they run a plugin update. **Updates are not automatic**. Understanding when and how to bump the plugin version is the most important part of contributing to this repo.

---

## How the plugin update lifecycle works

When a user installs the plugin (`/plugin install kessel-onboarding@kessel-onboarding-agents`), Claude Code:

1. Clones this repo to `~/.claude/plugins/marketplaces/kessel-onboarding-agents/` — a live git clone.
2. Extracts the plugin files into a versioned cache at `~/.claude/plugins/cache/kessel-onboarding-agents/kessel-onboarding/{version}/`.
3. Records the installed version and git commit SHA in `installed_plugins.json`.

**Users run skills from the cache, not from the live clone.** This means:

- Pushing a change to GitHub does not update users' skills.
- Users must explicitly run `/plugin update kessel-onboarding@kessel-onboarding-agents` to get new changes.
- The update command checks the `version` field in `.claude-plugin/plugin.json`. If the version hasn't changed, the cache is not refreshed even after a pull.

**Version bumps are the release mechanism.** A PR that changes skills, agents, or commands without bumping the version will not reach users until the next version bump.

---

## What requires a version bump

### Always bump

Any change to the following files requires a version bump — these are the files that get extracted into the user's plugin cache:

| Directory / File | What it controls |
|---|---|
| `skills/*/SKILL.md` | Skill instructions and behavior |
| `skills/*/reference.md` | Reference data loaded by skills |
| `agents/*.md` | Agent orchestration logic |
| `commands/*.md` | Slash command definitions |
| `context/*.json` | Platform-gate statuses and phase checklists used by skills |
| `examples/` | Example files referenced by skills |
| `.claude-plugin/plugin.json` | Plugin metadata |

### Does not require a version bump

| File | Reason |
|---|---|
| `docs/` | User-facing documentation only |
| `README.md`, `CONTRIBUTING.md` | Repo documentation |
| `.github/` | CI, templates, CODEOWNERS |
| `scripts/` | CI scripts |
| `demo/` or `examples/taskmanager/` | Demo app code, not loaded by the plugin |
| `.gitignore`, `.gitleaks.toml` | Repo tooling |

---

## Version bump guidance

This repo follows [Semantic Versioning](https://semver.org/): `MAJOR.MINOR.PATCH`.

### Patch (`1.0.0` → `1.0.1`)

Bug fixes and small improvements that don't change what a skill does or what it produces.

Examples:
- Fixing a typo or unclear wording in a SKILL.md
- Correcting a wrong example in reference.md
- Fixing a broken link or stale file path
- Tightening validation rules without changing outputs

### Minor (`1.0.0` → `1.1.0`)

New capabilities, new skills, or meaningful behavior changes that are backward-compatible — existing outputs and workflows remain valid.

Examples:
- Adding a new skill
- Adding a new command
- Adding a new flag to an existing command
- Expanding reference.md with new guidance that changes what the skill generates
- Adding a new question to the interview skill

### Major (`1.0.0` → `2.0.0`)

Breaking changes; existing artifacts (ServiceProfiles, handoffs, generated schemas) are no longer compatible, or the workflow changes significantly enough that users need to re-run parts of the process.

Examples:
- Changing the ServiceProfile JSON schema in a way that breaks existing handoff files
- Renaming slash commands
- Changing the artifacts directory structure
- Removing a skill or command

---

## How to bump the version

Two files must be updated together — they must always be in sync:

**`.claude-plugin/plugin.json`**
```json
{
  "version": "1.1.0",
  ...
}
```

**`.claude-plugin/marketplace.json`**
```json
{
  "plugins": [
    {
      "version": "1.1.0",
      ...
    }
  ]
}
```

Include the version bump in the same PR as the skill changes. Do not open a separate PR just to bump the version.

---

## Release process

1. Make your changes to skills, agents, or commands.
2. Determine the appropriate version bump (patch / minor / major).
3. Update `version` in both `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`.
4. Open a PR. The PR description should note the version bump and summarize what changed for users.
5. After merge, users running `/plugin update kessel-onboarding@kessel-onboarding-agents` will receive the new version on their next update.

There is no manual publish step; the GitHub repo IS the plugin distribution channel.

### Bypassing version checks during active development

CodeRabbit will flag missing version bumps on PRs that touch plugin files. To suppress this during active development (e.g. while building toward an initial release or to submit multiple small PRs to then release on a final PR), add one of the following to your PR:

- Include the text `skip-version-bump` anywhere in the PR title or description
- Apply the GitHub label `initial-build` to the PR

Remove these once the plugin is published and versioning discipline should be enforced on every PR.

---

## Adding new skills

When adding a new skill:

1. Create `skills/{skill-name}/SKILL.md` following the existing skill format (see any existing skill for structure).
2. Add the skill to the `## Skill reference` table in `README.md`.
3. Add a slash command spec in `commands/{name}.md` if the skill is directly user-invocable.
4. Update `AGENTS.md` skill locations tree.
5. If the skill is called by an agent, update the agent's skills table.
6. Bump the minor version.

---

## Updating context files

`context/platform-gates.json` and `context/phase-checklist.md` are loaded by skills at runtime. Changes to these files affect skill behavior and require a version bump. The platform-gates file in particular should be updated whenever a pattern's readiness status changes — update the `status_reviewed_at` field when you do.
