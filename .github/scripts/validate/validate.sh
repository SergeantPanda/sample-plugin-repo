#!/bin/bash
set -e

# validate-single-plugin.sh
# Validates one plugin and writes a markdown report fragment to a file.
#
# Usage: validate-single-plugin.sh <plugin_name> <pr_author> <base_ref> <output_file>
#
# Arguments:
#   plugin_name  - Plugin folder name (e.g. my-plugin)
#   pr_author    - GitHub username of PR author
#   base_ref     - Base branch reference (e.g. main)
#   output_file  - File path to write the markdown report fragment to
#
# Outputs (written to $GITHUB_OUTPUT):
#   result       - "pass" or "fail"
#   is_new       - "true" if this is a new plugin (not on base branch)
#   has_permission - "true" if pr_author is permitted to modify this plugin
#
# Environment variables required:
#   GITHUB_REPOSITORY - Full repository name (owner/repo)
#   GH_TOKEN          - GitHub token for API access

PLUGIN_NAME=$1
PR_AUTHOR=$2
BASE_REF=$3
OUTPUT_FILE=${4:-/dev/stdout}

if [[ -z "$PLUGIN_NAME" || -z "$PR_AUTHOR" || -z "$BASE_REF" ]]; then
  echo "Usage: $0 <plugin_name> <pr_author> <base_ref> [output_file]"
  exit 1
fi

REPO_OWNER=$(echo "$GITHUB_REPOSITORY" | cut -d'/' -f1)
REPO_NAME=$(echo "$GITHUB_REPOSITORY" | cut -d'/' -f2)

PLUGIN_DIR="plugins/$PLUGIN_NAME"
PLUGIN_JSON="$PLUGIN_DIR/plugin.json"
README="$PLUGIN_DIR/README.md"

check_repo_maintainer() {
  local author=$1
  PERMISSION=$(gh api repos/$REPO_OWNER/$REPO_NAME/collaborators/$author/permission --jq .permission 2>/dev/null || echo "none")
  if [[ "$PERMISSION" == "admin" || "$PERMISSION" == "maintain" || "$PERMISSION" == "write" ]]; then
    echo "1"
  else
    echo "0"
  fi
}

validate_semver() {
  local version=$1
  if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then echo "1"; else echo "0"; fi
}

validate_dispatcharr_version() {
  local version=$1
  if [[ "$version" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]]; then echo "1"; else echo "0"; fi
}

version_greater_than() {
  local new_version=$1
  local old_version=$2
  IFS='.' read -r NEW_MAJOR NEW_MINOR NEW_PATCH <<< "$new_version"
  IFS='.' read -r OLD_MAJOR OLD_MINOR OLD_PATCH <<< "$old_version"
  if (( NEW_MAJOR > OLD_MAJOR )); then return 0; fi
  if (( NEW_MAJOR < OLD_MAJOR )); then return 1; fi
  if (( NEW_MINOR > OLD_MINOR )); then return 0; fi
  if (( NEW_MINOR < OLD_MINOR )); then return 1; fi
  if (( NEW_PATCH > OLD_PATCH )); then return 0; fi
  return 1
}

failed=0
is_new="false"
has_permission="false"

{
  echo "### Plugin: \`$PLUGIN_NAME\`"
  echo ""

  # Folder name format
  if [[ ! "$PLUGIN_NAME" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    echo "- ❌ Folder name must be lowercase-kebab-case"
    echo "  Current: \`$PLUGIN_NAME\`  Example: \`my-plugin-name\`"
    failed=1
  else
    echo "- ✅ Folder name format valid"
  fi

  # plugin.json existence
  if [[ ! -f "$PLUGIN_JSON" ]]; then
    echo "- ❌ plugin.json missing"
    echo ""
    echo "❌ **Validation failed for \`$PLUGIN_NAME\`**"
    # Write outputs and exit
    echo "result=fail" >> "$GITHUB_OUTPUT"
    echo "is_new=false" >> "$GITHUB_OUTPUT"
    echo "has_permission=false" >> "$GITHUB_OUTPUT"
    exit 0  # non-fatal to matrix — report fragment is written
  fi
  echo "- ✅ plugin.json exists"

  # README (optional)
  if [[ ! -f "$README" ]]; then
    echo "- ℹ️ README.md not provided (optional)"
  else
    echo "- ✅ README.md exists"
  fi

  # JSON syntax
  if ! jq empty "$PLUGIN_JSON" 2>/dev/null; then
    echo "- ❌ Invalid JSON in plugin.json"
    echo ""
    echo "❌ **Validation failed for \`$PLUGIN_NAME\`**"
    echo "result=fail" >> "$GITHUB_OUTPUT"
    echo "is_new=false" >> "$GITHUB_OUTPUT"
    echo "has_permission=false" >> "$GITHUB_OUTPUT"
    exit 0
  fi
  echo "- ✅ JSON valid"

  # Required fields
  for key in name version description; do
    if ! jq -e ".\"$key\"" "$PLUGIN_JSON" >/dev/null 2>&1; then
      echo "- ❌ Required property \`$key\` missing"
      failed=1
    fi
  done

  # Extract metadata
  OWNER=$(jq -r '.owner // ""' "$PLUGIN_JSON")
  MAINTAINERS=$(jq -r '[.maintainers[]?] | join(" ")' "$PLUGIN_JSON")
  VERSION=$(jq -r '.version' "$PLUGIN_JSON")

  # owner/maintainers presence
  if [[ -z "$OWNER" ]] && [[ -z "$MAINTAINERS" ]]; then
    echo "- ❌ At least one of \`owner\` or \`maintainers\` must be set"
    echo "  **Action required:** Add your GitHub username to \`owner\`, \`maintainers\`, or both."
    echo "  Example: \`\"owner\": \"your-github-username\"\`"
    echo "  > Note: These fields are required by this repository to manage contribution permissions."
    failed=1
  fi

  # Permission check — use base branch version to prevent self-granting via the PR
  IS_REPO_MAINTAINER=$(check_repo_maintainer "$PR_AUTHOR")
  if [[ "$IS_REPO_MAINTAINER" -eq 1 ]]; then
    echo "- ✅ Permission check passed"
    has_permission="true"
  elif git show "origin/${BASE_REF}:${PLUGIN_JSON}" > /dev/null 2>&1; then
    BASE_JSON=$(git show "origin/${BASE_REF}:${PLUGIN_JSON}")
    BASE_OWNER=$(echo "$BASE_JSON" | jq -r '.owner // ""')
    BASE_MAINTAINERS=$(echo "$BASE_JSON" | jq -r '[.maintainers[]?] | join(" ")')
    if [[ "$PR_AUTHOR" == "$BASE_OWNER" ]] || [[ " $BASE_MAINTAINERS " =~ " $PR_AUTHOR " ]]; then
      echo "- ✅ Permission check passed"
      has_permission="true"
    else
      echo "- ❌ **Permission denied**: \`$PR_AUTHOR\` is not listed in \`owner\` or \`maintainers\` on the base branch"
      failed=1
    fi
  else
    # New plugin — no base version to check against.
    # The PR author must include themselves in owner or maintainers so future
    # PRs can be authorized. This is a correctable validation error, not a closure.
    if [[ "$PR_AUTHOR" == "$OWNER" ]] || [[ " $MAINTAINERS " =~ " $PR_AUTHOR " ]]; then
      echo "- ✅ New plugin: \`$PR_AUTHOR\` listed in \`owner\`/\`maintainers\`"
      has_permission="true"
    else
      echo "- ❌ Your GitHub username (\`$PR_AUTHOR\`) must appear in \`owner\` or \`maintainers\` for new plugin submissions"
      echo "  Add \`\"owner\": \"$PR_AUTHOR\"\` to your plugin.json"
      failed=1
    fi
  fi

  # Version format
  if [[ $(validate_semver "$VERSION") -eq 1 ]]; then
    echo "- ✅ Version format valid (\`$VERSION\`)"
  else
    echo "- ❌ Version must be semver (got \`$VERSION\`, expected X.Y.Z)"
    failed=1
  fi

  # min_dispatcharr_version (optional)
  MIN_DA_VERSION=$(jq -r '.min_dispatcharr_version // ""' "$PLUGIN_JSON")
  if [[ -n "$MIN_DA_VERSION" ]]; then
    if [[ $(validate_dispatcharr_version "$MIN_DA_VERSION") -eq 1 ]]; then
      echo "- ✅ Minimum Dispatcharr version valid (\`$MIN_DA_VERSION\`)"
    else
      echo "- ❌ \`min_dispatcharr_version\` must be semver (got \`$MIN_DA_VERSION\`, expected X.Y.Z or vX.Y.Z)"
      failed=1
    fi
  fi

  # URL fields (optional)
  REPO_URL=$(jq -r '.repo_url // ""' "$PLUGIN_JSON")
  DISCORD_THREAD=$(jq -r '.discord_thread // ""' "$PLUGIN_JSON")
  if [[ -n "$REPO_URL" ]]; then
    if [[ "$REPO_URL" =~ ^https?:// ]]; then
      echo "- ✅ \`repo_url\` valid"
    else
      echo "- ❌ \`repo_url\` must start with \`http://\` or \`https://\` (got \`$REPO_URL\`)"
      failed=1
    fi
  fi
  if [[ -n "$DISCORD_THREAD" ]]; then
    if [[ "$DISCORD_THREAD" =~ ^https?:// ]]; then
      echo "- ✅ \`discord_thread\` valid"
    else
      echo "- ❌ \`discord_thread\` must start with \`http://\` or \`https://\` (got \`$DISCORD_THREAD\`)"
      failed=1
    fi
  fi

  # Version bump check
  if git show "origin/${BASE_REF}:${PLUGIN_JSON}" > /dev/null 2>&1; then
    OLD_VERSION=$(git show "origin/${BASE_REF}:${PLUGIN_JSON}" | jq -r '.version')
    if version_greater_than "$VERSION" "$OLD_VERSION"; then
      echo "- ✅ Version bump valid (\`$OLD_VERSION\` -> \`$VERSION\`)"
    else
      echo "- ❌ Version \`$VERSION\` must be greater than current version \`$OLD_VERSION\`"
      failed=1
    fi
  else
    echo "- ✅ New plugin (version \`$VERSION\`)"
    is_new="true"
  fi

  # Summary
  echo ""
  if [[ $failed -eq 0 ]]; then
    echo "✅ **All checks passed for \`$PLUGIN_NAME\`**"
  else
    echo "❌ **Validation failed for \`$PLUGIN_NAME\`**"
  fi

  # Metadata table row (pipe-delimited, consumed by aggregate-report.sh)
  echo "<!--META_ROW:$(jq -r '[
    .name // "",
    .version // "",
    .description // "",
    .owner // "",
    ([ .maintainers[]? ] | join(", ")),
    (.repo_url // ""),
    (.discord_thread // "")
  ] | @tsv' "$PLUGIN_JSON")-->"

} > "$OUTPUT_FILE"

# Write job outputs
if [[ $failed -eq 0 ]]; then
  echo "result=pass" >> "$GITHUB_OUTPUT"
else
  echo "result=fail" >> "$GITHUB_OUTPUT"
fi
echo "is_new=$is_new" >> "$GITHUB_OUTPUT"
echo "has_permission=$has_permission" >> "$GITHUB_OUTPUT"

exit $failed
