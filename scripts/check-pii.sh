#!/bin/sh
# check-pii.sh — scan repo content for PII and sensitive data patterns that
# violate docs/responsible-use.md policy.
#
# Checks performed:
#   1. Real email addresses (non-placeholder domains)
#   2. Routable IP addresses (non-RFC-5737 / RFC-3849 test ranges)
#   3. Internal-looking hostnames (.corp., .internal, etc. — redhat.com/
#      redhat.atlassian.net are expected and allow-listed; this is an
#      internal Red Hat repo referencing the real corporate Jira instance)
#   4. Phone numbers (E.164 or common formats)
#   5. Credential-like inline values in prose/JSON (loose belt-and-suspenders
#      catch; gitleaks handles the heavier pattern matching)
#
# Ported from the TAILWIND repo's scripts/check-pii.sh.
#
# Exit codes:
#   0 — clean
#   1 — one or more findings; output written to REPORT_FILE
#
# Approved placeholders:
#   Email     user1@example.com / *@example.org / *@example.net / *@redhat.com
#   Hostname  host1.example.com / host1.example.org / redhat.atlassian.net
#   IP        192.0.2.x, 198.51.100.x, 203.0.113.x (RFC 5737)
#             0.0.0.0, 127.0.0.1, ::1
#   Secrets   <token>, <api-key>, <password>, <secret>, <credential>

set -e

REPORT_FILE="${REPORT_FILE:-/tmp/pii-report.txt}"
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"

: > "$REPORT_FILE"

# On MR pipelines, only scan files changed in the MR (avoids failing on
# pre-existing issues in unrelated files).  Full-repo scan still runs on
# default-branch pushes and when SCAN_ALL_FILES=true.
MR_FILES=""
if [ -n "${CI_MERGE_REQUEST_DIFF_BASE_SHA:-}" ] && [ "${SCAN_ALL_FILES:-}" != "true" ]; then
    MR_FILES=$(git diff --name-only --diff-filter=ACMR "${CI_MERGE_REQUEST_DIFF_BASE_SHA}...HEAD" -- \
        '*.md' '*.json' '*.yml' '*.yaml' '*.sh' '*.txt' '*.toml' 2>/dev/null || true)
    if [ -n "$MR_FILES" ]; then
        echo "==> MR mode: scanning $(echo "$MR_FILES" | wc -l | tr -d ' ') changed file(s)."
    else
        echo "==> MR mode: no scannable files changed — skipping."
        exit 0
    fi
fi

scan_and_flag() {
    # scan_and_flag LABEL INCLUDE_PATTERN EXCLUDE_PATTERN [EXCLUDE_PATTERN2 ...]
    # Writes "LABEL file:line → content" to REPORT_FILE for each match.
    label="$1"; include="$2"; shift 2
    # Security scripts and gitleaks config are excluded: they contain patterns by design.
    _pii_file_list() {
        if [ -n "$MR_FILES" ]; then
            printf '%s\n' "$MR_FILES" | grep -v -E \
                '^(scripts/check-pii\.sh|scripts/check-license\.sh|\.gitleaks\.toml)$' | \
                while IFS= read -r p; do printf './%s\n' "$p"; done
        else
            find . \( -path './.git' -o -path './node_modules' \
                      -o -path './scripts/check-pii.sh' \
                      -o -path './.gitleaks.toml' \) -prune -o \
                -type f \( -name '*.md' -o -name '*.json' -o -name '*.yml' \
                           -o -name '*.yaml' -o -name '*.sh' -o -name '*.txt' \
                           -o -name '*.toml' \) -print
        fi
    }
    _pii_file_list | \
    while IFS= read -r f; do
        [ -f "$f" ] || continue
        # grep returns exit 1 when no match — we want to continue scanning
        matches=$(grep -n -E "$include" "$f" 2>/dev/null || true)
        [ -z "$matches" ] && continue
        # Apply each exclude filter in sequence
        filtered="$matches"
        for excl; do
            filtered=$(printf '%s\n' "$filtered" | grep -v -E "$excl" || true)
            [ -z "$filtered" ] && break
        done
        [ -z "$filtered" ] && continue
        printf '%s\n' "$filtered" | while IFS= read -r hit; do
            ln=$(printf '%s' "$hit" | cut -d: -f1)
            content=$(printf '%s' "$hit" | cut -d: -f2-)
            printf '[%s] %s:%s  →  %s\n' "$label" "$f" "$ln" "$content" \
                >> "$REPORT_FILE"
        done
    done
}

echo "==> Scanning for PII and sensitive content …"

# ── 1. Real email addresses ──────────────────────────────────────────────────
# redhat.com is allow-listed: this is an internal Red Hat repo and its docs
# legitimately reference @redhat.com-style contacts.
echo "--- Checking: real email addresses"
scan_and_flag "PII:EMAIL" \
    '[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}' \
    '@(example\.com|example\.org|example\.net|redhat\.com)' \
    '(SPDX-|Apache-|#\s*email:|<[^@]+@[^@]+>|noreply@|user[0-9]+@example|git@|pii-ok:)' \
    '(usingai@|placeholder@|changeme@)'

# ── 2. Routable IP addresses ─────────────────────────────────────────────────
echo "--- Checking: routable IP addresses"
scan_and_flag "PII:IP" \
    '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' \
    '(127\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.|192\.0\.2\.|198\.51\.100\.|203\.0\.113\.|0\.0\.0\.0)' \
    '(192\.0\.2\.x|198\.51\.100\.x|203\.0\.113\.x|<ip-address>|pii-ok:)' \
    '([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+-[0-9])'

# ── 3. Internal-looking hostnames ────────────────────────────────────────────
# Catches clearly-internal patterns like myserver.corp.acme.com, host.internal,
# host.intranet — but NOT redhat.com or redhat.atlassian.net (this repo's
# canonical Jira instance, already excluded below), and NOT this repo's
# `jira.home_project` ServiceProfile field name (matches the `.home` fragment
# by coincidence — it's a field name, not a hostname).
echo "--- Checking: internal hostnames"
scan_and_flag "PII:HOSTNAME" \
    '[a-z0-9\-]+(\.corp\.[a-z]+|\.internal|\.intranet|\.lan|\.home)[^a-z]' \
    '(example\.(com|org|net)|host1\.example|placeholder|jira\.home_project|pii-ok:)'

# ── 4. Phone numbers ─────────────────────────────────────────────────────────
echo "--- Checking: phone numbers"
scan_and_flag "PII:PHONE" \
    '(\+1[\s\-.]?)?(\(?\d{3}\)?[\s\-.]?\d{3}[\s\-.]?\d{4})' \
    '(version|v[0-9]|[0-9]{4}-[0-9]{2}-[0-9]{2}|[0-9]+\.[0-9]+\.[0-9]+|pii-ok:)'

# ── 5. Hardcoded Jira / Atlassian instance URLs ───────────────────────────────
# This repo's canonical Jira instance (redhat.atlassian.net) is intentionally
# referenced throughout docs/config templates — allow-listed below. Flags
# *other* Atlassian instance URLs that shouldn't appear (e.g. a personal or
# unrelated tenant accidentally pasted from a screenshot/example).
echo "--- Checking: unexpected Atlassian instance URLs"
scan_and_flag "PII:JIRA_URL" \
    'https://[a-zA-Z0-9-]+\.atlassian\.net' \
    '(redhat\.atlassian\.net|your-org\.atlassian|example\.atlassian|<[a-z-]+>|pii-ok:)'

# ── 6. Inline credential assignments (belt-and-suspenders) ────────────────────
echo "--- Checking: inline credential assignments"
scan_and_flag "SENSITIVE:CRED" \
    '(password|passwd|secret|token|api[_\-]?key|auth[_\-]?key|private[_\-]?key|access[_\-]?key|client[_\-]?secret)[=:][[:space:]]*["\x27]?[A-Za-z0-9+/]{16,}' \
    '(<token>|<password>|<api-key>|<secret>|<credential>|<private-key>|YOUR_|REPLACE_|PLACEHOLDER|example|changeme|dummy|your-atlassian-api-token|pii-ok:)'

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
FINDINGS=$(wc -l < "$REPORT_FILE" | tr -d ' ')

if [ "$FINDINGS" -gt 0 ]; then
    cat "$REPORT_FILE"
    cat >> "$REPORT_FILE" << 'GUIDANCE'

════════════════════════════════════════════════════════════════════
SECURITY / PRIVACY CHECK FAILED — remediation guide
════════════════════════════════════════════════════════════════════

Each finding above is tagged [TYPE] file:line → matched content.

  PII:EMAIL      Replace with an approved placeholder:
                   user1@example.com  (RFC 2606 domain)

  PII:IP         Replace with an approved documentation range:
                   192.0.2.x, 198.51.100.x, 203.0.113.x  (RFC 5737)
                 or use the literal placeholder: <ip-address>

  PII:HOSTNAME   Replace internal hostnames with:
                   host1.example.com / host1.example.org

  PII:PHONE      Remove or replace with: <phone-number>

  PII:JIRA_URL   This repo's canonical Jira instance is redhat.atlassian.net
                 (already allow-listed). Remove any other hardcoded Atlassian
                 instance URL — it likely doesn't belong in this repo.

  SENSITIVE:CRED Replace inline secret values with bracketed placeholders:
                   <token>  <api-key>  <password>  <secret>

Policy reference: docs/responsible-use.md

If a finding is a false positive, add  # pii-ok: reason  on the flagged
line (or <!-- pii-ok: reason --> in Markdown) and note the exception in your
MR description.
════════════════════════════════════════════════════════════════════
GUIDANCE
    echo "==> check-pii: FAILED — ${FINDINGS} finding(s). See ${REPORT_FILE}"
    exit 1
else
    echo "==> check-pii: ok — no PII or sensitive content detected."
fi
