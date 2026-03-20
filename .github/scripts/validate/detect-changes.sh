#!/bin/bash
set -e

# detect-changes.sh
# Detects which plugins were modified in a PR, checks .github/ protection,
# and determines whether the PR should be auto-closed for lack of permission.
#
# Usage: detect-changes.sh <pr_author> <base_ref>
#
# Outputs (written to $GITHUB_OUTPUT):
#   matrix        - JSON array of plugin names for matrix strategy
#   plugin_count  - Number of modified plugins
#   close_pr      - "true" if the PR should be auto-closed (no permission, no new plugins)
#
# Exit codes:
#   0  - OK (matrix emitted, proceed to validation)
#   1  - Hard block (e.g. .github/ modification by unauthorized user, no plugin changes)

PR_AUTHOR=$1
BASE_REF=$2

if [[ -z "$PR_AUTHOR" || -z "$BASE_REF" ]]; then
  echo "Usage: $0 <pr_author> <base_ref>"
  exit 1
fi

REPO_OWNER=$(echo "$GITHUB_REPOSITORY" | cut -d'/' -f1)
REPO_NAME=$(echo "$GITHUB_REPOSITORY" | cut -d'/' -f2)

has_write_access() {
  local author=$1
  local perm
  perm=$(gh api repos/$REPO_OWNER/$REPO_NAME/collaborators/$author/permission --jq .permission 2>/dev/null || echo "none")
  if [[ "$perm" == "admin" || "$perm" == "maintain" || "$perm" == "write" ]]; then
    echo "1"
  else
    echo "0"
  fi
}

MERGE_BASE=$(git merge-base origin/$BASE_REF HEAD)

# --- .github/ protection check ---
GITHUB_CHANGES=$(git diff --name-only $MERGE_BASE HEAD | grep '^\.github/' || true)
if [[ -n "$GITHUB_CHANGES" ]]; then
  if [[ "$(has_write_access "$PR_AUTHOR")" -ne 1 ]]; then
    echo "## Workflow file modification denied" >&2
    echo "" >&2
    echo "This PR modifies files under \`.github/\`, which requires admin, maintain, or write access to the repository." >&2
    echo "" >&2
    echo "**Modified files:**" >&2
    echo "\`\`\`" >&2
    echo "$GITHUB_CHANGES" >&2
    echo "\`\`\`" >&2
    exit 1
  fi
fi

# --- Detect modified plugins ---
PLUGIN_LIST=$(git diff --name-only $MERGE_BASE HEAD \
  | grep '^plugins/' | cut -d '/' -f2 | sort -u)

if [[ -z "$PLUGIN_LIST" ]]; then
  echo "::error::No plugin changes detected in this PR."
  exit 1
fi

PLUGIN_COUNT=$(echo "$PLUGIN_LIST" | wc -w | tr -d ' ')

# --- Check if any modified plugin is new (does not exist on base branch) ---
HAS_NEW_PLUGIN=0
for plugin in $PLUGIN_LIST; do
  if ! git show origin/$BASE_REF:"plugins/$plugin/plugin.json" > /dev/null 2>&1; then
    HAS_NEW_PLUGIN=1
    break
  fi
done

# --- Check if PR author has permission for at least one modified plugin ---
HAS_ANY_PERMISSION=0
IS_REPO_MAINTAINER=$(has_write_access "$PR_AUTHOR")
if [[ "$IS_REPO_MAINTAINER" -eq 1 ]]; then
  HAS_ANY_PERMISSION=1
else
  for plugin in $PLUGIN_LIST; do
    plugin_json="plugins/$plugin/plugin.json"
    if [[ -f "$plugin_json" ]]; then
      OWNER=$(jq -r '.owner // ""' "$plugin_json")
      MAINTAINERS=$(jq -r '[.maintainers[]?] | join(" ")' "$plugin_json")
      if [[ "$PR_AUTHOR" == "$OWNER" ]] || [[ " $MAINTAINERS " =~ " $PR_AUTHOR " ]]; then
        HAS_ANY_PERMISSION=1
        break
      fi
    fi
  done
fi

# Determine if this PR should be auto-closed:
# Only close if the author has no permission AND there are no new plugins
CLOSE_PR="false"
if [[ $HAS_ANY_PERMISSION -eq 0 ]] && [[ $HAS_NEW_PLUGIN -eq 0 ]]; then
  CLOSE_PR="true"
fi

# Build JSON matrix array
MATRIX_JSON=$(echo "$PLUGIN_LIST" | jq -Rnc '[inputs]')

echo "matrix=$MATRIX_JSON" >> "$GITHUB_OUTPUT"
echo "plugin_count=$PLUGIN_COUNT" >> "$GITHUB_OUTPUT"
echo "close_pr=$CLOSE_PR" >> "$GITHUB_OUTPUT"

echo "Detected $PLUGIN_COUNT plugin(s): $PLUGIN_LIST"
echo "close_pr=$CLOSE_PR"
