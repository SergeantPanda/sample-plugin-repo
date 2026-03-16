#!/bin/bash
set -e

# publish-plugins.sh
# Builds plugin ZIPs, generates manifest, and publishes to releases branch
#
# Usage: publish-plugins.sh <source_branch>
#
# Arguments:
#   source_branch - Source branch to read plugins from (e.g., main)
#
# Environment variables required:
#   GITHUB_REPOSITORY - Full repository name (owner/repo)
#   GITHUB_TOKEN      - GitHub token with write access

SOURCE_BRANCH=$1

if [[ -z "$SOURCE_BRANCH" ]]; then
  echo "Usage: $0 <source_branch>"
  exit 1
fi

RELEASES_BRANCH="releases"
MAX_VERSIONED_ZIPS=10

echo "🚀 Publishing plugins from $SOURCE_BRANCH to $RELEASES_BRANCH"

# Create temporary working directory
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

echo "📦 Cloning repository..."
git clone --no-checkout "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" "$TMPDIR/repo"
cd "$TMPDIR/repo"

# Configure git
git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"

# Checkout or create releases branch
echo "🔀 Setting up $RELEASES_BRANCH branch..."
if git ls-remote --exit-code --heads origin $RELEASES_BRANCH >/dev/null 2>&1; then
  git checkout $RELEASES_BRANCH
  git pull origin $RELEASES_BRANCH || true
else
  git checkout --orphan $RELEASES_BRANCH
  git rm -rf . 2>/dev/null || true
  git commit --allow-empty -m "Initialize $RELEASES_BRANCH branch"
fi

# Clean old artifacts (keep plugin folders for version history)
rm -f manifest.json README.md

# Fetch source branch and copy plugins
echo "📥 Fetching plugins from $SOURCE_BRANCH..."
git fetch origin $SOURCE_BRANCH
git checkout origin/$SOURCE_BRANCH -- plugins

# Create releases directory structure
mkdir -p releases

# Build plugin ZIPs
echo "🗜️  Building plugin ZIPs..."
changed_plugins=()
for plugin_dir in plugins/*/; do
  plugin_name=$(basename "$plugin_dir")
  version=$(jq -r '.version' "$plugin_dir/plugin.json")
  
  # Create plugin subfolder in releases
  mkdir -p "releases/$plugin_name"
  mkdir -p "metadata/$plugin_name"
  
  # Check if this version already exists
  zip_path="releases/$plugin_name/${plugin_name}-${version}.zip"
  metadata_path="metadata/$plugin_name/${plugin_name}-${version}.json"
  
  if [[ -f "$zip_path" ]] && [[ -f "$metadata_path" ]]; then
    echo "  - $plugin_name v$version (already exists, skipping)"
    continue
  fi
  
  echo "  - $plugin_name v$version (building)"
  
  # Track this as a changed plugin
  changed_plugins+=("$plugin_name@$version")
  
  # Get commit SHA for this plugin from source branch
  commit_sha=$(git log -1 --format=%H origin/$SOURCE_BRANCH -- "$plugin_dir")
  commit_sha_short=$(git log -1 --format=%h origin/$SOURCE_BRANCH -- "$plugin_dir")
  build_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  last_updated=$(git log -1 --format=%cI origin/$SOURCE_BRANCH -- "$plugin_dir" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")
  
  # Create versioned ZIP
  zip -r "$zip_path" "$plugin_dir" -q
  
  # Calculate checksums for the ZIP
  checksum_md5=$(md5sum "$zip_path" | awk '{print $1}')
  checksum_sha256=$(shasum -a 256 "$zip_path" | awk '{print $1}')
  
  # Create metadata file for this version
  jq -n \
    --arg commit_sha "$commit_sha" \
    --arg commit_sha_short "$commit_sha_short" \
    --arg version "$version" \
    --arg build_timestamp "$build_timestamp" \
    --arg last_updated "$last_updated" \
    --arg checksum_md5 "$checksum_md5" \
    --arg checksum_sha256 "$checksum_sha256" \
    '{
      version: $version,
      commit_sha: $commit_sha,
      commit_sha_short: $commit_sha_short,
      build_timestamp: $build_timestamp,
      last_updated: $last_updated,
      checksum_md5: $checksum_md5,
      checksum_sha256: $checksum_sha256
    }' > "$metadata_path"
  
  # Update latest ZIP to point to this new version
  cp "$zip_path" "releases/$plugin_name/${plugin_name}-latest.zip"
done

# Generate per-plugin READMEs
echo "📝 Generating per-plugin READMEs..."
for plugin_dir in plugins/*/; do
  [[ ! -d "$plugin_dir" ]] && continue
  plugin_name=$(basename "$plugin_dir")
  plugin_file="$plugin_dir/plugin.json"
  
  [[ ! -f "$plugin_file" ]] && continue
  
  name=$(jq -r '.name' "$plugin_file")
  description=$(jq -r '.description' "$plugin_file")
  owner=$(jq -r '.owner' "$plugin_file")
  has_readme=false
  [[ -f "$plugin_dir/README.md" ]] && has_readme=true
  
  {
    echo "← [Back to All Plugins](../../)"
    echo ""
    if [[ "$has_readme" == "true" ]]; then
      echo "# [$name](https://github.com/${GITHUB_REPOSITORY}/blob/$SOURCE_BRANCH/plugins/${plugin_name}/README.md)"
    else
      echo "# $name"
    fi
    echo ""
    echo "$description"
    echo ""
    echo "**Owner:** $owner"
    echo ""
    echo "## 📥 Downloads"
    echo ""
    echo "### Latest Release"
    echo ""
    
    # Get latest version info
    latest_zip="releases/$plugin_name/${plugin_name}-latest.zip"
    if [[ -f "$latest_zip" ]]; then
      # Find the actual latest version by sorting
      latest_versioned=$(ls -1 "releases/$plugin_name/${plugin_name}"-*.zip 2>/dev/null | grep -v latest | sort -t- -k2 -V -r | head -1)
      if [[ -n "$latest_versioned" ]]; then
        zip_basename=$(basename "$latest_versioned")
        latest_version=$(echo "$zip_basename" | sed "s/${plugin_name}-\(.*\)\.zip/\1/")
        metadata_file="metadata/$plugin_name/${plugin_name}-${latest_version}.json"
        
        echo "**Version:** \`$latest_version\`"
        echo ""
        
        if [[ -f "$metadata_file" ]]; then
          commit_sha=$(jq -r '.commit_sha' "$metadata_file")
          commit_sha_short=$(jq -r '.commit_sha_short' "$metadata_file")
          build_timestamp=$(jq -r '.build_timestamp' "$metadata_file")
          checksum_md5=$(jq -r '.checksum_md5' "$metadata_file")
          checksum_sha256=$(jq -r '.checksum_sha256' "$metadata_file")
          
          echo "- **Download:** [\`${plugin_name}-latest.zip\`](${plugin_name}-latest.zip)"
          echo "- **Built:** $build_timestamp"
          echo "- **Source Commit:** [\`$commit_sha_short\`](https://github.com/${GITHUB_REPOSITORY}/commit/${commit_sha})"
          echo ""
          echo "**Checksums:**"
          echo "\`\`\`"
          echo "MD5:    $checksum_md5"
          echo "SHA256: $checksum_sha256"
          echo "\`\`\`"
        else
          echo "- **Download:** [\`${plugin_name}-latest.zip\`](${plugin_name}-latest.zip)"
        fi
      fi
    fi
    
    echo ""
    echo "### All Versions"
    echo ""
    echo "| Version | Download | Built | Commit | MD5 Checksum |"
    echo "|---------|----------|-------|--------|--------------|"
    
    # List all versions sorted by semantic version (newest first)
    for zipfile in $(ls -1 "releases/$plugin_name/${plugin_name}"-*.zip 2>/dev/null | grep -v latest | sort -t- -k2 -V -r); do
      zip_basename=$(basename "$zipfile")
      version=$(echo "$zip_basename" | sed "s/${plugin_name}-\(.*\)\.zip/\1/")
      metadata_file="metadata/$plugin_name/${plugin_name}-${version}.json"
      
      if [[ -f "$metadata_file" ]]; then
        commit_sha_short=$(jq -r '.commit_sha_short' "$metadata_file")
        commit_sha=$(jq -r '.commit_sha' "$metadata_file")
        build_timestamp=$(jq -r '.build_timestamp' "$metadata_file")
        checksum_md5=$(jq -r '.checksum_md5' "$metadata_file")
        
        # Format timestamp to date only
        build_date=$(echo "$build_timestamp" | cut -d'T' -f1)
        
        echo "| \`$version\` | [Download]($zip_basename) | $build_date | [\`$commit_sha_short\`](https://github.com/${GITHUB_REPOSITORY}/commit/${commit_sha}) | \`$checksum_md5\` |"
      else
        echo "| \`$version\` | [Download]($zip_basename) | - | - | - |"
      fi
    done
    
    echo ""
    echo "---"
    echo ""
    echo "**📂 Source:** [Browse Plugin](https://github.com/${GITHUB_REPOSITORY}/tree/$SOURCE_BRANCH/plugins/${plugin_name})"
    echo ""
    echo "**📋 Metadata:** [View full metadata](../../metadata/${plugin_name}/manifest.json)"
  } > "releases/$plugin_name/README.md"
  
  echo "  Generated README for $plugin_name"
done

# Build list of current plugin names
current_plugins=()
for plugin_dir in plugins/*/; do
  [[ ! -d "$plugin_dir" ]] && continue
  plugin_name=$(basename "$plugin_dir")
  current_plugins+=("$plugin_name")
done

# Clean up deleted plugins
echo "🧹 Checking for deleted plugins..."
if [[ -d "releases" ]]; then
  for release_dir in releases/*/; do
    [[ ! -d "$release_dir" ]] && continue
    plugin_name=$(basename "$release_dir")
    
    # Check if this plugin still exists in source
    if [[ ! -d "plugins/$plugin_name" ]]; then
      echo "  Removing deleted plugin: $plugin_name"
      rm -rf "$release_dir"
      rm -rf "metadata/$plugin_name"
    fi
  done
fi

# Clean up old versioned ZIPs (keep only most recent N)
echo "🧹 Cleaning up old versions..."
for plugin_dir in plugins/*/; do
  [[ ! -d "$plugin_dir" ]] && continue
  plugin_name=$(basename "$plugin_dir")
  zip_dir="releases/$plugin_name"
  metadata_dir="metadata/$plugin_name"
  
  # List all versioned zips (excluding latest), keep newest N
  OLD_ZIPS=$(ls -1t "$zip_dir"/${plugin_name}-*.zip 2>/dev/null \
    | grep -v "${plugin_name}-latest.zip" \
    | awk "NR>$MAX_VERSIONED_ZIPS")
  
  for old_zip in $OLD_ZIPS; do
    # Extract version from filename
    zip_basename=$(basename "$old_zip")
    version=$(echo "$zip_basename" | sed "s/${plugin_name}-\(.*\)\.zip/\1/")
    
    # Remove ZIP and corresponding metadata
    rm -f "$old_zip"
    rm -f "$metadata_dir/${plugin_name}-${version}.json"
    echo "  Removed $plugin_name v$version"
  done
  
  # Clean up orphaned ZIPs without metadata (except latest)
  if [[ -d "$zip_dir" ]]; then
    for zipfile in "$zip_dir"/${plugin_name}-*.zip; do
      [[ ! -f "$zipfile" ]] && continue
      zip_basename=$(basename "$zipfile")
      [[ "$zip_basename" == "${plugin_name}-latest.zip" ]] && continue
      
      version=$(echo "$zip_basename" | sed "s/${plugin_name}-\(.*\)\.zip/\1/")
      if [[ ! -f "$metadata_dir/${plugin_name}-${version}.json" ]]; then
        rm -f "$zipfile"
        echo "  Removed orphaned ZIP: $zip_basename (no metadata)"
      fi
    done
  fi
  
  # Clean up orphaned metadata without ZIPs
  if [[ -d "$metadata_dir" ]]; then
    for metafile in "$metadata_dir"/${plugin_name}-*.json; do
      [[ ! -f "$metafile" ]] && continue
      meta_basename=$(basename "$metafile")
      version=$(echo "$meta_basename" | sed "s/${plugin_name}-\(.*\)\.json/\1/")
      
      if [[ ! -f "$zip_dir/${plugin_name}-${version}.zip" ]]; then
        rm -f "$metafile"
        echo "  Removed orphaned metadata: $meta_basename (no ZIP)"
      fi
    done
  fi
done

# Generate per-plugin manifests and collect entries for main manifest
echo "📋 Generating plugin manifests..."

plugin_entries=()

for plugin_dir in plugins/*/; do
  plugin_file="$plugin_dir/plugin.json"
  if [[ -f "$plugin_file" ]]; then
    plugin_name=$(basename "$plugin_dir")
    
    echo "  - $plugin_name"
    
    # Build URLs for latest and versioned zips
    latest_url="https://github.com/${GITHUB_REPOSITORY}/raw/$RELEASES_BRANCH/releases/${plugin_name}/${plugin_name}-latest.zip"
    
    # Get list of versioned zip objects with version, URL, and metadata
    # Sort by semantic version (descending) to ensure latest is first
    versioned_zips="[]"
    latest_metadata="{}"
    for zipfile in $(ls -1 "releases/$plugin_name/${plugin_name}"-*.zip 2>/dev/null | grep -v latest | sort -t- -k2 -V -r); do
      zip_basename=$(basename "$zipfile")
      # Extract version from filename (e.g., plugin-name-1.0.0.zip -> 1.0.0)
      zip_version=$(echo "$zip_basename" | sed "s/${plugin_name}-\(.*\)\.zip/\1/")
      zip_url="https://github.com/${GITHUB_REPOSITORY}/raw/$RELEASES_BRANCH/releases/${plugin_name}/${zip_basename}"
      
      # Read metadata file if it exists
      metadata_file="metadata/$plugin_name/${plugin_name}-${zip_version}.json"
      if [[ -f "$metadata_file" ]]; then
        metadata=$(cat "$metadata_file")
        versioned_zips=$(jq --arg url "$zip_url" --argjson metadata "$metadata" '. + [($metadata + {url: $url})]' <<< "$versioned_zips")
        
        # Save the first (latest) metadata for top-level fields
        if [[ "$latest_metadata" == "{}" ]]; then
          latest_metadata="$metadata"
        fi
      else
        # Fallback for old versions without metadata
        versioned_zips=$(jq --arg version "$zip_version" --arg url "$zip_url" '. + [{version: $version, url: $url}]' <<< "$versioned_zips")
      fi
    done
    
    # Build complete plugin manifest entry
    plugin_entry=$(jq \
      --arg latest_url "$latest_url" \
      --argjson versioned_zips "$versioned_zips" \
      --argjson latest_metadata "$latest_metadata" \
      '. + {
        latest_url: $latest_url, 
        versions: $versioned_zips
      } + (
        if ($latest_metadata | length > 0) then {
          last_updated: $latest_metadata.last_updated,
          latest: ($latest_metadata + {
            latest_url: $latest_url,
            url: $versioned_zips[0].url
          }),
          latest_commit_sha: $latest_metadata.commit_sha,
          latest_commit_sha_short: $latest_metadata.commit_sha_short,
          latest_build_timestamp: $latest_metadata.build_timestamp,
          latest_checksum_md5: $latest_metadata.checksum_md5,
          latest_checksum_sha256: $latest_metadata.checksum_sha256
        } else {} end
      )' \
      "$plugin_file")
    
    # Save per-plugin manifest
    echo "$plugin_entry" | jq '.' > "metadata/$plugin_name/manifest.json"
    
    # Store for main manifest
    plugin_entries+=("$plugin_entry")
  fi
done

# Generate main manifest.json from collected entries
echo "📋 Generating main manifest.json..."
{
  echo '{'
  echo '  "plugins": ['
  
  first=true
  for entry in "${plugin_entries[@]}"; do
    if [[ "$first" != true ]]; then
      echo ","
    fi
    first=false
    
    echo "$entry" | sed 's/^/    /'
  done
  
  echo ""
  echo '  ]'
  echo '}'
} | jq '.' > manifest.json

# Generate README.md
echo "📄 Generating README.md..."
{
  echo "# Plugin Releases"
  echo ""
  echo "This branch contains all published plugin releases with automated builds and metadata."
  echo ""
  echo "## 📥 Quick Access"
  echo ""
  echo "- **Manifest**: [\`manifest.json\`](./manifest.json) - Complete plugin registry with metadata"
  echo "- **Releases**: [\`releases/\`](./releases/) - All plugin ZIP files"
  echo "- **Metadata**: [\`metadata/\`](./metadata/) - Version metadata with checksums"
  echo ""
  echo "## 📦 Available Plugins"
  echo ""
  echo "| Plugin | Version | Owner | Description |"
  echo "|--------|---------|-------|-------------|"
  
  # First pass: generate table of contents - active plugins first, alphabetically
  for plugin_dir in $(ls -d plugins/*/ | sort); do
    plugin_file="$plugin_dir/plugin.json"
    if [[ -f "$plugin_file" ]]; then
      deprecated=$(jq -r '.deprecated // false' "$plugin_file")
      unlisted=$(jq -r '.unlisted // false' "$plugin_file")
      [[ "$deprecated" == "true" ]] && continue
      [[ "$unlisted" == "true" ]] && continue
      
      plugin_name=$(basename "$plugin_dir")
      name=$(jq -r '.name' "$plugin_file")
      version=$(jq -r '.version' "$plugin_file")
      owner=$(jq -r '.owner' "$plugin_file")
      description=$(jq -r '.description' "$plugin_file")
      
      # Create anchor-safe name (lowercase, spaces to hyphens, remove special chars)
      anchor=$(echo "$name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/--*/-/g')
      
      echo "| [\`$name\`](#$anchor) | \`$version\` | $owner | $description |"
    fi
  done
  
  # Then deprecated plugins, alphabetically
  for plugin_dir in $(ls -d plugins/*/ | sort); do
    plugin_file="$plugin_dir/plugin.json"
    if [[ -f "$plugin_file" ]]; then
      deprecated=$(jq -r '.deprecated // false' "$plugin_file")
      unlisted=$(jq -r '.unlisted // false' "$plugin_file")
      [[ "$deprecated" != "true" ]] && continue
      [[ "$unlisted" == "true" ]] && continue
      
      plugin_name=$(basename "$plugin_dir")
      name=$(jq -r '.name' "$plugin_file")
      version=$(jq -r '.version' "$plugin_file")
      owner=$(jq -r '.owner' "$plugin_file")
      description=$(jq -r '.description' "$plugin_file")
      
      # Create anchor-safe name (lowercase, spaces to hyphens, remove special chars)
      anchor=$(echo "$name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/--*/-/g')
      
      echo "| [\`$name\`](#$anchor) ⚠️ | \`$version\` | $owner | ~~$description~~ |"
    fi
  done
  
  echo ""
  echo "---"
  echo ""
  
  # Function to render a plugin block
  render_plugin() {
    local is_deprecated=$1
    local plugin_name=$2
    local name=$3
    local version=$4
    local owner=$5
    local description=$6
    local maintainers=$7
    local last_updated=$8
    local commit_sha=$9
    local commit_sha_short=${10}
    local checksum_md5=${11}
    local checksum_sha256=${12}
    local version_count=${13}
    
    # Build URLs
    local zip_url="https://github.com/${GITHUB_REPOSITORY}/raw/$RELEASES_BRANCH/releases/${plugin_name}/${plugin_name}-latest.zip"
    local source_url="https://github.com/${GITHUB_REPOSITORY}/tree/$SOURCE_BRANCH/plugins/${plugin_name}"
    local readme_url="https://github.com/${GITHUB_REPOSITORY}/blob/$SOURCE_BRANCH/plugins/${plugin_name}/README.md"
    local commit_url="https://github.com/${GITHUB_REPOSITORY}/commit/${commit_sha}"
    local releases_dir="./releases/${plugin_name}"
    local has_source_readme=false
    [[ -f "plugins/$plugin_name/README.md" ]] && has_source_readme=true
    
    # Header
    if [[ "$is_deprecated" == "true" ]]; then
      if [[ "$has_source_readme" == "true" ]]; then
        echo "### ⚠️ [$name]($readme_url)"
      else
        echo "### ⚠️ $name"
      fi
      echo ""
    else
      if [[ "$has_source_readme" == "true" ]]; then
        echo "### [$name]($readme_url)"
      else
        echo "### $name"
      fi
      echo ""
    fi
    
    # Metadata
    echo "**Version:** \`$version\` | **Owner:** $owner | **Last Updated:** $last_updated"
    echo ""
    echo "$description"
    echo ""
    
    # Downloads and checksums
    echo "**Downloads:**"
    echo "- [Latest Release (\`$version\`)]($zip_url)"
    echo "- [All Versions ($version_count available)]($releases_dir)"
    echo ""
    # echo "**🔒 Checksums:**"
    # echo "\`\`\`"
    # echo "MD5:    $checksum_md5"
    # echo "SHA256: $checksum_sha256"
    # echo "\`\`\`"
    echo ""
    
    # Footer with conditional maintainers and source links
    local footer=""
    if [[ -n "$maintainers" ]]; then
      footer="**👥 Maintainers:** $maintainers | "
    fi
    footer+="**Source:** [Browse](${source_url})"
    if [[ "$has_source_readme" == "true" ]]; then
      footer+=" | [README]($readme_url)"
    fi
    footer+=" | **Last Change:** [\`$commit_sha_short\`]($commit_url)"
    echo "$footer"
    echo ""
    echo "---"
    echo ""
  }
  
  # Second pass: generate detailed plugin sections - active plugins first, alphabetically
  for plugin_dir in $(ls -d plugins/*/ | sort); do
    plugin_file="$plugin_dir/plugin.json"
    if [[ -f "$plugin_file" ]]; then
      deprecated=$(jq -r '.deprecated // false' "$plugin_file")
      unlisted=$(jq -r '.unlisted // false' "$plugin_file")
      [[ "$deprecated" == "true" ]] && continue
      [[ "$unlisted" == "true" ]] && continue
      
      plugin_name=$(basename "$plugin_dir")
      name=$(jq -r '.name' "$plugin_file")
      version=$(jq -r '.version' "$plugin_file")
      owner=$(jq -r '.owner' "$plugin_file")
      description=$(jq -r '.description' "$plugin_file")
      maintainers=$(jq -r '[.maintainers[]?] | join(", ")' "$plugin_file")
      last_updated=$(git log -1 --format=%cI origin/$SOURCE_BRANCH -- "$plugin_dir" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")
      commit_sha=$(git log -1 --format=%H origin/$SOURCE_BRANCH -- "$plugin_dir" 2>/dev/null || echo "unknown")
      commit_sha_short=$(git log -1 --format=%h origin/$SOURCE_BRANCH -- "$plugin_dir" 2>/dev/null || echo "unknown")
      
      # Get metadata if available
      metadata_file="metadata/$plugin_name/${plugin_name}-${version}.json"
      if [[ -f "$metadata_file" ]]; then
        checksum_md5=$(jq -r '.checksum_md5' "$metadata_file")
        checksum_sha256=$(jq -r '.checksum_sha256' "$metadata_file")
      else
        checksum_md5="N/A"
        checksum_sha256="N/A"
      fi
      
      # Count available versions
      version_count=$(ls -1 "releases/$plugin_name/${plugin_name}"-*.zip 2>/dev/null | grep -v latest | wc -l | tr -d ' ')
      
      render_plugin "false" "$plugin_name" "$name" "$version" "$owner" "$description" "$maintainers" \
        "$last_updated" "$commit_sha" "$commit_sha_short" "$checksum_md5" "$checksum_sha256" "$version_count"
    fi
  done
  
  # Then deprecated plugins (only show section if there are deprecated plugins)
  has_deprecated=false
  for plugin_dir in $(ls -d plugins/*/ | sort); do
    plugin_file="$plugin_dir/plugin.json"
    if [[ -f "$plugin_file" ]]; then
      deprecated=$(jq -r '.deprecated // false' "$plugin_file")
      if [[ "$deprecated" == "true" ]]; then
        has_deprecated=true
        break
      fi
    fi
  done
  
  if [[ "$has_deprecated" == "true" ]]; then
    echo ""
    echo "## ⚠️ Deprecated Plugins"
    echo ""
    echo "These plugins are deprecated and may be removed in the future without notice. They may not work in current or future versions of the application. Use at your own risk."
    echo ""
    
    for plugin_dir in $(ls -d plugins/*/ | sort); do
      plugin_file="$plugin_dir/plugin.json"
      if [[ -f "$plugin_file" ]]; then
        deprecated=$(jq -r '.deprecated // false' "$plugin_file")
        unlisted=$(jq -r '.unlisted // false' "$plugin_file")
        [[ "$deprecated" != "true" ]] && continue
        [[ "$unlisted" == "true" ]] && continue
        
        plugin_name=$(basename "$plugin_dir")
        name=$(jq -r '.name' "$plugin_file")
        version=$(jq -r '.version' "$plugin_file")
        owner=$(jq -r '.owner' "$plugin_file")
        description=$(jq -r '.description' "$plugin_file")
        maintainers=$(jq -r '[.maintainers[]?] | join(", ")' "$plugin_file")
        last_updated=$(git log -1 --format=%cI origin/$SOURCE_BRANCH -- "$plugin_dir" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")
        commit_sha=$(git log -1 --format=%H origin/$SOURCE_BRANCH -- "$plugin_dir" 2>/dev/null || echo "unknown")
        commit_sha_short=$(git log -1 --format=%h origin/$SOURCE_BRANCH -- "$plugin_dir" 2>/dev/null || echo "unknown")
        
        # Get metadata if available
        metadata_file="metadata/$plugin_name/${plugin_name}-${version}.json"
        if [[ -f "$metadata_file" ]]; then
          checksum_md5=$(jq -r '.checksum_md5' "$metadata_file")
          checksum_sha256=$(jq -r '.checksum_sha256' "$metadata_file")
        else
          checksum_md5="N/A"
          checksum_sha256="N/A"
        fi
        
        # Count available versions
        version_count=$(ls -1 "releases/$plugin_name/${plugin_name}"-*.zip 2>/dev/null | grep -v latest | wc -l | tr -d ' ')
        
        render_plugin "true" "$plugin_name" "$name" "$version" "$owner" "$description" "$maintainers" \
          "$last_updated" "$commit_sha" "$commit_sha_short" "$checksum_md5" "$checksum_sha256" "$version_count"
      fi
    done
  fi
  
  echo "## 🔍 Using the Manifest"
  echo ""
  echo "Programmatically access plugin information:"
  echo ""
  echo "\`\`\`bash"
  echo "curl https://raw.githubusercontent.com/${GITHUB_REPOSITORY}/$RELEASES_BRANCH/manifest.json"
  echo "\`\`\`"
  echo ""
  echo "The manifest includes:"
  echo "- Plugin metadata (name, version, owner, description)"
  echo "- Download URLs for all versions"
  echo "- Checksums (MD5, SHA256) for integrity verification"
  echo "- Git commit information for traceability"
  echo "- Build timestamps"
  echo ""
  echo "---"
  echo ""
  echo "*Last updated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")*"
} > README.md

# Clean up source plugins directory
echo "🧹 Removing source plugins from releases branch..."
rm -rf plugins
git rm -rf --cached plugins 2>/dev/null || true

# Commit and push changes
echo "💾 Committing changes..."
git add releases metadata manifest.json README.md

if git diff --cached --quiet; then
  echo "✅ No changes to commit"
else
  # Get source commit info
  source_commit=$(git rev-parse --short origin/$SOURCE_BRANCH)
  
  # Build commit message with conditional plugin list
  plugin_list=""
  if [[ ${#changed_plugins[@]} -gt 0 ]]; then
    plugin_list="

$(printf '%s\n' "${changed_plugins[@]}" | sed 's/^/- /')"
  fi
  
  commit_msg="Publish plugin updates from $SOURCE_BRANCH

Source commit: $source_commit
Plugins updated: ${#changed_plugins[@]}${plugin_list}

[skip ci]"
  
  git commit -m "$commit_msg"
  echo "⬆️  Pushing to $RELEASES_BRANCH..."
  git push "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" $RELEASES_BRANCH
  echo "✅ Successfully published to $RELEASES_BRANCH"
fi
