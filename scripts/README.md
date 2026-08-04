# Scripts

Automation for repository hygiene — structure checks and CI helpers, ported and
adapted from the TAILWIND program repo's `scripts/` (see `AGENTS.md` for the
CI adoption rationale).

## Current scripts

| Script | Purpose | CI stage |
| ------ | ------- | -------- |
| [`verify-structure.sh`](verify-structure.sh) | Validates top-level layout (`README.md`, `AGENTS.md`, `skills/`, `agents/`, `commands/`, `docs/`, `context/`); every `skills/*/` has a `SKILL.md`; no duplicate/non-kebab-case skill directory names; warns (non-blocking) if a skill or command file isn't mentioned in `AGENTS.md` | `verify` |
| [`check-skill-metadata.sh`](check-skill-metadata.sh) | Checks every `SKILL.md` for a top-level `#` heading and a `## When to use` section (case-insensitive), and flags hardcoded `/home/<user>/` paths | `verify` |
| [`quick_validate.py`](quick_validate.py) | Validates `SKILL.md` YAML frontmatter — required `name`/`description`, allowed keys, kebab-case naming, length limits | `verify` |
| [`check-pii.sh`](check-pii.sh) | Scans changed/committed files for PII patterns (email, phone, IP, internal hostnames) and inline credential-looking assignments | `security` |

## Local usage

Run any script directly from the repo root:

```bash
sh scripts/verify-structure.sh
sh scripts/check-skill-metadata.sh
sh scripts/check-pii.sh
python3 scripts/quick_validate.py skills/onboarding-preflight/
```

`check-skill-metadata.sh` and `check-pii.sh` default to a full-repo scan
locally; in CI on merge request pipelines they scope to changed files only
(set `SCAN_ALL_FILES=true` to force a full scan in CI).

## False positives

- `check-skill-metadata.sh`: add `# meta-ok: reason` or `<!-- meta-ok: reason -->` on the flagged line.
- `check-pii.sh`: add `# pii-ok: reason` or `<!-- pii-ok: reason -->` on the flagged line.

Secret detection (gitleaks) is configured separately via [`.gitleaks.toml`](../.gitleaks.toml) at the repo root.
