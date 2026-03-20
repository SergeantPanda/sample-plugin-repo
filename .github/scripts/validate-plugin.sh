#!/bin/bash
set -e

# validate-plugin.sh
# Validates a plugin PR and generates a validation report comment
#
# Usage: validate-plugin.sh <pr_number> <pr_author> <base_ref>
#
# Arguments:
#   pr_number  - GitHub PR number
#   pr_author  - GitHub username of PR author
#   base_ref   - Base branch reference (e.g., main)
#
# Environment variables required:
#   GITHUB_REPOSITORY - Full repository name (owner/repo)
#   GH_TOKEN          - GitHub token for API access

PR_NUMBER=$1
PR_AUTHOR=$2
BASE_REF=$3

if [[ -z "$PR_NUMBER" || -z "$PR_AUTHOR" || -z "$BASE_REF" ]]; then
  echo "Usage: $0 <pr_number> <pr_author> <base_ref>"
  exit 1
fi

REPO_OWNER=$(echo "$GITHUB_REPOSITORY" | cut -d'/' -f1)
REPO_NAME=$(echo "$GITHUB_REPOSITORY" | cut -d'/' -f2)

# Check if PR author is a repository maintainer
check_repo_maintainer() {
  local author=$1
  PERMISSION=$(gh api repos/$REPO_OWNER/$REPO_NAME/collaborators/$author/permission --jq .permission 2>/dev/null || echo "none")
  if [[ "$PERMISSION" == "admin" || "$PERMISSION" == "write" ]]; then
    echo "1"
  else
    echo "0"
  fi
}

# Validate dispatcharr version (semver with optional v prefix)
validate_dispatcharr_version() {
  local version=$1
  if [[ "$version" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "1"
  else
    echo "0"
  fi
}

# Validate semantic version format
validate_semver() {
  local version=$1
  if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "1"
  else
    echo "0"
  fi
}

# Compare two semantic versions
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

# Track whether the PR author has permission for at least one plugin
plugins_with_any_permission=0
# Track whether any modified plugin is new (not yet on base branch)
has_new_plugin=0

# Validate a single plugin
validate_plugin() {
  local plugin_name=$1
  local plugin_dir="plugins/$plugin_name"
  local plugin_json="$plugin_dir/plugin.json"
  local readme="$plugin_dir/README.md"
  local failed=0
  
  echo ""
  echo "### Plugin: \`$plugin_name\`"
  echo ""
  
  # Validate folder name format (lowercase-kebab-case)
  if [[ ! "$plugin_name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    echo "- ❌ Plugin folder name must be lowercase-kebab-case (lowercase letters, numbers, and hyphens only)"
    echo "  Current: \`$plugin_name\`"
    echo "  Example: \`my-plugin-name\`"
    failed=1
  else
    echo "- ✅ Folder name format valid"
  fi
  
  # Check for plugin.json
  if [[ ! -f "$plugin_json" ]]; then
    echo "- ❌ plugin.json missing"
    return 1
  fi
  echo "- ✅ plugin.json exists"
  
  # Check for README.md (optional)
  if [[ ! -f "$readme" ]]; then
    echo "- ℹ️ README.md not provided (optional)"
  else
    echo "- ✅ README.md exists"
  fi
  
  # Validate JSON syntax
  if ! jq empty "$plugin_json" 2>/dev/null; then
    echo "- ❌ Invalid JSON"
    return 1
  fi
  echo "- ✅ JSON valid"
  
  # Validate required fields
  local required_keys=("name" "version" "description")
  for key in "${required_keys[@]}"; do
    if ! jq -e ".\"$key\"" "$plugin_json" >/dev/null 2>&1; then
      echo "- ❌ Required property \`$key\` missing"
      failed=1
    fi
  done
  
  # Extract metadata
  OWNER=$(jq -r '.owner // ""' "$plugin_json")
  MAINTAINERS=$(jq -r '[.maintainers[]?] | join(" ")' "$plugin_json")
  VERSION=$(jq -r '.version' "$plugin_json")
  
  # Require at least one of owner or maintainers to be present
  if [[ -z "$OWNER" ]] && [[ -z "$MAINTAINERS" ]]; then
    echo "- ❌ At least one of \`owner\` or \`maintainers\` must be set"
    echo "  **Action required:** Add your GitHub username to \`owner\`, \`maintainers\`, or both."
    echo "  Example: \`\"owner\": \"your-github-username\"\`"
    echo "  Example: \`\"maintainers\": [\"your-github-username\"]\`"
    echo "  > Note: These fields are not part of the Dispatcharr plugin spec, but are required"
    echo "  > by this repository to manage contribution permissions."
    failed=1
  fi
  
  # Check ownership
  IS_REPO_MAINTAINER=$(check_repo_maintainer "$PR_AUTHOR")
  if [[ "$PR_AUTHOR" != "$OWNER" ]] && [[ ! " $MAINTAINERS " =~ " $PR_AUTHOR " ]] && [[ "$IS_REPO_MAINTAINER" -ne 1 ]]; then
    echo "- ❌ **Permission denied**: Your GitHub username (\`$PR_AUTHOR\`) must appear in \`owner\` or \`maintainers\`"
    failed=1
  else
    echo "- ✅ Permission check passed"
    plugins_with_any_permission=1
  fi
  
  # Validate version format
  if [[ $(validate_semver "$VERSION") -eq 1 ]]; then
    echo "- ✅ Version format valid (\`$VERSION\`)"
  else
    echo "- ❌ Version must be semantic (got \`$VERSION\`, expected X.Y.Z)"
    failed=1
  fi
  
  # Validate optional min_dispatcharr_version
  MIN_DA_VERSION=$(jq -r '.min_dispatcharr_version // ""' "$plugin_json")
  if [[ -n "$MIN_DA_VERSION" ]]; then
    if [[ $(validate_dispatcharr_version "$MIN_DA_VERSION") -eq 1 ]]; then
      echo "- ✅ Minimum Dispatcharr version valid (\`$MIN_DA_VERSION\`)"
    else
      echo "- ❌ \`min_dispatcharr_version\` must be semver format (got \`$MIN_DA_VERSION\`, expected X.Y.Z or vX.Y.Z)"
      failed=1
    fi
  fi

  # Check version bump for existing plugins
  if git show origin/$BASE_REF:"$plugin_json" > /dev/null 2>&1; then
    OLD_VERSION=$(git show origin/$BASE_REF:"$plugin_json" | jq -r '.version')
    if version_greater_than "$VERSION" "$OLD_VERSION"; then
      echo "- ✅ Version bump valid (\`$OLD_VERSION\` → \`$VERSION\`)"
    else
      echo "- ❌ Version \`$VERSION\` must be greater than current version \`$OLD_VERSION\`"
      failed=1
    fi
  else
    echo "- ✅ New plugin (version \`$VERSION\`)"
    has_new_plugin=1
  fi
  
  # Summary for this plugin
  if [[ $failed -eq 0 ]]; then
    echo ""
    echo "✅ **All checks passed for \`$plugin_name\`**"
  else
    echo ""
    echo "❌ **Validation failed for \`$plugin_name\`**"
  fi
  
  # Export table data for later rendering (only repo-relevant fields)
  local display_keys=("name" "version" "description" "owner" "maintainers")
  PLUGIN_TABLE_HEADER="|"
  PLUGIN_TABLE_ROW="|"
  for key in "${display_keys[@]}"; do
    PLUGIN_TABLE_HEADER+=" $key |"
    value=$(jq -r ".\"$key\" // \"\" | if type==\"array\" then join(\", \") else . end" "$plugin_json")
    PLUGIN_TABLE_ROW+=" $value |"
  done
  
  return $failed
}

# Main validation logic
main() {
  echo "<!--PLUGIN_VALIDATION_COMMENT-->"
  echo ""
  echo "# Plugin Validation Results"
  echo ""
  
  local overall_failed=0
  
  # Compute merge base
  MERGE_BASE=$(git merge-base origin/$BASE_REF HEAD)
  
  # Block PRs that modify .github/ files unless author is a repo maintainer or listed in CODEOWNERS
  GITHUB_CHANGES=$(git diff --name-only $MERGE_BASE HEAD | grep '^\.github/' || true)
  if [[ -n "$GITHUB_CHANGES" ]]; then
    IS_REPO_MAINTAINER=$(check_repo_maintainer "$PR_AUTHOR")
    
    # Parse CODEOWNERS: collect all @username entries from lines covering .github/
    CODEOWNERS_FILE=".github/CODEOWNERS"
    IS_CODEOWNER=0
    if [[ -f "$CODEOWNERS_FILE" ]]; then
      while IFS= read -r line; do
        # Skip comments and blank lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        pattern=$(echo "$line" | awk '{print $1}')
        # Check if this rule covers .github/ paths
        if [[ ".github/CODEOWNERS" == $pattern* ]] || [[ ".github/" == $pattern* ]] || [[ "$pattern" == "*" ]]; then
          owners=$(echo "$line" | grep -oE '@[A-Za-z0-9_-]+' | sed 's/@//')
          for owner in $owners; do
            if [[ "$owner" == "$PR_AUTHOR" ]]; then
              IS_CODEOWNER=1
              break 2
            fi
          done
        fi
      done < "$CODEOWNERS_FILE"
    fi
    
    if [[ "$IS_REPO_MAINTAINER" -ne 1 ]] && [[ "$IS_CODEOWNER" -ne 1 ]]; then
      echo "## Workflow file modification denied"
      echo ""
      echo "This PR modifies files under \`.github/\`, which is restricted to repository maintainers and users listed in CODEOWNERS."
      echo ""
      echo "**Modified files:**"
      echo "\`\`\`"
      echo "$GITHUB_CHANGES"
      echo "\`\`\`"
      exit 1
    fi
  fi
  
  # Detect modified plugins
  PLUGIN_DIRS=$(git diff --name-only $MERGE_BASE HEAD \
    | grep '^plugins/' | cut -d '/' -f2 | sort -u)
  
  PLUGIN_COUNT=$(echo "$PLUGIN_DIRS" | wc -w)
  
  if [[ -z "$PLUGIN_DIRS" ]]; then
    echo "❌ **Error:** No plugin changes detected"
    exit 1
  fi
  
  echo "**Modified plugins:** $PLUGIN_COUNT"
  echo ""
  
  # Validate each plugin
  local all_tables=""
  for plugin in $PLUGIN_DIRS; do
    if validate_plugin "$plugin"; then
      true  # Success
    else
      overall_failed=1
    fi
    
    # Collect table for this plugin
    if [[ -n "$PLUGIN_TABLE_HEADER" ]]; then
      if [[ -z "$all_tables" ]]; then
        all_tables="$PLUGIN_TABLE_HEADER"$'\n'
        # Generate separator
        separator="|"
        for col in $(echo "$PLUGIN_TABLE_HEADER" | tr '|' '\n' | tail -n +2 | head -n -1); do
          separator+="---|"
        done
        all_tables+="$separator"$'\n'
      fi
      all_tables+="$PLUGIN_TABLE_ROW"$'\n'
    fi
  done

  # Auto-close if the author has no permission for any modified plugin, and all modified plugins already exist
  if [[ $plugins_with_any_permission -eq 0 ]] && [[ $has_new_plugin -eq 0 ]]; then
    echo ""
    echo "---"
    echo ""
    echo "## PR Closed: Unauthorized"
    echo ""
    echo "Your GitHub username (\`$PR_AUTHOR\`) does not appear in \`owner\` or \`maintainers\` for any of the plugin(s) in this PR. This PR has been automatically closed."
    echo ""
    echo "If you are submitting a new plugin, add your GitHub username to the \`owner\` field in your \`plugin.json\`."
    if [[ -n "${DISCORD_URL:-}" ]]; then
      echo ""
      echo "For help or to discuss plugins:"
      echo "- [Dispatcharr Discord]($DISCORD_URL)"
    fi
    exit 2
  fi

  # Print overall status
  echo ""
  echo "---"
  echo ""
  if [[ "$overall_failed" -eq 0 ]]; then
    echo "## 🎉 All validation checks passed!"
    echo ""
    echo "This PR modifies **$PLUGIN_COUNT** plugin(s) and all checks have passed."
  else
    echo "## ❌ Validation failed"
    echo ""
    echo "Some checks failed. Please review the errors above and update your PR."
  fi
  
  # Print plugin information table
  if [[ -n "$all_tables" ]]; then
    echo ""
    echo "---"
    echo ""
    echo ""
    echo "## Plugin Metadata"
    echo ""
    echo "$all_tables"
  fi
  
  exit $overall_failed
}

# Run main
main
