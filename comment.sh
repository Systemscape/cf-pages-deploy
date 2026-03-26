#!/usr/bin/env bash
set -euo pipefail

DEPLOYMENT_URL="${INPUT_DEPLOYMENT_URL:-}"
ALIAS_URL="${INPUT_ALIAS_URL:-}"
if [ -z "$DEPLOYMENT_URL" ] && [ -z "$ALIAS_URL" ]; then
  echo "No deployment URL, skipping comment"
  exit 0
fi

API_BASE="${GITHUB_SERVER_URL}/api/v1/repos/${GITHUB_REPOSITORY}"
PR_NUMBER=$(jq -r '.pull_request.number' "$GITHUB_EVENT_PATH")
SHORT_SHA="${GITHUB_SHA:0:7}"
MARKER="${INPUT_COMMENT_MARKER}"
ENVIRONMENT="${INPUT_ENVIRONMENT:-preview}"

BODY="${MARKER}
### Cloudflare Pages Preview

| | |
|---|---|"

if [ -n "$ALIAS_URL" ]; then
  BODY+="
| **Preview URL** | ${ALIAS_URL} |"
fi

if [ -n "$DEPLOYMENT_URL" ]; then
  BODY+="
| **Commit URL** | ${DEPLOYMENT_URL} |"
fi

BODY+="
| **Commit** | \`${SHORT_SHA}\` |
| **Environment** | ${ENVIRONMENT} |"

# Find existing comment with our marker
COMMENT_ID=$(curl -sSf \
  -H "Authorization: token ${INPUT_FORGEJO_TOKEN}" \
  "${API_BASE}/issues/${PR_NUMBER}/comments" \
  | jq -r --arg marker "$MARKER" '.[] | select(.body | contains($marker)) | .id' | head -n1)

if [ -n "$COMMENT_ID" ] && [ "$COMMENT_ID" != "null" ]; then
  echo "Updating comment ${COMMENT_ID}"
  curl -sSf -X PATCH \
    -H "Authorization: token ${INPUT_FORGEJO_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg body "$BODY" '{body: $body}')" \
    "${API_BASE}/issues/comments/${COMMENT_ID}"
else
  echo "Creating new comment"
  curl -sSf -X POST \
    -H "Authorization: token ${INPUT_FORGEJO_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg body "$BODY" '{body: $body}')" \
    "${API_BASE}/issues/${PR_NUMBER}/comments"
fi
