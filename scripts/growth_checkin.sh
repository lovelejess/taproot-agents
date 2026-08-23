#!/bin/bash
set -euo pipefail

# Roamily weekly growth check-in.
# Gathers App Store + PostHog stats, then hands off to Claude Code to
# append a formatted log entry to the Notion "Roamily Growth Plan" page.
#
# Requires:
#   POSTHOG_API_KEY   - PostHog personal/project API key
#   POSTHOG_PROJECT_ID - PostHog project ID
# Both are set in the launchd plist's EnvironmentVariables, which is NOT
# committed to this repo (secrets never in code).

APP_STORE_ID="6786013233"
NOTION_GROWTH_PLAN_ID="3c5afcb9704981f4ac3cf9a111f874cb"

# --- App Store rating/review count (public, no auth) ---
appstore_json=$(curl -s "https://itunes.apple.com/lookup?id=${APP_STORE_ID}")
avg_rating=$(echo "$appstore_json" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['results'][0].get('averageUserRating','n/a'))")
rating_count=$(echo "$appstore_json" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['results'][0].get('userRatingCount','n/a'))")

# --- PostHog weekly active users (last 7 days) ---
if [[ -n "${POSTHOG_API_KEY:-}" && -n "${POSTHOG_PROJECT_ID:-}" ]]; then
  posthog_wau=$(curl -s -X POST "https://us.posthog.com/api/projects/${POSTHOG_PROJECT_ID}/query/" \
    -H "Authorization: Bearer ${POSTHOG_API_KEY}" \
    -H "Content-Type: application/json" \
    -d '{"query":{"kind":"HogQLQuery","query":"select count(distinct person_id) from events where timestamp > now() - interval 7 day"}}' \
    | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['results'][0][0])" 2>/dev/null || echo "n/a")
else
  posthog_wau="n/a (POSTHOG_API_KEY / POSTHOG_PROJECT_ID not set)"
fi

DATE=$(date "+%Y-%m-%d")

SUMMARY=$(cat <<EOF
Growth check-in for ${DATE}:
- App Store rating: ${avg_rating} (${rating_count} ratings)
- PostHog WAU (last 7 days): ${posthog_wau}
EOF
)

echo "$SUMMARY"

# Hand off to Claude Code to append this as a dated log entry under the
# "## Log" section of the Growth Plan page, and flag if any pivot trigger
# from the page's "Pivot triggers" section looks tripped.
claude -p "Append a new dated bullet to the '## Log' section of the Notion page ${NOTION_GROWTH_PLAN_ID} (Roamily Growth Plan) with this check-in data: ${SUMMARY}. Read the page's 'Pivot triggers' section first — if any trigger condition looks met based on this data (or prior log entries), add a one-line flag noting which one and why. Do not change anything else on the page."
