#!/bin/bash
set -e

# publish-generate-manifest.sh
# Generates metadata/<plugin>/manifest.json for each plugin and the root manifest.json.
#
# Called from the releases branch checkout directory by publish-plugins.sh.
# Required env: SOURCE_BRANCH, RELEASES_BRANCH, GITHUB_REPOSITORY

: "${SOURCE_BRANCH:?}" "${RELEASES_BRANCH:?}" "${GITHUB_REPOSITORY:?}"

plugin_entries=()

for plugin_dir in plugins/*/; do
  plugin_file="$plugin_dir/plugin.json"
  [[ ! -f "$plugin_file" ]] && continue
  plugin_name=$(basename "$plugin_dir")

  echo "  $plugin_name"

  latest_url="https://github.com/${GITHUB_REPOSITORY}/raw/$RELEASES_BRANCH/releases/${plugin_name}/${plugin_name}-latest.zip"

  versioned_zips="[]"
  latest_metadata="{}"

  for zipfile in $(ls -1 "releases/$plugin_name/${plugin_name}"-*.zip 2>/dev/null \
      | grep -v latest | sort -t- -k2 -V -r); do
    zip_basename=$(basename "$zipfile")
    zip_version=$(echo "$zip_basename" | sed "s/${plugin_name}-\(.*\)\.zip/\1/")
    zip_url="https://github.com/${GITHUB_REPOSITORY}/raw/$RELEASES_BRANCH/releases/${plugin_name}/${zip_basename}"
    metadata_file="metadata/$plugin_name/${plugin_name}-${zip_version}.json"

    if [[ -f "$metadata_file" ]]; then
      metadata=$(cat "$metadata_file")
      versioned_zips=$(jq --arg url "$zip_url" --argjson metadata "$metadata" \
        '. + [($metadata + {url: $url})]' <<< "$versioned_zips")
      if [[ "$latest_metadata" == "{}" ]]; then
        latest_metadata="$metadata"
      fi
    else
      versioned_zips=$(jq --arg version "$zip_version" --arg url "$zip_url" \
        '. + [{version: $version, url: $url}]' <<< "$versioned_zips")
    fi
  done

  plugin_entry=$(jq \
    --arg plugin_name "$plugin_name" \
    --arg latest_url "$latest_url" \
    --argjson versioned_zips "$versioned_zips" \
    --argjson latest_metadata "$latest_metadata" \
    'with_entries(select(.key | IN(
      "name","version","description","owner","maintainers",
      "deprecated","unlisted","min_dispatcharr_version","repo_url","discord_thread"
    ))) + {
      slug: $plugin_name,
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

  echo "$plugin_entry" | jq '.' > "metadata/$plugin_name/manifest.json"
  plugin_entries+=("$plugin_entry")
done

{
  echo '{'
  echo '  "plugins": ['
  first=true
  for entry in "${plugin_entries[@]}"; do
    if [[ "$first" != true ]]; then echo ","; fi
    first=false
    echo "$entry" | sed 's/^/    /'
  done
  echo ""
  echo '  ]'
  echo '}'
} | jq '.' > manifest.json

echo "Generated manifest.json with ${#plugin_entries[@]} plugin(s)."
