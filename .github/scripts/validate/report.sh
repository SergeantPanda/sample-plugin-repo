#!/bin/bash
set -e

# aggregate-report.sh
# Combines per-plugin report fragments, posts the final PR comment,
# and optionally closes an unauthorized PR.
#
# Usage: aggregate-report.sh <pr_number> <pr_author> <plugin_count> <close_pr> <fragments_dir>
#
# Arguments:
#   pr_number      - GitHub PR number
#   pr_author      - GitHub username of PR author
#   plugin_count   - Total number of plugins validated
#   close_pr       - "true" to close the PR after posting the comment
#   fragments_dir  - Directory containing per-plugin .md fragment files
#
# Environment variables required:
#   GITHUB_REPOSITORY - Full repository name (owner/repo)
#   GH_TOKEN          - GitHub token for API access

PR_NUMBER=$1
PR_AUTHOR=$2
PLUGIN_COUNT=$3
CLOSE_PR=$4
FRAGMENTS_DIR=${5:-.}

if [[ -z "$PR_NUMBER" || -z "$PR_AUTHOR" || -z "$PLUGIN_COUNT" || -z "$CLOSE_PR" ]]; then
  echo "Usage: $0 <pr_number> <pr_author> <plugin_count> <close_pr> [fragments_dir]"
  exit 1
fi

OVERALL_FAILED=0

# Parse per-plugin report files
COMBINED_BODY=""
TABLE_HEADER="| name | version | description | owner | maintainers |"
TABLE_SEP="|---|---|---|---|---|"
TABLE_ROWS=""

for fragment in "$FRAGMENTS_DIR"/*.fragment.md; do
  [[ -f "$fragment" ]] || continue

  # Check if fragment contains a failure marker
  if grep -q "❌" "$fragment"; then
    OVERALL_FAILED=1
  fi

  # Extract metadata table row from hidden comment marker
  META_ROW=$(grep '<!--META_ROW:' "$fragment" | sed 's/<!--META_ROW://;s/-->//' || true)
  if [[ -n "$META_ROW" ]]; then
    IFS=$'\t' read -r f_name f_version f_description f_owner f_maintainers <<< "$META_ROW"
    TABLE_ROWS+="| $f_name | $f_version | $f_description | $f_owner | $f_maintainers |"$'\n'
  fi

  # Strip internal marker lines from visible output
  VISIBLE=$(grep -v '<!--META_ROW:' "$fragment")
  COMBINED_BODY+="$VISIBLE"$'\n\n'
done

# Build comment
{
  echo "<!--PLUGIN_VALIDATION_COMMENT-->"
  echo ""
  echo "# Plugin Validation Results"
  echo ""
  echo "**Modified plugins:** $PLUGIN_COUNT"
  echo ""

  if [[ "$CLOSE_PR" == "true" ]]; then
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
  else
    echo "$COMBINED_BODY"

    echo "---"
    echo ""
    if [[ $OVERALL_FAILED -eq 0 ]]; then
      echo "## 🎉 All validation checks passed!"
      echo ""
      echo "This PR modifies **$PLUGIN_COUNT** plugin(s) and all checks have passed."
    else
      echo "## ❌ Validation failed"
      echo ""
      echo "Some checks failed. Please review the errors above and update your PR."
    fi

    if [[ -n "$TABLE_ROWS" ]]; then
      echo ""
      echo "---"
      echo ""
      echo "## Plugin Metadata"
      echo ""
      echo "$TABLE_HEADER"
      echo "$TABLE_SEP"
      echo "$TABLE_ROWS"
    fi
  fi
} > pr_comment.txt

# Post or update PR comment
EXISTING_COMMENT_ID=$(gh pr view $PR_NUMBER --json comments \
  --jq '.comments[] | select(.author.login=="github-actions[bot]") | select(.body | contains("<!--PLUGIN_VALIDATION_COMMENT-->")) | .id' \
  || true)

if [[ -n "$EXISTING_COMMENT_ID" ]]; then
  gh api "repos/$GITHUB_REPOSITORY/issues/comments/$EXISTING_COMMENT_ID" -X PATCH -f body="$(cat pr_comment.txt)"
else
  gh pr comment $PR_NUMBER --body "$(cat pr_comment.txt)"
fi

# Close if unauthorized
if [[ "$CLOSE_PR" == "true" ]]; then
  gh pr close $PR_NUMBER
  echo "PR #$PR_NUMBER closed: unauthorized"
  exit 0
fi

exit $OVERALL_FAILED
