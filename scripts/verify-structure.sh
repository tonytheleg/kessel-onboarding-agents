#!/bin/sh
# verify-structure.sh — structural checks for kessel-onboarding-agents repo layout.
# POSIX sh for Alpine CI. Adapted from the TAILWIND repo's verify-structure.sh,
# trimmed to what this repo actually has (no .claude-plugin manifest, CODEOWNERS,
# GOVERNANCE.md, or LICENSE — this is a small internal tool, not a governed OSS repo).
set -e
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"

FAILED=0

fail() {
    echo "error: $1" >&2
    FAILED=1
}

# ── Required top-level files and directories ─────────────────────────────────
test -f README.md || fail "missing README.md"
test -f AGENTS.md || fail "missing AGENTS.md"
test -d skills || fail "missing skills/ directory"
test -d agents || fail "missing agents/ directory"
test -d commands || fail "missing commands/ directory"
test -d docs || fail "missing docs/ directory"
test -d context || fail "missing context/ directory"

# ── Every skills/*/ must have a SKILL.md ─────────────────────────────────────
for dir in skills/*/; do
    [ -d "$dir" ] || continue
    if ! test -f "${dir}SKILL.md"; then
        fail "skill directory missing SKILL.md: $dir"
    fi
done

# ── Skill directory names must be kebab-case, with no duplicates ────────────
# (Filesystem prevents literal duplicates, but this also guards against
# case-variant collisions on case-insensitive filesystems and enforces the
# naming convention documented in AGENTS.md.)
SKILL_IDS_TMP=$(mktemp)
for dir in skills/*/; do
    [ -d "$dir" ] || continue
    id=$(basename "$dir")
    echo "$id" >> "$SKILL_IDS_TMP"
    case "$id" in
        [a-z0-9]*[a-z0-9])
            case "$id" in
                *[!a-z0-9-]*)
                    fail "skill directory name is not kebab-case: $id"
                    ;;
                *--*)
                    fail "skill directory name has consecutive hyphens: $id"
                    ;;
            esac
            ;;
        *)
            fail "skill directory name is not kebab-case: $id"
            ;;
    esac
done

DUPS=$(sort "$SKILL_IDS_TMP" | uniq -d)
rm -f "$SKILL_IDS_TMP"
if [ -n "$DUPS" ]; then
    fail "duplicate skill IDs under skills/: $DUPS"
fi

# ── Soft check: every skills/*/ directory should be mentioned in AGENTS.md ───
# (Warning only — catches skills added but never documented in the skill index.)
for dir in skills/*/; do
    [ -d "$dir" ] || continue
    id=$(basename "$dir")
    if ! grep -q "$id" AGENTS.md; then
        echo "warning: skill '$id' exists under skills/ but is not mentioned in AGENTS.md" >&2
    fi
done

# ── Soft check: every commands/*.md file should be mentioned in AGENTS.md ────
for f in commands/*.md; do
    [ -f "$f" ] || continue
    base=$(basename "$f")
    if ! grep -q "$base" AGENTS.md; then
        echo "warning: command file '$base' exists under commands/ but is not mentioned in AGENTS.md" >&2
    fi
done

if [ "$FAILED" -ne 0 ]; then
    echo "verify-structure: FAILED" >&2
    exit 1
fi

echo "verify-structure: ok"
