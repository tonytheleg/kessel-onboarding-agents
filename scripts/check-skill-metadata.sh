#!/bin/sh
# check-skill-metadata.sh — validate structural metadata for skill Markdown files.
#
# Checks every SKILL.md file under skills/*/:
#   1. File begins with an H1 heading (# Title)
#   2. File contains a "## When to use" section
#   3. No hardcoded user home paths (/home/<username>/) — use ~ or env vars
#
# Ported from the TAILWIND repo's scripts/check-skill-metadata.sh.
#
# Exit codes:
#   0 — all skill files pass
#   1 — one or more findings; output written to REPORT_FILE
#
# False-positive escape hatch: add  # meta-ok: reason  or  <!-- meta-ok: reason -->
# on a flagged line and note the exception in your MR description.

set -e

REPORT_FILE="${REPORT_FILE:-/tmp/skill-metadata-report.txt}"
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"

: > "$REPORT_FILE"

FINDINGS=0

flag() {
    label="$1"; file="$2"; line="$3"; detail="$4"
    printf '[%s] %s:%s  →  %s\n' "$label" "$file" "$line" "$detail" >> "$REPORT_FILE"
    FINDINGS=$((FINDINGS + 1))
}

echo "==> Checking skill file metadata …"

# On MR pipelines, only check skill files changed in the MR.
# Full scan still runs on default-branch pushes and when SCAN_ALL_FILES=true.
_skill_file_list() {
    if [ -n "${CI_MERGE_REQUEST_DIFF_BASE_SHA:-}" ] && [ "${SCAN_ALL_FILES:-}" != "true" ]; then
        changed=$(git diff --name-only --diff-filter=ACMR \
            "${CI_MERGE_REQUEST_DIFF_BASE_SHA}...HEAD" -- 'skills/*/SKILL.md' 2>/dev/null || true)
        if [ -n "$changed" ]; then
            echo "==> MR mode: checking $(echo "$changed" | wc -l | tr -d ' ') changed skill file(s)." >&2
            printf '%s\n' "$changed" | while IFS= read -r p; do printf './%s\n' "$p"; done
        else
            echo "==> MR mode: no skill files changed — skipping." >&2
        fi
    else
        find . \( -path './.git' -o -path './node_modules' \
                  -o -path './scripts' \) -prune -o \
            -path './skills/*/SKILL.md' \
            -type f -print | sort
    fi
}

_skill_file_list | \
while IFS= read -r f; do
    [ -f "$f" ] || continue
    rel="${f#./}"
    content=$(cat "$f" 2>/dev/null) || continue

    # ── 1. H1 title ───────────────────────────────────────────────────────────
    # The first non-blank line should be a # heading.
    first_heading=$(printf '%s\n' "$content" | grep -m1 '^# ' || true)
    if [ -z "$first_heading" ]; then
        flag "META:NO_TITLE" "$rel" "1" "File must start with a # H1 title heading"
    fi

    # ── 2. When-to-use section ────────────────────────────────────────────────
    if ! printf '%s\n' "$content" | grep -q -i '## When to use'; then
        flag "META:NO_WHEN_TO_USE" "$rel" "-" "File must contain a '## When to use' section"
    fi

    # ── 3. Hardcoded user home paths ──────────────────────────────────────────
    # Flags /home/<word>/ paths that look like real usernames.
    # Excluded: /home/user/, /home/runner/, /home/appuser/ (reserved/CI paths)
    printf '%s\n' "$content" | grep -n '/home/[a-zA-Z0-9_-]\+/' 2>/dev/null | \
        grep -v -E '(/home/(user|runner|appuser)/|meta-ok:)' | \
    while IFS= read -r hit; do
        ln=$(printf '%s' "$hit" | cut -d: -f1)
        matched=$(printf '%s' "$hit" | cut -d: -f2-)
        flag "META:HARDCODED_PATH" "$rel" "$ln" "Hardcoded user path — use ~ or an env var instead: ${matched}"
    done

done

echo ""
FINDINGS=$(wc -l < "$REPORT_FILE" | tr -d ' ')

if [ "$FINDINGS" -gt 0 ]; then
    cat "$REPORT_FILE"
    cat >> "$REPORT_FILE" << 'GUIDANCE'

════════════════════════════════════════════════════════════════════
SKILL METADATA CHECK FAILED — remediation guide
════════════════════════════════════════════════════════════════════

Each finding above is tagged [TYPE] file:line → detail.

  META:NO_TITLE        Add a # H1 heading as the first line of the file.
                         # My Skill Name

  META:NO_WHEN_TO_USE  Add a ## When to use section explaining when to invoke
                       this skill.

  META:HARDCODED_PATH  Replace /home/<username>/... with ~ or an environment
                       variable so the skill works for any user.
                         Bad:  /home/alice/projects/
                         Good: ~/projects/

If a finding is a false positive, add  # meta-ok: reason  or
<!-- meta-ok: reason --> on the flagged line and note the exception in your
MR description.
════════════════════════════════════════════════════════════════════
GUIDANCE
    echo "==> check-skill-metadata: FAILED — ${FINDINGS} finding(s). See ${REPORT_FILE}"
    exit 1
else
    echo "==> check-skill-metadata: ok — all skill files pass metadata checks."
fi
