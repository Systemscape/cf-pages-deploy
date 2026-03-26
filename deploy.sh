#!/usr/bin/env bash
set -euo pipefail

# Determine branch name explicitly to avoid detached HEAD producing "head.<project>.pages.dev"
if [ "$GITHUB_EVENT_NAME" = "pull_request" ]; then
  BRANCH="$GITHUB_HEAD_REF"
else
  BRANCH="$GITHUB_REF_NAME"
fi

# Wrangler >= 3.81.0 writes structured JSON output to this directory
WRANGLER_OUTPUT_DIR=$(mktemp -d)
export WRANGLER_OUTPUT_FILE_DIRECTORY="$WRANGLER_OUTPUT_DIR"

OUTPUT=$(npx wrangler pages deploy "$INPUT_DIRECTORY" \
  --project-name="$INPUT_PROJECT_NAME" \
  --branch="$BRANCH" \
  --commit-hash="$GITHUB_SHA" 2>&1) || {
  echo "::error::Wrangler deploy failed"
  echo "$OUTPUT"
  exit 1
}

echo "$OUTPUT"

# --- Extract outputs ---

DEPLOYMENT_URL=""
ALIAS_URL=""
ENVIRONMENT=""

# Primary: parse structured JSON artifacts (wrangler >= 3.81.0)
for f in "$WRANGLER_OUTPUT_DIR"/*.json; do
  [ -f "$f" ] || continue
  while IFS= read -r line; do
    MATCH=$(echo "$line" | jq -r 'select(.type == "pages-deploy-detailed") | [.url, .alias, .environment] | map(. // "") | @tsv' 2>/dev/null) || continue
    [ -z "$MATCH" ] && continue
    IFS=$'\t' read -r DEPLOYMENT_URL ALIAS_URL ENVIRONMENT <<< "$MATCH"
    break 2
  done < "$f"
done

# Fallback: parse stdout (older wrangler versions)
if [ -z "$DEPLOYMENT_URL" ]; then
  DEPLOYMENT_URL=$(echo "$OUTPUT" | sed -n 's/.*Take a peek over at \(https:\/\/[^ ]*\).*/\1/p')
  # Handle timeout/unknown status case
  if [ -z "$DEPLOYMENT_URL" ]; then
    DEPLOYMENT_URL=$(echo "$OUTPUT" | sed -n 's/.*Visit your deployment at \(https:\/\/[^ ]*\).*/\1/p')
  fi
fi

if [ -z "$ALIAS_URL" ]; then
  ALIAS_URL=$(echo "$OUTPUT" | sed -n 's/.*alias URL: \(https:\/\/[^ ]*\).*/\1/p')
fi

if [ -z "$ENVIRONMENT" ]; then
  if [ -n "$ALIAS_URL" ] && [ "$ALIAS_URL" != "$DEPLOYMENT_URL" ]; then
    ENVIRONMENT="preview"
  else
    ENVIRONMENT="production"
  fi
fi

rm -rf "$WRANGLER_OUTPUT_DIR"

# Write step outputs
{
  echo "deployment-url=${DEPLOYMENT_URL}"
  echo "deployment-alias-url=${ALIAS_URL}"
  echo "environment=${ENVIRONMENT}"
} >> "$GITHUB_OUTPUT"
